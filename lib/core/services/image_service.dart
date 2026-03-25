/// Service สำหรับจัดการรูปภาพ - resize, optimize
class ImageService {
  ImageService._();

  /// Transform Supabase Storage URL เพื่อ resize รูป
  /// ใช้ Supabase Image Transformation API
  ///
  /// [url] - URL ของรูปจาก Supabase Storage
  /// [width] - ความกว้างที่ต้องการ (pixel)
  /// [quality] - คุณภาพรูป (1-100), default 75
  /// [resize] - วิธีการ resize: 'contain' (ไม่ crop), 'cover' (crop ให้เต็ม), 'fill'
  ///
  /// Example:
  /// Original: https://xxx.supabase.co/storage/v1/object/public/bucket/image.jpg
  /// Transformed: https://xxx.supabase.co/storage/v1/render/image/public/bucket/image.jpg?width=300&quality=75&resize=contain
  static String getResizedUrl(
    String url, {
    int? width,
    int quality = 75,
    String resize = 'contain',
  }) {
    if (url.isEmpty) return url;

    // ตรวจสอบว่าเป็น Supabase Storage URL หรือไม่
    if (!url.contains('supabase.co/storage/v1/object/')) {
      return url;
    }

    // แปลง URL จาก object เป็น render/image
    // /storage/v1/object/public/... -> /storage/v1/render/image/public/...
    final transformedUrl = url.replaceFirst(
      '/storage/v1/object/',
      '/storage/v1/render/image/',
    );

    // เพิ่ม query parameters
    // resize=contain เพื่อให้ scale รูปทั้งหมดโดยไม่ crop
    final params = <String>[];
    if (width != null) {
      params.add('width=$width');
    }
    params.add('quality=$quality');
    params.add('resize=$resize');

    final queryString = params.join('&');

    // ตรวจสอบว่ามี query string อยู่แล้วหรือไม่
    if (transformedUrl.contains('?')) {
      return '$transformedUrl&$queryString';
    } else {
      return '$transformedUrl?$queryString';
    }
  }

  /// Get thumbnail URL (200px width, 60% quality)
  static String getThumbnailUrl(String url) {
    return getResizedUrl(url, width: 200, quality: 60);
  }

  /// Get medium size URL (400px width, 70% quality)
  static String getMediumUrl(String url) {
    return getResizedUrl(url, width: 400, quality: 70);
  }

  /// Get large size URL (800px width, 80% quality)
  static String getLargeUrl(String url) {
    return getResizedUrl(url, width: 800, quality: 80);
  }

  /// แปลง URL ต้นฉบับเป็น URL ของ static thumbnail (_thumb)
  /// ใช้สำหรับรูปที่มี pre-generated thumbnail อยู่ใน Storage แล้ว
  /// (เช่น รูปตัวอย่างยาใน nursingcare bucket)
  ///
  /// แทรก '_thumb' ก่อน extension:
  /// .../front-foiled.jpg → .../front-foiled_thumb.jpg
  ///
  /// ถ้า URL ว่างหรือไม่มี extension → return URL เดิม
  static String getStaticThumbnailUrl(String url) {
    if (url.isEmpty) return url;

    // หา '.' ตัวสุดท้ายเพื่อแทรก _thumb ก่อน extension
    final lastDot = url.lastIndexOf('.');
    if (lastDot == -1) return url;

    // ตรวจว่า '.' อยู่หลัง '/' ตัวสุดท้าย (เป็น extension จริง ไม่ใช่ dot ใน domain)
    final lastSlash = url.lastIndexOf('/');
    if (lastDot < lastSlash) return url;

    return '${url.substring(0, lastDot)}_thumb${url.substring(lastDot)}';
  }
}
