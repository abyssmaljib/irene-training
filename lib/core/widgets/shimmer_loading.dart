import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// =============================================================
/// Shimmer Loading System — Skeleton loading แบบไม่ใช้ package
/// =============================================================
///
/// ใช้แทน CircularProgressIndicator สำหรับ loading ที่ดูดีกว่า
/// สร้างจาก AnimationController + LinearGradient + ShaderMask
///
/// มี 4 widget หลัก:
/// 1. [ShimmerWrapper] — wrap children ด้วย shimmer animation
/// 2. [ShimmerBox] — กล่อง shimmer (สี่เหลี่ยม, วงกลม, text line)
/// 3. [SkeletonListItem] — skeleton สำหรับ list item (avatar + text lines)
/// 4. [SkeletonCard] — skeleton สำหรับ card (image area + text lines)
///
/// วิธีใช้:
/// ```dart
/// // wrap ทั้ง group ด้วย ShimmerWrapper
/// ShimmerWrapper(
///   isLoading: isLoading,
///   child: isLoading
///     ? Column(children: [
///         SkeletonListItem(),
///         SkeletonListItem(),
///         SkeletonListItem(),
///       ])
///     : RealContent(),
/// )
///
/// // หรือใช้ ShimmerBox เดี่ยวๆ
/// ShimmerWrapper(
///   isLoading: true,
///   child: ShimmerBox(width: 200, height: 20),
/// )
/// ```

// =====================
// ShimmerWrapper
// =====================

/// ShimmerWrapper — ครอบ widget ด้วย shimmer animation effect
/// ทำให้ child widgets ทั้งหมดมี animation วิ่งซ้ายไปขวา
///
/// [isLoading] = true → แสดง shimmer effect บน child
/// [isLoading] = false → แสดง child ปกติ (ไม่มี animation)
///
/// หลักการทำงาน:
/// 1. สร้าง AnimationController ที่วน loop ตลอด
/// 2. ใช้ ShaderMask + LinearGradient สร้าง "แถบแสง" วิ่งซ้ายไปขวา
/// 3. gradient จะเลื่อน position ตาม animation value
class ShimmerWrapper extends StatefulWidget {
  /// Widget ลูก (ปกติจะเป็น ShimmerBox หรือ Skeleton* widgets)
  final Widget child;

  /// เปิด/ปิด shimmer effect
  /// true = แสดง shimmer, false = แสดง child ปกติ
  final bool isLoading;

  /// ความเร็ว animation (default: 1500ms ต่อรอบ)
  final Duration duration;

  /// สีพื้นฐาน shimmer (default: สีเทาอ่อน)
  final Color baseColor;

  /// สีแถบแสงที่วิ่ง (default: สีขาวอ่อน)
  final Color highlightColor;

  const ShimmerWrapper({
    super.key,
    required this.child,
    this.isLoading = true,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor = const Color(0xFFE8E8E8),
    this.highlightColor = const Color(0xFFF5F5F5),
  });

  @override
  State<ShimmerWrapper> createState() => _ShimmerWrapperState();
}

class _ShimmerWrapperState extends State<ShimmerWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // สร้าง animation ที่วน loop ไม่หยุด
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ถ้าไม่ loading → แสดง child ปกติ ไม่มี animation
    if (!widget.isLoading) return widget.child;

    // ใช้ AnimatedBuilder เพื่อ rebuild เฉพาะ ShaderMask
    // ไม่ rebuild child (performance optimization)
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child, // child ไม่เปลี่ยน → cache ไว้
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // คำนวณ position ของ gradient ตาม animation value
            // เลื่อนจาก -1.0 ไป 2.0 ของความกว้าง
            final double slidePosition =
                -1.0 + (_controller.value * 3.0);

            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                // ทำให้แถบแสงแคบลง (ประมาณ 30% ของความกว้าง)
                (slidePosition - 0.3).clamp(0.0, 1.0),
                slidePosition.clamp(0.0, 1.0),
                (slidePosition + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child!,
        );
      },
    );
  }
}

// =====================
// ShimmerBox
// =====================

/// ShimmerBox — กล่อง shimmer สี่เหลี่ยมหรือวงกลม
/// ใช้เป็น placeholder สำหรับ content ที่กำลังโหลด
///
/// ตัวอย่าง:
/// ```dart
/// ShimmerBox(width: 200, height: 16)            // text placeholder
/// ShimmerBox.circle(size: 40)                     // avatar placeholder
/// ShimmerBox.text()                               // short text line
/// ShimmerBox.text(width: double.infinity)         // full-width text line
/// ```
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final bool isCircle;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.isCircle = false,
  });

  /// Avatar/profile picture placeholder (วงกลม)
  const ShimmerBox.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        isCircle = true,
        borderRadius = null;

  /// Text line placeholder
  /// width default = 100, height default = 14 (เท่า body text)
  const ShimmerBox.text({
    super.key,
    this.width = 100,
    this.height = 14,
  })  : isCircle = false,
        borderRadius = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // สีพื้นฐาน shimmer — สีเทาอ่อน
        color: const Color(0xFFE8E8E8),
        // วงกลม หรือ สี่เหลี่ยมมุมมน
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius:
            isCircle ? null : (borderRadius ?? BorderRadius.circular(4)),
      ),
    );
  }
}

// =====================
// SkeletonListItem
// =====================

/// SkeletonListItem — skeleton loading สำหรับ list item
/// layout: [circle/avatar] [title line] [subtitle line(s)] [trailing box]
///
/// ใช้คู่กับ ShimmerWrapper:
/// ```dart
/// ShimmerWrapper(
///   isLoading: true,
///   child: Column(
///     children: List.generate(5, (_) => SkeletonListItem()),
///   ),
/// )
/// ```
class SkeletonListItem extends StatelessWidget {
  /// แสดง leading circle (avatar) หรือไม่ (default: true)
  final bool showLeading;

  /// แสดง trailing box หรือไม่ (default: false)
  final bool showTrailing;

  /// จำนวน text line ใน title area (default: 2)
  final int titleLines;

  /// ความสูงของแต่ละ item (default: null = auto)
  final double? height;

  const SkeletonListItem({
    super.key,
    this.showLeading = true,
    this.showTrailing = false,
    this.titleLines = 2,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: AppSpacing.listItemPadding,
      child: Row(
        children: [
          // Leading: avatar circle
          if (showLeading) ...[
            const ShimmerBox.circle(size: 40),
            AppSpacing.horizontalGapMd,
          ],

          // Content: title + subtitle lines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(titleLines, (index) {
                // บรรทัดแรกยาวกว่า (80%), บรรทัดถัดไปสั้นลง (50-60%)
                final widthFraction = index == 0 ? 0.8 : 0.5 + (index * 0.05);
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < titleLines - 1 ? 8.0 : 0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: widthFraction.clamp(0.3, 1.0),
                    alignment: Alignment.centerLeft,
                    child: ShimmerBox(
                      width: double.infinity,
                      // บรรทัดแรกสูงกว่า (title), ที่เหลือเล็กกว่า (subtitle)
                      height: index == 0 ? 16 : 12,
                    ),
                  ),
                );
              }),
            ),
          ),

          // Trailing: small box
          if (showTrailing) ...[
            AppSpacing.horizontalGapSm,
            const ShimmerBox(width: 60, height: 24),
          ],
        ],
      ),
    );
  }
}

// =====================
// SkeletonCard
// =====================

/// SkeletonCard — skeleton loading สำหรับ card layout
/// layout: [image area (optional)] [content lines]
///
/// ใช้คู่กับ ShimmerWrapper:
/// ```dart
/// ShimmerWrapper(
///   isLoading: true,
///   child: SkeletonCard(showImage: true, contentLines: 3),
/// )
/// ```
class SkeletonCard extends StatelessWidget {
  /// ความสูงทั้งการ์ด (default: null = auto)
  final double? height;

  /// แสดง image area ด้านบนหรือไม่ (default: false)
  final bool showImage;

  /// ความสูงของ image area (default: 120)
  final double imageHeight;

  /// จำนวน content text lines (default: 3)
  final int contentLines;

  const SkeletonCard({
    super.key,
    this.height,
    this.showImage = false,
    this.imageHeight = 120,
    this.contentLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.smallRadius,
        boxShadow: AppShadows.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area — สี่เหลี่ยมยาวเต็มความกว้าง
          if (showImage)
            ShimmerBox(
              width: double.infinity,
              height: imageHeight,
              borderRadius: BorderRadius.zero,
            ),

          // Content area — text lines
          Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(contentLines, (index) {
                // line แรกยาว (90%), line 2 กลาง (70%), ที่เหลือสั้น (50%)
                final widthFraction =
                    index == 0 ? 0.9 : (index == 1 ? 0.7 : 0.5);
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < contentLines - 1 ? 10.0 : 0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: widthFraction,
                    alignment: Alignment.centerLeft,
                    child: ShimmerBox(
                      width: double.infinity,
                      height: index == 0 ? 16 : 12,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
