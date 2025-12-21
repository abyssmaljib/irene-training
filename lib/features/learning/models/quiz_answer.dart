class QuizAnswer {
  final String? id;
  final String sessionId;
  final String questionId;
  final String selectedChoice;
  final bool isCorrect;
  final int? answerTimeSeconds;
  final DateTime? answeredAt;

  const QuizAnswer({
    this.id,
    required this.sessionId,
    required this.questionId,
    required this.selectedChoice,
    required this.isCorrect,
    this.answerTimeSeconds,
    this.answeredAt,
  });

  factory QuizAnswer.fromJson(Map<String, dynamic> json) {
    return QuizAnswer(
      id: json['id'] as String?,
      sessionId: json['session_id'] as String,
      questionId: json['question_id'] as String,
      selectedChoice: json['selected_choice'] as String,
      isCorrect: json['is_correct'] as bool? ?? false,
      answerTimeSeconds: json['answer_time_seconds'] as int?,
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'question_id': questionId,
      'selected_choice': selectedChoice,
      'is_correct': isCorrect,
      if (answerTimeSeconds != null) 'answer_time_seconds': answerTimeSeconds,
    };
  }
}
