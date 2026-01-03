import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/input_fields.dart';
import '../models/new_tag.dart';
import '../providers/tag_provider.dart';

/// Widget สำหรับเลือก tag (Single Select) พร้อม handover toggle
class TagPickerWidget extends ConsumerWidget {
  final NewTag? selectedTag;
  final bool isHandover;
  final ValueChanged<NewTag> onTagSelected;
  final VoidCallback? onTagCleared;
  final ValueChanged<bool> onHandoverChanged;

  const TagPickerWidget({
    super.key,
    this.selectedTag,
    this.isHandover = false,
    required this.onTagSelected,
    this.onTagCleared,
    required this.onHandoverChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          'เลือกหัวข้อ',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        AppSpacing.verticalGapSm,

        // Tags grid
        tagsAsync.when(
          data: (tags) => _buildTagsGrid(tags),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => Text(
            'ไม่สามารถโหลด tags ได้',
            style: AppTypography.caption.copyWith(color: AppColors.error),
          ),
        ),

        // Handover toggle (แสดงเมื่อเลือก tag แล้ว)
        if (selectedTag != null) ...[
          AppSpacing.verticalGapMd,
          _buildHandoverToggle(),
        ],
      ],
    );
  }

  Widget _buildTagsGrid(List<NewTag> tags) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        final isSelected = selectedTag?.id == tag.id;

        return ChoiceChip(
          avatar: tag.emoji != null
              ? Text(
                  tag.emoji!,
                  style: const TextStyle(fontSize: 16),
                )
              : null,
          label: Text(tag.name),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              onTagSelected(tag);
            } else if (onTagCleared != null) {
              onTagCleared!();
            }
          },
          selectedColor: AppColors.accent1,
          backgroundColor: AppColors.surface,
          labelStyle: AppTypography.bodySmall.copyWith(
            color: isSelected ? AppColors.primary : AppColors.primaryText,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.alternate,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
      }).toList(),
    );
  }

  Widget _buildHandoverToggle() {
    final canToggle = selectedTag?.isOptionalHandover ?? false;
    final isForce = selectedTag?.isForceHandover ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHandover ? AppColors.tagPassedBg : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHandover ? AppColors.success : AppColors.alternate,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isHandover
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.alternate.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isHandover ? Icons.swap_horiz : Icons.swap_horiz_outlined,
              color: isHandover ? AppColors.success : AppColors.secondaryText,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ส่งเวร',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isHandover ? AppColors.success : AppColors.primaryText,
                  ),
                ),
                Text(
                  isForce
                      ? 'จำเป็นต้องส่งเวรสำหรับหัวข้อนี้'
                      : 'เลือกส่งเวรถ้าเรื่องนี้สำคัญ',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),

          // Switch
          Switch(
            value: isHandover,
            onChanged: canToggle ? onHandoverChanged : null,
            activeTrackColor: AppColors.success.withValues(alpha: 0.5),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.success;
              }
              return AppColors.secondaryText;
            }),
          ),
        ],
      ),
    );
  }
}

/// Compact version สำหรับ bottom sheet - แสดงเป็น chip button เท่านั้น
/// กดแล้วเปิด bottom sheet เลือก tag
/// Note: Handover toggle ถูกย้ายไปจัดการที่ parent widget แล้ว
class TagPickerCompact extends ConsumerWidget {
  final NewTag? selectedTag;
  final bool isHandover;
  final ValueChanged<NewTag> onTagSelected;
  final VoidCallback? onTagCleared;
  final ValueChanged<bool> onHandoverChanged;

  const TagPickerCompact({
    super.key,
    this.selectedTag,
    this.isHandover = false,
    required this.onTagSelected,
    this.onTagCleared,
    required this.onHandoverChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // แสดงแค่ chip button เท่านั้น (handover toggle อยู่ที่ parent)
    if (selectedTag != null) {
      return _buildSelectedTagChip(context);
    } else {
      return _buildSelectTagButton(context);
    }
  }

  /// แสดง tag ที่เลือกแล้ว
  Widget _buildSelectedTagChip(BuildContext context) {
    return GestureDetector(
      onTap: () => _showTagPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedTag?.emoji != null) ...[
              Text(selectedTag!.emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
            ],
            Text(
              selectedTag!.name,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onTagCleared != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onTagCleared,
                child: Icon(
                  Iconsax.close_circle,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ปุ่มเลือก tag (ยังไม่เลือก)
  Widget _buildSelectTagButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showTagPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.alternate),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#',
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'เลือกหัวข้อ',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Iconsax.arrow_down_1,
              size: 14,
              color: AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  void _showTagPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagPickerSheet(
        selectedTag: selectedTag,
        onSelect: (tag) {
          onTagSelected(tag);
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Bottom sheet สำหรับเลือก Tag พร้อม search
class TagPickerSheet extends ConsumerStatefulWidget {
  final NewTag? selectedTag;
  final void Function(NewTag) onSelect;

  const TagPickerSheet({
    super.key,
    this.selectedTag,
    required this.onSelect,
  });

  @override
  ConsumerState<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<TagPickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.alternate,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '# เลือกหัวข้อ',
              style: AppTypography.title,
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchField(
              controller: _searchController,
              hintText: 'ค้นหาหัวข้อ...',
              isDense: true,
              onChanged: (value) => setState(() => _searchQuery = value),
              onClear: () => setState(() => _searchQuery = ''),
            ),
          ),

          AppSpacing.verticalGapMd,

          // Tags grid
          Expanded(
            child: tagsAsync.when(
              data: (tags) {
                final filtered = _filterTags(tags);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Iconsax.hashtag, size: 48, color: AppColors.alternate),
                        AppSpacing.verticalGapMd,
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'ไม่พบหัวข้อ "$_searchQuery"'
                              : 'ไม่มีหัวข้อ',
                          style: AppTypography.body.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: filtered.map((tag) {
                      final isSelected = widget.selectedTag?.id == tag.id;
                      return _TagChip(
                        tag: tag,
                        isSelected: isSelected,
                        onTap: () => widget.onSelect(tag),
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'เกิดข้อผิดพลาด',
                  style: AppTypography.body.copyWith(color: AppColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<NewTag> _filterTags(List<NewTag> tags) {
    if (_searchQuery.isEmpty) return tags;

    final query = _searchQuery.toLowerCase();
    return tags.where((t) {
      return t.name.toLowerCase().contains(query) ||
          (t.emoji?.contains(query) ?? false);
    }).toList();
  }
}

/// Custom Tag Chip ที่สวยกว่า ChoiceChip
/// ใช้แนวทางเดียวกับ ProgressTag ใน tags_badges.dart
class _TagChip extends StatelessWidget {
  final NewTag tag;
  final bool isSelected;
  final VoidCallback? onTap;

  const _TagChip({
    required this.tag,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent1 : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.alternate,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tag.emoji != null) ...[
              Text(
                tag.emoji!,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              tag.name,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.primaryText,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
