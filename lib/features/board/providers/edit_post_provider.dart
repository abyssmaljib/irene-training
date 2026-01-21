import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../models/new_tag.dart';

/// State for Edit Post form
class EditPostState {
  final int postId;
  final String text;
  final String? title;

  /// Existing images (URLs from the post)
  final List<String> existingImageUrls;

  /// Indexes of existing images that user wants to remove
  final Set<int> removedExistingIndexes;

  /// New images to upload (local files)
  final List<File> newImages;

  final bool isSubmitting;
  final String? error;

  // AI Summary fields
  final bool isLoadingAI;
  final String? aiSummary;

  // Quiz fields
  final int? qaId; // existing QA id from post
  final String? qaQuestion;
  final String? qaChoiceA;
  final String? qaChoiceB;
  final String? qaChoiceC;
  final String? qaAnswer;

  // AI Quiz preview (before applying)
  final bool isLoadingQuizAI;
  final String? aiQuizQuestion;
  final String? aiQuizChoiceA;
  final String? aiQuizChoiceB;
  final String? aiQuizChoiceC;
  final String? aiQuizAnswer;

  // Tag and Resident fields (for shift leader+ editing)
  // Original values from post (for tracking changes)
  final int? originalResidentId;
  final String? originalResidentName;
  final String? originalTagName;
  // Current/edited values
  final int? residentId;
  final String? residentName;
  final NewTag? selectedTag;
  final bool isHandover;

  const EditPostState({
    required this.postId,
    this.text = '',
    this.title,
    this.existingImageUrls = const [],
    this.removedExistingIndexes = const {},
    this.newImages = const [],
    this.isSubmitting = false,
    this.error,
    // AI Summary
    this.isLoadingAI = false,
    this.aiSummary,
    // Quiz
    this.qaId,
    this.qaQuestion,
    this.qaChoiceA,
    this.qaChoiceB,
    this.qaChoiceC,
    this.qaAnswer,
    // AI Quiz preview
    this.isLoadingQuizAI = false,
    this.aiQuizQuestion,
    this.aiQuizChoiceA,
    this.aiQuizChoiceB,
    this.aiQuizChoiceC,
    this.aiQuizAnswer,
    // Tag and Resident
    this.originalResidentId,
    this.originalResidentName,
    this.originalTagName,
    this.residentId,
    this.residentName,
    this.selectedTag,
    this.isHandover = false,
  });

  /// Get final list of existing image URLs (excluding removed ones)
  List<String> get finalExistingUrls {
    return existingImageUrls
        .asMap()
        .entries
        .where((e) => !removedExistingIndexes.contains(e.key))
        .map((e) => e.value)
        .toList();
  }

  /// Count of remaining existing images
  int get remainingExistingCount =>
      existingImageUrls.length - removedExistingIndexes.length;

  /// Total image count (existing + new)
  int get totalImageCount => remainingExistingCount + newImages.length;

  /// Max 5 images allowed
  bool get canAddMoreImages => totalImageCount < 5;

  /// How many more images can be added
  int get remainingImageSlots => 5 - totalImageCount;

  bool get hasChanges =>
      text.isNotEmpty ||
      newImages.isNotEmpty ||
      removedExistingIndexes.isNotEmpty ||
      residentId != originalResidentId ||
      selectedTag?.name != originalTagName;

  /// Check if tag has changed
  bool get hasTagChanged => selectedTag?.name != originalTagName;

  /// Check if resident has changed
  bool get hasResidentChanged => residentId != originalResidentId;

  /// Check if quiz is complete (has question and all choices)
  bool get hasQuiz =>
      qaQuestion != null &&
      qaQuestion!.isNotEmpty &&
      qaChoiceA != null &&
      qaChoiceA!.isNotEmpty &&
      qaChoiceB != null &&
      qaChoiceB!.isNotEmpty &&
      qaChoiceC != null &&
      qaChoiceC!.isNotEmpty &&
      qaAnswer != null;

  /// Check if AI quiz preview is available
  bool get hasAiQuizPreview =>
      aiQuizQuestion != null && aiQuizQuestion!.isNotEmpty;

  EditPostState copyWith({
    int? postId,
    String? text,
    String? title,
    List<String>? existingImageUrls,
    Set<int>? removedExistingIndexes,
    List<File>? newImages,
    bool? isSubmitting,
    String? error,
    // AI Summary
    bool? isLoadingAI,
    String? aiSummary,
    bool clearAiSummary = false,
    // Quiz
    int? qaId,
    String? qaQuestion,
    String? qaChoiceA,
    String? qaChoiceB,
    String? qaChoiceC,
    String? qaAnswer,
    bool clearQuiz = false,
    // AI Quiz preview
    bool? isLoadingQuizAI,
    String? aiQuizQuestion,
    String? aiQuizChoiceA,
    String? aiQuizChoiceB,
    String? aiQuizChoiceC,
    String? aiQuizAnswer,
    bool clearAiQuizPreview = false,
    // Tag and Resident
    int? originalResidentId,
    String? originalResidentName,
    String? originalTagName,
    int? residentId,
    String? residentName,
    NewTag? selectedTag,
    bool? isHandover,
    bool clearResident = false,
    bool clearTag = false,
  }) {
    return EditPostState(
      postId: postId ?? this.postId,
      text: text ?? this.text,
      title: title ?? this.title,
      existingImageUrls: existingImageUrls ?? this.existingImageUrls,
      removedExistingIndexes:
          removedExistingIndexes ?? this.removedExistingIndexes,
      newImages: newImages ?? this.newImages,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      // AI Summary
      isLoadingAI: isLoadingAI ?? this.isLoadingAI,
      aiSummary: clearAiSummary ? null : (aiSummary ?? this.aiSummary),
      // Quiz
      qaId: clearQuiz ? null : (qaId ?? this.qaId),
      qaQuestion: clearQuiz ? null : (qaQuestion ?? this.qaQuestion),
      qaChoiceA: clearQuiz ? null : (qaChoiceA ?? this.qaChoiceA),
      qaChoiceB: clearQuiz ? null : (qaChoiceB ?? this.qaChoiceB),
      qaChoiceC: clearQuiz ? null : (qaChoiceC ?? this.qaChoiceC),
      qaAnswer: clearQuiz ? null : (qaAnswer ?? this.qaAnswer),
      // AI Quiz preview
      isLoadingQuizAI: isLoadingQuizAI ?? this.isLoadingQuizAI,
      aiQuizQuestion: clearAiQuizPreview ? null : (aiQuizQuestion ?? this.aiQuizQuestion),
      aiQuizChoiceA: clearAiQuizPreview ? null : (aiQuizChoiceA ?? this.aiQuizChoiceA),
      aiQuizChoiceB: clearAiQuizPreview ? null : (aiQuizChoiceB ?? this.aiQuizChoiceB),
      aiQuizChoiceC: clearAiQuizPreview ? null : (aiQuizChoiceC ?? this.aiQuizChoiceC),
      aiQuizAnswer: clearAiQuizPreview ? null : (aiQuizAnswer ?? this.aiQuizAnswer),
      // Tag and Resident - original values preserved
      originalResidentId: originalResidentId ?? this.originalResidentId,
      originalResidentName: originalResidentName ?? this.originalResidentName,
      originalTagName: originalTagName ?? this.originalTagName,
      // Current/edited values
      residentId: clearResident ? null : (residentId ?? this.residentId),
      residentName: clearResident ? null : (residentName ?? this.residentName),
      selectedTag: clearTag ? null : (selectedTag ?? this.selectedTag),
      isHandover: isHandover ?? this.isHandover,
    );
  }
}

/// Notifier for Edit Post state
class EditPostNotifier extends StateNotifier<EditPostState> {
  EditPostNotifier(int postId) : super(EditPostState(postId: postId));

  /// Initialize from existing post
  void initFromPost(Post post) {
    // Get tag name from post (postTagsString is comma-separated, take first)
    final tagName = post.postTagsString?.split(',').first.trim();

    state = EditPostState(
      postId: post.id,
      text: post.text ?? '',
      title: post.title,
      existingImageUrls: post.allImageUrls,
      // Load existing quiz data
      qaId: post.qaId,
      qaQuestion: post.qaQuestion,
      qaChoiceA: post.qaChoiceA,
      qaChoiceB: post.qaChoiceB,
      qaChoiceC: post.qaChoiceC,
      qaAnswer: post.qaAnswer,
      // Load existing tag and resident (for shift leader+ editing)
      originalResidentId: post.residentId,
      originalResidentName: post.residentName,
      originalTagName: tagName,
      residentId: post.residentId,
      residentName: post.residentName,
      isHandover: post.isHandover,
    );
    debugPrint('EditPostNotifier: initialized from post ${post.id}');
  }

  /// Initialize with a tag (when tag is loaded from provider)
  void setSelectedTag(NewTag? tag) {
    state = state.copyWith(
      selectedTag: tag,
      // Auto-set handover based on tag's handover mode
      isHandover: tag?.isForceHandover ?? state.isHandover,
    );
    debugPrint('EditPostNotifier: set tag to ${tag?.name}');
  }

  void setText(String value) {
    state = state.copyWith(text: value);
  }

  void setTitle(String? value) {
    state = state.copyWith(title: value);
  }

  /// Add new images (local files) to upload
  void addNewImages(List<File> images) {
    if (images.isEmpty) return;

    // Limit total images to 5
    final canAdd = state.remainingImageSlots;
    final toAdd = images.take(canAdd).toList();

    state = state.copyWith(
      newImages: [...state.newImages, ...toAdd],
    );
    debugPrint('EditPostNotifier: added ${toAdd.length} new images');
  }

  /// Remove a new image by index
  void removeNewImage(int index) {
    if (index < 0 || index >= state.newImages.length) return;

    final updated = [...state.newImages];
    updated.removeAt(index);
    state = state.copyWith(newImages: updated);
    debugPrint('EditPostNotifier: removed new image at index $index');
  }

  /// Mark an existing image for removal
  void removeExistingImage(int index) {
    if (index < 0 || index >= state.existingImageUrls.length) return;

    final updated = {...state.removedExistingIndexes, index};
    state = state.copyWith(removedExistingIndexes: updated);
    debugPrint('EditPostNotifier: marked existing image $index for removal');
  }

  /// Restore a previously removed existing image
  void restoreExistingImage(int index) {
    final updated = {...state.removedExistingIndexes};
    updated.remove(index);
    state = state.copyWith(removedExistingIndexes: updated);
    debugPrint('EditPostNotifier: restored existing image $index');
  }

  void setSubmitting(bool value) {
    state = state.copyWith(isSubmitting: value);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  // AI Summary methods
  void setLoadingAI(bool value) {
    state = state.copyWith(isLoadingAI: value);
  }

  void setAiSummary(String? summary) {
    state = state.copyWith(
      aiSummary: summary,
      isLoadingAI: false,
    );
  }

  void clearAiSummary() {
    state = state.copyWith(clearAiSummary: true);
  }

  // Quiz methods
  void setQaQuestion(String value) {
    state = state.copyWith(qaQuestion: value);
  }

  void setQaChoiceA(String value) {
    state = state.copyWith(qaChoiceA: value);
  }

  void setQaChoiceB(String value) {
    state = state.copyWith(qaChoiceB: value);
  }

  void setQaChoiceC(String value) {
    state = state.copyWith(qaChoiceC: value);
  }

  void setQaAnswer(String value) {
    state = state.copyWith(qaAnswer: value);
  }

  void clearQuiz() {
    state = state.copyWith(clearQuiz: true);
  }

  // AI Quiz preview methods
  void setLoadingQuizAI(bool value) {
    state = state.copyWith(isLoadingQuizAI: value);
  }

  void setAiQuizPreview({
    required String question,
    required String choiceA,
    required String choiceB,
    required String choiceC,
    required String answer,
  }) {
    state = state.copyWith(
      aiQuizQuestion: question,
      aiQuizChoiceA: choiceA,
      aiQuizChoiceB: choiceB,
      aiQuizChoiceC: choiceC,
      aiQuizAnswer: answer,
      isLoadingQuizAI: false,
    );
  }

  void applyAiQuizToForm() {
    state = state.copyWith(
      qaQuestion: state.aiQuizQuestion,
      qaChoiceA: state.aiQuizChoiceA,
      qaChoiceB: state.aiQuizChoiceB,
      qaChoiceC: state.aiQuizChoiceC,
      qaAnswer: state.aiQuizAnswer,
      clearAiQuizPreview: true,
    );
  }

  void clearAiQuizPreview() {
    state = state.copyWith(clearAiQuizPreview: true);
  }

  // Tag and Resident methods (for shift leader+ editing)
  void setResident(int id, String name) {
    state = state.copyWith(residentId: id, residentName: name);
    debugPrint('EditPostNotifier: set resident to $name (id: $id)');
  }

  void clearResident() {
    state = state.copyWith(clearResident: true);
    debugPrint('EditPostNotifier: cleared resident');
  }

  void setTag(NewTag tag) {
    state = state.copyWith(
      selectedTag: tag,
      // Auto-set handover based on tag's handover mode
      isHandover: tag.isForceHandover ? true : state.isHandover,
    );
    debugPrint('EditPostNotifier: set tag to ${tag.name}');
  }

  void clearTag() {
    state = state.copyWith(clearTag: true);
    debugPrint('EditPostNotifier: cleared tag');
  }

  void setHandover(bool value) {
    // ไม่สามารถปิด handover ได้ถ้า tag เป็น force handover
    if (state.selectedTag?.isForceHandover == true && !value) {
      debugPrint('EditPostNotifier: cannot disable handover for force-handover tag');
      return;
    }
    state = state.copyWith(isHandover: value);
    debugPrint('EditPostNotifier: set handover to $value');
  }

  void reset() {
    state = EditPostState(postId: state.postId);
  }
}

/// Provider family for edit post (keyed by postId)
final editPostProvider =
    StateNotifierProvider.family<EditPostNotifier, EditPostState, int>(
  (ref, postId) => EditPostNotifier(postId),
);
