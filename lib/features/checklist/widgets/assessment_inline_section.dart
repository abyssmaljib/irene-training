import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/network_image.dart';
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
/// รองรับทั้ง legacy subjects (1 NpsScale) และ sub-item subjects (N NpsScale grouped)
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
  /// คะแนนของแต่ละ rating slot
  /// key format:
  /// - Legacy subject: "$subjectId" (เช่น "2" สำหรับอาหาร)
  /// - Sub-item: "$subjectId:$subItemId" (เช่น "1:1" สำหรับ นอน→ชั่วโมง)
  final Map<String, int> _ratings = {};

  /// หมายเหตุของแต่ละ subject (1 description ต่อ subject ไม่ว่าจะมี sub-items กี่ข้อ)
  final Map<int, String> _descriptions = {};

  /// TextEditingControllers สำหรับแต่ละ subject — ป้องกัน focus หลุดตอน rebuild
  final Map<int, TextEditingController> _controllers = {};

  /// สร้าง key สำหรับ rating map
  String _ratingKey(int subjectId, [int? subItemId]) {
    return subItemId != null ? '$subjectId:$subItemId' : '$subjectId';
  }

  /// ตรวจว่า subject นี้ rate ครบหรือยัง
  /// Legacy: ต้องมี key "$subjectId"
  /// Sub-item: ต้องมี key ครบทุก sub-item
  bool _isSubjectComplete(AssessmentSubject subject) {
    if (!subject.hasSubItems) {
      return _ratings.containsKey(_ratingKey(subject.subjectId));
    }
    return subject.subItems.every(
      (si) => _ratings.containsKey(_ratingKey(subject.subjectId, si.subItemId)),
    );
  }

  /// จำนวน subjects ที่ rate ครบแล้ว (นับเป็น subject ไม่ใช่ rating slots)
  int get _completedCount =>
      widget.subjects.where((s) => _isSubjectComplete(s)).length;

  bool get _allRated => widget.subjects.every((s) => _isSubjectComplete(s));

  @override
  void initState() {
    super.initState();
    // สร้าง controller + restore initial ratings สำหรับแต่ละ subject
    for (final s in widget.subjects) {
      if (s.hasSubItems) {
        // Sub-item subject: restore rating สำหรับแต่ละ sub-item
        for (final si in s.subItems) {
          final initial = widget.initialRatings.cast<AssessmentRating?>().firstWhere(
                (r) => r!.subjectId == s.subjectId && r.subItemId == si.subItemId,
                orElse: () => null,
              );
          if (initial != null) {
            _ratings[_ratingKey(s.subjectId, si.subItemId)] = initial.rating;
          }
        }
        // Description ใช้จาก rating ตัวแรกที่มี (share 1 description ต่อ subject)
        final firstWithDesc = widget.initialRatings.cast<AssessmentRating?>().firstWhere(
              (r) =>
                  r!.subjectId == s.subjectId &&
                  r.description != null &&
                  r.description!.isNotEmpty,
              orElse: () => null,
            );
        if (firstWithDesc != null) {
          _descriptions[s.subjectId] = firstWithDesc.description!;
        }
      } else {
        // Legacy subject: restore เหมือนเดิม
        final initial = widget.initialRatings.cast<AssessmentRating?>().firstWhere(
              (r) => r!.subjectId == s.subjectId,
              orElse: () => null,
            );
        if (initial != null) {
          _ratings[_ratingKey(s.subjectId)] = initial.rating;
          if (initial.description != null && initial.description!.isNotEmpty) {
            _descriptions[s.subjectId] = initial.description!;
          }
        }
      }
      _controllers[s.subjectId] = TextEditingController(
        text: _descriptions[s.subjectId] ?? '',
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
    final ratings = <AssessmentRating>[];
    for (final s in widget.subjects) {
      final desc = _descriptions[s.subjectId]?.trim();

      if (s.hasSubItems) {
        // Sub-item subject: emit 1 rating per sub-item ที่กรอกแล้ว
        // description ใส่เฉพาะ sub-item แรก (เก็บ 1 ต่อ subject)
        var isFirst = true;
        for (final si in s.subItems) {
          final key = _ratingKey(s.subjectId, si.subItemId);
          if (_ratings.containsKey(key)) {
            ratings.add(AssessmentRating(
              subjectId: s.subjectId,
              subItemId: si.subItemId,
              rating: _ratings[key]!,
              description: isFirst ? desc : null,
            ));
            isFirst = false;
          }
        }
      } else {
        // Legacy subject: emit 1 rating
        final key = _ratingKey(s.subjectId);
        if (_ratings.containsKey(key)) {
          ratings.add(AssessmentRating(
            subjectId: s.subjectId,
            rating: _ratings[key]!,
            description: desc,
          ));
        }
      }
    }
    widget.onChanged(ratings);
    widget.onCompletionChanged(_allRated);
  }

  /// หา choice text สำหรับ rating ที่เลือก (legacy subject)
  String? _getChoiceText(List<String> choices, int rating) {
    final index = rating - 1;
    if (index < 0 || index >= choices.length) return null;
    return choices[index];
  }

  /// คำนวณ composite score จาก sub-items (สำหรับแสดงผล)
  double? _getCompositeScore(AssessmentSubject subject) {
    if (!subject.hasSubItems) return null;
    final scores = <int>[];
    for (final si in subject.subItems) {
      final key = _ratingKey(subject.subjectId, si.subItemId);
      if (_ratings.containsKey(key)) scores.add(_ratings[key]!);
    }
    if (scores.isEmpty) return null;

    switch (subject.scoringMethod) {
      case 'average':
        return scores.reduce((a, b) => a + b) / scores.length;
      case 'sum':
        return scores.reduce((a, b) => a + b).toDouble();
      case 'worst':
        return scores.reduce((a, b) => a < b ? a : b).toDouble();
      default:
        return scores.reduce((a, b) => a + b) / scores.length;
    }
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
            // Progress badge — นับเป็น subject (ไม่ใช่ rating slots)
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
                    : '$_completedCount/${widget.subjects.length}',
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
          if (subject.hasSubItems) {
            // Sub-item subject: แสดง grouped card
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: _SubItemSubjectCard(
                subject: subject,
                ratings: _ratings,
                ratingKeyFn: _ratingKey,
                getChoiceText: _getChoiceText,
                compositeScore: _getCompositeScore(subject),
                controller: _controllers[subject.subjectId]!,
                onSubItemRatingChanged: (subItemId, value) {
                  setState(() {
                    _ratings[_ratingKey(subject.subjectId, subItemId)] = value;
                  });
                  _notifyChanged();
                },
                onDescriptionChanged: (value) {
                  _descriptions[subject.subjectId] = value;
                  _notifyChanged();
                },
              ),
            );
          } else {
            // Legacy subject: แสดงเหมือนเดิม (zero regression)
            final key = _ratingKey(subject.subjectId);
            final rating = _ratings[key];
            final choiceText =
                rating != null ? _getChoiceText(subject.choices, rating) : null;
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: _LegacySubjectCard(
                subject: subject,
                rating: rating,
                choiceText: choiceText,
                controller: _controllers[subject.subjectId]!,
                onRatingChanged: (value) {
                  setState(() {
                    _ratings[key] = value;
                  });
                  _notifyChanged();
                },
                onDescriptionChanged: (value) {
                  _descriptions[subject.subjectId] = value;
                  _notifyChanged();
                },
              ),
            );
          }
        }),
      ],
    );
  }
}

// ============================================================
// Legacy Subject Card — เหมือนเดิมทุกประการ (ไม่มี sub-items)
// ============================================================

/// Card สำหรับประเมิน 1 หัวข้อแบบ legacy (ไม่มี sub-items)
class _LegacySubjectCard extends StatelessWidget {
  final AssessmentSubject subject;
  final int? rating;
  final String? choiceText;
  final TextEditingController controller;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<String> onDescriptionChanged;

  const _LegacySubjectCard({
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

          // คำอธิบาย
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

          // ดูเกณฑ์ตัวอย่าง — expandable, แสดง choices ทั้ง 5 + รูป (ถ้ามี)
          if (subject.choices.isNotEmpty) ...[
            SizedBox(height: AppSpacing.sm),
            _ChoicesExampleSection(
              choices: subject.choices,
              representUrls: subject.representUrls,
            ),
          ],

          SizedBox(height: AppSpacing.md),

          // NPS Scale 1-5
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

          // Choice text ที่เลือก + รูปตัวอย่างของ rating ที่เลือก
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

          // รูปตัวอย่างของ rating ที่เลือก — แสดงเต็มรูป ไม่ crop
          if (rating != null) ...[
            () {
              // ดึง represent_url ตาม rating (index = rating - 1)
              final urlIndex = rating! - 1;
              final representUrl =
                  urlIndex >= 0 && urlIndex < subject.representUrls.length
                      ? subject.representUrls[urlIndex]
                      : null;
              if (representUrl != null && representUrl.isNotEmpty) {
                // ใช้ LayoutBuilder เพื่อคำนวณ 1/3 ของความกว้าง
                return Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final imageWidth = constraints.maxWidth / 3;
                      return Center(
                        child: ClipRRect(
                          borderRadius: AppRadius.mediumRadius,
                          child: IreneNetworkImage(
                            imageUrl: representUrl,
                            width: imageWidth,
                            fit: BoxFit.contain,
                            memCacheWidth: 400,
                            compact: true,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
              return const SizedBox.shrink();
            }(),
          ],

          SizedBox(height: AppSpacing.sm),

          // หมายเหตุ
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

// ============================================================
// Sub-Item Subject Card — แสดง N NpsScale grouped ใต้ subject header
// ============================================================

/// Card สำหรับประเมินหัวข้อที่มี sub-items (เช่น การนอนหลับ → 3 ข้อย่อย)
class _SubItemSubjectCard extends StatelessWidget {
  final AssessmentSubject subject;
  final Map<String, int> ratings;
  final String Function(int, [int?]) ratingKeyFn;
  final String? Function(List<String>, int) getChoiceText;
  final double? compositeScore;
  final TextEditingController controller;
  final void Function(int subItemId, int value) onSubItemRatingChanged;
  final ValueChanged<String> onDescriptionChanged;

  const _SubItemSubjectCard({
    required this.subject,
    required this.ratings,
    required this.ratingKeyFn,
    required this.getChoiceText,
    required this.compositeScore,
    required this.controller,
    required this.onSubItemRatingChanged,
    required this.onDescriptionChanged,
  });

  /// ย่อ label
  String? _shortenLabel(String? text) {
    if (text == null) return null;
    if (text.length <= 15) return text;
    return '${text.substring(0, 13)}..';
  }

  /// สีของ composite score ตาม threshold
  Color _compositeColor(double score) {
    final rounded = score.round().clamp(1, 5);
    return kAssessmentThresholds[rounded - 1].color;
  }

  @override
  Widget build(BuildContext context) {
    // ตรวจว่า rate ครบทุก sub-item หรือยัง
    final isComplete = subject.subItems.every(
      (si) => ratings.containsKey(ratingKeyFn(subject.subjectId, si.subItemId)),
    );
    // นับจำนวน sub-items ที่ rate แล้ว
    final ratedCount = subject.subItems
        .where((si) =>
            ratings.containsKey(ratingKeyFn(subject.subjectId, si.subItemId)))
        .length;

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isComplete
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.tagNeutralBg,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(
          color: isComplete
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.secondaryText.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject header + sub-item progress
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.subjectName,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
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
                  ],
                ),
              ),
              // Sub-item progress badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isComplete
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.tagNeutralBg,
                  borderRadius: AppRadius.smallRadius,
                ),
                child: Text(
                  isComplete
                      ? '✓'
                      : '$ratedCount/${subject.subItems.length}',
                  style: AppTypography.caption.copyWith(
                    color: isComplete
                        ? AppColors.primary
                        : AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.sm),

          // Sub-item scales — แต่ละข้อย่อยมี NpsScale ของตัวเอง
          ...subject.subItems.map((subItem) {
            final key = ratingKeyFn(subject.subjectId, subItem.subItemId);
            final rating = ratings[key];
            final choiceText = rating != null
                ? getChoiceText(subItem.choices, rating)
                : null;

            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ชื่อข้อย่อย
                  Row(
                    children: [
                      // Bullet point
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: rating != null
                              ? AppColors.primary
                              : AppColors.secondaryText.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        subItem.name,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                          color: rating != null
                              ? AppColors.primaryText
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.xs),

                  // NPS Scale 1-5 สำหรับ sub-item นี้
                  Center(
                    child: NpsScale(
                      selectedValue: rating,
                      onChanged: (value) =>
                          onSubItemRatingChanged(subItem.subItemId, value),
                      minValue: 1,
                      maxValue: 5,
                      minLabel: _shortenLabel(subItem.choices.isNotEmpty
                          ? subItem.choices.first
                          : null),
                      maxLabel: _shortenLabel(subItem.choices.length >= 5
                          ? subItem.choices.last
                          : null),
                      thresholds: kAssessmentThresholds,
                      itemSize: 36,
                    ),
                  ),

                  // Choice text ที่เลือก
                  if (choiceText != null)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Center(
                        child: Text(
                          choiceText,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  // รูปตัวอย่างของ rating ที่เลือก — แสดงเต็มรูป ไม่ crop
                  if (rating != null) ...[
                    () {
                      final urlIndex = rating - 1;
                      final representUrl =
                          urlIndex >= 0 && urlIndex < subItem.representUrls.length
                              ? subItem.representUrls[urlIndex]
                              : null;
                      if (representUrl != null && representUrl.isNotEmpty) {
                        return Padding(
                          padding: EdgeInsets.only(top: AppSpacing.sm),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final imageWidth = constraints.maxWidth / 3;
                              return Center(
                                child: ClipRRect(
                                  borderRadius: AppRadius.mediumRadius,
                                  child: IreneNetworkImage(
                                    imageUrl: representUrl,
                                    width: imageWidth,
                                    fit: BoxFit.contain,
                                    memCacheWidth: 400,
                                    compact: true,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }(),
                  ],

                  // ดูเกณฑ์ตัวอย่าง สำหรับ sub-item นี้
                  if (subItem.choices.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.xs),
                    _ChoicesExampleSection(
                      choices: subItem.choices,
                      representUrls: subItem.representUrls,
                      subItemName: subItem.name,
                    ),
                  ],
                ],
              ),
            );
          }),

          // Composite score — แสดงเมื่อ rate อย่างน้อย 1 sub-item
          if (compositeScore != null) ...[
            Divider(
              color: AppColors.secondaryText.withValues(alpha: 0.15),
              height: AppSpacing.md,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'คะแนนรวม: ',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _compositeColor(compositeScore!)
                        .withValues(alpha: 0.15),
                    borderRadius: AppRadius.smallRadius,
                  ),
                  child: Text(
                    '${compositeScore!.toStringAsFixed(1)} / 5.0',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _compositeColor(compositeScore!),
                    ),
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: AppSpacing.sm),

          // หมายเหตุ — 1 ช่องต่อ subject (ไม่ใช่ต่อ sub-item)
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

// ============================================================
// Choices Example Section — แสดงตัวเลือกทั้ง 5 + รูปตัวอย่าง
// ============================================================

/// Expandable section แสดงเกณฑ์ตัวอย่างของแต่ละ scale (1-5)
/// กดเปิด/ปิดได้ — default ปิด เพื่อไม่ให้ UI รก
/// แสดงทั้ง choice text และรูปตัวอย่าง (ถ้ามี represent_url)
class _ChoicesExampleSection extends StatefulWidget {
  /// ตัวเลือก 1-5 เรียงตาม scale
  final List<String> choices;

  /// URL รูปตัวอย่างเรียงตาม scale (null = ไม่มีรูป)
  final List<String?> representUrls;

  /// ชื่อข้อย่อย (ถ้าเป็น sub-item จะแสดง prefix)
  final String? subItemName;

  const _ChoicesExampleSection({
    required this.choices,
    required this.representUrls,
    this.subItemName,
  });

  @override
  State<_ChoicesExampleSection> createState() => _ChoicesExampleSectionState();
}

class _ChoicesExampleSectionState extends State<_ChoicesExampleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // ไม่แสดงอะไรถ้าไม่มี choices
    if (widget.choices.isEmpty) return const SizedBox.shrink();

    // เช็คว่ามีรูปตัวอย่างอย่างน้อย 1 รูปไหม
    final hasAnyImage =
        widget.representUrls.any((url) => url != null && url.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ปุ่มเปิด/ปิด "ดูเกณฑ์ตัวอย่าง"
        // ใช้ InkWell + ConstrainedBox ให้ touch target >= 44px ตาม UX guideline
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: AppRadius.smallRadius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ลูกศรเปิด/ปิด — หมุนตาม state
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        color: AppColors.secondaryText,
                        size: 16,
                      ),
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      widget.subItemName != null
                          ? 'ดูเกณฑ์: ${widget.subItemName}'
                          : 'ดูเกณฑ์ตัวอย่าง',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // เนื้อหา choices ทั้ง 5 ระดับ — animate เปิด/ปิดอย่าง smooth
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.smallRadius,
                border: Border.all(
                  color: AppColors.secondaryText.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                children: List.generate(widget.choices.length, (index) {
                  final scale = index + 1; // scale 1-5
                  final choiceText = widget.choices[index];
                  // ดึง represent_url ถ้ามี (index ตรงกับ scale-1)
                  final representUrl = index < widget.representUrls.length
                      ? widget.representUrls[index]
                      : null;
                  final hasImage =
                      representUrl != null && representUrl.isNotEmpty;
                  // สีตาม threshold (1=แดง ... 5=เขียว)
                  final color = kAssessmentThresholds[index].color;
                  final isLast = index == widget.choices.length - 1;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: isLast ? 0 : AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // แถว: วงกลมเลข scale + choice text
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // วงกลมตัวเลข พร้อมสีตาม level (28px — ใหญ่ขึ้นให้อ่านง่าย)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$scale',
                                style: AppTypography.bodySmall.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            // Choice text — อธิบายว่าระดับนี้หมายถึงอะไร
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  choiceText,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.primaryText,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // รูปตัวอย่าง — แสดงใต้ choice text ถ้ามี represent_url
                        if (hasImage) ...[
                          SizedBox(height: AppSpacing.sm),
                          Padding(
                            padding: const EdgeInsets.only(left: 36),
                            child: ClipRRect(
                              borderRadius: AppRadius.smallRadius,
                              child: IreneNetworkImage(
                                imageUrl: representUrl,
                                width: double.infinity,
                                height: 140,
                                fit: BoxFit.cover,
                                memCacheWidth: 500,
                                compact: true,
                              ),
                            ),
                          ),
                        ],
                        // Divider ระหว่าง choice — แสดงเสมอเพื่อแยก visual ชัดเจน
                        if (!isLast)
                          Padding(
                            padding: EdgeInsets.only(top: AppSpacing.sm),
                            child: Divider(
                              color: AppColors.secondaryText
                                  .withValues(alpha: hasAnyImage ? 0.12 : 0.08),
                              height: 1,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
          // ใช้ easeOut สำหรับ expand animation ที่ natural
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }
}
