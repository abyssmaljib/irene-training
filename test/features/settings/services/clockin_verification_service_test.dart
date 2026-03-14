import 'dart:async'; // TimeoutException

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:irene_training/features/settings/services/clockin_verification_service.dart';

// =====================
// Mock classes
// =====================

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

// =====================
// TestableClockInVerificationService
// =====================
// Override platform-dependent methods (Geolocator, Permission)
// เพื่อควบคุมพฤติกรรมใน test ได้

class TestableClockInVerificationService extends ClockInVerificationService {
  // --- ควบคุม Location Services (ระดับ system) ---
  // default true เพื่อไม่ให้ test เดิมที่ไม่ได้เซตค่านี้พัง
  bool locationServiceEnabled = true;

  // --- ควบคุม Geolocator ---
  LocationPermission geoPermissionCheckResult = LocationPermission.always;
  LocationPermission geoPermissionRequestResult = LocationPermission.always;
  Position? currentPosition;
  Exception? geolocatorException;

  // --- ควบคุม distance ---
  double distanceResult = 0.0;

  // --- ควบคุม fetch config ---
  // null = ไม่มี record (admin ไม่ได้ตั้งค่า)
  // BUG 1: ถ้า fetchConfigException != null → throw เพื่อจำลอง offline/DB error
  Map<String, dynamic>? locationConfigResult;
  List<Map<String, dynamic>> wifiConfigResult = [];
  Exception? fetchConfigException; // BUG 1: จำลอง offline/DB error

  TestableClockInVerificationService({
    required MockSupabaseClient client,
    required MockNetworkInfo networkInfo,
  }) : super.forTesting(client: client, networkInfo: networkInfo);

  @override
  Future<bool> geolocatorIsLocationServiceEnabled() async =>
      locationServiceEnabled;

  @override
  Future<LocationPermission> geolocatorCheckPermission() async =>
      geoPermissionCheckResult;

  @override
  Future<LocationPermission> geolocatorRequestPermission() async =>
      geoPermissionRequestResult;

  @override
  Future<Position> geolocatorGetCurrentPosition() async {
    if (geolocatorException != null) throw geolocatorException!;
    return currentPosition ??
        Position(
          latitude: 13.7563,
          longitude: 100.5018,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
  }

  @override
  double geolocatorDistanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) =>
      distanceResult;

  @override
  Future<Map<String, dynamic>?> fetchLocationConfig(int nursinghomeId) async {
    if (fetchConfigException != null) throw fetchConfigException!;
    return locationConfigResult;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchWifiConfig(
      int nursinghomeId) async {
    if (fetchConfigException != null) throw fetchConfigException!;
    return wifiConfigResult;
  }
}

// =====================
// Test Data
// =====================

/// GPS config ที่ admin ตั้งค่าไว้ (ไม่มี is_active เพราะ filter ที่ query level แล้ว)
Map<String, dynamic> createGpsConfig({
  double lat = 13.7563,
  double lng = 100.5018,
  double radius = 100.0,
  String name = 'สถานที่ทดสอบ',
}) =>
    {
      'latitude': lat,
      'longitude': lng,
      'radius_meters': radius,
      'name': name,
    };

/// WiFi config ที่ admin ตั้งค่าไว้ (ไม่มี is_active เพราะ filter ที่ query level แล้ว)
List<Map<String, dynamic>> createWifiConfigs({
  List<String> ssids = const ['IreneWiFi', 'IreneWiFi_5G'],
}) =>
    ssids.map((ssid) => {'ssid': ssid}).toList();

/// สร้าง Position พร้อมกำหนด accuracy + isMocked
Position createPosition({
  double accuracy = 10,
  bool isMocked = false,
}) =>
    Position(
      latitude: 13.7563,
      longitude: 100.5018,
      timestamp: DateTime.now(),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: isMocked,
    );

void main() {
  late MockSupabaseClient mockClient;
  late MockNetworkInfo mockNetworkInfo;
  late TestableClockInVerificationService service;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockNetworkInfo = MockNetworkInfo();
    service = TestableClockInVerificationService(
      client: mockClient,
      networkInfo: mockNetworkInfo,
    );
  });

  // ============================================================
  // Scenario 1: Admin ไม่ได้ตั้งค่า WiFi → wifiMatch: null (ข้าม)
  // ============================================================
  group('Scenario 1: Admin ไม่ได้ตั้งค่า WiFi', () {
    test('ไม่มี WiFi config → wifiMatch: null (ข้ามเงื่อนไข)', () async {
      // Arrange — ไม่มี WiFi ที่ลงทะเบียน
      service.wifiConfigResult = [];
      service.locationConfigResult = null;

      // Act
      final result = await service.verify(1);

      // Assert — WiFi ไม่ได้ตั้งค่า → null (ไม่ block)
      expect(result.wifiMatch, isNull);
      expect(result.registeredWifiCount, equals(0));
    });
  });

  // ============================================================
  // Scenario 2: Admin ไม่ได้ตั้งค่า GPS → gpsMatch: null (ข้าม)
  // ============================================================
  group('Scenario 2: Admin ไม่ได้ตั้งค่า GPS', () {
    test('ไม่มี GPS config → gpsMatch: null (ข้ามเงื่อนไข)', () async {
      // Arrange — ไม่มี location config (fetchLocationConfig returns null)
      service.locationConfigResult = null;
      service.wifiConfigResult = [];

      // Act
      final result = await service.verify(1);

      // Assert — GPS ไม่ได้ตั้งค่า → null (ไม่ block)
      expect(result.gpsMatch, isNull);
    });
  });

  // ============================================================
  // Scenario 3: WiFi ตรง → wifiMatch: true
  // ============================================================
  group('Scenario 3: WiFi ตรงกับที่ลงทะเบียน', () {
    test('SSID ตรง → wifiMatch: true', () async {
      // Arrange — admin ตั้ง WiFi + user ต่อ WiFi ที่ตรง
      service.wifiConfigResult = createWifiConfigs();
      service.locationConfigResult = null;
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => 'IreneWiFi');

      // Act
      final result = await service.verify(1);

      // Assert
      expect(result.wifiMatch, isTrue);
      expect(result.currentSsid, equals('IreneWiFi'));
      expect(result.matchedSsid, equals('IreneWiFi'));
    });
  });

  // ============================================================
  // Scenario 4: GPS อยู่ในรัศมี → gpsMatch: true
  // ============================================================
  group('Scenario 4: GPS อยู่ในรัศมี', () {
    test('ระยะห่าง < radius → gpsMatch: true', () async {
      // Arrange — อยู่ในรัศมี 100 เมตร
      service.locationConfigResult = createGpsConfig(radius: 100);
      service.wifiConfigResult = [];
      service.distanceResult = 50.0; // ห่าง 50 เมตร (< 100)

      // Act
      final result = await service.verify(1);

      // Assert
      expect(result.gpsMatch, isTrue);
      expect(result.distanceMeters, equals(50.0));
      expect(result.registeredRadius, equals(100.0));
    });

    test('ระยะห่าง = radius (ขอบเขตพอดี) → gpsMatch: true', () async {
      // Arrange — อยู่พอดีขอบ
      service.locationConfigResult = createGpsConfig(radius: 100);
      service.wifiConfigResult = [];
      service.distanceResult = 100.0; // ห่างพอดี = radius

      // Act
      final result = await service.verify(1);

      // Assert — distance <= radius → ผ่าน
      expect(result.gpsMatch, isTrue);
    });
  });

  // ============================================================
  // Scenario 5: WiFi permission denied → wifiMatch: false (BLOCK)
  // ============================================================
  group('Scenario 5: WiFi permission denied → BLOCK', () {
    test('permission denied → wifiMatch: false + error message', () async {
      // Arrange — admin ตั้ง WiFi ไว้ แต่ user ปฏิเสธ permission
      service.wifiConfigResult = createWifiConfigs();
      service.locationConfigResult = null;
      service.geoPermissionCheckResult = LocationPermission.denied;
      service.geoPermissionRequestResult = LocationPermission.denied;

      // Act
      final result = await service.verify(1);

      // Assert — ต้อง block (false) ไม่ใช่ null!
      expect(result.wifiMatch, isFalse,
          reason: 'permission denied → false (block)');
      expect(result.wifiError, isNotNull);
      expect(result.wifiError, contains('อนุญาตสิทธิ์'));
    });
  });

  // ============================================================
  // Scenario 6: WiFi getWifiName() throws → wifiMatch: false (BLOCK)
  // ============================================================
  group('Scenario 6: WiFi getWifiName() throws → BLOCK', () {
    test('getWifiName() exception → wifiMatch: false + error', () async {
      // Arrange — admin ตั้ง WiFi ไว้ แต่ดึง SSID ไม่ได้
      service.wifiConfigResult = createWifiConfigs();
      service.locationConfigResult = null;
      when(() => mockNetworkInfo.getWifiName())
          .thenThrow(Exception('WiFi info not available'));

      // Act
      final result = await service.verify(1);

      // Assert — ต้อง block (false) ไม่ใช่ null!
      expect(result.wifiMatch, isFalse,
          reason: 'getWifiName() error → false (block)');
      expect(result.wifiError, isNotNull);
      expect(result.wifiError, contains('WiFi'));
    });
  });

  // ============================================================
  // Scenario 7: WiFi SSID ไม่ match → wifiMatch: false
  // ============================================================
  group('Scenario 7: WiFi SSID ไม่ตรง', () {
    test('ต่อ WiFi อื่นที่ไม่ได้ลงทะเบียน → wifiMatch: false', () async {
      // Arrange — ต่อ WiFi ที่ไม่ตรง
      service.wifiConfigResult = createWifiConfigs();
      service.locationConfigResult = null;
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => 'CoffeeShopWiFi');

      // Act
      final result = await service.verify(1);

      // Assert
      expect(result.wifiMatch, isFalse);
      expect(result.currentSsid, equals('CoffeeShopWiFi'));
      expect(result.matchedSsid, isNull);
    });
  });

  // ============================================================
  // Scenario 8: GPS permission denied → gpsMatch: false (BLOCK)
  // ============================================================
  group('Scenario 8: GPS permission denied → BLOCK', () {
    test('GPS permission denied → gpsMatch: false + error', () async {
      // Arrange — admin ตั้ง GPS ไว้ แต่ user ปฏิเสธ permission
      service.locationConfigResult = createGpsConfig();
      service.wifiConfigResult = [];
      service.geoPermissionCheckResult = LocationPermission.denied;
      service.geoPermissionRequestResult = LocationPermission.denied;

      // Act
      final result = await service.verify(1);

      // Assert — ต้อง block (false) ไม่ใช่ null!
      expect(result.gpsMatch, isFalse,
          reason: 'permission denied → false (block)');
      expect(result.gpsError, isNotNull);
      expect(result.gpsError, contains('อนุญาตสิทธิ์'));
    });

    test('GPS permission deniedForever → gpsMatch: false', () async {
      // Arrange — user ปฏิเสธถาวร
      service.locationConfigResult = createGpsConfig();
      service.wifiConfigResult = [];
      service.geoPermissionCheckResult = LocationPermission.denied;
      service.geoPermissionRequestResult = LocationPermission.deniedForever;

      // Act
      final result = await service.verify(1);

      // Assert
      expect(result.gpsMatch, isFalse);
      expect(result.gpsError, isNotNull);
    });
  });

  // ============================================================
  // Scenario 9: Geolocator throws → gpsMatch: false (BLOCK)
  // ============================================================
  group('Scenario 9: Geolocator exception → BLOCK', () {
    test('getCurrentPosition() throws → gpsMatch: false + error', () async {
      // Arrange — admin ตั้ง GPS ไว้ แต่ดึงตำแหน่งไม่ได้
      service.locationConfigResult = createGpsConfig();
      service.wifiConfigResult = [];
      service.geolocatorException = Exception('Location service disabled');

      // Act
      final result = await service.verify(1);

      // Assert — ต้อง block (false) ไม่ใช่ null!
      expect(result.gpsMatch, isFalse,
          reason: 'Geolocator error → false (block)');
      expect(result.gpsError, isNotNull);
      expect(result.gpsError, contains('GPS'));
    });
  });

  // ============================================================
  // Scenario 10: GPS อยู่นอกรัศมี → gpsMatch: false
  // ============================================================
  group('Scenario 10: GPS อยู่นอกรัศมี', () {
    test('ระยะห่าง > radius → gpsMatch: false', () async {
      // Arrange — อยู่นอกรัศมี
      service.locationConfigResult = createGpsConfig(radius: 100);
      service.wifiConfigResult = [];
      service.distanceResult = 250.0; // ห่าง 250 เมตร (> 100)

      // Act
      final result = await service.verify(1);

      // Assert
      expect(result.gpsMatch, isFalse);
      expect(result.distanceMeters, equals(250.0));
      expect(result.gpsError, isNull, reason: 'ไม่มี error เพราะตรวจได้ปกติ');
    });
  });

  // ============================================================
  // Scenario 11: WiFi SSID มี quotes → strip แล้ว match ได้
  // ============================================================
  group('Scenario 11: WiFi SSID strip quotes', () {
    test('"IreneWiFi" (มี quotes) → strip แล้ว match ได้', () async {
      // Arrange — network_info_plus คืนค่า SSID ที่ครอบด้วย quotes
      service.wifiConfigResult = createWifiConfigs(ssids: ['IreneWiFi']);
      service.locationConfigResult = null;
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => '"IreneWiFi"');

      // Act
      final result = await service.verify(1);

      // Assert — strip quotes แล้ว match
      expect(result.wifiMatch, isTrue);
      expect(result.currentSsid, equals('IreneWiFi'));
      expect(result.matchedSsid, equals('IreneWiFi'));
    });
  });

  // ============================================================
  // Scenario 12: WiFi ไม่ได้ต่อ (null SSID) → wifiMatch: false
  // ============================================================
  group('Scenario 12: WiFi ไม่ได้ต่อ (ใช้ mobile data)', () {
    test('currentSsid = null → wifiMatch: false', () async {
      // Arrange — ปิด WiFi ใช้ mobile data
      service.wifiConfigResult = createWifiConfigs();
      service.locationConfigResult = null;
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => null);

      // Act
      final result = await service.verify(1);

      // Assert — ไม่ได้ต่อ WiFi → ไม่ match
      expect(result.wifiMatch, isFalse);
      expect(result.currentSsid, isNull);
      expect(result.matchedSsid, isNull);
    });
  });

  // ============================================================
  // Scenario 13: Offline → fetchConfig throws → verify blocks (BUG 1)
  // ============================================================
  group('Scenario 13: Offline → fetchConfig throws → BLOCK (BUG 1)', () {
    test('fetchConfig throws (offline) → gps+wifi false + error', () async {
      // Arrange — Supabase fetch throws เพราะ offline
      service.fetchConfigException = Exception('SocketException: No internet');

      // Act
      final result = await service.verify(1);

      // Assert — ต้อง block ทั้งคู่ ไม่ใช่ bypass!
      expect(result.gpsMatch, isFalse,
          reason: 'BUG 1: offline ต้อง block ไม่ใช่ bypass');
      expect(result.gpsError, contains('อินเทอร์เน็ต'));
      expect(result.wifiMatch, isFalse);
      expect(result.wifiError, contains('อินเทอร์เน็ต'));
    });
  });

  // ============================================================
  // Scenario 14: Location Services ปิดที่ระดับ system
  // ============================================================
  group('Scenario 14: Location Services ปิดที่ระดับ system', () {
    test('GPS: Location Services ปิด → gpsMatch: false + error บอกให้เปิด', () async {
      // Arrange — Location Services ปิดที่ระดับ system
      service.locationConfigResult = createGpsConfig();
      service.wifiConfigResult = [];
      service.locationServiceEnabled = false;

      // Act
      final result = await service.verify(1);

      // Assert — ต้องแจ้ง error ที่ชัดเจนว่าต้องเปิด Location Services
      expect(result.gpsMatch, isFalse);
      expect(result.gpsError, isNotNull);
      expect(result.gpsError, contains('บริการตำแหน่งที่ตั้ง'));
    });

    test('WiFi: Location Services ปิด → wifiMatch: false + error บอกให้เปิด', () async {
      // Arrange — Location Services ปิดที่ระดับ system
      service.wifiConfigResult = createWifiConfigs();
      service.locationConfigResult = null;
      service.locationServiceEnabled = false;

      // Act
      final result = await service.verify(1);

      // Assert — ต้องแจ้ง error ที่ชัดเจนว่าต้องเปิด Location Services
      expect(result.wifiMatch, isFalse);
      expect(result.wifiError, isNotNull);
      expect(result.wifiError, contains('บริการตำแหน่งที่ตั้ง'));
    });

    test('ทั้ง GPS + WiFi fail พร้อมกันเมื่อ Location Services ปิด', () async {
      // Arrange — จำลองสถานการณ์จาก user report (screenshot)
      service.locationConfigResult = createGpsConfig();
      service.wifiConfigResult = createWifiConfigs();
      service.locationServiceEnabled = false;

      // Act
      final result = await service.verify(1);

      // Assert — ทั้งคู่ต้อง fail พร้อม error ที่ชัดเจน
      expect(result.gpsMatch, isFalse);
      expect(result.gpsError, contains('บริการตำแหน่งที่ตั้ง'));
      expect(result.wifiMatch, isFalse);
      expect(result.wifiError, contains('บริการตำแหน่งที่ตั้ง'));
    });
  });

  // ============================================================
  // Scenario 15: GPS permission deniedForever ตั้งแต่แรก
  // ============================================================
  group('Scenario 15: GPS permission deniedForever ตั้งแต่แรก', () {
    test('checkPermission = deniedForever → gpsMatch: false + error เปิดในตั้งค่า', () async {
      // Arrange — user เคยปฏิเสธถาวร ไม่ต้องถามซ้ำ
      service.locationConfigResult = createGpsConfig();
      service.wifiConfigResult = [];
      service.geoPermissionCheckResult = LocationPermission.deniedForever;

      // Act
      final result = await service.verify(1);

      // Assert — ต้อง block + บอกให้ไปเปิดในตั้งค่าแอป
      expect(result.gpsMatch, isFalse);
      expect(result.gpsError, isNotNull);
      expect(result.gpsError, contains('ตั้งค่าแอป'));
    });
  });

  // ============================================================
  // Scenario 16: ทั้ง GPS + WiFi ผ่านพร้อมกัน
  // ============================================================
  group('Scenario 16: ทั้ง GPS + WiFi ผ่านพร้อมกัน', () {
    test('GPS ในรัศมี + WiFi ตรง → ทั้งคู่ true', () async {
      // Arrange — ทุกเงื่อนไขผ่าน
      service.locationConfigResult = createGpsConfig(radius: 100);
      service.distanceResult = 30.0;
      service.wifiConfigResult = createWifiConfigs(ssids: ['IreneWiFi']);
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => 'IreneWiFi');

      // Act
      final result = await service.verify(1);

      // Assert
      expect(result.gpsMatch, isTrue);
      expect(result.wifiMatch, isTrue);
    });
  });

  // ============================================================
  // Scenario 17: GPS ผ่าน + WiFi ไม่ผ่าน
  // ============================================================
  group('Scenario 17: GPS ผ่าน แต่ WiFi ไม่ผ่าน', () {
    test('GPS true + WiFi false → clock-in ไม่ได้', () async {
      // Arrange
      service.locationConfigResult = createGpsConfig(radius: 100);
      service.distanceResult = 30.0;
      service.wifiConfigResult = createWifiConfigs();
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => 'OtherWiFi');

      // Act
      final result = await service.verify(1);

      // Assert — GPS ผ่าน แต่ WiFi ไม่ตรง
      expect(result.gpsMatch, isTrue);
      expect(result.wifiMatch, isFalse);
    });
  });

  // ============================================================
  // BUG 2: SSID with whitespace → trim แล้ว match
  // ============================================================
  group('BUG 2: SSID with whitespace', () {
    test('SSID มี whitespace ต่อท้าย → trim แล้ว match', () async {
      service.wifiConfigResult = createWifiConfigs(ssids: ['IreneWiFi']);
      service.locationConfigResult = null;
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => 'IreneWiFi  '); // trailing spaces

      final result = await service.verify(1);

      expect(result.wifiMatch, isTrue);
      expect(result.currentSsid, equals('IreneWiFi'));
    });

    test('SSID มี whitespace นำหน้า → trim แล้ว match', () async {
      service.wifiConfigResult = createWifiConfigs(ssids: ['IreneWiFi']);
      service.locationConfigResult = null;
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => '  IreneWiFi'); // leading spaces

      final result = await service.verify(1);

      expect(result.wifiMatch, isTrue);
      expect(result.currentSsid, equals('IreneWiFi'));
    });
  });

  // ============================================================
  // BUG 4: SSID case-insensitive comparison
  // ============================================================
  group('BUG 4: SSID case-insensitive', () {
    test('SSID ตัวพิมพ์ต่างกัน → ยัง match ได้', () async {
      service.wifiConfigResult = createWifiConfigs(ssids: ['IreneWiFi']);
      service.locationConfigResult = null;
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => 'irenewifi'); // all lowercase

      final result = await service.verify(1);

      expect(result.wifiMatch, isTrue);
      // matchedSsid ควรเป็นค่าจาก config (ไม่ใช่จาก device)
      expect(result.matchedSsid, equals('IreneWiFi'));
    });

    test('SSID ตัวพิมพ์ใหญ่ทั้งหมด → ยัง match ได้', () async {
      service.wifiConfigResult = createWifiConfigs(ssids: ['IreneWiFi']);
      service.locationConfigResult = null;
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => 'IRENEWIFI'); // all uppercase

      final result = await service.verify(1);

      expect(result.wifiMatch, isTrue);
    });
  });

  // ============================================================
  // BUG 5: GPS timeout → specific error message
  // ============================================================
  group('BUG 5: GPS timeout error message', () {
    test('TimeoutException → error "หาตำแหน่งไม่ทันเวลา"', () async {
      service.locationConfigResult = createGpsConfig();
      service.wifiConfigResult = [];
      service.geolocatorException = TimeoutException('GPS timeout');

      final result = await service.verify(1);

      expect(result.gpsMatch, isFalse);
      expect(result.gpsError, contains('ไม่ทันเวลา'));
    });
  });

  // ============================================================
  // BUG 6: Null lat/lng → treated as not configured
  // ============================================================
  group('BUG 6: Null lat/lng/radius in config', () {
    test('latitude = null → gpsMatch: null (not configured)', () async {
      service.locationConfigResult = {
        'latitude': null,
        'longitude': 100.5018,
        'radius_meters': 100,
        'name': 'Test',
      };
      service.wifiConfigResult = [];

      final result = await service.verify(1);

      expect(result.gpsMatch, isNull);
    });

    test('radius_meters = null → gpsMatch: null (not configured)', () async {
      service.locationConfigResult = {
        'latitude': 13.7563,
        'longitude': 100.5018,
        'radius_meters': null,
        'name': 'Test',
      };
      service.wifiConfigResult = [];

      final result = await service.verify(1);

      expect(result.gpsMatch, isNull);
    });
  });

  // ============================================================
  // BUG 8+9: GPS accuracy > radius → error
  // ============================================================
  group('BUG 8+9: GPS accuracy check', () {
    test('accuracy > radius → error "ตำแหน่งไม่แม่นยำพอ"', () async {
      service.locationConfigResult = createGpsConfig(radius: 100);
      service.wifiConfigResult = [];
      // accuracy 1500m (Approximate Location) > radius 100m
      service.currentPosition = createPosition(accuracy: 1500);

      final result = await service.verify(1);

      expect(result.gpsMatch, isFalse);
      expect(result.gpsError, contains('แม่นยำ'));
    });

    test('accuracy <= radius → ผ่านปกติ (ตรวจระยะทาง)', () async {
      service.locationConfigResult = createGpsConfig(radius: 100);
      service.wifiConfigResult = [];
      service.currentPosition = createPosition(accuracy: 10); // ดี
      service.distanceResult = 50.0;

      final result = await service.verify(1);

      expect(result.gpsMatch, isTrue);
      expect(result.distanceMeters, equals(50.0));
    });
  });

  // ============================================================
  // BUG 11: Mock GPS detected → block
  // ============================================================
  group('BUG 11: Mock GPS detection', () {
    test('isMocked = true → block with error', () async {
      service.locationConfigResult = createGpsConfig(radius: 100);
      service.wifiConfigResult = [];
      service.currentPosition = createPosition(isMocked: true);

      final result = await service.verify(1);

      expect(result.gpsMatch, isFalse);
      expect(result.gpsError, contains('จำลองตำแหน่ง'));
    });

    test('isMocked = false → ผ่านปกติ', () async {
      service.locationConfigResult = createGpsConfig(radius: 100);
      service.wifiConfigResult = [];
      service.currentPosition = createPosition(isMocked: false);
      service.distanceResult = 50.0;

      final result = await service.verify(1);

      expect(result.gpsMatch, isTrue);
    });
  });

  // ============================================================
  // BUG 12: Android "<unknown ssid>" → treated as null
  // ============================================================
  group('BUG 12: Android unknown ssid', () {
    test('<unknown ssid> → treated as null (not connected)', () async {
      service.wifiConfigResult = createWifiConfigs();
      service.locationConfigResult = null;
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => '<unknown ssid>');

      final result = await service.verify(1);

      expect(result.wifiMatch, isFalse);
      expect(result.currentSsid, isNull,
          reason: '<unknown ssid> ควรถูก treat เป็น null');
    });

    test('empty string → treated as null (not connected)', () async {
      service.wifiConfigResult = createWifiConfigs();
      service.locationConfigResult = null;
      when(() => mockNetworkInfo.getWifiName())
          .thenAnswer((_) async => '');

      final result = await service.verify(1);

      expect(result.wifiMatch, isFalse);
      expect(result.currentSsid, isNull,
          reason: 'empty string ควรถูก treat เป็น null');
    });
  });

  // ============================================================
  // BUG 13: radius_meters <= 0 → treated as not configured
  // ============================================================
  group('BUG 13: radius_meters invalid', () {
    test('radius = 0 → gpsMatch: null (not configured)', () async {
      service.locationConfigResult = createGpsConfig(radius: 0);
      service.wifiConfigResult = [];

      final result = await service.verify(1);

      expect(result.gpsMatch, isNull);
    });

    test('radius = -50 → gpsMatch: null (not configured)', () async {
      service.locationConfigResult = createGpsConfig(radius: -50);
      service.wifiConfigResult = [];

      final result = await service.verify(1);

      expect(result.gpsMatch, isNull);
    });
  });

  // ============================================================
  // BUG 15: Supabase fetch timeout → specific error message
  // ============================================================
  group('BUG 15: Supabase fetch timeout', () {
    test('fetchConfig timeout → error "นานเกินไป"', () async {
      // Arrange — จำลอง TimeoutException จาก Future.wait.timeout()
      service.fetchConfigException = TimeoutException('Supabase timeout');

      final result = await service.verify(1);

      expect(result.gpsMatch, isFalse);
      expect(result.gpsError, contains('นานเกินไป'));
      expect(result.wifiMatch, isFalse);
      expect(result.wifiError, contains('นานเกินไป'));
    });
  });
}
