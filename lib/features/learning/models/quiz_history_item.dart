class QuizHistoryItem {
  final String sessionId;
  final String userId;
  final String topicId;
  final String topicName;
  final String? coverImageUrl;
  final String seasonId;
  final String seasonName;
  final String progressId;
  final String quizType;
  final int attemptNumber;
  final int score;
  final int totalQuestions;
  final int passingScore;
  final bool isPassed;
  final int? timeLimitSeconds;
  final int? durationSeconds;
  final DateTime startedAt;
  final DateTime completedAt;
  final double scorePercent;
  final Map<String, dynamic>? thinkingBreakdown;

  const QuizHistoryItem({
    required this.sessionId,
    required this.userId,
    required this.topicId,
    required this.topicName,
    this.coverImageUrl,
    required this.seasonId,
    required this.seasonName,
    required this.progressId,
    required this.quizType,
    this.attemptNumber = 1,
    required this.score,
    required this.totalQuestions,
    required this.passingScore,
    required this.isPassed,
    this.timeLimitSeconds,
    this.durationSeconds,
    required this.startedAt,
    required this.completedAt,
    required this.scorePercent,
    this.thinkingBreakdown,
  });

  factory QuizHistoryItem.fromJson(Map<String, dynamic> json) {
    return QuizHistoryItem(
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      topicId: json['topic_id'] as String,
      topicName: json['topic_name'] as String,
      coverImageUrl: json['cover_image_url'] as String?,
      seasonId: json['season_id'] as String,
      seasonName: json['season_name'] as String,
      progressId: json['progress_id'] as String,
      quizType: json['quiz_type'] as String,
      attemptNumber: json['attempt_number'] as int? ?? 1,
      score: json['score'] as int,
      totalQuestions: json['total_questions'] as int,
      passingScore: json['passing_score'] as int,
      isPassed: json['is_passed'] as bool,
      timeLimitSeconds: json['time_limit_seconds'] as int?,
      durationSeconds: json['duration_seconds'] as int?,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: DateTime.parse(json['completed_at'] as String),
      scorePercent: (json['score_percent'] as num?)?.toDouble() ?? 0.0,
      thinkingBreakdown: json['thinking_breakdown'] as Map<String, dynamic>?,
    );
  }

  String get formattedScore => '$score/$totalQuestions';

  /// แสดงวันที่เป็นปี ค.ศ. (Christian Era)
  String get formattedDate {
    final months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    return '${completedAt.day} ${months[completedAt.month - 1]} ${completedAt.year}';
  }

  String get formattedDuration {
    if (durationSeconds == null) return '-';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get quizTypeDisplay => quizType == 'posttest' ? 'แบบทดสอบ' : 'ทบทวน';
}
