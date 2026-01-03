/// Model สำหรับ tag ใหม่จาก new_tags table
class NewTag {
  final int id;
  final String name;
  final String? icon;
  final String? emoji;
  final String handoverMode; // 'force' | 'optional' | 'none'
  final List<String>? legacyTags;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;

  const NewTag({
    required this.id,
    required this.name,
    this.icon,
    this.emoji,
    required this.handoverMode,
    this.legacyTags,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
  });

  /// บังคับส่งเวร - เปิดอัตโนมัติ ปิดไม่ได้
  bool get isForceHandover => handoverMode == 'force';

  /// เลือกส่งเวรได้ - toggle on/off (รวม 'none' ด้วย เพราะทุก tag สามารถส่งเวรได้)
  bool get isOptionalHandover => handoverMode == 'optional' || handoverMode == 'none';

  /// Default เปิด handover หรือไม่ (force = เปิด, optional/none = ปิด)
  bool get defaultHandover => isForceHandover;

  /// Display text with emoji
  String get displayName => emoji != null ? '$emoji $name' : name;

  factory NewTag.fromJson(Map<String, dynamic> json) {
    // Parse legacy_tags from JSON string or array
    List<String>? parseLegacyTags(dynamic value) {
      if (value == null) return null;
      if (value is List) return value.cast<String>();
      if (value is String) {
        // Parse JSON string like '["tag1","tag2"]'
        try {
          final trimmed = value.trim();
          if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
            // Simple parsing for ["tag1","tag2"] format
            final inner = trimmed.substring(1, trimmed.length - 1);
            if (inner.isEmpty) return [];
            return inner
                .split(',')
                .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
                .where((s) => s.isNotEmpty)
                .toList();
          }
        } catch (_) {}
      }
      return null;
    }

    return NewTag(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      emoji: json['emoji'] as String?,
      handoverMode: json['handover_mode'] as String? ?? 'none',
      legacyTags: parseLegacyTags(json['legacy_tags']),
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'emoji': emoji,
      'handover_mode': handoverMode,
      'legacy_tags': legacyTags,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewTag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NewTag(id: $id, name: $name, handoverMode: $handoverMode)';
}
