// ============================================
// ClockInVerificationService
// ============================================
// Service สำหรับตรวจสอบว่าเครื่องผู้ใช้ตรงกับเงื่อนไข clock-in หรือไม่
// โดยเปรียบเทียบกับค่าที่ admin ตั้งไว้ใน Supabase:
//   - GPS: ตำแหน่งปัจจุบันอยู่ในรัศมีที่กำหนดหรือไม่
//   - WiFi: เชื่อมต่อ WiFi ที่ลงทะเบียนหรือไม่
//
// ใช้แสดงสถานะในหน้า Settings ของ Flutter app

import 'dart:async'; // TimeoutException สำหรับ GPS timeout + Supabase fetch timeout

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================
// Result Model - ผลลัพธ์การตรวจสอบ
// ============================================

class ClockInVerificationResult {
  // --- GPS ---
  final bool? gpsMatch;           // true = อยู่ในรัศมี, false = นอกรัศมี, null = ไม่ได้เปิดใช้งาน/ไม่มีข้อมูล
  final double? distanceMeters;   // ระยะห่างจากจุดที่ตั้งค่า (เมตร)
  final double? registeredRadius; // รัศมีที่ตั้งค่าไว้ (เมตร)
  final String? locationName;     // ชื่อสถานที่ที่ตั้งค่าไว้
  final String? gpsError;         // error message ถ้าดึง GPS ไม่ได้

  // --- WiFi ---
  final bool? wifiMatch;          // true = ตรง, false = ไม่ตรง, null = ไม่ได้เปิดใช้งาน/ไม่มีข้อมูล
  final String? currentSsid;      // SSID ที่เชื่อมต่ออยู่ตอนนี้
  final String? matchedSsid;      // SSID ที่ match กับรายการที่ลงทะเบียน (ถ้ามี)
  final int registeredWifiCount;  // จำนวน WiFi ที่ลงทะเบียนไว้ (active)
  final String? wifiError;        // error message ถ้าดึง WiFi ไม่ได้

  const ClockInVerificationResult({
    this.gpsMatch,
    this.distanceMeters,
    this.registeredRadius,
    this.locationName,
    this.gpsError,
    this.wifiMatch,
    this.currentSsid,
    this.matchedSsid,
    this.registeredWifiCount = 0,
    this.wifiError,
  });
}

// ============================================
// Main Service
// ============================================

class ClockInVerificationService {
  final SupabaseClient _supabase;
  final NetworkInfo _networkInfo;

  ClockInVerificationService()
      : _supabase = Supabase.instance.client,
        _networkInfo = NetworkInfo();

  /// Constructor สำหรับ testing — inject dependencies แทน singleton
  @visibleForTesting
  ClockInVerificationService.forTesting({
    required SupabaseClient client,
    required NetworkInfo networkInfo,
  })  : _supabase = client,
        _networkInfo = networkInfo;

  // ============================================
  // Platform wrappers — override ใน test เพื่อจำลอง permission/GPS
  // ============================================

  /// ตรวจ GPS permission ปัจจุบัน
  @visibleForTesting
  Future<LocationPermission> geolocatorCheckPermission() =>
      Geolocator.checkPermission();

  /// ขอ GPS permission
  @visibleForTesting
  Future<LocationPermission> geolocatorRequestPermission() =>
      Geolocator.requestPermission();

  /// ดึงตำแหน่งปัจจุบัน (high accuracy, timeout 15 วินาที)
  /// BUG 3: เพิ่มจาก 10s → 15s เพราะ iOS first fix ในตึกอาจใช้เวลา > 10s
  @visibleForTesting
  Future<Position> geolocatorGetCurrentPosition() =>
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

  /// ตรวจว่า Location Services (GPS) เปิดอยู่ที่ระดับ system หรือไม่
  /// (แยกจาก permission — user อาจอนุญาต app แต่ปิด Location Services ที่ตั้งค่าเครื่อง)
  @visibleForTesting
  Future<bool> geolocatorIsLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  /// คำนวณระยะห่างระหว่าง 2 จุด (เมตร)
  @visibleForTesting
  double geolocatorDistanceBetween(
    double startLat, double startLng, double endLat, double endLng,
  ) => Geolocator.distanceBetween(startLat, startLng, endLat, endLng);

  // ============================================
  // ตรวจสอบทั้ง GPS + WiFi
  // ============================================
  // ดึงข้อมูลที่ admin ตั้งค่าจาก Supabase แล้วเปรียบเทียบกับเครื่องปัจจุบัน
  Future<ClockInVerificationResult> verify(int nursinghomeId) async {
    // ============================================
    // Phase 1: ดึง config จาก Supabase (พร้อม timeout)
    // ============================================
    // BUG 1: ถ้า fetch ไม่ได้ (offline/DB error) → block clock-in
    //   ป้องกัน bypass ด้วยการปิด internet (เดิม catch → null → ผ่าน)
    // BUG 15: เพิ่ม timeout 15 วินาที ป้องกัน verify() ค้างตลอดกาล
    Map<String, dynamic>? locationConfig;
    List<Map<String, dynamic>> wifiConfigs;
    try {
      final results = await Future.wait([
        fetchLocationConfig(nursinghomeId),
        fetchWifiConfig(nursinghomeId),
      ]).timeout(const Duration(seconds: 15));
      locationConfig = results[0] as Map<String, dynamic>?;
      wifiConfigs = results[1] as List<Map<String, dynamic>>;
    } on TimeoutException {
      // Supabase fetch ช้าเกินไป (DNS stuck, server down)
      debugPrint('[ClockInVerification] Config fetch timeout');
      return const ClockInVerificationResult(
        gpsMatch: false,
        gpsError: 'ตรวจสอบเงื่อนไขนานเกินไป กรุณาลองใหม่',
        wifiMatch: false,
        wifiError: 'ตรวจสอบเงื่อนไขนานเกินไป กรุณาลองใหม่',
      );
    } catch (e) {
      // Network error / offline / DB error → block clock-in
      debugPrint('[ClockInVerification] Config fetch error: $e');
      return const ClockInVerificationResult(
        gpsMatch: false,
        gpsError: 'ไม่สามารถตรวจสอบเงื่อนไขได้ กรุณาตรวจสอบอินเทอร์เน็ต',
        wifiMatch: false,
        wifiError: 'ไม่สามารถตรวจสอบเงื่อนไขได้ กรุณาตรวจสอบอินเทอร์เน็ต',
      );
    }

    // ============================================
    // Phase 2: ตรวจสอบ GPS ก่อน แล้ว WiFi (sequential เพราะ share permission request)
    // ============================================
    final gpsResult = await checkGps(locationConfig);
    final wifiResult = await checkWifi(wifiConfigs);

    return ClockInVerificationResult(
      // GPS
      gpsMatch: gpsResult['match'] as bool?,
      distanceMeters: gpsResult['distance'] as double?,
      registeredRadius: gpsResult['radius'] as double?,
      locationName: gpsResult['name'] as String?,
      gpsError: gpsResult['error'] as String?,
      // WiFi
      wifiMatch: wifiResult['match'] as bool?,
      currentSsid: wifiResult['currentSsid'] as String?,
      matchedSsid: wifiResult['matchedSsid'] as String?,
      registeredWifiCount: wifiResult['registeredCount'] as int? ?? 0,
      wifiError: wifiResult['error'] as String?,
    );
  }

  // ============================================
  // ดึง location config จาก B_Nursinghome_Location
  // ============================================
  // BUG 1: ลบ try/catch — ให้ throw ขึ้นไป verify() จัดการ
  //   null = ไม่มี record (admin ไม่ได้ตั้งค่า), throw = error (offline/DB)
  // BUG 19: เพิ่ม is_active filter ให้ consistent กับ fetchWifiConfig
  //   ป้องกัน maybeSingle() throw เมื่อมี inactive + active config
  @visibleForTesting
  Future<Map<String, dynamic>?> fetchLocationConfig(int nursinghomeId) async {
    final response = await _supabase
        .from('B_Nursinghome_Location')
        .select('latitude, longitude, radius_meters, name')
        .eq('nursinghome_id', nursinghomeId)
        .eq('is_active', true)
        .maybeSingle();
    return response;
  }

  // ============================================
  // ดึง WiFi config จาก B_Nursinghome_WiFi
  // ============================================
  // BUG 1: ลบ try/catch — ให้ throw ขึ้นไป verify() จัดการ
  //   [] = ไม่มี active WiFi (admin ไม่ได้ตั้งค่า), throw = error (offline/DB)
  @visibleForTesting
  Future<List<Map<String, dynamic>>> fetchWifiConfig(int nursinghomeId) async {
    final response = await _supabase
        .from('B_Nursinghome_WiFi')
        .select('ssid')
        .eq('nursinghome_id', nursinghomeId)
        .eq('is_active', true);
    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================
  // ตรวจสอบ GPS - ตำแหน่งปัจจุบันอยู่ในรัศมีหรือไม่
  // ============================================
  @visibleForTesting
  Future<Map<String, dynamic>> checkGps(Map<String, dynamic>? config) async {
    // ถ้าไม่มี config → ไม่ตรวจ (admin ไม่ได้ตั้งค่า หรือปิดใช้งาน)
    // หมายเหตุ: is_active ถูก filter แล้วที่ fetchLocationConfig()
    if (config == null) {
      return {'match': null};
    }

    try {
      // ตรวจว่า Location Services เปิดอยู่ที่ระดับ system หรือไม่
      // (user อาจอนุญาต app แต่ปิด Location Services ที่ตั้งค่าเครื่อง)
      final serviceEnabled = await geolocatorIsLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'match': false,
          'error': 'กรุณาเปิดบริการตำแหน่งที่ตั้ง (Location Services) ในตั้งค่าเครื่อง',
          'name': config['name'] as String?,
          'radius': (config['radius_meters'] as num?)?.toDouble(),
        };
      }

      // ขอ permission (ใช้ wrapper method เพื่อให้ test override ได้)
      final permission = await geolocatorCheckPermission();
      if (permission == LocationPermission.denied) {
        final requested = await geolocatorRequestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return {
            'match': false,
            'error': 'กรุณาอนุญาตสิทธิ์การเข้าถึงตำแหน่งเพื่อตรวจสอบ GPS',
            'name': config['name'] as String?,
            'radius': (config['radius_meters'] as num?)?.toDouble(),
          };
        }
      } else if (permission == LocationPermission.deniedForever) {
        // user เคยปฏิเสธถาวร → ต้องไปเปิดใน Settings เอง
        return {
          'match': false,
          'error': 'สิทธิ์ตำแหน่งถูกปิดถาวร กรุณาเปิดในตั้งค่าแอป',
          'name': config['name'] as String?,
          'radius': (config['radius_meters'] as num?)?.toDouble(),
        };
      }

      // BUG 6: ตรวจว่า lat/lng/radius มีค่าครบก่อน cast
      // ป้องกัน crash ถ้า admin ตั้งค่าไม่ครบ (เช่น DB manipulation)
      final lat = config['latitude'];
      final lng = config['longitude'];
      final radius = config['radius_meters'];
      if (lat == null || lng == null || radius == null) {
        return {'match': null}; // treat as "not configured properly"
      }

      final registeredLat = (lat as num).toDouble();
      final registeredLng = (lng as num).toDouble();
      final radiusMeters = (radius as num).toDouble();

      // BUG 13: ตรวจว่า radius เป็นค่าที่ valid (> 0)
      // Admin UI validates 10-500m แต่ direct DB manipulation อาจตั้งค่าผิด
      if (radiusMeters <= 0) {
        return {'match': null}; // treat as not configured properly
      }

      // ดึงตำแหน่งปัจจุบัน (ใช้ wrapper method)
      final position = await geolocatorGetCurrentPosition();

      // BUG 11: ตรวจจับ mock/fake location (Android only — iOS always returns false)
      // ป้องกัน user ใช้แอพจำลอง GPS เพื่อ clock-in จากที่อื่น
      if (position.isMocked) {
        return {
          'match': false,
          'error': 'ตรวจพบการจำลองตำแหน่ง กรุณาปิดแอพจำลอง GPS แล้วลองใหม่',
          'name': config['name'] as String?,
          'radius': radiusMeters,
        };
      }

      // BUG 8+9: ตรวจว่า accuracy เพียงพอสำหรับ radius ที่ตั้งไว้
      // Android 12+ "Approximate Location" → accuracy 1-2km → ห่าง radius เกือบเสมอ
      // iOS 14+ ปิด "Precise Location" → accuracy ~5km → GPS fail
      // ถ้า accuracy > radius → ตำแหน่งไม่แม่นยำพอที่จะตัดสินได้
      if (position.accuracy > radiusMeters) {
        return {
          'match': false,
          'error': 'ตำแหน่งไม่แม่นยำพอ กรุณาเปิด "ตำแหน่งที่แม่นยำ" (Precise Location) ในตั้งค่า',
          'name': config['name'] as String?,
          'radius': radiusMeters,
        };
      }

      // คำนวณระยะห่างระหว่างตำแหน่งปัจจุบันกับตำแหน่งที่ลงทะเบียน
      final distance = geolocatorDistanceBetween(
        position.latitude,
        position.longitude,
        registeredLat,
        registeredLng,
      );

      return {
        'match': distance <= radiusMeters,
        'distance': distance,
        'radius': radiusMeters,
        'name': config['name'] as String?,
      };
    } on TimeoutException {
      // BUG 5: แยก timeout error จาก error ทั่วไป
      // Geolocator throws TimeoutException เมื่อ timeLimit หมด
      // มักเกิดในตึกหรือเพิ่งเปิด GPS (iOS first fix ช้า)
      return {
        'match': false,
        'error': 'หาตำแหน่งไม่ทันเวลา กรุณาออกจากในตึกแล้วลองใหม่',
        'name': config['name'] as String?,
        'radius': (config['radius_meters'] as num?)?.toDouble(),
      };
    } catch (e) {
      debugPrint('[ClockInVerification] GPS error: $e');
      // admin ตั้งค่า GPS ไว้แล้ว แต่ตรวจไม่ได้ → block (false)
      return {
        'match': false,
        'error': 'ตรวจสอบตำแหน่งไม่สำเร็จ กรุณาเปิด GPS แล้วลองใหม่',
        'name': config['name'] as String?,
        'radius': (config['radius_meters'] as num?)?.toDouble(),
      };
    }
  }

  // ============================================
  // ตรวจสอบ WiFi - เชื่อมต่อ WiFi ที่ลงทะเบียนหรือไม่
  // ============================================
  @visibleForTesting
  Future<Map<String, dynamic>> checkWifi(List<Map<String, dynamic>> configs) async {
    // ถ้าไม่มี WiFi ที่ลงทะเบียน (active) → ไม่ตรวจ
    if (configs.isEmpty) {
      return {'match': null, 'registeredCount': 0};
    }

    try {
      // ตรวจว่า Location Services เปิดอยู่ที่ระดับ system หรือไม่
      // WiFi SSID บน iOS/Android ต้องใช้ Location Services จึงจะดึง SSID ได้
      final serviceEnabled = await geolocatorIsLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'match': false,
          'error': 'กรุณาเปิดบริการตำแหน่งที่ตั้ง (Location Services) ในตั้งค่าเครื่อง',
          'registeredCount': configs.length,
        };
      }

      // ตรวจ permission ผ่าน Geolocator (ใช้ CLLocationManager ตัวเดียวกับ GPS)
      // หลีกเลี่ยงใช้ permission_handler แยก เพราะ iOS อาจ conflict
      // เมื่อมี CLLocationManager หลายตัวจาก package คนละตัว
      final permission = await geolocatorCheckPermission();
      if (permission == LocationPermission.denied) {
        final requested = await geolocatorRequestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return {
            'match': false,
            'error': 'กรุณาอนุญาตสิทธิ์การเข้าถึงตำแหน่งเพื่อตรวจสอบ WiFi',
            'registeredCount': configs.length,
          };
        }
      } else if (permission == LocationPermission.deniedForever) {
        return {
          'match': false,
          'error': 'สิทธิ์ตำแหน่งถูกปิดถาวร กรุณาเปิดในตั้งค่าแอป',
          'registeredCount': configs.length,
        };
      }

      // ดึง SSID ของ WiFi ที่เชื่อมต่ออยู่
      String? currentSsid = await _networkInfo.getWifiName();

      // BUG 2: strip quotes + trim whitespace
      // network_info_plus อาจคืนค่า SSID ที่ครอบด้วย quotes เช่น "MyWiFi"
      // และอาจมี whitespace ที่ปลาย → trim ออก
      if (currentSsid != null) {
        currentSsid = currentSsid.replaceAll('"', '').trim();
      }

      // BUG 12: Android อาจ return "<unknown ssid>" เมื่อ permission ไม่สมบูรณ์
      // treat เป็น null (ไม่ทราบ WiFi) แทนที่จะแสดง SSID ปลอม
      if (currentSsid == null || currentSsid.isEmpty || currentSsid == '<unknown ssid>') {
        currentSsid = null;
      }

      // BUG 4: เปรียบเทียบแบบ case-insensitive
      // iOS/Android อาจ return SSID ตัวเล็ก/ใหญ่ต่างจากที่ admin ลงทะเบียน
      final registeredSsids = configs.map((c) => c['ssid'] as String).toList();
      final lowerSsid = currentSsid?.toLowerCase();
      final matchedSsid = registeredSsids.cast<String?>().firstWhere(
        (s) => s?.toLowerCase() == lowerSsid,
        orElse: () => null,
      );

      return {
        'match': matchedSsid != null,
        'currentSsid': currentSsid,
        'matchedSsid': matchedSsid,
        'registeredCount': configs.length,
      };
    } catch (e) {
      debugPrint('[ClockInVerification] WiFi error: $e');
      // admin ตั้งค่า WiFi ไว้แล้ว แต่ตรวจไม่ได้ → block (false)
      // ป้องกันไม่ให้ bypass ด้วยการทำให้เกิด error
      return {
        'match': false,
        'error': 'ตรวจสอบ WiFi ไม่สำเร็จ กรุณาเปิด WiFi แล้วลองใหม่',
        'registeredCount': configs.length,
      };
    }
  }
}
