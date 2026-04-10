import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../models/new_tag.dart';
import '../models/post_measurement_entry.dart';
import '../../checklist/models/assessment_models.dart';
import '../../checklist/models/measurement_config.dart';

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

  /// Existing video URLs (from the post)
  final List<String> existingVideoUrls;

  /// Indexes of existing videos that user wants to remove
  final Set<int> removedExistingVideoIndexes;

  /// New videos to upload (local files) - จำกัด 1 ไฟล์ เหมือน create
  final List<File> newVideos;

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

  // === Measurement + Assessment (แนบค่าวัดและประเมินสุขภาพกับ post) ===

  /// ค่าวัดปัจจุบัน keyed by measurementType
  final Map<String, PostMeasurementEntry> measurements;

  /// ค่าวัดเดิมจาก DB (สำหรับเปรียบเทียบว่ามีการเปลี่ยนแปลงไหม)
  final Map<String, PostMeasurementEntry> originalMeasurements;

  /// หัวข้อประเมินที่โหลดจาก DB
  final List<AssessmentSubject> assessmentSubjects;

  /// ผลประเมินปัจจุบัน
  final List<AssessmentRating> assessmentRatings;

  /// ผลประเมินเดิมจาก DB
  final List<AssessmentRating> originalAssessmentRatings;

  const EditPostState({
    required this.postId,
    this.text = '',
    this.title,
    this.existingImageUrls = const [],
    this.removedExistingIndexes = const {},
    this.newImages = const [],
    this.existingVideoUrls = const [],
    this.removedExistingVideoIndexes = const {},
    this.newVideos = const [],
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
    // Measurement + Assessment
    this.measurements = const {},
    this.originalMeasurements = const {},
    this.assessmentSubjects = const [],
    this.assessmentRatings = const [],
    this.originalAssessmentRatings = const [],
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

  /// Get final list of existing video URLs (excluding removed ones)
  List<String> get finalExistingVideoUrls {
    return existingVideoUrls
        .asMap()
        .entries
        .where((e) => !removedExistingVideoIndexes.contains(e.key))
        .map((e) => e.value)
        .toList();
  }

  /// Count of remaining existing images
  int get remainingExistingCount =>
      existingImageUrls.length - removedExistingIndexes.length;

  /// Count of remaining existing videos
  int get remainingExistingVideoCount =>
      existingVideoUrls.length - removedExistingVideoIndexes.length;

  /// Total image count (existing + new)
  int get totalImageCount => remainingExistingCount + newImages.length;

  /// Total video count (existing + new)
  int get totalVideoCount => remainingExistingVideoCount + newVideos.length;

  /// Check if has any images
  bool get hasImages => totalImageCount > 0;

  /// Check if has any videos
  bool get hasVideo => totalVideoCount > 0;

  /// Max 5 images allowed
  bool get canAddMoreImages => totalImageCount < 5 && !hasVideo;

  /// Can add video (mutual exclusion with images, max 1 video)
  bool get canAddVideo => totalVideoCount < 1 && !hasImages;

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

  /// มี measurement ที่กรอกค่าแล้วอย่างน้อย 1 ตัว
  bool get hasMeasurements => measurements.values.any((e) => e.hasValue);

  /// จำนวน measurement ที่กรอกค่าแล้ว
  int get filledMeasurementCount =>
      measurements.values.where((e) => e.hasValue).length;

  /// มี assessment rating อย่างน้อย 1 หัวข้อ
  bool get hasAssessmentRatings => assessmentRatings.isNotEmpty;

  /// ตรวจว่า measurements เปลี่ยนจากเดิมไหม
  bool get hasMeasurementChanges {
    if (measurements.length != originalMeasurements.length) return true;
    for (final entry in measurements.entries) {
      final orig = originalMeasurements[entry.key];
      if (orig == null) return true;
      if (entry.value.value != orig.value) return true;
      if (entry.value.photoUrl != orig.photoUrl) return true;
    }
    return false;
  }

  /// ตรวจว่า assessments เปลี่ยนจากเดิมไหม
  bool get hasAssessmentChanges {
    if (assessmentRatings.length != originalAssessmentRatings.length) {
      return true;
    }
    for (int i = 0; i < assessmentRatings.length; i++) {
      final curr = assessmentRatings[i];
      final orig = originalAssessmentRatings.where(
        (r) => r.subjectId == curr.subjectId,
      );
      if (orig.isEmpty) return true;
      if (orig.first.rating != curr.rating) return true;
      if (orig.first.description != curr.description) return true;
    }
    return false;
  }

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
    List<String>? existingVideoUrls,
    Set<int>? removedExistingVideoIndexes,
    List<File>? newVideos,
    bool clearVideos = false,
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
    // Measurement + Assessment
    Map<String, PostMeasurementEntry>? measurements,
    bool clearMeasurements = false,
    Map<String, PostMeasurementEntry>? originalMeasurements,
    List<AssessmentSubject>? assessmentSubjects,
    bool clearAssessmentSubjects = false,
    List<AssessmentRating>? assessmentRatings,
    bool clearAssessmentRatings = false,
    List<AssessmentRating>? originalAssessmentRatings,
  }) {
    return EditPostState(
      postId: postId ?? this.postId,
      text: text ?? this.text,
      title: title ?? this.title,
      existingImageUrls: existingImageUrls ?? this.existingImageUrls,
      removedExistingIndexes:
          removedExistingIndexes ?? this.removedExistingIndexes,
      newImages: newImages ?? this.newImages,
      existingVideoUrls: clearVideos ? const [] : (existingVideoUrls ?? this.existingVideoUrls),
      removedExistingVideoIndexes: clearVideos ? const {} : (removedExistingVideoIndexes ?? this.removedExistingVideoIndexes),
      newVideos: clearVideos ? const [] : (newVideos ?? this.newVideos),
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
      // Measurement + Assessment
      measurements: clearMeasurements ? const {} : (measurements ?? this.measurements),
      originalMeasurements: originalMeasurements ?? this.originalMeasurements,
      assessmentSubjects: clearAssessmentSubjects ? const [] : (assessmentSubjects ?? this.assessmentSubjects),
      assessmentRatings: clearAssessmentRatings ? const [] : (assessmentRatings ?? this.assessmentRatings),
      originalAssessmentRatings: originalAssessmentRatings ?? this.originalAssessmentRatings,
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
      existingVideoUrls: post.videoUrls,
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
    debugPrint('EditPostNotifier: initialized from post ${post.id}, videos: ${post.videoUrls.length}');
  }

  /// Initialize with a tag (when tag is loaded from provider)
  /// เรียกเมื่อโหลด tag จาก originalTagName หลังจาก initFromPost
  /// ต้องไม่ override isHandover ที่โหลดมาจาก post เดิม
  void setSelectedTag(NewTag? tag) {
    state = state.copyWith(
      selectedTag: tag,
      // ถ้า tag เป็น force handover → บังคับ true
      // ถ้าไม่ใช่ → เก็บค่าเดิมจาก state (ที่โหลดมาจาก post)
      isHandover: tag?.isForceHandover == true ? true : state.isHandover,
    );
    debugPrint('EditPostNotifier: set tag to ${tag?.name}, isHandover=${state.isHandover}');
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

  /// เพิ่ม URL เข้า existing images (สำหรับรูป measurement ที่ upload ใหม่ระหว่าง edit)
  void addExistingImageUrl(String url) {
    state = state.copyWith(
      existingImageUrls: [...state.existingImageUrls, url],
    );
    debugPrint('EditPostNotifier: added existing image URL');
  }

  /// Restore a previously removed existing image
  void restoreExistingImage(int index) {
    final updated = {...state.removedExistingIndexes};
    updated.remove(index);
    state = state.copyWith(removedExistingIndexes: updated);
    debugPrint('EditPostNotifier: restored existing image $index');
  }

  // ========== Video Methods ==========

  /// Add new video (local file) to upload - จำกัด 1 ไฟล์
  void addNewVideo(File video) {
    // ถ้ามีวีดีโอแล้ว (existing หรือ new) ไม่เพิ่ม
    if (!state.canAddVideo) {
      debugPrint('EditPostNotifier: cannot add video - already has video or images');
      return;
    }

    state = state.copyWith(newVideos: [video]);
    debugPrint('EditPostNotifier: added new video');
  }

  /// Remove new video by index
  void removeNewVideo(int index) {
    if (index < 0 || index >= state.newVideos.length) return;

    final updated = [...state.newVideos];
    updated.removeAt(index);
    state = state.copyWith(newVideos: updated);
    debugPrint('EditPostNotifier: removed new video at index $index');
  }

  /// Mark an existing video for removal
  void removeExistingVideo(int index) {
    if (index < 0 || index >= state.existingVideoUrls.length) return;

    final updated = {...state.removedExistingVideoIndexes, index};
    state = state.copyWith(removedExistingVideoIndexes: updated);
    debugPrint('EditPostNotifier: marked existing video $index for removal');
  }

  /// Restore a previously removed existing video
  void restoreExistingVideo(int index) {
    final updated = {...state.removedExistingVideoIndexes};
    updated.remove(index);
    state = state.copyWith(removedExistingVideoIndexes: updated);
    debugPrint('EditPostNotifier: restored existing video $index');
  }

  /// Clear all videos (existing and new)
  void clearAllVideos() {
    state = state.copyWith(clearVideos: true);
    debugPrint('EditPostNotifier: cleared all videos');
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

  // === Measurement Methods ===

  /// Initialize measurements จาก DB (สำหรับ edit post)
  void initMeasurementsFromDb(List<Map<String, dynamic>> rows) {
    final map = <String, PostMeasurementEntry>{};
    for (final row in rows) {
      final type = row['measurement_type'] as String;
      final config = measurementConfigByType[type];
      if (config == null) continue;

      map[type] = PostMeasurementEntry(
        measurementType: type,
        config: config,
        value: (row['numeric_value'] as num?)?.toDouble(),
        photoUrl: row['photo_url'] as String?,
      );
    }
    state = state.copyWith(
      measurements: map,
      originalMeasurements: Map.unmodifiable(map),
    );
  }

  /// เพิ่ม measurement type
  void addMeasurement(String measurementType) {
    final config = measurementConfigByType[measurementType];
    if (config == null) return;
    if (state.measurements.containsKey(measurementType)) return;

    final updated = Map<String, PostMeasurementEntry>.from(state.measurements);
    updated[measurementType] = PostMeasurementEntry(
      measurementType: measurementType,
      config: config,
    );
    state = state.copyWith(measurements: updated);
  }

  /// ลบ measurement type
  void removeMeasurement(String measurementType) {
    final updated = Map<String, PostMeasurementEntry>.from(state.measurements);
    updated.remove(measurementType);
    state = state.copyWith(measurements: updated);
  }

  /// อัพเดทค่า
  void updateMeasurementValue(String measurementType, double? value) {
    final entry = state.measurements[measurementType];
    if (entry == null) return;

    final updated = Map<String, PostMeasurementEntry>.from(state.measurements);
    updated[measurementType] = entry.copyWith(
      value: value,
      clearValue: value == null,
    );
    state = state.copyWith(measurements: updated);
  }

  /// อัพเดท photo URL
  void updateMeasurementPhoto(String measurementType, String? photoUrl) {
    final entry = state.measurements[measurementType];
    if (entry == null) return;

    final updated = Map<String, PostMeasurementEntry>.from(state.measurements);
    updated[measurementType] = entry.copyWith(
      photoUrl: photoUrl,
      clearPhotoUrl: photoUrl == null,
    );
    state = state.copyWith(measurements: updated);
  }

  /// อัพเดท photo uploading state
  void setMeasurementPhotoUploading(String measurementType, bool uploading) {
    final entry = state.measurements[measurementType];
    if (entry == null) return;

    final updated = Map<String, PostMeasurementEntry>.from(state.measurements);
    updated[measurementType] = entry.copyWith(isUploadingPhoto: uploading);
    state = state.copyWith(measurements: updated);
  }

  // === Assessment Methods ===

  /// Initialize assessments จาก DB (สำหรับ edit post)
  void initAssessmentsFromDb(List<AssessmentRating> ratings) {
    state = state.copyWith(
      assessmentRatings: ratings,
      originalAssessmentRatings: List.unmodifiable(ratings),
    );
  }

  /// Set assessment subjects (โหลดจาก DB)
  void setAssessmentSubjects(List<AssessmentSubject> subjects) {
    state = state.copyWith(assessmentSubjects: subjects);
  }

  /// Set assessment ratings (user กรอก)
  void setAssessmentRatings(List<AssessmentRating> ratings) {
    state = state.copyWith(assessmentRatings: ratings);
  }
}

/// Provider family for edit post (keyed by postId)
final editPostProvider =
    StateNotifierProvider.family<EditPostNotifier, EditPostState, int>(
  (ref, postId) => EditPostNotifier(postId),
);
