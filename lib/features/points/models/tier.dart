// Model สำหรับ Point Tier
// แต่ละ tier มี threshold คะแนนขั้นต่ำ
// User จะอยู่ใน tier ที่ min_points <= total_points

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
    };
  }

  /// ชื่อที่แสดง (ใช้ภาษาไทยถ้ามี)
  String get displayName => nameTh ?? name;

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
  String toString() => 'Tier(name: $name, minPoints: $minPoints)';
}

/// ข้อมูล tier ของ user พร้อม progress ไป tier ถัดไป
class UserTierInfo {
  final Tier currentTier;
  final Tier? nextTier;
  final int totalPoints;

  const UserTierInfo({
    required this.currentTier,
    this.nextTier,
    required this.totalPoints,
  });

  /// สร้างจาก get_user_tier function result
  factory UserTierInfo.fromJson(Map<String, dynamic> json) {
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
    );
  }

  /// Progress ไป tier ถัดไป (0.0 - 1.0)
  /// ถ้าไม่มี next tier = 1.0 (max)
  double get progressToNextTier {
    if (nextTier == null) return 1.0;

    final currentMin = currentTier.minPoints;
    final nextMin = nextTier!.minPoints;
    final range = nextMin - currentMin;

    if (range <= 0) return 1.0;

    final progress = (totalPoints - currentMin) / range;
    return progress.clamp(0.0, 1.0);
  }

  /// Points ที่ต้องการเพื่อไป tier ถัดไป
  int get pointsToNextTier {
    if (nextTier == null) return 0;
    return (nextTier!.minPoints - totalPoints).clamp(0, nextTier!.minPoints);
  }

  /// ถึง tier สูงสุดแล้วหรือไม่
  bool get isMaxTier => nextTier == null;
}
