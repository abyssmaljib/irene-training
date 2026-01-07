import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/vital_sign_form_provider.dart';
import 'package:hugeicons/hugeicons.dart';

/// Widget for rating subjects with star ratings and optional descriptions
class RatingSection extends ConsumerWidget {
  const RatingSection({
    super.key,
    required this.residentId,
    this.vitalSignId,
  });

  final int residentId;
  final int? vitalSignId; // null = create mode, non-null = edit mode

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use appropriate provider based on mode
    final isEditMode = vitalSignId != null;
    final formState = isEditMode
        ? ref.watch(editVitalSignFormProvider((residentId: residentId, vitalSignId: vitalSignId!))).value
        : ref.watch(vitalSignFormProvider(residentId)).value;
    if (formState == null) return const SizedBox.shrink();

    // Get notifier based on mode
    final VitalSignFormNotifier createNotifier;
    final EditVitalSignFormNotifier? editNotifier;
    if (isEditMode) {
      editNotifier = ref.read(editVitalSignFormProvider((residentId: residentId, vitalSignId: vitalSignId!)).notifier);
      createNotifier = ref.read(vitalSignFormProvider(residentId).notifier);
    } else {
      createNotifier = ref.read(vitalSignFormProvider(residentId).notifier);
      editNotifier = null;
    }

    // Helper functions
    void setRating(int relationId, int rating) => isEditMode
        ? editNotifier!.setRating(relationId, rating)
        : createNotifier.setRating(relationId, rating);
    void setRatingDescription(int relationId, String description) => isEditMode
        ? editNotifier!.setRatingDescription(relationId, description)
        : createNotifier.setRatingDescription(relationId, description);

    final ratings = formState.ratings.values.toList();

    if (ratings.isEmpty) {
      return Center(
        child: Text(
          'ไม่มีหัวข้อการประเมิน',
          style: AppTypography.body.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Show error message at top if validation fails
        if (formState.errorMessage != null &&
            formState.errorMessage!.contains('ประเมิน'))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: AppIconSize.input,
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '*อย่าลืมประเมินให้ครบด้วยน้า',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Rating subjects
        ...ratings.map((rating) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _RatingCard(
              subjectName: rating.subjectName,
              subjectDescription: rating.subjectDescription,
              choices: rating.choices,
              currentRating: rating.rating,
              currentDescription: rating.description,
              onRatingChanged: (newRating) {
                setRating(rating.relationId, newRating);
              },
              onDescriptionChanged: (description) {
                setRatingDescription(rating.relationId, description);
              },
            ),
          );
        }),
      ],
    );
  }
}

/// Card for a single rating subject
class _RatingCard extends StatefulWidget {
  const _RatingCard({
    required this.subjectName,
    required this.subjectDescription,
    required this.choices,
    required this.currentRating,
    required this.currentDescription,
    required this.onRatingChanged,
    required this.onDescriptionChanged,
  });

  final String subjectName;
  final String? subjectDescription;
  final List<String>? choices;
  final int? currentRating;
  final String? currentDescription;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<String> onDescriptionChanged;

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.currentDescription ?? '',
    );
  }

  @override
  void didUpdateWidget(_RatingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if value changed from external source (not from user typing)
    if (widget.currentDescription != oldWidget.currentDescription &&
        widget.currentDescription != _descriptionController.text) {
      _descriptionController.text = widget.currentDescription ?? '';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Get choice text for a given rating (1-5)
  String? _getChoiceText(int rating) {
    if (widget.choices == null || widget.choices!.isEmpty) return null;
    final index = rating - 1; // rating 1-5 -> index 0-4
    if (index < 0 || index >= widget.choices!.length) return null;
    return widget.choices![index];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject name
        Text(
          widget.subjectName,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),

        // Subject description (if available)
        if (widget.subjectDescription != null &&
            widget.subjectDescription!.isNotEmpty)
          Text(
            widget.subjectDescription!,
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        const SizedBox(height: 12),

        // Star rating (5 stars)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            final isSelected = widget.currentRating != null &&
                               widget.currentRating! >= starValue;

            return GestureDetector(
              onTap: () => widget.onRatingChanged(starValue),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedStar,
                  size: 40,
                  color: isSelected
                      ? AppColors.warning
                      : AppColors.alternate,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),

        // Choice text for selected rating
        if (widget.currentRating != null && widget.currentRating! > 0)
          Builder(
            builder: (context) {
              final choiceText = _getChoiceText(widget.currentRating!);
              if (choiceText == null) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  choiceText,
                  style: AppTypography.heading3.copyWith(
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),

        // Optional description text field
        TextField(
          controller: _descriptionController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'รายละเอียดเพิ่มเติม (ถ้ามี)',
            hintText: 'เช่น สภาพอารมณ์ การสื่อสาร ฯลฯ',
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
          onChanged: widget.onDescriptionChanged,
        ),
      ],
    );
  }
}
