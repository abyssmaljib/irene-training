import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/create_post_provider.dart';
import 'restock_section_widget.dart';

// ============================================
// PostExtrasSection — "แนบเพิ่มเติม" section
// ============================================
// Collapsible container สำหรับ features เพิ่มเติมที่แนบไปกับ Post
// แสดงเมื่อเลือก resident แล้ว ใน AdvancedCreatePostScreen
//
// ปัจจุบัน:
//   - อัพเดตสต็อก (restock ยา)
//
// อนาคต (เพิ่ม chip + content ง่ายๆ):
//   - ใบนัด (appointment slip)
//   - อื่นๆ
//
// Layout:
// ┌─ 📎 แนบเพิ่มเติม ─────────────── ▼ ─┐
// │ [💊 อัพเดตสต็อก (2)]  [📋 ใบนัด]    │
// │                                       │
// │ ┌─ Restock content ─────────────────┐ │
// │ │ (expanded content ของ chip ที่เลือก)│ │
// │ └───────────────────────────────────┘ │
// └───────────────────────────────────────┘

class PostExtrasSection extends StatefulWidget {
  /// ID ของ resident ที่เลือก
  final int residentId;

  /// ชื่อ resident (ส่งต่อให้หน้าเพิ่มยา)
  final String? residentName;

  // === Restock props ===
  final List<RestockItem> restockItems;
  final ValueChanged<List<RestockItem>> onRestockItemsLoaded;
  final void Function(int medicineListId, bool enabled) onRestockItemToggled;
  final void Function(int medicineListId, String inputDisplay, double reconcile)
      onRestockQuantityChanged;

  /// Callback เมื่อสร้างยาใหม่สำเร็จ → ส่ง med_history ID กลับ
  final ValueChanged<int>? onNewMedicineCreated;

  const PostExtrasSection({
    super.key,
    required this.residentId,
    this.residentName,
    required this.restockItems,
    required this.onRestockItemsLoaded,
    required this.onRestockItemToggled,
    required this.onRestockQuantityChanged,
    this.onNewMedicineCreated,
  });

  @override
  State<PostExtrasSection> createState() => _PostExtrasSectionState();
}

/// Enum สำหรับ feature ที่แสดงใน extras
/// เพิ่ม feature ใหม่ได้ง่าย: เพิ่ม enum value + chip + content
enum _ExtraFeature {
  restock,
  // appointment, // อนาคต: ใบนัด
}

class _PostExtrasSectionState extends State<PostExtrasSection> {
  // Expand/collapse ของ outer section
  bool _isExpanded = false;

  // Feature ที่กำลังเปิดอยู่ (null = ไม่มี content แสดง)
  _ExtraFeature? _activeFeature;

  /// จำนวน restock items ที่ enabled (สำหรับแสดง badge)
  int get _restockEnabledCount =>
      widget.restockItems.where((i) => i.enabled).length;

  /// ตรวจว่ามี feature ไหนมีข้อมูลที่ user เลือกแล้วบ้าง
  /// ใช้สำหรับ highlight header
  bool get _hasAnyEnabled => _restockEnabledCount > 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // === Header: "แนบเพิ่มเติม" ===
        _buildHeader(),

        // === Content (expanded): chips + active feature content ===
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _isExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _buildExpandedContent(),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ============================================
  // Header — tap เพื่อ expand/collapse
  // ============================================
  Widget _buildHeader() {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: _hasAnyEnabled ? AppColors.primary : AppColors.alternate,
            width: _hasAnyEnabled ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: _hasAnyEnabled
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Icon
            HugeIcon(
              icon: HugeIcons.strokeRoundedAttachment01,
              size: AppIconSize.lg,
              color: _hasAnyEnabled
                  ? AppColors.primary
                  : AppColors.secondaryText,
            ),
            const SizedBox(width: 8),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'แนบเพิ่มเติม',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _hasAnyEnabled
                          ? AppColors.primary
                          : AppColors.primaryText,
                    ),
                  ),
                  Text(
                    'อัพเดตสต็อก, ใบนัด และอื่นๆ',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            // Expand/collapse arrow
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                size: AppIconSize.md,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // Expanded Content — chips + feature content
  // ============================================
  Widget _buildExpandedContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === Feature Chips ===
          // Tap chip เพื่อ toggle แสดง/ซ่อน content ของ feature นั้น
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureChip(
                feature: _ExtraFeature.restock,
                icon: HugeIcons.strokeRoundedMedicine02,
                label: 'อัพเดตสต็อก',
                count: _restockEnabledCount,
              ),
              // อนาคต: เพิ่ม chip ใหม่ตรงนี้
              // _buildFeatureChip(
              //   feature: _ExtraFeature.appointment,
              //   icon: HugeIcons.strokeRoundedCalendar03,
              //   label: 'ใบนัด',
              // ),
            ],
          ),

          // === Active Feature Content ===
          if (_activeFeature != null) ...[
            AppSpacing.verticalGapSm,
            _buildActiveFeatureContent(),
          ],
        ],
      ),
    );
  }

  // ============================================
  // Feature Chip — tap toggle active feature
  // ============================================
  Widget _buildFeatureChip({
    required _ExtraFeature feature,
    required dynamic icon,
    required String label,
    int count = 0,
  }) {
    final isActive = _activeFeature == feature;

    return InkWell(
      onTap: () {
        setState(() {
          // Toggle: tap อีกครั้งเพื่อ collapse
          _activeFeature = isActive ? null : feature;
        });
      },
      borderRadius: AppRadius.fullRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: AppRadius.fullRadius,
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.alternate,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: icon,
              size: AppIconSize.sm,
              color: isActive ? AppColors.primary : AppColors.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isActive ? AppColors.primary : AppColors.primaryText,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            // Badge จำนวน (ถ้า > 0)
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.fullRadius,
                ),
                child: Text(
                  '$count',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================
  // Active Feature Content — render ตาม feature ที่เลือก
  // ============================================
  Widget _buildActiveFeatureContent() {
    switch (_activeFeature) {
      case _ExtraFeature.restock:
        return RestockSectionContent(
          residentId: widget.residentId,
          residentName: widget.residentName,
          restockItems: widget.restockItems,
          onItemsLoaded: widget.onRestockItemsLoaded,
          onItemToggled: widget.onRestockItemToggled,
          onQuantityChanged: widget.onRestockQuantityChanged,
          onNewMedicineCreated: widget.onNewMedicineCreated,
        );
      // อนาคต:
      // case _ExtraFeature.appointment:
      //   return AppointmentSectionContent(...);
      default:
        return const SizedBox.shrink();
    }
  }
}