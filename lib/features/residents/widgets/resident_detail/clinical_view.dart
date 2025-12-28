import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../medicine/screens/medicine_list_screen.dart';
import '../../../medicine/screens/medicine_photos_screen.dart';
import '../../../medicine/widgets/medicine_summary_card.dart';
import '../../../medicine/widgets/medicine_photos_card.dart';

/// Clinical View - แสดงข้อมูลทางคลินิกของ Resident
/// ปัจจุบันแสดง Medicine Summary Card
/// ในอนาคตจะเพิ่ม: กราฟสัญญาณชีพ, SOAP Notes, etc.
class ClinicalView extends StatelessWidget {
  final int residentId;
  final String residentName;

  const ClinicalView({
    super.key,
    required this.residentId,
    required this.residentName,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MedicineSummaryCard(
            residentId: residentId,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MedicineListScreen(
                    residentId: residentId,
                    residentName: residentName,
                  ),
                ),
              );
            },
          ),

          SizedBox(height: AppSpacing.md),

          // Medicine Photos Card
          MedicinePhotosCard(
            residentId: residentId,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MedicinePhotosScreen(
                    residentId: residentId,
                    residentName: residentName,
                  ),
                ),
              );
            },
          ),

          // ในอนาคตจะเพิ่ม cards อื่นๆ เช่น:
          // - VitalSignsCard
          // - SOAPNotesCard
          // - LabResultsCard
        ],
      ),
    );
  }
}
