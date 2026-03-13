import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:irene_training/features/learning/services/badge_service.dart';

// Mock SupabaseClient เพื่อให้สร้าง BadgeService ได้โดยไม่ต้อง init Supabase
class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Unit tests สำหรับ Shift Badges logic
/// ทดสอบ pure functions โดย pass mock client เข้าไป:
/// - checkShiftBadgeCondition: ตรวจว่า badge แต่ละประเภทให้ถูกคน
/// - isWinner / isWinnerDouble: ตรวจ winner + tie breaker
/// - countKindnessTasks: นับ task ที่ช่วยคนอื่น
/// - calculateAvgTimingDiff: คำนวณค่าเบี่ยงเบนเวลา
/// - calculateDeadAirMinutes: คำนวณ dead air
/// - calculateDifficultyScores: คำนวณ novice/master scores
void main() {
  late BadgeService badgeService;

  setUp(() {
    // ส่ง mock client เข้าไป → ไม่เรียก Supabase.instance.client
    badgeService = BadgeService(client: MockSupabaseClient());
  });

  // ============================================================
  // Helper: สร้าง ShiftStaffStats สำหรับ test
  // ============================================================

  /// สร้าง stats แบบกำหนดค่าได้ (default = 0 ทุกอย่าง)
  ShiftStaffStats makeStats({
    String staffId = 'user-1',
    String staffName = 'Test User',
    int problemCount = 0,
    int completedCount = 0,
    int kindnessCount = 0,
    double avgTimingDiff = double.infinity,
    int deadAirMinutes = 0,
    int noviceScore = 0,
    int masterScore = 0,
    DateTime? lastTaskTime,
  }) {
    return ShiftStaffStats(
      staffId: staffId,
      staffName: staffName,
      problemCount: problemCount,
      completedCount: completedCount,
      kindnessCount: kindnessCount,
      avgTimingDiff: avgTimingDiff,
      deadAirMinutes: deadAirMinutes,
      noviceScore: noviceScore,
      masterScore: masterScore,
      lastTaskTime: lastTaskTime,
    );
  }

  // ============================================================
  // Group 1: Happy Path — แต่ละ badge ให้ถูกคน
  // ============================================================

  group('Happy Path - shift_most_completed', () {
    test('ได้ badge เมื่อทำงานเสร็จมากที่สุด', () {
      // user ทำเสร็จ 10 งาน, คนอื่นทำ 5 และ 3
      final myStats = makeStats(
        staffId: 'me',
        completedCount: 10,
        lastTaskTime: DateTime(2026, 3, 10, 14, 0),
      );
      final allStats = [
        myStats,
        makeStats(staffId: 'other-1', completedCount: 5),
        makeStats(staffId: 'other-2', completedCount: 3),
      ];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_completed',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });
  });

  group('Happy Path - shift_most_problems', () {
    test('ได้ badge เมื่อติ๊กปัญหามากที่สุด', () {
      final myStats = makeStats(
        staffId: 'me',
        problemCount: 5,
        lastTaskTime: DateTime(2026, 3, 10, 14, 0),
      );
      final allStats = [
        myStats,
        makeStats(staffId: 'other-1', problemCount: 2),
        makeStats(staffId: 'other-2', problemCount: 1),
      ];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_problems',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });
  });

  group('Happy Path - shift_most_kindness', () {
    test('ได้ badge เมื่อช่วยคนไข้คนอื่นมากที่สุด', () {
      final myStats = makeStats(
        staffId: 'me',
        kindnessCount: 3,
        lastTaskTime: DateTime(2026, 3, 10, 14, 0),
      );
      final allStats = [
        myStats,
        // staff อื่น kindnessCount = 0 (เพราะ code return 0 สำหรับ staff อื่น)
        makeStats(staffId: 'other-1', kindnessCount: 0),
      ];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_kindness',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });
  });

  group('Happy Path - shift_best_timing', () {
    test('ได้ badge เมื่อ timing deviation ต่ำที่สุด', () {
      final myStats = makeStats(
        staffId: 'me',
        avgTimingDiff: 5.0, // ค่าเบี่ยงเบน 5 นาที (ดีมาก)
        lastTaskTime: DateTime(2026, 3, 10, 14, 0),
      );
      final allStats = [
        myStats,
        makeStats(staffId: 'other-1', avgTimingDiff: 20.0),
        makeStats(staffId: 'other-2', avgTimingDiff: 30.0),
      ];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_best_timing',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });
  });

  group('Happy Path - shift_most_dead_air', () {
    test('ได้ badge เมื่อ dead air มากที่สุด', () {
      final myStats = makeStats(
        staffId: 'me',
        deadAirMinutes: 120,
        lastTaskTime: DateTime(2026, 3, 10, 14, 0),
      );
      final allStats = [
        myStats,
        makeStats(staffId: 'other-1', deadAirMinutes: 60),
        makeStats(staffId: 'other-2', deadAirMinutes: 30),
      ];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_dead_air',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });
  });

  group('Happy Path - shift_novice_rating', () {
    test('ได้ badge เมื่อ noviceScore >= threshold', () {
      final myStats = makeStats(staffId: 'me', noviceScore: 15);
      final allStats = [myStats];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_novice_rating',
        requirementValue: {'min_diff_sum': 10},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });

    test('ได้ badge พอดี threshold (noviceScore == 10)', () {
      final myStats = makeStats(staffId: 'me', noviceScore: 10);
      final allStats = [myStats];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_novice_rating',
        requirementValue: {'min_diff_sum': 10},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });
  });

  group('Happy Path - shift_master_rating', () {
    test('ได้ badge เมื่อ masterScore >= threshold', () {
      final myStats = makeStats(staffId: 'me', masterScore: 12);
      final allStats = [myStats];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_master_rating',
        requirementValue: {'min_diff_sum': 10},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });
  });

  // ============================================================
  // Group 2: Edge Cases — ขอบเขตที่อาจเป็นปัญหา
  // ============================================================

  group('Edge Case - staff คนเดียวในเวร', () {
    test('ได้ shift_most_completed ถ้ามี task >= 1', () {
      // ขึ้นเวรคนเดียว completedCount = 1 → ชนะ (เทียบกับตัวเอง)
      final myStats = makeStats(
        staffId: 'me',
        completedCount: 1,
        lastTaskTime: DateTime(2026, 3, 10, 14, 0),
      );
      final allStats = [myStats]; // คนเดียวในเวร

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_completed',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      // ถ้าขึ้นเวรคนเดียวและมี task >= 1 → ได้ badge
      expect(result, isTrue);
    });

    test('ไม่ได้ shift_most_completed ถ้า completedCount = 0', () {
      final myStats = makeStats(staffId: 'me', completedCount: 0);
      final allStats = [myStats];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_completed',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      // completedCount = 0 → ไม่ผ่าน minimum threshold
      expect(result, isFalse);
    });
  });

  group('Edge Case - Tie breaker', () {
    test('ชนะ tie ถ้า lastTaskTime เร็วกว่า', () {
      // 2 คน completedCount เท่ากัน แต่ me ทำเสร็จก่อน
      final myStats = makeStats(
        staffId: 'me',
        completedCount: 5,
        lastTaskTime: DateTime(2026, 3, 10, 13, 0), // เร็วกว่า
      );
      final otherStats = makeStats(
        staffId: 'other',
        completedCount: 5,
        lastTaskTime: DateTime(2026, 3, 10, 14, 0), // ช้ากว่า
      );
      final allStats = [myStats, otherStats];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_completed',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });

    test('แพ้ tie ถ้า lastTaskTime ช้ากว่า', () {
      final myStats = makeStats(
        staffId: 'me',
        completedCount: 5,
        lastTaskTime: DateTime(2026, 3, 10, 15, 0), // ช้ากว่า
      );
      final otherStats = makeStats(
        staffId: 'other',
        completedCount: 5,
        lastTaskTime: DateTime(2026, 3, 10, 13, 0), // เร็วกว่า
      );
      final allStats = [myStats, otherStats];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_completed',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isFalse);
    });
  });

  group('Edge Case - ค่าเป็น 0 ไม่ได้ badge', () {
    test('problemCount = 0 → ไม่ได้ shift_most_problems', () {
      final myStats = makeStats(staffId: 'me', problemCount: 0);
      final allStats = [myStats];

      expect(
        badgeService.checkShiftBadgeCondition(
          requirementType: 'shift_most_problems',
          requirementValue: {},
          myStats: myStats,
          allStats: allStats,
        ),
        isFalse,
      );
    });

    test('kindnessCount = 0 → ไม่ได้ shift_most_kindness', () {
      final myStats = makeStats(staffId: 'me', kindnessCount: 0);
      final allStats = [myStats];

      expect(
        badgeService.checkShiftBadgeCondition(
          requirementType: 'shift_most_kindness',
          requirementValue: {},
          myStats: myStats,
          allStats: allStats,
        ),
        isFalse,
      );
    });

    test('deadAirMinutes = 0 → ไม่ได้ shift_most_dead_air', () {
      final myStats = makeStats(staffId: 'me', deadAirMinutes: 0);
      final allStats = [myStats];

      expect(
        badgeService.checkShiftBadgeCondition(
          requirementType: 'shift_most_dead_air',
          requirementValue: {},
          myStats: myStats,
          allStats: allStats,
        ),
        isFalse,
      );
    });
  });

  group('Edge Case - avgTimingDiff = infinity', () {
    test('ไม่ได้ shift_best_timing ถ้าไม่มี tasks ที่มี expected time', () {
      // avgTimingDiff = infinity (default) → ไม่มี task ที่มี expected time
      final myStats = makeStats(
        staffId: 'me',
        avgTimingDiff: double.infinity,
      );
      final allStats = [myStats];

      expect(
        badgeService.checkShiftBadgeCondition(
          requirementType: 'shift_best_timing',
          requirementValue: {},
          myStats: myStats,
          allStats: allStats,
        ),
        isFalse,
      );
    });
  });

  group('Edge Case - novice/master ต่ำกว่า threshold', () {
    test('noviceScore = 5 < threshold 10 → ไม่ได้ badge', () {
      final myStats = makeStats(staffId: 'me', noviceScore: 5);
      final allStats = [myStats];

      expect(
        badgeService.checkShiftBadgeCondition(
          requirementType: 'shift_novice_rating',
          requirementValue: {'min_diff_sum': 10},
          myStats: myStats,
          allStats: allStats,
        ),
        isFalse,
      );
    });

    test('masterScore = 0 → ไม่ได้ badge', () {
      final myStats = makeStats(staffId: 'me', masterScore: 0);
      final allStats = [myStats];

      expect(
        badgeService.checkShiftBadgeCondition(
          requirementType: 'shift_master_rating',
          requirementValue: {'min_diff_sum': 10},
          myStats: myStats,
          allStats: allStats,
        ),
        isFalse,
      );
    });
  });

  group('Edge Case - kindness เทียบกันจริงระหว่าง staff', () {
    test('ไม่ได้ badge ถ้า staff อื่น kindness สูงกว่า', () {
      // ตอนนี้ query assigned residents ของ staff ทุกคนจริงแล้ว
      // → staff อื่นที่ช่วยคนไข้เยอะกว่าจะชนะ
      final myStats = makeStats(
        staffId: 'me',
        kindnessCount: 2,
        lastTaskTime: DateTime(2026, 3, 10, 14, 0),
      );
      final allStats = [
        myStats,
        makeStats(
          staffId: 'other-1',
          kindnessCount: 5, // ช่วยเยอะกว่า
          lastTaskTime: DateTime(2026, 3, 10, 13, 0),
        ),
      ];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_kindness',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isFalse);
    });

    test('ได้ badge ถ้า kindness สูงที่สุดจริงๆ', () {
      final myStats = makeStats(
        staffId: 'me',
        kindnessCount: 5,
        lastTaskTime: DateTime(2026, 3, 10, 14, 0),
      );
      final allStats = [
        myStats,
        makeStats(staffId: 'other-1', kindnessCount: 2),
        makeStats(staffId: 'other-2', kindnessCount: 3),
      ];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_kindness',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });
  });

  group('Edge Case - lastTaskTime = null (tie breaker fails)', () {
    test('แพ้ tie ถ้า myTime = null', () {
      final myStats = makeStats(
        staffId: 'me',
        completedCount: 5,
        lastTaskTime: null, // ไม่มีเวลา → แพ้ tie
      );
      final otherStats = makeStats(
        staffId: 'other',
        completedCount: 5,
        lastTaskTime: DateTime(2026, 3, 10, 14, 0),
      );
      final allStats = [myStats, otherStats];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_completed',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isFalse);
    });
  });

  // ============================================================
  // Group 3: Helper Functions — คำนวณ stats
  // ============================================================

  group('calculateAvgTimingDiff', () {
    test('คำนวณค่าเฉลี่ยถูกต้อง', () {
      // task 1: completed 10 นาทีหลัง expected
      // task 2: completed 20 นาทีก่อน expected
      // avg = (10 + 20) / 2 = 15.0
      final tasks = [
        {
          'log_completed_at': '2026-03-10T14:10:00',
          'ExpectedDateTime': '2026-03-10T14:00:00',
        },
        {
          'log_completed_at': '2026-03-10T14:40:00',
          'ExpectedDateTime': '2026-03-10T15:00:00',
        },
      ];

      final result = badgeService.calculateAvgTimingDiff(tasks);
      expect(result, equals(15.0));
    });

    test('คืน infinity ถ้าไม่มี tasks', () {
      expect(badgeService.calculateAvgTimingDiff([]), equals(double.infinity));
    });

    test('ข้ามถ้า expected time เป็น null', () {
      final tasks = [
        {
          'log_completed_at': '2026-03-10T14:10:00',
          'ExpectedDateTime': null,
        },
      ];

      // ไม่มี task ที่คำนวณได้ → infinity
      expect(badgeService.calculateAvgTimingDiff(tasks), equals(double.infinity));
    });
  });

  group('calculateDeadAirMinutes', () {
    test('คำนวณ gaps ระหว่าง tasks ถูกต้อง', () {
      // clockIn 08:00, task1 เสร็จ 09:00, task2 เสร็จ 10:00, clockOut 11:00
      // gap1 = 60 min (08:00→09:00)
      // gap2 = 60 min (09:00→10:00)
      // gap3 = 60 min (10:00→11:00)
      // total = 180 min - 75 min allowance = 105 min
      final tasks = [
        {'log_completed_at': '2026-03-10T09:00:00'},
        {'log_completed_at': '2026-03-10T10:00:00'},
      ];

      final result = badgeService.calculateDeadAirMinutes(
        staffTasks: tasks,
        clockIn: DateTime(2026, 3, 10, 8, 0),
        clockOut: DateTime(2026, 3, 10, 11, 0),
      );

      // total gaps = 180 min, หัก allowance 75 = 105
      expect(result, equals(105));
    });

    test('คืน 0 ถ้า gap <= allowance 75 นาที', () {
      // clockIn 08:00, task เสร็จ 08:30, clockOut 09:00
      // gap1 = 30 min, gap2 = 30 min → total = 60 min
      // 60 - 75 = -15 → clamp(0) = 0
      final tasks = [
        {'log_completed_at': '2026-03-10T08:30:00'},
      ];

      final result = badgeService.calculateDeadAirMinutes(
        staffTasks: tasks,
        clockIn: DateTime(2026, 3, 10, 8, 0),
        clockOut: DateTime(2026, 3, 10, 9, 0),
      );

      expect(result, equals(0));
    });

    test('ไม่มี task เลย → dead air = ทั้งเวร - allowance', () {
      // clockIn 08:00, clockOut 16:00 → 480 min - 75 = 405
      final result = badgeService.calculateDeadAirMinutes(
        staffTasks: [],
        clockIn: DateTime(2026, 3, 10, 8, 0),
        clockOut: DateTime(2026, 3, 10, 16, 0),
      );

      // ไม่มี task → dead air = ทั้งเวร = 480 min
      // แต่ code path สำหรับ empty tasks คืน clockOut - clockIn ตรงๆ
      expect(result, equals(480));
    });
  });

  group('calculateDifficultyScores', () {
    test('คำนวณ novice/master scores ถูกต้อง', () {
      // task 1: user ให้ 8, norm 5 → novice += 3
      // task 2: user ให้ 3, norm 6 → master += 3
      // task 3: user ให้ 5, norm 5 → ไม่เปลี่ยน
      final tasks = [
        {'difficulty_score': 8, 'avg_difficulty_score_30d': 5},
        {'difficulty_score': 3, 'avg_difficulty_score_30d': 6},
        {'difficulty_score': 5, 'avg_difficulty_score_30d': 5},
      ];

      final (novice, master) = badgeService.calculateDifficultyScores(tasks);
      expect(novice, equals(3));
      expect(master, equals(3));
    });

    test('ข้าม task ที่ไม่มี difficulty_score', () {
      final tasks = [
        {'difficulty_score': null, 'avg_difficulty_score_30d': 5},
        {'difficulty_score': 8, 'avg_difficulty_score_30d': null},
        {'difficulty_score': 7, 'avg_difficulty_score_30d': 5},
      ];

      final (novice, master) = badgeService.calculateDifficultyScores(tasks);
      // เฉพาะ task 3 ที่มีทั้งคู่: 7 - 5 = 2 (novice)
      expect(novice, equals(2));
      expect(master, equals(0));
    });

    test('ไม่มี tasks → scores = 0', () {
      final (novice, master) = badgeService.calculateDifficultyScores([]);
      expect(novice, equals(0));
      expect(master, equals(0));
    });
  });

  group('countKindnessTasks', () {
    test('นับ tasks ที่ resident ไม่อยู่ใน assigned list', () {
      final tasks = [
        {'resident_id': 1}, // assigned → ไม่นับ
        {'resident_id': 2}, // assigned → ไม่นับ
        {'resident_id': 3}, // ไม่ assigned → นับ!
        {'resident_id': 4}, // ไม่ assigned → นับ!
      ];

      final result = badgeService.countKindnessTasks(
        staffTasks: tasks,
        assignedResidentIds: [1, 2], // assigned เฉพาะ 1, 2
      );

      expect(result, equals(2));
    });

    test('return 0 ถ้า assignedResidentIds ว่าง (ไม่ได้เลือกตอน clock in)', () {
      final tasks = [
        {'resident_id': 3},
        {'resident_id': 4},
      ];

      final result = badgeService.countKindnessTasks(
        staffTasks: tasks,
        assignedResidentIds: [], // ไม่มี assigned → ถือว่าทุก task เป็นของตัวเอง
      );

      expect(result, equals(0));
    });

    test('ข้าม task ที่ resident_id = null', () {
      final tasks = [
        {'resident_id': null},
        {'resident_id': 3},
      ];

      final result = badgeService.countKindnessTasks(
        staffTasks: tasks,
        assignedResidentIds: [1, 2],
      );

      // เฉพาะ resident 3 ที่นับ
      expect(result, equals(1));
    });

    test('นับ kindness สำหรับ staff อื่นได้ถูกต้อง (ใช้ assigned residents จริง)', () {
      // ตอนนี้ countKindnessTasks ไม่สนว่าเป็น current user หรือ staff อื่น
      // เพราะ caller ส่ง assigned residents ของ staff คนนั้นมาตรงๆ
      final tasks = [
        {'resident_id': 10}, // assigned → ไม่นับ
        {'resident_id': 20}, // ไม่ assigned → นับ!
        {'resident_id': 30}, // ไม่ assigned → นับ!
      ];

      final result = badgeService.countKindnessTasks(
        staffTasks: tasks,
        assignedResidentIds: [10, 11, 12], // staff อื่นดูแล 10, 11, 12
      );

      // resident 20, 30 ไม่อยู่ใน assigned → kindness = 2
      expect(result, equals(2));
    });
  });

  // ============================================================
  // Group 4: Unknown requirement type
  // ============================================================

  group('Edge Case - unknown requirement type', () {
    test('คืน false สำหรับ type ที่ไม่รู้จัก', () {
      final myStats = makeStats(staffId: 'me', completedCount: 100);
      final allStats = [myStats];

      expect(
        badgeService.checkShiftBadgeCondition(
          requirementType: 'shift_unknown_type',
          requirementValue: {},
          myStats: myStats,
          allStats: allStats,
        ),
        isFalse,
      );
    });
  });

  // ============================================================
  // Group 5: Timing tie breaker สำหรับ best_timing (double)
  // ============================================================

  group('Edge Case - best_timing tie breaker', () {
    test('ชนะ tie (avgTimingDiff ห่างไม่เกิน 0.01)', () {
      final myStats = makeStats(
        staffId: 'me',
        avgTimingDiff: 10.005,
        lastTaskTime: DateTime(2026, 3, 10, 13, 0), // เร็วกว่า
      );
      final otherStats = makeStats(
        staffId: 'other',
        avgTimingDiff: 10.005,
        lastTaskTime: DateTime(2026, 3, 10, 14, 0), // ช้ากว่า
      );
      final allStats = [myStats, otherStats];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_best_timing',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });

    test('ไม่ได้ badge ถ้าคนอื่น timing ดีกว่าชัดเจน', () {
      final myStats = makeStats(
        staffId: 'me',
        avgTimingDiff: 20.0,
        lastTaskTime: DateTime(2026, 3, 10, 13, 0),
      );
      final otherStats = makeStats(
        staffId: 'other',
        avgTimingDiff: 5.0, // ดีกว่าชัด
        lastTaskTime: DateTime(2026, 3, 10, 14, 0),
      );
      final allStats = [myStats, otherStats];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_best_timing',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isFalse);
    });
  });

  // ============================================================
  // Group 6: Default requirement_value (ไม่มี min_diff_sum)
  // ============================================================

  group('Edge Case - default threshold ถ้าไม่ระบุ min_diff_sum', () {
    test('ใช้ default threshold = 10 ถ้า requirement_value ว่าง', () {
      final myStats = makeStats(staffId: 'me', noviceScore: 10);
      final allStats = [myStats];

      // ไม่ส่ง min_diff_sum → ใช้ default 10
      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_novice_rating',
        requirementValue: {}, // ว่าง
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });

    test('ไม่ได้ badge ถ้า score = 9 (ต่ำกว่า default 10)', () {
      final myStats = makeStats(staffId: 'me', noviceScore: 9);
      final allStats = [myStats];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_novice_rating',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isFalse);
    });
  });

  // ============================================================
  // Group 7: Self-comparison skip (Bug #3 fix)
  // ก่อนแก้: isWinner เปรียบเทียบกับตัวเอง → ถ้า lastTaskTime=null
  // จะ return false เพราะ myTime==null ใน tie-breaker
  // หลังแก้: skip ตัวเองด้วย staffId → ไม่เข้า tie-breaker กับตัวเอง
  // ============================================================

  group('Self-comparison skip - winner with null lastTaskTime', () {
    test('ได้ badge ถ้าขึ้นเวรคนเดียว + lastTaskTime=null (skip self)', () {
      // ก่อนแก้: isWinner เจอ otherValue==myValue, myTime==null → return false
      // หลังแก้: skip self → ไม่มีใครเปรียบเทียบ → return true
      final myStats = makeStats(
        staffId: 'me',
        completedCount: 5,
        lastTaskTime: null, // ไม่มี log_completed_at
      );
      final allStats = [myStats]; // คนเดียวในเวร

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_completed',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      // ขึ้นเวรคนเดียว + completedCount > 0 → ต้องได้ badge
      expect(result, isTrue);
    });

    test('ได้ badge ถ้า lastTaskTime=null แต่คนอื่น completedCount น้อยกว่า', () {
      // ก่อนแก้: self-comparison fail ก่อนไปถึง other
      // หลังแก้: skip self → เปรียบเทียบกับ other เท่านั้น → 3 < 5 → ชนะ
      final myStats = makeStats(
        staffId: 'me',
        completedCount: 5,
        lastTaskTime: null,
      );
      final allStats = [
        myStats,
        makeStats(
          staffId: 'other',
          completedCount: 3,
          lastTaskTime: DateTime(2026, 3, 10, 14, 0),
        ),
      ];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_completed',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });
  });

  group('Self-comparison skip - isWinnerDouble', () {
    test('ได้ best_timing ถ้า lastTaskTime=null แต่ timing ดีกว่าคนอื่น', () {
      // isWinnerDouble ก็ต้อง skip self เหมือนกัน
      final myStats = makeStats(
        staffId: 'me',
        avgTimingDiff: 5.0, // ดีกว่า
        lastTaskTime: null,
      );
      final allStats = [
        myStats,
        makeStats(
          staffId: 'other',
          avgTimingDiff: 20.0, // แย่กว่า
          lastTaskTime: DateTime(2026, 3, 10, 14, 0),
        ),
      ];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_best_timing',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      expect(result, isTrue);
    });
  });

  group('Self-comparison skip - edge cases', () {
    test('แพ้ tie กับคนอื่นถ้า myTime=null (ไม่ใช่ self-comparison)', () {
      // tie กับคนอื่น (ไม่ใช่ตัวเอง) + myTime=null → ยังต้องแพ้
      final myStats = makeStats(
        staffId: 'me',
        completedCount: 5,
        lastTaskTime: null,
      );
      final allStats = [
        myStats,
        makeStats(
          staffId: 'other',
          completedCount: 5, // เท่ากัน
          lastTaskTime: DateTime(2026, 3, 10, 14, 0),
        ),
      ];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_completed',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      // tie กับคนอื่น + myTime=null → แพ้ (ถูกต้อง)
      expect(result, isFalse);
    });

    test('ทุกคน lastTaskTime=null + tie → แพ้', () {
      // ทั้งคู่ completedCount เท่ากัน + lastTaskTime=null
      final myStats = makeStats(
        staffId: 'me',
        completedCount: 5,
        lastTaskTime: null,
      );
      final allStats = [
        myStats,
        makeStats(
          staffId: 'other',
          completedCount: 5,
          lastTaskTime: null, // ทั้งคู่ null
        ),
      ];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_completed',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      // tie + myTime=null → แพ้ (ถ้าเราไม่มี time ก็ไม่ควรได้เปรียบ)
      expect(result, isFalse);
    });

    test('skip self ไม่ว่า me อยู่ตำแหน่งไหนใน allStats (5 คน)', () {
      // me อยู่กลาง list (index 2) — ต้อง skip ถูกตัว
      final myStats = makeStats(
        staffId: 'me',
        problemCount: 8,
        lastTaskTime: null, // null แต่ต้องชนะเพราะ count สูงสุด
      );
      final allStats = [
        makeStats(staffId: 'staff-1', problemCount: 3),
        makeStats(staffId: 'staff-2', problemCount: 5),
        myStats, // อยู่กลาง list
        makeStats(staffId: 'staff-3', problemCount: 6),
        makeStats(staffId: 'staff-4', problemCount: 2),
      ];

      final result = badgeService.checkShiftBadgeCondition(
        requirementType: 'shift_most_problems',
        requirementValue: {},
        myStats: myStats,
        allStats: allStats,
      );

      // problemCount = 8 สูงสุด → ต้องได้ badge
      expect(result, isTrue);
    });
  });
}
