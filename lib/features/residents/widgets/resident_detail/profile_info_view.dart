import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/resident_detail.dart';
import '../../providers/resident_detail_provider.dart';

/// View แสดงข้อมูลส่วนตัวและข้อมูลทางการแพทย์
class ProfileInfoView extends ConsumerStatefulWidget {
  final ResidentDetail resident;

  const ProfileInfoView({
    super.key,
    required this.resident,
  });

  @override
  ConsumerState<ProfileInfoView> createState() => _ProfileInfoViewState();
}

class _ProfileInfoViewState extends ConsumerState<ProfileInfoView>
    with SingleTickerProviderStateMixin {
  late AnimationController _highlightController;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Check if highlight was triggered before this widget was built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(highlightUnderlyingDiseasesProvider)) {
        _triggerHighlight();
      }
    });
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  void _triggerHighlight() {
    // กระพริบ 3 ครั้ง
    _highlightController.forward().then((_) {
      _highlightController.reverse().then((_) {
        _highlightController.forward().then((_) {
          _highlightController.reverse().then((_) {
            _highlightController.forward().then((_) {
              _highlightController.reverse().then((_) {
                // Reset provider state
                ref.read(highlightUnderlyingDiseasesProvider.notifier).state = false;
              });
            });
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to highlight trigger
    ref.listen<bool>(highlightUnderlyingDiseasesProvider, (previous, next) {
      if (next) {
        _triggerHighlight();
      }
    });

    final resident = widget.resident;
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Section
          _buildSection(
            title: 'ข้อมูลส่วนตัว',
            icon: Iconsax.user,
            children: [
              _buildInfoRow('ชื่อ-นามสกุล', resident.name),
              _buildInfoRow('วันเกิด', '${resident.dobDisplay} (${resident.ageDisplay})'),
              _buildInfoRow('เพศ', resident.gender ?? '-'),
              _buildInfoRow('เลขบัตรประชาชน', _maskNationalId(resident.nationalId)),
              _buildInfoRow('Zone', resident.zoneName),
              _buildInfoRow('เตียง', resident.bed ?? '-'),
              _buildInfoRow('วันที่เข้าพัก', resident.contractDateDisplay),
              _buildInfoRow('สถานะ', resident.status ?? '-'),
              if (resident.hasSpecialStatus)
                _buildInfoRow('สถานะพิเศษ', resident.specialStatus ?? '-'),
            ],
          ),

          AppSpacing.verticalGapMd,

          // Medical Section
          _buildSection(
            title: 'ข้อมูลทางการแพทย์',
            icon: Iconsax.health,
            children: [
              _buildDiseaseChipsRow(
                'โรคประจำตัว',
                resident.underlyingDiseases,
              ),
              _buildInfoRow('แพ้ยา/อาหาร', resident.foodDrugAllergy ?? '-'),
              _buildInfoRow('อาหาร', resident.dietary ?? '-'),
              if (resident.pastHistory != null &&
                  resident.pastHistory!.isNotEmpty)
                _buildExpandableInfoRow(
                  'ประวัติการรักษา',
                  resident.pastHistory!,
                ),
            ],
          ),

          AppSpacing.verticalGapMd,

          // Relatives Section (Placeholder)
          _buildSection(
            title: 'ผู้ติดต่อ/ญาติ',
            icon: Iconsax.people,
            children: [
              _buildPlaceholder(
                icon: Iconsax.user_add,
                message: 'Coming Soon',
                subtitle: 'ระบบจัดการผู้ติดต่อกำลังพัฒนา',
              ),
            ],
          ),

          // Bottom padding
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.medium),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                AppSpacing.horizontalGapSm,
                Text(title, style: AppTypography.title),
              ],
            ),
          ),
          // Section Content
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Row แสดงโรคประจำตัวเป็น chips พร้อม highlight animation
  Widget _buildDiseaseChipsRow(String label, List<String> diseases) {
    return AnimatedBuilder(
      animation: _highlightController,
      builder: (context, child) {
        final highlightColor = Color.lerp(
          Colors.transparent,
          AppColors.primary.withValues(alpha: 0.2),
          _highlightController.value,
        );
        return Container(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: highlightColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              Expanded(
                child: diseases.isEmpty
                    ? Text(
                        '-',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: diseases.map((disease) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.tagPendingBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.tagPendingText
                                    .withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              disease,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.tagPendingText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandableInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          AppSpacing.verticalGapXs,
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.smallRadius,
            ),
            child: Text(
              value,
              style: AppTypography.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder({
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.secondaryText),
          AppSpacing.verticalGapSm,
          Text(
            message,
            style: AppTypography.title.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          Text(
            subtitle,
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  /// Mask national ID for privacy (show only last 4 digits)
  String _maskNationalId(String? nationalId) {
    if (nationalId == null || nationalId.isEmpty) return '-';
    if (nationalId.length <= 4) return nationalId;
    return 'x-xxxx-xxxxx-${nationalId.substring(nationalId.length - 4)}';
  }
}
