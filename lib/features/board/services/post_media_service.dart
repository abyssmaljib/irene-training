import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

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

      // อ่านเป็น bytes สำหรับ upload (รองรับทั้ง mobile และ web)
      final bytes = await file.readAsBytes();

      await _supabase.storage.from(_bucketName).uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(contentType: 'image/jpeg'),
      );

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

      // อ่านเป็น bytes สำหรับ upload (รองรับทั้ง mobile และ web)
      final bytes = await file.readAsBytes();
      debugPrint('PostMediaService: video size: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');

      await _supabase.storage.from(_bucketName).uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(contentType: 'video/mp4'),
      );

      final url = _supabase.storage.from(_bucketName).getPublicUrl(filePath);

      debugPrint('PostMediaService: uploaded video successfully, URL: $url');
      return url;
    } catch (e) {
      debugPrint('PostMediaService uploadVideo error: $e');
      return null;
    }
  }

  /// Generate thumbnail จาก video file
  /// Returns File ของ thumbnail หรือ null ถ้า error
  Future<File?> generateVideoThumbnail(File videoFile) async {
    try {
      // ไม่ support web
      if (kIsWeb) {
        debugPrint('PostMediaService: thumbnail generation not supported on web');
        return null;
      }

      debugPrint('PostMediaService: generating thumbnail for ${videoFile.path}');

      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 512,
        quality: 75,
      );

      if (thumbnailPath == null) {
        debugPrint('PostMediaService: failed to generate thumbnail');
        return null;
      }

      debugPrint('PostMediaService: thumbnail generated at $thumbnailPath');
      return File(thumbnailPath);
    } catch (e) {
      debugPrint('PostMediaService generateVideoThumbnail error: $e');
      return null;
    }
  }

  /// Upload thumbnail ไป Supabase Storage
  /// Returns URL ของ thumbnail หรือ null ถ้า error
  Future<String?> uploadThumbnail(File file, {String? userId}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${userId ?? 'unknown'}_thumb_$timestamp.jpg';
      final filePath = 'thumbnails/$fileName';

      debugPrint('PostMediaService: uploading thumbnail $filePath');

      // อ่านเป็น bytes สำหรับ upload
      final bytes = await file.readAsBytes();

      await _supabase.storage.from(_bucketName).uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(contentType: 'image/jpeg'),
      );

      final url = _supabase.storage.from(_bucketName).getPublicUrl(filePath);

      debugPrint('PostMediaService: uploaded thumbnail successfully, URL: $url');
      return url;
    } catch (e) {
      debugPrint('PostMediaService uploadThumbnail error: $e');
      return null;
    }
  }

  /// Upload video พร้อม generate และ upload thumbnail
  /// Returns ({videoUrl, thumbnailUrl}) หรือ null ถ้า video upload failed
  Future<({String? videoUrl, String? thumbnailUrl})> uploadVideoWithThumbnail(
    File videoFile, {
    String? userId,
  }) async {
    // Generate thumbnail ก่อน upload video
    final thumbnailFile = await generateVideoThumbnail(videoFile);

    // Upload video
    final videoUrl = await uploadVideo(videoFile, userId: userId);
    if (videoUrl == null) {
      return (videoUrl: null, thumbnailUrl: null);
    }

    // Upload thumbnail (ถ้ามี)
    String? thumbnailUrl;
    if (thumbnailFile != null) {
      thumbnailUrl = await uploadThumbnail(thumbnailFile, userId: userId);
      // ลบ temp file
      try {
        await thumbnailFile.delete();
      } catch (_) {}
    }

    return (videoUrl: videoUrl, thumbnailUrl: thumbnailUrl);
  }

  /// Upload video พร้อม generate thumbnail และ REAL progress callback ผ่าน dio
  /// [DEPRECATED] ใช้ uploadVideoWithTus() แทน สำหรับ resumable uploads
  /// Progress: 0-10% thumbnail generation, 10-90% video upload (real), 90-100% thumbnail upload
  /// Returns ({videoUrl, thumbnailUrl}) หรือ null ถ้า video upload failed
  Future<({String? videoUrl, String? thumbnailUrl})> uploadVideoWithProgress(
    File videoFile, {
    String? userId,
    void Function(double progress)? onProgress,
    dio.CancelToken? cancelToken,
  }) async {
    try {
      // Stage 1: Generate thumbnail (0-10%)
      onProgress?.call(0.02);
      debugPrint('PostMediaService: [Progress 2%] Starting thumbnail generation...');

      final thumbnailFile = await generateVideoThumbnail(videoFile);
      onProgress?.call(0.10);
      debugPrint('PostMediaService: [Progress 10%] Thumbnail generated');

      // Stage 2: Upload video ด้วย dio (10-90%) - REAL progress tracking
      onProgress?.call(0.10);
      debugPrint('PostMediaService: [Progress 10%] Starting video upload with streaming...');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(videoFile.path);
      final safeExt = extension.isNotEmpty ? extension : '.mp4';
      final fileName = '${userId ?? 'unknown'}_$timestamp$safeExt';
      final filePath = 'videos/$fileName';

      // ดึง file size สำหรับแสดง info
      final fileSize = await videoFile.length();
      final fileSizeMB = fileSize / 1024 / 1024;
      debugPrint('PostMediaService: Video size: ${fileSizeMB.toStringAsFixed(2)} MB');

      // สร้าง Supabase Storage upload URL
      // Format: https://<project>.supabase.co/storage/v1/object/<bucket>/<path>
      // ใช้ rest.url และแทนที่ /rest/v1 เป็น /storage/v1
      final supabaseUrl = _supabase.rest.url.replaceAll('/rest/v1', '');
      final uploadUrl = '$supabaseUrl/storage/v1/object/$_bucketName/$filePath';

      // ดึง access token สำหรับ authorization
      final session = _supabase.auth.currentSession;
      final accessToken = session?.accessToken ?? '';

      // สร้าง dio instance สำหรับ upload
      final dioClient = dio.Dio();

      // ใช้ streaming upload ด้วย dio - จะได้ REAL progress
      // อ่านไฟล์เป็น stream แทนที่จะโหลดทั้งหมดเข้า memory
      final formData = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(
          videoFile.path,
          filename: fileName,
          contentType: dio.DioMediaType('video', 'mp4'),
        ),
      });

      debugPrint('PostMediaService: Uploading to $uploadUrl');

      // Upload ด้วย dio พร้อม onSendProgress callback
      final response = await dioClient.post(
        uploadUrl,
        data: formData,
        cancelToken: cancelToken,
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            // ไม่ใช้ x-upsert เพราะเราใช้ชื่อไฟล์ unique (timestamp) อยู่แล้ว
            // และ x-upsert ต้องผ่านทั้ง INSERT + UPDATE policy
          },
        ),
        // นี่คือ REAL progress - dio จะ report ทุกครั้งที่ส่งข้อมูลไป server
        onSendProgress: (sent, total) {
          // แปลง progress จาก 10-90% (80% ของ total)
          final uploadProgress = sent / total;
          final overallProgress = 0.10 + (uploadProgress * 0.80);
          onProgress?.call(overallProgress);

          // Log progress ทุก 10%
          final percent = (uploadProgress * 100).toInt();
          if (percent % 10 == 0) {
            final sentMB = (sent / 1024 / 1024).toStringAsFixed(1);
            final totalMB = (total / 1024 / 1024).toStringAsFixed(1);
            debugPrint(
                'PostMediaService: [Upload $percent%] $sentMB MB / $totalMB MB');
          }
        },
      );

      // ตรวจสอบ response
      if (response.statusCode != 200) {
        debugPrint('PostMediaService: Upload failed with status ${response.statusCode}');
        debugPrint('PostMediaService: Response: ${response.data}');
        return (videoUrl: null, thumbnailUrl: null);
      }

      final videoUrl = _supabase.storage.from(_bucketName).getPublicUrl(filePath);
      onProgress?.call(0.90);
      debugPrint('PostMediaService: [Progress 90%] Video uploaded successfully');
      debugPrint('PostMediaService: Video URL: $videoUrl');

      // Stage 3: Upload thumbnail (90-100%)
      String? thumbnailUrl;
      if (thumbnailFile != null) {
        onProgress?.call(0.92);
        debugPrint('PostMediaService: [Progress 92%] Starting thumbnail upload...');

        thumbnailUrl = await uploadThumbnail(thumbnailFile, userId: userId);

        // ลบ temp file
        try {
          await thumbnailFile.delete();
        } catch (_) {}
      }

      onProgress?.call(1.0);
      debugPrint('PostMediaService: [Progress 100%] Upload complete!');

      return (videoUrl: videoUrl, thumbnailUrl: thumbnailUrl);
    } on dio.DioException catch (e) {
      if (e.type == dio.DioExceptionType.cancel) {
        debugPrint('PostMediaService: Upload cancelled by user');
        return (videoUrl: null, thumbnailUrl: null);
      }
      debugPrint('PostMediaService uploadVideoWithProgress DioError: ${e.message}');
      debugPrint('PostMediaService DioError response: ${e.response?.data}');
      return (videoUrl: null, thumbnailUrl: null);
    } catch (e) {
      debugPrint('PostMediaService uploadVideoWithProgress error: $e');
      return (videoUrl: null, thumbnailUrl: null);
    }
  }

  /// สร้าง CancelToken สำหรับยกเลิก upload (สำหรับ dio)
  dio.CancelToken createCancelToken() => dio.CancelToken();

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
