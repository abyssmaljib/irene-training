import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/create_post_provider.dart';
import '../services/ai_helper_service.dart';

/// AI Summary widget for advanced create post screen
/// Shows AI summarize button and result when text > 50 chars
class AiSummaryWidget extends ConsumerStatefulWidget {
  final TextEditingController textController;
  final VoidCallback? onReplaceText;

  const AiSummaryWidget({
    super.key,
    required this.textController,
    this.onReplaceText,
  });

  @override
  ConsumerState<AiSummaryWidget> createState() => _AiSummaryWidgetState();
}

class _AiSummaryWidgetState extends ConsumerState<AiSummaryWidget> {
  final _aiService = AiHelperService();

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }

  int _getTextLength() {
    return widget.textController.text.replaceAll(' ', '').length;
  }

  bool _canSummarize() {
    return _getTextLength() > 50;
  }

  Future<void> _summarize() async {
    final text = widget.textController.text;
    if (text.trim().isEmpty) return;

    ref.read(createPostProvider.notifier).setLoadingAI(true);

    final result = await _aiService.summarizeText(text);

    if (mounted) {
      ref.read(createPostProvider.notifier).setAiSummary(result);
    }
  }

  void _replaceText() {
    final summary = ref.read(createPostProvider).aiSummary;
    if (summary != null) {
      widget.textController.text = summary;
      widget.textController.selection = TextSelection.collapsed(
        offset: summary.length,
      );
      ref.read(createPostProvider.notifier).setText(summary);
      widget.onReplaceText?.call();
    }
  }

  void _copyText() {
    final summary = ref.read(createPostProvider).aiSummary;
    if (summary != null) {
      Clipboard.setData(ClipboardData(text: summary));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('คัดลอกข้อความแล้ว'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createPostProvider);
    final textLength = _getTextLength();
    final canSummarize = _canSummarize();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summarize button row
        Row(
          children: [
            // AI Summarize button
            OutlinedButton.icon(
              onPressed: canSummarize && !state.isLoadingAI ? _summarize : null,
              icon: state.isLoadingAI
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : HugeIcon(icon: HugeIcons.strokeRoundedMagicWand01, size: AppIconSize.sm),
              label: Text('น้องไอรีนน์ ช่วยสรุป'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    canSummarize ? AppColors.primary : AppColors.secondaryText,
                side: BorderSide(
                  color: canSummarize
                      ? AppColors.primary
                      : AppColors.alternate,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: AppTypography.bodySmall,
              ),
            ),

            const SizedBox(width: 12),

            // Character count hint
            if (!canSummarize)
              Expanded(
                child: Text(
                  'พิมพ์มากกว่า 50 ตัวอักษร เพื่อเปิดใช้งาน ($textLength/50)',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
          ],
        ),

        // AI Summary result
        if (state.aiSummary != null && canSummarize) ...[
          AppSpacing.verticalGapMd,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFFEFBFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFFE5DEF8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary text
                SelectableText(
                  state.aiSummary!,
                  style: AppTypography.body.copyWith(
                    color: AppColors.primaryText,
                    height: 1.5,
                  ),
                ),

                AppSpacing.verticalGapMd,

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _replaceText,
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowUp02, size: AppIconSize.sm),
                      label: Text('แทนที่ข้อความ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFF3A0EB6),
                        side: BorderSide(color: Color(0xFFBEABF2)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: AppTypography.caption,
                        minimumSize: Size(0, 32),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _copyText,
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedCopy01, size: AppIconSize.sm),
                      label: Text('คัดลอกข้อความ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFF3A0EB6),
                        side: BorderSide(color: Color(0xFFBEABF2)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: AppTypography.caption,
                        minimumSize: Size(0, 32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Disclaimer
          AppSpacing.verticalGapSm,
          Text(
            'โปรดทราบว่า ผู้โพสต้องตรวจสอบข้อมูลด้วยตนเองทุกครั้งก่อนโพส เนื่องจากน้องไอรีนน์เป็น AI อาจจะสรุปหรือย่อความได้ไม่สมบูรณ์แบบเท่ามนุษย์',
            style: AppTypography.caption.copyWith(
              color: AppColors.warning,
            ),
          ),
        ],
      ],
    );
  }
}
