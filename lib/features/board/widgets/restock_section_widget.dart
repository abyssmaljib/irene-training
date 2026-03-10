import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/input_fields.dart';
import '../../../core/widgets/network_image.dart';
import '../../medicine/screens/add_medicine_to_resident_screen.dart';
import '../../medicine/services/medicine_service.dart';
import '../../medicine/widgets/medicine_info_card.dart';
import '../providers/create_post_provider.dart';
import '../services/ticket_service.dart';
import '../widgets/ticket_detail_bottom_sheet.dart';

// ============================================
// RestockSectionContent
// ============================================
// Content widget สำหรับ "อัพเดตสต็อก" ใน PostExtrasSection
// ไม่มี header ตัวเอง — ใช้เป็น content ภายใน PostExtrasSection
//
// แสดงรายการยา active ของ resident → user ติ๊กเลือก + กรอกจำนวน
//
// Input mode:
//   + (default) → กรอก 30 = เพิ่มจากเดิม 30  (currentReconcile + 30)
//   -           → กรอก 5  = ลดจากเดิม 5       (currentReconcile - 5)
//   =           → กรอก 50 = ตั้งค่าเป็น 50     (reconcile = 50)

/// โหมดการคำนวณ reconcile สำหรับ smart input
/// user เลือกผ่านปุ่ม +, -, = ใต้ input field
enum RestockInputMode {
  /// บวกเพิ่มจากยอดคงเหลือเดิม (default)
  add,

  /// ลบออกจากยอดคงเหลือเดิม
  subtract,

  /// ตั้งค่าตรงๆ (แทนที่ยอดเดิม)
  replace,
}

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
          medicineSummary: med, // เก็บข้อมูลยาฉบับเต็มสำหรับแสดงรูป + detail
        );
      }).toList();

      // === Fetch open tickets สำหรับยาทั้งหมด ===
      // ดึง ticket ที่ยังเปิดอยู่ (status != 'completed') จาก B_Ticket
      // เพื่อแสดงให้ user เห็นว่ามี ticket ค้างอยู่ พร้อม checkbox ปิด
      final medListIds = items.map((i) => i.medicineListId).toList();
      final ticketMap = await TicketService.instance
          .getOpenTicketsByMedListIds(medListIds);

      // ใส่ tickets เข้าไปใน RestockItem แต่ละตัว
      final itemsWithTickets = items.map((item) {
        final tickets = ticketMap[item.medicineListId] ?? [];
        return item.copyWith(openTickets: tickets);
      }).toList();

      _loadedResidentId = widget.residentId;
      widget.onItemsLoaded(itemsWithTickets);

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

  /// คำนวณ reconcile จาก input + mode
  /// mode จะถูกส่งมาจาก _RestockItemTile (user เลือกจากปุ่ม +/-/=)
  double _parseSmartInput(
    String input,
    double currentReconcile,
    RestockInputMode mode,
  ) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 0;

    final value = double.tryParse(trimmed) ?? 0;

    switch (mode) {
      case RestockInputMode.add:
        return currentReconcile + value;
      case RestockInputMode.subtract:
        final result = currentReconcile - value;
        return result < 0 ? 0 : result;
      case RestockInputMode.replace:
        return value;
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

    // เรียงยาที่มี ticket ไว้ด้านบน เพื่อให้ user เห็นก่อน
    final sortedItems = [...widget.restockItems]
      ..sort((a, b) {
        final aHas = a.openTickets.isNotEmpty ? 0 : 1;
        final bHas = b.openTickets.isNotEmpty ? 0 : 1;
        return aHas.compareTo(bHas);
      });

    // รายการยา + ปุ่มเพิ่มยาอื่น
    return Column(
      children: [
        // รายการยา active (ยาที่มี ticket อยู่ด้านบน)
        ...sortedItems.map((item) {
          return _RestockItemTile(
            item: item,
            residentId: widget.residentId,
            residentName: widget.residentName,
            onToggled: (enabled) {
              widget.onItemToggled(item.medicineListId, enabled);
            },
            onQuantityChanged: (inputDisplay, mode) {
              final reconcile = _parseSmartInput(
                  inputDisplay, item.currentReconcile, mode);
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
  final int residentId;
  final String? residentName;
  final ValueChanged<bool> onToggled;

  /// Callback เมื่อกรอกจำนวน — ส่ง (inputDisplay, mode) กลับให้ parent
  final void Function(String inputDisplay, RestockInputMode mode)
      onQuantityChanged;

  const _RestockItemTile({
    required this.item,
    required this.residentId,
    this.residentName,
    required this.onToggled,
    required this.onQuantityChanged,
  });

  @override
  State<_RestockItemTile> createState() => _RestockItemTileState();
}

class _RestockItemTileState extends State<_RestockItemTile> {
  late final TextEditingController _controller;

  /// โหมด input ปัจจุบัน (default = add เพราะ user มักจะเติมยาเพิ่ม)
  RestockInputMode _inputMode = RestockInputMode.add;

  /// เก็บ stock_status ที่ user เปลี่ยนจาก TicketDetailBottomSheet
  /// key = ticket.id, value = stock_status ใหม่
  /// ใช้ local state เพราะ TicketSummary เป็น immutable
  final Map<int, String> _localStockStatuses = {};

  /// Ticket ที่ user สร้างใหม่จากหน้านี้ (ยังไม่อยู่ใน widget.item.openTickets)
  final List<TicketSummary> _createdTickets = [];

  /// กำลังสร้าง ticket อยู่
  bool _isCreatingTicket = false;

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

  /// มี ticket เปิดอยู่หรือไม่ — ใช้ highlight กรอบ
  bool get _hasTickets =>
      widget.item.openTickets.isNotEmpty || _createdTickets.isNotEmpty;

  /// รวม tickets ทั้งหมด: จาก server + ที่สร้างใหม่ในรอบนี้
  List<TicketSummary> get _allTickets => [
        ...widget.item.openTickets,
        ..._createdTickets,
      ];

  /// Hint text ตามโหมด input ที่เลือก
  String get _inputModeHint {
    switch (_inputMode) {
      case RestockInputMode.add:
        return 'กรอกจำนวนที่เพิ่ม';
      case RestockInputMode.subtract:
        return 'กรอกจำนวนที่ลด';
      case RestockInputMode.replace:
        return 'กรอกยอดคงเหลือใหม่';
    }
  }

  /// Prefix สำหรับแสดงใน preview ตามโหมด
  String get _modePrefix {
    switch (_inputMode) {
      case RestockInputMode.add:
        return '+';
      case RestockInputMode.subtract:
        return '-';
      case RestockInputMode.replace:
        return '=';
    }
  }

  /// ปุ่มเลือกโหมด input: + (เพิ่ม), - (ลด), = (ตั้งค่า)
  /// แสดงเป็น segmented chips เล็กๆ ใต้ input field
  Widget _buildModeSelector() {
    return Row(
      children: [
        _buildModeChip(RestockInputMode.add, '+', 'เพิ่ม'),
        const SizedBox(width: 6),
        _buildModeChip(RestockInputMode.subtract, '−', 'ลด'),
        const SizedBox(width: 6),
        _buildModeChip(RestockInputMode.replace, '=', 'ตั้งค่า'),
      ],
    );
  }

  /// Chip สำหรับแต่ละโหมด — กดเพื่อเปลี่ยนโหมด
  Widget _buildModeChip(RestockInputMode mode, String symbol, String label) {
    final isActive = _inputMode == mode;

    return GestureDetector(
      onTap: () {
        if (_inputMode == mode) return;
        setState(() => _inputMode = mode);
        // Re-calculate ด้วยโหมดใหม่ + ค่าที่กรอกอยู่
        if (_controller.text.isNotEmpty) {
          widget.onQuantityChanged(_controller.text, mode);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.alternate,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              symbol,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.primary : AppColors.secondaryText,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isActive ? AppColors.primary : AppColors.secondaryText,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// สร้าง ticket ใหม่สำหรับยานี้
  Future<void> _createTicket() async {
    if (_isCreatingTicket) return;

    setState(() => _isCreatingTicket = true);

    final med = widget.item.medicineSummary;
    final ticket = await TicketService.instance.createTicketForMedicine(
      medicineListId: widget.item.medicineListId,
      residentId: widget.residentId,
      medicineName: med?.displayName ?? widget.item.medicineName,
      residentName: widget.residentName,
    );

    if (!mounted) return;

    if (ticket != null) {
      setState(() {
        _createdTickets.add(ticket);
        _isCreatingTicket = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('สร้างตั๋ว #${ticket.id} แล้ว'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _isCreatingTicket = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สร้างตั๋วไม่สำเร็จ'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// ปุ่มสร้าง Ticket ใหม่
  Widget _buildCreateTicketButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isCreatingTicket ? null : _createTicket,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.alternate),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isCreatingTicket)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTicket01,
                  size: 16,
                  color: AppColors.secondary,
                ),
              const SizedBox(width: 6),
              Text(
                _isCreatingTicket ? 'กำลังสร้าง...' : '+ สร้าง Ticket',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    // สีกรอบ: enabled (primary) > มี ticket (secondary/amber) > ปกติ (alternate)
    final Color borderColor;
    final double borderWidth;
    final Color bgColor;

    if (item.enabled) {
      borderColor = AppColors.primary;
      borderWidth = 2;
      bgColor = AppColors.primary.withValues(alpha: 0.05);
    } else if (_hasTickets) {
      // Highlight ยาที่มี ticket — ให้ user เห็นว่ามีตั๋วค้างอยู่
      borderColor = AppColors.secondary;
      borderWidth = 1.5;
      bgColor = AppColors.accent2;
    } else {
      borderColor = AppColors.alternate;
      borderWidth = 1;
      bgColor = Colors.transparent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: borderWidth),
          borderRadius: BorderRadius.circular(12),
          color: bgColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === ListTile-style header ===
            // กดทั้งแถว → toggle checkbox (ไม่ต้องจิ้ม checkbox เล็กๆ)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onToggled(!item.enabled),
                borderRadius: BorderRadius.circular(11),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // รูปยา (thumbnail)
                      _buildMedicineThumb(),
                      const SizedBox(width: 12),

                      // ชื่อยา + brand + strength + คงเหลือ
                      Expanded(child: _buildMedicineNameColumn()),

                      const SizedBox(width: 8),

                      // Checkbox (visual indicator เท่านั้น — กดทั้ง row ได้)
                      IgnorePointer(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: item.enabled,
                            onChanged: (_) {},
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
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // === Expanded content (เมื่อ enabled) ===
            // ดูรายละเอียดยา + input field + preview + tickets
            if (item.enabled)
              Padding(
                padding:
                    const EdgeInsets.only(left: 12, right: 12, bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ปุ่ม "ดูรายละเอียดยา" — เปิด bottom sheet
                    GestureDetector(
                      onTap: _showMedicineDetail,
                      child: Text(
                        'ดูรายละเอียดยา',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                      ),
                    ),
                    AppSpacing.verticalGapSm,

                    // Smart input field + unit label
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _controller,
                            onChanged: (value) {
                              widget.onQuantityChanged(value, _inputMode);
                            },
                            hintText: _inputModeHint,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
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

                    // === Mode selector: +, -, = ===
                    // ปุ่มเลือกโหมด input (default = บวกเพิ่ม)
                    const SizedBox(height: 6),
                    _buildModeSelector(),

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
                          '($_modePrefix${_formatNumber(_difference.abs())})',
                          style: AppTypography.caption.copyWith(
                            color: _difference >= 0
                                ? AppColors.tagPassedText
                                : AppColors.tagPendingText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    // === Ticket section ===
                    // แสดง tickets ที่มีอยู่ + ที่สร้างใหม่ในรอบนี้
                    if (_allTickets.isNotEmpty) ...[
                      AppSpacing.verticalGapSm,
                      ..._allTickets.map((ticket) => _buildTicketRow(ticket)),
                    ],

                    // ปุ่มสร้าง Ticket ใหม่
                    AppSpacing.verticalGapSm,
                    _buildCreateTicketButton(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// รูปยา thumbnail (40x40) — แสดง frontFoiled ถ้ามี, ไม่มีแสดง icon
  Widget _buildMedicineThumb() {
    final med = widget.item.medicineSummary;
    final imageUrl = med?.frontFoiled;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: IreneNetworkImage(
          imageUrl: imageUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          memCacheWidth: 100,
          compact: true,
        ),
      );
    }

    // Placeholder icon
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.alternate,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedMedicine02,
          color: AppColors.secondaryText,
          size: 22,
        ),
      ),
    );
  }

  /// ชื่อยา: generic name + brand (ถ้าต่าง) + strength + คงเหลือ
  Widget _buildMedicineNameColumn() {
    final item = widget.item;
    final med = item.medicineSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ชื่อสามัญ (generic name)
        Text(
          med?.genericName ?? item.medicineName,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: item.enabled
                ? AppColors.primaryText
                : AppColors.secondaryText,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // ชื่อการค้า (brand) — แสดงเฉพาะถ้าต่างจาก generic
        if (med?.brandName != null &&
            med!.brandName!.isNotEmpty &&
            med.brandName != med.genericName)
          Text(
            med.brandName!,
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        // ความแรง (strength) — ถ้ามี
        if (med?.str != null && med!.str!.isNotEmpty)
          Text(
            med.str!,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        // คงเหลือ
        const SizedBox(height: 2),
        Text(
          'คงเหลือ: ${_formatNumber(item.currentReconcile)} ${item.unit}',
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  /// กดดูรายละเอียดยา → แสดง MedicineInfoCard ใน bottom sheet
  void _showMedicineDetail() {
    final med = widget.item.medicineSummary;
    if (med == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.alternate,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // MedicineInfoCard
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: MedicineInfoCard(medicine: med),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  /// Mapping stock_status key → (emoji, label) สำหรับแสดง badge
  static const _stockStatusDisplayMap = <String, (String, String)>{
    'pending': ('🟡', 'รอแจ้งญาติ'),
    'notified': ('📞', 'แจ้งญาติแล้ว'),
    'waiting_relative': ('🚗', 'รอญาตินำยามา'),
    'waiting_appointment': ('🏥', 'รอไปพบแพทย์'),
    'added_to_appointment': ('📅', 'เพิ่มในนัดหมายแล้ว'),
    'staff_purchase': ('🛒', 'ญาติให้เราซื้อให้'),
    'purchasing': ('🔄', 'กำลังจัดซื้อ'),
    'waiting_delivery': ('📦', 'รอยามาส่ง'),
    'completed': ('✅', 'ได้รับยาแล้ว - เสร็จสิ้น'),
  };

  /// หา emoji + label จาก stock_status key
  (String, String) _getStockStatusDisplay(String key) {
    return _stockStatusDisplayMap[key] ?? ('⚪', key);
  }

  /// เปิด TicketDetailBottomSheet พร้อม callback อัพเดท stock_status กลับ
  void _openTicketDetail(TicketSummary ticket) {
    // ใช้ local stock status ถ้า user เคยเปลี่ยนในรอบนี้
    final currentStatus =
        _localStockStatuses[ticket.id] ?? ticket.stockStatus ?? 'pending';

    // สร้าง ticket ใหม่ที่มี stockStatus ล่าสุด (เพราะ TicketSummary เป็น immutable)
    final updatedTicket = TicketSummary(
      id: ticket.id,
      title: ticket.title,
      description: ticket.description,
      status: ticket.status,
      priority: ticket.priority,
      meetingAgenda: ticket.meetingAgenda,
      createdAt: ticket.createdAt,
      followUpDate: ticket.followUpDate,
      createdByNickname: ticket.createdByNickname,
      stockStatus: currentStatus,
      medListId: ticket.medListId,
    );

    showTicketDetailBottomSheet(
      context,
      ticket: updatedTicket,
      // เมื่อ user เปลี่ยน stock_status ใน detail sheet → อัพเดท badge ในหน้านี้
      onStockStatusChanged: (newStatus) {
        setState(() {
          _localStockStatuses[ticket.id] = newStatus;
        });
      },
    );
  }

  /// แสดง ticket 1 แถว: #ID + title + stock status badge (มุมขวาบน)
  /// Ticket จะถูกปิดอัตโนมัติเมื่อ restock มี reconcile > 0
  Widget _buildTicketRow(TicketSummary ticket) {

    // ใช้ local stock status ถ้า user เคยเปลี่ยน, ไม่งั้นใช้จาก ticket
    final currentStatus =
        _localStockStatuses[ticket.id] ?? ticket.stockStatus ?? 'pending';
    final (emoji, label) = _getStockStatusDisplay(currentStatus);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: ticket icon + #ID + stock status badge (มุมขวาบน)
            // กด badge → เปิดหน้ารายละเอียดตั๋ว + เปลี่ยนสถานะได้
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTicket02,
                  size: 16,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ตั๋ว #${ticket.id}',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                // Stock status badge — กดเพื่อเปิดรายละเอียดตั๋ว
                GestureDetector(
                  onTap: () => _openTicketDetail(ticket),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.alternate),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$emoji $label',
                          style: AppTypography.caption
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowRight01,
                          size: 12,
                          color: AppColors.secondaryText,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Row 2: ticket title (ถ้ามี)
            if (ticket.title.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                ticket.title,
                style: AppTypography.caption
                    .copyWith(color: AppColors.secondaryText),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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

