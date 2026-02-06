// Model สำหรับ Period Reward Distribution
// รางวัลที่ user ได้รับเมื่อจบรอบ leaderboard (weekly/monthly/seasonal)
// ข้อมูลมาจากตาราง period_reward_distributions + JOIN กับ leaderboard_periods

/// ประเภทรางวัลจาก period
enum PeriodRewardType {
  bonusPoints('bonus_points', 'คะแนนพิเศษ', '💰'),
  badge('badge', 'เหรียญ', '🏅'),
  title('title', 'ฉายา', '👑');

  final String value;
  final String displayName;
  final String icon;

  const PeriodRewardType(this.value, this.displayName, this.icon);

  /// สร้างจาก string value
  static PeriodRewardType fromString(String? value) {
    return PeriodRewardType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PeriodRewardType.bonusPoints,
    );
  }
}

/// ประเภท period (weekly/monthly/seasonal)
enum PeriodType {
  weekly('weekly', 'รายสัปดาห์'),
  monthly('monthly', 'รายเดือน'),
  seasonal('seasonal', 'ราย Season');

  final String value;
  final String displayName;

  const PeriodType(this.value, this.displayName);

  static PeriodType fromString(String? value) {
    return PeriodType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PeriodType.weekly,
    );
  }
}

/// Model สำหรับรางวัลที่ user ได้รับจาก period completion
class PeriodRewardEntry {
  final String id;
  final String periodId;
  final String userId;
  final int rank;
  final PeriodRewardType rewardType;
  final int bonusPoints;
  final String? title;
  final String? badgeId;
  final String status; // 'distributed', 'pending', 'failed'
  final DateTime? distributedAt;
  final DateTime createdAt;

  // Period info (จาก JOIN กับ leaderboard_periods)
  final String? periodName;
  final PeriodType? periodType;
  final DateTime? periodStartDate;
  final DateTime? periodEndDate;

  const PeriodRewardEntry({
    required this.id,
    required this.periodId,
    required this.userId,
    required this.rank,
    required this.rewardType,
    this.bonusPoints = 0,
    this.title,
    this.badgeId,
    required this.status,
    this.distributedAt,
    required this.createdAt,
    this.periodName,
    this.periodType,
    this.periodStartDate,
    this.periodEndDate,
  });

  /// สร้างจาก Supabase JSON response
  /// ใช้กับ query ที่ JOIN leaderboard_periods:
  /// .select('*, leaderboard_periods(name, period_type, start_date, end_date)')
  factory PeriodRewardEntry.fromJson(Map<String, dynamic> json) {
    // ดึง period info จาก nested JOIN object
    final periodData = json['leaderboard_periods'] as Map<String, dynamic>?;

    return PeriodRewardEntry(
      id: json['id'] as String,
      periodId: json['period_id'] as String,
      userId: json['user_id'] as String,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      rewardType: PeriodRewardType.fromString(json['reward_type'] as String?),
      bonusPoints: (json['bonus_points'] as num?)?.toInt() ?? 0,
      title: json['title'] as String?,
      badgeId: json['badge_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      distributedAt: json['distributed_at'] != null
          ? DateTime.parse(json['distributed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      // Period info จาก JOIN
      periodName: periodData?['name'] as String?,
      periodType: periodData != null
          ? PeriodType.fromString(periodData['period_type'] as String?)
          : null,
      periodStartDate: periodData?['start_date'] != null
          ? DateTime.parse(periodData!['start_date'] as String)
          : null,
      periodEndDate: periodData?['end_date'] != null
          ? DateTime.parse(periodData!['end_date'] as String)
          : null,
    );
  }

  /// ว่าแจกรางวัลแล้วหรือยัง
  bool get isDistributed => status == 'distributed';

  /// Icon ของอันดับ (top 3 ได้เหรียญ)
  String get rankIcon {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  /// คำอธิบายรางวัล เช่น "+50 คะแนนพิเศษ" หรือ "ฉายา: NA ดีเด่น"
  String get rewardDescription {
    switch (rewardType) {
      case PeriodRewardType.bonusPoints:
        return '+$bonusPoints คะแนนพิเศษ';
      case PeriodRewardType.badge:
        return 'เหรียญพิเศษ';
      case PeriodRewardType.title:
        return 'ฉายา: ${title ?? '-'}';
    }
  }

  /// Status label ภาษาไทย
  String get statusLabel {
    switch (status) {
      case 'distributed':
        return '✅ แจกแล้ว';
      case 'pending':
        return '⏳ รอแจก';
      case 'failed':
        return '❌ แจกไม่สำเร็จ';
      default:
        return status;
    }
  }

  @override
  String toString() =>
      'PeriodRewardEntry(rank: $rank, type: ${rewardType.value}, period: $periodName)';
}
