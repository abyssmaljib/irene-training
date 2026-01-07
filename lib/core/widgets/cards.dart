import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// Content Card - Standard card container
class ContentCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const ContentCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.smallRadius,
        boxShadow: AppShadows.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smallRadius,
          child: Padding(
            padding: padding ?? AppSpacing.cardPadding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// List Item Card - For list items with title and subtitle
class ListItemCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? statusTag;

  const ListItemCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.statusTag,
  });

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      onTap: onTap,
      padding: AppSpacing.listItemPadding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            AppSpacing.horizontalGapMd,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.title.copyWith(fontSize: 16),
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
              ],
            ),
          ),
          if (trailing != null) ...[
            AppSpacing.horizontalGapSm,
            trailing!,
          ] else ...[
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

/// Status Card - Card with colored status indicator
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

/// Login Card - Card container for login form
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