// Model สำหรับผลสรุป Season
// เก็บอันดับ, tier, คะแนน ณ จบ season
// พร้อมเปรียบเทียบกับ season ก่อน (แบบเกมออนไลน์)

class SeasonResult {
  final String id;
  final String seasonPeriodId;
  final String userId;

  // อันดับและ tier ณ จบ season
  final int finalRank;
  final String? finalTierName;
  final String? finalTierNameTh;
  final String? finalTierIcon;
  final String? finalTierColor;
  final double? finalPercentile;

  // คะแนน
  final int seasonPoints; // คะแนนที่ได้ใน season นี้
  final int totalPointsAtEnd; // คะแนนรวมทั้งหมด ณ ตอนจบ
  final int transactionCount; // จำนวน transactions ใน season

  // เปรียบเทียบกับ season ก่อน
  final int? prevSeasonRank; // อันดับ season ก่อน
  final String? prevSeasonTierName; // ชื่อ tier season ก่อน
  final int? rankChange; // + = ดีขึ้น (rank เลขน้อยลง), - = แย่ลง
  final bool tierChanged; // tier เปลี่ยนหรือไม่
  final String? tierDirection; // 'up', 'down', 'same'

  // ข้อมูล user (snapshot ตอนจบ season)
  final String? nickname;
  final String? fullName;
  final String? photoUrl;
  final int? nursinghomeId;

  final DateTime createdAt;

  const SeasonResult({
    required this.id,
    required this.seasonPeriodId,
    required this.userId,
    required this.finalRank,
    this.finalTierName,
    this.finalTierNameTh,
    this.finalTierIcon,
    this.finalTierColor,
    this.finalPercentile,
    required this.seasonPoints,
    required this.totalPointsAtEnd,
    required this.transactionCount,
    this.prevSeasonRank,
    this.prevSeasonTierName,
    this.rankChange,
    this.tierChanged = false,
    this.tierDirection,
    this.nickname,
    this.fullName,
    this.photoUrl,
    this.nursinghomeId,
    required this.createdAt,
  });

  /// สร้างจาก JSON (Supabase response)
  factory SeasonResult.fromJson(Map<String, dynamic> json) {
    return SeasonResult(
      id: json['id'] as String,
      seasonPeriodId: json['season_period_id'] as String,
      userId: json['user_id'] as String,
      finalRank: json['final_rank'] as int? ?? 0,
      finalTierName: json['final_tier_name'] as String?,
      finalTierNameTh: json['final_tier_name_th'] as String?,
      finalTierIcon: json['final_tier_icon'] as String?,
      finalTierColor: json['final_tier_color'] as String?,
      finalPercentile: (json['final_percentile'] as num?)?.toDouble(),
      seasonPoints: (json['season_points'] as num?)?.toInt() ?? 0,
      totalPointsAtEnd: (json['total_points_at_end'] as num?)?.toInt() ?? 0,
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      prevSeasonRank: (json['prev_season_rank'] as num?)?.toInt(),
      prevSeasonTierName: json['prev_season_tier_name'] as String?,
      rankChange: (json['rank_change'] as num?)?.toInt(),
      tierChanged: json['tier_changed'] as bool? ?? false,
      tierDirection: json['tier_direction'] as String?,
      nickname: json['nickname'] as String?,
      fullName: json['full_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      nursinghomeId: (json['nursinghome_id'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// ชื่อ tier ที่แสดง (ไทย ถ้ามี)
  String get tierDisplayName => finalTierNameTh ?? finalTierName ?? 'Bronze';

  /// แสดงผล percentile เช่น "Top 5.3%"
  String? get percentileDisplay {
    if (finalPercentile == null) return null;
    final topPercent = (100 - finalPercentile!).clamp(0, 100);
    if (topPercent < 1) return '#1';
    return 'Top ${topPercent.toStringAsFixed(topPercent == topPercent.roundToDouble() ? 0 : 1)}%';
  }

  /// เช็คว่า tier ขึ้นหรือลง
  bool get isTierUp => tierDirection == 'up';
  bool get isTierDown => tierDirection == 'down';
  bool get isTierSame => tierDirection == 'same' || tierDirection == null;

  /// เช็คว่าอันดับดีขึ้นหรือไม่ (rank เลขน้อยลง = ดีขึ้น)
  bool get isRankImproved => rankChange != null && rankChange! > 0;
  bool get isRankDeclined => rankChange != null && rankChange! < 0;

  /// แสดง rank change เป็นข้อความ เช่น "↑ 3", "↓ 2", "="
  String get rankChangeDisplay {
    if (rankChange == null) return 'ใหม่';
    if (rankChange! > 0) return '↑ $rankChange';
    if (rankChange! < 0) return '↓ ${rankChange!.abs()}';
    return '=';
  }

  @override
  String toString() =>
      'SeasonResult(rank: $finalRank, tier: $finalTierName, pts: $seasonPoints)';
}