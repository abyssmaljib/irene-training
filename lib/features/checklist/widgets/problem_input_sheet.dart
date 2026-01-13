import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/input_fields.dart';
import '../models/problem_type.dart';
import '../models/task_log.dart';
import '../services/task_service.dart';
import 'resolution_history_section.dart';

/// Bottom Sheet สำหรับเลือกประเภทปัญหาและกรอกหมายเหตุเมื่อแจ้งติดปัญหา
/// UI แสดง Chips สำหรับเลือกประเภท และ TextField สำหรับรายละเอียดเพิ่มเติม
///
/// ถ้าส่ง [task] มาด้วย จะแสดง "ประวัติการแก้ปัญหา" ก่อนเลือกประเภทปัญหา
/// เพื่อให้ user เห็นว่าปัญหาลักษณะนี้เคยแก้อย่างไร
class ProblemInputSheet extends StatefulWidget {
  // callback เมื่อ user กด submit
  final Function(ProblemData data) onSubmit;

  // Task ที่กำลังแจ้งปัญหา (optional) - ใช้สำหรับดึงประวัติการแก้ปัญหา
  final TaskLog? task;

  const ProblemInputSheet({
    super.key,
    required this.onSubmit,
    this.task,
  });

  /// แสดง bottom sheet และ return ProblemData ที่เลือก (null ถ้า cancel)
  /// [task] - Task ที่กำลังแจ้งปัญหา (optional) - ใช้สำหรับดึงประวัติการแก้ปัญหา
  static Future<ProblemData?> show(BuildContext context, {TaskLog? task}) async {
    ProblemData? result;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProblemInputSheet(
        task: task,
        onSubmit: (data) {
          result = data;
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
  // Controller สำหรับ TextField รายละเอียดเพิ่มเติม
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  // State สำหรับ Chip ที่เลือก
  ProblemType? _selectedType;

  // State สำหรับ loading
  bool _isSubmitting = false;

  // State สำหรับ resolution history
  // ใช้ Future เพื่อให้โหลดแบบ non-blocking ไม่ให้ค้าง
  Future<List<TaskLog>>? _resolutionHistoryFuture;

  @override
  void initState() {
    super.initState();
    // ดึง resolution history ถ้ามี task
    // ทำใน initState เพื่อให้โหลดตั้งแต่เปิด sheet
    if (widget.task != null) {
      _loadResolutionHistory();
    }
  }

  /// โหลดประวัติการแก้ปัญหา (non-blocking)
  void _loadResolutionHistory() {
    _resolutionHistoryFuture = TaskService.instance.getResolutionHistory(
      taskId: widget.task?.taskId,
      residentId: widget.task?.residentId,
      taskType: widget.task?.taskType,
      limit: 5, // แสดงแค่ 5 รายการล่าสุด
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// ตรวจสอบว่าสามารถ submit ได้หรือไม่
  /// - ต้องเลือกประเภทปัญหา
  /// - ถ้าเลือก "อื่นๆ" ต้องกรอกรายละเอียด
  bool get _canSubmit {
    if (_selectedType == null) return false;
    if (_selectedType!.requiresDescription) {
      return _controller.text.trim().isNotEmpty;
    }
    return true;
  }

  void _handleSubmit() {
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);

    // สร้าง ProblemData และส่งกลับ
    final data = ProblemData(
      type: _selectedType!,
      description: _controller.text.trim().isEmpty
          ? null
          : _controller.text.trim(),
    );

    widget.onSubmit(data);
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
        child: SingleChildScrollView(
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
                  'กรุณาเลือกประเภทปัญหา',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                AppSpacing.verticalGapMd,

                // Resolution History Section (แสดงก่อนเลือกประเภท)
                // ใช้ FutureBuilder เพื่อโหลดแบบ non-blocking
                if (_resolutionHistoryFuture != null)
                  FutureBuilder<List<TaskLog>>(
                    future: _resolutionHistoryFuture,
                    builder: (context, snapshot) {
                      return ResolutionHistorySection(
                        resolutionHistory: snapshot.data ?? [],
                        isLoading: snapshot.connectionState == ConnectionState.waiting,
                      );
                    },
                  ),

                // Problem Type Chips - ใช้ Wrap เพื่อให้ chips ขึ้นบรรทัดใหม่อัตโนมัติ
                _buildProblemTypeChips(),
                AppSpacing.verticalGapMd,

                // Text field สำหรับรายละเอียดเพิ่มเติม
                // แสดงเฉพาะเมื่อเลือกประเภทแล้ว
                if (_selectedType != null) ...[
                  Text(
                    _selectedType!.requiresDescription
                        ? 'กรุณาระบุรายละเอียด *'
                        : 'รายละเอียดเพิ่มเติม (ไม่บังคับ)',
                    style: AppTypography.bodySmall.copyWith(
                      color: _selectedType!.requiresDescription
                          ? AppColors.error
                          : AppColors.secondaryText,
                    ),
                  ),
                  AppSpacing.verticalGapSm,
                  AppTextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    hintText: 'รายละเอียดปัญหาที่พบ...',
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleSubmit(),
                    onChanged: (_) => setState(() {}),
                  ),
                  AppSpacing.verticalGapLg,
                ],

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    // ปิด button ถ้ายังไม่เลือกประเภท หรือ "อื่นๆ" แต่ไม่กรอก
                    onPressed: (_isSubmitting || !_canSubmit)
                        ? null
                        : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.error.withValues(alpha: 0.5),
                      disabledForegroundColor:
                          Colors.white.withValues(alpha: 0.7),
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
                        : HugeIcon(
                            icon: HugeIcons.strokeRoundedAlert02,
                            color: Colors.white, // ต้องระบุสีให้ icon
                          ),
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
      ),
    );
  }

  /// สร้าง Chips สำหรับเลือกประเภทปัญหา
  Widget _buildProblemTypeChips() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: ProblemType.values.map((type) {
        final isSelected = _selectedType == type;

        return ChoiceChip(
          // แสดง emoji + label
          label: Text(
            '${type.emoji} ${type.label}',
            style: AppTypography.bodySmall.copyWith(
              color: isSelected ? Colors.white : AppColors.primaryText,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedType = selected ? type : null;
              // ถ้าเลือก "อื่นๆ" ให้ focus ที่ text field
              if (selected && type == ProblemType.other) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _focusNode.requestFocus();
                });
              }
            });
          },
          // Styling
          selectedColor: AppColors.error,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: isSelected ? AppColors.error : AppColors.inputBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          showCheckmark: false,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
        );
      }).toList(),
    );
  }
}
