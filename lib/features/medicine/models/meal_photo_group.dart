import 'medicine_summary.dart';
import 'med_log.dart';
import 'med_error_log.dart';

/// สถานะของมื้อยา
enum MealPhotoStatus {
  /// ไม่มียาในมื้อนี้
  noMedicine,

  /// มียาแต่ยังไม่ได้จัดยา (ไม่มีรูป 2C)
  pending,

  /// จัดยาแล้ว แต่ยังไม่ได้ให้ยา (มี 2C แต่ไม่มี 3C)
  arranged,

  /// ให้ยาแล้ว (มี 3C)
  completed,
}

/// กลุ่มรูปยาแบ่งตามมื้อ
class MealPhotoGroup {
  /// Key สำหรับ identify มื้อ (เช่น "morning_before", "noon_after", "bedtime")
  final String mealKey;

  /// ชื่อมื้อสำหรับแสดง (เช่น "เช้า (ก่อนอาหาร)")
  final String label;

  /// รายการยาในมื้อนี้
  final List<MedicineSummary> medicines;

  /// Log การจัดยา/ให้ยา (ถ้ามี)
  final MedLog? medLog;

  /// สถานะการตรวจสอบรูป 2C จากหัวหน้าเวร
  final NurseMarkStatus nurseMark2C;

  /// สถานะการตรวจสอบรูป 3C จากหัวหน้าเวร
  final NurseMarkStatus nurseMark3C;

  /// ชื่อผู้ตรวจสอบรูป 2C (format: "ชื่อจริง (ชื่อเล่น)")
  final String? reviewer2CName;

  /// ชื่อผู้ตรวจสอบรูป 3C (format: "ชื่อจริง (ชื่อเล่น)")
  final String? reviewer3CName;

  MealPhotoGroup({
    required this.mealKey,
    required this.label,
    required this.medicines,
    this.medLog,
    this.nurseMark2C = NurseMarkStatus.none,
    this.nurseMark3C = NurseMarkStatus.none,
    this.reviewer2CName,
    this.reviewer3CName,
  });

  /// สถานะของมื้อนี้
  MealPhotoStatus get status {
    if (medicines.isEmpty) {
      return MealPhotoStatus.noMedicine;
    }
    if (medLog?.picture3CUrl != null && medLog!.picture3CUrl!.isNotEmpty) {
      return MealPhotoStatus.completed;
    }
    if (medLog?.picture2CUrl != null && medLog!.picture2CUrl!.isNotEmpty) {
      return MealPhotoStatus.arranged;
    }
    return MealPhotoStatus.pending;
  }

  /// จำนวนยาในมื้อนี้
  int get medicineCount => medicines.length;

  /// มียาในมื้อนี้หรือไม่
  bool get hasMedicines => medicines.isNotEmpty;

  /// จัดยาแล้วหรือยัง
  bool get isArranged =>
      status == MealPhotoStatus.arranged ||
      status == MealPhotoStatus.completed;

  /// ให้ยาแล้วหรือยัง
  bool get isCompleted => status == MealPhotoStatus.completed;
}

/// รายการมื้อยาทั้งหมด (7 มื้อ)
class MealSlots {
  static const morningBefore = 'morning_before';
  static const morningAfter = 'morning_after';
  static const noonBefore = 'noon_before';
  static const noonAfter = 'noon_after';
  static const eveningBefore = 'evening_before';
  static const eveningAfter = 'evening_after';
  static const bedtime = 'bedtime';

  /// รายการมื้อทั้งหมดตามลำดับ
  static const List<String> allSlots = [
    morningBefore,
    morningAfter,
    noonBefore,
    noonAfter,
    eveningBefore,
    eveningAfter,
    bedtime,
  ];

  /// ชื่อมื้อสำหรับแสดง
  static String getLabel(String slot) {
    switch (slot) {
      case morningBefore:
        return 'เช้า (ก่อนอาหาร)';
      case morningAfter:
        return 'เช้า (หลังอาหาร)';
      case noonBefore:
        return 'กลางวัน (ก่อนอาหาร)';
      case noonAfter:
        return 'กลางวัน (หลังอาหาร)';
      case eveningBefore:
        return 'เย็น (ก่อนอาหาร)';
      case eveningAfter:
        return 'เย็น (หลังอาหาร)';
      case bedtime:
        return 'ก่อนนอน';
      default:
        return slot;
    }
  }

  /// ชื่อสั้นของมื้อ
  static String getShortLabel(String slot) {
    switch (slot) {
      case morningBefore:
        return 'เช้า-ก่อน';
      case morningAfter:
        return 'เช้า-หลัง';
      case noonBefore:
        return 'กลางวัน-ก่อน';
      case noonAfter:
        return 'กลางวัน-หลัง';
      case eveningBefore:
        return 'เย็น-ก่อน';
      case eveningAfter:
        return 'เย็น-หลัง';
      case bedtime:
        return 'ก่อนนอน';
      default:
        return slot;
    }
  }

  /// แปลงจาก bldb + beforeAfter เป็น slot key
  static String toSlotKey(String bldb, String beforeAfter) {
    switch (bldb) {
      case 'เช้า':
        return beforeAfter == 'ก่อนอาหาร' ? morningBefore : morningAfter;
      case 'กลางวัน':
        return beforeAfter == 'ก่อนอาหาร' ? noonBefore : noonAfter;
      case 'เย็น':
        return beforeAfter == 'ก่อนอาหาร' ? eveningBefore : eveningAfter;
      case 'ก่อนนอน':
        return bedtime;
      default:
        return bldb;
    }
  }

  /// ข้อมูล bldb และ beforeAfter จาก slot key
  static (String bldb, String beforeAfter) fromSlotKey(String slot) {
    switch (slot) {
      case morningBefore:
        return ('เช้า', 'ก่อนอาหาร');
      case morningAfter:
        return ('เช้า', 'หลังอาหาร');
      case noonBefore:
        return ('กลางวัน', 'ก่อนอาหาร');
      case noonAfter:
        return ('กลางวัน', 'หลังอาหาร');
      case eveningBefore:
        return ('เย็น', 'ก่อนอาหาร');
      case eveningAfter:
        return ('เย็น', 'หลังอาหาร');
      case bedtime:
        return ('ก่อนนอน', '');
      default:
        return ('', '');
    }
  }
}
