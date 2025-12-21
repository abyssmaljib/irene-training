/// Represents a single thinking skill category with performance data
class ThinkingSkillCategory {
  final String type;
  final int total;
  final int correct;
  final double percent;

  const ThinkingSkillCategory({
    required this.type,
    required this.total,
    required this.correct,
    required this.percent,
  });

  factory ThinkingSkillCategory.fromJson(String type, Map<String, dynamic> json) {
    return ThinkingSkillCategory(
      type: type,
      total: (json['total'] as num?)?.toInt() ?? 0,
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Normalized value for radar chart (0.0 - 1.0)
  double get normalizedValue => percent / 100.0;
}

/// Aggregated thinking skills data for visualization
class ThinkingSkillsData {
  final ThinkingSkillCategory? analysis;
  final ThinkingSkillCategory? prioritization;
  final ThinkingSkillCategory? riskAssessment;
  final ThinkingSkillCategory? reasoning;
  final ThinkingSkillCategory? uncertainty;
  final ThinkingSkillCategory? knowledge;

  const ThinkingSkillsData({
    this.analysis,
    this.prioritization,
    this.riskAssessment,
    this.reasoning,
    this.uncertainty,
    this.knowledge,
  });

  factory ThinkingSkillsData.fromThinkingBreakdown(Map<String, dynamic>? breakdown) {
    if (breakdown == null) return const ThinkingSkillsData();

    return ThinkingSkillsData(
      analysis: breakdown['analysis'] != null
          ? ThinkingSkillCategory.fromJson('analysis', breakdown['analysis'] as Map<String, dynamic>)
          : null,
      prioritization: breakdown['prioritization'] != null
          ? ThinkingSkillCategory.fromJson('prioritization', breakdown['prioritization'] as Map<String, dynamic>)
          : null,
      riskAssessment: breakdown['risk_assessment'] != null
          ? ThinkingSkillCategory.fromJson('risk_assessment', breakdown['risk_assessment'] as Map<String, dynamic>)
          : null,
      reasoning: breakdown['reasoning'] != null
          ? ThinkingSkillCategory.fromJson('reasoning', breakdown['reasoning'] as Map<String, dynamic>)
          : null,
      uncertainty: breakdown['uncertainty'] != null
          ? ThinkingSkillCategory.fromJson('uncertainty', breakdown['uncertainty'] as Map<String, dynamic>)
          : null,
      knowledge: breakdown['knowledge'] != null
          ? ThinkingSkillCategory.fromJson('knowledge', breakdown['knowledge'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Get the 5 pentagon categories (excludes knowledge)
  List<ThinkingSkillCategory> get pentagonCategories {
    return [
      analysis ?? const ThinkingSkillCategory(type: 'analysis', total: 0, correct: 0, percent: 0),
      prioritization ?? const ThinkingSkillCategory(type: 'prioritization', total: 0, correct: 0, percent: 0),
      riskAssessment ?? const ThinkingSkillCategory(type: 'risk_assessment', total: 0, correct: 0, percent: 0),
      reasoning ?? const ThinkingSkillCategory(type: 'reasoning', total: 0, correct: 0, percent: 0),
      uncertainty ?? const ThinkingSkillCategory(type: 'uncertainty', total: 0, correct: 0, percent: 0),
    ];
  }

  /// Check if there is any data to display
  bool get hasData {
    return analysis != null ||
        prioritization != null ||
        riskAssessment != null ||
        reasoning != null ||
        uncertainty != null;
  }

  /// Knowledge category percentage for badge
  double get knowledgePercent => knowledge?.percent ?? 0.0;
  bool get hasKnowledge => knowledge != null && knowledge!.total > 0;
}
