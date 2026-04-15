/// ข้อย่อยของหัวข้อประเมิน (เช่น "ชั่วโมงนอนรวม" ภายใต้ "การนอนหลับ")
/// โหลดจาก Report_Sub_Item table
class AssessmentSubItem {
  /// Report_Sub_Item.id
  final int subItemId;

  /// ชื่อข้อย่อย (เช่น "ชั่วโมงนอนรวม", "ความต่อเนื่อง")
  final String name;

  /// คำอธิบาย (optional)
  final String? description;

  /// ตัวเลือก 1-5 เรียงตาม scale
  /// เช่น ["น้อยกว่า 3 ชม.", "3-5 ชม.", "5-7 ชม.", "7-8 ชม.", "มากกว่า 8 ชม."]
  final List<String> choices;

  /// URL รูปตัวอย่างสำหรับแต่ละ choice (เรียงตาม scale 1-5)
  /// null ถ้า choice นั้นไม่มีรูปตัวอย่าง
  final List<String?> representUrls;

  /// ลำดับการแสดงผล
  final int sortOrder;

  const AssessmentSubItem({
    required this.subItemId,
    required this.name,
    this.description,
    required this.choices,
    this.representUrls = const [],
    required this.sortOrder,
  });
}

/// หัวข้อประเมิน 1 หัวข้อ (เช่น "อารมณ์", "การนอนหลับ")
/// โหลดจาก Task_Report_Subject → Report_Subject → Report_Choice
/// ถ้ามี sub-items → choices ว่าง, ใช้ subItems แทน
class AssessmentSubject {
  /// Report_Subject.id
  final int subjectId;

  /// ชื่อหัวข้อ (เช่น "อารมณ์", "การนอนหลับ")
  final String subjectName;

  /// คำอธิบายหัวข้อ (optional)
  final String? subjectDescription;

  /// ตัวเลือก 1-5 เรียงตาม scale (สำหรับ legacy subjects ที่ไม่มี sub-items)
  /// เช่น ["แย่มาก", "แย่", "ปานกลาง", "ดี", "ดีมาก"]
  /// ว่างถ้า subject มี sub-items
  final List<String> choices;

  /// URL รูปตัวอย่างสำหรับแต่ละ choice (เรียงตาม scale 1-5)
  /// ใช้กับ legacy subjects เท่านั้น (sub-item subjects เก็บ representUrls ใน subItems)
  final List<String?> representUrls;

  /// ข้อย่อย (ถ้ามี) — เช่น การนอน → [ชั่วโมง, ความต่อเนื่อง, ความสดชื่น]
  /// ว่างถ้าเป็น legacy subject (ไม่มี sub-items)
  final List<AssessmentSubItem> subItems;

  /// วิธีคิดคะแนนรวมจาก sub-items
  /// 'none' = ไม่มี sub-items (ใช้ choices โดยตรง)
  /// 'average' = เฉลี่ยทุก sub-item
  /// 'sum' = รวมคะแนน
  /// 'worst' = ใช้ค่าต่ำสุด
  final String scoringMethod;

  const AssessmentSubject({
    required this.subjectId,
    required this.subjectName,
    this.subjectDescription,
    required this.choices,
    this.representUrls = const [],
    this.subItems = const [],
    this.scoringMethod = 'none',
  });

  /// มี sub-items หรือไม่ — ถ้ามีจะใช้ UI แบบ grouped
  bool get hasSubItems => subItems.isNotEmpty;

  /// จำนวน "items" ที่ต้องกด — ถ้าไม่มี sub-items = 1, ถ้ามี = จำนวน sub-items
  int get totalRatingSlots => hasSubItems ? subItems.length : 1;
}

/// ผลการประเมิน 1 รายการ (อาจเป็นของ subject หรือ sub-item)
class AssessmentRating {
  /// Report_Subject.id — หัวข้อที่ประเมิน
  final int subjectId;

  /// Report_Sub_Item.id — ข้อย่อยที่ประเมิน (null = legacy subject ไม่มี sub-items)
  final int? subItemId;

  /// คะแนน 1-5 (scale value, ไม่ใช่ Report_Choice.id)
  final int rating;

  /// หมายเหตุเพิ่มเติม (optional)
  final String? description;

  const AssessmentRating({
    required this.subjectId,
    this.subItemId,
    required this.rating,
    this.description,
  });
}
