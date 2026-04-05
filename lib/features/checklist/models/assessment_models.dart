/// หัวข้อประเมิน 1 หัวข้อ (เช่น "อารมณ์", "การเคลื่อนไหว")
/// โหลดจาก Task_Report_Subject → Report_Subject → Report_Choice
class AssessmentSubject {
  /// Report_Subject.id
  final int subjectId;

  /// ชื่อหัวข้อ (เช่น "อารมณ์", "นอนหลับ")
  final String subjectName;

  /// คำอธิบายหัวข้อ (optional)
  final String? subjectDescription;

  /// ตัวเลือก 1-5 เรียงตาม scale
  /// เช่น ["แย่มาก", "แย่", "ปานกลาง", "ดี", "ดีมาก"]
  final List<String> choices;

  const AssessmentSubject({
    required this.subjectId,
    required this.subjectName,
    this.subjectDescription,
    required this.choices,
  });
}

/// ผลการประเมิน 1 หัวข้อ
class AssessmentRating {
  /// Report_Subject.id — หัวข้อที่ประเมิน
  final int subjectId;

  /// คะแนน 1-5 (scale value, ไม่ใช่ Report_Choice.id)
  final int rating;

  /// หมายเหตุเพิ่มเติม (optional)
  final String? description;

  const AssessmentRating({
    required this.subjectId,
    required this.rating,
    this.description,
  });
}
