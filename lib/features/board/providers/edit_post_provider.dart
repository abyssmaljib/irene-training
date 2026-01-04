import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';

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

  const EditPostState({
    required this.postId,
    this.text = '',
    this.title,
    this.existingImageUrls = const [],
    this.removedExistingIndexes = const {},
    this.newImages = const [],
    this.isSubmitting = false,
    this.error,
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
      removedExistingIndexes.isNotEmpty;

  EditPostState copyWith({
    int? postId,
    String? text,
    String? title,
    List<String>? existingImageUrls,
    Set<int>? removedExistingIndexes,
    List<File>? newImages,
    bool? isSubmitting,
    String? error,
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
    );
  }
}

/// Notifier for Edit Post state
class EditPostNotifier extends StateNotifier<EditPostState> {
  EditPostNotifier(int postId) : super(EditPostState(postId: postId));

  /// Initialize from existing post
  void initFromPost(Post post) {
    state = EditPostState(
      postId: post.id,
      text: post.text ?? '',
      title: post.title,
      existingImageUrls: post.allImageUrls,
    );
    debugPrint('EditPostNotifier: initialized from post ${post.id}');
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

  void reset() {
    state = EditPostState(postId: state.postId);
  }
}

/// Provider family for edit post (keyed by postId)
final editPostProvider =
    StateNotifierProvider.family<EditPostNotifier, EditPostState, int>(
  (ref, postId) => EditPostNotifier(postId),
);
