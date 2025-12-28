import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/medicine_summary.dart';
import 'overlay_med_widget.dart';

/// Item แสดงรูปยา + ชื่อ + จำนวน
class MedicinePhotoItem extends StatelessWidget {
  final MedicineSummary medicine;
  final bool showFoiled; // true = แผง (2C), false = เม็ดยา (3C)
  final bool showOverlay; // แสดง overlay จำนวนเม็ดยา
  final VoidCallback? onTap;

  const MedicinePhotoItem({
    super.key,
    required this.medicine,
    this.showFoiled = true,
    this.showOverlay = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = showFoiled ? medicine.photo2C : medicine.photo3C;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap ?? (hasPhoto ? () => _showFullImage(context, photoUrl) : null),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadius.smallRadius,
          border: Border.all(color: AppColors.inputBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo area with overlay
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // รูปยา (ใช้ CachedNetworkImage)
                  hasPhoto
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.background,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => _buildPlaceholder(),
                          fadeInDuration: const Duration(milliseconds: 150),
                          memCacheWidth: 300,
                          memCacheHeight: 300,
                        )
                      : _buildPlaceholder(),

                  // Overlay จำนวนเม็ดยา
                  if (showOverlay && medicine.takeTab != null && medicine.takeTab! > 0)
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return OverlayMedWidget(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            takeTab: medicine.takeTab,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Info area
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                border: Border(
                  top: BorderSide(color: AppColors.inputBorder),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Medicine name + strength
                  Text(
                    medicine.str != null && medicine.str!.isNotEmpty
                        ? '${medicine.displayName} ${medicine.str}'
                        : medicine.displayName,
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Dosage
                  if (medicine.displayDosage.isNotEmpty)
                    Text(
                      medicine.displayDosage,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.image,
              size: 32,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: 4),
            Text(
              showFoiled ? 'ไม่มีรูป (จัดยา)' : 'ไม่มีรูป (เสิร์ฟยา)',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(AppSpacing.md),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadius.mediumRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  border: Border(
                    bottom: BorderSide(color: AppColors.inputBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        medicine.displayName,
                        style: AppTypography.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Iconsax.close_circle,
                        color: AppColors.textSecondary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Image
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.image,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'ไม่สามารถโหลดรูปได้',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Medicine Detail Card
              _buildMedicineDetailCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// Format ชื่อการค้า + strength + (generic name)
  /// เช่น "Berlontin 100 mg (gabapentin)"
  String _formatBrandNameWithGeneric() {
    final parts = <String>[];

    // Brand name
    if (medicine.brandName != null && medicine.brandName!.isNotEmpty) {
      parts.add(medicine.brandName!);
    }

    // Strength
    if (medicine.str != null && medicine.str!.isNotEmpty) {
      parts.add(medicine.str!);
    }

    var result = parts.join(' ');

    // Generic name in parentheses
    if (medicine.displayName.isNotEmpty) {
      result += ' (${medicine.displayName})';
    }

    return result;
  }

  /// Card แสดงรายละเอียดยา
  Widget _buildMedicineDetailCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.inputBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Brand name + Strength (generic name)
          if (medicine.brandName != null && medicine.brandName!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _buildInfoItem(
                icon: Iconsax.tag,
                label: 'ชื่อการค้า',
                value: _formatBrandNameWithGeneric(),
              ),
            ),

          // Row 2: Dosage + Route
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (medicine.displayDosage.isNotEmpty)
                  _buildInfoChip(medicine.displayDosage, const Color(0xFF0EA5E9)),
                if (medicine.route != null && medicine.route!.isNotEmpty) ...[
                  SizedBox(width: 8),
                  _buildInfoChip(medicine.route!, const Color(0xFF8B5CF6)),
                ],
                if (medicine.prn == true) ...[
                  SizedBox(width: 8),
                  _buildInfoChip('PRN', const Color(0xFFF97316)),
                ],
              ],
            ),
          ),

          // Row 3: Category (ATC)
          if (medicine.atcLevel2NameTh != null || medicine.atcLevel1NameTh != null)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _buildInfoItem(
                icon: Iconsax.category,
                label: 'ประเภท',
                value: medicine.atcLevel2NameTh ?? medicine.atcLevel1NameTh ?? '',
              ),
            ),

          // Row 4: Meals (BLDB) + Before/After
          if (medicine.bldb.isNotEmpty || medicine.beforeAfter.isNotEmpty)
            _buildMealInfo(),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        SizedBox(width: 4),
        Text(
          '$label: ',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.fullRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildMealInfo() {
    // Meal icons
    final mealIcons = {
      'เช้า': Iconsax.sun_1,
      'กลางวัน': Iconsax.sun,
      'เย็น': Iconsax.moon,
      'ก่อนนอน': Iconsax.moon,
    };

    final mealColors = {
      'เช้า': const Color(0xFFF59E0B),
      'กลางวัน': const Color(0xFFF97316),
      'เย็น': const Color(0xFF3B82F6),
      'ก่อนนอน': const Color(0xFF8B5CF6),
    };

    return Row(
      children: [
        Icon(Iconsax.clock, size: 14, color: AppColors.textSecondary),
        SizedBox(width: 4),
        Text(
          'มื้อ: ',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        // Meal chips
        ...medicine.bldb.map((meal) {
          final color = mealColors[meal] ?? AppColors.primary;
          final icon = mealIcons[meal] ?? Iconsax.clock;
          return Padding(
            padding: EdgeInsets.only(right: 4),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.fullRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 10, color: color),
                  SizedBox(width: 2),
                  Text(
                    meal,
                    style: AppTypography.caption.copyWith(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        // Before/After chips
        if (medicine.beforeAfter.isNotEmpty) ...[
          SizedBox(width: 4),
          ...medicine.beforeAfter.map((ba) {
            final isBefore = ba.contains('ก่อน');
            final color = isBefore ? const Color(0xFF0EA5E9) : const Color(0xFFEF4444);
            return Padding(
              padding: EdgeInsets.only(right: 4),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.fullRadius,
                ),
                child: Text(
                  ba,
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
