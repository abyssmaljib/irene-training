import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_service.dart';

/// Service สำหรับตรวจสอบและบังคับ update app
///
/// ทำงานโดย:
/// 1. ดึง app_version (minimum build number) จาก nursinghomes table
/// 2. เทียบกับ buildNumber ปัจจุบันของ app
/// 3. ถ้า buildNumber < app_version จะ return true (ต้อง update)
class ForceUpdateService {
  // Singleton pattern
  ForceUpdateService._();
  static final ForceUpdateService instance = ForceUpdateService._();

  // Store URLs
  // iOS: ใช้ TestFlight link (เปลี่ยนเป็น App Store link เมื่อ app ขึ้น store แล้ว)
  // Android: ใช้ Play Store link
  static const String _appStoreUrl =
      'https://testflight.apple.com/join/Ny9rQQk8';
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.giantkumakuma.irene';

  /// ตรวจสอบว่า user ต้อง update app หรือไม่
  ///
  /// Return: true ถ้าต้อง update, false ถ้าไม่ต้อง
  ///
  /// Logic:
  /// - ยกเว้น version 1.0.0 (dev/debug build) ไม่ต้องเช็ค
  /// - ดึง nursinghome_id ของ user จาก user_info
  /// - ดึง app_version จาก nursinghomes table
  /// - เทียบกับ buildNumber ปัจจุบัน
  /// - ถ้า buildNumber < app_version → ต้อง update
  Future<bool> isUpdateRequired() async {
    try {
      // 0. ดึง version ปัจจุบัน และยกเว้น 1.0.0 (dev/debug build)
      final packageInfo = await PackageInfo.fromPlatform();
      debugPrint('🔍 ForceUpdate: version=${packageInfo.version}, buildNumber=${packageInfo.buildNumber}');

      if (packageInfo.version == '1.0.0') {
        debugPrint('🔍 ForceUpdate: ❌ SKIP - Version 1.0.0 = dev build');
        return false;
      }

      // 1. ดึง nursinghome_id ของ user
      final nursinghomeId = await UserService().getNursinghomeId();
      debugPrint('🔍 ForceUpdate: nursinghomeId=$nursinghomeId');

      if (nursinghomeId == null) {
        debugPrint('🔍 ForceUpdate: ❌ SKIP - nursinghomeId เป็น null');
        return false;
      }

      // 2. ดึง app_version จาก nursinghomes table
      final response = await Supabase.instance.client
          .from('nursinghomes')
          .select('app_version')
          .eq('id', nursinghomeId)
          .maybeSingle();

      debugPrint('🔍 ForceUpdate: DB response=$response');

      final minBuildNumber = response?['app_version'] as int?;
      debugPrint('🔍 ForceUpdate: app_version จาก DB=$minBuildNumber');

      if (minBuildNumber == null || minBuildNumber == 0) {
        debugPrint('🔍 ForceUpdate: ❌ SKIP - app_version เป็น null หรือ 0 (ไม่บังคับ update)');
        return false;
      }

      // 3. ดึง buildNumber ปัจจุบันของ app
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint('🔍 ForceUpdate: currentBuild=$currentBuildNumber vs requiredBuild=$minBuildNumber');

      // 4. เทียบ version
      final needsUpdate = currentBuildNumber < minBuildNumber;
      debugPrint('🔍 ForceUpdate: ${needsUpdate ? "✅ ต้อง UPDATE!" : "✅ ไม่ต้อง update (version ใหม่พอ)"}');

      return needsUpdate;
    } catch (e, stackTrace) {
      debugPrint('🔍 ForceUpdate: ❌ ERROR: $e');
      debugPrint('🔍 ForceUpdate: StackTrace: $stackTrace');
      return false;
    }
  }

  /// เปิด App Store หรือ Play Store ตาม platform
  ///
  /// - iOS: เปิด App Store
  /// - Android: เปิด Play Store
  /// - Web/Desktop: ไม่ทำอะไร (return false)
  Future<bool> openStore() async {
    String? storeUrl;

    // เลือก URL ตาม platform
    if (!kIsWeb) {
      try {
        if (Platform.isIOS) {
          storeUrl = _appStoreUrl;
        } else if (Platform.isAndroid) {
          storeUrl = _playStoreUrl;
        }
      } catch (e) {
        debugPrint('ForceUpdateService: Platform detection error: $e');
      }
    }

    if (storeUrl == null) {
      debugPrint('ForceUpdateService: Store URL not available for this platform');
      return false;
    }

    try {
      final uri = Uri.parse(storeUrl);

      // เปิด URL ใน browser/store app
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      debugPrint('ForceUpdateService: Launched store: $launched');
      return launched;
    } catch (e) {
      debugPrint('ForceUpdateService: Failed to open store: $e');
      return false;
    }
  }

  /// ดึงข้อมูล version ปัจจุบันสำหรับแสดงใน dialog
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version} (${packageInfo.buildNumber})';
    } catch (e) {
      return 'Unknown';
    }
  }
}
