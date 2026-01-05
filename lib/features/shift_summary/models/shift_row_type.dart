/// Row types for shift detail popup
enum ShiftRowType {
  /// Normal shift (isManualAddDeduct == false)
  /// - Regular clock in/out record
  normal,

  /// Manual add/deduct without DD (isManualAddDeduct == true && ddRecordId == null)
  /// - Special records like absence, sick leave, additional pay
  manualAddDeduct,

  /// DD record (isManualAddDeduct == true && ddRecordId != null)
  /// - Doctor/Duty records that require post submission
  ddRecord,
}
