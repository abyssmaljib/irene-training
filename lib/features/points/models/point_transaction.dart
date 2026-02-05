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
  manualAdjustment('manual_adjustment', 'ปรับปรุงคะแนน', '🔧'),
  transfer('transfer', 'โอนคะแนน', '🔄'),
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
class UserPointsSummary {
  final String userId;
  final String? nickname;
  final String? fullName;
  final String? photoUrl;
  final int? nursinghomeId;
  final int totalPoints;
  final int weekPoints;
  final int monthPoints;
  final int transactionCount;

  // Tier info
  final String? tierId;
  final String? tierName;
  final String? tierNameTh;
  final String? tierIcon;
  final String? tierColor;
  final String? nextTierName;
  final int? nextTierMinPoints;

  const UserPointsSummary({
    required this.userId,
    this.nickname,
    this.fullName,
    this.photoUrl,
    this.nursinghomeId,
    required this.totalPoints,
    required this.weekPoints,
    required this.monthPoints,
    required this.transactionCount,
    this.tierId,
    this.tierName,
    this.tierNameTh,
    this.tierIcon,
    this.tierColor,
    this.nextTierName,
    this.nextTierMinPoints,
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
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      tierId: json['tier_id'] as String?,
      tierName: json['tier_name'] as String?,
      tierNameTh: json['tier_name_th'] as String?,
      tierIcon: json['tier_icon'] as String?,
      tierColor: json['tier_color'] as String?,
      nextTierName: json['next_tier_name'] as String?,
      nextTierMinPoints: json['next_tier_min_points'] as int?,
    );
  }

  /// ชื่อ tier ที่แสดง
  String get tierDisplayName => tierNameTh ?? tierName ?? 'Bronze';

  /// Progress ไป tier ถัดไป (0.0 - 1.0)
  double get progressToNextTier {
    if (nextTierMinPoints == null) return 1.0;

    // หา current tier min points (ประมาณจาก tier name)
    final currentMin = _estimateCurrentTierMin();
    final nextMin = nextTierMinPoints!;
    final range = nextMin - currentMin;

    if (range <= 0) return 1.0;

    final progress = (totalPoints - currentMin) / range;
    return progress.clamp(0.0, 1.0);
  }

  int _estimateCurrentTierMin() {
    // ใช้ค่า default ตาม tier name
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
    if (nextTierMinPoints == null) return 0;
    return (nextTierMinPoints! - totalPoints).clamp(0, nextTierMinPoints!);
  }

  /// ถึง tier สูงสุดแล้วหรือไม่
  bool get isMaxTier => nextTierMinPoints == null;
}
