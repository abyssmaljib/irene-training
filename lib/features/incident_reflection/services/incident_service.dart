// Service สำหรับจัดการ Incidents และการถอดบทเรียน
// CRUD operations กับ B_Incident table ผ่าน Supabase

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/incident.dart';
import '../models/chat_message.dart';
import '../models/reflection_pillars.dart';

/// Service สำหรับจัดการ Incidents
/// ใช้ Singleton pattern เพื่อให้มี instance เดียวทั้ง app
class IncidentService {
  // Singleton instance
  static final IncidentService instance = IncidentService._();
  IncidentService._();

  final _supabase = Supabase.instance.client;

  // Cache สำหรับ incidents
  int? _cachedNursinghomeId;
  String? _cachedUserId;
  List<Incident>? _cachedIncidents;
  DateTime? _cacheTime;
  static const _cacheMaxAge = Duration(minutes: 2);

  /// ตรวจสอบว่า cache ยังใช้ได้อยู่
  bool _isCacheValid(String userId, int nursinghomeId) {
    if (_cachedUserId != userId) return false;
    if (_cachedNursinghomeId != nursinghomeId) return false;
    if (_cachedIncidents == null) return false;
    if (_cacheTime == null) return false;
    return DateTime.now().difference(_cacheTime!) < _cacheMaxAge;
  }

  /// ล้าง cache
  void invalidateCache() {
    _cachedIncidents = null;
    _cacheTime = null;
    debugPrint('IncidentService: cache invalidated');
  }

  /// ดึง incidents ทั้งหมดที่ user เป็นเจ้าของ (staff_id contains userId)
  ///
  /// ใช้ v_incidents_with_details view ที่ join ข้อมูลผู้รายงานและ resident แล้ว
  Future<List<Incident>> getMyIncidents(
    String userId,
    int nursinghomeId, {
    bool forceRefresh = false,
  }) async {
    // ใช้ cache ถ้ายังใช้ได้
    if (!forceRefresh && _isCacheValid(userId, nursinghomeId)) {
      debugPrint(
          'getMyIncidents: using cached data (${_cachedIncidents!.length} incidents)');
      return _cachedIncidents!;
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Query จาก view พร้อม filter ที่ staff_id array contains userId
      // ใช้ cs (contains) operator สำหรับ array column
      final response = await _supabase
          .from('v_incidents_with_details')
          .select()
          .eq('nursinghome_id', nursinghomeId)
          .contains('staff_id', [userId])
          .order('created_at', ascending: false);

      stopwatch.stop();

      final incidents = (response as List)
          .map((json) => Incident.fromJson(json))
          .toList();

      // Update cache
      _cachedUserId = userId;
      _cachedNursinghomeId = nursinghomeId;
      _cachedIncidents = incidents;
      _cacheTime = DateTime.now();

      debugPrint(
          'getMyIncidents: fetched ${incidents.length} incidents in ${stopwatch.elapsedMilliseconds}ms');
      return incidents;
    } catch (e) {
      debugPrint('getMyIncidents error: $e');
      // Return cached data if available even on error
      if (_cachedIncidents != null) {
        debugPrint('getMyIncidents: returning stale cache on error');
        return _cachedIncidents!;
      }
      return [];
    }
  }

  /// ดึง incident เดียวโดย id
  Future<Incident?> getIncidentById(int incidentId) async {
    try {
      final response = await _supabase
          .from('v_incidents_with_details')
          .select()
          .eq('id', incidentId)
          .maybeSingle();

      if (response == null) return null;
      return Incident.fromJson(response);
    } catch (e) {
      debugPrint('getIncidentById error: $e');
      return null;
    }
  }

  /// เริ่มการถอดบทเรียน (update status เป็น in_progress)
  Future<bool> startReflection(int incidentId) async {
    try {
      await _supabase.from('B_Incident').update({
        'reflection_status': 'in_progress',
        'reflection_started_at': DateTime.now().toIso8601String(),
      }).eq('id', incidentId);

      invalidateCache();
      debugPrint('startReflection: incident $incidentId started');
      return true;
    } catch (e) {
      debugPrint('startReflection error: $e');
      return false;
    }
  }

  /// อัปเดต chat history
  ///
  /// บันทึกประวัติการสนทนากับ AI ลงใน B_Incident.chat_history (jsonb)
  Future<bool> updateChatHistory(
    int incidentId,
    List<ChatMessage> chatHistory,
  ) async {
    try {
      // แปลง chat messages เป็น JSON array
      final chatJson = chatHistory.map((msg) => msg.toJson()).toList();

      await _supabase.from('B_Incident').update({
        'chat_history': chatJson,
      }).eq('id', incidentId);

      debugPrint(
          'updateChatHistory: saved ${chatHistory.length} messages for incident $incidentId');
      return true;
    } catch (e) {
      debugPrint('updateChatHistory error: $e');
      return false;
    }
  }

  /// บันทึกการถอดบทเรียนที่เสร็จสมบูรณ์
  ///
  /// อัปเดต 4 Pillars และเปลี่ยน status เป็น completed
  Future<bool> completeReflection(
    int incidentId, {
    required String whyItMatters,
    required String rootCause,
    required String coreValueAnalysis,
    required List<String> violatedCoreValues,
    required String preventionPlan,
  }) async {
    try {
      await _supabase.from('B_Incident').update({
        'why_it_matters': whyItMatters,
        'root_cause': rootCause,
        'core_value_analysis': coreValueAnalysis,
        'violated_core_values': violatedCoreValues,
        'prevention_plan': preventionPlan,
        'reflection_status': 'completed',
        'reflection_completed_at': DateTime.now().toIso8601String(),
      }).eq('id', incidentId);

      invalidateCache();
      debugPrint('completeReflection: incident $incidentId completed');
      return true;
    } catch (e) {
      debugPrint('completeReflection error: $e');
      return false;
    }
  }

  /// บันทึกผลสรุปจาก AI (ReflectionSummary)
  Future<bool> saveReflectionSummary(
    int incidentId,
    ReflectionSummary summary,
  ) async {
    return completeReflection(
      incidentId,
      whyItMatters: summary.whyItMatters,
      rootCause: summary.rootCause,
      coreValueAnalysis: summary.coreValueAnalysis,
      violatedCoreValues: summary.violatedCoreValues, // เป็น List<String> อยู่แล้ว
      preventionPlan: summary.preventionPlan,
    );
  }

  /// นับจำนวน incidents ตาม reflection status
  Future<Map<ReflectionStatus, int>> getIncidentCounts(
    String userId,
    int nursinghomeId,
  ) async {
    // ใช้ cached incidents ถ้ามี
    final incidents = await getMyIncidents(userId, nursinghomeId);

    return {
      ReflectionStatus.pending: incidents
          .where((i) => i.reflectionStatus == ReflectionStatus.pending)
          .length,
      ReflectionStatus.inProgress: incidents
          .where((i) => i.reflectionStatus == ReflectionStatus.inProgress)
          .length,
      ReflectionStatus.completed: incidents
          .where((i) => i.reflectionStatus == ReflectionStatus.completed)
          .length,
    };
  }

  /// ดึง pending count อย่างเดียว (สำหรับ badge)
  Future<int> getPendingCount(String userId, int nursinghomeId) async {
    final counts = await getIncidentCounts(userId, nursinghomeId);
    return counts[ReflectionStatus.pending] ?? 0;
  }

  /// Reset ความคืบหน้าการถอดบทเรียน (กลับไป in_progress และล้าง 4 pillars)
  ///
  /// ใช้เมื่อ user ต้องการเริ่มถอดบทเรียนใหม่ตั้งแต่ต้น
  Future<bool> resetReflectionProgress(int incidentId) async {
    try {
      await _supabase.from('B_Incident').update({
        // Reset status กลับเป็น in_progress
        'reflection_status': 'in_progress',
        'reflection_completed_at': null,
        // ล้าง 4 pillars
        'why_it_matters': null,
        'root_cause': null,
        'core_value_analysis': null,
        'violated_core_values': null,
        'prevention_plan': null,
      }).eq('id', incidentId);

      invalidateCache();
      debugPrint('resetReflectionProgress: incident $incidentId reset');
      return true;
    } catch (e) {
      debugPrint('resetReflectionProgress error: $e');
      return false;
    }
  }

  /// อัพเดตเนื้อหา 4 Pillars แบบ incremental
  ///
  /// บันทึกเฉพาะ fields ที่มีค่าใหม่ (ไม่เป็น null)
  /// ใช้เมื่อ AI extract ข้อมูลได้ระหว่างสนทนา
  /// ถ้าครบ 4 Pillars จะ auto-update status เป็น 'completed' ด้วย
  Future<bool> updatePillarContent(
    int incidentId, {
    String? whyItMatters,
    String? rootCause,
    String? coreValueAnalysis,
    List<String>? violatedCoreValues,
    String? preventionPlan,
  }) async {
    try {
      // สร้าง update map เฉพาะ fields ที่มีค่า
      final updateData = <String, dynamic>{};

      if (whyItMatters != null && whyItMatters.isNotEmpty) {
        updateData['why_it_matters'] = whyItMatters;
      }
      if (rootCause != null && rootCause.isNotEmpty) {
        updateData['root_cause'] = rootCause;
      }
      if (coreValueAnalysis != null && coreValueAnalysis.isNotEmpty) {
        updateData['core_value_analysis'] = coreValueAnalysis;
      }
      if (violatedCoreValues != null && violatedCoreValues.isNotEmpty) {
        updateData['violated_core_values'] = violatedCoreValues;
      }
      if (preventionPlan != null && preventionPlan.isNotEmpty) {
        updateData['prevention_plan'] = preventionPlan;
      }

      // ถ้าไม่มีอะไรอัพเดต ก็ไม่ต้องทำอะไร
      if (updateData.isEmpty) {
        debugPrint('updatePillarContent: no content to update');
        return true;
      }

      await _supabase.from('B_Incident').update(updateData).eq('id', incidentId);

      invalidateCache();
      debugPrint(
          'updatePillarContent: updated ${updateData.keys.join(', ')} for incident $incidentId');

      // ตรวจสอบว่าครบ 4 Pillars หรือยัง → auto-update status เป็น 'completed'
      await _checkAndUpdateCompletionStatus(incidentId);

      return true;
    } catch (e) {
      debugPrint('updatePillarContent error: $e');
      return false;
    }
  }

  /// ตรวจสอบว่าข้อมูล 4 Pillars ครบหรือยัง
  /// ถ้าครบแล้วและ status ยังไม่เป็น 'completed' จะ auto-update ให้
  Future<void> _checkAndUpdateCompletionStatus(int incidentId) async {
    try {
      // ดึงข้อมูลปัจจุบันจาก DB
      final response = await _supabase
          .from('B_Incident')
          .select(
              'why_it_matters, root_cause, core_value_analysis, violated_core_values, prevention_plan, reflection_status')
          .eq('id', incidentId)
          .maybeSingle();

      if (response == null) return;

      // ตรวจสอบว่าครบ 4 Pillars หรือยัง
      final whyItMatters = response['why_it_matters'] as String?;
      final rootCause = response['root_cause'] as String?;
      final coreValueAnalysis = response['core_value_analysis'] as String?;
      final violatedCoreValues = response['violated_core_values'] as List?;
      final preventionPlan = response['prevention_plan'] as String?;
      final currentStatus = response['reflection_status'] as String?;

      // Pillar 1: why_it_matters มีค่า
      final pillar1Complete = whyItMatters?.isNotEmpty ?? false;
      // Pillar 2: root_cause มีค่า
      final pillar2Complete = rootCause?.isNotEmpty ?? false;
      // Pillar 3: core_value_analysis หรือ violated_core_values มีค่า
      final pillar3Complete = (coreValueAnalysis?.isNotEmpty ?? false) ||
          (violatedCoreValues?.isNotEmpty ?? false);
      // Pillar 4: prevention_plan มีค่า
      final pillar4Complete = preventionPlan?.isNotEmpty ?? false;

      final allComplete =
          pillar1Complete && pillar2Complete && pillar3Complete && pillar4Complete;

      // ถ้าครบแล้วและ status ยังไม่เป็น 'completed' → update
      if (allComplete && currentStatus != 'completed') {
        await _supabase.from('B_Incident').update({
          'reflection_status': 'completed',
          'reflection_completed_at': DateTime.now().toIso8601String(),
        }).eq('id', incidentId);

        invalidateCache();
        debugPrint(
            '_checkAndUpdateCompletionStatus: incident $incidentId auto-marked as completed');
      }
    } catch (e) {
      debugPrint('_checkAndUpdateCompletionStatus error: $e');
      // ไม่ throw - แค่ log error เพราะไม่ใช่ critical
    }
  }
}
