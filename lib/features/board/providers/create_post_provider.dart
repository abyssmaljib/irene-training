import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/new_tag.dart';
import '../../checklist/providers/task_provider.dart';

/// State สำหรับ Create Post form
class CreatePostState {
  final String text;
  final NewTag? selectedTag;
  final bool isHandover;
  final bool sendToFamily; // ส่งให้ญาติ
  final int? selectedResidentId;
  final String? selectedResidentName;
  final List<File> selectedImages;
  final List<String> uploadedImageUrls;
  // รองรับหลาย video - เก็บรวมกับรูปใน multi_img_url array ตอน submit
  final List<File> selectedVideos;
  final List<String> uploadedVideoUrls;

  // Video upload state (for optimistic background upload)
  final bool isUploadingVideo;
  final double videoUploadProgress; // 0.0 - 1.0
  final String? videoUploadError;
  final String? videoThumbnailUrl; // thumbnail จาก video ที่อัพโหลดสำเร็จ

  final bool isSubmitting;
  final String? error;

  // Advanced fields (for advanced create post screen)
  final String? title;
  final String? qaQuestion;
  final String? qaChoiceA;
  final String? qaChoiceB;
  final String? qaChoiceC;
  final String? qaAnswer; // 'A', 'B', or 'C'
  final String? aiSummary;
  final bool isLoadingAI;

  // AI-generated quiz preview (before applying to form)
  final String? aiQuizQuestion;
  final String? aiQuizChoiceA;
  final String? aiQuizChoiceB;
  final String? aiQuizChoiceC;
  final String? aiQuizAnswer;
  final bool isLoadingQuizAI;

  // DD Record context (for creating post from shift summary)
  final int? ddId;
  final String? ddTemplateText;

  const CreatePostState({
    this.text = '',
    this.selectedTag,
    this.isHandover = false,
    this.sendToFamily = false,
    this.selectedResidentId,
    this.selectedResidentName,
    this.selectedImages = const [],
    this.uploadedImageUrls = const [],
    this.selectedVideos = const [],
    this.uploadedVideoUrls = const [],
    this.isUploadingVideo = false,
    this.videoUploadProgress = 0.0,
    this.videoUploadError,
    this.videoThumbnailUrl,
    this.isSubmitting = false,
    this.error,
    // Advanced fields
    this.title,
    this.qaQuestion,
    this.qaChoiceA,
    this.qaChoiceB,
    this.qaChoiceC,
    this.qaAnswer,
    this.aiSummary,
    this.isLoadingAI = false,
    // AI quiz preview
    this.aiQuizQuestion,
    this.aiQuizChoiceA,
    this.aiQuizChoiceB,
    this.aiQuizChoiceC,
    this.aiQuizAnswer,
    this.isLoadingQuizAI = false,
    // DD Record context
    this.ddId,
    this.ddTemplateText,
  });

  bool get isValid => text.trim().isNotEmpty;

  bool get hasResident => selectedResidentId != null;

  bool get hasTag => selectedTag != null;

  bool get hasImages => selectedImages.isNotEmpty || uploadedImageUrls.isNotEmpty;

  // รวม upload states ด้วย เพื่อแสดง UI ตอน uploading/error
  bool get hasVideo =>
      selectedVideos.isNotEmpty ||
      uploadedVideoUrls.isNotEmpty ||
      isUploadingVideo ||
      videoUploadError != null;

  bool get hasQuiz =>
      qaQuestion != null &&
      qaQuestion!.trim().isNotEmpty &&
      qaChoiceA != null &&
      qaChoiceA!.trim().isNotEmpty &&
      qaChoiceB != null &&
      qaChoiceB!.trim().isNotEmpty &&
      qaChoiceC != null &&
      qaChoiceC!.trim().isNotEmpty &&
      qaAnswer != null;

  bool get hasTitle => title != null && title!.trim().isNotEmpty;

  bool get hasAiQuizPreview =>
      aiQuizQuestion != null && aiQuizQuestion!.trim().isNotEmpty;

  CreatePostState copyWith({
    String? text,
    NewTag? selectedTag,
    bool? clearTag,
    bool? isHandover,
    bool? sendToFamily,
    int? selectedResidentId,
    bool? clearResident,
    String? selectedResidentName,
    List<File>? selectedImages,
    List<String>? uploadedImageUrls,
    List<File>? selectedVideos,
    bool? clearVideos,
    List<String>? uploadedVideoUrls,
    bool? isUploadingVideo,
    double? videoUploadProgress,
    String? videoUploadError,
    bool? clearVideoUploadError,
    String? videoThumbnailUrl,
    bool? clearVideoThumbnail,
    bool? isSubmitting,
    String? error,
    bool? clearError,
    // Advanced fields
    String? title,
    bool? clearTitle,
    String? qaQuestion,
    String? qaChoiceA,
    String? qaChoiceB,
    String? qaChoiceC,
    String? qaAnswer,
    bool? clearQuiz,
    String? aiSummary,
    bool? clearAiSummary,
    bool? isLoadingAI,
    // AI quiz preview
    String? aiQuizQuestion,
    String? aiQuizChoiceA,
    String? aiQuizChoiceB,
    String? aiQuizChoiceC,
    String? aiQuizAnswer,
    bool? clearAiQuizPreview,
    bool? isLoadingQuizAI,
    // DD Record context
    int? ddId,
    String? ddTemplateText,
    bool? clearDD,
  }) {
    return CreatePostState(
      text: text ?? this.text,
      selectedTag: clearTag == true ? null : (selectedTag ?? this.selectedTag),
      isHandover: isHandover ?? this.isHandover,
      sendToFamily: sendToFamily ?? this.sendToFamily,
      selectedResidentId: clearResident == true
          ? null
          : (selectedResidentId ?? this.selectedResidentId),
      selectedResidentName: clearResident == true
          ? null
          : (selectedResidentName ?? this.selectedResidentName),
      selectedImages: selectedImages ?? this.selectedImages,
      uploadedImageUrls: uploadedImageUrls ?? this.uploadedImageUrls,
      selectedVideos:
          clearVideos == true ? const [] : (selectedVideos ?? this.selectedVideos),
      uploadedVideoUrls: clearVideos == true
          ? const []
          : (uploadedVideoUrls ?? this.uploadedVideoUrls),
      isUploadingVideo: clearVideos == true ? false : (isUploadingVideo ?? this.isUploadingVideo),
      videoUploadProgress: clearVideos == true ? 0.0 : (videoUploadProgress ?? this.videoUploadProgress),
      videoUploadError: clearVideos == true || clearVideoUploadError == true
          ? null
          : (videoUploadError ?? this.videoUploadError),
      videoThumbnailUrl: clearVideos == true || clearVideoThumbnail == true
          ? null
          : (videoThumbnailUrl ?? this.videoThumbnailUrl),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError == true ? null : (error ?? this.error),
      // Advanced fields
      title: clearTitle == true ? null : (title ?? this.title),
      qaQuestion: clearQuiz == true ? null : (qaQuestion ?? this.qaQuestion),
      qaChoiceA: clearQuiz == true ? null : (qaChoiceA ?? this.qaChoiceA),
      qaChoiceB: clearQuiz == true ? null : (qaChoiceB ?? this.qaChoiceB),
      qaChoiceC: clearQuiz == true ? null : (qaChoiceC ?? this.qaChoiceC),
      qaAnswer: clearQuiz == true ? null : (qaAnswer ?? this.qaAnswer),
      aiSummary:
          clearAiSummary == true ? null : (aiSummary ?? this.aiSummary),
      isLoadingAI: isLoadingAI ?? this.isLoadingAI,
      // AI quiz preview
      aiQuizQuestion: clearAiQuizPreview == true
          ? null
          : (aiQuizQuestion ?? this.aiQuizQuestion),
      aiQuizChoiceA: clearAiQuizPreview == true
          ? null
          : (aiQuizChoiceA ?? this.aiQuizChoiceA),
      aiQuizChoiceB: clearAiQuizPreview == true
          ? null
          : (aiQuizChoiceB ?? this.aiQuizChoiceB),
      aiQuizChoiceC: clearAiQuizPreview == true
          ? null
          : (aiQuizChoiceC ?? this.aiQuizChoiceC),
      aiQuizAnswer: clearAiQuizPreview == true
          ? null
          : (aiQuizAnswer ?? this.aiQuizAnswer),
      isLoadingQuizAI: isLoadingQuizAI ?? this.isLoadingQuizAI,
      // DD Record context
      ddId: clearDD == true ? null : (ddId ?? this.ddId),
      ddTemplateText: clearDD == true ? null : (ddTemplateText ?? this.ddTemplateText),
    );
  }

  /// Reset to initial state
  CreatePostState reset() {
    return const CreatePostState();
  }
}

/// Notifier สำหรับจัดการ Create Post state
class CreatePostNotifier extends StateNotifier<CreatePostState> {
  CreatePostNotifier() : super(const CreatePostState());

  /// อัพเดท text
  void setText(String value) {
    state = state.copyWith(text: value, clearError: true);
  }

  /// เลือก tag
  void selectTag(NewTag tag) {
    // Auto-set handover based on mode
    final isHandover = tag.isForceHandover ? true : false;

    state = state.copyWith(
      selectedTag: tag,
      isHandover: isHandover,
      clearError: true,
    );
  }

  /// ยกเลิกการเลือก tag
  void clearTag() {
    state = state.copyWith(
      clearTag: true,
      isHandover: false,
      clearError: true,
    );
  }

  /// Toggle handover (only for optional mode - ทุก tag ที่ไม่ใช่ force)
  void setHandover(bool value) {
    if (state.selectedTag == null) return;
    if (state.selectedTag!.isForceHandover) return; // Can't change force

    state = state.copyWith(isHandover: value, clearError: true);
  }

  /// Toggle ส่งให้ญาติ
  void setSendToFamily(bool value) {
    state = state.copyWith(sendToFamily: value, clearError: true);
  }

  /// เลือก resident
  /// เมื่อเลือก resident จะ reset handover เป็น false (ถ้า tag ไม่ได้บังคับส่งเวร)
  /// เพื่อป้องกันการติ๊กส่งเวรพร่ำเพรื่อโดยไม่มีเหตุผล
  void selectResident(int id, String name) {
    // ถ้า tag ไม่บังคับส่งเวร → reset handover เป็น false
    final shouldResetHandover = state.selectedTag != null &&
        !state.selectedTag!.isForceHandover;

    state = state.copyWith(
      selectedResidentId: id,
      selectedResidentName: name,
      // reset handover เมื่อเลือก resident และ tag ไม่บังคับส่งเวร
      isHandover: shouldResetHandover ? false : state.isHandover,
      clearError: true,
    );
  }

  /// ยกเลิกการเลือก resident
  /// เมื่อไม่มี resident = เรื่องส่วนกลาง → บังคับส่งเวร
  void clearResident() {
    state = state.copyWith(
      clearResident: true,
      isHandover: true, // auto-enable ส่งเวรเมื่อไม่มี resident
      clearError: true,
    );
  }

  /// เพิ่มรูปภาพ
  void addImages(List<File> images) {
    final newImages = [...state.selectedImages, ...images];
    state = state.copyWith(selectedImages: newImages, clearError: true);
  }

  /// ลบรูปภาพ
  void removeImage(int index) {
    final newImages = List<File>.from(state.selectedImages);
    if (index >= 0 && index < newImages.length) {
      newImages.removeAt(index);
      state = state.copyWith(selectedImages: newImages);
    }
  }

  /// ลบรูปภาพที่ upload แล้ว
  void removeUploadedImage(int index) {
    final newUrls = List<String>.from(state.uploadedImageUrls);
    if (index >= 0 && index < newUrls.length) {
      newUrls.removeAt(index);
      state = state.copyWith(uploadedImageUrls: newUrls);
    }
  }

  /// Set uploaded image URLs
  void setUploadedImageUrls(List<String> urls) {
    state = state.copyWith(uploadedImageUrls: urls);
  }

  /// Set submitting state
  void setSubmitting(bool value) {
    state = state.copyWith(isSubmitting: value);
  }

  /// Set error
  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  /// Reset state
  void reset() {
    state = state.reset();
  }

  /// Initialize state with pre-filled values (สำหรับ task completion by post)
  /// sendToFamily = true เพื่อให้ระบบ automation ส่งให้ญาติ
  void initFromTask({
    required String text,
    int? residentId,
    String? residentName,
  }) {
    state = CreatePostState(
      text: text,
      selectedResidentId: residentId,
      selectedResidentName: residentName,
      sendToFamily: true, // auto-enable เมื่อมาจาก task
    );
  }

  /// Clear images after successful upload
  void clearLocalImages() {
    state = state.copyWith(selectedImages: []);
  }

  /// เพิ่มวีดีโอ (รองรับหลายไฟล์)
  void addVideos(List<File> videos) {
    final newVideos = [...state.selectedVideos, ...videos];
    state = state.copyWith(selectedVideos: newVideos, clearError: true);
  }

  /// ลบวีดีโอตาม index
  void removeVideo(int index) {
    final newVideos = List<File>.from(state.selectedVideos);
    if (index >= 0 && index < newVideos.length) {
      newVideos.removeAt(index);
      state = state.copyWith(selectedVideos: newVideos);
    }
  }

  /// ลบ uploaded video URL ตาม index
  void removeUploadedVideo(int index) {
    final newUrls = List<String>.from(state.uploadedVideoUrls);
    if (index >= 0 && index < newUrls.length) {
      newUrls.removeAt(index);
      state = state.copyWith(uploadedVideoUrls: newUrls);
    }
  }

  /// ล้างวีดีโอทั้งหมด
  void clearVideos() {
    state = state.copyWith(clearVideos: true, clearError: true);
  }

  /// Set uploaded video URLs
  void setUploadedVideoUrls(List<String> urls) {
    state = state.copyWith(uploadedVideoUrls: urls);
  }

  // === Video Upload State Methods (for optimistic background upload) ===

  /// เริ่มอัพโหลดวีดีโอ - set uploading state
  void startVideoUpload(File videoFile) {
    state = state.copyWith(
      selectedVideos: [videoFile],
      isUploadingVideo: true,
      videoUploadProgress: 0.0,
      clearVideoUploadError: true,
    );
  }

  /// อัพเดท progress (0.0 - 1.0)
  void setVideoUploadProgress(double progress) {
    state = state.copyWith(videoUploadProgress: progress.clamp(0.0, 1.0));
  }

  /// อัพโหลดสำเร็จ - เก็บ URL และ thumbnail
  void setVideoUploadSuccess(String videoUrl, String? thumbnailUrl) {
    state = state.copyWith(
      isUploadingVideo: false,
      videoUploadProgress: 1.0,
      uploadedVideoUrls: [videoUrl],
      videoThumbnailUrl: thumbnailUrl,
      selectedVideos: const [], // clear local file - ใช้ URL แทน
    );
  }

  /// อัพโหลดล้มเหลว - เก็บ error message
  void setVideoUploadError(String error) {
    state = state.copyWith(
      isUploadingVideo: false,
      videoUploadError: error,
    );
  }

  /// Clear video upload error (สำหรับ retry)
  void clearVideoUploadError() {
    state = state.copyWith(clearVideoUploadError: true);
  }

  /// ยกเลิกวีดีโอที่กำลังอัพโหลดหรืออัพโหลดแล้ว
  void cancelVideoUpload() {
    state = state.copyWith(
      clearVideos: true,
      isUploadingVideo: false,
      videoUploadProgress: 0.0,
      clearVideoUploadError: true,
      clearVideoThumbnail: true,
    );
  }

  // === Advanced Post Methods ===

  /// Set title
  void setTitle(String? value) {
    state = state.copyWith(
      title: value?.isEmpty == true ? null : value,
      clearTitle: value?.isEmpty == true,
      clearError: true,
    );
  }

  /// Set quiz question
  void setQaQuestion(String? value) {
    state = state.copyWith(qaQuestion: value, clearError: true);
  }

  /// Set quiz choice A
  void setQaChoiceA(String? value) {
    state = state.copyWith(qaChoiceA: value, clearError: true);
  }

  /// Set quiz choice B
  void setQaChoiceB(String? value) {
    state = state.copyWith(qaChoiceB: value, clearError: true);
  }

  /// Set quiz choice C
  void setQaChoiceC(String? value) {
    state = state.copyWith(qaChoiceC: value, clearError: true);
  }

  /// Set quiz answer ('A', 'B', or 'C')
  void setQaAnswer(String? value) {
    state = state.copyWith(qaAnswer: value, clearError: true);
  }

  /// Clear all quiz fields
  void clearQuiz() {
    state = state.copyWith(clearQuiz: true, clearError: true);
  }

  /// Set AI summary result
  void setAiSummary(String? value) {
    state = state.copyWith(
      aiSummary: value,
      clearAiSummary: value == null,
      isLoadingAI: false,
    );
  }

  /// Set AI loading state
  void setLoadingAI(bool value) {
    state = state.copyWith(isLoadingAI: value);
  }

  /// Clear AI summary
  void clearAiSummary() {
    state = state.copyWith(clearAiSummary: true);
  }

  // === AI Quiz Preview Methods ===

  /// Set AI-generated quiz preview
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

  /// Set AI quiz loading state
  void setLoadingQuizAI(bool value) {
    state = state.copyWith(isLoadingQuizAI: value);
  }

  /// Clear AI quiz preview
  void clearAiQuizPreview() {
    state = state.copyWith(clearAiQuizPreview: true);
  }

  /// Apply AI quiz preview to form fields (keep preview visible)
  void applyAiQuizToForm() {
    if (!state.hasAiQuizPreview) return;

    state = state.copyWith(
      qaQuestion: state.aiQuizQuestion,
      qaChoiceA: state.aiQuizChoiceA,
      qaChoiceB: state.aiQuizChoiceB,
      qaChoiceC: state.aiQuizChoiceC,
      qaAnswer: state.aiQuizAnswer,
      // Don't clear preview - keep it visible
    );
  }

  // === DD Record Methods ===

  /// Initialize state for DD record post creation
  /// รองรับ preselect tag เช่น "พบแพทย์" เมื่อสร้าง post จาก DD
  void initFromDD({
    required int ddId,
    required String templateText,
    int? residentId,
    String? residentName,
    String? title,
    NewTag? preselectedTag,
  }) {
    // ถ้ามี preselectedTag ให้ set handover ตาม mode ของ tag นั้น
    final isHandover = preselectedTag?.isForceHandover ?? false;

    state = CreatePostState(
      text: templateText,
      ddId: ddId,
      ddTemplateText: templateText,
      selectedResidentId: residentId,
      selectedResidentName: residentName,
      title: title,
      selectedTag: preselectedTag,
      isHandover: isHandover,
    );
  }

  /// Clear DD context
  void clearDD() {
    state = state.copyWith(clearDD: true);
  }

  /// Check if current post is for DD record
  bool get hasDDContext => state.ddId != null;
}

/// Provider for create post state
final createPostProvider =
    StateNotifierProvider<CreatePostNotifier, CreatePostState>((ref) {
  return CreatePostNotifier();
});

/// Provider to check if user can create advanced post
/// Uses SystemRole.canQC (level >= 30 = หัวหน้าเวรขึ้นไป)
final canCreateAdvancedPostProvider = Provider<bool>((ref) {
  final roleAsync = ref.watch(currentUserSystemRoleProvider);
  return roleAsync.maybeWhen(
    data: (role) => role?.canQC ?? false,
    orElse: () => false,
  );
});
