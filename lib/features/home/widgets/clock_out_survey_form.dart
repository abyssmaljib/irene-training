import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/nps_scale.dart';

/// Form สำหรับกรอก survey ก่อนลงเวร
class ClockOutSurveyForm extends StatefulWidget {
  final void Function({
    required int shiftScore,
    required int selfScore,
    required String shiftSurvey,
    String? bugSurvey,
  }) onSubmit;
  final bool isLoading;

  const ClockOutSurveyForm({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
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
      _shiftScore > 0 &&
      _selfScore > 0 &&
      _shiftSurveyController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _shiftSurveyController.dispose();
    _bugSurveyController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_isValid || widget.isLoading) return;

    widget.onSubmit(
      shiftScore: _shiftScore,
      selfScore: _selfScore,
      shiftSurvey: _shiftSurveyController.text.trim(),
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
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: EdgeInsets.all(AppSpacing.md),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.next,
            // ไม่ใช้ onChanged + setState เพราะจะ rebuild ทั้ง form ทุกครั้งที่พิมพ์
            // ใช้ ValueListenableBuilder ที่ wrap ปุ่ม submit แทน (ดูด้านล่าง)
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
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: EdgeInsets.all(AppSpacing.md),
            ),
            maxLines: 2,
            textInputAction: TextInputAction.done,
          ),

          AppSpacing.verticalGapLg,

          // Submit Button - สีสันสดใส เต็มความกว้าง
          // ใช้ ValueListenableBuilder เพื่อ rebuild เฉพาะปุ่มเมื่อข้อความเปลี่ยน
          // แทนการใช้ setState ใน onChanged ซึ่งจะ rebuild ทั้ง form
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _shiftSurveyController,
            builder: (context, value, child) {
              return _buildSubmitButton();
            },
          ),
        ],
      ),
    );
  }

  /// Thresholds สำหรับ rating 1-5 (ให้คะแนนเวร/ตัวเอง)
  /// - 1: แย่มาก (แดง)
  /// - 2: ไม่ค่อยดี (ส้ม)
  /// - 3: ปานกลาง (เหลือง)
  /// - 4: ดี (เขียว)
  /// - 5: ดีมาก (primary teal)
  static const _ratingThresholds = [
    NpsThreshold(from: 1, to: 1, color: Color(0xFFE53935), label: 'แย่มาก'),
    NpsThreshold(from: 2, to: 2, color: Color(0xFFFF9800), label: 'ไม่ค่อยดี'),
    NpsThreshold(from: 3, to: 3, color: Color(0xFFFFC107), label: 'ปานกลาง'),
    NpsThreshold(from: 4, to: 4, color: Color(0xFF4DB6AC), label: 'ดี'),
    NpsThreshold(from: 5, to: 5, color: Color(0xFF0D9488), label: 'ดีมาก'),
  ];

  /// คืนค่าสี text ที่เหมาะสมกับ threshold color
  /// สีเหลืองและส้มจะใช้สีเข้มขึ้นเพื่อให้อ่านง่าย
  Color _getTextColorForThreshold(Color color) {
    final colorInt = color.toARGB32();
    // สีเหลือง (FFC107) → ใช้สีน้ำตาลเข้ม
    if (colorInt == 0xFFFFC107) {
      return const Color(0xFF8D6E00);
    }
    // สีส้ม (FF9800) → ใช้สีส้มเข้ม
    if (colorInt == 0xFFFF9800) {
      return const Color(0xFFBF6000);
    }
    // สีอื่นๆ ใช้สีเดิมได้เลย
    return color;
  }

  Widget _buildRatingSection({
    required String label,
    required String hint,
    required int? value,
    required ValueChanged<int> onChanged,
  }) {
    // หา threshold ที่ตรงกับค่าที่เลือก เพื่อแสดง label และสี
    final selectedThreshold = value != null && value > 0
        ? _ratingThresholds.where((t) => value >= t.from && value <= t.to).firstOrNull
        : null;

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
        // ใช้ NpsScale แทน star rating
        NpsScale(
          selectedValue: value == 0 ? null : value,
          onChanged: onChanged,
          minValue: 1,
          maxValue: 5,
          minLabel: 'แย่มาก',
          maxLabel: 'ดีมาก',
          thresholds: _ratingThresholds,
          itemSize: 40,
        ),
        // กล่องแสดงข้อความของคะแนนที่เลือก
        if (selectedThreshold != null) ...[
          AppSpacing.verticalGapSm,
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selectedThreshold.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selectedThreshold.color.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                selectedThreshold.label ?? '',
                style: AppTypography.bodySmall.copyWith(
                  // ใช้สีเข้มขึ้นสำหรับเหลืองและส้ม เพื่อให้อ่านง่าย
                  color: _getTextColorForThreshold(selectedThreshold.color),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
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
