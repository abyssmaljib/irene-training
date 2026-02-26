// Model สำหรับ Point Tier
// รองรับทั้ง fixed threshold (เดิม) และ percentile-based (ใหม่)
// percentile mode: tier กำหนดจาก % ranking ใน rolling 3-month window

class Tier {
  final String id;
  final String name;
  final String? nameTh;
  final int minPoints;
  final String? icon;
  final String? color;
  final List<String>? benefits;
  final int sortOrder;
  final bool isActive;

  // Percentile mode fields (ใหม่)
  // tierType = 'percentile' หมายถึงใช้ percentile ranking แทน fixed threshold
  final String tierType; // 'fixed' หรือ 'percentile'
  final double? percentileMin; // เช่น 95 สำหรับ Diamond (Top 5%)
  final double? percentileMax; // เช่น 100 สำหรับ Diamond

  const Tier({
    required this.id,
    required this.name,
    this.nameTh,
    required this.minPoints,
    this.icon,
    this.color,
    this.benefits,
    this.sortOrder = 0,
    this.isActive = true,
    this.tierType = 'fixed',
    this.percentileMin,
    this.percentileMax,
  });

  /// สร้าง Tier จาก JSON (Supabase response)
  factory Tier.fromJson(Map<String, dynamic> json) {
    return Tier(
      id: json['id'] as String,
      name: json['name'] as String,
      nameTh: json['name_th'] as String?,
      minPoints: json['min_points'] as int? ?? 0,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      benefits: (json['benefits'] as List<dynamic>?)?.cast<String>(),
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      tierType: json['tier_type'] as String? ?? 'fixed',
      percentileMin: (json['percentile_min'] as num?)?.toDouble(),
      percentileMax: (json['percentile_max'] as num?)?.toDouble(),
    );
  }

  /// แปลงเป็น JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_th': nameTh,
      'min_points': minPoints,
      'icon': icon,
      'color': color,
      'benefits': benefits,
      'sort_order': sortOrder,
      'is_active': isActive,
      'tier_type': tierType,
      'percentile_min': percentileMin,
      'percentile_max': percentileMax,
    };
  }

  /// ชื่อที่แสดง (ใช้ภาษาไทยถ้ามี)
  String get displayName => nameTh ?? name;

  /// เช็คว่าเป็น percentile mode หรือไม่
  bool get isPercentileMode => tierType == 'percentile';

  /// Default tier สำหรับ user ที่ยังไม่มี points
  static const Tier defaultTier = Tier(
    id: 'default',
    name: 'Bronze',
    nameTh: 'บรอนซ์',
    minPoints: 0,
    icon: '🥉',
    color: '#CD7F32',
    sortOrder: 1,
  );

  @override
  String toString() => 'Tier(name: $name, minPoints: $minPoints, type: $tierType)';
}

/// ข้อมูล tier ของ user พร้อม progress ไป tier ถัดไป
/// รองรับทั้ง fixed threshold และ percentile-based ranking
class UserTierInfo {
  final Tier currentTier;
  final Tier? nextTier;
  final int totalPoints;

  // Percentile-based fields (ใหม่)
  // ใช้สำหรับ ranking แบบ % — tier กำหนดจากตำแหน่งเทียบกับคนอื่น
  final String tierType; // 'fixed' หรือ 'percentile'
  final double? percentile; // Percentile ของ user (0-100), เช่น 94.7 = Top 5.3%
  final int? rollingPoints; // คะแนนใน rolling 3-month window
  final int? rankInCohort; // อันดับที่ (เช่น 2 = อันดับ 2)
  final int? cohortSize; // จำนวนคนทั้งหมดที่ eligible
  final int? pointsGapToNext; // คะแนนโดยประมาณที่ต้องเพิ่มเพื่อถึง tier ถัดไป

  const UserTierInfo({
    required this.currentTier,
    this.nextTier,
    required this.totalPoints,
    this.tierType = 'fixed',
    this.percentile,
    this.rollingPoints,
    this.rankInCohort,
    this.cohortSize,
    this.pointsGapToNext,
  });

  /// สร้างจาก get_user_tier function result
  /// รองรับทั้ง fixed (เดิม) และ percentile (ใหม่) response
  factory UserTierInfo.fromJson(Map<String, dynamic> json) {
    final type = json['tier_type'] as String? ?? 'fixed';

    return UserTierInfo(
      currentTier: Tier(
        id: json['tier_id'] as String? ?? 'default',
        name: json['tier_name'] as String? ?? 'Bronze',
        nameTh: json['tier_name_th'] as String?,
        minPoints: json['min_points'] as int? ?? 0,
        icon: json['tier_icon'] as String?,
        color: json['tier_color'] as String?,
      ),
      nextTier: json['next_tier_name'] != null
          ? Tier(
              id: 'next',
              name: json['next_tier_name'] as String,
              minPoints: json['next_tier_min_points'] as int? ?? 0,
            )
          : null,
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      // Percentile fields
      tierType: type,
      percentile: (json['percentile'] as num?)?.toDouble(),
      rollingPoints: (json['rolling_points'] as num?)?.toInt(),
      rankInCohort: (json['rank_in_cohort'] as num?)?.toInt(),
      cohortSize: (json['cohort_size'] as num?)?.toInt(),
      pointsGapToNext: (json['points_gap_to_next'] as num?)?.toInt(),
    );
  }

  /// เช็คว่าใช้ percentile mode หรือไม่
  bool get isPercentileMode => tierType == 'percentile';

  /// Progress ไป tier ถัดไป (0.0 - 1.0)
  /// - percentile mode: ใช้ gap ที่คำนวณไว้จาก DB
  /// - fixed mode: ใช้ min_points range เดิม
  double get progressToNextTier {
    if (nextTier == null) return 1.0;

    if (isPercentileMode && pointsGapToNext != null && rollingPoints != null) {
      // Percentile mode: คำนวณจาก rolling_points กับ gap
      // ถ้า gap = 0 แปลว่าเกือบถึงแล้ว
      if (pointsGapToNext == 0) return 0.95;
      // ดู progress จาก gap vs total needed
      // ถ้าคะแนนห่างจาก next tier 1000 และ gap ยังเหลือ 200
      // progress = 1 - (200/1000) = 0.8
      final totalNeeded = pointsGapToNext! + rollingPoints!;
      if (totalNeeded <= 0) return 0.5;
      return (rollingPoints! / totalNeeded).clamp(0.0, 0.99);
    }

    // Fixed mode (fallback)
    final currentMin = currentTier.minPoints;
    final nextMin = nextTier!.minPoints;
    final range = nextMin - currentMin;

    if (range <= 0) return 1.0;

    final progress = (totalPoints - currentMin) / range;
    return progress.clamp(0.0, 1.0);
  }

  /// Points ที่ต้องการเพื่อไป tier ถัดไป
  /// - percentile mode: ใช้ points_gap_to_next จาก DB
  /// - fixed mode: ใช้ next_tier_min_points - total_points
  int get pointsToNextTier {
    if (nextTier == null) return 0;

    if (isPercentileMode && pointsGapToNext != null) {
      return pointsGapToNext!.clamp(0, 999999);
    }

    // Fixed mode fallback
    return (nextTier!.minPoints - totalPoints).clamp(0, nextTier!.minPoints);
  }

  /// ถึง tier สูงสุดแล้วหรือไม่
  bool get isMaxTier => nextTier == null;

  /// แสดง percentile เป็นข้อความ เช่น "Top 5.3%"
  /// ถ้าไม่มีข้อมูล percentile จะ return null
  String? get percentileDisplay {
    if (percentile == null) return null;
    final topPercent = (100 - percentile!).clamp(0, 100);
    // ถ้า Top 0% (อันดับ 1) แสดงเป็น "#1"
    if (topPercent < 1) return '#1';
    return 'Top ${topPercent.toStringAsFixed(topPercent == topPercent.roundToDouble() ? 0 : 1)}%';
  }

  /// แสดงอันดับ เช่น "อันดับ 2 จาก 18 คน"
  String? get rankDisplay {
    if (rankInCohort == null || cohortSize == null) return null;
    return 'อันดับ $rankInCohort จาก $cohortSize คน';
  }
}