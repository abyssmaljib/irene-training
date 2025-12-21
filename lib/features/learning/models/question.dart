class Choice {
  final String key;
  final String text;
  final bool isCorrect;

  const Choice({
    required this.key,
    required this.text,
    required this.isCorrect,
  });

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      key: json['key'] as String,
      text: json['text'] as String,
      isCorrect: json['is_correct'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'text': text,
      'is_correct': isCorrect,
    };
  }
}

class Question {
  final String id;
  final String topicId;
  final String? seasonId;
  final String questionText;
  final String? questionImageUrl;
  final List<Choice> choices;
  final String? explanation;
  final String? explanationImageUrl;
  final int difficulty;
  final String? thinkingType;
  final List<String>? tags;

  const Question({
    required this.id,
    required this.topicId,
    this.seasonId,
    required this.questionText,
    this.questionImageUrl,
    required this.choices,
    this.explanation,
    this.explanationImageUrl,
    this.difficulty = 2,
    this.thinkingType,
    this.tags,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final choicesJson = json['choices'] as List<dynamic>;
    final choices = choicesJson
        .map((c) => Choice.fromJson(c as Map<String, dynamic>))
        .toList();

    return Question(
      id: json['id'] as String,
      topicId: json['topic_id'] as String,
      seasonId: json['season_id'] as String?,
      questionText: json['question_text'] as String,
      questionImageUrl: json['question_image_url'] as String?,
      choices: choices,
      explanation: json['explanation'] as String?,
      explanationImageUrl: json['explanation_image_url'] as String?,
      difficulty: json['difficulty'] as int? ?? 2,
      thinkingType: json['thinking_type'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Choice get correctChoice => choices.firstWhere((c) => c.isCorrect);

  bool isCorrectAnswer(String choiceKey) {
    return choices.any((c) => c.key == choiceKey && c.isCorrect);
  }
}
