import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// BottomSheetScaffold — Base layout สำหรับ bottom sheet ทุกตัวใน app
///
/// จัดการ boilerplate ให้อัตโนมัติ:
/// - Handle bar (แถบจับลาก)
/// - Rounded top corners
/// - Keyboard padding (เลื่อนขึ้นเมื่อ keyboard เปิด)
/// - SafeArea ด้านล่าง
/// - Scrollable content
/// - Sticky footer (ปุ่ม submit ที่อยู่ด้านล่างเสมอ)
///
/// วิธีใช้:
/// ```dart
/// // แบบง่าย — มี title + content
/// BottomSheetScaffold.show(
///   context,
///   builder: (ctx) => BottomSheetScaffold(
///     title: 'สร้างรายการใหม่',
///     child: Column(
///       children: [
///         AppTextField(label: 'ชื่อ', ...),
///         AppTextField(label: 'รายละเอียด', ...),
///       ],
///     ),
///     footer: PrimaryButton(
///       text: 'บันทึก',
///       onPressed: () => save(),
///     ),
///   ),
/// );
///
/// // แบบมีปุ่มปิด
/// BottomSheetScaffold(
///   title: 'ตั้งค่า',
///   showCloseButton: true,
///   child: SettingsContent(),
/// )
/// ```
class BottomSheetScaffold extends StatelessWidget {
  /// Title text ด้านบน (optional)
  final String? title;

  /// Custom title widget (ใช้แทน [title] เมื่อต้องการ layout พิเศษ)
  /// เช่น Row ที่มี icon + title + badge
  final Widget? titleWidget;

  /// แสดง handle bar (แถบลากสีเทา) ด้านบน (default: true)
  final bool showHandle;

  /// แสดงปุ่มปิด (X) ที่มุมขวาบน (default: false)
  final bool showCloseButton;

  /// Content หลักของ bottom sheet
  final Widget child;

  /// Footer widget ที่ fixed อยู่ด้านล่าง (เช่น ปุ่ม submit)
  /// จะอยู่เหนือ keyboard เสมอ
  final Widget? footer;

  /// Content สามารถ scroll ได้หรือไม่ (default: true)
  final bool scrollable;

  /// ความสูงสูงสุดเป็น fraction ของหน้าจอ (default: 0.9 = 90%)
  final double maxHeightFraction;

  /// Padding ของ content area (default: AppSpacing.paddingHorizontalMd)
  final EdgeInsets? contentPadding;

  /// สีพื้นหลัง (default: AppColors.surface = สีขาว)
  final Color? backgroundColor;

  const BottomSheetScaffold({
    super.key,
    required this.child,
    this.title,
    this.titleWidget,
    this.showHandle = true,
    this.showCloseButton = false,
    this.footer,
    this.scrollable = true,
    this.maxHeightFraction = 0.9,
    this.contentPadding,
    this.backgroundColor,
  });

  /// Helper method สำหรับแสดง bottom sheet
  /// จัดการ config ที่ถูกต้องให้อัตโนมัติ:
  /// - isScrollControlled = true (เพื่อให้ขยายได้เต็มจอ)
  /// - backgroundColor = transparent (ให้ BottomSheetScaffold จัดการเอง)
  /// - useSafeArea = true
  ///
  /// ตัวอย่าง:
  /// ```dart
  /// final result = await BottomSheetScaffold.show<bool>(
  ///   context,
  ///   builder: (ctx) => BottomSheetScaffold(
  ///     title: 'ยืนยัน',
  ///     child: Text('ต้องการดำเนินการ?'),
  ///     footer: PrimaryButton(
  ///       text: 'ตกลง',
  ///       onPressed: () => Navigator.pop(ctx, true),
  ///     ),
  ///   ),
  /// );
  /// ```
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      // ต้องเป็น true เพื่อให้ bottom sheet ขยายเกินครึ่งจอได้
      isScrollControlled: true,
      // ให้ BottomSheetScaffold จัดการ background + rounded corners เอง
      backgroundColor: Colors.transparent,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: true,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    // คำนวณ keyboard height เพื่อเลื่อน content ขึ้น
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight =
        MediaQuery.sizeOf(context).height * maxHeightFraction;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      // เลื่อน content ขึ้นเมื่อ keyboard เปิด
      padding: EdgeInsets.only(bottom: keyboardHeight),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        // มุมบนมน — ใช้ AppRadius.large (24px) ตาม design standard
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      child: SafeArea(
        top: false, // ไม่ต้อง safe area ด้านบน (อยู่กลางจอ)
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar + Header
            _buildHeader(context),

            // Content area (scrollable or fixed)
            Flexible(
              child: scrollable
                  ? SingleChildScrollView(
                      padding: contentPadding ??
                          AppSpacing.paddingHorizontalMd,
                      child: child,
                    )
                  : Padding(
                      padding: contentPadding ??
                          AppSpacing.paddingHorizontalMd,
                      child: child,
                    ),
            ),

            // Footer (sticky ด้านล่าง, เหนือ keyboard)
            if (footer != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  color: backgroundColor ?? AppColors.surface,
                  // เส้นบาง ๆ แบ่ง footer กับ content
                  border: Border(
                    top: BorderSide(
                      color: AppColors.inputBorder.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                ),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }

  /// สร้าง header area: handle bar + title + close button
  Widget _buildHeader(BuildContext context) {
    final hasTitle = title != null || titleWidget != null;

    return Column(
      children: [
        // Handle bar — แถบสีเทาด้านบนสำหรับลาก
        if (showHandle)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

        // Title row: [title] ... [close button]
        if (hasTitle || showCloseButton)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                // Title
                Expanded(
                  child: titleWidget ??
                      Text(
                        title ?? '',
                        style: AppTypography.heading3,
                      ),
                ),

                // Close button
                if (showCloseButton)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      color: AppColors.textSecondary,
                      size: AppIconSize.lg,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
