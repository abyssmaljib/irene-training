// Model สำหรับ Point Reward
// Virtual rewards เช่น titles, badges พิเศษที่ user สามารถปลดล็อคได้

/// ประเภทของ reward
enum RewardType {
  title('title', 'ตำแหน่ง'),
  badge('badge', 'เหรียญพิเศษ'),
  frame('frame', 'กรอบรูป');

  final String value;
  final String displayName;

  const RewardType(this.value, this.displayName);

  static RewardType fromString(String? value) {
    return RewardType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RewardType.title,
    );
  }
}

/// เงื่อนไขการปลดล็อค reward
class UnlockCondition {
  final String type; // 'tier', 'points', 'badge_count', 'quiz_count'
  final String? tierId;
  final int? minPoints;
  final int? minCount;

  const UnlockCondition({
    required this.type,
    this.tierId,
    this.minPoints,
    this.minCount,
  });

  factory UnlockCondition.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UnlockCondition(type: 'none');
    }
    return UnlockCondition(
      type: json['type'] as String? ?? 'none',
      tierId: json['tier_id'] as String?,
      minPoints: json['min'] as int? ?? json['min_points'] as int?,
      minCount: json['count'] as int? ?? json['min_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (tierId != null) 'tier_id': tierId,
      if (minPoints != null) 'min': minPoints,
      if (minCount != null) 'count': minCount,
    };
  }

  /// คำอธิบายเงื่อนไข
  String get description {
    switch (type) {
      case 'tier':
        return 'ถึงระดับ $tierId';
      case 'points':
        return 'สะสม ${minPoints ?? 0} คะแนน';
      case 'badge_count':
        return 'สะสม ${minCount ?? 0} เหรียญ';
      case 'quiz_count':
        return 'สอบผ่าน ${minCount ?? 0} หัวข้อ';
      default:
        return 'ปลดล็อคอัตโนมัติ';
    }
  }
}

/// Model สำหรับ Reward
class PointReward {
  final String id;
  final String name;
  final String? nameTh;
  final String? description;
  final RewardType type;
  final String? icon;
  final UnlockCondition? unlockCondition;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;

  const PointReward({
    required this.id,
    required this.name,
    this.nameTh,
    this.description,
    required this.type,
    this.icon,
    this.unlockCondition,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory PointReward.fromJson(Map<String, dynamic> json) {
    return PointReward(
      id: json['id'] as String,
      name: json['name'] as String,
      nameTh: json['name_th'] as String?,
      description: json['description'] as String?,
      type: RewardType.fromString(json['type'] as String?),
      icon: json['icon'] as String?,
      unlockCondition: json['unlock_condition'] != null
          ? UnlockCondition.fromJson(
              json['unlock_condition'] as Map<String, dynamic>,
            )
          : null,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_th': nameTh,
      'description': description,
      'type': type.value,
      'icon': icon,
      'unlock_condition': unlockCondition?.toJson(),
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }

  /// ชื่อที่แสดง
  String get displayName => nameTh ?? name;
}

/// Reward ที่ user ได้รับแล้ว
class UserReward {
  final String id;
  final String userId;
  final String rewardId;
  final DateTime unlockedAt;
  final bool isEquipped;

  // Reward details (จาก JOIN)
  final PointReward? reward;

  const UserReward({
    required this.id,
    required this.userId,
    required this.rewardId,
    required this.unlockedAt,
    this.isEquipped = false,
    this.reward,
  });

  factory UserReward.fromJson(Map<String, dynamic> json) {
    return UserReward(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      rewardId: json['reward_id'] as String,
      unlockedAt: DateTime.parse(json['unlocked_at'] as String),
      isEquipped: json['is_equipped'] as bool? ?? false,
      reward: json['point_rewards'] != null
          ? PointReward.fromJson(json['point_rewards'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Reward พร้อมสถานะว่า user ได้รับหรือยัง
class RewardWithStatus {
  final PointReward reward;
  final bool isUnlocked;
  final bool isEquipped;
  final DateTime? unlockedAt;

  const RewardWithStatus({
    required this.reward,
    required this.isUnlocked,
    this.isEquipped = false,
    this.unlockedAt,
  });
}
