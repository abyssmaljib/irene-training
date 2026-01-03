import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/new_tag.dart';
import '../../checklist/providers/task_provider.dart';

/// State สำหรับ Create Post form
class CreatePostState {
  final String text;
  final NewTag? selectedTag;
  final bool isHandover;
  final int? selectedResidentId;
  final String? selectedResidentName;
  final List<File> selectedImages;
  final List<String> uploadedImageUrls;
  final File? selectedVideo;
  final String? uploadedVideoUrl;
  final bool isSubmitting;
  final String? error;

  const CreatePostState({
    this.text = '',
    this.selectedTag,
    this.isHandover = false,
    this.selectedResidentId,
    this.selectedResidentName,
    this.selectedImages = const [],
    this.uploadedImageUrls = const [],
    this.selectedVideo,
    this.uploadedVideoUrl,
    this.isSubmitting = false,
    this.error,
  });

  bool get isValid => text.trim().isNotEmpty;

  bool get hasResident => selectedResidentId != null;

  bool get hasTag => selectedTag != null;

  bool get hasImages => selectedImages.isNotEmpty || uploadedImageUrls.isNotEmpty;

  bool get hasVideo => selectedVideo != null || uploadedVideoUrl != null;

  CreatePostState copyWith({
    String? text,
    NewTag? selectedTag,
    bool? clearTag,
    bool? isHandover,
    int? selectedResidentId,
    bool? clearResident,
    String? selectedResidentName,
    List<File>? selectedImages,
    List<String>? uploadedImageUrls,
    File? selectedVideo,
    bool? clearVideo,
    String? uploadedVideoUrl,
    bool? isSubmitting,
    String? error,
    bool? clearError,
  }) {
    return CreatePostState(
      text: text ?? this.text,
      selectedTag: clearTag == true ? null : (selectedTag ?? this.selectedTag),
      isHandover: isHandover ?? this.isHandover,
      selectedResidentId: clearResident == true
          ? null
          : (selectedResidentId ?? this.selectedResidentId),
      selectedResidentName: clearResident == true
          ? null
          : (selectedResidentName ?? this.selectedResidentName),
      selectedImages: selectedImages ?? this.selectedImages,
      uploadedImageUrls: uploadedImageUrls ?? this.uploadedImageUrls,
      selectedVideo: clearVideo == true ? null : (selectedVideo ?? this.selectedVideo),
      uploadedVideoUrl: clearVideo == true ? null : (uploadedVideoUrl ?? this.uploadedVideoUrl),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError == true ? null : (error ?? this.error),
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

  /// เลือก resident
  void selectResident(int id, String name) {
    state = state.copyWith(
      selectedResidentId: id,
      selectedResidentName: name,
      clearError: true,
    );
  }

  /// ยกเลิกการเลือก resident
  void clearResident() {
    state = state.copyWith(clearResident: true, clearError: true);
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
  void initFromTask({
    required String text,
    int? residentId,
    String? residentName,
  }) {
    state = CreatePostState(
      text: text,
      selectedResidentId: residentId,
      selectedResidentName: residentName,
    );
  }

  /// Clear images after successful upload
  void clearLocalImages() {
    state = state.copyWith(selectedImages: []);
  }

  /// เพิ่มวีดีโอ
  void setVideo(File video) {
    state = state.copyWith(selectedVideo: video, clearError: true);
  }

  /// ลบวีดีโอ
  void clearVideo() {
    state = state.copyWith(clearVideo: true, clearError: true);
  }

  /// Set uploaded video URL
  void setUploadedVideoUrl(String url) {
    state = state.copyWith(uploadedVideoUrl: url);
  }
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
