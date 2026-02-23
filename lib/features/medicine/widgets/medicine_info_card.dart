import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/network_image.dart';
import '../models/medicine_summary.dart';

/// Card แสดงข้อมูลยาแบบ read-only
///
/// ใช้ร่วมกันใน:
/// - TurnOffMedicineSheet (หยุดยา)
/// - TurnOnMedicineSheet (กลับมาใช้ยา)
/// - EditMedicineScreen (แก้ไขยา)
///
/// แสดง: ชื่อยา, brand, strength, route, unit, รูปยา, timing badges
///
/// ถ้าส่ง [onTapEdit] มา → แสดง icon แก้ไข และกดเพื่อไปหน้าแก้ไขยาใน DB ได้
class MedicineInfoCard extends StatelessWidget {
  const MedicineInfoCard({
    super.key,
    required this.medicine,
    this.onTapEdit,
  });

  final MedicineSummary medicine;

  /// Callback เมื่อกดเพื่อแก้ไขยาในฐานข้อมูล (เฉพาะ canQC)
  final VoidCallback? onTapEdit;

  @override
  Widget build(BuildContext context) {
    // ถ้ามี onTapEdit → ใช้ Material + InkWell เพื่อให้กดได้ + มี ripple effect
    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alternate, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row บน: รูปยา + ข้อมูลหลัก + edit icon (ถ้ากดได้)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // รูปยา (frontFoiled)
              _buildMedicineImage(),
              const SizedBox(width: AppSpacing.md),
              // ชื่อ + brand + strength + route
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ชื่อสามัญ (generic name)
                    if (medicine.genericName != null &&
                        medicine.genericName!.isNotEmpty)
                      Text(
                        medicine.genericName!,
                        style: AppTypography.heading3
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    // ชื่อการค้า (brand name) - แสดงเฉพาะถ้าต่างจาก generic
                    if (medicine.brandName != null &&
                        medicine.brandName!.isNotEmpty &&
                        medicine.brandName != medicine.genericName)
                      Text(
                        medicine.brandName!,
                        style: AppTypography.body
                            .copyWith(color: AppColors.secondaryText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    // ความแรง (strength)
                    if (medicine.str != null && medicine.str!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        medicine.str!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    // วิธีใช้ (route) + หน่วย (unit)
                    if (medicine.route != null || medicine.unit != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [medicine.route, medicine.unit]
                            .where((e) => e != null && e.isNotEmpty)
                            .join(' - '),
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.secondaryText),
                      ),
                    ],
                  ],
                ),
              ),
              // ไอคอนแก้ไข - แสดงเฉพาะเมื่อกดได้ (canQC)
              if (onTapEdit != null) ...[
                const SizedBox(width: AppSpacing.xs),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedEdit02,
                  color: AppColors.secondaryText,
                  size: 18,
                ),
              ],
            ],
          ),

          // Dosage + Timing badges (ด้านล่าง)
          if (medicine.bldb.isNotEmpty ||
              medicine.beforeAfter.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            // ปริมาณยา (เช่น "1 เม็ด")
            if (medicine.takeTab != null) ...[
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedMedicine01,
                    size: AppIconSize.sm,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    medicine.displayDosage,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            // Timing badges
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // ก่อน/หลังอาหาร
                if (medicine.isBeforeFood)
                  _buildBadge(
                    'ก่อนอาหาร',
                    AppColors.tagPendingBg,
                    AppColors.tagPendingText,
                  ),
                if (medicine.isAfterFood)
                  _buildBadge(
                    'หลังอาหาร',
                    AppColors.tagReadBg,
                    AppColors.tagReadText,
                  ),
                // เวลา
                if (medicine.isMorning) _buildTimeBadge('เช้า'),
                if (medicine.isNoon) _buildTimeBadge('กลางวัน'),
                if (medicine.isEvening) _buildTimeBadge('เย็น'),
                if (medicine.isBedtime) _buildTimeBadge('ก่อนนอน'),
                // PRN
                if (medicine.prn == true)
                  _buildBadge(
                    'เมื่อมีอาการ',
                    AppColors.tagFailedBg,
                    AppColors.tagFailedText,
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    // ถ้ามี onTapEdit → wrap ด้วย InkWell เพื่อให้กดไปหน้าแก้ไขยาใน DB ได้
    if (onTapEdit != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapEdit,
          borderRadius: BorderRadius.circular(12),
          child: card,
        ),
      );
    }

    return card;
  }

  /// รูปยา - ใช้ frontFoiled ถ้ามี, ถ้าไม่มีแสดง placeholder icon
  Widget _buildMedicineImage() {
    final imageUrl = medicine.frontFoiled;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return IreneNetworkImage(
        imageUrl: imageUrl,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        memCacheWidth: 200,
        borderRadius: BorderRadius.circular(12),
        compact: true,
        errorPlaceholder: _buildPlaceholderImage(),
      );
    }

    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.alternate,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedMedicine02,
          color: AppColors.secondaryText,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.fullRadius,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTimeBadge(String label) {
    return _buildBadge(label, AppColors.accent1, AppColors.primary);
  }
}
