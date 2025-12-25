class Zone {
  final int id;
  final int nursinghomeId;
  final String name;
  final int residentCount;

  const Zone({
    required this.id,
    required this.nursinghomeId,
    required this.name,
    this.residentCount = 0,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      id: json['zone_id'] as int? ?? json['id'] as int,
      nursinghomeId: json['nursinghome_id'] as int,
      name: json['zone_name'] as String? ?? json['zone'] as String? ?? '-',
      residentCount: json['resident_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nursinghome_id': nursinghomeId,
      'zone': name,
      'resident_count': residentCount,
    };
  }
}
