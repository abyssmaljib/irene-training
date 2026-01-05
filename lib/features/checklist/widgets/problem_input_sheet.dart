import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/input_fields.dart';

/// Bottom Sheet สำหรับกรอกหมายเหตุเมื่อแจ้งติดปัญหา
class ProblemInputSheet extends StatefulWidget {
  final Function(String description) onSubmit;

  const ProblemInputSheet({
    super.key,
    required this.onSubmit,
  });

  /// แสดง bottom sheet และ return description ที่กรอก (null ถ้า cancel)
  static Future<String?> show(BuildContext context) async {
    String? result;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProblemInputSheet(
        onSubmit: (description) {
          result = description;
          Navigator.pop(context);
        },
      ),
    );
    return result;
  }

  @override
  State<ProblemInputSheet> createState() => _ProblemInputSheetState();
}

class _ProblemInputSheetState extends State<ProblemInputSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Auto focus เมื่อเปิด sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    // คำนวณ padding สำหรับ keyboard
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AppSpacing.verticalGapMd,

              // Title
              Text(
                'แจ้งติดปัญหา',
                style: AppTypography.title.copyWith(
                  color: AppColors.error,
                ),
              ),
              AppSpacing.verticalGapSm,

              // Description
              Text(
                'กรุณาระบุรายละเอียดปัญหาที่พบ',
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              AppSpacing.verticalGapMd,

              // Text field
              AppTextField(
                controller: _controller,
                focusNode: _focusNode,
                hintText: 'เช่น ผู้พักอาศัยไม่อยู่ห้อง, อุปกรณ์ไม่พร้อม...',
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleSubmit(),
              ),
              AppSpacing.verticalGapLg,

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Iconsax.warning_2),
                  label: Text(
                    'แจ้งปัญหา',
                    style: AppTypography.button,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
