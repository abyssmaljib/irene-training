import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/resident_detail.dart';

/// Collapsible Header สำหรับ Resident Detail
/// Expanded: แสดง Avatar + ข้อมูลแบบเดิม (Row layout)
/// Collapsed: แสดง Avatar เล็ก + ชื่อ ใน AppBar
class CollapsibleResidentHeader extends StatelessWidget {
  final ResidentDetail resident;
  final double expandedHeight;
  final double collapsedHeight;
  final VoidCallback? onBackPressed;
  final VoidCallback? onCallPressed;
  final VoidCallback? onMorePressed;
  final VoidCallback? onShowMoreDiseases;

  const CollapsibleResidentHeader({
    super.key,
    required this.resident,
    this.expandedHeight = 180,
    this.collapsedHeight = kToolbarHeight,
    this.onBackPressed,
    this.onCallPressed,
    this.onMorePressed,
    this.onShowMoreDiseases,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: expandedHeight,
      collapsedHeight: collapsedHeight,
      pinned: true,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      leading: IconButton(
        icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01),
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedMoreVertical),
          onPressed: onMorePressed,
        ),
        SizedBox(width: AppSpacing.md),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = constraints.biggest.height;
          final shrinkRatio = 1 - ((top - collapsedHeight) / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);

          return FlexibleSpaceBar(
            centerTitle: true,
            titlePadding: EdgeInsets.zero,
            title: _buildCollapsedTitle(shrinkRatio),
            background: _buildExpandedContent(shrinkRatio),
          );
        },
      ),
    );
  }

  /// Title เมื่อ collapsed (Avatar เล็ก + ชื่อ)
  Widget _buildCollapsedTitle(double shrinkRatio) {
    final opacity = ((shrinkRatio - 0.5) * 2).clamp(0.0, 1.0);
    if (opacity <= 0) return SizedBox.shrink();

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.inputBorder, width: 1.5),
              ),
              // RepaintBoundary แยก layer ไม่ให้ repaint ทุก scroll frame
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: resident.imageUrl != null && resident.imageUrl!.isNotEmpty
                      // จำกัดขนาดใน memory เพื่อป้องกัน crash บน iOS/Android สเปคต่ำ
                      ? Image.network(resident.imageUrl!, fit: BoxFit.cover, cacheWidth: 100, errorBuilder: (context, error, stackTrace) => _buildMiniAvatar())
                      : _buildMiniAvatar(),
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'คุณ${resident.name}',
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAvatar() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: HugeIcon(icon: HugeIcons.strokeRoundedUser, size: AppIconSize.sm, color: AppColors.secondaryText),
      ),
    );
  }

  /// Content เมื่อ expanded (Layout แบบเดิม)
  Widget _buildExpandedContent(double shrinkRatio) {
    final opacity = (1 - (shrinkRatio * 1.4)).clamp(0.0, 1.0);

    return SafeArea(
      child: Opacity(
        opacity: opacity,
        child: Padding(
          padding: EdgeInsets.only(
            top: kToolbarHeight + AppSpacing.sm,
            left: AppSpacing.md,
            right: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(),
              SizedBox(width: AppSpacing.md),
              Expanded(child: _buildInfo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder, width: 2),
      ),
      // RepaintBoundary แยก layer ไม่ให้ repaint ทุก scroll frame
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: resident.imageUrl != null && resident.imageUrl!.isNotEmpty
              ? Image.network(
                  resident.imageUrl!,
                  fit: BoxFit.cover,
                  // จำกัดขนาดใน memory เพื่อป้องกัน crash บน iOS/Android สเปคต่ำ
                  cacheWidth: 400,
                  errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                )
              : _buildDefaultAvatar(),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: HugeIcon(icon: HugeIcons.strokeRoundedUser, size: AppIconSize.xxl, color: AppColors.secondaryText),
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name
        Text(
          'คุณ${resident.name}',
          style: AppTypography.title.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Age & Gender (ถ้ามีข้อมูล)
        if (_buildAgeGenderText().isNotEmpty) ...[
          SizedBox(height: 2),
          Text(
            _buildAgeGenderText(),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
        SizedBox(height: AppSpacing.xs),
        // Status Badges (Zone, Status) + Disease link
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            ..._buildBadges(),
            // ปุ่มดูโรคประจำตัว (ถ้ามี)
            if (resident.underlyingDiseases.isNotEmpty)
              GestureDetector(
                onTap: onShowMoreDiseases,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tagPendingBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.tagPendingText.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedMedicine01,
                        size: AppIconSize.xs,
                        color: AppColors.tagPendingText,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'โรคประจำตัว ${resident.underlyingDiseases.length}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.tagPendingText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _buildAgeGenderText() {
    final parts = <String>[];
    if (resident.age != null) parts.add('${resident.age} ปี');
    if (resident.gender != null && resident.gender!.isNotEmpty) {
      // gender อาจเป็น 'M'/'F' หรือ 'ชาย'/'หญิง' ขึ้นอยู่กับ data source
      final isMale = resident.gender == 'M' || resident.gender == 'ชาย';
      parts.add(isMale ? 'ชาย' : 'หญิง');
    }
    return parts.join(' • ');
  }

  List<Widget> _buildBadges() {
    final badges = <Widget>[];

    // Zone badge
    badges.add(_buildBadge(
      label: resident.zoneName,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      textColor: AppColors.primary,
      icon: HugeIcons.strokeRoundedLocation01,
    ));

    // Status badge
    if (resident.status != null) {
      final isStay = resident.status?.toLowerCase() == 'stay';
      badges.add(_buildBadge(
        label: isStay ? 'อยู่' : 'ออก',
        backgroundColor: isStay ? AppColors.tagPassedBg : AppColors.tagFailedBg,
        textColor: isStay ? AppColors.tagPassedText : AppColors.tagFailedText,
      ));
    }

    return badges;
  }

  Widget _buildBadge({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    dynamic icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            HugeIcon(icon: icon, size: AppIconSize.xs, color: textColor),
            SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

}
