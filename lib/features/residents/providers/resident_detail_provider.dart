import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/resident_detail.dart';
import '../models/vital_sign.dart';
import '../services/resident_detail_service.dart';

/// Provider สำหรับ ResidentDetailService
final residentDetailServiceProvider = Provider<ResidentDetailService>((ref) {
  return ResidentDetailService.instance;
});

/// Provider สำหรับดึงข้อมูล Resident ตาม ID
final residentDetailProvider =
    FutureProvider.family<ResidentDetail?, int>((ref, residentId) async {
  final service = ref.watch(residentDetailServiceProvider);
  return service.getResidentById(residentId);
});

/// Provider สำหรับดึง Vital Sign ล่าสุด
final latestVitalSignProvider =
    FutureProvider.family<VitalSign?, int>((ref, residentId) async {
  final service = ref.watch(residentDetailServiceProvider);
  return service.getLatestVitalSign(residentId);
});

/// Provider สำหรับดึง Vital Sign History (สำหรับ chart - Future use)
final vitalSignHistoryProvider =
    FutureProvider.family<List<VitalSign>, int>((ref, residentId) async {
  final service = ref.watch(residentDetailServiceProvider);
  return service.getVitalSignHistory(residentId);
});

/// Provider สำหรับดึงรายการโรคประจำตัว
final underlyingDiseasesProvider =
    FutureProvider.family<List<String>, int>((ref, residentId) async {
  final service = ref.watch(residentDetailServiceProvider);
  return service.getUnderlyingDiseases(residentId);
});

/// Provider สำหรับ selected view (Care, Clinical, Info)
enum DetailViewType { care, clinical, info }

final selectedViewProvider = StateProvider<DetailViewType>((ref) {
  return DetailViewType.care; // Default to Care Dashboard
});

/// Provider สำหรับ highlight underlying diseases section
/// เมื่อ user กด "ดูเพิ่มเติม" จาก header
final highlightUnderlyingDiseasesProvider = StateProvider<bool>((ref) {
  return false;
});
