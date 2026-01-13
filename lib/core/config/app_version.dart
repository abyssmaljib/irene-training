/// App Version Configuration
/// ใช้สำหรับเปรียบเทียบ version เพื่อแสดง What's New dialog
///
/// หมายเหตุ: ต้อง sync กับ version ใน pubspec.yaml
/// หรือใช้ package_info_plus เพื่อดึง version อัตโนมัติในอนาคต
class AppVersion {
  /// Current app version (format: major.minor.patch)
  /// ต้องอัปเดตทุกครั้งที่มี release ใหม่
  static const String current = '1.0.0';

  /// เปรียบเทียบ version strings
  /// Returns true ถ้า [version1] ใหม่กว่า [version2]
  ///
  /// ตัวอย่าง:
  /// - isNewerVersion('1.0.1', '1.0.0') → true
  /// - isNewerVersion('1.1.0', '1.0.9') → true
  /// - isNewerVersion('2.0.0', '1.9.9') → true
  /// - isNewerVersion('1.0.0', '1.0.0') → false
  static bool isNewerVersion(String version1, String version2) {
    // แปลง version string เป็น list ของตัวเลข
    // เช่น '1.0.5' → [1, 0, 5]
    final parts1 = version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // เปรียบเทียบทีละส่วน (major → minor → patch)
    for (int i = 0; i < parts1.length && i < parts2.length; i++) {
      if (parts1[i] > parts2[i]) return true;
      if (parts1[i] < parts2[i]) return false;
    }

    // ถ้าเท่ากันทุก part แต่ version1 มี parts มากกว่า
    // เช่น '1.0.0.1' vs '1.0.0' → version1 ใหม่กว่า
    return parts1.length > parts2.length;
  }
}
