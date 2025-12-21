/// Badge model สำหรับแสดงข้อมูล badge
class Badge {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String? imageUrl;
  final String category;
  final int points;
  final String rarity; // common, rare, epic, legendary
  final String requirementType;
  final Map<String, dynamic>? requirementValue;
  final bool isEarned;
  final DateTime? earnedAt;

  const Badge({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.imageUrl,
    this.category = 'general',
    this.points = 10,
    this.rarity = 'common',
    required this.requirementType,
    this.requirementValue,
    this.isEarned = false,
    this.earnedAt,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['badge_id'] as String,
      name: json['badge_name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String? ?? 'general',
      points: json['points'] as int? ?? 10,
      rarity: json['rarity'] as String? ?? 'common',
      requirementType: json['requirement_type'] as String,
      requirementValue: json['requirement_value'] as Map<String, dynamic>?,
      isEarned: json['is_earned'] as bool? ?? false,
      earnedAt: json['earned_at'] != null
          ? DateTime.parse(json['earned_at'] as String)
          : null,
    );
  }

  /// สร้าง Badge จาก training_badges table โดยตรง
  factory Badge.fromBadgeTable(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String? ?? 'general',
      points: json['points'] as int? ?? 10,
      rarity: json['rarity'] as String? ?? 'common',
      requirementType: json['requirement_type'] as String,
      requirementValue: json['requirement_value'] as Map<String, dynamic>?,
      isEarned: true,
      earnedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'badge_id': id,
      'badge_name': name,
      'description': description,
      'icon': icon,
      'image_url': imageUrl,
      'category': category,
      'points': points,
      'rarity': rarity,
      'requirement_type': requirementType,
      'requirement_value': requirementValue,
      'is_earned': isEarned,
      'earned_at': earnedAt?.toIso8601String(),
    };
  }

  /// Get rarity color
  String get rarityEmoji {
    switch (rarity) {
      case 'legendary':
        return '🏆';
      case 'epic':
        return '💎';
      case 'rare':
        return '⭐';
      default:
        return '🎖️';
    }
  }
}
