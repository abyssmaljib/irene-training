// IreneNetworkImage - Widget สำหรับโหลดรูปจาก network
//
// มี timeout 15 วินาที และ retry mechanism สำหรับอินเตอร์เน็ตช้า
// ใช้แทน Image.network หรือ CachedNetworkImage โดยตรง
//
// ตัวอย่างการใช้งาน:
// ```dart
// IreneNetworkImage(
//   imageUrl: 'https://example.com/image.jpg',
//   width: 200,
//   height: 150,
//   fit: BoxFit.cover,
// )
// ```

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../services/image_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Widget สำหรับโหลดรูปจาก network พร้อม timeout และ retry mechanism
///
/// Features:
/// - Timeout 15 วินาที - ถ้าโหลดไม่เสร็จจะแสดง "โหลดช้า" + ปุ่มลองใหม่
/// - Error handling - ถ้าโหลดไม่ได้จะแสดง "โหลดไม่สำเร็จ" + ปุ่มลองใหม่
/// - Memory optimization - ใช้ memCacheWidth/Height เพื่อลด memory usage
/// - Retry mechanism - กดลองใหม่ได้เมื่อ timeout หรือ error
class IreneNetworkImage extends StatefulWidget {
  /// URL ของรูปที่ต้องการโหลด
  final String imageUrl;

  /// ขนาด widget (ถ้าไม่ระบุจะใช้ขนาดจาก parent)
  final double? width;
  final double? height;

  /// วิธีการ fit รูปใน container
  final BoxFit fit;

  /// ขนาดสำหรับ cache ใน memory (default = 400)
  /// ใช้เพื่อไม่ให้โหลดรูปขนาดใหญ่เกินไปเข้า memory
  final int? memCacheWidth;
  final int? memCacheHeight;

  /// Border radius ของรูป
  final BorderRadius? borderRadius;

  /// Widget ที่จะแสดงแทนเมื่อ error (optional)
  /// ถ้าไม่ระบุจะใช้ default error widget ที่มีปุ่มลองใหม่
  final Widget? errorPlaceholder;

  /// แสดง UI แบบ compact สำหรับรูปเล็กๆ (เช่น avatar)
  /// - ไม่แสดงข้อความ "โหลดช้า" หรือ "เน็ตช้าหรือไม่มีสัญญาณ"
  /// - แสดงแค่ icon + ปุ่มลองใหม่
  final bool compact;

  /// Timeout duration (default = 15 วินาที)
  final Duration timeout;

  /// ใช้ Supabase Image Transformation เพื่อโหลดรูปขนาดเล็กจาก server
  /// ช่วยลดขนาด download จาก ~1.5MB → ~50KB (ลด 96%)
  /// Default = true
  final bool useServerResize;

  const IreneNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth = 400,
    this.memCacheHeight,
    this.borderRadius,
    this.errorPlaceholder,
    this.compact = false,
    this.timeout = const Duration(seconds: 15),
    this.useServerResize = true,
  });

  @override
  State<IreneNetworkImage> createState() => _IreneNetworkImageState();
}

class _IreneNetworkImageState extends State<IreneNetworkImage> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _timedOut = false;
  Timer? _timeoutTimer;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  /// เริ่ม timer นับถอยหลัง timeout
  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(widget.timeout, () {
      if (_isLoading && mounted) {
        setState(() {
          _timedOut = true;
          _isLoading = false;
        });
      }
    });
  }

  /// กดปุ่มลองใหม่
  void _retry() {
    if (!mounted) return;
    setState(() {
      _retryCount++;
      _isLoading = true;
      _hasError = false;
      _timedOut = false;
    });
    _startTimeoutTimer();
  }

  /// เรียกเมื่อรูปโหลดสำเร็จ
  void _onImageLoaded() {
    _timeoutTimer?.cancel();
    if (mounted && _isLoading) {
      setState(() {
        _isLoading = false;
        _hasError = false;
        _timedOut = false;
      });
    }
  }

  /// เรียกเมื่อเกิด error
  void _onImageError() {
    _timeoutTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ Supabase Image Transformation เพื่อโหลดรูปขนาดเล็กจาก server
    // ลดจาก ~1.5MB → ~50KB ช่วยแก้ปัญหา crash บน iOS
    final effectiveUrl = widget.useServerResize
        ? ImageService.getResizedUrl(
            widget.imageUrl,
            width: widget.memCacheWidth ?? 400,
            quality: 75,
          )
        : widget.imageUrl;

    Widget imageWidget;

    if (_timedOut) {
      imageWidget = _buildTimeoutWidget();
    } else if (_hasError) {
      imageWidget = widget.errorPlaceholder ?? _buildErrorWidget();
    } else {
      imageWidget = CachedNetworkImage(
        key: ValueKey('${widget.imageUrl}_$_retryCount'),
        imageUrl: effectiveUrl,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        fadeInDuration: const Duration(milliseconds: 150),
        memCacheWidth: widget.memCacheWidth,
        memCacheHeight: widget.memCacheHeight,
        placeholder: (context, url) => _buildLoadingWidget(),
        errorWidget: (context, url, error) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onImageError());
          return widget.errorPlaceholder ?? _buildErrorWidget();
        },
        imageBuilder: (context, imageProvider) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onImageLoaded());
          return Image(
            image: imageProvider,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
          );
        },
      );
    }

    // ใส่ borderRadius ถ้ามี
    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Widget แสดงระหว่างโหลด
  Widget _buildLoadingWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.background,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  /// Widget แสดงเมื่อ timeout
  Widget _buildTimeoutWidget() {
    if (widget.compact) {
      return _buildCompactErrorWidget(
        icon: HugeIcons.strokeRoundedWifiError01,
        color: AppColors.tagPendingText,
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedWifiError01,
              size: AppIconSize.xl,
              color: AppColors.tagPendingText,
            ),
            const SizedBox(height: 4),
            Text(
              'โหลดช้า',
              style: AppTypography.caption.copyWith(
                color: AppColors.tagPendingText,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 4),
            _buildRetryButton(),
          ],
        ),
      ),
    );
  }

  /// Widget แสดงเมื่อ error
  Widget _buildErrorWidget() {
    if (widget.compact) {
      return _buildCompactErrorWidget(
        icon: HugeIcons.strokeRoundedWifiError01,
        color: AppColors.textSecondary,
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedWifiError01,
              size: AppIconSize.xl,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              'โหลดไม่สำเร็จ',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 9,
              ),
            ),
            Text(
              'เน็ตช้าหรือไม่มีสัญญาณ',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 8,
              ),
            ),
            const SizedBox(height: 4),
            _buildRetryButton(),
          ],
        ),
      ),
    );
  }

  /// Compact error widget สำหรับรูปเล็กๆ
  Widget _buildCompactErrorWidget({
    required dynamic icon,
    required Color color,
  }) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.background,
      child: Center(
        child: GestureDetector(
          onTap: _retry,
          child: HugeIcon(
            icon: icon,
            size: AppIconSize.md,
            color: color,
          ),
        ),
      ),
    );
  }

  /// ปุ่มลองใหม่
  Widget _buildRetryButton() {
    return GestureDetector(
      onTap: _retry,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: AppRadius.fullRadius,
        ),
        child: Text(
          'ลองใหม่',
          style: AppTypography.caption.copyWith(
            color: AppColors.primary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Widget สำหรับแสดง avatar จาก network
///
/// เหมาะสำหรับรูปโปรไฟล์ขนาดเล็กที่ต้องการ:
/// - ClipOval อัตโนมัติ
/// - cacheWidth ที่เหมาะสม (48 หรือ 96 px)
/// - Compact error UI (แค่ icon)
/// - Fallback icon เมื่อโหลดไม่ได้
class IreneNetworkAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget? fallbackIcon;

  const IreneNetworkAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final cacheSize = (diameter * 2).toInt(); // 2x สำหรับ high DPI

    // ถ้าไม่มี URL แสดง fallback
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? AppColors.accent1,
        child: fallbackIcon ??
            HugeIcon(
              icon: HugeIcons.strokeRoundedUser,
              size: radius,
              color: AppColors.primary,
            ),
      );
    }

    return ClipOval(
      child: IreneNetworkImage(
        imageUrl: imageUrl!,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        memCacheWidth: cacheSize,
        compact: true,
        errorPlaceholder: CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? AppColors.accent1,
          child: fallbackIcon ??
              HugeIcon(
                icon: HugeIcons.strokeRoundedUser,
                size: radius,
                color: AppColors.primary,
              ),
        ),
      ),
    );
  }
}
