/// Model สำหรับประวัติการใช้ยา (med_history table)
///
/// บันทึกการเปลี่ยนแปลงยาของ resident รวมถึง:
/// - วันเริ่มและวันหยุดให้ยา
/// - จำนวนยาที่ reconcile (ยาคงเหลือ)
/// - หมายเหตุและการตั้งค่าใหม่
class MedHistory {
  final int id;
  final DateTime createdAt;

  // Foreign Key
  final int medListId;      // FK to medicine_list

  // ช่วงเวลาการให้ยา
  final DateTime onDate;    // วันที่เริ่มให้ยา
  final DateTime? offDate;  // วันที่หยุดให้ยา (null = ให้ต่อเนื่อง)

  // ข้อมูลเพิ่มเติม
  final String? note;       // หมายเหตุ
  final String? userId;     // UUID ของ user ที่บันทึก
  final double? reconcile;  // จำนวนยาคงเหลือ (สำหรับคำนวณวันที่ยาจะหมด)
  final String? newSetting; // ข้อมูล setting ใหม่ (JSON string)

  const MedHistory({
    required this.id,
    required this.createdAt,
    required this.medListId,
    required this.onDate,
    this.offDate,
    this.note,
    this.userId,
    this.reconcile,
    this.newSetting,
  });

  /// สร้างจาก JSON (Supabase response)
  factory MedHistory.fromJson(Map<String, dynamic> json) {
    return MedHistory(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      medListId: json['med_list_id'] as int,
      onDate: _parseDate(json['on_date']),
      offDate: json['off_date'] != null ? _parseDate(json['off_date']) : null,
      note: json['note'] as String?,
      userId: json['user_id'] as String?,
      reconcile: (json['reconcile'] as num?)?.toDouble(),
      newSetting: json['new_setting'] as String?,
    );
  }

  /// Helper function แปลง date string เป็น DateTime
  static DateTime _parseDate(dynamic value) {
    if (value is String) {
      // รองรับทั้ง ISO format และ date-only format
      return DateTime.parse(value);
    }
    return DateTime.now();
  }

  /// แปลงเป็น JSON สำหรับส่งไป Supabase
  Map<String, dynamic> toJson() {
    return {
      'med_list_id': medListId,
      'on_date': _formatDate(onDate),
      if (offDate != null) 'off_date': _formatDate(offDate!),
      if (note != null) 'note': note,
      if (userId != null) 'user_id': userId,
      if (reconcile != null) 'reconcile': reconcile,
      if (newSetting != null) 'new_setting': newSetting,
    };
  }

  /// Helper function แปลง DateTime เป็น date string (YYYY-MM-DD)
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ==========================================
  // Helper Getters
  // ==========================================

  /// ตรวจสอบว่ายังใช้ยาอยู่หรือไม่
  bool get isActive {
    if (offDate == null) return true; // ไม่มี off date = ให้ต่อเนื่อง
    return offDate!.isAfter(DateTime.now());
  }

  /// ตรวจสอบว่าเป็นยาให้ต่อเนื่องหรือไม่
  bool get isContinuous => offDate == null;

  /// จำนวนวันที่ให้ยา
  int get daysDuration {
    final end = offDate ?? DateTime.now();
    return end.difference(onDate).inDays;
  }

  /// ข้อความแสดงช่วงเวลา: "01/01/2026 - 31/01/2026" หรือ "01/01/2026 - ต่อเนื่อง"
  String get periodDisplayText {
    final start = _formatDisplayDate(onDate);
    if (offDate == null) {
      return '$start - ต่อเนื่อง';
    }
    return '$start - ${_formatDisplayDate(offDate!)}';
  }

  /// Helper function แปลง DateTime เป็น display string (DD/MM/YYYY)
  static String _formatDisplayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// ข้อความสถานะ: "ใช้อยู่", "หยุดแล้ว", "รอเริ่ม"
  String get statusText {
    final now = DateTime.now();
    if (onDate.isAfter(now)) return 'รอเริ่ม';
    if (isActive) return 'ใช้อยู่';
    return 'หยุดแล้ว';
  }

  /// copyWith สำหรับสร้าง instance ใหม่
  MedHistory copyWith({
    int? id,
    DateTime? createdAt,
    int? medListId,
    DateTime? onDate,
    DateTime? offDate,
    String? note,
    String? userId,
    double? reconcile,
    String? newSetting,
  }) {
    return MedHistory(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      medListId: medListId ?? this.medListId,
      onDate: onDate ?? this.onDate,
      offDate: offDate ?? this.offDate,
      note: note ?? this.note,
      userId: userId ?? this.userId,
      reconcile: reconcile ?? this.reconcile,
      newSetting: newSetting ?? this.newSetting,
    );
  }

  @override
  String toString() =>
      'MedHistory(id: $id, medListId: $medListId, onDate: $onDate, offDate: $offDate)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedHistory && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
