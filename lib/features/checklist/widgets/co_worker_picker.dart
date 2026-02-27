import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/network_image.dart';
import '../providers/batch_task_provider.dart';

/// Reusable widget สำหรับเลือกเพื่อนร่วมเวร
///
/// ใช้ได้ทั้งใน BatchTaskScreen และ TaskDetailScreen
/// — ดึงรายชื่อจาก coWorkersProvider (คนที่ clock-in เวรเดียวกัน ยังไม่ clock-out)
/// — แสดง chip ของคนที่เลือก + ปุ่ม "เลือก" เปิด bottom sheet
/// — แจ้ง parent ผ่าน onChanged callback ทุกครั้งที่ selection เปลี่ยน
class CoWorkerPickerSection extends ConsumerStatefulWidget {
  /// รายชื่อเพื่อนร่วมเวรที่เลือกไว้แล้ว (ถ้ามี)
  final List<CoWorker> initialSelection;

  /// Callback เมื่อ selection เปลี่ยน — parent เอาไปใช้ตอน complete task
  final ValueChanged<List<CoWorker>> onChanged;

  const CoWorkerPickerSection({
    super.key,
    this.initialSelection = const [],
    required this.onChanged,
  });

  @override
  ConsumerState<CoWorkerPickerSection> createState() =>
      _CoWorkerPickerSectionState();
}

class _CoWorkerPickerSectionState
    extends ConsumerState<CoWorkerPickerSection> {
  late List<CoWorker> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelection);
  }

  /// เพิ่มเพื่อนร่วมเวร
  void _addCoWorker(CoWorker cw) {
    setState(() => _selected.add(cw));
    widget.onChanged(_selected);
  }

  /// ลบเพื่อนร่วมเวร
  void _removeCoWorker(String userId) {
    setState(() => _selected.removeWhere((c) => c.userId == userId));
    widget.onChanged(_selected);
  }

  @override
  Widget build(BuildContext context) {
    // ทั้ง card กดได้เลย → เปิด bottom sheet เลือกเพื่อนร่วมเวร
    return GestureDetector(
      onTap: () => _showCoWorkerPicker(context),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          border: Border.all(color: AppColors.alternate, width: 0.5),
        ),
        child: Stack(
          children: [
            // Overlay icon จางๆ มุมขวา — ตกแต่งให้ card ดูสวย
            Positioned(
              right: -8,
              bottom: -8,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedUserAdd02,
                color: AppColors.primary.withValues(alpha: 0.07),
                size: 100,
              ),
            ),

            // เนื้อหาหลัก
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedUserGroup,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      AppSpacing.horizontalGapSm,
                      Expanded(
                        child: Text(
                          'เพื่อนร่วมเวร',
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Label จางๆ บอกว่ากดได้
                      Text(
                        _selected.isEmpty ? 'กดเพื่อเลือก' : 'กดเพื่อแก้ไข',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryText.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),

                  // รายชื่อที่เลือกแล้ว (chips) หรือข้อความยังไม่ได้เลือก
                  if (_selected.isNotEmpty) ...[
                    AppSpacing.verticalGapSm,
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: _selected.map((cw) {
                        return Chip(
                          avatar: IreneNetworkAvatar(
                            imageUrl: cw.photoUrl,
                            radius: 12,
                          ),
                          label: Text(cw.nickname, style: AppTypography.caption),
                          deleteIcon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 14,
                            color: AppColors.secondaryText,
                          ),
                          onDeleted: () => _removeCoWorker(cw.userId),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    AppSpacing.verticalGapSm,
                    Text(
                      'ยังไม่ได้เลือก (point จะไม่ถูกหาร)',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  // คำอธิบายเพิ่มเติม
                  AppSpacing.verticalGapXs,
                  Text(
                    'หลังถ่ายรูปเสร็จ เพื่อนร่วมเวรที่เลือกจะได้หารคะแนนด้วยคนละครึ่ง',
                    style: AppTypography.overline.copyWith(
                      color: AppColors.secondaryText,
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

  /// เปิด bottom sheet ให้เลือกเพื่อนร่วมเวร
  void _showCoWorkerPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        // ใช้ StatefulBuilder เพื่อ rebuild bottom sheet เมื่อ toggle
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Consumer(
              builder: (_, sheetRef, _) {
                final coWorkersAsync = sheetRef.watch(coWorkersProvider);
                final selectedIds =
                    _selected.map((c) => c.userId).toSet();

                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedUserGroup,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            AppSpacing.horizontalGapSm,
                            Text(
                              'เลือกเพื่อนร่วมเวร',
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pop(sheetCtx),
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedCancel01,
                                color: AppColors.secondaryText,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.verticalGapSm,
                        Text(
                          'point จะถูกหารเท่าๆ กันกับเพื่อนที่เลือก',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                        AppSpacing.verticalGapMd,

                        // Content: loading / error / list
                        coWorkersAsync.when(
                          loading: () => Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          error: (err, _) => Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              'โหลดรายชื่อไม่สำเร็จ',
                              style: AppTypography.body.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          data: (coWorkers) {
                            if (coWorkers.isEmpty) {
                              return Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: Center(
                                  child: Column(
                                    children: [
                                      HugeIcon(
                                        icon:
                                            HugeIcons.strokeRoundedUserBlock01,
                                        color: AppColors.secondaryText,
                                        size: 40,
                                      ),
                                      AppSpacing.verticalGapSm,
                                      Text(
                                        'ไม่พบเพื่อนร่วมเวร',
                                        style: AppTypography.body.copyWith(
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                      AppSpacing.verticalGapXs,
                                      Text(
                                        'ยังไม่มีคนอื่นขึ้นเวรเดียวกัน',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // รายชื่อเพื่อนร่วมเวร (กด toggle เลือก/ไม่เลือก)
                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.4,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: coWorkers.length,
                                itemBuilder: (_, i) {
                                  final cw = coWorkers[i];
                                  final isSelected =
                                      selectedIds.contains(cw.userId);

                                  return ListTile(
                                    leading: IreneNetworkAvatar(
                                      imageUrl: cw.photoUrl,
                                      radius: 18,
                                    ),
                                    title: Text(
                                      cw.nickname,
                                      style: AppTypography.body,
                                    ),
                                    trailing: isSelected
                                        ? HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedCheckmarkCircle02,
                                            color: AppColors.primary,
                                            size: 24,
                                          )
                                        : HugeIcon(
                                            icon:
                                                HugeIcons.strokeRoundedCircle,
                                            color: AppColors.secondaryText,
                                            size: 24,
                                          ),
                                    onTap: () {
                                      if (isSelected) {
                                        _removeCoWorker(cw.userId);
                                      } else {
                                        _addCoWorker(cw);
                                      }
                                      // rebuild bottom sheet เพื่อ update checkmark
                                      setSheetState(() {});
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
