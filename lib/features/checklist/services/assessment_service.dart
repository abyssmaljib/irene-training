import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assessment_models.dart';

/// Service จัดการ Assessment Rating สำหรับ checklist task completion
/// - ดึงหัวข้อประเมินจาก TaskType_Report_Subject (ผูกด้วย taskType)
/// - รองรับ sub-items (หัวข้อย่อย เช่น "การนอน" มี 3 ข้อย่อย)
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

      // ดึง subjects พร้อม sub-items
      final result = await _fetchSubjectsWithSubItems(subjectIds);

      // เก็บ cache
      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('AssessmentService.getSubjectsForTaskType error: $e');
      return [];
    }
  }

  /// ดึงหัวข้อประเมินทั้งหมดของ nursing home (ไม่ filter by taskType)
  /// ใช้สำหรับ post assessment — เพราะ post ไม่มี taskType
  Future<List<AssessmentSubject>> getAllSubjectsForNursingHome(
    int nursinghomeId,
  ) async {
    // เช็ค cache (ใช้ key พิเศษ)
    final cacheKey = '_all_:$nursinghomeId';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    try {
      // Query 1: ดึง subject_ids ทั้งหมดของ nursing home (DISTINCT)
      final relations = await _supabase
          .from('TaskType_Report_Subject')
          .select('subject_id')
          .eq('nursinghome_id', nursinghomeId);

      if (relations.isEmpty) {
        _cache[cacheKey] = [];
        return [];
      }

      // รวม subject_id ทั้งหมด (ไม่ซ้ำ)
      final subjectIds =
          relations.map((r) => r['subject_id'] as int).toSet().toList();

      // ดึง subjects พร้อม sub-items
      final result = await _fetchSubjectsWithSubItems(subjectIds);

      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('AssessmentService.getAllSubjectsForNursingHome error: $e');
      return [];
    }
  }

  /// ดึง subjects + sub-items + choices ทั้งหมดในครั้งเดียว
  /// Shared logic ระหว่าง getSubjectsForTaskType() และ getAllSubjectsForNursingHome()
  Future<List<AssessmentSubject>> _fetchSubjectsWithSubItems(
    List<int> subjectIds,
  ) async {
    // Query 2: ดึง subject metadata พร้อม scoring_method
    final subjects = await _supabase
        .from('Report_Subject')
        .select('id, Subject, Description, scoring_method')
        .inFilter('id', subjectIds)
        .order('id', ascending: true);

    // Query 3: ดึง sub-items สำหรับ subjects ที่มี
    final subItems = await _supabase
        .from('Report_Sub_Item')
        .select('id, subject_id, name, description, sort_order')
        .inFilter('subject_id', subjectIds)
        .order('sort_order', ascending: true);

    // สร้าง map: subjectId → [sub-items]
    final subItemsMap = <int, List<Map<String, dynamic>>>{};
    for (final si in subItems) {
      final subjectId = si['subject_id'] as int;
      subItemsMap.putIfAbsent(subjectId, () => []);
      subItemsMap[subjectId]!.add(si);
    }

    // รวม sub-item IDs ทั้งหมด (สำหรับ query choices ของ sub-items)
    final subItemIds = subItems.map((si) => si['id'] as int).toList();

    // Query 4: ดึง choices + represent_url — แยก 2 กลุ่ม:
    // 4a: Legacy choices (sub_item_id IS NULL) สำหรับ subjects ที่ไม่มี sub-items
    final legacyChoices = await _supabase
        .from('Report_Choice')
        .select('Choice, Scale, Subject, represent_url')
        .inFilter('Subject', subjectIds)
        .isFilter('sub_item_id', null)
        .order('Scale', ascending: true);

    // สร้าง map: subjectId → [legacy choice texts] และ [represent_urls]
    final legacyChoicesMap = <int, List<String>>{};
    final legacyRepresentUrlsMap = <int, List<String?>>{};
    for (final c in legacyChoices) {
      final subjectId = c['Subject'] as int;
      legacyChoicesMap.putIfAbsent(subjectId, () => []);
      legacyChoicesMap[subjectId]!.add(c['Choice'] as String);
      legacyRepresentUrlsMap.putIfAbsent(subjectId, () => []);
      legacyRepresentUrlsMap[subjectId]!.add(c['represent_url'] as String?);
    }

    // 4b: Sub-item choices (sub_item_id IS NOT NULL)
    final subItemChoicesMap = <int, List<String>>{};
    final subItemRepresentUrlsMap = <int, List<String?>>{};
    if (subItemIds.isNotEmpty) {
      final subItemChoices = await _supabase
          .from('Report_Choice')
          .select('Choice, Scale, sub_item_id, represent_url')
          .inFilter('sub_item_id', subItemIds)
          .order('Scale', ascending: true);

      // สร้าง map: subItemId → [choice texts] และ [represent_urls]
      for (final c in subItemChoices) {
        final siId = c['sub_item_id'] as int;
        subItemChoicesMap.putIfAbsent(siId, () => []);
        subItemChoicesMap[siId]!.add(c['Choice'] as String);
        subItemRepresentUrlsMap.putIfAbsent(siId, () => []);
        subItemRepresentUrlsMap[siId]!.add(c['represent_url'] as String?);
      }
    }

    // รวมเป็น AssessmentSubject list
    return subjects.map((s) {
      final id = s['id'] as int;
      final scoringMethod = s['scoring_method'] as String? ?? 'none';
      final subItemRows = subItemsMap[id] ?? [];

      // สร้าง AssessmentSubItem list จาก sub-item rows
      final assessmentSubItems = subItemRows.map((si) {
        final siId = si['id'] as int;
        return AssessmentSubItem(
          subItemId: siId,
          name: si['name'] as String,
          description: si['description'] as String?,
          choices: subItemChoicesMap[siId] ?? [],
          representUrls: subItemRepresentUrlsMap[siId] ?? [],
          sortOrder: si['sort_order'] as int,
        );
      }).toList();

      return AssessmentSubject(
        subjectId: id,
        subjectName: s['Subject'] as String? ?? '',
        subjectDescription: s['Description'] as String?,
        // Legacy subjects ใช้ choices โดยตรง, sub-item subjects ใช้ subItems
        choices: assessmentSubItems.isEmpty ? (legacyChoicesMap[id] ?? []) : [],
        representUrls: assessmentSubItems.isEmpty
            ? (legacyRepresentUrlsMap[id] ?? [])
            : [],
        subItems: assessmentSubItems,
        scoringMethod: scoringMethod,
      );
    }).toList();
  }

  /// บันทึกผลประเมินลง Scale_Report_Log
  /// รองรับทั้ง task (taskLogId) และ post (postId)
  /// ต้องส่ง taskLogId หรือ postId อย่างใดอย่างหนึ่ง
  /// สำหรับ sub-item subjects จะบันทึก N rows (1 ต่อ sub-item)
  Future<void> saveRatings({
    int? taskLogId,
    int? postId,
    required int residentId,
    required List<AssessmentRating> ratings,
  }) async {
    if (ratings.isEmpty) return;
    // Guard: ต้องมี source อย่างน้อย 1 อย่าง (ป้องกัน orphaned records)
    if (taskLogId == null && postId == null) {
      debugPrint('AssessmentService.saveRatings: both taskLogId and postId are null, skipping');
      return;
    }

    try {
      await _supabase.from('Scale_Report_Log').insert(
            ratings
                .map((r) => {
                      if (taskLogId != null) 'task_log_id': taskLogId,
                      if (postId != null) 'post_id': postId,
                      'Subject_id': r.subjectId,
                      // เก็บ sub_item_id ถ้ามี (สำหรับ sub-item subjects)
                      if (r.subItemId != null) 'sub_item_id': r.subItemId,
                      // เก็บ scale value (1-5) ใน Choice_id — ตาม pattern เดิมของ Flutter
                      'Choice_id': r.rating,
                      'resident_id': residentId,
                      'report_description': r.description ?? '',
                    })
                .toList(),
          );
      final source = taskLogId != null ? 'task $taskLogId' : 'post $postId';
      debugPrint(
          'AssessmentService: saved ${ratings.length} ratings for $source');
    } catch (e) {
      debugPrint('AssessmentService.saveRatings error: $e');
      // ไม่ rethrow — ไม่ให้ assessment error block completion flow
    }
  }

  /// ลบผลประเมินของ task (ใช้ตอน unmarkTask)
  /// ลบทั้ง legacy และ sub-item entries เพราะ filter แค่ task_log_id
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

  /// ลบผลประเมินของ post (ใช้ก่อน re-insert เมื่อ edit post)
  Future<void> deleteRatingsForPost(int postId) async {
    try {
      await _supabase
          .from('Scale_Report_Log')
          .delete()
          .eq('post_id', postId);
      debugPrint('AssessmentService: deleted ratings for post $postId');
    } catch (e) {
      debugPrint('AssessmentService.deleteRatingsForPost error: $e');
    }
  }

  /// ดึงผลประเมินที่ผูกกับ post (สำหรับ edit post)
  /// Returns: list ของ AssessmentRating ที่เคยบันทึกไว้ (รวม sub-item entries)
  Future<List<AssessmentRating>> getRatingsForPost(int postId) async {
    try {
      final result = await _supabase
          .from('Scale_Report_Log')
          .select('Subject_id, sub_item_id, Choice_id, report_description')
          .eq('post_id', postId);

      return result
          .map((r) => AssessmentRating(
                subjectId: r['Subject_id'] as int,
                subItemId: r['sub_item_id'] as int?,
                rating: r['Choice_id'] as int,
                description: r['report_description'] as String?,
              ))
          .toList();
    } catch (e) {
      debugPrint('AssessmentService.getRatingsForPost error: $e');
      return [];
    }
  }

  /// ล้าง cache (เรียกเมื่อ admin เปลี่ยน mapping หรือ sub-items)
  void clearCache() => _cache.clear();
}
