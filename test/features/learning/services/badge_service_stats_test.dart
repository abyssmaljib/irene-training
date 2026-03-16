// Unit tests สำหรับ BadgeService.buildStatsJson()
// ทดสอบ pure computation logic ที่คำนวณ shift badge stats จาก raw task data
// ไม่ต้อง mock Supabase เพราะเป็น static method ที่รับ data ตรงๆ
//
// รัน: flutter test test/features/learning/services/badge_service_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:irene_training/features/learning/services/badge_service.dart';

void main() {
  // ============================================================
  // Helper: สร้าง task log map สำหรับ test
  // ============================================================

  /// สร้าง task log entry แบบกำหนดค่าได้
  /// จำลอง row จาก A_Task_logs_ver2
  Map<String, dynamic> makeTask({
    int id = 1,
    String status = 'complete',
    String? completedAt = '2026-03-15T10:00:00',
    String? expectedDateTime = '2026-03-15T09:30:00',
    int? difficultyScore,
    int? taskId,
    int? cTaskId,
  }) {
    return {
      'id': id,
      'status': status,
      'completed_at': completedAt,
      'ExpectedDateTime': expectedDateTime,
      'difficulty_score': difficultyScore,
      'task_id': taskId,
      'c_task_id': cTaskId,
    };
  }

  // ============================================================
  // Group 1: Happy Path — เวรปกติ 12 ชม. มี tasks ผสม
  // ============================================================

  group('Happy Path - เวรปกติมี tasks ผสม', () {
    test('Scenario 1: คำนวณ stats ครบทุก field จาก mixed tasks', () {
      // เวรเช้า 07:00-19:00, มี 5 tasks
      // - 3 complete, 1 problem, 1 ไม่มี status ที่รู้จัก
      // - task 101 มี difficulty 8, norm 5 → novice += 3
      // - task 102 มี difficulty 3, norm 6 → master += 3
      final tasks = [
        makeTask(
            id: 1,
            status: 'complete',
            completedAt: '2026-03-15T08:00:00',
            expectedDateTime: '2026-03-15T08:00:00',
            difficultyScore: 8,
            taskId: 101),
        makeTask(
            id: 2,
            status: 'complete',
            completedAt: '2026-03-15T10:00:00',
            expectedDateTime: '2026-03-15T09:30:00',
            difficultyScore: 3,
            taskId: 102),
        makeTask(
            id: 3,
            status: 'problem',
            completedAt: '2026-03-15T12:00:00',
            expectedDateTime: null, // problem task ไม่มี expected time
            taskId: 103),
        makeTask(
            id: 4,
            status: 'complete',
            completedAt: '2026-03-15T15:00:00',
            expectedDateTime: '2026-03-15T14:00:00',
            taskId: 104),
        makeTask(
            id: 5,
            status: 'pending',
            completedAt: '2026-03-15T16:00:00',
            expectedDateTime: null, // pending ไม่มี expected time
            taskId: 105),
      ];

      // norm map: task 101 = 5, task 102 = 6
      final normMap = {101: 5.0, 102: 6.0};

      // resident map: task 101→resident 1, 104→resident 3 (ไม่ assigned)
      final residentMap = <int, int?>{
        101: 1,
        102: 1,
        103: 2,
        104: 3, // ไม่ assigned → kindness
        105: 1,
      };

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: normMap,
        residentMap: residentMap,
        assignedResidentIds: [1, 2], // assigned เฉพาะ resident 1, 2
        clockIn: DateTime(2026, 3, 15, 7, 0), // 07:00 ICT
      );

      expect(result['completed_count'], equals(3));
      expect(result['problem_count'], equals(1));
      expect(result['kindness_count'], equals(1)); // task 104 → resident 3
      expect(result['total_tasks'], equals(5));
      expect(result['version'], equals(1));

      // difficulty: task 101 = 8-5=+3 (novice), task 102 = 3-6=-3 (master)
      expect(result['difficulty_diff_sum'], equals(3));
      expect(result['norm_difficulty_sum'], equals(3));

      // timing: task 1 = 0 min, task 2 = 30 min, task 4 = 60 min → avg = 30
      expect(result['avg_timing_diff'], equals(30.0));

      // last_task_time = 16:00
      expect(result['last_task_time'], contains('2026-03-15T16:00:00'));

      // adjust_date: clock-in 07:00 → ไม่ shift
      expect(result['adjust_date'], equals('2026-03-15'));
    });
  });

  // ============================================================
  // Group 2: Kindness calculation
  // ============================================================

  group('Happy Path - Kindness', () {
    test('Scenario 2: นับ kindness ถูกต้อง — tasks ของ resident ที่ไม่ใช่ตัวเอง',
        () {
      final tasks = [
        makeTask(id: 1, taskId: 10),
        makeTask(id: 2, taskId: 20),
        makeTask(id: 3, cTaskId: 30), // calendar task
      ];

      // resident mapping:
      // task 10 → resident 1 (assigned)
      // task 20 → resident 5 (ไม่ assigned → kindness!)
      // c_task 30 → resident 8 (ไม่ assigned → kindness!)
      final residentMap = <int, int?>{10: 1, 20: 5, 30: 8};

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: {},
        residentMap: residentMap,
        assignedResidentIds: [1, 2, 3], // assigned 1,2,3
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      expect(result['kindness_count'], equals(2)); // task 20 + c_task 30
    });
  });

  // ============================================================
  // Group 3: Difficulty scores
  // ============================================================

  group('Happy Path - Difficulty', () {
    test('Scenario 3: difficulty > norm → novice diff', () {
      final tasks = [
        makeTask(id: 1, difficultyScore: 9, taskId: 101),
        makeTask(id: 2, difficultyScore: 7, taskId: 102),
      ];
      // norm 101=5, 102=5 → novice: (9-5)+(7-5) = 4+2 = 6
      final normMap = {101: 5.0, 102: 5.0};

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: normMap,
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      expect(result['difficulty_diff_sum'], equals(6));
      expect(result['norm_difficulty_sum'], equals(0));
    });

    test('Scenario 4: difficulty < norm → master diff', () {
      final tasks = [
        makeTask(id: 1, difficultyScore: 2, taskId: 101),
        makeTask(id: 2, difficultyScore: 1, taskId: 102),
      ];
      // norm 101=5, 102=5 → master: |2-5|+|1-5| = 3+4 = 7
      final normMap = {101: 5.0, 102: 5.0};

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: normMap,
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      expect(result['difficulty_diff_sum'], equals(0));
      expect(result['norm_difficulty_sum'], equals(7));
    });
  });

  // ============================================================
  // Group 4: Timing diff
  // ============================================================

  group('Happy Path - Timing', () {
    test('Scenario 5: avg timing diff คำนวณจาก abs(completed - expected)', () {
      final tasks = [
        // เสร็จช้า 10 นาที
        makeTask(
          id: 1,
          completedAt: '2026-03-15T08:10:00',
          expectedDateTime: '2026-03-15T08:00:00',
        ),
        // เสร็จเร็ว 20 นาที
        makeTask(
          id: 2,
          completedAt: '2026-03-15T09:40:00',
          expectedDateTime: '2026-03-15T10:00:00',
        ),
      ];

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: {},
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      // avg = (10 + 20) / 2 = 15.0
      expect(result['avg_timing_diff'], equals(15.0));
    });
  });

  // ============================================================
  // Group 5: Last task time
  // ============================================================

  group('Happy Path - Last task time', () {
    test('Scenario 6: last_task_time = MAX(completed_at)', () {
      final tasks = [
        makeTask(id: 1, completedAt: '2026-03-15T08:00:00'),
        makeTask(id: 2, completedAt: '2026-03-15T18:30:00'), // ล่าสุด
        makeTask(id: 3, completedAt: '2026-03-15T12:00:00'),
      ];

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: {},
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      expect(result['last_task_time'], contains('2026-03-15T18:30:00'));
    });
  });

  // ============================================================
  // Group 6: Edge Cases — Zero/Empty
  // ============================================================

  group('Edge Case - Zero tasks', () {
    test('Scenario 7: 0 tasks → ทุกค่าเป็น 0/default', () {
      final result = BadgeService.buildStatsJson(
        taskLogs: [],
        normMap: {},
        residentMap: {},
        assignedResidentIds: [1, 2],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      expect(result['completed_count'], equals(0));
      expect(result['problem_count'], equals(0));
      expect(result['kindness_count'], equals(0));
      expect(result['avg_timing_diff'], equals(999999.0));
      expect(result['difficulty_diff_sum'], equals(0));
      expect(result['norm_difficulty_sum'], equals(0));
      expect(result['last_task_time'], isNull);
      expect(result['total_tasks'], equals(0));
      expect(result['version'], equals(1));
    });
  });

  // ============================================================
  // Group 7: Edge Cases — adjust_date
  // ============================================================

  group('Edge Case - adjust_date', () {
    test('Scenario 8: clock-in hour < 7 (02:00 เวรดึก) → shift back 1 day',
        () {
      final result = BadgeService.buildStatsJson(
        taskLogs: [],
        normMap: {},
        residentMap: {},
        assignedResidentIds: [],
        // clock-in 02:00 local = เวรดึก → adjust_date ควรเป็นวันก่อน
        clockIn: DateTime(2026, 3, 15, 2, 0),
      );

      // hour=2 < 7 → shift back → 2026-03-14
      expect(result['adjust_date'], equals('2026-03-14'));
    });

    test('Scenario 9: clock-in hour == 7 (เวรเช้าพอดี) → ไม่ shift', () {
      final result = BadgeService.buildStatsJson(
        taskLogs: [],
        normMap: {},
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      // hour=7 → ไม่ shift → 2026-03-15
      expect(result['adjust_date'], equals('2026-03-15'));
    });

    test('Scenario 17: cross-year boundary — 2026-01-01 02:00 → 2025-12-31',
        () {
      final result = BadgeService.buildStatsJson(
        taskLogs: [],
        normMap: {},
        residentMap: {},
        assignedResidentIds: [],
        // 1 ม.ค. 02:00 → adjustDate = 31 ธ.ค. ปีก่อน
        clockIn: DateTime(2026, 1, 1, 2, 0),
      );

      expect(result['adjust_date'], equals('2025-12-31'));
    });
  });

  // ============================================================
  // Group 8: Edge Cases — Null/Missing values
  // ============================================================

  group('Edge Case - Null ExpectedDateTime', () {
    test('Scenario 10: ทุก task ไม่มี ExpectedDateTime → avg_timing = 999999',
        () {
      final tasks = [
        makeTask(id: 1, expectedDateTime: null),
        makeTask(id: 2, expectedDateTime: null),
      ];

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: {},
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      expect(result['avg_timing_diff'], equals(999999.0));
    });
  });

  group('Edge Case - Null difficulty_score', () {
    test('Scenario 11: ทุก task ไม่มี difficulty → scores = 0', () {
      final tasks = [
        makeTask(id: 1, difficultyScore: null, taskId: 101),
        makeTask(id: 2, difficultyScore: null, taskId: 102),
      ];
      final normMap = {101: 5.0, 102: 5.0};

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: normMap,
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      expect(result['difficulty_diff_sum'], equals(0));
      expect(result['norm_difficulty_sum'], equals(0));
    });

    test('Scenario 12: task มี difficulty แต่ไม่มีใน normMap → skip', () {
      final tasks = [
        makeTask(id: 1, difficultyScore: 8, taskId: 101),
        makeTask(id: 2, difficultyScore: 3, taskId: 102),
      ];
      // normMap ว่าง → ไม่มี norm สำหรับเทียบ → skip ทั้งคู่
      final normMap = <int, double>{};

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: normMap,
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      expect(result['difficulty_diff_sum'], equals(0));
      expect(result['norm_difficulty_sum'], equals(0));
    });
  });

  // ============================================================
  // Group 9: Edge Cases — task_id / c_task_id variations
  // ============================================================

  group('Edge Case - c_task_id only (calendar tasks)', () {
    test('Scenario 13: task มีแค่ c_task_id → ใช้เป็น cache key', () {
      final tasks = [
        // calendar task: task_id=null, c_task_id=201
        makeTask(id: 1, difficultyScore: 9, taskId: null, cTaskId: 201),
      ];
      // norm สำหรับ c_task 201
      final normMap = {201: 5.0};

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: normMap,
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      // 9 - 5 = 4 (novice)
      expect(result['difficulty_diff_sum'], equals(4));
    });
  });

  // ============================================================
  // Group 10: Edge Cases — Kindness edge cases
  // ============================================================

  group('Edge Case - Kindness empty/null', () {
    test('Scenario 14: assignedResidentIds = [] → kindnessCount = 0', () {
      final tasks = [
        makeTask(id: 1, taskId: 101),
        makeTask(id: 2, taskId: 102),
      ];
      final residentMap = <int, int?>{101: 5, 102: 8};

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: {},
        residentMap: residentMap,
        assignedResidentIds: [], // ว่าง → ไม่นับ kindness
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      expect(result['kindness_count'], equals(0));
    });

    test('Scenario 15: task ที่ resident_id = null → ไม่นับเป็น kindness', () {
      final tasks = [
        makeTask(id: 1, taskId: 101),
        makeTask(id: 2, taskId: 102),
      ];
      // resident 101 = null (task ไม่มี resident), 102 = 5 (ไม่ assigned)
      final residentMap = <int, int?>{101: null, 102: 5};

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: {},
        residentMap: residentMap,
        assignedResidentIds: [1, 2], // assigned 1,2
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      // เฉพาะ task 102 → resident 5 ≠ [1,2] → kindness = 1
      // task 101 → resident null → skip
      expect(result['kindness_count'], equals(1));
    });
  });

  // ============================================================
  // Group 11: Edge Cases — Difficulty == 0
  // ============================================================

  group('Edge Case - Difficulty diff == 0', () {
    test('Scenario 16: user == norm → ไม่นับทั้ง novice และ master', () {
      final tasks = [
        makeTask(id: 1, difficultyScore: 5, taskId: 101),
        makeTask(id: 2, difficultyScore: 7, taskId: 102),
      ];
      final normMap = {101: 5.0, 102: 7.0}; // เท่ากันเป๊ะ

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: normMap,
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      expect(result['difficulty_diff_sum'], equals(0));
      expect(result['norm_difficulty_sum'], equals(0));
    });
  });

  // ============================================================
  // Group 12: Edge Cases — Mixed statuses
  // ============================================================

  group('Edge Case - ทุก task เป็น problem', () {
    test('completedCount=0, problemCount=N', () {
      final tasks = [
        makeTask(id: 1, status: 'problem'),
        makeTask(id: 2, status: 'problem'),
        makeTask(id: 3, status: 'problem'),
      ];

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: {},
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      expect(result['completed_count'], equals(0));
      expect(result['problem_count'], equals(3));
      expect(result['total_tasks'], equals(3));
    });
  });

  group('Edge Case - status ที่ไม่ใช่ complete/problem', () {
    test('status อื่นไม่ถูกนับใน completed หรือ problem', () {
      final tasks = [
        makeTask(id: 1, status: 'pending'),
        makeTask(id: 2, status: 'cancelled'),
        makeTask(id: 3, status: 'in_progress'),
      ];

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: {},
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      expect(result['completed_count'], equals(0));
      expect(result['problem_count'], equals(0));
      expect(result['total_tasks'], equals(3)); // ยังนับ total
    });
  });

  // ============================================================
  // Group 13: Malformed data resilience
  // ============================================================

  group('Edge Case - malformed completed_at', () {
    test('completed_at เป็น invalid string → skip ใน timing + lastTaskTime',
        () {
      final tasks = [
        makeTask(
          id: 1,
          completedAt: 'not-a-date',
          expectedDateTime: '2026-03-15T08:00:00',
        ),
        makeTask(
          id: 2,
          completedAt: '2026-03-15T10:00:00',
          expectedDateTime: '2026-03-15T09:30:00',
        ),
      ];

      final result = BadgeService.buildStatsJson(
        taskLogs: tasks,
        normMap: {},
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 3, 15, 7, 0),
      );

      // เฉพาะ task 2 ที่คำนวณ timing ได้ → 30 min
      expect(result['avg_timing_diff'], equals(30.0));
      // last_task_time ก็เฉพาะ task 2
      expect(result['last_task_time'], contains('2026-03-15T10:00:00'));
    });
  });

  // ============================================================
  // Group 14: adjust_date date formatting
  // ============================================================

  group('Edge Case - adjust_date format', () {
    test('เดือนและวัน 1 หลัก ต้อง pad ด้วย 0', () {
      // clock-in 2026-01-05 08:00 → adjust_date = "2026-01-05"
      final result = BadgeService.buildStatsJson(
        taskLogs: [],
        normMap: {},
        residentMap: {},
        assignedResidentIds: [],
        clockIn: DateTime(2026, 1, 5, 8, 0),
      );

      expect(result['adjust_date'], equals('2026-01-05'));
    });
  });
}
