import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/nps_scale.dart';
import '../../../core/widgets/success_popup.dart';
import '../models/assessment_models.dart';

/// Color thresholds สำหรับ scale 1-5 (เหมือน rating_section ใน vital sign)
/// แดง(1) → ส้ม(2) → เหลือง(3) → เขียวอ่อน(4) → เขียว(5)
const kAssessmentThresholds = [
  NpsThreshold(from: 1, to: 1, color: Color(0xFFE53935)),
  NpsThreshold(from: 2, to: 2, color: Color(0xFFFF9800)),
  NpsThreshold(from: 3, to: 3, color: Color(0xFFFFC107)),
  NpsThreshold(from: 4, to: 4, color: Color(0xFF8BC34A)),
  NpsThreshold(from: 5, to: 5, color: Color(0xFF0D9488)),
];

/// Dialog ให้ผู้ช่วยพยาบาลป��ะเมิน resident ตาม subjects ที่กำหนดใน task template
///
/// แสดงหลัง DifficultyRatingDialog ตอน complete task
/// แต่ละ subject = 1 card มี NpsScale 1-5 + optional description
///
/// Returns:
/// - null = user ปิด dialog (ยกเลิก)
/// - List of AssessmentRating = ผลประเมินทุกหัวข้อ
class AssessmentRatingDialog extends StatefulWidget {
  /// หัวข้อที่ต้องประเมิน (จาก Task_Report_Subject)
  final List<AssessmentSubject> subjects;

  /// ชื่อ resident (แสดง subtitle)
  final String? residentName;

  const AssessmentRatingDialog({
    super.key,
    required this.subjects,
    this.residentName,
  });

  /// Show dialog และ return ผลลัพธ์
  static Future<List<AssessmentRating>?> show(
    BuildContext context, {
    required List<AssessmentSubject> subjects,
    String? residentName,
  }) async {
    return showDialog<List<AssessmentRating>>(
      context: context,
      barrierDismissible: false, // ต้องกดปุ่มเท่านั้น (ป้องกัน dismiss โดยบังเอิญ)
      builder: (context) => AssessmentRatingDialog(
        subjects: subjects,
        residentName: residentName,
      ),
    );
  }

  @override
  State<AssessmentRatingDialog> createState() =>
      _AssessmentRatingDialogState();
}

class _AssessmentRatingDialogState extends State<AssessmentRatingDialog> {
  /// คะแนนที่เลือกของแต่ละ subject (subjectId → rating 1-5)
  final Map<int, int> _ratings = {};

  /// หมายเหตุของแต่ละ subject (subjectId → text)
  final Map<int, String> _descriptions = {};

  /// ป้องกัน confirm ซ้ำ
  bool _hasConfirmed = false;

  /// ตรวจว่าประเมินครบทุกหัวข้อหรือยัง
  bool get _allRated =>
      widget.subjects.every((s) => _ratings.containsKey(s.subjectId));

  /// จำนวนที่ประเมินแล้ว / ทั้งหมด
  String get _progressText =>
      '${_ratings.length}/${widget.subjects.length}';

  /// หา choice text สำหรับ rating ที่เลือก
  String? _getChoiceText(AssessmentSubject subject, int rating) {
    final index = rating - 1; // rating 1-5 → index 0-4
    if (index < 0 || index >= subject.choices.length) return null;
    return subject.choices[index];
  }

  /// ยืนยันผลประเมิน
  Future<void> _handleConfirm() async {
    if (_hasConfirmed || !_allRated) return;
    _hasConfirmed = true;

    // เล่นเสียง
    SoundService.instance.playTaskComplete();

    // แสดง success popup
    await SuccessPopup.show(
      context,
      emoji: '📋',
      message: 'บันทึกแล้ว',
      color: AppColors.primary,
      autoCloseDuration: const Duration(milliseconds: 600),
    );

    if (!mounted) return;

    // สร้าง result list
    final results = widget.subjects.map((s) {
      return AssessmentRating(
        subjectId: s.subjectId,
        rating: _ratings[s.subjectId]!,
        description: _descriptions[s.subjectId]?.trim(),
      );
    }).toList();

    Navigator.pop(context, results);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeRadius,
      ),
      backgroundColor: AppColors.surface,
      contentPadding: EdgeInsets.zero,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      content: SizedBox(
        width: double.maxFinite,
        // จำกัดความสูง เพื่อให้ scroll ได้ถ้ามีหลาย subjects
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // === Header (ไม่ scroll) ===
              Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
                child: Column(
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedTaskDone02,
                          color: AppColors.primary,
                          size: AppIconSize.xl,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),

                    // Title
                    Text(
                      'ประเมินสุขภาพ',
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Subtitle (ชื่อ resident)
                    if (widget.residentName != null)
                      Text(
                        widget.residentName!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.secondaryText,
                        ),
                        textAlign: TextAlign.center,
                      ),

                    SizedBox(height: AppSpacing.xs),

                    // Progress badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _allRated
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.tagNeutralBg,
                        borderRadius: AppRadius.smallRadius,
                      ),
                      child: Text(
                        _allRated
                            ? '✓ ครบทุกหัวข้อ'
                            : 'ประเมินแล้ว $_progressText',
                        style: AppTypography.caption.copyWith(
                          color: _allRated
                              ? AppColors.primary
                              : AppColors.secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),

              // === Subject cards (scrollable) ===
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: widget.subjects.length,
                  separatorBuilder: (_, _) => SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final subject = widget.subjects[index];
                    final rating = _ratings[subject.subjectId];
                    return _SubjectCard(
                      subject: subject,
                      rating: rating,
                      choiceText:
                          rating != null ? _getChoiceText(subject, rating) : null,
                      description: _descriptions[subject.subjectId],
                      onRatingChanged: (value) {
                        setState(() {
                          _ratings[subject.subjectId] = value;
                        });
                      },
                      onDescriptionChanged: (value) {
                        _descriptions[subject.subjectId] = value;
                      },
                    );
                  },
                ),
              ),

              // === Footer buttons (ไม่ scroll) ===
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // ปุ่มยกเลิก
                    Expanded(
                      child: SecondaryButton(
                        onPressed: () => Navigator.pop(context, null),
                        text: 'ยกเลิก',
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    // ปุ่มยืนยัน (disabled ถ้ายังประเมินไม่ครบ)
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        onPressed: _allRated ? _handleConfirm : null,
                        text: _allRated
                            ? 'ยืนยัน'
                            : 'ประเมินอีก ${widget.subjects.length - _ratings.length} หัวข้อ',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card สำหรับประเมิน 1 หัวข้อ
/// แสดงชื่อ subject + NpsScale 1-5 + choice text + optional description
/// ใช้ StatefulWidget เพื่อเก็บ TextEditingController — ป้องกัน focus หลุดตอน parent rebuild
class _SubjectCard extends StatefulWidget {
  final AssessmentSubject subject;
  final int? rating;
  final String? choiceText;
  final String? description;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<String> onDescriptionChanged;

  const _SubjectCard({
    required this.subject,
    required this.rating,
    required this.choiceText,
    required this.description,
    required this.onRatingChanged,
    required this.onDescriptionChanged,
  });

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.description ?? '');
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rating = widget.rating;
    final subject = widget.subject;
    final choiceText = widget.choiceText;

    return Semantics(
      label: '${subject.subjectName} — ${rating != null ? "ให้คะแนน $rating จาก 5" : "ยังไม่ประเมิน"}',
      child: Container(
        padding: AppSpacing.paddingSm,
        decoration: BoxDecoration(
          color: rating != null
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.tagNeutralBg,
          borderRadius: AppRadius.mediumRadius,
          border: Border.all(
            color: rating != null
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ชื่อหัวข้อ
            Text(
              subject.subjectName,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            // คำอธิบาย (ถ้ามี)
            if (subject.subjectDescription != null &&
                subject.subjectDescription!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  subject.subjectDescription!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),

            SizedBox(height: AppSpacing.sm),

            // NPS Scale 1-5
            Center(
              child: NpsScale(
                selectedValue: rating,
                onChanged: widget.onRatingChanged,
                minValue: 1,
                maxValue: 5,
                minLabel: subject.choices.isNotEmpty ? subject.choices.first : null,
                maxLabel: subject.choices.length >= 5 ? subject.choices.last : null,
                thresholds: kAssessmentThresholds,
                itemSize: 40,
              ),
            ),

            // Choice text ที่เลือก (แสดงเมื่อมี rating)
            if (choiceText != null) ...[
              SizedBox(height: AppSpacing.xs),
              Center(
                child: Text(
                  choiceText,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            // Optional description (หมายเหตุ) — ใช้ controller เพื่อรักษา focus ตอน parent rebuild
            SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _descController,
              onChanged: widget.onDescriptionChanged,
              maxLines: 1,
              style: AppTypography.bodySmall,
              decoration: InputDecoration(
                hintText: 'หมายเหตุ (ถ้ามี)',
                hintStyle: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText.withValues(alpha: 0.5),
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.smallRadius,
                  borderSide: BorderSide(
                      color: AppColors.secondaryText.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.smallRadius,
                  borderSide: BorderSide(
                      color: AppColors.secondaryText.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.smallRadius,
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
