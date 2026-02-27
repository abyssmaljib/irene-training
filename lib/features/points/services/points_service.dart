import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

// PointsService: Core service สำหรับจัดการ Point Transactions
// - บันทึก points เมื่อ user ทำกิจกรรมต่างๆ
// - ดึง leaderboard และ history
// - ตรวจสอบ tier ของ user

/// Points ที่ได้รับจากแต่ละกิจกรรม
/// Updated: ลดคะแนน Quiz/Content และปรับสูตร Task scoring ใหม่
class PointsConfig {
  // ==================== Quiz & Content Points ====================

  /// Quiz posttest ผ่านครั้งแรก (ลดจาก 50)
  static const int quizPassed = 10;

  /// Bonus สำหรับคะแนนเต็ม (perfect score) (ลดจาก 20)
  static const int quizPerfect = 5;

  /// อ่าน content ครั้งแรก (ต่อ topic) (ลดจาก 5)
  static const int contentRead = 2;

  /// ทำ review quiz
  static const int reviewCompleted = 5;

  // ==================== Task Scoring (New Formula) ====================
  // Task Points = Time Score + Type Score + Difficulty Bonus

  /// Time Accuracy Score - เวลาที่ใช้จริง vs เวลาที่กำหนด
  /// ± 15 นาที = 5 points (ตรงเวลามาก)
  /// ± 30 นาที = 3 points (พอรับได้)
  /// ± 45 นาที = 2 points (เริ่มเบี่ยงเบน)
  /// > 1 ชม = 1 point (เวลาไม่ตรงกับจริง)
  static int taskTimeScore(int actualMinutes, int expectedMinutes) {
    final diff = (actualMinutes - expectedMinutes).abs();
    if (diff <= 15) return 5;
    if (diff <= 30) return 3;
    if (diff <= 45) return 2;
    return 1;
  }

  /// Completion Type Score
  /// สร้าง Post = 4 points (ต้องใช้เวลา+ความพยายามสูงสุด)
  /// ถ่ายรูป = 2 points (มีหลักฐานภาพ)
  /// ติ๊กเฉยๆ = 1 point (ทำเสร็จแต่ไม่มีหลักฐาน)
  /// ติดปัญหา = 0 points (ไม่ได้ complete จริง)
  static int taskTypeScore(String completionType) {
    switch (completionType) {
      case 'post':
        return 4;
      case 'photo':
        return 2;
      case 'check':
        return 1;
      case 'problem':
      default:
        return 0;
    }
  }

  /// Difficulty Bonus - +1 point ต่อทุก difficulty_score ที่เกิน 5
  /// เช่น difficulty 8 = +3 bonus
  static int taskDifficultyBonus(int difficultyScore) {
    if (difficultyScore <= 5) return 0;
    return difficultyScore - 5;
  }

  /// คำนวณ Total Task Points ตาม formula ใหม่
  /// Points = Time Score + Type Score + Difficulty Bonus
  static int calculateTaskPoints({
    required int actualMinutes,
    required int expectedMinutes,
    required String completionType,
    required int difficultyScore,
  }) {
    final timeScore = taskTimeScore(actualMinutes, expectedMinutes);
    final typeScore = taskTypeScore(completionType);
    final diffBonus = taskDifficultyBonus(difficultyScore);
    return timeScore + typeScore + diffBonus;
  }

  // ==================== Medicine Photo Points ====================

  /// ถ่ายรูปจัดยา/เสิร์ฟยา (ต่อรูป)
  static const int medicinePhoto = 5;

  // ==================== Dead Air Penalty ====================

  /// Dead Air Allowance - 75 นาที (1 ชม. 15 นาที) ให้ฟรี
  static const int deadAirAllowanceMinutes = 75;

  /// คำนวณ penalty จาก dead air
  /// -1 point ต่อทุก 10 นาที dead air
  static int deadAirPenalty(int deadAirMinutes) {
    if (deadAirMinutes <= 0) return 0;
    return (deadAirMinutes / 10).floor(); // ปัดลง
  }

  // ==================== Incident Penalty ====================

  /// คะแนนที่หักตาม severity ของ incident
  /// LEVEL_1 = 100, LEVEL_2 = 300, LEVEL_3 = 500
  static int incidentPenalty(String severity) {
    switch (severity.toUpperCase()) {
      case 'LEVEL_2':
        return 300;
      case 'LEVEL_3':
        return 500;
      case 'LEVEL_1':
      default:
        return 100;
    }
  }

  /// คะแนนที่คืนเมื่อถอดบทเรียนเสร็จ (50% ของ penalty)
  /// LEVEL_1 = +50, LEVEL_2 = +150, LEVEL_3 = +250
  static int incidentReflectionBonus(String severity) {
    return (incidentPenalty(severity) * 0.5).round();
  }

  // ==================== Late Clock-In Penalty ====================

  /// Grace period (นาที) - สาย 5 นาทีแรกไม่โดนหัก
  static const int lateClockInGraceMinutes = 5;

  /// คำนวณ penalty จากเวลาที่สาย (นาที)
  /// สาย 5-15 นาที = -50, 15-30 นาที = -100, >30 นาที = -150
  static int lateClockInPenalty(int lateMinutes) {
    if (lateMinutes <= 5) return 0;
    if (lateMinutes <= 15) return 50;
    if (lateMinutes <= 30) return 100;
    return 150;
  }

  // ==================== Legacy (deprecated) ====================

  /// ทำ task เสร็จ (base) - deprecated, ใช้ calculateTaskPoints แทน
  @Deprecated('Use calculateTaskPoints instead')
  static const int taskCompleted = 5;
}

class PointsService {
  final SupabaseClient _client;

  PointsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ==================== Recording Points ====================

  /// บันทึก point transaction ทั่วไป
  /// คืนค่า points ที่บันทึก (หรือ 0 ถ้า error)
  Future<int> recordTransaction({
    required String userId,
    required int points,
    required String transactionType,
    String? description,
    String? referenceType,
    String? referenceId,
    String? seasonId,
    int? nursinghomeId,
  }) async {
    try {
      // ถ้าไม่มี nursinghomeId ให้ดึงจาก user_info
      int? nhId = nursinghomeId;
      if (nhId == null) {
        final userInfo = await _client
            .from('user_info')
            .select('nursinghome_id')
            .eq('id', userId)
            .maybeSingle();
        nhId = userInfo?['nursinghome_id'] as int?;
      }

      await _client.from('Point_Transaction').insert({
        'user_id': userId,
        'point_change': points,
        'transaction_type': transactionType,
        'description': description,
        'reference_type': referenceType,
        'reference_id': referenceId,
        'season_id': seasonId,
        'nursinghome_id': nhId,
        'DateClaim': DateTime.now().toIso8601String().split('T')[0],
      });

      debugPrint('📊 Points recorded: $points for $transactionType');
      return points;
    } catch (e) {
      debugPrint('❌ Error recording points: $e');
      return 0;
    }
  }

  /// บันทึก points สำหรับ Quiz Passed
  /// - 50 points สำหรับผ่าน posttest ครั้งแรก
  /// - +20 bonus สำหรับ perfect score
  Future<int> recordQuizPassed({
    required String userId,
    required String sessionId,
    required String topicId,
    required String topicName,
    required int score,
    required int totalQuestions,
    required bool isFirstPass,
    String? seasonId,
  }) async {
    if (!isFirstPass) {
      debugPrint('📊 Quiz already passed before, no points awarded');
      return 0;
    }

    int totalPoints = 0;

    // Base points for passing
    final basePoints = await recordTransaction(
      userId: userId,
      points: PointsConfig.quizPassed,
      transactionType: 'quiz_passed',
      description: 'สอบผ่าน: $topicName',
      referenceType: 'quiz_session',
      referenceId: sessionId,
      seasonId: seasonId,
    );
    totalPoints += basePoints;

    // Bonus for perfect score
    if (score == totalQuestions) {
      final bonusPoints = await recordTransaction(
        userId: userId,
        points: PointsConfig.quizPerfect,
        transactionType: 'quiz_perfect',
        description: 'คะแนนเต็ม: $topicName',
        referenceType: 'quiz_session',
        referenceId: sessionId,
        seasonId: seasonId,
      );
      totalPoints += bonusPoints;
    }

    return totalPoints;
  }

  /// บันทึก points สำหรับ Badge Earned
  /// ใช้ points จาก training_badges.points
  Future<int> recordBadgeEarned({
    required String userId,
    required String badgeId,
    required int badgePoints,
    required String badgeName,
    String? seasonId,
  }) async {
    return await recordTransaction(
      userId: userId,
      points: badgePoints,
      transactionType: 'badge_earned',
      description: 'ได้รับเหรียญ: $badgeName',
      referenceType: 'badge',
      referenceId: badgeId,
      seasonId: seasonId,
    );
  }

  /// บันทึก points สำหรับ Content Read (ครั้งแรก)
  Future<int> recordContentRead({
    required String userId,
    required String topicId,
    required String topicName,
    String? seasonId,
  }) async {
    // ตรวจสอบว่าเคยได้ points จาก topic นี้หรือยัง
    final existing = await _client
        .from('Point_Transaction')
        .select('id')
        .eq('user_id', userId)
        .eq('transaction_type', 'content_read')
        .eq('reference_id', topicId)
        .maybeSingle();

    if (existing != null) {
      debugPrint('📊 Content already read, no points awarded');
      return 0;
    }

    return await recordTransaction(
      userId: userId,
      points: PointsConfig.contentRead,
      transactionType: 'content_read',
      description: 'อ่านบทเรียน: $topicName',
      referenceType: 'topic',
      referenceId: topicId,
      seasonId: seasonId,
    );
  }

  /// บันทึก points สำหรับ Review Quiz
  Future<int> recordReviewCompleted({
    required String userId,
    required String sessionId,
    required String topicName,
    String? seasonId,
  }) async {
    return await recordTransaction(
      userId: userId,
      points: PointsConfig.reviewCompleted,
      transactionType: 'review_completed',
      description: 'ทบทวน: $topicName',
      referenceType: 'quiz_session',
      referenceId: sessionId,
      seasonId: seasonId,
    );
  }

  /// บันทึก points สำหรับ Task Completed (New Formula)
  /// Points = Time Score + Type Score + Difficulty Bonus
  ///
  /// [actualMinutes] - เวลาที่ใช้จริง (นาที)
  /// [expectedMinutes] - เวลาที่กำหนด (นาที)
  /// [completionType] - ประเภทการ complete: 'post', 'photo', 'check', 'problem'
  /// [difficultyScore] - ระดับความยาก (1-10)
  Future<int> recordTaskCompletedV2({
    required String userId,
    required int taskLogId,
    required String taskName,
    required int actualMinutes,
    required int expectedMinutes,
    required String completionType,
    int difficultyScore = 5,
  }) async {
    // ถ้าติดปัญหา type score = 0 แต่ยังได้ time score + diff bonus
    final totalPoints = PointsConfig.calculateTaskPoints(
      actualMinutes: actualMinutes,
      expectedMinutes: expectedMinutes,
      completionType: completionType,
      difficultyScore: difficultyScore,
    );

    if (totalPoints <= 0) {
      debugPrint('📊 Task has no points (problem type with low scores)');
      return 0;
    }

    // Build description with breakdown
    final timeScore =
        PointsConfig.taskTimeScore(actualMinutes, expectedMinutes);
    final typeScore = PointsConfig.taskTypeScore(completionType);
    final diffBonus = PointsConfig.taskDifficultyBonus(difficultyScore);

    final description = 'งาน: $taskName '
        '(เวลา: +$timeScore, ประเภท: +$typeScore, ความยาก: +$diffBonus)';

    return await recordTransaction(
      userId: userId,
      points: totalPoints,
      transactionType: 'task_completed',
      description: description,
      referenceType: 'task_log',
      referenceId: taskLogId.toString(),
    );
  }

  /// บันทึก penalty สำหรับ Dead Air (หักตอนลงเวร)
  /// สูตร: Total Gaps - 75 (allowance) - Break Overlap
  /// Penalty: -1 point ต่อทุก 10 นาที
  Future<int> recordDeadAirPenalty({
    required String userId,
    required int clockRecordId,
    required int deadAirMinutes,
    int? nursinghomeId,
  }) async {
    if (deadAirMinutes <= 0) {
      debugPrint('📊 No dead air, no penalty');
      return 0;
    }

    final penalty = PointsConfig.deadAirPenalty(deadAirMinutes);
    if (penalty <= 0) return 0;

    // บันทึกเป็น negative points
    return await recordTransaction(
      userId: userId,
      points: -penalty, // ติดลบ!
      transactionType: 'dead_air_penalty',
      description: 'ทำไรอยู่อ่ะ: $deadAirMinutes นาที (-$penalty points)',
      referenceType: 'clock_record',
      referenceId: clockRecordId.toString(),
      nursinghomeId: nursinghomeId,
    );
  }

  /// บันทึก points สำหรับถ่ายรูปจัดยา/เสิร์ฟยา
  /// ได้ points ครั้งแรกต่อรูป (ต่อ resident + วัน + มื้อ + ประเภท)
  ///
  /// [residentId] - ID ของผู้พัก
  /// [date] - วันที่ (เฉพาะ date ไม่รวม time)
  /// [mealKey] - มื้อ เช่น 'ก่อนอาหารเช้า', 'หลังอาหารกลางวัน'
  /// [photoType] - ประเภทรูป: '2C' (จัดยา) หรือ '3C' (เสิร์ฟยา)
  Future<int> recordMedicinePhotoTaken({
    required String userId,
    required int residentId,
    required DateTime date,
    required String mealKey,
    required String photoType,
    int? nursinghomeId,
  }) async {
    // สร้าง unique reference ID: resident_date_meal_photoType
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final referenceId = '${residentId}_${dateStr}_${mealKey}_$photoType';

    // ตรวจสอบว่าเคยได้ points จากรูปนี้หรือยัง
    final existing = await _client
        .from('Point_Transaction')
        .select('id')
        .eq('user_id', userId)
        .eq('transaction_type', 'medicine_photo')
        .eq('reference_id', referenceId)
        .maybeSingle();

    if (existing != null) {
      debugPrint('📊 Medicine photo already recorded, no points awarded');
      return 0;
    }

    // สร้าง description ที่อ่านง่าย
    final photoLabel = photoType == '2C' ? 'จัดยา' : 'เสิร์ฟยา';
    final description = 'ถ่ายรูป$photoLabel: $mealKey';

    return await recordTransaction(
      userId: userId,
      points: PointsConfig.medicinePhoto,
      transactionType: 'medicine_photo',
      description: description,
      referenceType: 'med_log',
      referenceId: referenceId,
      nursinghomeId: nursinghomeId,
    );
  }

  /// บันทึก points เมื่อรูปยืนยันของ user ถูกเลือกเป็นรูปตัวอย่าง
  /// เรียกจาก task_detail_screen หลัง admin กดปุ่ม "แทนที่ตัวอย่าง"
  ///
  /// [userId] - ID ของ user ที่ถ่ายรูป (completed_by) ไม่ใช่ admin
  /// [taskLogId] - ID ของ task log ที่มีรูปถูกเลือก
  /// [taskTitle] - ชื่อ task สำหรับแสดงใน description
  /// คืน points ที่ให้สำเร็จ (100) หรือ 0 ถ้าเคยให้แล้ว
  Future<int> recordSampleImageSelected({
    required String userId,
    required int taskLogId,
    required String taskTitle,
    int? nursinghomeId,
  }) async {
    final referenceId = taskLogId.toString();

    // ตรวจสอบว่าเคยให้ points จาก task log นี้หรือยัง (ป้องกันซ้ำ)
    final existing = await _client
        .from('Point_Transaction')
        .select('id')
        .eq('user_id', userId)
        .eq('transaction_type', 'sample_image_selected')
        .eq('reference_id', referenceId)
        .maybeSingle();

    if (existing != null) {
      debugPrint('📊 Sample image reward already given for task $taskLogId');
      return 0;
    }

    return await recordTransaction(
      userId: userId,
      points: 100,
      transactionType: 'sample_image_selected',
      description: '✨ รูปถูกเลือกเป็นตัวอย่าง: $taskTitle',
      referenceType: 'task_log',
      referenceId: referenceId,
      nursinghomeId: nursinghomeId,
    );
  }

  /// บันทึก bonus เมื่อถอดบทเรียน incident เสร็จ (คืน 50% ของ penalty)
  /// เรียกจาก chat_provider หลัง user กดส่งสำเร็จ
  ///
  /// [incidentId] - ID ของ incident
  /// [severity] - ระดับ severity (LEVEL_1, LEVEL_2, LEVEL_3)
  /// [staffIds] - รายการ staff ที่เกี่ยวข้อง (ทุกคนได้คืน)
  /// คืน total bonus ที่ให้สำเร็จ (สำหรับแสดง feedback)
  Future<int> recordIncidentReflectionBonus({
    required int incidentId,
    required String severity,
    required List<String> staffIds,
    int? nursinghomeId,
  }) async {
    if (staffIds.isEmpty) return 0;

    final bonus = PointsConfig.incidentReflectionBonus(severity);
    if (bonus <= 0) return 0;

    // ตรวจสอบว่าเคยให้ bonus ไปแล้วหรือยัง (ป้องกันซ้ำ)
    try {
      final existing = await _client
          .from('Point_Transaction')
          .select('id')
          .eq('transaction_type', 'incident_reflection_bonus')
          .eq('reference_type', 'incident_reflection')
          .eq('reference_id', incidentId.toString())
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        debugPrint('📊 Incident reflection bonus already given for incident $incidentId');
        return 0;
      }
    } catch (e) {
      debugPrint('⚠️ Error checking existing bonus: $e');
      // ดำเนินการต่อ — ถ้าเช็คไม่ได้ก็ให้ bonus ไป (ดีกว่าไม่ให้)
    }

    int totalBonus = 0;
    // ให้ bonus ทุกคนใน staff_id[]
    for (final staffId in staffIds) {
      final result = await recordTransaction(
        userId: staffId,
        points: bonus,
        transactionType: 'incident_reflection_bonus',
        description: 'คืนคะแนน 50%: ถอดบทเรียนเสร็จ (${severity.toUpperCase()})',
        referenceType: 'incident_reflection',
        referenceId: incidentId.toString(),
        nursinghomeId: nursinghomeId,
      );
      if (result > 0) totalBonus += result;
    }

    debugPrint('📊 Incident reflection bonus: +$bonus x ${staffIds.length} staff = $totalBonus total');
    return totalBonus;
  }

  /// บันทึก points สำหรับ Batch Task Completed (หาร point กับเพื่อนร่วมเวร)
  ///
  /// คำนวณ points เหมือน recordTaskCompleted (V1) แล้วหาร
  /// ด้วยจำนวนคน (completingUser + coWorkers)
  ///
  /// สร้าง Point_Transaction record ให้ทุกคน:
  /// - completingUser = คนที่กดถ่ายรูป+complete
  /// - coWorkerIds = เพื่อนร่วมเวรที่เลือกไว้
  ///
  /// [taskLogId] - ID ของ task log
  /// [taskName] - ชื่อ task (ใช้ใน description)
  /// [residentName] - ชื่อคนไข้ (ใช้ใน description)
  /// [completingUserId] - user ที่กด complete
  /// [coWorkerIds] - รายชื่อ co-worker user IDs
  /// [difficultyScore] - คะแนนความยาก (1-10)
  ///
  /// คืนค่า points ที่แต่ละคนได้ (หลังหาร)
  Future<int> recordBatchTaskCompleted({
    required String completingUserId,
    required int taskLogId,
    required String taskName,
    required String residentName,
    required List<String> coWorkerIds,
    int? difficultyScore,
    int? nursinghomeId,
  }) async {
    final referenceId = taskLogId.toString();

    // ตรวจสอบ duplicate — ป้องกันกดซ้ำหรือ retry ให้แต้มซ้ำ
    final existing = await _client
        .from('Point_Transaction')
        .select('id')
        .eq('user_id', completingUserId)
        .eq('transaction_type', 'batch_task_completed')
        .eq('reference_id', referenceId)
        .maybeSingle();

    if (existing != null) {
      debugPrint('📊 Batch task already recorded for task $taskLogId');
      return 0;
    }

    // คำนวณ total points เหมือน V1: base 5 + difficulty bonus
    int totalPoints = 5; // base points
    int diffBonus = 0;
    if (difficultyScore != null && difficultyScore > 5) {
      diffBonus = PointsConfig.taskDifficultyBonus(difficultyScore);
      totalPoints += diffBonus;
    }

    // หารจำนวนคน (user + co-workers)
    final totalPeople = 1 + coWorkerIds.length;
    // ใช้ ~/ (integer division) เพื่อไม่ให้แต้มรวมเกินจริง
    // เช่น 5 ~/ 3 = 1 (ไม่ใช่ 2 จาก ceil ที่ทำให้แจก 6 แต้มจาก 5)
    // กรณี totalPeople > totalPoints (เช่น 6 คน 5 แต้ม) → หารได้ 0
    // ให้ผู้ทำงานได้ totalPoints เต็ม ส่วน co-workers ได้ 1 คนละ
    // เพื่อให้ทุกคนได้แต้มแต่รวมไม่ inflate มากจนเกินไป
    final rawPerPerson = totalPoints ~/ totalPeople;
    final pointsPerPerson = rawPerPerson > 0 ? rawPerPerson : 1;
    // ผู้ทำงาน: ได้ points เท่ากัน หรือได้ทั้งหมดถ้าหารไม่พอ
    final completingUserPoints = rawPerPerson > 0 ? rawPerPerson : totalPoints;

    final description =
        'Batch: $taskName - $residentName (หาร $totalPeople คน)';

    // ดึง nursinghomeId ครั้งเดียวเพื่อ pass ให้ทุกคน (ไม่ต้อง query ซ้ำ)
    int? nhId = nursinghomeId;
    if (nhId == null) {
      final userInfo = await _client
          .from('user_info')
          .select('nursinghome_id')
          .eq('id', completingUserId)
          .maybeSingle();
      nhId = userInfo?['nursinghome_id'] as int?;
    }

    // บันทึก points ให้คนที่ complete (ได้ completingUserPoints)
    int recorded = 0;
    final baseResult = await recordTransaction(
      userId: completingUserId,
      points: completingUserPoints,
      transactionType: 'batch_task_completed',
      description: description,
      referenceType: 'task_log',
      referenceId: referenceId,
      nursinghomeId: nhId,
    );
    if (baseResult > 0) recorded++;

    // บันทึก points ให้ co-workers ทุกคน — ใช้ Future.wait เพื่อลด latency
    // จาก O(N) sequential → O(1) parallel network calls
    final futures = coWorkerIds.map((coWorkerId) async {
      final cwResult = await recordTransaction(
        userId: coWorkerId,
        points: pointsPerPerson,
        transactionType: 'batch_task_completed',
        description: description,
        referenceType: 'task_log',
        referenceId: referenceId,
        nursinghomeId: nhId,
      );
      if (cwResult > 0) {
        recorded++;
        // แจ้งเตือนเพื่อนร่วมเวรว่าได้รับคะแนนจากการหาร
        try {
          await _client.from('notifications').insert({
            'title': '🎉 ได้รับคะแนนจากเพื่อนร่วมเวร',
            'body': 'คุณได้ +$pointsPerPerson คะแนน จากงาน $taskName'
                '${residentName.isNotEmpty ? ' - $residentName' : ''}'
                ' (หาร $totalPeople คน)',
            'user_id': coWorkerId,
            'type': 'points',
            'reference_table': 'A_Task_logs_ver2',
            'reference_id': taskLogId,
          });
        } catch (e) {
          // notification ล้มเหลวไม่ควร block flow หลัก
          debugPrint('⚠️ Failed to send co-worker notification: $e');
        }
      }
    });

    await Future.wait(futures);

    debugPrint(
        '📊 Batch points: $totalPoints total / $totalPeople people = $pointsPerPerson each ($recorded records)');
    return pointsPerPerson;
  }

  /// บันทึก points สำหรับ Task Completed (Legacy - deprecated)
  /// - 5 points base
  /// - + (difficulty_score - 5) bonus ถ้า difficulty > 5
  @Deprecated('Use recordTaskCompletedV2 instead')
  Future<int> recordTaskCompleted({
    required String userId,
    required int taskLogId,
    required String taskName,
    int? difficultyScore,
  }) async {
    int totalPoints = 0;

    // Base points (using deprecated constant)
    // ignore: deprecated_member_use_from_same_package
    final basePoints = await recordTransaction(
      userId: userId,
      points: 5, // Hardcoded to avoid deprecation warning
      transactionType: 'task_completed',
      description: 'ทำงานเสร็จ: $taskName',
      referenceType: 'task_log',
      referenceId: taskLogId.toString(),
    );
    totalPoints += basePoints;

    // Difficulty bonus
    if (difficultyScore != null && difficultyScore > 5) {
      final bonus = PointsConfig.taskDifficultyBonus(difficultyScore);
      final bonusPoints = await recordTransaction(
        userId: userId,
        points: bonus,
        transactionType: 'task_difficult',
        description: 'งานยาก (ระดับ $difficultyScore): $taskName',
        referenceType: 'task_log',
        referenceId: taskLogId.toString(),
      );
      totalPoints += bonusPoints;
    }

    return totalPoints;
  }

  // ==================== Querying Points ====================

  /// ดึง total points ของ user
  Future<int> getUserTotalPoints(String userId) async {
    try {
      final result = await _client
          .from('Point_Transaction')
          .select('point_change')
          .eq('user_id', userId);

      int total = 0;
      for (final row in result) {
        total += (row['point_change'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('❌ Error getting user total points: $e');
      return 0;
    }
  }

  /// ดึง user points summary (พร้อม tier info)
  Future<UserPointsSummary?> getUserSummary(String userId) async {
    try {
      final result = await _client
          .from('user_points_summary')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (result == null) return null;
      return UserPointsSummary.fromJson(result);
    } catch (e) {
      debugPrint('❌ Error getting user summary: $e');
      return null;
    }
  }

  /// ดึง tier info ของ user
  Future<UserTierInfo?> getUserTier(String userId) async {
    try {
      final result = await _client.rpc(
        'get_user_tier',
        params: {'p_user_id': userId},
      );

      if (result == null || (result as List).isEmpty) {
        // Return default tier
        return UserTierInfo(
          currentTier: Tier.defaultTier,
          nextTier: const Tier(
            id: 'silver',
            name: 'Silver',
            nameTh: 'ซิลเวอร์',
            minPoints: 500,
          ),
          totalPoints: 0,
        );
      }

      return UserTierInfo.fromJson(result[0] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ Error getting user tier: $e');
      return null;
    }
  }

  /// ดึง leaderboard (ใช้ RPC function - deprecated)
  Future<List<LeaderboardEntry>> getLeaderboard({
    int? nursinghomeId,
    LeaderboardPeriod period = LeaderboardPeriod.allTime,
    int limit = 50,
  }) async {
    try {
      final result = await _client.rpc(
        'get_leaderboard',
        params: {
          'p_nursinghome_id': nursinghomeId,
          'p_period': period.value,
          'p_limit': limit,
        },
      );

      if (result == null) return [];

      return (result as List)
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting leaderboard: $e');
      return [];
    }
  }

  // Note: getSimpleLeaderboard removed - using history view instead

  /// ดึง rank ของ user
  Future<int?> getUserRank({
    required String userId,
    int? nursinghomeId,
    LeaderboardPeriod period = LeaderboardPeriod.allTime,
  }) async {
    try {
      final leaderboard = await getLeaderboard(
        nursinghomeId: nursinghomeId,
        period: period,
        limit: 1000, // ดึงมากพอที่จะหา user
      );

      final userEntry = leaderboard.where((e) => e.userId == userId).firstOrNull;
      return userEntry?.rank;
    } catch (e) {
      debugPrint('❌ Error getting user rank: $e');
      return null;
    }
  }

  /// ดึง transaction history ของ user
  Future<List<PointTransaction>> getUserHistory({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final result = await _client
          .from('point_transaction_history')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (result as List)
          .map((e) => PointTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting user history: $e');
      return [];
    }
  }

  // ==================== Season Results ====================

  /// ดึงผลสรุป Season ของ user (แบบเกมออนไลน์)
  /// เรียงจาก season ล่าสุดก่อน
  Future<List<SeasonResult>> getSeasonResults(String userId) async {
    try {
      final result = await _client
          .from('season_results')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (result as List)
          .map((e) => SeasonResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting season results: $e');
      return [];
    }
  }

  /// ดึง season results ทั้งหมดของ season (ทุก user)
  /// ใช้แสดง leaderboard ของ season นั้นๆ
  Future<List<SeasonResult>> getSeasonLeaderboard(String seasonPeriodId) async {
    try {
      final result = await _client
          .from('season_results')
          .select()
          .eq('season_period_id', seasonPeriodId)
          .order('final_rank');

      return (result as List)
          .map((e) => SeasonResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting season leaderboard: $e');
      return [];
    }
  }

  /// ดึง active seasonal period (season ปัจจุบัน)
  /// return null ถ้ายังไม่มี seasonal period
  Future<Map<String, dynamic>?> getCurrentSeason({int? nursinghomeId}) async {
    try {
      final query = _client
          .from('leaderboard_periods')
          .select()
          .eq('period_type', 'seasonal')
          .eq('status', 'active');

      if (nursinghomeId != null) {
        final result = await query.eq('nursinghome_id', nursinghomeId).maybeSingle();
        return result;
      }

      final result = await query.maybeSingle();
      return result;
    } catch (e) {
      debugPrint('❌ Error getting current season: $e');
      return null;
    }
  }

  // ==================== Tiers ====================

  /// ดึง tiers ทั้งหมด
  Future<List<Tier>> getAllTiers() async {
    try {
      final result = await _client
          .from('point_tiers')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      return (result as List)
          .map((e) => Tier.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting tiers: $e');
      return [];
    }
  }

  // ==================== Period Rewards ====================

  /// ดึงรางวัลที่ user ได้จาก period completions (weekly/monthly/seasonal)
  /// JOIN กับ leaderboard_periods เพื่อดึง period name + date range มาด้วย
  Future<List<PeriodRewardEntry>> getUserPeriodRewards(String userId) async {
    try {
      final result = await _client
          .from('period_reward_distributions')
          .select(
              '*, leaderboard_periods(name, period_type, start_date, end_date)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (result as List)
          .map((e) => PeriodRewardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting user period rewards: $e');
      return [];
    }
  }

  // ==================== Rewards ====================

  /// ดึง rewards ทั้งหมด
  Future<List<PointReward>> getAllRewards() async {
    try {
      final result = await _client
          .from('point_rewards')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      return (result as List)
          .map((e) => PointReward.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting rewards: $e');
      return [];
    }
  }

  /// ดึง rewards ของ user (พร้อมสถานะ unlocked)
  Future<List<RewardWithStatus>> getUserRewards(String userId) async {
    try {
      // ดึง rewards ทั้งหมด
      final allRewards = await getAllRewards();

      // ดึง user's unlocked rewards
      final userRewardsResult = await _client
          .from('user_rewards')
          .select('reward_id, is_equipped, unlocked_at')
          .eq('user_id', userId);

      final userRewardsMap = <String, Map<String, dynamic>>{};
      for (final row in userRewardsResult) {
        userRewardsMap[row['reward_id'] as String] = row;
      }

      // Combine
      return allRewards.map((reward) {
        final userReward = userRewardsMap[reward.id];
        return RewardWithStatus(
          reward: reward,
          isUnlocked: userReward != null,
          isEquipped: userReward?['is_equipped'] as bool? ?? false,
          unlockedAt: userReward?['unlocked_at'] != null
              ? DateTime.parse(userReward!['unlocked_at'] as String)
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting user rewards: $e');
      return [];
    }
  }

  /// Equip/Unequip reward
  Future<bool> toggleRewardEquipped({
    required String userId,
    required String rewardId,
    required bool equipped,
  }) async {
    try {
      await _client
          .from('user_rewards')
          .update({'is_equipped': equipped})
          .eq('user_id', userId)
          .eq('reward_id', rewardId);
      return true;
    } catch (e) {
      debugPrint('❌ Error toggling reward: $e');
      return false;
    }
  }
}
