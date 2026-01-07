import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/zone.dart';
import '../models/resident_simple.dart';
import '../models/break_time_option.dart';
import '../models/friend_break_time.dart';
import 'zone_multi_select.dart';
import 'resident_checkbox_list.dart';
import 'break_time_selector.dart';

/// Section สำหรับ Clock-in (Before Duty)
class ClockInSection extends StatelessWidget {
  final List<Zone> zones;
  final Set<int> selectedZoneIds;
  final ValueChanged<Set<int>> onZonesChanged;
  final bool isLoadingZones;

  final List<ResidentSimple> residents;
  final Set<int> selectedResidentIds;
  final Set<int> disabledResidentIds;
  final ValueChanged<Set<int>> onResidentsChanged;
  final bool isLoadingResidents;

  final List<BreakTimeOption> breakTimeOptions;
  final Set<int> selectedBreakTimeIds;
  final Map<int, List<FriendBreakTime>> occupiedBreakTimes;
  final String? currentUserName;
  final ValueChanged<Set<int>> onBreakTimesChanged;
  final bool isLoadingBreakTimes;

  // Dev mode
  final bool devMode;
  final String? devCurrentShift;
  final ValueChanged<String>? onDevShiftChanged;

  final VoidCallback onClockIn;
  final bool isClockingIn;

  const ClockInSection({
    super.key,
    required this.zones,
    required this.selectedZoneIds,
    required this.onZonesChanged,
    this.isLoadingZones = false,
    required this.residents,
    required this.selectedResidentIds,
    this.disabledResidentIds = const {},
    required this.onResidentsChanged,
    this.isLoadingResidents = false,
    required this.breakTimeOptions,
    required this.selectedBreakTimeIds,
    this.occupiedBreakTimes = const {},
    this.currentUserName,
    required this.onBreakTimesChanged,
    this.isLoadingBreakTimes = false,
    this.devMode = false,
    this.devCurrentShift,
    this.onDevShiftChanged,
    required this.onClockIn,
    this.isClockingIn = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.mediumRadius,
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedClock01,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              AppSpacing.horizontalGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เตรียมขึ้นเวร',
                      style: AppTypography.heading3,
                    ),
                    Text(
                      'กรุณาเลือก Zone, คนไข้ และเวลาพัก',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        AppSpacing.verticalGapLg,

        // Zone Selection
        ZoneMultiSelect(
          zones: zones,
          selectedZoneIds: selectedZoneIds,
          onChanged: onZonesChanged,
          isLoading: isLoadingZones,
        ),

        AppSpacing.verticalGapLg,

        // Resident Selection
        ResidentCheckboxList(
          residents: residents,
          selectedResidentIds: selectedResidentIds,
          disabledResidentIds: disabledResidentIds,
          onChanged: onResidentsChanged,
          isLoading: isLoadingResidents,
        ),

        AppSpacing.verticalGapLg,

        // Break Time Selection
        BreakTimeSelector(
          breakTimeOptions: breakTimeOptions,
          selectedBreakTimeIds: selectedBreakTimeIds,
          occupiedBreakTimes: occupiedBreakTimes,
          currentUserName: currentUserName,
          onChanged: onBreakTimesChanged,
          isLoading: isLoadingBreakTimes,
          devMode: devMode,
          devCurrentShift: devCurrentShift,
          onDevShiftChanged: onDevShiftChanged,
        ),

        AppSpacing.verticalGapXl,

        // Clock In Button - Welcome & Happy Style!
        _buildClockInButton(),

        AppSpacing.verticalGapLg,
      ],
    );
  }

  bool get _canClockIn =>
      devMode || // Dev mode: always allow clock in
      (selectedZoneIds.isNotEmpty &&
      selectedResidentIds.isNotEmpty &&
      selectedBreakTimeIds.isNotEmpty);

  String _getValidationMessage() {
    final missing = <String>[];
    if (selectedZoneIds.isEmpty) missing.add('Zone');
    if (selectedResidentIds.isEmpty) missing.add('คนไข้');
    if (selectedBreakTimeIds.isEmpty) missing.add('เวลาพัก');

    if (missing.isEmpty) return '';
    return 'กรุณาเลือก ${missing.join(', ')}';
  }

  Widget _buildClockInButton() {
    final canClockIn = _canClockIn;

    return Column(
      children: [
        // ข้อความแสดงสถานะ - สีอ่อน เรียบง่าย
        if (canClockIn) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                color: AppColors.primary,
                size: 18,
              ),
              AppSpacing.horizontalGapXs,
              Text(
                'เลือกครบแล้ว พร้อมขึ้นเวร!',
                style: AppTypography.body.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
        ],

        // ปุ่มขึ้นเวร - สีสดใส โดดเด่น เมื่อ active / สีเทาชัดเจน เมื่อ disabled
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: canClockIn
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF6366F1), // Indigo - สดใสกว่า
                      Color(0xFFEC4899), // Pink
                      Color(0xFFF59E0B), // Amber - สว่างกว่า
                    ],
                  )
                : null,
            // Disabled: สีเทาชัดเจน ไม่กลืนกับ background
            color: canClockIn ? null : const Color(0xFFD1D5DB), // Gray-300
            borderRadius: BorderRadius.circular(20),
            border: canClockIn
                ? null
                : Border.all(
                    color: const Color(0xFF9CA3AF), // Gray-400 border
                    width: 1,
                  ),
            boxShadow: canClockIn
                ? [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(-4, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canClockIn && !isClockingIn ? onClockIn : null,
              borderRadius: BorderRadius.circular(20),
              child: Center(
                child: isClockingIn
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (canClockIn)
                            const Text('✨ ', style: TextStyle(fontSize: 22)),
                          Text(
                            canClockIn ? 'เริ่มขึ้นเวรเลย!' : 'ขึ้นเวร',
                            style: AppTypography.heading3.copyWith(
                              color: canClockIn
                                  ? Colors.white
                                  : const Color(0xFF6B7280), // Gray-500 text when disabled
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (canClockIn)
                            const Text(' ✨', style: TextStyle(fontSize: 22)),
                        ],
                      ),
              ),
            ),
          ),
        ),

        // ข้อความแจ้งเตือน
        if (!canClockIn)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedInformationCircle,
                  size: 14,
                  color: AppColors.secondaryText,
                ),
                AppSpacing.horizontalGapXs,
                Text(
                  _getValidationMessage(),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
