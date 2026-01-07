import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/clock_in_out.dart';
import '../models/zone.dart';
import '../models/resident_simple.dart';
import '../models/break_time_option.dart';

/// Card แสดงข้อมูลเวรปัจจุบัน (On Shift)
class OnShiftCard extends StatelessWidget {
  final ClockInOut currentShift;
  final List<Zone> zones;
  final List<ResidentSimple> residents;
  final List<BreakTimeOption> breakTimeOptions;
  final VoidCallback onClockOut;
  final bool isClockingOut;
  final bool canClockOut;
  final String? disabledReason;

  const OnShiftCard({
    super.key,
    required this.currentShift,
    required this.zones,
    this.residents = const [],
    this.breakTimeOptions = const [],
    required this.onClockOut,
    this.isClockingOut = false,
    this.canClockOut = true,
    this.disabledReason,
  });

  String get _shiftDisplay {
    return currentShift.shift;
  }

  String get _clockInTimeDisplay {
    if (currentShift.clockInTimestamp == null) return '-';
    // แปลงเป็น local time (เวลาไทย) ก่อนแสดง
    final localTime = currentShift.clockInTimestamp!.toLocal();
    return DateFormat('HH:mm น.').format(localTime);
  }

  String get _zonesDisplay {
    if (currentShift.zones.isEmpty) return '-';

    // หา zone names จาก zones list
    final zoneNames = currentShift.zones.map((zoneId) {
      final zone = zones.firstWhere(
        (z) => z.id == zoneId,
        orElse: () => Zone(id: zoneId, nursinghomeId: 0, name: 'Zone $zoneId'),
      );
      return zone.name;
    }).toList()..sort();

    if (zoneNames.length <= 2) {
      return zoneNames.join(', ');
    }
    return '${zoneNames.take(2).join(', ')} +${zoneNames.length - 2}';
  }

  /// แสดงรายชื่อคนไข้ที่เลือก
  List<String> get _selectedResidentNames {
    if (currentShift.selectedResidentIdList.isEmpty) return [];

    return currentShift.selectedResidentIdList.map((residentId) {
      final resident = residents.firstWhere(
        (r) => r.id == residentId,
        orElse: () => ResidentSimple(id: residentId, name: 'คนไข้ #$residentId'),
      );
      return resident.name;
    }).toList();
  }

  /// แสดงเวลาพักที่เลือก
  List<String> get _selectedBreakTimes {
    if (currentShift.selectedBreakTime.isEmpty) return [];

    return currentShift.selectedBreakTime.map((breakTimeId) {
      final breakTime = breakTimeOptions.firstWhere(
        (b) => b.id == breakTimeId,
        orElse: () => BreakTimeOption(
          id: breakTimeId,
          breakTime: '-',
          shift: currentShift.shift,
          nursinghomeId: 0,
        ),
      );
      return breakTime.breakTime;
    }).toList();
  }

  Widget _buildInfoSection({
    required dynamic icon,
    required String label,
    required List<String> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: icon,
                color: Colors.white.withValues(alpha: 0.85),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                item,
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF087069), // เข้มกว่า primary
            Color(0xFF0D9488), // primary
            Color(0xFF3BA3A0), // อ่อนกว่า primary เล็กน้อย
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.mediumRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedClock01,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              AppSpacing.horizontalGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'กำลังอยู่ในเวร',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      _shiftDisplay,
                      style: AppTypography.heading3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Clock in time badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedLogin01,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _clockInTimeDisplay,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          AppSpacing.verticalGapMd,

          // Zone และจำนวนคนไข้
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Zones
                Expanded(
                  child: _InfoItem(
                    icon: HugeIcons.strokeRoundedMapsLocation01,
                    label: 'Zone',
                    value: _zonesDisplay,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                // Residents count
                Expanded(
                  child: _InfoItem(
                    icon: HugeIcons.strokeRoundedUserGroup,
                    label: 'คนไข้',
                    value: '${currentShift.residentCount} คน',
                  ),
                ),
              ],
            ),
          ),

          // รายชื่อคนไข้
          if (_selectedResidentNames.isNotEmpty) ...[
            AppSpacing.verticalGapSm,
            _buildInfoSection(
              icon: HugeIcons.strokeRoundedUser,
              label: 'คนไข้ที่ดูแล',
              items: _selectedResidentNames,
            ),
          ],

          // เวลาพัก
          if (_selectedBreakTimes.isNotEmpty) ...[
            AppSpacing.verticalGapSm,
            _buildInfoSection(
              icon: HugeIcons.strokeRoundedCoffee01,
              label: 'เวลาพัก',
              items: _selectedBreakTimes,
            ),
          ],

          AppSpacing.verticalGapMd,

          // Clock out button - สีสดใส โดดเด่น
          _buildClockOutButton(),
        ],
      ),
    );
  }

  Widget _buildClockOutButton() {
    final isEnabled = canClockOut && !isClockingOut;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: isEnabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF6B6B), // Coral Red
                      Color(0xFFEE5A24), // Vibrant Orange
                      Color(0xFFFF9F43), // Warm Orange
                    ],
                  )
                : null,
            // Disabled: สีเทา mute
            color: isEnabled ? null : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(18),
            border: isEnabled
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  )
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: const Color(0xFFEE5A24).withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isEnabled ? onClockOut : null,
              borderRadius: BorderRadius.circular(18),
              child: Center(
                child: isClockingOut
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
                                : Colors.white.withValues(alpha: 0.5),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isEnabled ? 'ลงเวร เสร็จสิ้นภารกิจ!' : 'ลงเวร',
                            style: AppTypography.title.copyWith(
                              color: isEnabled
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        // แสดงเหตุผลที่ยังลงเวรไม่ได้
        if (!canClockOut && disabledReason != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedInformationCircle,
                size: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                disabledReason!,
                style: AppTypography.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final dynamic icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HugeIcon(
          icon: icon,
          color: Colors.white.withValues(alpha: 0.85),
          size: 18,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            Text(
              value,
              style: AppTypography.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
