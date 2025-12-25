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

  /// Get category display name (Thai)
  String get categoryDisplayName {
    switch (category) {
      case 'achievement':
        return 'ความสำเร็จ';
      case 'progress':
        return 'ความก้าวหน้า';
      case 'streak':
        return 'ความต่อเนื่อง';
      case 'milestone':
        return 'เหตุการณ์สำคัญ';
      case 'time':
        return 'เวลา';
      case 'fun':
        return 'สนุกสนาน';
      case 'speed':
        return 'ความเร็ว';
      case 'skill':
        return 'ทักษะ';
      default:
        return 'ทั่วไป';
    }
  }

  /// Get category icon
  String get categoryIcon {
    switch (category) {
      case 'achievement':
        return '🏅';
      case 'progress':
        return '📈';
      case 'streak':
        return '🔥';
      case 'milestone':
        return '🎯';
      case 'time':
        return '⏱️';
      case 'fun':
        return '🎉';
      case 'speed':
        return '⚡';
      case 'skill':
        return '🧠';
      default:
        return '📌';
    }
  }

  /// Get requirement description (Thai)
  String get requirementDescription {
    final value = requirementValue ?? {};
    switch (requirementType) {
      case 'perfect_score':
        return 'ได้คะแนนเต็ม 10/10';
      case 'high_score_count':
        final count = value['count'] ?? 3;
        final minScore = value['min_score'] ?? 8;
        return 'ได้คะแนน $minScore+ จำนวน $count ครั้ง';
      case 'first_try':
        return 'ผ่านการทดสอบตั้งแต่ครั้งแรก';
      case 'first_try_count':
        final count = value['count'] ?? 5;
        return 'ผ่านตั้งแต่ครั้งแรก $count หัวข้อ';
      case 'streak':
        final days = value['days'] ?? 7;
        return 'เข้าเรียนติดต่อกัน $days วัน';
      case 'topics_completed':
        final count = value['count'] ?? 10;
        return 'ผ่านการทดสอบ $count หัวข้อ';
      case 'review_count':
        final count = value['count'] ?? 10;
        return 'ทบทวนครบ $count ครั้ง';
      case 'speed_demon':
        final maxSec = value['max_seconds'] ?? 300;
        final mins = maxSec ~/ 60;
        return 'ทำเสร็จภายใน $mins นาที';
      case 'quiz_time_green':
        return 'ทำข้อสอบเสร็จในโซนสีเขียว (<10 นาที)';
      case 'quiz_time_orange':
        return 'ทำข้อสอบเสร็จในโซนสีส้ม (10-15 นาที)';
      case 'quiz_time_red':
        return 'ทำข้อสอบเสร็จในโซนสีแดง (>15 นาที)';
      case 'night_owl':
        return 'ทำข้อสอบหลังเที่ยงคืน';
      case 'early_bird':
        return 'ทำข้อสอบก่อน 6 โมงเช้า';
      case 'weekend_warrior':
        return 'ทำข้อสอบในวันหยุดสุดสัปดาห์';
      default:
        return description ?? 'เงื่อนไขพิเศษ';
    }
  }
}

/// Badge info with stats
class BadgeInfo {
  final Badge badge;
  final int earnedCount;
  final int totalUsers;
  final bool isEarnedByCurrentUser;

  const BadgeInfo({
    required this.badge,
    required this.earnedCount,
    required this.totalUsers,
    this.isEarnedByCurrentUser = false,
  });

  double get earnedPercent =>
      totalUsers > 0 ? (earnedCount / totalUsers * 100) : 0;
}

/// Badge statistics
class BadgeStats {
  final List<BadgeInfo> badges;
  final Map<String, List<BadgeInfo>> byCategory;
  final Map<String, List<BadgeInfo>> byRarity;
  final int totalBadges;
  final int totalUsers;
  final Set<String> earnedBadgeIds;

  const BadgeStats({
    required this.badges,
    required this.byCategory,
    required this.byRarity,
    required this.totalBadges,
    required this.totalUsers,
    this.earnedBadgeIds = const {},
  });

  int get earnedCount => earnedBadgeIds.length;
}
