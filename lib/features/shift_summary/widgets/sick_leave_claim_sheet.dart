import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../services/shift_summary_service.dart';

/// Bottom sheet สำหรับแนบหลักฐานการลาป่วย
class SickLeaveClaimSheet extends ConsumerStatefulWidget {
  final int specialRecordId;
  final DateTime date;

  const SickLeaveClaimSheet({
    super.key,
    required this.specialRecordId,
    required this.date,
  });

  @override
  ConsumerState<SickLeaveClaimSheet> createState() => _SickLeaveClaimSheetState();
}

class _SickLeaveClaimSheetState extends ConsumerState<SickLeaveClaimSheet> {
  final _reasonController = TextEditingController();
  Uint8List? _fileBytes;
  String? _fileName;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thaiMonths = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    // แสดงปี ค.ศ. (Christian Era)
    final dateStr = '${widget.date.day} ${thaiMonths[widget.date.month]} ${widget.date.year}';

    return Container(
      padding: EdgeInsets.only(
        // ใช้ viewInsetsOf แทน .of().viewInsets เพื่อลดการ rebuild ตอน keyboard animation
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'แนบหลักฐานลาป่วย',
                    style: AppTypography.heading3,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'วันที่ $dateStr',
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              SizedBox(height: AppSpacing.lg),

              // File picker
              _buildFilePicker(),
              SizedBox(height: AppSpacing.md),

              // Reason text field
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'เหตุผลการลาป่วย',
                  hintText: 'เช่น ไข้หวัด, ปวดท้อง',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                maxLines: 3,
              ),
              SizedBox(height: AppSpacing.lg),

              // Error message
              if (_error != null) ...[
                Text(
                  _error!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.error,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
              ],

              // Submit button
              ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        'ยืนยันการลาป่วย',
                        style: AppTypography.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              // Approve button for shift leader and above
              // Hidden for now - leaders can't access this screen for other users
              // if (canApprove) ...[
              //   SizedBox(height: AppSpacing.sm),
              //   OutlinedButton(
              //     onPressed: _isLoading ? null : _approveByLeader,
              //     style: OutlinedButton.styleFrom(
              //       foregroundColor: AppColors.primary,
              //       padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              //       side: BorderSide(color: AppColors.primary),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(8),
              //       ),
              //     ),
              //     child: Text(
              //       'อนุญาตโดยหัวหน้างาน',
              //       style: AppTypography.body.copyWith(
              //         color: AppColors.primary,
              //         fontWeight: FontWeight.w600,
              //       ),
              //     ),
              //   ),
              // ],
              SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _fileBytes != null ? AppColors.primary : AppColors.alternate,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            if (_fileBytes != null && _isImageFile) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _fileBytes!,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: _fileBytes != null ? HugeIcons.strokeRoundedCheckmarkCircle02 : HugeIcons.strokeRoundedFileUpload,
                  color: _fileBytes != null
                      ? AppColors.success
                      : AppColors.secondaryText,
                ),
                SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    _fileName ?? 'แนบใบรับรองแพทย์ (รูปภาพ/PDF)',
                    style: AppTypography.body.copyWith(
                      color: _fileBytes != null
                          ? AppColors.primaryText
                          : AppColors.secondaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _isImageFile {
    if (_fileName == null) return false;
    final ext = _fileName!.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif');
  }

  bool get _canSubmit =>
      _fileBytes != null &&
      _reasonController.text.trim().isNotEmpty &&
      !_isLoading;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _fileBytes = file.bytes;
            _fileName = file.name;
            _error = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'ไม่สามารถเลือกไฟล์ได้';
      });
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ShiftSummaryService.instance;

      // Upload file
      final url = await service.uploadSickEvidenceFromBytes(
        bytes: _fileBytes!,
        fileName: _fileName!,
      );

      if (url == null) {
        throw Exception('ไม่สามารถอัปโหลดไฟล์ได้');
      }

      // Update record
      final success = await service.claimSickLeave(
        specialRecordId: widget.specialRecordId,
        sickEvident: url,
        sickReason: _reasonController.text.trim(),
      );

      if (!success) {
        throw Exception('ไม่สามารถบันทึกข้อมูลได้');
      }

      if (mounted) {
        Navigator.pop(context, true);
        AppToast.success(context, 'บันทึกการลาป่วยเรียบร้อย');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Hidden for now - leaders can't access this screen for other users
  // /// Approve sick leave by shift leader (without requiring evidence upload)
  // Future<void> _approveByLeader() async {
  //   // Require reason but not file
  //   if (_reasonController.text.trim().isEmpty) {
  //     setState(() {
  //       _error = 'กรุณากรอกเหตุผลการลาป่วย';
  //     });
  //     return;
  //   }

  //   setState(() {
  //     _isLoading = true;
  //     _error = null;
  //   });

  //   try {
  //     final service = ShiftSummaryService.instance;

  //     // Use placeholder image for leader approval
  //     const approvalImageUrl = 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/test-5uhwpj/assets/3kpavktrbeol/%E0%B9%80%E0%B8%81%E0%B9%88%E0%B8%87%E0%B8%A1%E0%B8%B2%E0%B8%81.png';

  //     final success = await service.claimSickLeave(
  //       specialRecordId: widget.specialRecordId,
  //       sickEvident: approvalImageUrl,
  //       sickReason: _reasonController.text.trim(),
  //     );

  //     if (!success) {
  //       throw Exception('ไม่สามารถบันทึกข้อมูลได้');
  //     }

  //     if (mounted) {
  //       Navigator.pop(context, true);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('อนุญาตการลาป่วยเรียบร้อย'),
  //           backgroundColor: AppColors.success,
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _error = e.toString();
  //       _isLoading = false;
  //     });
  //   }
  // }
}
