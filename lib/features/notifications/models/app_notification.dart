/// Notification model for the app
/// Named AppNotification to avoid conflict with Flutter's Notification class
class AppNotification {
  final int id;
  final String title;
  final String body;
  final String userId;
  final bool isRead;
  final DateTime createdAt;
  final NotificationType type;
  final int? referenceId;
  final String? referenceTable;
  final String? imageUrl;
  final String? actionUrl;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
    required this.isRead,
    required this.createdAt,
    this.type = NotificationType.system,
    this.referenceId,
    this.referenceTable,
    this.imageUrl,
    this.actionUrl,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      userId: json['user_id'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      type: NotificationType.fromString(json['type'] as String?),
      referenceId: json['reference_id'] as int?,
      referenceTable: json['reference_table'] as String?,
      imageUrl: json['image_url'] as String?,
      actionUrl: json['action_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'user_id': userId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'type': type.value,
      'reference_id': referenceId,
      'reference_table': referenceTable,
      'image_url': imageUrl,
      'action_url': actionUrl,
    };
  }

  AppNotification copyWith({
    int? id,
    String? title,
    String? body,
    String? userId,
    bool? isRead,
    DateTime? createdAt,
    NotificationType? type,
    int? referenceId,
    String? referenceTable,
    String? imageUrl,
    String? actionUrl,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      userId: userId ?? this.userId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      referenceId: referenceId ?? this.referenceId,
      referenceTable: referenceTable ?? this.referenceTable,
      imageUrl: imageUrl ?? this.imageUrl,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }

  /// Get relative time string (e.g., "5 นาทีที่แล้ว")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'เมื่อสักครู่';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} วันที่แล้ว';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks สัปดาห์ที่แล้ว';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months เดือนที่แล้ว';
    }
  }
}

/// Notification types enum
enum NotificationType {
  post('post'),
  task('task'),
  calendar('calendar'),
  badge('badge'),
  comment('comment'),
  system('system'),
  review('review'),
  assignment('assignment');  // การมอบหมายผู้รับบริการ

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.system,
    );
  }

  /// Get display name in Thai
  String get displayName {
    switch (this) {
      case NotificationType.post:
        return 'โพสต์';
      case NotificationType.task:
        return 'งาน';
      case NotificationType.calendar:
        return 'นัดหมาย';
      case NotificationType.badge:
        return 'เหรียญรางวัล';
      case NotificationType.comment:
        return 'ความคิดเห็น';
      case NotificationType.system:
        return 'ระบบ';
      case NotificationType.review:
        return 'ทบทวน';
      case NotificationType.assignment:
        return 'มอบหมายงาน';
    }
  }
}
