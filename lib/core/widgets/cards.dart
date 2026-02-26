import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// ContentCard - การ์ดพื้นฐานที่ใช้ซ้ำได้ทั้ง app
/// รองรับ: สีพื้นหลัง, border, shadow, borderRadius, onTap
///
/// เมื่อ [onTap] == null จะไม่สร้าง Material+InkWell wrapper
/// เพื่อลด widget tree ที่ไม่จำเป็น (performance optimization)
///
/// ตัวอย่างการใช้งาน:
/// ```dart
/// // การ์ดพื้นฐาน
/// ContentCard(child: Text('Hello'))
///
/// // การ์ดที่กดได้ — มี ripple effect
/// ContentCard(
///   onTap: () => print('tapped'),
///   child: Text('Tap me'),
/// )
///
/// // การ์ดที่กำหนดสีเอง + ไม่มี shadow
/// ContentCard(
///   backgroundColor: AppColors.accent1,
///   showShadow: false,
///   border: Border.all(color: AppColors.primary),
///   child: Text('Custom card'),
/// )
/// ```
class ContentCard extends StatelessWidget {
  /// Content ภายในการ์ด
  final Widget child;

  /// Callback เมื่อกดการ์ด (null = ไม่มี ripple effect)
  final VoidCallback? onTap;

  /// Padding ภายในการ์ด (default: AppSpacing.cardPadding = 16 ทุกด้าน)
  final EdgeInsets? padding;

  /// Margin ภายนอกการ์ด (default: horizontal 16, vertical 8)
  final EdgeInsets? margin;

  /// สีพื้นหลังการ์ด (default: AppColors.secondaryBackground = สีขาว)
  final Color? backgroundColor;

  /// Border radius (default: AppRadius.smallRadius = 8px)
  final BorderRadius? borderRadius;

  /// เส้นขอบการ์ด (default: ไม่มี)
  final Border? border;

  /// เงาของการ์ด (default: AppShadows.cardShadow)
  /// ใช้คู่กับ [showShadow] — ถ้า showShadow = false จะไม่แสดงเงา
  final List<BoxShadow>? boxShadow;

  /// แสดงเงาหรือไม่ (default: true)
  /// shortcut สำหรับปิดเงาโดยไม่ต้องส่ง boxShadow: []
  final bool showShadow;

  /// Clip behavior สำหรับ content ที่ล้นขอบ (default: none)
  final Clip clipBehavior;

  const ContentCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.showShadow = true,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    // กำหนด default values
    final effectiveBorderRadius = borderRadius ?? AppRadius.smallRadius;
    final effectiveBg = backgroundColor ?? AppColors.secondaryBackground;
    final effectiveShadow = showShadow
        ? (boxShadow ?? AppShadows.cardShadow)
        : <BoxShadow>[];

    // สร้าง content พร้อม padding
    Widget content = Padding(
      padding: padding ?? AppSpacing.cardPadding,
      child: child,
    );

    // ถ้ามี onTap → wrap ด้วย Material + InkWell สำหรับ ripple effect
    // + Semantics เพื่อ accessibility (screen reader รู้ว่ากดได้)
    // ถ้าไม่มี → ไม่ต้อง wrap เพื่อลด widget tree
    if (onTap != null) {
      content = Semantics(
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: effectiveBorderRadius,
            child: content,
          ),
        ),
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveBorderRadius,
        border: border,
        boxShadow: effectiveShadow,
      ),
      child: content,
    );
  }
}

/// ListItemCard - การ์ดสำหรับแสดงรายการ (list item)
/// มี leading icon, title, subtitle, trailing widget, และ status tag
///
/// [showArrow] ควบคุมว่าจะแสดงลูกศรขวาเมื่อไม่มี trailing หรือไม่
/// [bodyWidget] ใช้สำหรับ custom content layout ใต้ title/subtitle
///
/// ตัวอย่างการใช้งาน:
/// ```dart
/// // แบบพื้นฐาน — มีลูกศรอัตโนมัติ
/// ListItemCard(
///   title: 'รายการที่ 1',
///   subtitle: 'รายละเอียด',
///   onTap: () => navigateToDetail(),
/// )
///
/// // แบบไม่มีลูกศร + มี body widget
/// ListItemCard(
///   title: 'งานวันนี้',
///   showArrow: false,
///   bodyWidget: Row(children: [tag1, tag2]),
/// )
///
/// // แบบมี leading + custom trailing
/// ListItemCard(
///   leading: CircleAvatar(child: Icon(Icons.person)),
///   title: 'ผู้พักอาศัย',
///   trailing: StatusBadge.passed(),
/// )
/// ```
class ListItemCard extends StatelessWidget {
  /// ข้อความหัวข้อหลัก
  final String title;

  /// ข้อความรอง (แสดงใต้ title)
  final String? subtitle;

  /// Widget ด้านซ้าย (เช่น avatar, icon)
  final Widget? leading;

  /// Widget ด้านขวา (เช่น badge, icon button)
  /// ถ้าไม่ระบุ และ [showArrow] = true จะแสดงลูกศรขวา
  final Widget? trailing;

  /// Callback เมื่อกดการ์ด
  final VoidCallback? onTap;

  /// Widget แสดง status (เช่น StatusBadge, ProgressTag)
  final Widget? statusTag;

  /// แสดงลูกศรขวาเมื่อไม่มี [trailing] (default: true)
  /// ตั้ง false เมื่อไม่ต้องการลูกศร
  final bool showArrow;

  /// จำนวนบรรทัดสูงสุดของ title (null = ไม่จำกัด)
  final int? titleMaxLines;

  /// Style สำหรับ title (default: AppTypography.title + fontSize 16)
  final TextStyle? titleStyle;

  /// การจัด widget ในแนวตั้ง (default: center)
  final CrossAxisAlignment crossAxisAlignment;

  /// Custom body widget — แสดงใต้ title/subtitle/statusTag
  /// ใช้สำหรับ layout ที่ซับซ้อนกว่า text ธรรมดา
  final Widget? bodyWidget;

  const ListItemCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.statusTag,
    this.showArrow = true,
    this.titleMaxLines,
    this.titleStyle,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.bodyWidget,
  });

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      onTap: onTap,
      padding: AppSpacing.listItemPadding,
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          // Leading widget (avatar, icon, etc.)
          if (leading != null) ...[
            leading!,
            AppSpacing.horizontalGapMd,
          ],

          // Main content: title + subtitle + statusTag + bodyWidget
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: titleStyle ??
                      AppTypography.title.copyWith(fontSize: 16),
                  maxLines: titleMaxLines,
                  overflow:
                      titleMaxLines != null ? TextOverflow.ellipsis : null,
                ),
                if (subtitle != null) ...[
                  AppSpacing.verticalGapXs,
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall,
                  ),
                ],
                if (statusTag != null) ...[
                  AppSpacing.verticalGapSm,
                  statusTag!,
                ],
                // Custom body สำหรับ layout ที่ซับซ้อน
                if (bodyWidget != null) ...[
                  AppSpacing.verticalGapSm,
                  bodyWidget!,
                ],
              ],
            ),
          ),

          // Trailing widget หรือ ลูกศรขวา
          if (trailing != null) ...[
            AppSpacing.horizontalGapSm,
            trailing!,
          ] else if (showArrow) ...[
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

/// StatusCard - การ์ดที่มี status badge สีต่างๆ
/// ใช้แสดงรายการที่มีสถานะ เช่น งานที่ผ่าน/ไม่ผ่าน
class StatusCard extends StatelessWidget {
  final String title;
  final String status;
  final Color statusColor;
  final String? description;
  final VoidCallback? onTap;

  const StatusCard({
    super.key,
    required this.title,
    required this.status,
    required this.statusColor,
    this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.title.copyWith(fontSize: 16),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: AppRadius.smallRadius,
                ),
                child: Text(
                  status,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.surface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (description != null) ...[
            AppSpacing.verticalGapSm,
            Text(
              description!,
              style: AppTypography.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// LoginCard - การ์ดสำหรับ form login
/// ใช้เป็น container ของ form ใน login screen
class LoginCard extends StatelessWidget {
  final Widget child;

  const LoginCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.smallRadius,
        boxShadow: AppShadows.cardShadow,
      ),
      child: child,
    );
  }
}
