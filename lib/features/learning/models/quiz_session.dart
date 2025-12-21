class QuizSession {
  final String id;
  final String userId;
  final String topicId;
  final String seasonId;
  final String progressId;
  final String quizType; // 'posttest' or 'review'
  final int attemptNumber;
  final int score;
  final int totalQuestions;
  final int passingScore;
  final int timeLimitSeconds;
  final List<String> questionIds;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool? isPassed;
  final int? durationSeconds;

  const QuizSession({
    required this.id,
    required this.userId,
    required this.topicId,
    required this.seasonId,
    required this.progressId,
    required this.quizType,
    this.attemptNumber = 1,
    this.score = 0,
    this.totalQuestions = 20,
    this.passingScore = 16,
    this.timeLimitSeconds = 600,
    required this.questionIds,
    required this.startedAt,
    this.completedAt,
    this.isPassed,
    this.durationSeconds,
  });

  factory QuizSession.fromJson(Map<String, dynamic> json) {
    return QuizSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      topicId: json['topic_id'] as String,
      seasonId: json['season_id'] as String,
      progressId: json['progress_id'] as String,
      quizType: json['quiz_type'] as String,
      attemptNumber: json['attempt_number'] as int? ?? 1,
      score: json['score'] as int? ?? 0,
      totalQuestions: json['total_questions'] as int? ?? 20,
      passingScore: json['passing_score'] as int? ?? 16,
      timeLimitSeconds: json['time_limit_seconds'] as int? ?? 600,
      questionIds: (json['question_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      isPassed: json['is_passed'] as bool?,
      durationSeconds: json['duration_seconds'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'topic_id': topicId,
      'season_id': seasonId,
      'progress_id': progressId,
      'quiz_type': quizType,
      'attempt_number': attemptNumber,
      'score': score,
      'total_questions': totalQuestions,
      'passing_score': passingScore,
      'time_limit_seconds': timeLimitSeconds,
      'question_ids': questionIds,
      'started_at': startedAt.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    };
  }

  double get scorePercent =>
      totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;

  bool get passed => isPassed ?? (score >= passingScore);

  QuizSession copyWith({
    int? score,
    DateTime? completedAt,
    bool? isPassed,
    int? durationSeconds,
  }) {
    return QuizSession(
      id: id,
      userId: userId,
      topicId: topicId,
      seasonId: seasonId,
      progressId: progressId,
      quizType: quizType,
      attemptNumber: attemptNumber,
      score: score ?? this.score,
      totalQuestions: totalQuestions,
      passingScore: passingScore,
      timeLimitSeconds: timeLimitSeconds,
      questionIds: questionIds,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      isPassed: isPassed ?? this.isPassed,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
