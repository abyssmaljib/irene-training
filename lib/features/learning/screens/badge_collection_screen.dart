// Badge Collection Screen - หน้าแสดง badges ทั้งหมดที่ user สะสม
//
// แสดง badges ในรูปแบบ grid 3 columns พร้อม tabs แบ่งตามประเภทและความหายาก
// - Earned badges: แสดงสีเต็ม + checkmark
// - Unearned badges: แสดง greyscale + lock

import 'package:flutter/material.dart' hide Badge;
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../models/badge.dart';
import '../services/badge_service.dart';

/// หน้าแสดง badge collection ทั้งหมดของ user
///
/// ใช้ TabBar แบ่งเป็น 2 tabs:
/// - ตามประเภท: จัดกลุ่มตาม category (achievement, progress, streak, etc.)
/// - ตามความหายาก: จัดกลุ่มตาม rarity (legendary, epic, rare, common)
class BadgeCollectionScreen extends StatefulWidget {
  const BadgeCollectionScreen({super.key});

  @override
  State<BadgeCollectionScreen> createState() => _BadgeCollectionScreenState();
}

class _BadgeCollectionScreenState extends State<BadgeCollectionScreen>
    with SingleTickerProviderStateMixin {
  // TabController สำหรับสลับระหว่าง "ตามประเภท" และ "ตามความหายาก"
  late TabController _tabController;

  // ข้อมูล badge statistics จาก BadgeService
  BadgeStats? _stats;

  // สถานะการโหลดข้อมูล
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // สร้าง TabController สำหรับ 2 tabs
    _tabController = TabController(length: 2, vsync: this);
    // โหลดข้อมูล badges
    _loadStats();
  }

  @override
  void dispose() {
    // ต้อง dispose TabController เพื่อป้องกัน memory leak
    _tabController.dispose();
    super.dispose();
  }

  /// โหลดข้อมูล badge statistics จาก BadgeService
  ///
  /// ใช้ getBadgeStats() ซึ่ง return BadgeStats ที่มี:
  /// - badges: List ของ BadgeInfo ทั้งหมด
  /// - byCategory: Map จัดกลุ่มตาม category
  /// - byRarity: Map จัดกลุ่มตาม rarity
  /// - earnedCount: จำนวน badges ที่ได้รับแล้ว
  /// - totalBadges: จำนวน badges ทั้งหมด
  Future<void> _loadStats() async {
    final service = BadgeService();
    final stats = await service.getBadgeStats();
    // ตรวจสอบว่า widget ยังอยู่ใน tree ก่อน setState
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      // ใช้ IreneSecondaryAppBar ซึ่งเป็น AppBar มาตรฐานสำหรับหน้ารอง
      // มี back button อัตโนมัติ
      appBar: IreneSecondaryAppBar(
        title: 'Badges ที่สะสม',
      ),
      body: _isLoading
          // แสดง loading indicator ขณะโหลดข้อมูล
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header section แสดง progress และ TabBar
                _buildHeader(),
                // เนื้อหาหลัก - TabBarView
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: แสดง badges จัดกลุ่มตาม category
                      _buildByCategoryTab(),
                      // Tab 2: แสดง badges จัดกลุ่มตาม rarity
                      _buildByRarityTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// สร้าง Header section ประกอบด้วย:
  /// - Progress indicator แสดงจำนวน badges ที่ได้/ทั้งหมด
  /// - Progress bar แบบ linear
  /// - TabBar สำหรับสลับ view
  Widget _buildHeader() {
    return Container(
      color: AppColors.secondaryBackground,
      child: Column(
        children: [
          // Progress section
          Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              children: [
                // แถวแสดงข้อความและจำนวน
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Badges ที่สะสมได้',
                      style: AppTypography.body.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Badge แสดงจำนวน earned/total
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: AppRadius.fullRadius,
                      ),
                      child: Text(
                        '${_stats?.earnedCount ?? 0}/${_stats?.totalBadges ?? 0}',
                        style: AppTypography.body.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Linear progress bar แสดง % ที่ได้รับ
                ClipRRect(
                  borderRadius: AppRadius.smallRadius,
                  child: LinearProgressIndicator(
                    // คำนวณ progress value (0.0 - 1.0)
                    value: _stats != null && _stats!.totalBadges > 0
                        ? _stats!.earnedCount / _stats!.totalBadges
                        : 0,
                    backgroundColor: AppColors.alternate,
                    valueColor: const AlwaysStoppedAnimation(AppColors.success),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          // TabBar section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryBackground,
              borderRadius: AppRadius.smallRadius,
            ),
            child: TabBar(
              controller: _tabController,
              // ขนาด indicator เท่ากับ tab
              indicatorSize: TabBarIndicatorSize.tab,
              // ใช้ BoxDecoration แทน default indicator
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.smallRadius,
              ),
              // สีตัวอักษร tab ที่เลือก/ไม่เลือก
              labelColor: AppColors.surface,
              unselectedLabelColor: AppColors.secondaryText,
              labelStyle: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
              // ไม่ต้องมี padding และ divider
              labelPadding: EdgeInsets.zero,
              dividerHeight: 0,
              tabs: const [
                Tab(text: 'ตามประเภท'),
                Tab(text: 'ตามความหายาก'),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// สร้าง Tab แสดง badges จัดกลุ่มตาม category
  ///
  /// แต่ละ category จะมี:
  /// - Section header แสดง emoji + ชื่อ + จำนวน earned/total
  /// - Grid 3 columns แสดง badge cards
  Widget _buildByCategoryTab() {
    if (_stats == null) return const SizedBox.shrink();

    final categories = _stats!.byCategory.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final badges = _stats!.byCategory[category]!;
        return _buildSection(
          emoji: badges.first.badge.categoryIcon,
          title: badges.first.badge.categoryDisplayName,
          badges: badges,
        );
      },
    );
  }

  /// สร้าง Tab แสดง badges จัดกลุ่มตาม rarity
  ///
  /// เรียงลำดับจาก legendary -> epic -> rare -> common
  Widget _buildByRarityTab() {
    if (_stats == null) return const SizedBox.shrink();

    // กำหนดลำดับ rarity ที่ต้องการแสดง
    const rarityOrder = ['legendary', 'epic', 'rare', 'common'];
    // Filter เฉพาะ rarity ที่มีใน data
    final rarities = rarityOrder
        .where((r) => _stats!.byRarity.containsKey(r))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rarities.length,
      itemBuilder: (context, index) {
        final rarity = rarities[index];
        final badges = _stats!.byRarity[rarity]!;
        return _buildSection(
          emoji: _getRarityEmoji(rarity),
          title: _getRarityLabel(rarity),
          badges: badges,
          titleColor: _getRarityColor(rarity),
        );
      },
    );
  }

  /// สร้าง section สำหรับแต่ละ category/rarity
  ///
  /// ประกอบด้วย:
  /// - Header row: emoji + title + earned count badge
  /// - Grid 3 columns แสดง badge cards
  Widget _buildSection({
    required String emoji,
    required String title,
    required List<BadgeInfo> badges,
    Color? titleColor,
  }) {
    // นับจำนวนที่ earned ใน section นี้
    final earnedInSection = badges.where((b) => b.isEarnedByCurrentUser).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(width: 8),
              // Badge แสดง earned/total ใน section นี้
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: earnedInSection > 0
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.primaryBackground,
                  borderRadius: AppRadius.smallRadius,
                ),
                child: Text(
                  '$earnedInSection/${badges.length}',
                  style: AppTypography.caption.copyWith(
                    color: earnedInSection > 0
                        ? AppColors.success
                        : AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Grid 3 columns
        // ใช้ GridView.builder เพื่อแสดง badges
        GridView.builder(
          // ต้องใช้ shrinkWrap เพราะอยู่ใน ListView
          shrinkWrap: true,
          // ปิด scroll เพราะ parent ListView จะ handle scroll
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // 3 columns ตามที่ user ต้องการ
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75, // ทำให้ card สูงกว่ากว้าง
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) {
            return _buildBadgeCard(badges[index]);
          },
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  /// สร้าง Badge Card widget
  ///
  /// แสดง:
  /// - Badge icon (56x56 circle) พร้อม border ตาม rarity
  /// - Checkmark ถ้าได้รับแล้ว / Lock ถ้ายังไม่ได้
  /// - Badge name (max 2 lines)
  /// - Rarity indicator (emoji + label)
  Widget _buildBadgeCard(BadgeInfo info) {
    final badge = info.badge;
    final isEarned = info.isEarnedByCurrentUser;
    final rarityColor = _getRarityColor(badge.rarity);

    return GestureDetector(
      // เมื่อกดจะแสดง bottom sheet รายละเอียด
      onTap: () => _showBadgeDetail(info),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: AppRadius.smallRadius,
          // Border แตกต่างตาม earned state
          border: Border.all(
            color: isEarned ? AppColors.success : AppColors.alternate,
            width: isEarned ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge icon with status indicator
            Stack(
              children: [
                // Badge circle
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    // สีพื้นหลังตาม rarity และ earned state
                    color: isEarned
                        ? rarityColor.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isEarned ? rarityColor : Colors.grey,
                      width: isEarned ? 3 : 2,
                    ),
                  ),
                  child: Center(
                    child: _buildBadgeIcon(badge, isEarned),
                  ),
                ),
                // Status indicator (checkmark หรือ lock)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildStatusIndicator(isEarned),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Badge name
            Text(
              badge.name,
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                // ถ้ายังไม่ได้ให้ใช้สีจาง
                color: isEarned
                    ? AppColors.primaryText
                    : AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            // Rarity indicator
            Text(
              '${badge.rarityEmoji} ${_getRarityLabel(badge.rarity)}',
              style: AppTypography.caption.copyWith(
                fontSize: 9,
                color: isEarned ? rarityColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// สร้าง Badge icon
  ///
  /// ถ้ามี imageUrl จะแสดงรูป ถ้าไม่มีจะแสดง emoji
  /// ถ้ายังไม่ได้รับจะใส่ ColorFiltered เป็น greyscale
  Widget _buildBadgeIcon(Badge badge, bool isEarned) {
    Widget iconWidget;

    if (badge.imageUrl != null) {
      // แสดงรูปจาก URL
      iconWidget = ClipOval(
        child: Image.network(
          badge.imageUrl!,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          // จำกัดขนาดใน memory เพื่อป้องกัน crash บน iOS/Android สเปคต่ำ
          cacheWidth: 100,
          // ถ้าโหลดรูปไม่ได้ให้แสดง emoji แทน
          errorBuilder: (context, error, stackTrace) => Text(
            badge.icon ?? badge.rarityEmoji,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      );
    } else {
      // แสดง emoji
      iconWidget = Text(
        badge.icon ?? badge.rarityEmoji,
        style: const TextStyle(fontSize: 24),
      );
    }

    // ถ้ายังไม่ได้รับ ใส่ greyscale filter
    if (!isEarned) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.grey,
          BlendMode.saturation,
        ),
        child: iconWidget,
      );
    }

    return iconWidget;
  }

  /// สร้าง status indicator (checkmark/lock)
  Widget _buildStatusIndicator(bool isEarned) {
    if (isEarned) {
      // แสดง checkmark สีเขียว
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 2),
        ),
        child: const Icon(
          Icons.check,
          size: 10,
          color: Colors.white,
        ),
      );
    } else {
      // แสดง lock icon
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 2),
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedSquareLock02,
          size: 10,
          color: Colors.white,
        ),
      );
    }
  }

  /// แสดง Bottom Sheet รายละเอียด badge
  ///
  /// ประกอบด้วย:
  /// - Badge icon ขนาดใหญ่
  /// - ชื่อและ description
  /// - Requirement description
  /// - จำนวน users ที่ได้รับและ %
  /// - วันที่ได้รับ (ถ้าได้แล้ว)
  void _showBadgeDetail(BadgeInfo info) {
    final badge = info.badge;
    final isEarned = info.isEarnedByCurrentUser;
    final rarityColor = _getRarityColor(badge.rarity);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Badge icon ขนาดใหญ่
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isEarned
                              ? rarityColor.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isEarned ? rarityColor : Colors.grey,
                            width: 4,
                          ),
                          // เพิ่ม shadow สำหรับ earned badge
                          boxShadow: isEarned
                              ? [
                                  BoxShadow(
                                    color: rarityColor.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: _buildBadgeIcon(badge, isEarned),
                        ),
                      ),
                      // Status indicator
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isEarned ? AppColors.success : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.secondaryBackground,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            isEarned ? Icons.check : Icons.lock,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Badge name
                  Text(
                    badge.name,
                    style: AppTypography.title.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Rarity tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: rarityColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.fullRadius,
                    ),
                    child: Text(
                      '${badge.rarityEmoji} ${_getRarityLabel(badge.rarity)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: rarityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description (ถ้ามี)
                  if (badge.description != null) ...[
                    Text(
                      badge.description!,
                      style: AppTypography.body.copyWith(
                        color: AppColors.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Requirement
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBackground,
                      borderRadius: AppRadius.smallRadius,
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedTarget02,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            badge.requirementDescription,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Users count
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedUserGroup,
                        size: 16,
                        color: AppColors.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${info.earnedCount} คนได้รับ',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Percentage with color coding
                      Text(
                        '(${info.earnedPercent.toStringAsFixed(1)}%)',
                        style: AppTypography.bodySmall.copyWith(
                          // สีตาม % ที่ได้รับ
                          color: info.earnedPercent < 10
                              ? AppColors.error // หายาก
                              : info.earnedPercent < 30
                                  ? AppColors.warning // ปานกลาง
                                  : AppColors.success, // ธรรมดา
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Points
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedStar,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+${badge.points} pts',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Earned date (ถ้าได้แล้ว)
                  if (isEarned && badge.earnedAt != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smallRadius,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                            size: 16,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ได้รับเมื่อ ${_formatDate(badge.earnedAt!)}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.smallRadius,
                        ),
                      ),
                      child: const Text('ปิด'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format date สำหรับแสดงวันที่ได้รับ badge
  String _formatDate(DateTime date) {
    final thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    // แปลงเป็นปี พ.ศ.
    final thaiYear = date.year + 543;
    return '${date.day} ${thaiMonths[date.month - 1]} $thaiYear';
  }

  /// Get rarity color
  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'legendary':
        return const Color(0xFFFFD700); // Gold
      case 'epic':
        return const Color(0xFF9B59B6); // Purple
      case 'rare':
        return const Color(0xFF3498DB); // Blue
      default:
        return AppColors.primary; // Teal (common)
    }
  }

  /// Get rarity emoji
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

  /// Get rarity label (English)
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
