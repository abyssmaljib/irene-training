import 'package:flutter/material.dart' hide Badge;
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/badge.dart';
import '../services/badge_service.dart';

/// Dialog แสดงข้อมูล badge ทั้งหมด
class BadgeInfoDialog extends StatefulWidget {
  const BadgeInfoDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BadgeInfoDialog(),
    );
  }

  @override
  State<BadgeInfoDialog> createState() => _BadgeInfoDialogState();
}

class _BadgeInfoDialogState extends State<BadgeInfoDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  BadgeStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final service = BadgeService();
    final stats = await service.getBadgeStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.alternate,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedAward01,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Badge ทั้งหมด',
                            style: AppTypography.title.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_stats != null)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'ได้แล้ว ${_stats!.earnedCount}/${_stats!.totalBadges}',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '• ${_stats!.totalUsers} users',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryBackground,
                  borderRadius: AppRadius.smallRadius,
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.smallRadius,
                  ),
                  labelColor: AppColors.surface,
                  unselectedLabelColor: AppColors.secondaryText,
                  labelStyle: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  labelPadding: EdgeInsets.zero,
                  dividerHeight: 0,
                  tabs: const [
                    Tab(text: 'ตามประเภท'),
                    Tab(text: 'ตามความหายาก'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildByCategoryTab(scrollController),
                          _buildByRarityTab(scrollController),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildByCategoryTab(ScrollController scrollController) {
    if (_stats == null) return const SizedBox.shrink();

    final categories = _stats!.byCategory.keys.toList();

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final badges = _stats!.byCategory[category]!;
        return _buildCategorySection(category, badges);
      },
    );
  }

  Widget _buildByRarityTab(ScrollController scrollController) {
    if (_stats == null) return const SizedBox.shrink();

    // Order: legendary, epic, rare, common
    final rarityOrder = ['legendary', 'epic', 'rare', 'common'];
    final rarities = rarityOrder
        .where((r) => _stats!.byRarity.containsKey(r))
        .toList();

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rarities.length,
      itemBuilder: (context, index) {
        final rarity = rarities[index];
        final badges = _stats!.byRarity[rarity]!;
        return _buildRaritySection(rarity, badges);
      },
    );
  }

  Widget _buildCategorySection(String category, List<BadgeInfo> badges) {
    final firstBadge = badges.first.badge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(
                firstBadge.categoryIcon,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                firstBadge.categoryDisplayName,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryBackground,
                  borderRadius: AppRadius.smallRadius,
                ),
                child: Text(
                  '${badges.length}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Badges list
        ...badges.map((info) => _buildBadgeInfoItem(info)),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRaritySection(String rarity, List<BadgeInfo> badges) {
    final color = _getRarityColor(rarity);
    final emoji = _getRarityEmoji(rarity);
    final label = _getRarityLabel(rarity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rarity header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smallRadius,
                ),
                child: Text(
                  '${badges.length}',
                  style: AppTypography.caption.copyWith(
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Badges list
        ...badges.map((info) => _buildBadgeInfoItem(info)),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBadgeInfoItem(BadgeInfo info) {
    final badge = info.badge;
    final rarityColor = _getRarityColor(badge.rarity);
    final isEarned = info.isEarnedByCurrentUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEarned ? AppColors.tagPassedBg : AppColors.surface,
        borderRadius: AppRadius.smallRadius,
        border: Border.all(
          color: isEarned ? AppColors.success : AppColors.alternate,
          width: isEarned ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Badge icon with earned indicator
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isEarned
                      ? rarityColor.withValues(alpha: 0.2)
                      : rarityColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: rarityColor,
                    width: isEarned ? 3 : 2,
                  ),
                ),
                child: Center(
                  child: badge.imageUrl != null
                      ? ClipOval(
                          child: Image.network(
                            badge.imageUrl!,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            // จำกัดขนาดใน memory เพื่อป้องกัน crash บน iOS/Android สเปคต่ำ
                            cacheWidth: 100,
                            errorBuilder: (context, error, stackTrace) => Text(
                              badge.icon ?? badge.rarityEmoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        )
                      : Text(
                          badge.icon ?? badge.rarityEmoji,
                          style: TextStyle(
                            fontSize: 20,
                            color: isEarned ? null : Colors.grey,
                          ),
                        ),
                ),
              ),
              // Earned checkmark
              if (isEarned)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 12),

          // Badge info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Earned tag
                    if (isEarned) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ได้แล้ว',
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        badge.name,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isEarned ? AppColors.primaryText : AppColors.secondaryText,
                        ),
                      ),
                    ),
                    // Rarity tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: rarityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getRarityLabel(badge.rarity),
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          color: rarityColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  badge.requirementDescription,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                // Stats row
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedUserGroup,
                      size: 14,
                      color: AppColors.secondaryText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${info.earnedCount} คนได้รับ',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${info.earnedPercent.toStringAsFixed(1)}%)',
                      style: AppTypography.caption.copyWith(
                        color: info.earnedPercent < 10
                            ? AppColors.error
                            : info.earnedPercent < 30
                                ? AppColors.warning
                                : AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedStar,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '+${badge.points}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'legendary':
        return const Color(0xFFFFD700);
      case 'epic':
        return const Color(0xFF9B59B6);
      case 'rare':
        return const Color(0xFF3498DB);
      default:
        return AppColors.primary;
    }
  }

  String _getRarityEmoji(String rarity) {
    switch (rarity) {
      case 'legendary':
        return '🏆';
      case 'epic':
        return '💎';
      case 'rare':
        return '⭐';
      default:
        return '🎖️';
    }
  }

  String _getRarityLabel(String rarity) {
    switch (rarity) {
      case 'legendary':
        return 'Legendary';
      case 'epic':
        return 'Epic';
      case 'rare':
        return 'Rare';
      default:
        return 'Common';
    }
  }
}
