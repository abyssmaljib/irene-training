import 'dart:convert';

/// Model สำหรับเก็บ draft ของ post ที่ยังไม่ได้โพส
/// ใช้ SharedPreferences เก็บเป็น JSON string
class PostDraft {
  /// หัวข้อโพส (Advanced mode only)
  final String? title;

  /// เนื้อหาโพส
  final String text;

  /// Tag ที่เลือก
  final int? tagId;
  final String? tagName;
  final String? tagEmoji;
  final String? tagHandoverMode;

  /// Toggle states
  final bool isHandover;
  final bool sendToFamily;

  /// Resident ที่เลือก
  final int? residentId;
  final String? residentName;

  /// Paths ของไฟล์ที่เลือก (local file paths)
  final List<String> imagePaths;
  final String? videoPath;

  /// เวลาที่บันทึก draft
  final DateTime savedAt;

  /// บอกว่า draft นี้มาจาก Advanced mode หรือไม่
  /// เพื่อ restore ไปหน้าที่ถูกต้อง
  final bool isAdvanced;

  const PostDraft({
    this.title,
    required this.text,
    this.tagId,
    this.tagName,
    this.tagEmoji,
    this.tagHandoverMode,
    this.isHandover = false,
    this.sendToFamily = false,
    this.residentId,
    this.residentName,
    this.imagePaths = const [],
    this.videoPath,
    required this.savedAt,
    this.isAdvanced = false,
  });

  /// ตรวจสอบว่า draft มีข้อมูลที่ควรเก็บหรือไม่
  /// ถ้าไม่มีข้อมูลเลย ไม่ต้องบันทึก
  bool get hasContent =>
      text.trim().isNotEmpty ||
      (title?.trim().isNotEmpty ?? false) ||
      tagId != null ||
      residentId != null ||
      imagePaths.isNotEmpty ||
      videoPath != null;

  /// แปลงเป็น JSON Map
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'text': text,
      'tagId': tagId,
      'tagName': tagName,
      'tagEmoji': tagEmoji,
      'tagHandoverMode': tagHandoverMode,
      'isHandover': isHandover,
      'sendToFamily': sendToFamily,
      'residentId': residentId,
      'residentName': residentName,
      'imagePaths': imagePaths,
      'videoPath': videoPath,
      'savedAt': savedAt.toIso8601String(),
      'isAdvanced': isAdvanced,
    };
  }

  /// สร้างจาก JSON Map
  factory PostDraft.fromJson(Map<String, dynamic> json) {
    return PostDraft(
      title: json['title'] as String?,
      text: json['text'] as String? ?? '',
      tagId: json['tagId'] as int?,
      tagName: json['tagName'] as String?,
      tagEmoji: json['tagEmoji'] as String?,
      tagHandoverMode: json['tagHandoverMode'] as String?,
      isHandover: json['isHandover'] as bool? ?? false,
      sendToFamily: json['sendToFamily'] as bool? ?? false,
      residentId: json['residentId'] as int?,
      residentName: json['residentName'] as String?,
      imagePaths: (json['imagePaths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      videoPath: json['videoPath'] as String?,
      savedAt: json['savedAt'] != null
          ? DateTime.parse(json['savedAt'] as String)
          : DateTime.now(),
      isAdvanced: json['isAdvanced'] as bool? ?? false,
    );
  }

  /// แปลงเป็น JSON string สำหรับเก็บใน SharedPreferences
  String toJsonString() => jsonEncode(toJson());

  /// สร้างจาก JSON string
  factory PostDraft.fromJsonString(String jsonString) {
    return PostDraft.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Copy with - สำหรับ update บาง field
  PostDraft copyWith({
    String? title,
    String? text,
    int? tagId,
    String? tagName,
    String? tagEmoji,
    String? tagHandoverMode,
    bool? isHandover,
    bool? sendToFamily,
    int? residentId,
    String? residentName,
    List<String>? imagePaths,
    String? videoPath,
    DateTime? savedAt,
    bool? isAdvanced,
  }) {
    return PostDraft(
      title: title ?? this.title,
      text: text ?? this.text,
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
      tagEmoji: tagEmoji ?? this.tagEmoji,
      tagHandoverMode: tagHandoverMode ?? this.tagHandoverMode,
      isHandover: isHandover ?? this.isHandover,
      sendToFamily: sendToFamily ?? this.sendToFamily,
      residentId: residentId ?? this.residentId,
      residentName: residentName ?? this.residentName,
      imagePaths: imagePaths ?? this.imagePaths,
      videoPath: videoPath ?? this.videoPath,
      savedAt: savedAt ?? this.savedAt,
      isAdvanced: isAdvanced ?? this.isAdvanced,
    );
  }

  @override
  String toString() =>
      'PostDraft(text: ${text.length} chars, tag: $tagName, resident: $residentName, '
      'images: ${imagePaths.length}, savedAt: $savedAt, isAdvanced: $isAdvanced)';
}
