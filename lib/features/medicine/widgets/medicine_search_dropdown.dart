import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/network_image.dart';
import '../models/med_db.dart';

/// Widget สำหรับค้นหาและเลือกยาจากฐานข้อมูล
///
/// แสดง TextField สำหรับค้นหา พร้อม dropdown แสดงผลลัพธ์
/// รองรับ debounce เพื่อลด API calls
/// มีปุ่ม "เพิ่มยาใหม่" ที่ด้านล่างของรายการ
class MedicineSearchDropdown extends StatefulWidget {
  const MedicineSearchDropdown({
    super.key,
    required this.onSearch,
    required this.onSelect,
    required this.onAddNew,
    this.searchResults = const [],
    this.isSearching = false,
    this.selectedMedicine,
    this.onClear,
    this.onEditMedicine,
    this.enabled = true,
    this.hintText = 'ค้นหายา...',
    this.debounceDuration = const Duration(milliseconds: 500),
    this.showAddNewButton = true,
  });

  /// Callback เมื่อ user พิมพ์ค้นหา (หลัง debounce)
  final void Function(String query) onSearch;

  /// Callback เมื่อเลือกยาจาก dropdown
  final void Function(MedDB medicine) onSelect;

  /// Callback เมื่อกดปุ่ม "เพิ่มยาใหม่"
  /// ส่ง query ไปด้วยเพื่อ pre-fill ชื่อยา
  final void Function(String query) onAddNew;

  /// รายการผลลัพธ์จากการค้นหา
  final List<MedDB> searchResults;

  /// กำลังค้นหาอยู่หรือไม่
  final bool isSearching;

  /// ยาที่เลือกไว้แล้ว (ถ้ามี)
  final MedDB? selectedMedicine;

  /// Callback เมื่อล้างยาที่เลือก
  final VoidCallback? onClear;

  /// Callback เมื่อกดปุ่ม edit ยาที่เลือกไว้
  /// ส่ง MedDB ไปเพื่อเปิดหน้าแก้ไข
  final void Function(MedDB medicine)? onEditMedicine;

  /// สามารถแก้ไขได้หรือไม่
  final bool enabled;

  /// Placeholder text
  final String hintText;

  /// ระยะเวลา debounce ก่อนเรียก search
  final Duration debounceDuration;

  /// แสดงปุ่ม "เพิ่มยาใหม่ลงฐานข้อมูล" หรือไม่
  /// เฉพาะหัวหน้าเวรขึ้นไปถึงจะเห็นปุ่มนี้
  final bool showAddNewButton;

  @override
  State<MedicineSearchDropdown> createState() => _MedicineSearchDropdownState();
}

class _MedicineSearchDropdownState extends State<MedicineSearchDropdown> {
  // Controller สำหรับ TextField
  final _textController = TextEditingController();
  // Focus node สำหรับตรวจสอบว่ากำลัง focus หรือไม่
  final _focusNode = FocusNode();
  // Timer สำหรับ debounce
  Timer? _debounceTimer;
  // ควบคุมการแสดง dropdown
  bool _showDropdown = false;
  // Overlay entry สำหรับ dropdown
  OverlayEntry? _overlayEntry;
  // Layer link สำหรับ position dropdown
  final _layerLink = LayerLink();
  // กำลังอยู่ในโหมดแก้ไข/เปลี่ยนยา (กดที่ card แล้วจะเปิดช่องค้นหา แต่ยังเก็บยาเดิมไว้)
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // ฟัง focus changes
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    _removeOverlay();
    super.dispose();
  }

  /// จัดการเมื่อ focus เปลี่ยน
  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // เมื่อ focus: แสดง dropdown ถ้ามี results
      if (_textController.text.isNotEmpty || widget.searchResults.isNotEmpty) {
        _showOverlay();
      }
    } else {
      // เมื่อ unfocus: ซ่อน dropdown หลังจาก delay เล็กน้อย
      // (ให้ user กดเลือกได้ก่อน)
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  /// จัดการเมื่อ text เปลี่ยน
  void _onTextChanged(String value) {
    // Cancel timer เดิม
    _debounceTimer?.cancel();

    // ถ้าว่างเปล่า ให้ซ่อน dropdown
    if (value.isEmpty) {
      _removeOverlay();
      return;
    }

    // แสดง dropdown ทันที (จะแสดง loading)
    _showOverlay();

    // ตั้ง debounce timer
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (value.isNotEmpty) {
        widget.onSearch(value);
      }
    });
  }

  /// แสดง overlay dropdown
  void _showOverlay() {
    if (_overlayEntry != null || !mounted) return;

    _showDropdown = true;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  /// ลบ overlay
  void _removeOverlay() {
    _showDropdown = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Update overlay content
  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  /// สร้าง overlay entry
  OverlayEntry _createOverlayEntry() {
    // หา render box ของ TextField
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + AppSpacing.xs),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surface,
            child: _buildDropdownContent(),
          ),
        ),
      ),
    );
  }

  /// สร้างเนื้อหา dropdown
  Widget _buildDropdownContent() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // กำลัง loading
            if (widget.isSearching)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            // มีผลลัพธ์
            else if (widget.searchResults.isNotEmpty) ...[
              ...widget.searchResults.map((medicine) => _MedicineListTile(
                    medicine: medicine,
                    onTap: () {
                      widget.onSelect(medicine);
                      _textController.clear();
                      _removeOverlay();
                      _focusNode.unfocus();
                      // ออกจากโหมดแก้ไขเมื่อเลือกยาใหม่แล้ว
                      setState(() {
                        _isEditing = false;
                      });
                    },
                    // ปุ่ม edit - เปิดหน้าแก้ไขยาในฐานข้อมูล
                    onEdit: widget.onEditMedicine != null
                        ? () {
                            _removeOverlay();
                            _focusNode.unfocus();
                            widget.onEditMedicine!(medicine);
                          }
                        : null,
                  )),
              // Divider ก่อนปุ่มเพิ่มยาใหม่ (แสดงเฉพาะเมื่อมีปุ่ม)
              if (widget.showAddNewButton) const Divider(height: 1),
            ]
            // ไม่พบผลลัพธ์ (แต่มี query)
            else if (_textController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'ไม่พบยา "${_textController.text}"',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),

            // ปุ่มเพิ่มยาใหม่ (แสดงเฉพาะเมื่อ showAddNewButton = true)
            // สำหรับหัวหน้าเวรขึ้นไปเท่านั้น
            if (widget.showAddNewButton)
              InkWell(
                onTap: () {
                  final query = _textController.text;
                  _removeOverlay();
                  _focusNode.unfocus();
                  widget.onAddNew(query);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent1,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedAdd01,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'เพิ่มยาใหม่ลงฐานข้อมูล',
                        style: AppTypography.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(MedicineSearchDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // อัพเดท overlay เมื่อ search results เปลี่ยน
    // ใช้ addPostFrameCallback เพื่อหลีกเลี่ยง setState during build error
    if (oldWidget.searchResults != widget.searchResults ||
        oldWidget.isSearching != widget.isSearching) {
      if (_showDropdown) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _updateOverlay();
          }
        });
      }
    }
  }

  /// เริ่มโหมดแก้ไข - แสดง search field แต่ยังเก็บยาเดิมไว้
  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    // Focus ที่ search field และเปิด dropdown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  /// ยกเลิกโหมดแก้ไข - กลับไปแสดง card ยาเดิม
  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _textController.clear();
    });
    _removeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    // ถ้ามียาที่เลือกแล้ว และไม่ได้อยู่ในโหมดแก้ไข -> แสดง card
    if (widget.selectedMedicine != null && !_isEditing) {
      return _SelectedMedicineCard(
        medicine: widget.selectedMedicine!,
        // กดที่ card = เปิดโหมดแก้ไขเพื่อเปลี่ยนยา
        onTap: widget.enabled ? _startEditing : null,
      );
    }

    // แสดง search field (ไม่มียาเลือก หรือ กำลังอยู่ในโหมดแก้ไข)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field + ปุ่มยกเลิก (ถ้าอยู่ในโหมดแก้ไข)
        Row(
          children: [
            // Search field
            Expanded(
              child: CompositedTransformTarget(
                link: _layerLink,
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  onChanged: _onTextChanged,
                  decoration: InputDecoration(
                    hintText: _isEditing ? 'ค้นหายาใหม่...' : widget.hintText,
                    hintStyle: AppTypography.body.copyWith(
                      color: AppColors.secondaryText,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        color: AppColors.secondaryText,
                        size: 20,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    suffixIcon: _textController.text.isNotEmpty
                        ? IconButton(
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedCancel01,
                              color: AppColors.secondaryText,
                              size: 20,
                            ),
                            onPressed: () {
                              _textController.clear();
                              _removeOverlay();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.alternate, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  style: AppTypography.body,
                ),
              ),
            ),

            // ปุ่มยกเลิกการค้นหา (แสดงเฉพาะเมื่ออยู่ในโหมดแก้ไข)
            if (_isEditing) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: _cancelEditing,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: const Size(0, 48),
                ),
                child: Text(
                  'ยกเลิก',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ],
        ),

        // แสดงชื่อยาเดิม พร้อมปุ่ม edit (ถ้ามี callback)
        if (_isEditing && widget.selectedMedicine != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _CompactSelectedMedicineLabel(
            medicine: widget.selectedMedicine!,
            // ส่ง onEdit callback ไปให้กดแก้ไขยาได้
            onEdit: widget.onEditMedicine != null
                ? () => widget.onEditMedicine!(widget.selectedMedicine!)
                : null,
          ),
        ],
      ],
    );
  }
}

/// ListTile สำหรับแสดงรายการยาใน dropdown
class _MedicineListTile extends StatelessWidget {
  const _MedicineListTile({
    required this.medicine,
    required this.onTap,
    this.onEdit,
  });

  final MedDB medicine;
  final VoidCallback onTap;
  /// Callback เมื่อกดปุ่ม edit - เปิดหน้าแก้ไขยาในฐานข้อมูล
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Icon ยา
            // รูปยา - ใช้ IreneNetworkImage ที่มี timeout และ retry
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent1,
                borderRadius: BorderRadius.circular(8),
              ),
              child: medicine.hasAnyImage && medicine.frontFoiled != null
                  ? IreneNetworkImage(
                      imageUrl: medicine.frontFoiled!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      memCacheWidth: 100,
                      borderRadius: BorderRadius.circular(8),
                      compact: true,
                      errorPlaceholder: _buildDefaultIcon(),
                    )
                  : _buildDefaultIcon(),
            ),
            const SizedBox(width: AppSpacing.sm),
            // ข้อมูลยา
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ชื่อยา
                  Text(
                    medicine.displayName,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // รายละเอียด (strength, route, unit)
                  if (medicine.shortDescription.isNotEmpty)
                    Text(
                      medicine.shortDescription,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // ปุ่ม edit - เปิดหน้าแก้ไขยาในฐานข้อมูล
            if (onEdit != null) ...[
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedPencilEdit01,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Center(
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedMedicine01,
        color: AppColors.primary,
        size: 24,
      ),
    );
  }
}

/// Card แสดงยาที่เลือกแล้ว
/// กดที่ card เพื่อเปลี่ยนยาได้
class _SelectedMedicineCard extends StatelessWidget {
  const _SelectedMedicineCard({
    required this.medicine,
    this.onTap,
  });

  final MedDB medicine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // ใช้ InkWell เพื่อให้กดที่ทั้ง card ได้เพื่อเปลี่ยนยา
    return InkWell(
      onTap: onTap, // กดที่ card = เปิดโหมดแก้ไขเพื่อเปลี่ยนยา
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.accent1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Row(
          children: [
            // รูปยา - ใช้ IreneNetworkImage ที่มี timeout และ retry
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: medicine.hasAnyImage && medicine.frontFoiled != null
                  ? IreneNetworkImage(
                      imageUrl: medicine.frontFoiled!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      memCacheWidth: 100,
                      borderRadius: BorderRadius.circular(8),
                      compact: true,
                      errorPlaceholder: _buildDefaultIcon(),
                    )
                  : _buildDefaultIcon(),
            ),
            const SizedBox(width: AppSpacing.md),
            // ข้อมูลยา
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ชื่อยา
                  Text(
                    medicine.displayName,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // รายละเอียด
                  Text(
                    medicine.shortDescription.isNotEmpty
                        ? medicine.shortDescription
                        : '${medicine.route ?? 'รับประทาน'} • ${medicine.unit ?? 'เม็ด'}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.secondaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // ไอคอนเปลี่ยนยา
            if (onTap != null)
              HugeIcon(
                icon: HugeIcons.strokeRoundedExchange01,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Center(
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedMedicine01,
        color: AppColors.primary,
        size: 28,
      ),
    );
  }
}

/// แสดงชื่อยาเดิมแบบ label พร้อมปุ่ม edit
/// ใช้ตอนอยู่ในโหมดแก้ไข เพื่อบอกว่ายาเดิมคืออะไร และให้กดเข้าไปแก้ไขยาได้
class _CompactSelectedMedicineLabel extends StatelessWidget {
  const _CompactSelectedMedicineLabel({
    required this.medicine,
    this.onEdit,
  });

  final MedDB medicine;

  /// Callback เมื่อกดปุ่ม edit - เปิดหน้าแก้ไขยา
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // ไอคอนยา
          HugeIcon(
            icon: HugeIcons.strokeRoundedMedicine01,
            color: AppColors.primary,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.xs),
          // ชื่อยาเดิม
          Expanded(
            child: Text(
              'เดิม: ${medicine.displayName}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // ปุ่ม edit - เปิดหน้าแก้ไขยา
          if (onEdit != null) ...[
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: onEdit,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedPencilEdit01,
                color: AppColors.primary,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
