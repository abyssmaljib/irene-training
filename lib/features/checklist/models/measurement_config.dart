/// Configuration สำหรับ measurement tasks
/// Match ด้วย taskType ของ task (ไม่ใช่ title)
/// taskType ที่รองรับ: 'ชั่งน้ำหนัก', 'วัดส่วนสูง'
class MeasurementConfig {
  /// ประเภทการวัด ตรงกับ measurement_type ใน resident_measurements table
  final String measurementType;

  /// หน่วยวัด เช่น 'kg', 'cm'
  final String unit;

  /// ข้อความแสดงใน dialog เช่น 'น้ำหนัก (กก.)'
  final String label;

  /// ค่าต่ำสุดที่สมเหตุสมผล — ถ้าต่ำกว่านี้จะเตือน (soft validation)
  final double min;

  /// ค่าสูงสุดที่สมเหตุสมผล — ถ้าสูงกว่านี้จะเตือน (soft validation)
  final double max;

  /// placeholder สำหรับ TextField
  final String placeholder;

  const MeasurementConfig({
    required this.measurementType,
    required this.unit,
    required this.label,
    required this.min,
    required this.max,
    required this.placeholder,
  });
}

/// Map จาก taskType → MeasurementConfig
const Map<String, MeasurementConfig> measurementTaskTypes = {
  'ชั่งน้ำหนัก': MeasurementConfig(
    measurementType: 'weight',
    unit: 'kg',
    label: 'น้ำหนัก (กก.)',
    min: 20,
    max: 200,
    placeholder: 'เช่น 65.5',
  ),
  'วัดส่วนสูง': MeasurementConfig(
    measurementType: 'height',
    unit: 'cm',
    label: 'ส่วนสูง (ซม.)',
    min: 50,
    max: 220,
    placeholder: 'เช่น 165',
  ),
};

/// ตรวจ taskType ว่าเป็น measurement task หรือไม่
/// return MeasurementConfig ถ้าใช่, null ถ้าไม่ใช่
MeasurementConfig? getMeasurementConfig(String? taskType) {
  if (taskType == null || taskType.isEmpty) return null;
  return measurementTaskTypes[taskType];
}
