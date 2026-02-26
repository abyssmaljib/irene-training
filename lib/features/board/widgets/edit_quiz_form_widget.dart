import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/edit_post_provider.dart';
import '../services/ai_helper_service.dart';
import '../../../core/widgets/app_snackbar.dart';

/// Quiz form widget for advanced edit post screen
/// Allows users to edit or create a quiz with question and 3 choices (A, B, C)
class EditQuizFormWidget extends ConsumerStatefulWidget {
  final int postId;
  /// Text from the post content for AI to generate quiz from
  final String? postText;

  const EditQuizFormWidget({
    super.key,
    required this.postId,
    this.postText,
  });

  @override
  ConsumerState<EditQuizFormWidget> createState() => _EditQuizFormWidgetState();
}

class _EditQuizFormWidgetState extends ConsumerState<EditQuizFormWidget> {
  bool _isExpanded = false;
  final _questionController = TextEditingController();
  final _choiceAController = TextEditingController();
  final _choiceBController = TextEditingController();
  final _choiceCController = TextEditingController();
  final _aiService = AiHelperService();

  // Cooldown timer for AI generation (prevents rate limiting)
  static const _cooldownSeconds = 10;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Initialize from state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(editPostProvider(widget.postId));
      _questionController.text = state.qaQuestion ?? '';
      _choiceAController.text = state.qaChoiceA ?? '';
      _choiceBController.text = state.qaChoiceB ?? '';
      _choiceCController.text = state.qaChoiceC ?? '';
      // Expand if there's existing quiz data
      if (state.qaQuestion?.isNotEmpty == true) {
        setState(() => _isExpanded = true);
      }
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _choiceAController.dispose();
    _choiceBController.dispose();
    _choiceCController.dispose();
    _aiService.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownRemaining = _cooldownSeconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining--;
        if (_cooldownRemaining <= 0) {
          timer.cancel();
        }
      });
    });
  }

  bool get _isOnCooldown => _cooldownRemaining > 0;

  /// คำนวณจำนวนตัวอักษร (ไม่นับ space)
  int _getTextLength() {
    final text = widget.postText ?? ref.read(editPostProvider(widget.postId)).text;
    return text.replaceAll(' ', '').length;
  }

  /// ตรวจสอบว่าสามารถใช้ AI ได้หรือไม่ (ต้องมากกว่า 50 ตัวอักษร)
  bool get _canUseAI => _getTextLength() > 50;

  void _clearQuiz() {
    _questionController.clear();
    _choiceAController.clear();
    _choiceBController.clear();
    _choiceCController.clear();
    ref.read(editPostProvider(widget.postId).notifier).clearQuiz();
  }

  Future<void> _generateQuizWithAI() async {
    final text = widget.postText ?? ref.read(editPostProvider(widget.postId)).text;
    if (text.trim().isEmpty) {
      // แจ้งเตือน validation: ต้องใส่เนื้อหาก่อนสร้าง quiz ด้วย AI
      AppSnackbar.warning(context, 'กรุณาใส่รายละเอียดก่อน');
      return;
    }

    ref.read(editPostProvider(widget.postId).notifier).setLoadingQuizAI(true);

    try {
      final result = await _aiService.generateQuiz(text);

      // Check if result is valid (not empty)
      final isValidResult = result != null &&
          result.question.trim().isNotEmpty &&
          result.choiceA.trim().isNotEmpty &&
          result.choiceB.trim().isNotEmpty &&
          result.choiceC.trim().isNotEmpty;

      if (isValidResult && mounted) {
        // Store in preview state (not directly to form)
        ref.read(editPostProvider(widget.postId).notifier).setAiQuizPreview(
              question: result.question,
              choiceA: result.choiceA,
              choiceB: result.choiceB,
              choiceC: result.choiceC,
              answer: result.answer,
            );

        // Start cooldown to prevent rate limiting
        _startCooldown();

        // แจ้ง AI สร้างคำถามสำเร็จ
        AppSnackbar.success(context, 'สร้างคำถามสำเร็จ กดแทนที่เพื่อใช้งาน');
      } else {
        if (mounted) {
          ref.read(editPostProvider(widget.postId).notifier).setLoadingQuizAI(false);
          // แจ้ง error เมื่อ AI สร้างคำถามไม่สำเร็จ
          AppSnackbar.error(context, 'ไม่สามารถสร้างคำถามได้ กรุณาลองใหม่');
        }
      }
    } catch (e) {
      if (mounted) {
        ref.read(editPostProvider(widget.postId).notifier).setLoadingQuizAI(false);
        // แจ้ง error เมื่อเกิดข้อผิดพลาดระหว่างสร้างคำถาม
        AppSnackbar.error(context, 'เกิดข้อผิดพลาด: $e');
      }
    }
  }

  void _applyAiQuizToForm() {
    final state = ref.read(editPostProvider(widget.postId));
    if (!state.hasAiQuizPreview) return;

    // Fill the text controllers
    _questionController.text = state.aiQuizQuestion ?? '';
    _choiceAController.text = state.aiQuizChoiceA ?? '';
    _choiceBController.text = state.aiQuizChoiceB ?? '';
    _choiceCController.text = state.aiQuizChoiceC ?? '';

    // Apply to provider state
    ref.read(editPostProvider(widget.postId).notifier).applyAiQuizToForm();

    // แจ้งแทนที่คำถามจาก AI สำเร็จ
    AppSnackbar.success(context, 'แทนที่คำถามเรียบร้อย');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editPostProvider(widget.postId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with expand/collapse
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                HugeIcon(
                  icon: _isExpanded ? HugeIcons.strokeRoundedArrowDown01 : HugeIcons.strokeRoundedArrowRight01,
                  size: AppIconSize.lg,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'แก้ไขคำถามสั้น',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.alternate,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Optional',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
                const Spacer(),
                if (state.hasQuiz)
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    size: AppIconSize.md,
                    color: AppColors.success,
                  ),
              ],
            ),
          ),
        ),

        // Expanded content
        if (_isExpanded) ...[
          AppSpacing.verticalGapSm,
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.alternate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI Generate Quiz button row
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: state.isLoadingQuizAI || _isOnCooldown || !_canUseAI
                          ? null
                          : _generateQuizWithAI,
                      icon: state.isLoadingQuizAI
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : HugeIcon(icon: HugeIcons.strokeRoundedFlash, size: AppIconSize.md),
                      label: Text(_isOnCooldown
                          ? 'รอ $_cooldownRemaining วินาที...'
                          : 'น้องไอรีนน์ ช่วยสร้างคำถาม'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _canUseAI
                            ? const Color(0xFF3A0EB6)
                            : AppColors.secondaryText,
                        backgroundColor:
                            _canUseAI ? const Color(0xFFF4F2FD) : AppColors.alternate,
                        side: BorderSide(
                            color: _canUseAI
                                ? const Color(0xFFB0A8C9)
                                : AppColors.alternate),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        textStyle: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Character count hint
                    if (!_canUseAI)
                      Expanded(
                        child: Text(
                          'พิมพ์มากกว่า 50 ตัวอักษร (${_getTextLength()}/50)',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                  ],
                ),

                // AI Quiz Preview Box
                if (state.hasAiQuizPreview) ...[
                  AppSpacing.verticalGapMd,
                  _buildAiQuizPreview(state),
                ],

                AppSpacing.verticalGapMd,

                // Question field
                Text(
                  'คำถาม',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _questionController,
                  decoration: InputDecoration(
                    hintText: 'เช่น การลาป่วยควรแจ้งล่วงหน้าภายในกี่วัน?',
                    hintStyle: AppTypography.body.copyWith(
                      color: AppColors.secondaryText,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: AppTypography.body,
                  onChanged: (value) {
                    ref.read(editPostProvider(widget.postId).notifier).setQaQuestion(value);
                  },
                ),

                AppSpacing.verticalGapMd,

                // Choices
                Text(
                  'คำตอบ',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Choice A
                _buildChoiceField(
                  label: 'A',
                  controller: _choiceAController,
                  hintText: 'คำตอบข้อ A',
                  isSelected: state.qaAnswer == 'A',
                  onChanged: (value) {
                    ref.read(editPostProvider(widget.postId).notifier).setQaChoiceA(value);
                  },
                  onSelectAnswer: () {
                    ref.read(editPostProvider(widget.postId).notifier).setQaAnswer('A');
                  },
                ),
                const SizedBox(height: 8),

                // Choice B
                _buildChoiceField(
                  label: 'B',
                  controller: _choiceBController,
                  hintText: 'คำตอบข้อ B',
                  isSelected: state.qaAnswer == 'B',
                  onChanged: (value) {
                    ref.read(editPostProvider(widget.postId).notifier).setQaChoiceB(value);
                  },
                  onSelectAnswer: () {
                    ref.read(editPostProvider(widget.postId).notifier).setQaAnswer('B');
                  },
                ),
                const SizedBox(height: 8),

                // Choice C
                _buildChoiceField(
                  label: 'C',
                  controller: _choiceCController,
                  hintText: 'คำตอบข้อ C',
                  isSelected: state.qaAnswer == 'C',
                  onChanged: (value) {
                    ref.read(editPostProvider(widget.postId).notifier).setQaChoiceC(value);
                  },
                  onSelectAnswer: () {
                    ref.read(editPostProvider(widget.postId).notifier).setQaAnswer('C');
                  },
                ),

                AppSpacing.verticalGapMd,

                // Answer selection hint
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedInformationCircle,
                      size: AppIconSize.sm,
                      color: AppColors.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'กดวงกลมเพื่อเลือกคำตอบที่ถูกต้อง',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),

                AppSpacing.verticalGapMd,

                // Clear button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearQuiz,
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedDelete01, size: AppIconSize.sm),
                    label: Text('ล้างคำถาม'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      textStyle: AppTypography.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChoiceField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required bool isSelected,
    required ValueChanged<String> onChanged,
    required VoidCallback onSelectAnswer,
  }) {
    return Row(
      children: [
        // Radio button for answer selection
        GestureDetector(
          onTap: onSelectAnswer,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.success : AppColors.alternate,
                width: 2,
              ),
              color: isSelected
                  ? AppColors.success.withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 8),

        // Label
        Container(
          width: 28,
          alignment: Alignment.center,
          child: Text(
            '$label:',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Text field
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            style: AppTypography.body,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// Build AI quiz preview box with apply button
  Widget _buildAiQuizPreview(EditPostState state) {
    final answerLabel = switch (state.aiQuizAnswer) {
      'A' => state.aiQuizChoiceA ?? '',
      'B' => state.aiQuizChoiceB ?? '',
      'C' => state.aiQuizChoiceC ?? '',
      _ => '',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFBFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5DEF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview content
          SelectableText(
            'คำถาม : ${state.aiQuizQuestion ?? ''}\n'
            'A : ${state.aiQuizChoiceA ?? ''}\n'
            'B : ${state.aiQuizChoiceB ?? ''}\n'
            'C : ${state.aiQuizChoiceC ?? ''}\n'
            'เฉลย : ${state.aiQuizAnswer ?? ''} - $answerLabel',
            style: AppTypography.body.copyWith(
              color: AppColors.primaryText,
              height: 1.6,
            ),
          ),

          AppSpacing.verticalGapMd,

          // Disclaimer
          Text(
            'โปรดทราบว่า ผู้โพสต้องตรวจสอบข้อมูลด้วยตนเองทุกครั้งก่อนโพส เนื่องจากน้องไอรีนน์เป็น AI อาจจะสรุปหรือย่อความได้ไม่สมบูรณ์แบบเท่ามนุษย์',
            style: AppTypography.caption.copyWith(
              color: AppColors.warning,
            ),
          ),

          AppSpacing.verticalGapMd,

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _applyAiQuizToForm,
                icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowDown02, size: AppIconSize.sm),
                label: Text('แทนที่ข้อความ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3A0EB6),
                  side: BorderSide(color: const Color(0xFFBEABF2)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: AppTypography.caption,
                  minimumSize: const Size(0, 32),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(editPostProvider(widget.postId).notifier).clearAiQuizPreview();
                },
                icon: HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, size: AppIconSize.sm),
                label: Text('ยกเลิก'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondaryText,
                  side: BorderSide(color: AppColors.alternate),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: AppTypography.caption,
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
