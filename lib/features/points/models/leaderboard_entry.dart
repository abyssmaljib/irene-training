// Model สำหรับ Leaderboard Entry
// แต่ละ row ใน leaderboard

/// Period สำหรับ filter leaderboard
enum LeaderboardPeriod {
  // "Season นี้" เป็น default — แสดงคะแนนตั้งแต่ season ปัจจุบันเริ่ม (รวม carry-over bonus)
  thisSeason('this_season', 'Season นี้'),
  thisWeek('this_week', 'สัปดาห์นี้'),
  thisMonth('this_month', 'เดือนนี้'),
  rolling3m('rolling_3m', '3 เดือน'), // Rolling 3-month window (ใช้คำนวณ tier percentile)
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

  // Percentile fields (จาก user_tier_cache)
  // null ถ้ายังไม่ได้คำนวณ หรือ period ไม่ใช่ rolling_3m
  final double? percentile;
  final int? rollingPoints; // คะแนนใน rolling 3-month window

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
    this.percentile,
    this.rollingPoints,
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
      // Percentile fields — null ถ้า DB ยังไม่มีข้อมูล
      percentile: (json['percentile'] as num?)?.toDouble(),
      rollingPoints: (json['rolling_points'] as num?)?.toInt(),
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

  /// แสดง percentile เช่น "Top 5.3%"
  /// null ถ้ายังไม่ได้คำนวณ
  String? get percentileDisplay {
    if (percentile == null) return null;
    final topPercent = (100 - percentile!).clamp(0, 100);
    if (topPercent < 1) return '#1';
    return 'Top ${topPercent.toStringAsFixed(topPercent == topPercent.roundToDouble() ? 0 : 1)}%';
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
