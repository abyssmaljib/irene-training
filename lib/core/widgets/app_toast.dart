// AppToast — Modern overlay toast notification
// ลอยจากด้านบน, auto-dismiss, ไม่ block UI
//
// Features:
// - Slide-in animation จากด้านบน
// - Auto-dismiss หลัง 3 วินาที (configurable)
// - กดปิดได้ (swipe up หรือ tap)
// - 4 variants: success, error, info, warning
// - รองรับ subtitle (optional)
//
// ใช้งาน:
// ```dart
// AppToast.success(context, 'บันทึกเรียบร้อย');
// AppToast.success(context, 'ส่งคะแนนแล้ว', subtitle: '+100 คะแนนให้ น้องแป้ง');
// AppToast.error(context, 'เกิดข้อผิดพลาด');
// ```

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppToast {
  AppToast._();

  /// แสดง success toast (สีเขียว)
  static void success(
    BuildContext context,
    String message, {
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      subtitle: subtitle,
      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
      backgroundColor: AppColors.tagPassedBg,
      textColor: AppColors.tagPassedText,
      iconColor: AppColors.tagPassedText,
      borderColor: AppColors.tagPassedText,
      duration: duration,
    );
  }

  /// แสดง error toast (สีแดง)
  static void error(
    BuildContext context,
    String message, {
    String? subtitle,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      message: message,
      subtitle: subtitle,
      icon: HugeIcons.strokeRoundedAlert02,
      backgroundColor: AppColors.tagFailedBg,
      textColor: AppColors.tagFailedText,
      iconColor: AppColors.tagFailedText,
      borderColor: AppColors.tagFailedText,
      duration: duration,
    );
  }

  /// แสดง info toast (สี teal)
  static void info(
    BuildContext context,
    String message, {
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      subtitle: subtitle,
      icon: HugeIcons.strokeRoundedInformationCircle,
      backgroundColor: AppColors.accent1,
      textColor: AppColors.primary,
      iconColor: AppColors.primary,
      borderColor: AppColors.primary,
      duration: duration,
    );
  }

  /// แสดง warning toast (สีส้ม)
  static void warning(
    BuildContext context,
    String message, {
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      subtitle: subtitle,
      icon: HugeIcons.strokeRoundedAlertCircle,
      backgroundColor: AppColors.tagPendingBg,
      textColor: AppColors.tagPendingText,
      iconColor: AppColors.tagPendingText,
      borderColor: AppColors.tagPendingText,
      duration: duration,
    );
  }

  // OverlayEntry ปัจจุบัน — เก็บไว้เพื่อลบ toast ก่อนหน้า (ไม่ให้ซ้อน)
  static OverlayEntry? _currentEntry;

  /// Internal method สำหรับแสดง toast ผ่าน Overlay
  static void _show(
    BuildContext context, {
    required String message,
    String? subtitle,
    required dynamic icon,
    required Color backgroundColor,
    required Color textColor,
    required Color iconColor,
    required Color borderColor,
    required Duration duration,
  }) {
    // ลบ toast เดิมทันที (ไม่ให้ซ้อนกัน)
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        subtitle: subtitle,
        icon: icon,
        backgroundColor: backgroundColor,
        textColor: textColor,
        iconColor: iconColor,
        borderColor: borderColor,
        duration: duration,
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

/// Widget ภายในที่จัดการ animation + auto-dismiss
class _ToastWidget extends StatefulWidget {
  final String message;
  final String? subtitle;
  final dynamic icon;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final Color borderColor;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
    required this.borderColor,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    // Animation controller สำหรับ slide-in/out
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Slide จากด้านบน (-1.0) ลงมาตำแหน่งปกติ (0.0)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // เริ่ม animation slide-in
    _controller.forward();

    // Auto-dismiss หลังหมดเวลา
    Future.delayed(widget.duration, _dismiss);
  }

  /// ปิด toast อย่างปลอดภัย (มี animation slide-out)
  void _dismiss() {
    if (_dismissed || !mounted) return;
    _dismissed = true;

    // Slide-out animation แล้วค่อย remove
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // คำนวณ safe area (status bar)
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + AppSpacing.sm,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          // Swipe up เพื่อปิด
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              // Swipe ขึ้น → ปิด
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -100) {
                _dismiss();
              }
            },
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.borderColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icon
                    if (widget.icon is IconData)
                      Icon(widget.icon, size: AppIconSize.lg,
                          color: widget.iconColor)
                    else
                      HugeIcon(
                        icon: widget.icon,
                        size: AppIconSize.lg,
                        color: widget.iconColor,
                      ),
                    AppSpacing.horizontalGapSm,

                    // ข้อความ
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.message,
                            style: AppTypography.bodySmall.copyWith(
                              color: widget.textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // Subtitle (ถ้ามี)
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: AppTypography.caption.copyWith(
                                color:
                                    widget.textColor.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ปุ่มปิด (X)
                    GestureDetector(
                      onTap: _dismiss,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 16,
                          color: widget.textColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
