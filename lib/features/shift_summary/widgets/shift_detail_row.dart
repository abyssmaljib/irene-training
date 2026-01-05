import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../board/providers/create_post_provider.dart';
import '../../board/screens/advanced_create_post_screen.dart';
import '../../board/screens/board_screen.dart';
import '../models/clock_summary.dart';
import '../models/shift_row_type.dart';
import '../services/shift_summary_service.dart';
import 'sick_leave_claim_sheet.dart';

/// Row แสดงรายละเอียดเวรแต่ละวัน
/// มี 3 รูปแบบตาม ShiftRowType
class ShiftDetailRow extends ConsumerStatefulWidget {
  final ClockSummary clockSummary;
  final VoidCallback? onRefresh;
  final bool isHighlighted;

  const ShiftDetailRow({
    super.key,
    required this.clockSummary,
    this.onRefresh,
    this.isHighlighted = false,
  });

  @override
  ConsumerState<ShiftDetailRow> createState() => _ShiftDetailRowState();
}

class _ShiftDetailRowState extends ConsumerState<ShiftDetailRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<Color?> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _flashAnimation = ColorTween(
      begin: AppColors.primary.withValues(alpha: 0.4),
      end: Colors.transparent,
    ).animate(CurvedAnimation(
      parent: _flashController,
      curve: Curves.easeOut,
    ));

    // Start flash animation if highlighted
    if (widget.isHighlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _flashController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  ClockSummary get clockSummary => widget.clockSummary;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flashAnimation,
      builder: (context, child) {
        return Material(
          color: widget.isHighlighted && _flashController.isAnimating
              ? _flashAnimation.value
              : _getBackgroundColor(),
          child: InkWell(
            onTap: () => _handleTap(context, ref),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.alternate,
                    width: 0.5,
                  ),
                ),
              ),
              child: _buildContent(),
            ),
          ),
        );
      },
    );
  }

  Color _getBackgroundColor() {
    if (clockSummary.isAbsent == true && !clockSummary.isSick) {
      // ขาดงาน - สีเหลืองอ่อน
      return AppColors.warning.withValues(alpha: 0.1);
    } else if (clockSummary.isAbsent == true && clockSummary.isSick) {
      // ลาป่วย - สีเขียวอ่อน
      return AppColors.success.withValues(alpha: 0.1);
    }
    return Colors.transparent;
  }

  Widget _buildContent() {
    switch (clockSummary.rowType) {
      case ShiftRowType.normal:
        return _buildNormalRow();
      case ShiftRowType.manualAddDeduct:
        return _buildManualAddDeductRow();
      case ShiftRowType.ddRecord:
        return _buildDDRecordRow();
    }
  }

  /// Normal shift row
  Widget _buildNormalRow() {
    return Row(
      children: [
        // วันที่
        Expanded(
          child: Text(
            clockSummary.dateFormatted,
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
        ),
        // เวลาเข้า
        Expanded(
          child: Text(
            clockSummary.clockInTimeFormatted,
            style: AppTypography.caption.copyWith(
              color: clockSummary.clockInIsAuto == true
                  ? AppColors.error
                  : AppColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // เวลาออก
        Expanded(
          child: Text(
            clockSummary.clockOutTimeFormatted,
            style: AppTypography.caption.copyWith(
              color: clockSummary.clockOutIsAuto == true
                  ? AppColors.error
                  : AppColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // ประเภทเวร
        Expanded(
          child: Text(
            clockSummary.shiftType ?? '-',
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
        ),
        // พิเศษ (icons)
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (clockSummary.isSupport == true)
                Icon(
                  Iconsax.star,
                  size: 16,
                  color: AppColors.warning,
                ),
              if (clockSummary.incharge == true)
                Icon(
                  Iconsax.medal,
                  size: 16,
                  color: AppColors.success,
                ),
            ],
          ),
        ),
        // Note (additional/deduction)
        Expanded(
          child: _buildNoteCell(),
        ),
      ],
    );
  }

  /// Manual add/deduct row (without DD)
  Widget _buildManualAddDeductRow() {
    String reasonText = '';
    Color textColor = AppColors.primaryText;

    if (clockSummary.isAbsent == true && !clockSummary.isSick) {
      reasonText = 'ขาดงาน - กรุณาแนบหลักฐาน';
      textColor = AppColors.error;
    } else if (clockSummary.isAbsent == true && clockSummary.isSick) {
      reasonText = 'ใช้สิทธิลาป่วย (S)';
      textColor = AppColors.primary;
    } else if (clockSummary.additionalReason != null &&
        clockSummary.additionalReason!.isNotEmpty) {
      reasonText = clockSummary.additionalReason!;
      textColor = AppColors.success;
    } else if (clockSummary.finalDeductionReason != null &&
        clockSummary.finalDeductionReason!.isNotEmpty) {
      reasonText = clockSummary.finalDeductionReason!;
      textColor = AppColors.error;
    }

    // Show notification dot if can claim sick leave
    final showNotiBadge = clockSummary.canClaimSickLeave;

    return Row(
      children: [
        // วันที่
        Expanded(
          child: Text(
            clockSummary.dateFormatted,
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
        ),
        // เหตุผล (ขยาย 4 columns) with notification badge
        Expanded(
          flex: 4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showNotiBadge)
                Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Flexible(
                child: Text(
                  reasonText,
                  style: AppTypography.caption.copyWith(
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // จำนวนเงิน
        Expanded(
          child: _buildAmountCell(),
        ),
      ],
    );
  }

  /// DD Record row
  Widget _buildDDRecordRow() {
    final hasDDPost = clockSummary.ddPostId != null;

    return Row(
      children: [
        // วันที่
        Expanded(
          child: Text(
            clockSummary.dateFormatted,
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
        ),
        // สถานะ (ขยาย 4 columns)
        Expanded(
          flex: 4,
          child: Text(
            hasDDPost ? 'เขียนส่งเวรเรียบร้อย' : 'ยังไม่ได้ส่งเวร',
            style: AppTypography.caption.copyWith(
              color: hasDDPost ? AppColors.primary : AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Icon
        Expanded(
          child: Icon(
            hasDDPost ? Iconsax.tick_square : Iconsax.close_square,
            size: 20,
            color: hasDDPost ? AppColors.primary : AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildNoteCell() {
    final additional = clockSummary.additional ?? 0;
    final deduction = clockSummary.finalDeduction ?? 0;

    if (additional > 0) {
      return Text(
        '+$additional',
        style: AppTypography.caption.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      );
    } else if (deduction > 0) {
      return Text(
        '-${deduction.toStringAsFixed(0)}',
        style: AppTypography.caption.copyWith(
          color: AppColors.error,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildAmountCell() {
    final additional = clockSummary.additional ?? 0;
    final deduction = clockSummary.finalDeduction ?? 0;

    if (additional > 0) {
      return Text(
        '+$additional',
        style: AppTypography.caption.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      );
    } else if (deduction > 0) {
      return Text(
        '-${deduction.toStringAsFixed(0)}',
        style: AppTypography.caption.copyWith(
          color: AppColors.error,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      );
    }
    return SizedBox.shrink();
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    // DD Record with post - open post detail
    if (clockSummary.ddRecordId != null && clockSummary.ddPostId != null) {
      _openPostDetail(context, clockSummary.ddPostId!);
      return;
    }

    // DD Record without post - open create post
    if (clockSummary.ddRecordId != null && clockSummary.ddPostId == null) {
      _openCreatePost(context, ref, clockSummary.ddRecordId!);
      return;
    }

    // Absent but not sick - show sick leave claim
    if (clockSummary.canClaimSickLeave && clockSummary.specialRecordId != null) {
      _showSickLeaveClaim(context);
      return;
    }

    // Sick with evidence - show evidence
    if (clockSummary.isAbsent == true &&
        clockSummary.isSick &&
        clockSummary.sickEvident != null) {
      _showSickEvidence(context);
      return;
    }
  }

  void _openPostDetail(BuildContext context, int postId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: postId),
      ),
    );
  }

  Future<void> _openCreatePost(BuildContext context, WidgetRef ref, int ddRecordId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      // Fetch DD Record info
      final ddRecord = await ShiftSummaryService.instance.getDDRecordWithCalendar(ddRecordId);

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      if (ddRecord == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่พบข้อมูล DD Record')),
          );
        }
        return;
      }

      // Create template text
      final residentName = ddRecord['appointment_resident_name'] as String? ?? '';
      final appointmentTitle = ddRecord['appointment_title'] as String? ?? '';
      final appointmentDescription = ddRecord['appointment_description'] as String? ?? '';
      final residentId = ddRecord['appointment_resident_id'] as int?;

      final templateText = '''
พาผู้พักอาศัย: $residentName
เรื่อง: $appointmentTitle
รายละเอียด: $appointmentDescription
'''.trim();

      // Initialize create post state with DD context
      ref.read(createPostProvider.notifier).initFromDD(
        ddId: ddRecordId,
        templateText: templateText,
        residentId: residentId,
        residentName: residentName.isNotEmpty ? residentName : null,
        title: '📋 รายงานการไปพบแพทย์',
      );

      // Navigate to AdvancedCreatePostScreen
      if (context.mounted) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const AdvancedCreatePostScreen()),
        );

        if (result == true) {
          widget.onRefresh?.call();
        }
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  void _showSickLeaveClaim(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SickLeaveClaimSheet(
        specialRecordId: clockSummary.specialRecordId!,
        date: clockSummary.clockInTime ?? DateTime.now(),
      ),
    );

    if (result == true) {
      widget.onRefresh?.call();
    }
  }

  void _showSickEvidence(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('หลักฐานการลาป่วย'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (clockSummary.sickEvident != null)
              Image.network(
                clockSummary.sickEvident!,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => Container(
                  height: 100,
                  color: AppColors.background,
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
            if (clockSummary.sickReason != null) ...[
              SizedBox(height: AppSpacing.md),
              Text(
                'เหตุผล:',
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              Text(
                clockSummary.sickReason!,
                style: AppTypography.body,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ปิด'),
          ),
        ],
      ),
    );
  }
}
