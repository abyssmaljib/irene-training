import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assessment_models.dart';

/// Service จัดการ Assessment Rating สำหรับ checklist task completion
/// - ดึงหัวข้อประเมินจาก TaskType_Report_Subject (ผูกด้วย taskType)
/// - บันทึก/ลบผลประเมินใน Scale_Report_Log
class AssessmentService {
  static final instance = AssessmentService._();
  AssessmentService._();

  final _supabase = Supabase.instance.client;

  /// Cache subjects ตาม taskType เพื่อไม่ต้อง query ซ้ำทุก task completion
  /// key = "$taskType:$nursinghomeId"
  final Map<String, List<AssessmentSubject>> _cache = {};

  /// ดึงหัวข้อประเมินสำหรับ taskType
  /// เช่น taskType = 'อาหาร' → ได้ [Subject #2 การรับประทานอาหาร]
  Future<List<AssessmentSubject>> getSubjectsForTaskType(
    String taskType,
    int nursinghomeId,
  ) async {
    // เช็ค cache ก่อน
    final cacheKey = '$taskType:$nursinghomeId';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    try {
      // Query 1: ดึง subject_ids จาก TaskType_Report_Subject
      final relations = await _supabase
          .from('TaskType_Report_Subject')
          .select('subject_id')
          .eq('task_type', taskType)
          .eq('nursinghome_id', nursinghomeId);

      if (relations.isEmpty) {
        _cache[cacheKey] = [];
        return [];
      }

      // รวม subject_id ทั้งหมด (ไม่ซ้ำ)
      final subjectIds =
          relations.map((r) => r['subject_id'] as int).toSet().toList();

      // Query 2: ดึง subject metadata
      final subjects = await _supabase
          .from('Report_Subject')
          .select('id, Subject, Description')
          .inFilter('id', subjectIds)
          .order('id', ascending: true);

      // Query 3: ดึง choices ทั้งหมดในครั้งเดียว (ป้องกัน N+1)
      final allChoices = await _supabase
          .from('Report_Choice')
          .select('Choice, Scale, Subject')
          .inFilter('Subject', subjectIds)
          .order('Scale', ascending: true);

      // สร้าง map: subjectId → [choice texts sorted by scale]
      final choicesMap = <int, List<String>>{};
      for (final c in allChoices) {
        final subjectId = c['Subject'] as int;
        choicesMap.putIfAbsent(subjectId, () => []);
        choicesMap[subjectId]!.add(c['Choice'] as String);
      }

      // รวมเป็น AssessmentSubject list
      final result = subjects.map((s) {
        final id = s['id'] as int;
        return AssessmentSubject(
          subjectId: id,
          subjectName: s['Subject'] as String? ?? '',
          subjectDescription: s['Description'] as String?,
          choices: choicesMap[id] ?? [],
        );
      }).toList();

      // เก็บ cache
      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('AssessmentService.getSubjectsForTaskType error: $e');
      return [];
    }
  }

  /// บันทึกผลประเมินลง Scale_Report_Log (ผูกกับ task_log_id)
  Future<void> saveRatings({
    required int taskLogId,
    required int residentId,
    required List<AssessmentRating> ratings,
  }) async {
    if (ratings.isEmpty) return;

    try {
      await _supabase.from('Scale_Report_Log').insert(
            ratings
                .map((r) => {
                      'task_log_id': taskLogId,
                      'Subject_id': r.subjectId,
                      // เก็บ scale value (1-5) ใน Choice_id — ตาม pattern เดิมของ Flutter
                      'Choice_id': r.rating,
                      'resident_id': residentId,
                      'report_description': r.description ?? '',
                    })
                .toList(),
          );
      debugPrint(
          'AssessmentService: saved ${ratings.length} ratings for task $taskLogId');
    } catch (e) {
      debugPrint('AssessmentService.saveRatings error: $e');
      // ไม่ rethrow — ไม่ให้ assessment error block task completion flow
    }
  }

  /// ลบผลประเมินของ task (ใช้ตอน unmarkTask)
  Future<void> deleteRatings(int taskLogId) async {
    try {
      await _supabase
          .from('Scale_Report_Log')
          .delete()
          .eq('task_log_id', taskLogId);
      debugPrint('AssessmentService: deleted ratings for task $taskLogId');
    } catch (e) {
      debugPrint('AssessmentService.deleteRatings error: $e');
    }
  }

  /// ล้าง cache (เรียกเมื่อ admin เปลี่ยน mapping)
  void clearCache() => _cache.clear();
}
