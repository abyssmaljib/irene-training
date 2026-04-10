import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/nps_scale.dart';
import '../models/assessment_models.dart';

/// Color thresholds สำหรับ scale 1-5
/// แดง(1) → ส้ม(2) → เหลือง(3) → เขียวอ่อน(4) → เขียว(5)
const kAssessmentThresholds = [
  NpsThreshold(from: 1, to: 1, color: Color(0xFFE53935)),
  NpsThreshold(from: 2, to: 2, color: Color(0xFFFF9800)),
  NpsThreshold(from: 3, to: 3, color: Color(0xFFFFC107)),
  NpsThreshold(from: 4, to: 4, color: Color(0xFF8BC34A)),
  NpsThreshold(from: 5, to: 5, color: Color(0xFF0D9488)),
];

/// Inline section สำหรับประเมินสุขภาพ resident ในหน้า task detail
/// แสดงเหมือน MeasurementInputSection — user กรอกก่อนกด complete
class AssessmentInlineSection extends StatefulWidget {
  /// หัวข้อที่ต้องประเมิน
  final List<AssessmentSubject> subjects;

  /// callback เมื่อ rating เปลี่ยน — ส่ง list ของ ratings ที่กรอกแล้ว
  final ValueChanged<List<AssessmentRating>> onChanged;

  /// callback เมื่อประเมินครบ/ไม่ครบ — ใช้ enable/disable ปุ่ม complete
  final ValueChanged<bool> onCompletionChanged;

  /// ผลประเมินเดิม (สำหรับ edit/restore) — ถ้ามีจะ pre-fill ratings
  final List<AssessmentRating> initialRatings;

  const AssessmentInlineSection({
    super.key,
    required this.subjects,
    required this.onChanged,
    required this.onCompletionChanged,
    this.initialRatings = const [],
  });

  @override
  State<AssessmentInlineSection> createState() =>
      _AssessmentInlineSectionState();
}

class _AssessmentInlineSectionState extends State<AssessmentInlineSection> {
  /// คะแนนของแต่ละ subject (subjectId → rating 1-5)
  final Map<int, int> _ratings = {};

  /// หมายเหตุของแต่ละ subject
  final Map<int, String> _descriptions = {};

  /// TextEditingControllers สำหรับแต่ละ subject — ป้องกัน focus หลุดตอน rebuild
  final Map<int, TextEditingController> _controllers = {};

  bool get _allRated =>
      widget.subjects.every((s) => _ratings.containsKey(s.subjectId));

  @override
  void initState() {
    super.initState();
    // สร้าง controller สำหรับแต่ละ subject
    for (final s in widget.subjects) {
      // หา initial rating สำหรับ subject นี้ (ถ้ามี)
      final initial = widget.initialRatings.cast<AssessmentRating?>().firstWhere(
            (r) => r!.subjectId == s.subjectId,
            orElse: () => null,
          );
      if (initial != null) {
        _ratings[s.subjectId] = initial.rating;
        if (initial.description != null && initial.description!.isNotEmpty) {
          _descriptions[s.subjectId] = initial.description!;
        }
      }
      _controllers[s.subjectId] = TextEditingController(
        text: initial?.description ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// เรียกทุกครั้งที่ rating เปลี่ยน — ส่ง callback ไป parent
  void _notifyChanged() {
    final ratings = widget.subjects
        .where((s) => _ratings.containsKey(s.subjectId))
        .map((s) => AssessmentRating(
              subjectId: s.subjectId,
              rating: _ratings[s.subjectId]!,
              description: _descriptions[s.subjectId]?.trim(),
            ))
        .toList();
    widget.onChanged(ratings);
    widget.onCompletionChanged(_allRated);
  }

  /// หา choice text สำหรับ rating ที่เลือก
  String? _getChoiceText(AssessmentSubject subject, int rating) {
    final index = rating - 1;
    if (index < 0 || index >= subject.choices.length) return null;
    return subject.choices[index];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'ประเมินสุขภาพ',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // Progress badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _allRated
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.tagNeutralBg,
                borderRadius: AppRadius.smallRadius,
              ),
              child: Text(
                _allRated
                    ? '✓ ครบ'
                    : '${_ratings.length}/${widget.subjects.length}',
                style: AppTypography.caption.copyWith(
                  color:
                      _allRated ? AppColors.primary : AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),

        // Subject cards
        ...widget.subjects.map((subject) {
          final rating = _ratings[subject.subjectId];
          final choiceText =
              rating != null ? _getChoiceText(subject, rating) : null;
          return Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: _InlineSubjectCard(
              subject: subject,
              rating: rating,
              choiceText: choiceText,
              controller: _controllers[subject.subjectId]!,
              onRatingChanged: (value) {
                setState(() {
                  _ratings[subject.subjectId] = value;
                });
                _notifyChanged();
              },
              onDescriptionChanged: (value) {
                _descriptions[subject.subjectId] = value;
                _notifyChanged();
              },
            ),
          );
        }),
      ],
    );
  }
}

/// Card สำหรับประเมิน 1 หัวข้อ (inline version)
class _InlineSubjectCard extends StatelessWidget {
  final AssessmentSubject subject;
  final int? rating;
  final String? choiceText;
  final TextEditingController controller;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<String> onDescriptionChanged;

  const _InlineSubjectCard({
    required this.subject,
    required this.rating,
    required this.choiceText,
    required this.controller,
    required this.onRatingChanged,
    required this.onDescriptionChanged,
  });

  /// ย่อ min/max label ให้สั้น — choice text เต็มยาวเกินไปสำหรับ scale label
  String? _shortenLabel(String? text) {
    if (text == null) return null;
    if (text.length <= 15) return text;
    return '${text.substring(0, 13)}..';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: rating != null
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.tagNeutralBg,
        borderRadius: AppRadius.mediumRadius,
        // Card ที่ยังไม่ rate ก็มี border อ่อนๆ เพื่อให้เห็นขอบเขตชัด
        border: Border.all(
          color: rating != null
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.secondaryText.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ชื่อหัวข้อ
          Text(
            subject.subjectName,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),

          // คำอธิบาย — ใช้ bodySmall แทน caption เพื่อให้อ่านง่ายขึ้น
          if (subject.subjectDescription != null &&
              subject.subjectDescription!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                subject.subjectDescription!,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.secondaryText),
              ),
            ),

          SizedBox(height: AppSpacing.md),

          // NPS Scale 1-5 — ใช้ label สั้นๆ ไม่ใช้ choice text เต็ม
          Center(
            child: NpsScale(
              selectedValue: rating,
              onChanged: onRatingChanged,
              minValue: 1,
              maxValue: 5,
              minLabel: _shortenLabel(
                  subject.choices.isNotEmpty ? subject.choices.first : null),
              maxLabel: _shortenLabel(
                  subject.choices.length >= 5 ? subject.choices.last : null),
              thresholds: kAssessmentThresholds,
              itemSize: 40,
            ),
          ),

          // Choice text ที่เลือก — แสดงข้อความเต็มตรงกลาง
          if (choiceText != null) ...[
            SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                choiceText!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          SizedBox(height: AppSpacing.sm),

          // หมายเหตุ — minLines 2 ให้มีพื้นที่เขียนเพิ่ม
          TextField(
            controller: controller,
            onChanged: onDescriptionChanged,
            minLines: 2,
            maxLines: 4,
            style: AppTypography.bodySmall,
            decoration: InputDecoration(
              hintText: 'หมายเหตุเพิ่มเติม',
              hintStyle: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryText.withValues(alpha: 0.4),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    );
  }
}
