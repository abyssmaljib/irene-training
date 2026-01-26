import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/medicine_summary.dart';
import 'overlay_med_widget.dart';

/// Item แสดงรูปยา + ชื่อ + จำนวน
class MedicinePhotoItem extends StatelessWidget {
  final MedicineSummary medicine;
  final bool showFoiled; // true = แผง (2C), false = เม็ดยา (3C)
  final bool showOverlay; // แสดง overlay จำนวนเม็ดยา
  final VoidCallback? onTap;
  final BorderRadius? borderRadius; // custom border radius สำหรับ grid layout ที่ชนกัน

  const MedicinePhotoItem({
    super.key,
    required this.medicine,
    this.showFoiled = true,
    this.showOverlay = true,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = showFoiled ? medicine.photo2C : medicine.photo3C;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    // ใช้ borderRadius ที่ส่งมา หรือ default เป็น smallRadius
    final effectiveRadius = borderRadius ?? AppRadius.smallRadius;

    return GestureDetector(
      onTap: onTap ?? (hasPhoto ? () => _showFullImage(context, photoUrl) : null),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: effectiveRadius,
          border: Border.all(color: AppColors.inputBorder),
        ),
        clipBehavior: Clip.antiAlias,
        // ใช้ Stack เพื่อให้ชื่อยาซ้อนบนรูป
        child: Stack(
          fit: StackFit.expand,
          children: [
            // รูปยา - เต็มพื้นที่
            hasPhoto
                ? _MedicineNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: AppColors.background,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: _buildPlaceholder(),
                  )
                : _buildPlaceholder(),

            // Overlay จำนวนเม็ดยา
            if (showOverlay && medicine.takeTab != null && medicine.takeTab! > 0)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return OverlayMedWidget(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      takeTab: medicine.takeTab,
                    );
                  },
                ),
              ),

            // ชื่อยา - ซ้อนด้านล่างแบบ gradient ใส
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  medicine.str != null && medicine.str!.isNotEmpty
                      ? '${medicine.displayName} ${medicine.str}'
                      : medicine.displayName,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedImage01,
              size: AppIconSize.xxl,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: 4),
            Text(
              showFoiled ? 'ไม่มีรูป (จัดยา)' : 'ไม่มีรูป (เสิร์ฟยา)',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(AppSpacing.md),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadius.mediumRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  border: Border(
                    bottom: BorderSide(color: AppColors.inputBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        medicine.displayName,
                        style: AppTypography.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancelCircle,
                        color: AppColors.textSecondary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Image
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    // จำกัดขนาดใน memory เพื่อป้องกัน crash บน iOS/Android สเปคต่ำ
                    cacheWidth: 1200,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedImage01,
                              size: AppIconSize.xxxl,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'ไม่สามารถโหลดรูปได้',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Medicine Detail Card
              _buildMedicineDetailCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// Format ชื่อการค้า + strength + (generic name)
  /// เช่น "Berlontin 100 mg (gabapentin)"
  String _formatBrandNameWithGeneric() {
    final parts = <String>[];

    // Brand name
    if (medicine.brandName != null && medicine.brandName!.isNotEmpty) {
      parts.add(medicine.brandName!);
    }

    // Strength
    if (medicine.str != null && medicine.str!.isNotEmpty) {
      parts.add(medicine.str!);
    }

    var result = parts.join(' ');

    // Generic name in parentheses
    if (medicine.displayName.isNotEmpty) {
      result += ' (${medicine.displayName})';
    }

    return result;
  }

  /// Card แสดงรายละเอียดยา
  Widget _buildMedicineDetailCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.inputBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Brand name + Strength (generic name)
          if (medicine.brandName != null && medicine.brandName!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _buildInfoItem(
                icon: HugeIcons.strokeRoundedTag01,
                label: 'ชื่อการค้า',
                value: _formatBrandNameWithGeneric(),
              ),
            ),

          // Row 2: Dosage + Route
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (medicine.displayDosage.isNotEmpty)
                  _buildInfoChip(medicine.displayDosage, const Color(0xFF0EA5E9)),
                if (medicine.route != null && medicine.route!.isNotEmpty) ...[
                  SizedBox(width: 8),
                  _buildInfoChip(medicine.route!, const Color(0xFF8B5CF6)),
                ],
                if (medicine.prn == true) ...[
                  SizedBox(width: 8),
                  _buildInfoChip('PRN', const Color(0xFFF97316)),
                ],
              ],
            ),
          ),

          // Row 3: Category (ATC)
          if (medicine.atcLevel2NameTh != null || medicine.atcLevel1NameTh != null)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _buildInfoItem(
                icon: HugeIcons.strokeRoundedDashboardSquare01,
                label: 'ประเภท',
                value: medicine.atcLevel2NameTh ?? medicine.atcLevel1NameTh ?? '',
              ),
            ),

          // Row 4: Meals (BLDB) + Before/After
          if (medicine.bldb.isNotEmpty || medicine.beforeAfter.isNotEmpty)
            _buildMealInfo(),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required dynamic icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: AppIconSize.sm, color: AppColors.textSecondary),
        SizedBox(width: 4),
        Text(
          '$label: ',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.fullRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildMealInfo() {
    // Meal icons
    final mealIcons = {
      'เช้า': HugeIcons.strokeRoundedSun01,
      'กลางวัน': HugeIcons.strokeRoundedSun03,
      'เย็น': HugeIcons.strokeRoundedMoon02,
      'ก่อนนอน': HugeIcons.strokeRoundedMoon02,
    };

    final mealColors = {
      'เช้า': const Color(0xFFF59E0B),
      'กลางวัน': const Color(0xFFF97316),
      'เย็น': const Color(0xFF3B82F6),
      'ก่อนนอน': const Color(0xFF8B5CF6),
    };

    return Row(
      children: [
        HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: AppIconSize.sm, color: AppColors.textSecondary),
        SizedBox(width: 4),
        Text(
          'มื้อ: ',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        // Meal chips
        ...medicine.bldb.map((meal) {
          final color = mealColors[meal] ?? AppColors.primary;
          final icon = mealIcons[meal] ?? HugeIcons.strokeRoundedClock01;
          return Padding(
            padding: EdgeInsets.only(right: 4),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.fullRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(icon: icon, size: AppIconSize.xs, color: color),
                  SizedBox(width: 2),
                  Text(
                    meal,
                    style: AppTypography.caption.copyWith(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        // Before/After chips
        if (medicine.beforeAfter.isNotEmpty) ...[
          SizedBox(width: 4),
          ...medicine.beforeAfter.map((ba) {
            final isBefore = ba.contains('ก่อน');
            final color = isBefore ? const Color(0xFF0EA5E9) : const Color(0xFFEF4444);
            return Padding(
              padding: EdgeInsets.only(right: 4),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.fullRadius,
                ),
                child: Text(
                  ba,
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

/// Widget สำหรับแสดงรูปยาจาก network พร้อม timeout และ retry mechanism
/// - มี timeout 15 วินาที ถ้าโหลดไม่เสร็จจะแสดงข้อความ "โหลดช้า" พร้อมปุ่มลองใหม่
/// - ถ้า error จะแสดงข้อความ "โหลดไม่ได้" พร้อมปุ่มลองใหม่
/// - ใช้ _retryCount เป็น key เพื่อบังคับ rebuild เมื่อกดลองใหม่
class _MedicineNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget placeholder; // Widget สำหรับแสดงระหว่างโหลด
  final Widget errorWidget; // Widget สำหรับแสดงเมื่อ error (fallback)

  const _MedicineNetworkImage({
    required this.imageUrl,
    required this.fit,
    required this.placeholder,
    required this.errorWidget,
  });

  @override
  State<_MedicineNetworkImage> createState() => _MedicineNetworkImageState();
}

class _MedicineNetworkImageState extends State<_MedicineNetworkImage> {
  // Timeout 15 วินาที - ถ้าโหลดนานกว่านี้ถือว่าช้าเกินไป
  static const _loadTimeout = Duration(seconds: 15);

  bool _isLoading = true; // กำลังโหลดอยู่หรือไม่
  bool _hasError = false; // เกิด error หรือไม่
  bool _timedOut = false; // timeout หรือไม่
  Timer? _timeoutTimer; // Timer สำหรับนับ timeout
  int _retryCount = 0; // นับจำนวนครั้งที่กด retry (ใช้เป็น key เพื่อ force rebuild)

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
    _timeoutTimer = Timer(_loadTimeout, () {
      // ถ้ายังโหลดอยู่และ widget ยัง mount อยู่ = timeout
      if (_isLoading && mounted) {
        setState(() {
          _timedOut = true;
          _isLoading = false;
        });
      }
    });
  }

  /// กดปุ่มลองใหม่ - reset state และเพิ่ม retryCount เพื่อ force rebuild CachedNetworkImage
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

  /// เรียกเมื่อเกิด error ตอนโหลดรูป
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
    // ถ้า timeout แสดง UI สำหรับ timeout
    if (_timedOut) return _buildTimeoutWidget();
    // ถ้า error แสดง UI สำหรับ error
    if (_hasError) return _buildErrorWidget();

    // ใช้ CachedNetworkImage พร้อม key ที่เปลี่ยนเมื่อ retry
    // เพื่อบังคับให้โหลดใหม่
    return CachedNetworkImage(
      key: ValueKey('${widget.imageUrl}_$_retryCount'),
      imageUrl: widget.imageUrl,
      fit: widget.fit,
      fadeInDuration: const Duration(milliseconds: 150),
      // ใช้แค่ memCacheWidth เพื่อรักษา aspect ratio ของรูปต้นฉบับ
      // (ถ้าใส่ทั้ง width และ height จะบังคับให้รูปเป็น 1:1 ทำให้บิดเบี้ยว)
      memCacheWidth: 400,
      // placeholder แสดงระหว่างโหลด
      placeholder: (context, url) => widget.placeholder,
      // errorWidget เรียก _onImageError เพื่อ update state
      errorWidget: (context, url, error) {
        // ใช้ addPostFrameCallback เพื่อหลีกเลี่ยง setState ระหว่าง build
        WidgetsBinding.instance.addPostFrameCallback((_) => _onImageError());
        return widget.errorWidget;
      },
      // imageBuilder เรียก _onImageLoaded เมื่อรูปโหลดสำเร็จ
      imageBuilder: (context, imageProvider) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onImageLoaded());
        return Image(image: imageProvider, fit: widget.fit);
      },
    );
  }

  /// Widget แสดงเมื่อ timeout (โหลดช้า)
  Widget _buildTimeoutWidget() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon wifi error สี pending
            HugeIcon(
              icon: HugeIcons.strokeRoundedWifiError01,
              size: AppIconSize.xl,
              color: AppColors.tagPendingText,
            ),
            SizedBox(height: 4),
            Text(
              'โหลดช้า',
              style: AppTypography.caption.copyWith(
                color: AppColors.tagPendingText,
                fontSize: 9,
              ),
            ),
            SizedBox(height: 4),
            // ปุ่มลองใหม่
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            ),
          ],
        ),
      ),
    );
  }

  /// Widget แสดงเมื่อ error (โหลดไม่สำเร็จ)
  Widget _buildErrorWidget() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon wifi error สี secondary
            HugeIcon(
              icon: HugeIcons.strokeRoundedWifiError01,
              size: AppIconSize.xl,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 4),
            Text(
              'โหลดไม่สำเร็จ',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 9,
              ),
            ),
            // บอก user ว่าอาจเป็นเพราะเน็ตช้า
            Text(
              'เน็ตช้าหรือไม่มีสัญญาณ',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 8,
              ),
            ),
            SizedBox(height: 4),
            // ปุ่มลองใหม่
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            ),
          ],
        ),
      ),
    );
  }
}
