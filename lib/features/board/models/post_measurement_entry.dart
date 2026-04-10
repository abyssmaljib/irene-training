import '../../../features/checklist/models/measurement_config.dart';

/// ข้อมูล measurement 1 รายการที่แนบกับ post
/// เช่น น้ำหนัก 65.5 kg พร้อมรูปตาชั่ง
class PostMeasurementEntry {
  /// ประเภทการวัด เช่น 'weight', 'height', 'dtx', 'insulin'
  final String measurementType;

  /// Config ของ measurement (min/max/unit/label)
  final MeasurementConfig config;

  /// ค่าที่กรอก (null = ยังไม่กรอก)
  final double? value;

  /// URL รูปถ่าย (เช่น รูปตาชั่ง, เครื่องวัด)
  final String? photoUrl;

  /// กำลัง upload รูปอยู่หรือไม่
  final bool isUploadingPhoto;

  const PostMeasurementEntry({
    required this.measurementType,
    required this.config,
    this.value,
    this.photoUrl,
    this.isUploadingPhoto = false,
  });

  /// ตรวจว่ามีค่าที่กรอกแล้วหรือยัง (> 0)
  bool get hasValue => value != null && value! > 0;

  /// ตรวจว่ามีรูปถ่ายหรือไม่
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  PostMeasurementEntry copyWith({
    String? measurementType,
    MeasurementConfig? config,
    double? value,
    bool clearValue = false,
    String? photoUrl,
    bool clearPhotoUrl = false,
    bool? isUploadingPhoto,
  }) {
    return PostMeasurementEntry(
      measurementType: measurementType ?? this.measurementType,
      config: config ?? this.config,
      value: clearValue ? null : (value ?? this.value),
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
    );
  }

  @override
  String toString() =>
      'PostMeasurementEntry($measurementType: $value ${config.unit})';
}
