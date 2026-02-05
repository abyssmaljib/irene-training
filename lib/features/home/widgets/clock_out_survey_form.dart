import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/widgets/nps_scale.dart';
import '../models/shift_leader.dart';
import 'bug_report_form.dart';

/// Form สำหรับกรอก survey ก่อนลงเวร
class ClockOutSurveyForm extends StatefulWidget {
  /// Callback เมื่อ submit form
  /// - leaderScore จะเป็น null ถ้าไม่มีหัวหน้าเวร
  final void Function({
    required int shiftScore,
    required int selfScore,
    required String shiftSurvey,
    String? bugSurvey,
    int? leaderScore,
  }) onSubmit;
  final bool isLoading;

  /// ข้อมูลหัวหน้าเวร (ถ้ามี) - ใช้แสดง card ประเมินหัวหน้าเวร
  final ShiftLeader? shiftLeader;

  const ClockOutSurveyForm({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
    this.shiftLeader,
  });

  @override
  State<ClockOutSurveyForm> createState() => _ClockOutSurveyFormState();
}

class _ClockOutSurveyFormState extends State<ClockOutSurveyForm> {
  int _shiftScore = 0;
  int _selfScore = 0;
  int _leaderScore = 0; // คะแนนประเมินหัวหน้าเวร
  final _shiftSurveyController = TextEditingController();

  /// ตรวจสอบว่า form valid หรือไม่
  /// - ถ้ามีหัวหน้าเวร ต้องให้คะแนนหัวหน้าเวรด้วย
  bool get _isValid {
    final baseValid = _shiftScore > 0 &&
        _selfScore > 0 &&
        _shiftSurveyController.text.trim().isNotEmpty;

    // ถ้ามีหัวหน้าเวร ต้องให้คะแนนด้วย
    if (widget.shiftLeader != null) {
      return baseValid && _leaderScore > 0;
    }
    return baseValid;
  }

  @override
  void dispose() {
    _shiftSurveyController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_isValid || widget.isLoading) return;

    widget.onSubmit(
      shiftScore: _shiftScore,
      selfScore: _selfScore,
      shiftSurvey: _shiftSurveyController.text.trim(),
      bugSurvey: null, // Bug report ย้ายไปใช้ BugReportForm แยกแล้ว
      leaderScore: widget.shiftLeader != null ? _leaderScore : null,
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

          // NPS Score Rating (1-10)
          _buildNpsSection(
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

          // Leader Score Rating (ถ้ามีหัวหน้าเวร)
          if (widget.shiftLeader != null) ...[
            _buildLeaderRatingCard(),
            AppSpacing.verticalGapMd,
          ],

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
              fillColor: AppColors.background,
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

          // Bug Report Button - เปิด BugReportForm dialog
          _buildBugReportButton(),

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

  /// Widget สำหรับ NPS (1-10) - แนะนำงานที่นี่ให้เพื่อน
  Widget _buildNpsSection({
    required int? value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'อยากแนะนำงานของที่นี่ (ไอรีนน์ เนอร์สซิ่งโฮม) ให้แก่เพื่อนร่วมอาชีพ หรือรุ่นน้องมากน้อยขนาดไหน',
          style: AppTypography.subtitle,
        ),
        AppSpacing.verticalGapSm,
        // NPS Scale 1-10 (ไม่มี thresholds แค่แสดงเลข)
        NpsScale(
          selectedValue: value == 0 ? null : value,
          onChanged: onChanged,
          minValue: 1,
          maxValue: 10,
          minLabel: 'ไม่แนะนำ',
          maxLabel: 'แนะนำเป็นอย่างยิ่ง',
          itemSize: 32,
        ),
      ],
    );
  }

  /// Thresholds สำหรับ rating 1-10 (ให้คะแนนตัวเอง)
  /// - 1-2: แย่มาก (แดง)
  /// - 3-4: ไม่ค่อยดี (ส้ม)
  /// - 5-6: ปานกลาง (เหลือง)
  /// - 7-8: ดี (เขียว)
  /// - 9-10: ดีมาก (primary teal)
  static const _ratingThresholds = [
    NpsThreshold(from: 1, to: 2, color: Color(0xFFE53935), label: 'แย่มาก'),
    NpsThreshold(from: 3, to: 4, color: Color(0xFFFF9800), label: 'ไม่ค่อยดี'),
    NpsThreshold(from: 5, to: 6, color: Color(0xFFFFC107), label: 'ปานกลาง'),
    NpsThreshold(from: 7, to: 8, color: Color(0xFF4DB6AC), label: 'ดี'),
    NpsThreshold(from: 9, to: 10, color: Color(0xFF0D9488), label: 'ดีมาก'),
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
        // ใช้ NpsScale 1-10 สำหรับให้คะแนนตัวเอง
        NpsScale(
          selectedValue: value == 0 ? null : value,
          onChanged: onChanged,
          minValue: 1,
          maxValue: 10,
          minLabel: 'แย่มาก',
          maxLabel: 'ดีมาก',
          thresholds: _ratingThresholds,
          itemSize: 32, // ลดขนาดลงเพราะมี 10 ช่อง
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

  /// Card สำหรับประเมินหัวหน้าเวร
  /// แสดง profile (รูป, ชื่อจริง, ชื่อเล่น) และ NPS scale 1-10
  Widget _buildLeaderRatingCard() {
    final leader = widget.shiftLeader!;

    // หา threshold ที่ตรงกับค่าที่เลือก
    final selectedThreshold = _leaderScore > 0
        ? _ratingThresholds
            .where((t) => _leaderScore >= t.from && _leaderScore <= t.to)
            .firstOrNull
        : null;

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        // สีพื้นหลังอ่อนๆ ตาม primary color
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - ประเมินหัวหน้าเวร
          Text('ประเมินหัวหน้าเวร', style: AppTypography.subtitle),
          AppSpacing.verticalGapXs,
          Text(
            'ให้คะแนนการดูแลของหัวหน้าเวรในเวรนี้',
            style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
          ),

          AppSpacing.verticalGapMd,

          // Profile section - รูป + ชื่อ
          Row(
            children: [
              // Avatar
              if (leader.photoUrl != null && leader.photoUrl!.isNotEmpty)
                IreneNetworkAvatar(
                  imageUrl: leader.photoUrl,
                  radius: 24,
                  fallbackIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedUser,
                    color: AppColors.secondaryText,
                    size: 24,
                  ),
                )
              else
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedUser,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              AppSpacing.horizontalGapMd,
              // ชื่อ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ชื่อเล่น (ตัวใหญ่)
                    Text(
                      leader.nickname ?? leader.displayName,
                      style: AppTypography.title.copyWith(
                        color: AppColors.primaryText,
                      ),
                    ),
                    // ชื่อจริง (ถ้ามี และไม่ซ้ำกับชื่อเล่น)
                    if (leader.fullName != null &&
                        leader.fullName != leader.nickname)
                      Text(
                        leader.fullName!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                  ],
                ),
              ),
              // Badge หัวหน้าเวร
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedUserStar01,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'หน.เวร',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          AppSpacing.verticalGapMd,

          // NPS Scale 1-10
          NpsScale(
            selectedValue: _leaderScore == 0 ? null : _leaderScore,
            onChanged: (v) => setState(() => _leaderScore = v),
            minValue: 1,
            maxValue: 10,
            minLabel: 'แย่มาก',
            maxLabel: 'ดีมาก',
            thresholds: _ratingThresholds,
            itemSize: 32,
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
                    color: _getTextColorForThreshold(selectedThreshold.color),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ปุ่มรายงานปัญหา/Bug - กดแล้วเปิด BugReportForm dialog
  Widget _buildBugReportButton() {
    return InkWell(
      onTap: () => showBugReportDialog(context),
      borderRadius: AppRadius.smallRadius,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: AppRadius.smallRadius,
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedBug01,
              color: AppColors.error,
              size: AppIconSize.lg,
            ),
            AppSpacing.horizontalGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'รายงานปัญหา/Bug',
                    style: AppTypography.subtitle.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  Text(
                    'กดเพื่อแจ้งปัญหาที่พบในแอป',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: AppColors.error.withValues(alpha: 0.5),
              size: AppIconSize.md,
            ),
          ],
        ),
      ),
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
