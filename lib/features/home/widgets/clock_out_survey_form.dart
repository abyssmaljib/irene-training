import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Form สำหรับกรอก survey ก่อนลงเวร
class ClockOutSurveyForm extends StatefulWidget {
  final void Function({
    required int shiftScore,
    required int selfScore,
    required String shiftSurvey,
    String? bugSurvey,
  }) onSubmit;
  final bool isLoading;

  /// Dev mode: skip validation, ใช้ค่า default
  final bool devMode;

  const ClockOutSurveyForm({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
    this.devMode = false,
  });

  @override
  State<ClockOutSurveyForm> createState() => _ClockOutSurveyFormState();
}

class _ClockOutSurveyFormState extends State<ClockOutSurveyForm> {
  int _shiftScore = 0;
  int _selfScore = 0;
  final _shiftSurveyController = TextEditingController();
  final _bugSurveyController = TextEditingController();

  bool get _isValid =>
      widget.devMode || // Dev mode: skip validation
      (_shiftScore > 0 &&
      _selfScore > 0 &&
      _shiftSurveyController.text.trim().isNotEmpty);

  @override
  void dispose() {
    _shiftSurveyController.dispose();
    _bugSurveyController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_isValid || widget.isLoading) return;

    // Dev mode: ใช้ค่า default ถ้าไม่ได้กรอก
    final shiftScore = _shiftScore > 0 ? _shiftScore : 5;
    final selfScore = _selfScore > 0 ? _selfScore : 5;
    final shiftSurvey = _shiftSurveyController.text.trim().isNotEmpty
        ? _shiftSurveyController.text.trim()
        : 'DEV MODE - ลงเวรทดสอบ';

    widget.onSubmit(
      shiftScore: shiftScore,
      selfScore: selfScore,
      shiftSurvey: shiftSurvey,
      bugSurvey: _bugSurveyController.text.trim().isNotEmpty
          ? _bugSurveyController.text.trim()
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text('สรุปเวร', style: AppTypography.heading3),
                Text(
                  'กรอกแบบสำรวจก่อนลงเวร',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.verticalGapMd,

          // Cat image
          Center(
            child: Image.asset(
              'assets/images/graceful_cat.webp',
              width: 200,
              height: 200,
            ),
          ),

          AppSpacing.verticalGapLg,

          // Shift Score Rating
          _buildRatingSection(
            label: 'ให้คะแนนเวรนี้',
            hint: 'เวรนี้เป็นอย่างไรบ้าง?',
            value: _shiftScore,
            onChanged: (v) => setState(() => _shiftScore = v),
          ),

          AppSpacing.verticalGapMd,

          // Self Score Rating
          _buildRatingSection(
            label: 'ให้คะแนนตัวเอง',
            hint: 'ทำงานได้ดีแค่ไหน?',
            value: _selfScore,
            onChanged: (v) => setState(() => _selfScore = v),
          ),

          AppSpacing.verticalGapMd,

          // Shift Survey TextField
          Text('สิ่งที่เกิดขึ้นในเวรนี้ *', style: AppTypography.subtitle),
          AppSpacing.verticalGapSm,
          TextField(
            controller: _shiftSurveyController,
            decoration: InputDecoration(
              hintText: 'เล่าสิ่งที่เกิดขึ้นในเวรนี้...',
              hintStyle: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
              filled: true,
              fillColor: AppColors.alternate.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.all(AppSpacing.md),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),

          AppSpacing.verticalGapMd,

          // Bug Survey TextField (Optional)
          Text('รายงานปัญหา/Bug (ถ้ามี)', style: AppTypography.subtitle),
          AppSpacing.verticalGapSm,
          TextField(
            controller: _bugSurveyController,
            decoration: InputDecoration(
              hintText: 'พบปัญหาอะไรบ้างในระบบ?',
              hintStyle: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
              filled: true,
              fillColor: AppColors.alternate.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.all(AppSpacing.md),
            ),
            maxLines: 2,
            textInputAction: TextInputAction.done,
          ),

          AppSpacing.verticalGapLg,

          // Submit Button - สีสันสดใส เต็มความกว้าง
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildRatingSection({
    required String label,
    required String hint,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.subtitle),
        AppSpacing.verticalGapXs,
        Text(
          hint,
          style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
        ),
        AppSpacing.verticalGapSm,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            final isSelected = starValue <= value;
            return GestureDetector(
              onTap: () => onChanged(starValue),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: HugeIcon(
                  icon: isSelected ? HugeIcons.strokeRoundedStar : HugeIcons.strokeRoundedStar,
                  color: isSelected ? AppColors.warning : AppColors.secondaryText,
                  size: 40,
                ),
              ),
            );
          }),
        ),
        if (value > 0)
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                _getRatingText(value),
                style: AppTypography.caption.copyWith(
                  color: _getRatingColor(value),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getRatingText(int value) {
    switch (value) {
      case 1:
        return 'แย่มาก';
      case 2:
        return 'ไม่ค่อยดี';
      case 3:
        return 'ปานกลาง';
      case 4:
        return 'ดี';
      case 5:
        return 'ดีมาก';
      default:
        return '';
    }
  }

  Color _getRatingColor(int value) {
    switch (value) {
      case 1:
        return AppColors.error;
      case 2:
        return AppColors.warning;
      case 3:
        return AppColors.secondaryText;
      case 4:
        return AppColors.success;
      case 5:
        return AppColors.primary;
      default:
        return AppColors.secondaryText;
    }
  }

  Widget _buildSubmitButton() {
    final isEnabled = _isValid && !widget.isLoading;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6366F1), // Indigo
                  Color(0xFFEC4899), // Pink
                  Color(0xFFF59E0B), // Amber
                ],
              )
            : null,
        color: isEnabled ? null : AppColors.alternate,
        borderRadius: BorderRadius.circular(16),
        border: isEnabled
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? _handleSubmit : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedLogout01,
                        color: isEnabled
                            ? Colors.white
                            : AppColors.secondaryText,
                        size: AppIconSize.lg,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEnabled ? 'ลงเวร เสร็จสิ้นภารกิจ!' : 'ลงเวร',
                        style: AppTypography.title.copyWith(
                          color: isEnabled
                              ? Colors.white
                              : AppColors.secondaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
