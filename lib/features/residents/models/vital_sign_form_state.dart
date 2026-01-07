/// State model for Vital Sign creation/edit form (Lean single-page design)
class VitalSignFormState {
  // Edit mode
  final int? vitalSignId; // null = create mode, non-null = edit mode

  // Meta
  final bool isFullReport; // true = ฉบับเต็ม, false = ฉบับย่อ
  final DateTime selectedDateTime;
  final String shift; // 'เวรเช้า' | 'เวรดึก'

  // Vital signs (as String for text field controllers)
  final String? temp;
  final String? rr;
  final String? o2;
  final String? sBP;
  final String? dBP;
  final String? pr;
  final String? dtx;
  final String? insulin;

  // Care activities
  final String? input;
  final String? output;
  final String? napkin;
  final bool defecation;
  final String? constipation;

  // Ratings & Report
  final Map<int, RatingData> ratings; // relationId -> rating data
  final String? reportD; // เวรเช้า report
  final String? reportN; // เวรดึก report

  // UI state
  final bool isLoading;
  final String? errorMessage;

  VitalSignFormState({
    this.vitalSignId,
    this.isFullReport = true,
    required this.selectedDateTime,
    required this.shift,
    this.temp,
    this.rr,
    this.o2,
    this.sBP,
    this.dBP,
    this.pr,
    this.dtx,
    this.insulin,
    this.input,
    this.output,
    this.napkin,
    this.defecation = true,
    this.constipation,
    this.ratings = const {},
    this.reportD,
    this.reportN,
    this.isLoading = false,
    this.errorMessage,
  });

  VitalSignFormState copyWith({
    int? vitalSignId,
    bool? isFullReport,
    DateTime? selectedDateTime,
    String? shift,
    String? temp,
    String? rr,
    String? o2,
    String? sBP,
    String? dBP,
    String? pr,
    String? dtx,
    String? insulin,
    String? input,
    String? output,
    String? napkin,
    bool? defecation,
    String? constipation,
    Map<int, RatingData>? ratings,
    String? reportD,
    String? reportN,
    bool? isLoading,
    String? errorMessage,
  }) {
    return VitalSignFormState(
      vitalSignId: vitalSignId ?? this.vitalSignId,
      isFullReport: isFullReport ?? this.isFullReport,
      selectedDateTime: selectedDateTime ?? this.selectedDateTime,
      shift: shift ?? this.shift,
      temp: temp ?? this.temp,
      rr: rr ?? this.rr,
      o2: o2 ?? this.o2,
      sBP: sBP ?? this.sBP,
      dBP: dBP ?? this.dBP,
      pr: pr ?? this.pr,
      dtx: dtx ?? this.dtx,
      insulin: insulin ?? this.insulin,
      input: input ?? this.input,
      output: output ?? this.output,
      napkin: napkin ?? this.napkin,
      defecation: defecation ?? this.defecation,
      constipation: constipation ?? this.constipation,
      ratings: ratings ?? this.ratings,
      reportD: reportD ?? this.reportD,
      reportN: reportN ?? this.reportN,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Validate that all ratings have been filled (only for full report)
  bool get allRatingsComplete {
    if (!isFullReport) return true; // Skip validation for abbreviated report
    if (ratings.isEmpty) return true; // No ratings required
    return ratings.values.every((r) => r.rating != null && r.rating! > 0);
  }

  /// Check if this is edit mode
  bool get isEditMode => vitalSignId != null;
}

/// Data for a single rating subject
class RatingData {
  final int relationId;
  final int subjectId;
  final String subjectName;
  final String? subjectDescription;
  final List<String>? choices; // Choice texts for ratings 1-5 (e.g., ["แย่มาก", "แย่", "ปานกลาง", "ดี", "ดีมาก"])
  final int? rating; // 1-5 stars
  final String? description; // Optional text note

  RatingData({
    required this.relationId,
    required this.subjectId,
    required this.subjectName,
    this.subjectDescription,
    this.choices,
    this.rating,
    this.description,
  });

  RatingData copyWith({
    int? rating,
    String? description,
  }) {
    return RatingData(
      relationId: relationId,
      subjectId: subjectId,
      subjectName: subjectName,
      subjectDescription: subjectDescription,
      choices: choices,
      rating: rating ?? this.rating,
      description: description ?? this.description,
    );
  }

  bool get isComplete => rating != null && rating! > 0;

  /// Get the choice text for current rating (null if no rating or no choices available)
  String? get selectedChoiceText {
    if (rating == null || rating! < 1 || choices == null || choices!.isEmpty) {
      return null;
    }
    final index = rating! - 1; // rating 1-5 -> index 0-4
    if (index < 0 || index >= choices!.length) return null;
    return choices![index];
  }
}
