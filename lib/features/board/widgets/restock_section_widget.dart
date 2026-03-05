import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/input_fields.dart';
import '../../medicine/screens/add_medicine_to_resident_screen.dart';
import '../../medicine/services/medicine_service.dart';
import '../providers/create_post_provider.dart';

// ============================================
// RestockSectionContent
// ============================================
// Content widget สำหรับ "อัพเดตสต็อก" ใน PostExtrasSection
// ไม่มี header ตัวเอง — ใช้เป็น content ภายใน PostExtrasSection
//
// แสดงรายการยา active ของ resident → user ติ๊กเลือก + กรอกจำนวน
//
// Smart input pattern:
//   "+30" → เพิ่มจากเดิม 30   (currentReconcile + 30)
//   "-5"  → ลดจากเดิม 5      (currentReconcile - 5)
//   "50"  → ใส่ค่าตรง 50      (reconcile = 50)

class RestockSectionContent extends StatefulWidget {
  /// ID ของ resident ที่เลือก (ใช้ fetch ยา)
  final int residentId;

  /// ชื่อ resident (ใช้แสดงในหน้าเพิ่มยา)
  final String? residentName;

  /// รายการ restock items จาก state
  final List<RestockItem> restockItems;

  /// Callback เมื่อ fetch ยาสำเร็จ → ส่ง items กลับให้ notifier
  final ValueChanged<List<RestockItem>> onItemsLoaded;

  /// Callback เมื่อ toggle checkbox
  final void Function(int medicineListId, bool enabled) onItemToggled;

  /// Callback เมื่อกรอกจำนวน (smart input)
  final void Function(int medicineListId, String inputDisplay, double reconcile)
      onQuantityChanged;

  /// Callback เมื่อสร้างยาใหม่สำเร็จ → ส่ง med_history ID กลับ
  /// ใช้เพื่อ track pending med_history ที่ต้อง link กับ post ภายหลัง
  final ValueChanged<int>? onNewMedicineCreated;

  const RestockSectionContent({
    super.key,
    required this.residentId,
    this.residentName,
    required this.restockItems,
    required this.onItemsLoaded,
    required this.onItemToggled,
    required this.onQuantityChanged,
    this.onNewMedicineCreated,
  });

  @override
  State<RestockSectionContent> createState() => _RestockSectionContentState();
}

class _RestockSectionContentState extends State<RestockSectionContent> {
  bool _isLoading = false;
  String? _error;
  int? _loadedResidentId;

  @override
  void initState() {
    super.initState();
    _fetchMedicines();
  }

  @override
  void didUpdateWidget(covariant RestockSectionContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // เปลี่ยน resident → fetch ยาใหม่
    if (widget.residentId != oldWidget.residentId) {
      _loadedResidentId = null;
      _fetchMedicines();
    }
  }

  /// Fetch ยา active ของ resident แล้วสร้าง RestockItem list
  Future<void> _fetchMedicines() async {
    if (_loadedResidentId == widget.residentId &&
        widget.restockItems.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final medicines = await MedicineService.instance
          .getActiveMedicines(widget.residentId);

      final items = medicines.map((med) {
        final name = med.str != null && med.str!.isNotEmpty
            ? '${med.displayName} ${med.str}'
            : med.displayName;

        return RestockItem(
          medicineListId: med.medicineListId,
          medicineName: name,
          currentReconcile: med.lastMedHistoryReconcile ?? 0,
          unit: med.unit ?? 'เม็ด',
        );
      }).toList();

      _loadedResidentId = widget.residentId;
      widget.onItemsLoaded(items);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('[RestockSection] fetch error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'ไม่สามารถโหลดรายการยาได้';
        });
      }
    }
  }

  /// เปิดหน้าเพิ่มยาให้ resident → พอเสร็จก็ refresh รายการ
  /// result อาจเป็น int (med_history ID) หรือ true (เดิม) หรือ null (ยกเลิก)
  Future<void> _openAddMedicine() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicineToResidentScreen(
          residentId: widget.residentId,
          residentName: widget.residentName,
        ),
      ),
    );

    // ถ้าเพิ่มสำเร็จ → force refresh รายการยา
    if (result != null && mounted) {
      // ถ้าได้ med_history ID กลับมา → แจ้ง parent เพื่อ track pending
      if (result is int) {
        widget.onNewMedicineCreated?.call(result);
      }
      _loadedResidentId = null;
      MedicineService.instance.invalidateCache();
      _fetchMedicines();
    }
  }

  /// คำนวณ reconcile จาก smart input
  double _parseSmartInput(String input, double currentReconcile) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 0;

    if (trimmed.startsWith('+')) {
      final value = double.tryParse(trimmed.substring(1)) ?? 0;
      return currentReconcile + value;
    } else if (trimmed.startsWith('-')) {
      final value = double.tryParse(trimmed.substring(1)) ?? 0;
      final result = currentReconcile - value;
      return result < 0 ? 0 : result;
    } else {
      return double.tryParse(trimmed) ?? 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Error
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: AppIconSize.sm,
              color: AppColors.error,
            ),
            AppSpacing.horizontalGapXs,
            Text(
              _error!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
        ),
      );
    }

    // Empty — ไม่มียา active
    if (widget.restockItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedInformationCircle,
              size: AppIconSize.sm,
              color: AppColors.secondaryText,
            ),
            AppSpacing.horizontalGapXs,
            Text(
              'ไม่มียาที่ active สำหรับผู้พักนี้',
              style:
                  AppTypography.caption.copyWith(color: AppColors.secondaryText),
            ),
          ],
        ),
      );
    }

    // รายการยา + ปุ่มเพิ่มยาอื่น
    return Column(
      children: [
        // รายการยา active
        ...widget.restockItems.map((item) {
          return _RestockItemTile(
            item: item,
            onToggled: (enabled) {
              widget.onItemToggled(item.medicineListId, enabled);
            },
            onQuantityChanged: (inputDisplay) {
              final reconcile =
                  _parseSmartInput(inputDisplay, item.currentReconcile);
              widget.onQuantityChanged(
                  item.medicineListId, inputDisplay, reconcile);
            },
          );
        }),

        // ปุ่ม "เพิ่มยาอื่น" — เปิดหน้า AddMedicineToResidentScreen
        AppSpacing.verticalGapXs,
        InkWell(
          onTap: _openAddMedicine,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.alternate,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  size: AppIconSize.md,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'เพิ่มยาอื่น',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================
// _RestockItemTile — แต่ละรายการยา
// ============================================
// StatefulWidget เพื่อเก็บ TextEditingController ถาวร
// ป้องกัน: สร้าง controller ใหม่ทุก rebuild → field หลุด focus
class _RestockItemTile extends StatefulWidget {
  final RestockItem item;
  final ValueChanged<bool> onToggled;
  final ValueChanged<String> onQuantityChanged;

  const _RestockItemTile({
    required this.item,
    required this.onToggled,
    required this.onQuantityChanged,
  });

  @override
  State<_RestockItemTile> createState() => _RestockItemTileState();
}

class _RestockItemTileState extends State<_RestockItemTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.inputDisplay);
  }

  @override
  void didUpdateWidget(covariant _RestockItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller เฉพาะเมื่อค่าเปลี่ยนจากภายนอก (reset จาก notifier)
    if (widget.item.inputDisplay != oldWidget.item.inputDisplay &&
        widget.item.inputDisplay != _controller.text) {
      _controller.text = widget.item.inputDisplay;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _difference =>
      widget.item.reconcile - widget.item.currentReconcile;

  bool get _showPreview =>
      widget.item.enabled && widget.item.inputDisplay.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: item.enabled ? AppColors.primary : AppColors.alternate,
            width: item.enabled ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: item.enabled
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Checkbox + ชื่อยา
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: item.enabled,
                    onChanged: (v) => widget.onToggled(v ?? false),
                    activeColor: AppColors.primary,
                    checkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: BorderSide(
                      color: item.enabled
                          ? AppColors.primary
                          : AppColors.secondaryText,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.medicineName,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: item.enabled
                          ? AppColors.primaryText
                          : AppColors.secondaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Row 2: คงเหลือ + input field
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'คงเหลือ: ${_formatNumber(item.currentReconcile)} ${item.unit}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),

                  // Smart input field (แสดงเมื่อ enabled)
                  if (item.enabled) ...[
                    AppSpacing.verticalGapSm,
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _controller,
                            onChanged: widget.onQuantityChanged,
                            hintText: 'เช่น +30, -5, หรือ 50',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            isDense: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.unit,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),

                    // Preview reconcile ใหม่
                    if (_showPreview) ...[
                      AppSpacing.verticalGapXs,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _difference >= 0
                              ? AppColors.tagPassedBg
                              : AppColors.tagPendingBg,
                          borderRadius: AppRadius.smallRadius,
                        ),
                        child: Text(
                          '→ ${_formatNumber(item.reconcile)} ${item.unit} '
                          '(${_difference >= 0 ? '+' : ''}${_formatNumber(_difference)})',
                          style: AppTypography.caption.copyWith(
                            color: _difference >= 0
                                ? AppColors.tagPassedText
                                : AppColors.tagPendingText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}