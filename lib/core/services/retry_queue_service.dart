import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/checklist/services/assessment_service.dart';
import '../../features/checklist/models/assessment_models.dart';
import '../../features/points/services/points_service.dart';

/// Retry Queue Service — เก็บ operations ที่ fail ไว้ใน local storage แล้ว retry ทีหลัง
///
/// ใช้สำหรับ secondary operations ที่ไม่ควร block task completion:
/// - Assessment ratings save
/// - Batch points recording
///
/// Flow:
/// 1. Operation fail → enqueue ไว้ใน SharedPreferences
/// 2. App resume / next task complete → processQueue() retry ทั้งหมด
/// 3. สำเร็จ → ลบออกจาก queue
/// 4. fail อีก → เก็บไว้ retry ครั้งถัดไป (max 5 ครั้ง)
class RetryQueueService {
  static final RetryQueueService instance = RetryQueueService._();
  RetryQueueService._();

  static const _queueKey = 'retry_queue_v1';
  static const _maxRetries = 5;

  // ========== Enqueue Operations ==========

  /// เพิ่ม assessment ratings ที่ fail เข้า queue
  Future<void> enqueueAssessmentRatings({
    required int taskLogId,
    required int residentId,
    required List<AssessmentRating> ratings,
  }) async {
    // แปลง ratings เป็น JSON-serializable map
    final ratingsData = ratings
        .map((r) => {
              'subjectId': r.subjectId,
              'rating': r.rating,
              if (r.description != null) 'description': r.description,
            })
        .toList();

    await _enqueue({
      'type': 'assessment_ratings',
      'taskLogId': taskLogId,
      'residentId': residentId,
      'ratings': ratingsData,
    });
    debugPrint('📋 RetryQueue: enqueued assessment ratings for task $taskLogId');
  }

  /// เพิ่ม batch points ที่ fail เข้า queue
  Future<void> enqueueBatchPoints({
    required String completingUserId,
    required int taskLogId,
    required String taskName,
    required String residentName,
    required List<String> coWorkerIds,
    int? difficultyScore,
    int? nursinghomeId,
  }) async {
    await _enqueue({
      'type': 'batch_points',
      'completingUserId': completingUserId,
      'taskLogId': taskLogId,
      'taskName': taskName,
      'residentName': residentName,
      'coWorkerIds': coWorkerIds,
      'difficultyScore': difficultyScore,
      'nursinghomeId': nursinghomeId,
    });
    debugPrint('📋 RetryQueue: enqueued batch points for task $taskLogId');
  }

  // ========== Process Queue ==========

  /// ประมวลผล queue ทั้งหมด — เรียกตอน app resume หรือหลัง task complete สำเร็จ
  /// return จำนวน items ที่ process สำเร็จ
  Future<int> processQueue() async {
    final items = await _getQueue();
    if (items.isEmpty) return 0;

    debugPrint('📋 RetryQueue: processing ${items.length} items');
    int successCount = 0;
    final remaining = <Map<String, dynamic>>[];

    for (final item in items) {
      final retryCount = (item['retryCount'] as int?) ?? 0;

      // เกิน max retries → ทิ้งไป (ป้องกัน queue โตไม่หยุด)
      if (retryCount >= _maxRetries) {
        debugPrint(
            '📋 RetryQueue: dropped item after $_maxRetries retries: ${item['type']}');
        continue;
      }

      final success = await _processItem(item);
      if (success) {
        successCount++;
      } else {
        // เพิ่ม retry count แล้วเก็บไว้ retry ครั้งถัดไป
        remaining.add({...item, 'retryCount': retryCount + 1});
      }
    }

    // บันทึก queue ที่เหลือ (items ที่ยัง fail)
    await _saveQueue(remaining);

    if (successCount > 0) {
      debugPrint(
          '📋 RetryQueue: $successCount succeeded, ${remaining.length} remaining');
    }
    return successCount;
  }

  /// จำนวน items ใน queue (สำหรับแสดง badge หรือ debug)
  Future<int> get pendingCount async {
    final items = await _getQueue();
    return items.length;
  }

  // ========== Private Helpers ==========

  /// ประมวลผล item แต่ละตัวตาม type
  Future<bool> _processItem(Map<String, dynamic> item) async {
    try {
      final type = item['type'] as String;

      switch (type) {
        case 'assessment_ratings':
          return await _processAssessmentRatings(item);
        case 'batch_points':
          return await _processBatchPoints(item);
        default:
          debugPrint('📋 RetryQueue: unknown type: $type');
          return false;
      }
    } catch (e) {
      debugPrint('📋 RetryQueue: process error: $e');
      return false;
    }
  }

  /// Retry: บันทึก assessment ratings
  Future<bool> _processAssessmentRatings(Map<String, dynamic> item) async {
    final taskLogId = item['taskLogId'] as int;
    final residentId = item['residentId'] as int;
    final ratingsData = (item['ratings'] as List).cast<Map<String, dynamic>>();

    // แปลงกลับเป็น AssessmentRating objects
    final ratings = ratingsData
        .map((r) => AssessmentRating(
              subjectId: r['subjectId'] as int,
              rating: r['rating'] as int,
              description: r['description'] as String?,
            ))
        .toList();

    try {
      await AssessmentService.instance.saveRatings(
        taskLogId: taskLogId,
        residentId: residentId,
        ratings: ratings,
      );
      debugPrint('📋 RetryQueue: assessment ratings saved for task $taskLogId');
      return true;
    } catch (e) {
      debugPrint('📋 RetryQueue: assessment retry failed: $e');
      return false;
    }
  }

  /// Retry: บันทึก batch points
  Future<bool> _processBatchPoints(Map<String, dynamic> item) async {
    try {
      // ตรวจสอบว่า user ยังมี session อยู่ (ต้อง auth ก่อน call RPC)
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return false;

      await PointsService().recordBatchTaskCompleted(
        completingUserId: item['completingUserId'] as String,
        taskLogId: item['taskLogId'] as int,
        taskName: item['taskName'] as String,
        residentName: item['residentName'] as String,
        coWorkerIds: (item['coWorkerIds'] as List).cast<String>(),
        difficultyScore: item['difficultyScore'] as int?,
        nursinghomeId: item['nursinghomeId'] as int?,
      );
      debugPrint(
          '📋 RetryQueue: batch points saved for task ${item['taskLogId']}');
      return true;
    } catch (e) {
      debugPrint('📋 RetryQueue: batch points retry failed: $e');
      return false;
    }
  }

  /// เพิ่ม item เข้า queue (persist ใน SharedPreferences)
  Future<void> _enqueue(Map<String, dynamic> item) async {
    final queue = await _getQueue();
    queue.add({...item, 'retryCount': 0, 'createdAt': DateTime.now().toIso8601String()});
    await _saveQueue(queue);
  }

  /// อ่าน queue จาก SharedPreferences
  Future<List<Map<String, dynamic>>> _getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('📋 RetryQueue: failed to parse queue: $e');
      return [];
    }
  }

  /// บันทึก queue ลง SharedPreferences
  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(_queueKey);
    } else {
      await prefs.setString(_queueKey, jsonEncode(queue));
    }
  }
}
