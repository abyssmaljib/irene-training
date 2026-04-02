// Model สำหรับ Point Transaction
// บันทึกการได้รับ/ใช้ points ของ user

/// ประเภทของ transaction
enum PointTransactionType {
  quizPassed('quiz_passed', 'สอบผ่าน', '📝'),
  quizPerfect('quiz_perfect', 'คะแนนเต็ม', '🌟'),
  contentRead('content_read', 'อ่านบทเรียน', '📖'),
  badgeEarned('badge_earned', 'ได้รับเหรียญ', '🏅'),
  reviewCompleted('review_completed', 'ทบทวนบทเรียน', '🔄'),
  taskCompleted('task_completed', 'ทำงานเสร็จ', '✅'),
  taskDifficult('task_difficult', 'งานยาก', '💪'),
  medArrange('MedArrange', 'จัดยา', '💊'),
  incidentPenalty('incident_penalty', 'หักคะแนน Incident', '⚠️'),
  incidentReflectionBonus('incident_reflection_bonus', 'คืนคะแนนถอดบทเรียน', '📝'),
  lateClockIn('late_clock_in', 'ขึ้นเวรสาย', '⏰'),
  manualAdjustment('manual_adjustment', 'ปรับปรุงคะแนน', '🔧'),
  transfer('transfer', 'โอนคะแนน', '🔄'),
  periodReward('period_reward', 'รางวัลประจำรอบ', '🎁'),
  seasonCarryover('season_carryover', 'โบนัสเริ่มต้น Season', '🎁'),
  other('other', 'อื่นๆ', '📌');

  final String value;
  final String displayName;
  final String icon;

  const PointTransactionType(this.value, this.displayName, this.icon);

  /// สร้างจาก string value
  static PointTransactionType fromString(String? value) {
    return PointTransactionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PointTransactionType.other,
    );
  }
}

/// Model สำหรับ Point Transaction
class PointTransaction {
  final int id;
  final DateTime createdAt;
  final String userId;
  final int pointChange;
  final PointTransactionType transactionType;
  final String? description;
  final String? referenceType;
  final String? referenceId;
  final int? nursinghomeId;
  final String? seasonId;

  // จาก JOIN กับ user_info (optional)
  final String? userNickname;
  final String? userPhotoUrl;

  const PointTransaction({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.pointChange,
    required this.transactionType,
    this.description,
    this.referenceType,
    this.referenceId,
    this.nursinghomeId,
    this.seasonId,
    this.userNickname,
    this.userPhotoUrl,
  });

  /// สร้างจาก JSON (Supabase response)
  factory PointTransaction.fromJson(Map<String, dynamic> json) {
    return PointTransaction(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      userId: json['user_id'] as String,
      pointChange: json['point_change'] as int? ?? 0,
      transactionType: PointTransactionType.fromString(
        json['transaction_type'] as String?,
      ),
      description: json['description'] as String?,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      nursinghomeId: json['nursinghome_id'] as int?,
      seasonId: json['season_id'] as String?,
      userNickname: json['nickname'] as String?,
      userPhotoUrl: json['photo_url'] as String?,
    );
  }

  /// แปลงเป็น JSON สำหรับ insert
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'point_change': pointChange,
      'transaction_type': transactionType.value,
      'description': description,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'nursinghome_id': nursinghomeId,
      'season_id': seasonId,
    };
  }

  /// ว่าเป็น positive หรือ negative points
  bool get isPositive => pointChange > 0;

  /// แสดงผล points พร้อมเครื่องหมาย
  String get displayPoints {
    final sign = isPositive ? '+' : '';
    return '$sign$pointChange';
  }

  /// วันที่แสดงผล
  DateTime get transactionDate => DateTime(
        createdAt.year,
        createdAt.month,
        createdAt.day,
      );

  @override
  String toString() =>
      'PointTransaction(id: $id, points: $pointChange, type: ${transactionType.value})';
}

/// สรุป points ของ user
/// รองรับทั้ง fixed threshold (เดิม) และ percentile-based (ใหม่)
class UserPointsSummary {
  final String userId;
  final String? nickname;
  final String? fullName;
  final String? photoUrl;
  final int? nursinghomeId;
  final int totalPoints;
  final int weekPoints;
  final int monthPoints;
  final int seasonPoints; // คะแนนใน season ปัจจุบัน (รวม carry-over bonus)
  final int transactionCount;

  // Tier info (ใช้ได้ทั้ง fixed และ percentile mode)
  final String? tierId;
  final String? tierName;
  final String? tierNameTh;
  final String? tierIcon;
  final String? tierColor;
  final String? nextTierName;
  final int? nextTierMinPoints;

  // Percentile-based fields (ใหม่)
  // ถ้า percentile != null แสดงว่าใช้ percentile mode
  final double? percentile; // Percentile ของ user (0-100)
  final int? rollingPoints; // คะแนนใน rolling 3-month window
  final int? rankInCohort; // อันดับที่ในกลุ่ม eligible
  final int? cohortSize; // จำนวนคน eligible ทั้งหมด
  final int? pointsGapToNext; // คะแนนโดยประมาณที่ต้องเพิ่มเพื่อถึง tier ถัดไป

  const UserPointsSummary({
    required this.userId,
    this.nickname,
    this.fullName,
    this.photoUrl,
    this.nursinghomeId,
    required this.totalPoints,
    required this.weekPoints,
    required this.monthPoints,
    this.seasonPoints = 0,
    required this.transactionCount,
    this.tierId,
    this.tierName,
    this.tierNameTh,
    this.tierIcon,
    this.tierColor,
    this.nextTierName,
    this.nextTierMinPoints,
    this.percentile,
    this.rollingPoints,
    this.rankInCohort,
    this.cohortSize,
    this.pointsGapToNext,
  });

  factory UserPointsSummary.fromJson(Map<String, dynamic> json) {
    return UserPointsSummary(
      userId: json['user_id'] as String,
      nickname: json['nickname'] as String?,
      fullName: json['full_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      nursinghomeId: json['nursinghome_id'] as int?,
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      weekPoints: (json['week_points'] as num?)?.toInt() ?? 0,
      monthPoints: (json['month_points'] as num?)?.toInt() ?? 0,
      seasonPoints: (json['season_points'] as num?)?.toInt() ?? 0,
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      tierId: json['tier_id'] as String?,
      tierName: json['tier_name'] as String?,
      tierNameTh: json['tier_name_th'] as String?,
      tierIcon: json['tier_icon'] as String?,
      tierColor: json['tier_color'] as String?,
      nextTierName: json['next_tier_name'] as String?,
      nextTierMinPoints: (json['next_tier_min_points'] as num?)?.toInt(),
      // Percentile fields — null ถ้ายังไม่ถูกคำนวณ (fallback ไป fixed mode)
      percentile: (json['percentile'] as num?)?.toDouble(),
      rollingPoints: (json['rolling_points'] as num?)?.toInt(),
      rankInCohort: (json['rank_in_cohort'] as num?)?.toInt(),
      cohortSize: (json['cohort_size'] as num?)?.toInt(),
      pointsGapToNext: (json['points_gap_to_next'] as num?)?.toInt(),
    );
  }

  /// เช็คว่าใช้ percentile mode หรือไม่
  /// ถ้า percentile != null แสดงว่า user ถูกคำนวณแล้ว
  bool get isPercentileMode => percentile != null;

  /// ชื่อ tier ที่แสดง
  String get tierDisplayName => tierNameTh ?? tierName ?? 'Bronze';

  /// Progress ไป tier ถัดไป (0.0 - 1.0)
  /// - percentile mode: ใช้ gap ที่คำนวณจาก DB
  /// - fixed mode: ใช้ min_points range เดิม
  double get progressToNextTier {
    if (nextTierName == null && nextTierMinPoints == null) return 1.0;

    if (isPercentileMode && pointsGapToNext != null && rollingPoints != null) {
      // Percentile mode: คำนวณจาก rolling_points กับ gap
      if (pointsGapToNext == 0) return 0.95;
      final totalNeeded = pointsGapToNext! + rollingPoints!;
      if (totalNeeded <= 0) return 0.5;
      return (rollingPoints! / totalNeeded).clamp(0.0, 0.99);
    }

    // Fixed mode fallback
    if (nextTierMinPoints == null) return 1.0;
    final currentMin = _estimateCurrentTierMin();
    final nextMin = nextTierMinPoints!;
    final range = nextMin - currentMin;
    if (range <= 0) return 1.0;
    final progress = (totalPoints - currentMin) / range;
    return progress.clamp(0.0, 1.0);
  }

  /// Fallback สำหรับ fixed mode — ประมาณ current tier min points จากชื่อ tier
  int _estimateCurrentTierMin() {
    switch (tierName?.toLowerCase()) {
      case 'bronze':
        return 0;
      case 'silver':
        return 500;
      case 'gold':
        return 1500;
      case 'platinum':
        return 3000;
      case 'diamond':
        return 5000;
      default:
        return 0;
    }
  }

  /// Points ที่ต้องการเพื่อไป tier ถัดไป
  int get pointsToNextTier {
    if (isPercentileMode && pointsGapToNext != null) {
      return pointsGapToNext!.clamp(0, 999999);
    }
    if (nextTierMinPoints == null) return 0;
    return (nextTierMinPoints! - totalPoints).clamp(0, nextTierMinPoints!);
  }

  /// ถึง tier สูงสุดแล้วหรือไม่
  bool get isMaxTier =>
      nextTierName == null && nextTierMinPoints == null;

  /// แสดง percentile เป็นข้อความ เช่น "Top 5.3%"
  String? get percentileDisplay {
    if (percentile == null) return null;
    final topPercent = (100 - percentile!).clamp(0, 100);
    if (topPercent < 1) return '#1';
    return 'Top ${topPercent.toStringAsFixed(topPercent == topPercent.roundToDouble() ? 0 : 1)}%';
  }

  /// แสดงอันดับ เช่น "อันดับ 2 จาก 18 คน"
  String? get rankDisplay {
    if (rankInCohort == null || cohortSize == null) return null;
    return 'อันดับ $rankInCohort จาก $cohortSize คน';
  }
}
