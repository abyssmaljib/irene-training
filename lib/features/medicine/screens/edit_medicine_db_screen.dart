import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/widgets/success_popup.dart';
import '../providers/create_medicine_db_provider.dart';
import '../providers/edit_medicine_db_form_provider.dart';
import '../services/medicine_service.dart';

/// หน้าแก้ไขยาในฐานข้อมูล (med_DB)
///
/// Features:
/// - Pre-populate ค่าจาก MedDB ที่มีอยู่
/// - แก้ไขข้อมูลยา (ชื่อ, ขนาด, วิธีให้, หมวดหมู่, รูปภาพ)
/// - ปุ่ม "สร้างซ้ำ" สำหรับ copy ยาพร้อมเติม "(copy)" ต่อท้ายชื่อ
class EditMedicineDBScreen extends ConsumerStatefulWidget {
  const EditMedicineDBScreen({
    super.key,
    required this.medDbId,
  });

  /// ID ของยาที่ต้องการแก้ไข
  final int medDbId;

  @override
  ConsumerState<EditMedicineDBScreen> createState() =>
      _EditMedicineDBScreenState();
}

class _EditMedicineDBScreenState extends ConsumerState<EditMedicineDBScreen> {
  // Controllers สำหรับ text fields
  final _genericNameController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _strengthController = TextEditingController();
  final _routeController = TextEditingController();
  final _unitController = TextEditingController();
  final _groupController = TextEditingController();
  final _infoController = TextEditingController();
  final _atcLevel3Controller = TextEditingController();

  // Image picker
  final _imagePicker = ImagePicker();

  // Form key สำหรับ validation
  final _formKey = GlobalKey<FormState>();

  // Flag เพื่อ sync controller กับ state ครั้งแรก
  bool _isInitialized = false;

  @override
  void dispose() {
    _genericNameController.dispose();
    _brandNameController.dispose();
    _strengthController.dispose();
    _routeController.dispose();
    _unitController.dispose();
    _groupController.dispose();
    _infoController.dispose();
    _atcLevel3Controller.dispose();
    super.dispose();
  }

  /// Sync controllers กับ state (เรียกครั้งเดียวตอน load เสร็จ)
  void _syncControllersWithState(dynamic state) {
    if (_isInitialized) return;
    _isInitialized = true;

    _genericNameController.text = state.genericName;
    _brandNameController.text = state.brandName;
    _strengthController.text = state.strength;
    _routeController.text = state.route;
    _unitController.text = state.unit;
    _groupController.text = state.group;
    _infoController.text = state.info;
    _atcLevel3Controller.text = state.atcLevel3;
  }

  /// เลือกรูปจาก Gallery หรือ Camera
  Future<void> _pickImage(String imageType) async {
    // แสดง bottom sheet ให้เลือก source
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedCamera01,
                color: AppColors.primary,
                size: 24,
              ),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                color: AppColors.primary,
                size: 24,
              ),
              title: const Text('เลือกจากแกลเลอรี่'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      // Set uploading state
      final notifier =
          ref.read(editMedicineDBFormProvider(widget.medDbId).notifier);
      switch (imageType) {
        case 'frontFoiled':
          notifier.setUploading(frontFoiled: true);
          break;
        case 'backFoiled':
          notifier.setUploading(backFoiled: true);
          break;
        case 'frontNude':
          notifier.setUploading(frontNude: true);
          break;
        case 'backNude':
          notifier.setUploading(backNude: true);
          break;
      }

      // Upload to Supabase
      debugPrint('[EditMedicineDB] Uploading image: ${pickedFile.path}');
      final url = await MedicineService.instance.uploadMedicineImage(
        File(pickedFile.path),
        imageType,
      );
      debugPrint('[EditMedicineDB] Upload result URL: $url');

      // ตรวจสอบว่า upload สำเร็จหรือไม่
      if (url == null) {
        // Upload fail - แสดง error และ reset uploading state
        switch (imageType) {
          case 'frontFoiled':
            notifier.setUploading(frontFoiled: false);
            break;
          case 'backFoiled':
            notifier.setUploading(backFoiled: false);
            break;
          case 'frontNude':
            notifier.setUploading(frontNude: false);
            break;
          case 'backNude':
            notifier.setUploading(backNude: false);
            break;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไม่สามารถ upload รูปได้ กรุณาลองใหม่'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Set URL (upload สำเร็จ)
      switch (imageType) {
        case 'frontFoiled':
          notifier.setFrontFoiledUrl(url);
          break;
        case 'backFoiled':
          notifier.setBackFoiledUrl(url);
          break;
        case 'frontNude':
          notifier.setFrontNudeUrl(url);
          break;
        case 'backNude':
          notifier.setBackNudeUrl(url);
          break;
      }
    } catch (e) {
      debugPrint('[EditMedicineDB] Error picking/uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถ upload รูปได้: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// บันทึกการแก้ไข
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier =
        ref.read(editMedicineDBFormProvider(widget.medDbId).notifier);
    final result = await notifier.submit();

    if (result != null && mounted) {
      // สำเร็จ - แสดง popup แล้วกลับ
      await SuccessPopup.show(context, emoji: '💊', message: 'บันทึกสำเร็จ');
      if (mounted) Navigator.pop(context, true);
    }
  }

  /// สร้างซ้ำ (Duplicate)
  Future<void> _duplicate() async {
    final notifier =
        ref.read(editMedicineDBFormProvider(widget.medDbId).notifier);
    final result = await notifier.duplicate();

    if (result != null && mounted) {
      // สำเร็จ - แสดง popup แล้วกลับพร้อมส่ง MedDB ใหม่
      await SuccessPopup.show(context, emoji: '📋', message: 'สร้างซ้ำสำเร็จ');
      if (mounted) Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ฟัง form state
    final formState = ref.watch(editMedicineDBFormProvider(widget.medDbId));
    // ฟัง ATC Level 1 list
    final atcLevel1List = ref.watch(atcLevel1ListProvider);

    return Scaffold(
      // ใช้ IreneSecondaryAppBar แทน AppBar เพื่อ consistency ทั้งแอป
      // ใช้ Cancel icon เพราะเป็นหน้า edit form (ปิดโดยไม่บันทึก)
      appBar: IreneSecondaryAppBar(
        title: 'แก้ไขยาในฐานข้อมูล',
        leadingIcon: HugeIcons.strokeRoundedCancel01,
      ),
      body: formState.when(
        // กำลังโหลด
        loading: () => const Center(child: CircularProgressIndicator()),
        // Error
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'เกิดข้อผิดพลาด',
                style: AppTypography.heading3,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                error.toString(),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              // ปุ่ม retry
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(editMedicineDBFormProvider(widget.medDbId).notifier)
                    .reload(),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  color: AppColors.primary,
                  size: 20,
                ),
                label: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
        // โหลดเสร็จ - แสดง form
        data: (state) {
          // Sync controllers ครั้งแรก
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncControllersWithState(state);
          });

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==========================================
                  // Section 1: ข้อมูลพื้นฐาน
                  // ==========================================
                  _SectionHeader(
                    icon: HugeIcons.strokeRoundedMedicine01,
                    title: 'ข้อมูลยา',
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Generic Name
                  _InputField(
                    label: 'ชื่อสามัญ (Generic Name)',
                    hint: 'เช่น Paracetamol',
                    controller: _genericNameController,
                    onChanged: (value) => ref
                        .read(editMedicineDBFormProvider(widget.medDbId)
                            .notifier)
                        .setGenericName(value),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Brand Name
                  _InputField(
                    label: 'ชื่อการค้า (Brand Name)',
                    hint: 'เช่น Tylenol',
                    controller: _brandNameController,
                    onChanged: (value) => ref
                        .read(editMedicineDBFormProvider(widget.medDbId)
                            .notifier)
                        .setBrandName(value),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Strength
                  _InputField(
                    label: 'ขนาด/ความแรง',
                    hint: 'เช่น 500 mg',
                    controller: _strengthController,
                    onChanged: (value) => ref
                        .read(editMedicineDBFormProvider(widget.medDbId)
                            .notifier)
                        .setStrength(value),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Route & Unit (Row)
                  Row(
                    children: [
                      Expanded(
                        child: _InputField(
                          label: 'วิธีให้ยา',
                          hint: 'เช่น รับประทาน',
                          controller: _routeController,
                          onChanged: (value) => ref
                              .read(editMedicineDBFormProvider(widget.medDbId)
                                  .notifier)
                              .setRoute(value),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _InputField(
                          label: 'หน่วย',
                          hint: 'เช่น เม็ด',
                          controller: _unitController,
                          onChanged: (value) => ref
                              .read(editMedicineDBFormProvider(widget.medDbId)
                                  .notifier)
                              .setUnit(value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Group
                  _InputField(
                    label: 'กลุ่มยา',
                    hint: 'เช่น ยาแก้ปวด',
                    controller: _groupController,
                    onChanged: (value) => ref
                        .read(editMedicineDBFormProvider(widget.medDbId)
                            .notifier)
                        .setGroup(value),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Info
                  _InputField(
                    label: 'รายละเอียดเพิ่มเติม',
                    hint: 'ข้อมูลอื่นๆ เกี่ยวกับยา',
                    controller: _infoController,
                    maxLines: 3,
                    onChanged: (value) => ref
                        .read(editMedicineDBFormProvider(widget.medDbId)
                            .notifier)
                        .setInfo(value),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ==========================================
                  // Section 2: ATC Classification
                  // ==========================================
                  _SectionHeader(
                    icon: HugeIcons.strokeRoundedFolder01,
                    title: 'การจัดหมวดหมู่ (ATC)',
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ATC Level 1 Dropdown
                  atcLevel1List.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text(
                      'ไม่สามารถโหลดหมวดหมู่ได้: $error',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    data: (level1List) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Level 1 Dropdown
                        Text(
                          'หมวดหลัก (Level 1)',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (level1List.isEmpty)
                          Text(
                            'ไม่พบข้อมูลหมวดหมู่ยาในระบบ',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          )
                        else ...[
                          DropdownButtonFormField<String>(
                            key: ValueKey('atc1_${state.atcLevel1Code}'),
                            initialValue: state.atcLevel1Code,
                            decoration: InputDecoration(
                              hintText: 'เลือกหมวดหลัก',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.alternate,
                                  width: 1,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                            items: level1List.map((level1) {
                              return DropdownMenuItem<String>(
                                value: level1.code,
                                child: Text(
                                  level1.displayName,
                                  style: AppTypography.body,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) => ref
                                .read(editMedicineDBFormProvider(widget.medDbId)
                                    .notifier)
                                .setAtcLevel1(value),
                            isExpanded: true,
                          ),

                          // Level 2 Dropdown (แสดงเมื่อเลือก Level 1)
                          if (state.atcLevel1Code != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            _buildAtcLevel2Dropdown(state.atcLevel1Code!),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ATC Level 3 (free text)
                  _InputField(
                    label: 'กลุ่มย่อย (Level 3 - ถ้ามี)',
                    hint: 'ระบุกลุ่มย่อยเพิ่มเติม',
                    controller: _atcLevel3Controller,
                    onChanged: (value) => ref
                        .read(editMedicineDBFormProvider(widget.medDbId)
                            .notifier)
                        .setAtcLevel3(value),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ==========================================
                  // Section 3: รูปภาพ
                  // ==========================================
                  _SectionHeader(
                    icon: HugeIcons.strokeRoundedImage01,
                    title: 'รูปยา',
                    subtitle: 'ไม่บังคับ',
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // รูปภาพ 4 รูป
                  Row(
                    children: [
                      Expanded(
                        child: _ImageUploadBox(
                          label: 'หน้า (ฟอยล์)',
                          imageUrl: state.effectiveFrontFoiledUrl,
                          isUploading: state.isUploadingFrontFoiled,
                          onTap: () => _pickImage('frontFoiled'),
                          onClear: state.effectiveFrontFoiledUrl != null
                              ? () => ref
                                  .read(editMedicineDBFormProvider(
                                          widget.medDbId)
                                      .notifier)
                                  .clearImage('frontFoiled')
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ImageUploadBox(
                          label: 'หลัง (ฟอยล์)',
                          imageUrl: state.effectiveBackFoiledUrl,
                          isUploading: state.isUploadingBackFoiled,
                          onTap: () => _pickImage('backFoiled'),
                          onClear: state.effectiveBackFoiledUrl != null
                              ? () => ref
                                  .read(editMedicineDBFormProvider(
                                          widget.medDbId)
                                      .notifier)
                                  .clearImage('backFoiled')
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _ImageUploadBox(
                          label: 'หน้า (เปลือย)',
                          imageUrl: state.effectiveFrontNudeUrl,
                          isUploading: state.isUploadingFrontNude,
                          onTap: () => _pickImage('frontNude'),
                          onClear: state.effectiveFrontNudeUrl != null
                              ? () => ref
                                  .read(editMedicineDBFormProvider(
                                          widget.medDbId)
                                      .notifier)
                                  .clearImage('frontNude')
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ImageUploadBox(
                          label: 'หลัง (เปลือย)',
                          imageUrl: state.effectiveBackNudeUrl,
                          isUploading: state.isUploadingBackNude,
                          onTap: () => _pickImage('backNude'),
                          onClear: state.effectiveBackNudeUrl != null
                              ? () => ref
                                  .read(editMedicineDBFormProvider(
                                          widget.medDbId)
                                      .notifier)
                                  .clearImage('backNude')
                              : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ==========================================
                  // Error message + ปุ่ม
                  // ==========================================

                  // Error message (ถ้ามี)
                  if (state.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.tagFailedBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedAlert02,
                            color: AppColors.tagFailedText,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.tagFailedText,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedCancel01,
                              color: AppColors.tagFailedText,
                              size: 16,
                            ),
                            onPressed: () => ref
                                .read(editMedicineDBFormProvider(widget.medDbId)
                                    .notifier)
                                .clearError(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // ปุ่ม Row: สร้างซ้ำ (Secondary) + บันทึก (Primary)
                  Row(
                    children: [
                      // ปุ่มสร้างซ้ำ (Secondary - Outlined ตาม design system)
                      Expanded(
                        child: SecondaryButton(
                          text: state.isDuplicating ? 'กำลังสร้าง...' : 'สร้างซ้ำ',
                          onPressed: state.isLoading ||
                                  state.isUploading ||
                                  state.isDuplicating
                              ? null
                              : _duplicate,
                          isLoading: state.isDuplicating,
                          icon: HugeIcons.strokeRoundedCopy01,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // ปุ่มบันทึก (Primary)
                      Expanded(
                        child: PrimaryButton(
                          text: 'บันทึก',
                          onPressed: state.isLoading ||
                                  state.isUploading ||
                                  state.isDuplicating
                              ? null
                              : _submit,
                          isLoading: state.isLoading,
                          icon: HugeIcons.strokeRoundedFloppyDisk,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// สร้าง ATC Level 2 Dropdown
  Widget _buildAtcLevel2Dropdown(String level1Code) {
    final level2ListAsync = ref.watch(atcLevel2ListProvider(level1Code));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'หมวดย่อย (Level 2)',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        level2ListAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => Text(
            'ไม่สามารถโหลดหมวดย่อยได้',
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
          data: (level2List) {
            final formState =
                ref.watch(editMedicineDBFormProvider(widget.medDbId)).value;
            return DropdownButtonFormField<String>(
              key: ValueKey('atc2_${formState?.atcLevel2Code}'),
              initialValue: formState?.atcLevel2Code,
              decoration: InputDecoration(
                hintText: 'เลือกหมวดย่อย',
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              items: level2List.map((level2) {
                return DropdownMenuItem<String>(
                  value: level2.code,
                  child: Text(
                    level2.displayName,
                    style: AppTypography.body,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) => ref
                  .read(editMedicineDBFormProvider(widget.medDbId).notifier)
                  .setAtcLevel2(value),
              isExpanded: true,
            );
          },
        ),
      ],
    );
  }
}

// ==========================================
// Helper Widgets (คล้ายกับ CreateMedicineDBScreen)
// ==========================================

/// Section Header
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final dynamic icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(
          icon: icon,
          color: AppColors.primary,
          size: 24,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: AppTypography.heading3.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            '($subtitle)',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ],
    );
  }
}

/// Input Field
class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.body.copyWith(
              color: AppColors.secondaryText.withValues(alpha: 0.5),
            ),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          style: AppTypography.body,
        ),
      ],
    );
  }
}

/// Image Upload Box with optional clear button
class _ImageUploadBox extends StatelessWidget {
  const _ImageUploadBox({
    required this.label,
    required this.onTap,
    this.imageUrl,
    this.isUploading = false,
    this.onClear,
  });

  final String label;
  final String? imageUrl;
  final bool isUploading;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    // ใช้ AspectRatio 1:1 เพื่อให้รูปเป็นจตุรัส ไม่ว่าจอจะกว้างแค่ไหน
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTap: isUploading ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: imageUrl != null ? AppColors.primary : AppColors.alternate,
              width: imageUrl != null ? 2 : 1,
            ),
          ),
          child: isUploading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // รูปยา - ใช้ IreneNetworkImage ที่มี timeout และ retry
                          IreneNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                            compact: true,
                            errorPlaceholder: _buildPlaceholder(),
                          ),
                          // Label overlay
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2,
                                horizontal: 4,
                              ),
                              color: Colors.black54,
                              child: Text(
                                label,
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // Clear button (ถ้ามี)
                          if (onClear != null)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: onClear,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedCancel01,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedAdd01,
          color: AppColors.secondaryText,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
