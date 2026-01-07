import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/resident_detail.dart';

/// Header widget สำหรับแสดงข้อมูลหลักของ Resident
/// ใช้ใน SliverAppBar expanded area
class ResidentHeader extends StatelessWidget {
  final ResidentDetail resident;

  const ResidentHeader({
    super.key,
    required this.resident,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          _buildAvatar(),
          SizedBox(width: AppSpacing.md),
          // Info
          Expanded(child: _buildInfo()),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.inputBorder,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: resident.imageUrl != null && resident.imageUrl!.isNotEmpty
            ? Image.network(
                resident.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedUser,
          size: AppIconSize.xl,
          color: AppColors.secondaryText,
        ),
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
        SizedBox(height: 2),
        // Age & Gender
        Text(
          _buildAgeGenderText(),
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        // Badges row - scrollable horizontally
        SizedBox(
          height: 24,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _buildBadges()
                .map((badge) => Padding(
                      padding: EdgeInsets.only(right: AppSpacing.xs),
                      child: badge,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  String _buildAgeGenderText() {
    final parts = <String>[];
    if (resident.age != null) {
      parts.add('${resident.age} ปี');
    }
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

    // Bed badge
    if (resident.bed != null && resident.bed!.isNotEmpty) {
      badges.add(_buildBadge(
        label: 'เตียง ${resident.bed}',
        backgroundColor: AppColors.background,
        textColor: AppColors.textPrimary,
        icon: HugeIcons.strokeRoundedLamp01,
      ));
    }

    // Status badge
    if (resident.status != null) {
      final isStay = resident.status?.toLowerCase() == 'stay';
      badges.add(_buildBadge(
        label: isStay ? 'อยู่' : 'ออก',
        backgroundColor: isStay ? AppColors.tagPassedBg : AppColors.tagFailedBg,
        textColor: isStay ? AppColors.tagPassedText : AppColors.tagFailedText,
      ));
    }

    // Special status badges
    if (resident.isFallRisk) {
      badges.add(_buildBadge(
        label: 'เสี่ยงล้ม',
        backgroundColor: AppColors.tagFailedBg,
        textColor: AppColors.tagFailedText,
        icon: HugeIcons.strokeRoundedAlert02,
      ));
    }

    if (resident.isNPO) {
      badges.add(_buildBadge(
        label: 'NPO',
        backgroundColor: AppColors.tagPendingBg,
        textColor: AppColors.tagPendingText,
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
      padding: EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            HugeIcon(icon: icon, size: AppIconSize.xs, color: textColor),
            SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
