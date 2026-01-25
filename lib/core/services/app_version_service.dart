import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service สำหรับจัดการข้อมูล App Version
/// อัพเดตข้อมูล version, build number, platform ไปที่ user_info ตอน login
class AppVersionService {
  // Singleton pattern
  AppVersionService._();
  static final AppVersionService instance = AppVersionService._();

  // Cache ข้อมูล package เพื่อไม่ต้องโหลดซ้ำ
  PackageInfo? _packageInfo;

  /// ดึงข้อมูล package info (cached)
  Future<PackageInfo> getPackageInfo() async {
    // ถ้ายังไม่เคยโหลด ให้โหลดและเก็บ cache
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!;
  }

  /// ดึงชื่อ platform ปัจจุบัน
  /// Return: 'android', 'ios', 'web', 'windows', 'macos', 'linux', หรือ 'unknown'
  String getPlatformName() {
    // ตรวจสอบ web ก่อนเพราะ kIsWeb ใช้ได้ทุก platform
    if (kIsWeb) return 'web';

    // ตรวจสอบ platform อื่นๆ (ต้องไม่ใช่ web ถึงจะใช้ Platform ได้)
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (e) {
      // Platform ไม่รองรับ (เช่น web หรือ platform ใหม่)
      debugPrint('AppVersionService: Platform detection error: $e');
    }

    return 'unknown';
  }

  /// อัพเดตข้อมูล version ไปที่ user_info table
  /// เรียกใช้ตอน user login เข้า app
  Future<void> updateVersionInfo() async {
    // ดึง current user
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('AppVersionService: No user logged in, skipping version update');
      return;
    }

    try {
      // ดึงข้อมูล package
      final packageInfo = await getPackageInfo();

      // ดึงชื่อ platform
      final platform = getPlatformName();

      // เตรียมข้อมูลที่จะอัพเดต
      final versionData = {
        'appVersion': packageInfo.version, // เช่น "1.2.3"
        'buildNumber': packageInfo.buildNumber, // เช่น "45"
        'packageName': packageInfo.packageName, // เช่น "com.example.app"
        'platform': platform, // เช่น "android", "ios", "web"
      };

      // อัพเดตไปที่ user_info table
      await Supabase.instance.client
          .from('user_info')
          .update(versionData)
          .eq('id', user.id);

      debugPrint('AppVersionService: Updated version info - '
          'v${packageInfo.version}+${packageInfo.buildNumber} '
          'on $platform for user ${user.id}');
    } catch (e) {
      // ไม่ throw error เพราะไม่อยากให้ login fail แค่เพราะอัพเดต version ไม่ได้
      debugPrint('AppVersionService: Failed to update version info: $e');
    }
  }

  /// ดึง version string สำหรับแสดงใน UI
  /// Return: "1.2.3 (45)" หรือ "1.2.3" ถ้าไม่มี build number
  Future<String> getVersionString() async {
    final packageInfo = await getPackageInfo();

    if (packageInfo.buildNumber.isNotEmpty) {
      return '${packageInfo.version} (${packageInfo.buildNumber})';
    }
    return packageInfo.version;
  }
}
