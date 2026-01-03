import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service สำหรับ upload รูปภาพและวิดีโอสำหรับ Posts
class PostMediaService {
  static final instance = PostMediaService._();
  PostMediaService._();

  final _supabase = Supabase.instance.client;

  /// ชื่อ bucket ใน Supabase Storage
  static const _bucketName = 'post-media';

  /// Video file extensions
  static const _videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'];

  /// ตรวจสอบว่า URL เป็น video หรือไม่
  static bool isVideoUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return _videoExtensions.any((ext) => lowerUrl.contains(ext));
  }

  /// แยก URLs เป็น images และ videos
  static ({List<String> images, List<String> videos}) separateMediaUrls(List<String>? urls) {
    if (urls == null || urls.isEmpty) {
      return (images: [], videos: []);
    }

    final images = <String>[];
    final videos = <String>[];

    for (final url in urls) {
      if (isVideoUrl(url)) {
        videos.add(url);
      } else {
        images.add(url);
      }
    }

    return (images: images, videos: videos);
  }

  /// Upload รูปภาพไป Supabase Storage
  /// Returns URL ของรูปที่ upload แล้ว หรือ null ถ้า error
  Future<String?> uploadImage(File file, {String? userId}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(file.path);
      final safeExt = extension.isNotEmpty ? extension : '.jpg';
      final fileName = '${userId ?? 'unknown'}_$timestamp$safeExt';
      final filePath = 'images/$fileName';

      debugPrint('PostMediaService: uploading image $filePath');

      await _supabase.storage.from(_bucketName).upload(filePath, file);

      final url = _supabase.storage.from(_bucketName).getPublicUrl(filePath);

      debugPrint('PostMediaService: uploaded image successfully, URL: $url');
      return url;
    } catch (e) {
      debugPrint('PostMediaService uploadImage error: $e');
      return null;
    }
  }

  /// Upload หลายรูปภาพพร้อมกัน
  /// Returns list ของ URLs ที่ upload สำเร็จ
  Future<List<String>> uploadImages(List<File> files, {String? userId}) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadImage(file, userId: userId);
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }

  /// Upload วิดีโอไป Supabase Storage
  /// Returns URL ของวิดีโอที่ upload แล้ว หรือ null ถ้า error
  Future<String?> uploadVideo(File file, {String? userId}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(file.path);
      final safeExt = extension.isNotEmpty ? extension : '.mp4';
      final fileName = '${userId ?? 'unknown'}_$timestamp$safeExt';
      final filePath = 'videos/$fileName';

      debugPrint('PostMediaService: uploading video $filePath');

      // Get file size for logging
      final fileSize = await file.length();
      debugPrint('PostMediaService: video size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      await _supabase.storage.from(_bucketName).upload(filePath, file);

      final url = _supabase.storage.from(_bucketName).getPublicUrl(filePath);

      debugPrint('PostMediaService: uploaded video successfully, URL: $url');
      return url;
    } catch (e) {
      debugPrint('PostMediaService uploadVideo error: $e');
      return null;
    }
  }

  /// ดึง file extension จาก path
  String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filePath.length - 1) {
      return '';
    }
    return filePath.substring(lastDot).toLowerCase();
  }

  /// Upload ทั้งรูปและวิดีโอ แล้วรวม URLs เป็น list เดียว
  /// Returns list ของ URLs ทั้งหมด (images + video)
  Future<List<String>> uploadAllMedia({
    required List<File> images,
    File? video,
    String? userId,
  }) async {
    final urls = <String>[];

    // Upload images
    if (images.isNotEmpty) {
      final imageUrls = await uploadImages(images, userId: userId);
      urls.addAll(imageUrls);
    }

    // Upload video
    if (video != null) {
      final videoUrl = await uploadVideo(video, userId: userId);
      if (videoUrl != null) {
        urls.add(videoUrl);
      }
    }

    return urls;
  }
}
