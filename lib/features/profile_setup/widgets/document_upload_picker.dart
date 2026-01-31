import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/network_image.dart';
import '../../board/widgets/image_picker_bar.dart';

/// ประเภทเอกสารที่สามารถ upload ได้
enum DocumentType {
  idCard, // สำเนาบัตรประชาชน
  certificate, // วุฒิบัตร/ประกาศนียบัตร
  resume, // Resume
  bankBook, // หน้าบุ๊คแบงค์
}

/// Extension สำหรับ DocumentType
extension DocumentTypeExtension on DocumentType {
  /// Storage folder path สำหรับแต่ละประเภท
  String get folderName {
    switch (this) {
      case DocumentType.idCard:
        return 'id-card';
      case DocumentType.certificate:
        return 'certificate';
      case DocumentType.resume:
        return 'resume';
      case DocumentType.bankBook:
        return 'bank-book';
    }
  }

  /// Label ภาษาไทย
  String get label {
    switch (this) {
      case DocumentType.idCard:
        return 'สำเนาบัตรประชาชน';
      case DocumentType.certificate:
        return 'วุฒิบัตร/ประกาศนียบัตร';
      case DocumentType.resume:
        return 'Resume';
      case DocumentType.bankBook:
        return 'หน้าบุ๊คแบงค์';
    }
  }

  /// คำอธิบายเพิ่มเติม
  String get description {
    switch (this) {
      case DocumentType.idCard:
        return 'เฉพาะด้านหน้า เซ็นสำเนาถูกต้อง';
      case DocumentType.certificate:
        return 'วุฒิบัตรด้านการบริบาล (ถ้ามี)';
      case DocumentType.resume:
        return 'ไฟล์ประวัติการทำงาน (ถ้ามี)';
      case DocumentType.bankBook:
        return 'หน้าแรกที่แสดงเลขบัญชี';
    }
  }

  /// Icon ที่แสดง
  dynamic get icon {
    switch (this) {
      case DocumentType.idCard:
        return HugeIcons.strokeRoundedIdentityCard;
      case DocumentType.certificate:
        return HugeIcons.strokeRoundedCertificate01;
      case DocumentType.resume:
        return HugeIcons.strokeRoundedFile01;
      case DocumentType.bankBook:
        return HugeIcons.strokeRoundedBank;
    }
  }
}

/// Widget สำหรับ upload เอกสารต่างๆ
/// แสดงเป็น card พร้อม thumbnail preview
class DocumentUploadPicker extends StatelessWidget {
  /// ประเภทเอกสาร
  final DocumentType documentType;

  /// URL รูปปัจจุบัน (จาก network)
  final String? currentDocumentUrl;

  /// ไฟล์ที่เลือกใหม่ (ยังไม่ upload)
  final File? selectedFile;

  /// Callback เมื่อเลือกไฟล์ใหม่
  final ValueChanged<File?> onFileSelected;

  /// กำลัง upload อยู่หรือไม่
  final bool isUploading;

  /// แสดง required asterisk (*) หรือไม่
  final bool isRequired;

  /// มี error หรือไม่
  final bool hasError;

  /// Error message
  final String? errorText;

  const DocumentUploadPicker({
    super.key,
    required this.documentType,
    this.currentDocumentUrl,
    this.selectedFile,
    required this.onFileSelected,
    this.isUploading = false,
    this.isRequired = false,
    this.hasError = false,
    this.errorText,
  });

  /// ตรวจสอบว่ามีเอกสารแล้วหรือยัง
  bool get hasDocument =>
      selectedFile != null ||
      (currentDocumentUrl != null && currentDocumentUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Card สำหรับ upload
        GestureDetector(
          onTap: isUploading ? null : () => _showPicker(context),
          child: Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: AppColors.primaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError
                    ? AppColors.error
                    : (hasDocument ? AppColors.success : AppColors.alternate),
                width: hasError ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Thumbnail / Placeholder
                _buildThumbnail(),
                AppSpacing.horizontalGapMd,

                // Info section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label + required
                      Row(
                        children: [
                          Text(
                            documentType.label,
                            style: AppTypography.label.copyWith(
                              color: hasError
                                  ? AppColors.error
                                  : AppColors.primaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isRequired)
                            Text(
                              ' *',
                              style: AppTypography.label.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Description
                      Text(
                        documentType.description,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),

                      // Status
                      const SizedBox(height: 4),
                      _buildStatus(),
                    ],
                  ),
                ),

                // Action icon
                if (isUploading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  HugeIcon(
                    icon: hasDocument
                        ? HugeIcons.strokeRoundedEdit02
                        : HugeIcons.strokeRoundedUpload04,
                    color: hasDocument
                        ? AppColors.secondaryText
                        : AppColors.primary,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),

        // Error text
        if (errorText != null && hasError) ...[
          AppSpacing.verticalGapXs,
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlertCircle,
                color: AppColors.error,
                size: 14,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// สร้าง thumbnail preview
  Widget _buildThumbnail() {
    const size = 60.0;

    // ถ้ามีไฟล์ที่เลือกใหม่
    if (selectedFile != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            selectedFile!,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // ถ้ามี URL เดิม
    if (currentDocumentUrl != null && currentDocumentUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: IreneNetworkImage(
            imageUrl: currentDocumentUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            memCacheWidth: (size * 2).toInt(),
          ),
        ),
      );
    }

    // Placeholder
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasError ? AppColors.error : AppColors.alternate,
        ),
      ),
      child: Center(
        child: HugeIcon(
          icon: documentType.icon,
          color: hasError ? AppColors.error : AppColors.secondaryText,
          size: 28,
        ),
      ),
    );
  }

  /// สร้าง status badge
  Widget _buildStatus() {
    if (hasDocument) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            color: AppColors.success,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            'อัพโหลดแล้ว',
            style: AppTypography.caption.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedUpload04,
          color: AppColors.primary,
          size: 14,
        ),
        const SizedBox(width: 4),
        Text(
          'แตะเพื่ออัพโหลด',
          style: AppTypography.caption.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// แสดง bottom sheet เลือกรูป
  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _DocumentPickerSheet(
        documentType: documentType,
        onFileSelected: (file) {
          Navigator.pop(context);
          onFileSelected(file);
        },
        onRemoveFile: hasDocument
            ? () {
                Navigator.pop(context);
                onFileSelected(null);
              }
            : null,
      ),
    );
  }
}

/// Bottom sheet สำหรับเลือกไฟล์
class _DocumentPickerSheet extends StatelessWidget {
  final DocumentType documentType;
  final ValueChanged<File?> onFileSelected;
  final VoidCallback? onRemoveFile;

  const _DocumentPickerSheet({
    required this.documentType,
    required this.onFileSelected,
    this.onRemoveFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.alternate,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AppSpacing.verticalGapMd,

              // Title
              Text(
                'อัพโหลด${documentType.label}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              AppSpacing.verticalGapLg,

              // Camera option
              _buildOption(
                icon: HugeIcons.strokeRoundedCamera01,
                label: 'ถ่ายรูป',
                onTap: () async {
                  final file = await ImagePickerHelper.pickFromCamera();
                  if (file != null) {
                    onFileSelected(file);
                  }
                },
              ),
              AppSpacing.verticalGapSm,

              // Gallery option
              _buildOption(
                icon: HugeIcons.strokeRoundedImage01,
                label: 'เลือกจากแกลเลอรี่',
                onTap: () async {
                  final file = await ImagePickerHelper.pickSingleFromGallery();
                  if (file != null) {
                    onFileSelected(file);
                  }
                },
              ),

              // Remove option (ถ้ามีไฟล์อยู่)
              if (onRemoveFile != null) ...[
                AppSpacing.verticalGapSm,
                _buildOption(
                  icon: HugeIcons.strokeRoundedDelete02,
                  label: 'ลบเอกสาร',
                  onTap: onRemoveFile!,
                  isDestructive: true,
                ),
              ],

              AppSpacing.verticalGapMd,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : AppColors.primaryText;

    return Material(
      color: AppColors.accent1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
