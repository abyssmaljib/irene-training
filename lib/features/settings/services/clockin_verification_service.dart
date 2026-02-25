// ============================================
// ClockInVerificationService
// ============================================
// Service สำหรับตรวจสอบว่าเครื่องผู้ใช้ตรงกับเงื่อนไข clock-in หรือไม่
// โดยเปรียบเทียบกับค่าที่ admin ตั้งไว้ใน Supabase:
//   - GPS: ตำแหน่งปัจจุบันอยู่ในรัศมีที่กำหนดหรือไม่
//   - WiFi: เชื่อมต่อ WiFi ที่ลงทะเบียนหรือไม่
//
// ใช้แสดงสถานะในหน้า Settings ของ Flutter app

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final _supabase = Supabase.instance.client;
  final _networkInfo = NetworkInfo();

  // ============================================
  // ตรวจสอบทั้ง GPS + WiFi พร้อมกัน
  // ============================================
  // ดึงข้อมูลที่ admin ตั้งค่าจาก Supabase แล้วเปรียบเทียบกับเครื่องปัจจุบัน
  Future<ClockInVerificationResult> verify(int nursinghomeId) async {
    // ดึงข้อมูลจาก Supabase พร้อมกัน (location + wifi)
    final results = await Future.wait([
      _fetchLocationConfig(nursinghomeId),
      _fetchWifiConfig(nursinghomeId),
    ]);

    final locationConfig = results[0] as Map<String, dynamic>?;
    final wifiConfigs = results[1] as List<Map<String, dynamic>>;

    // ตรวจสอบ GPS และ WiFi พร้อมกัน
    final gpsResult = await _checkGps(locationConfig);
    final wifiResult = await _checkWifi(wifiConfigs);

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
  Future<Map<String, dynamic>?> _fetchLocationConfig(int nursinghomeId) async {
    try {
      final response = await _supabase
          .from('B_Nursinghome_Location')
          .select('latitude, longitude, radius_meters, is_active, name')
          .eq('nursinghome_id', nursinghomeId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('[ClockInVerification] Error fetching location: $e');
      return null;
    }
  }

  // ============================================
  // ดึง WiFi config จาก B_Nursinghome_WiFi
  // ============================================
  Future<List<Map<String, dynamic>>> _fetchWifiConfig(int nursinghomeId) async {
    try {
      final response = await _supabase
          .from('B_Nursinghome_WiFi')
          .select('ssid, is_active')
          .eq('nursinghome_id', nursinghomeId)
          .eq('is_active', true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[ClockInVerification] Error fetching WiFi: $e');
      return [];
    }
  }

  // ============================================
  // ตรวจสอบ GPS - ตำแหน่งปัจจุบันอยู่ในรัศมีหรือไม่
  // ============================================
  Future<Map<String, dynamic>> _checkGps(Map<String, dynamic>? config) async {
    // ถ้าไม่มี config หรือปิดใช้งาน → ไม่ตรวจ
    if (config == null || config['is_active'] != true) {
      return {'match': null};
    }

    try {
      // ขอ permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return {
            'match': null,
            'error': 'ไม่ได้รับสิทธิ์เข้าถึงตำแหน่ง',
            'name': config['name'] as String?,
            'radius': (config['radius_meters'] as num?)?.toDouble(),
          };
        }
      }

      // ดึงตำแหน่งปัจจุบัน
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // คำนวณระยะห่างระหว่างตำแหน่งปัจจุบันกับตำแหน่งที่ลงทะเบียน
      final registeredLat = (config['latitude'] as num).toDouble();
      final registeredLng = (config['longitude'] as num).toDouble();
      final radiusMeters = (config['radius_meters'] as num).toDouble();

      final distance = Geolocator.distanceBetween(
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
    } catch (e) {
      debugPrint('[ClockInVerification] GPS error: $e');
      return {
        'match': null,
        'error': 'ดึงตำแหน่งไม่สำเร็จ',
        'name': config['name'] as String?,
        'radius': (config['radius_meters'] as num?)?.toDouble(),
      };
    }
  }

  // ============================================
  // ตรวจสอบ WiFi - เชื่อมต่อ WiFi ที่ลงทะเบียนหรือไม่
  // ============================================
  Future<Map<String, dynamic>> _checkWifi(List<Map<String, dynamic>> configs) async {
    // ถ้าไม่มี WiFi ที่ลงทะเบียน (active) → ไม่ตรวจ
    if (configs.isEmpty) {
      return {'match': null, 'registeredCount': 0};
    }

    try {
      // ขอ permission สำหรับ WiFi info (ต้องใช้ location permission บน Android)
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        return {
          'match': null,
          'error': 'ไม่ได้รับสิทธิ์เข้าถึง WiFi',
          'registeredCount': configs.length,
        };
      }

      // ดึง SSID ของ WiFi ที่เชื่อมต่ออยู่
      String? currentSsid = await _networkInfo.getWifiName();

      // network_info_plus อาจคืนค่า SSID ที่ครอบด้วย quotes เช่น "MyWiFi"
      // ต้อง strip ออก
      if (currentSsid != null) {
        currentSsid = currentSsid.replaceAll('"', '');
      }

      // เปรียบเทียบกับรายการที่ลงทะเบียน (case-sensitive)
      final registeredSsids = configs.map((c) => c['ssid'] as String).toList();
      final matchedSsid = registeredSsids.contains(currentSsid) ? currentSsid : null;

      return {
        'match': matchedSsid != null,
        'currentSsid': currentSsid,
        'matchedSsid': matchedSsid,
        'registeredCount': configs.length,
      };
    } catch (e) {
      debugPrint('[ClockInVerification] WiFi error: $e');
      return {
        'match': null,
        'error': 'ดึงข้อมูล WiFi ไม่สำเร็จ',
        'registeredCount': configs.length,
      };
    }
  }
}
