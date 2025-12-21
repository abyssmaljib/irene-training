class Topic {
  final String id;
  final String name;
  final String? type;
  final String? coverImageUrl;
  final int? displayOrder;
  final String? description;
  final bool? isRead;
  final String? quizStatus;

  Topic({
    required this.id,
    required this.name,
    this.type,
    this.coverImageUrl,
    this.displayOrder,
    this.description,
    this.isRead,
    this.quizStatus,
  });

  // แปลงจาก Map (ที่ได้จาก Supabase) เป็น Topic object
  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['Type'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      displayOrder: json['display_order'] as int?,
      description: json['description'] as String?,
      isRead: json['is_read'] as bool?,
      quizStatus: json['quiz_status'] as String?,
    );
  }
}
