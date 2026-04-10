/// Configuration สำหรับ measurement tasks
/// Match ด้วย taskType ของ task (ไม่ใช่ title)
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
  'DTX': MeasurementConfig(
    measurementType: 'dtx',
    unit: 'mg/dL',
    label: 'น้ำตาลในเลือด (mg/dL)',
    min: 30,
    max: 500,
    placeholder: 'เช่น 120',
  ),
  'Insulin': MeasurementConfig(
    measurementType: 'insulin',
    unit: 'units',
    label: 'อินซูลิน (units)',
    min: 0,
    max: 100,
    placeholder: 'เช่น 10',
  ),
};

/// ตรวจ taskType ว่าเป็น measurement task หรือไม่
/// return MeasurementConfig ถ้าใช่, null ถ้าไม่ใช่
MeasurementConfig? getMeasurementConfig(String? taskType) {
  if (taskType == null || taskType.isEmpty) return null;
  return measurementTaskTypes[taskType];
}

/// Map จาก measurementType → MeasurementConfig (สำหรับ post measurement)
/// ใช้เมื่อต้อง lookup config โดย measurementType แทน taskType
/// เช่น measurementConfigByType['weight'] → MeasurementConfig(weight, kg, ...)
final Map<String, MeasurementConfig> measurementConfigByType = {
  for (final config in measurementTaskTypes.values)
    config.measurementType: config,
};

/// รายการ measurement types ทั้งหมดที่ใช้ได้ใน post + FAB shortcut
/// เรียงตามลำดับที่ต้องการแสดงใน UI
const List<String> postMeasurementTypes = [
  'weight',
  'height',
  'dtx',
  'insulin',
];
