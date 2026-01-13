import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// ปุ่มสำหรับเล่น Tutorial ซ้ำ
/// ใช้ได้ทั้งใน AppBar และ Settings List
class ReplayTutorialButton extends StatelessWidget {
  /// Callback เมื่อกดปุ่ม
  final VoidCallback onPressed;

  /// รูปแบบการแสดงผล
  final ReplayTutorialButtonStyle style;

  const ReplayTutorialButton({
    super.key,
    required this.onPressed,
    this.style = ReplayTutorialButtonStyle.icon,
  });

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      ReplayTutorialButtonStyle.icon => _buildIconButton(),
      ReplayTutorialButtonStyle.listTile => _buildListTile(),
    };
  }

  /// สร้างปุ่ม icon สำหรับ AppBar
  Widget _buildIconButton() {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'ดู Tutorial',
      icon: HugeIcon(
        icon: HugeIcons.strokeRoundedHelpCircle,
        color: AppColors.secondaryText,
        size: AppIconSize.lg,
      ),
    );
  }

  /// สร้าง ListTile สำหรับ Settings
  Widget _buildListTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedHelpCircle,
                    color: AppColors.primary,
                    size: AppIconSize.lg,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.md),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ดู Tutorial อีกครั้ง',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'เรียนรู้วิธีใช้งานแอปพลิเคชัน',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: AppColors.secondaryText,
                size: AppIconSize.md,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// รูปแบบการแสดงผลของ ReplayTutorialButton
enum ReplayTutorialButtonStyle {
  /// แสดงเป็น icon button (สำหรับ AppBar)
  icon,

  /// แสดงเป็น list tile (สำหรับ Settings)
  listTile,
}
