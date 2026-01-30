/// DateFormatUtils - Utility functions สำหรับ format วันที่/เวลา
/// รวม pattern ที่ซ้ำกันจากหลาย files เช่น task_card.dart, post_card.dart
///
/// ตัวอย่างการใช้งาน:
/// ```dart
/// final time = DateFormatUtils.formatTime(DateTime.now());  // "08.30 น."
/// final ago = DateFormatUtils.formatTimeAgo(createdAt);     // "5 นาทีที่แล้ว"
/// ```
class DateFormatUtils {
  /// Format เวลาเป็น "HH.mm น." (แบบไทย)
  /// แปลงเป็น local time ก่อนแสดงผล
  static String formatTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour.$minute น.';
  }

  /// Format เวลาเป็น "HH:mm" (แบบสากล)
  /// ใช้สำหรับแสดงเวลาที่ติ๊กงาน
  static String formatCompletedTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Format เวลาเป็น relative time (เช่น "5 นาทีที่แล้ว")
  /// ใช้สำหรับแสดงเวลาที่โพสต์/สร้าง
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays == 1) return 'เมื่อวาน';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';

    // Format as date
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  /// Format วันที่เป็น "d MMM yyyy" (แบบไทย)
  /// เช่น "15 ม.ค. 2024"
  static String formatThaiDate(DateTime dateTime) {
    const thaiMonths = [
      '',
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    return '${dateTime.day} ${thaiMonths[dateTime.month]} ${dateTime.year}';
  }

  /// Format วันที่เป็น "d MMM" (สั้น ไม่มีปี)
  /// เช่น "15 ม.ค."
  static String formatThaiDateShort(DateTime dateTime) {
    const thaiMonths = [
      '',
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    return '${dateTime.day} ${thaiMonths[dateTime.month]}';
  }

  /// Format วันที่และเวลา "d MMM HH:mm"
  /// เช่น "15 ม.ค. 08:30"
  static String formatThaiDateTime(DateTime dateTime) {
    final date = formatThaiDateShort(dateTime);
    final time = formatCompletedTime(dateTime);
    return '$date $time';
  }

  /// ได้ชื่อวันในสัปดาห์ (ภาษาไทย)
  static String getThaiDayName(int weekday) {
    const thaiDays = [
      '',
      'จันทร์',
      'อังคาร',
      'พุธ',
      'พฤหัสบดี',
      'ศุกร์',
      'เสาร์',
      'อาทิตย์',
    ];
    return thaiDays[weekday];
  }

  /// ได้ชื่อย่อวันในสัปดาห์ (ภาษาไทย)
  static String getThaiDayAbbr(int weekday) {
    const thaiDaysAbbr = ['', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    return thaiDaysAbbr[weekday];
  }
}
