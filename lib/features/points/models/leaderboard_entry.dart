// Model สำหรับ Leaderboard Entry
// แต่ละ row ใน leaderboard

/// Period สำหรับ filter leaderboard
enum LeaderboardPeriod {
  thisWeek('this_week', 'สัปดาห์นี้'),
  thisMonth('this_month', 'เดือนนี้'),
  allTime('all_time', 'ทั้งหมด');

  final String value;
  final String displayName;

  const LeaderboardPeriod(this.value, this.displayName);
}

/// Entry ใน Leaderboard
class LeaderboardEntry {
  final String userId;
  final String? nickname;
  final String? fullName;
  final String? photoUrl;
  final int? nursinghomeId;
  final int totalPoints;
  final String? tierName;
  final String? tierIcon;
  final String? tierColor;
  final int rank;

  const LeaderboardEntry({
    required this.userId,
    this.nickname,
    this.fullName,
    this.photoUrl,
    this.nursinghomeId,
    required this.totalPoints,
    this.tierName,
    this.tierIcon,
    this.tierColor,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] as String,
      nickname: json['nickname'] as String?,
      fullName: json['full_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      nursinghomeId: json['nursinghome_id'] as int?,
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      tierName: json['tier_name'] as String?,
      tierIcon: json['tier_icon'] as String?,
      tierColor: json['tier_color'] as String?,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
    );
  }

  /// ชื่อที่แสดง (ใช้ nickname ก่อน)
  String get displayName => nickname ?? fullName ?? 'ไม่ระบุชื่อ';

  /// ว่าอยู่ top 3 หรือไม่
  bool get isTopThree => rank >= 1 && rank <= 3;

  /// Icon สำหรับ rank (เฉพาะ top 3)
  String? get rankIcon {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return null;
    }
  }

  @override
  String toString() =>
      'LeaderboardEntry(rank: $rank, name: $displayName, points: $totalPoints)';
}

/// ข้อมูล Leaderboard รวม
class LeaderboardData {
  final LeaderboardPeriod period;
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUser;
  final int? currentUserRank;

  const LeaderboardData({
    required this.period,
    required this.entries,
    this.currentUser,
    this.currentUserRank,
  });

  /// Top 3 users
  List<LeaderboardEntry> get topThree =>
      entries.where((e) => e.isTopThree).toList();

  /// Users นอก top 3
  List<LeaderboardEntry> get restOfList =>
      entries.where((e) => !e.isTopThree).toList();

  /// จำนวน users ทั้งหมด
  int get totalUsers => entries.length;

  /// ว่า current user อยู่ใน top 10 หรือไม่
  bool get isCurrentUserInTopTen =>
      currentUserRank != null && currentUserRank! <= 10;
}
