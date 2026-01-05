import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/break_time_option.dart';
import '../models/friend_break_time.dart';

/// Widget สำหรับเลือกเวลาพัก
/// แสดงภาพรวมเพื่อนที่เลือกไปแล้วก่อน แล้วค่อยให้ user เลือก
/// มีสีบอกใบ้: เขียว = ว่าง, เหลือง = มีบ้าง, แดง = เยอะ
class BreakTimeSelector extends StatelessWidget {
  final List<BreakTimeOption> breakTimeOptions;
  final Set<int> selectedBreakTimeIds;
  final Map<int, List<FriendBreakTime>> occupiedBreakTimes;
  final String? currentUserName;
  final ValueChanged<Set<int>> onChanged;
  final bool isLoading;

  // Dev mode props
  final bool devMode;
  final String? devCurrentShift; // เวรปัจจุบันที่กำลังแสดง
  final ValueChanged<String>? onDevShiftChanged;

  const BreakTimeSelector({
    super.key,
    required this.breakTimeOptions,
    required this.selectedBreakTimeIds,
    this.occupiedBreakTimes = const {},
    this.currentUserName,
    required this.onChanged,
    this.isLoading = false,
    this.devMode = false,
    this.devCurrentShift,
    this.onDevShiftChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Group break times by break_name (เช่น พัก 20 นาที)
    final groupedBreakTimes = <String, List<BreakTimeOption>>{};
    for (final option in breakTimeOptions) {
      final groupName = option.breakName ?? 'อื่นๆ';
      groupedBreakTimes.putIfAbsent(groupName, () => []).add(option);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'เลือกเวลาพัก',
              style: AppTypography.title,
            ),
            if (selectedBreakTimeIds.isNotEmpty) ...[
              AppSpacing.horizontalGapSm,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedBreakTimeIds.length}',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        AppSpacing.verticalGapXs,
        // คำอธิบาย
        Text(
          'ดูว่าเพื่อนเลือกเวลาไหนไปแล้ว แล้วเลือกเวลาที่ไม่ซ้ำกัน',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        AppSpacing.verticalGapSm,
        // Legend
        _buildLegend(),
        // Dev mode: shift toggle
        if (devMode && onDevShiftChanged != null) ...[
          AppSpacing.verticalGapSm,
          _buildDevShiftToggle(),
        ],
        AppSpacing.verticalGapMd,

        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (breakTimeOptions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mediumRadius,
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Text(
              'ไม่มีตัวเลือกเวลาพัก',
              style: AppTypography.body.copyWith(color: AppColors.secondaryText),
              textAlign: TextAlign.center,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mediumRadius,
              border: Border.all(color: AppColors.inputBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: groupedBreakTimes.entries.map((entry) {
                final validOptions = entry.value
                    .where((option) => option.breakTime.isNotEmpty)
                    .toList();

                if (validOptions.isEmpty) return const SizedBox.shrink();

                // IDs ทั้งหมดใน group นี้
                final groupOptionIds = validOptions.map((o) => o.id).toSet();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group name (e.g., "พัก 20 นาที")
                      Text(
                        entry.key,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                      AppSpacing.verticalGapSm,
                      // Break time list
                      ...validOptions.map((option) {
                        final isSelected =
                            selectedBreakTimeIds.contains(option.id);
                        final friends = occupiedBreakTimes[option.id] ?? [];
                        final occupancyLevel = _getOccupancyLevel(friends.length);

                        return _BreakTimeRow(
                          breakTime: option.breakTime,
                          isSelected: isSelected,
                          friends: friends,
                          occupancyLevel: occupancyLevel,
                          currentUserName:
                              isSelected ? currentUserName : null,
                          onTap: () {
                            final newSelection =
                                Set<int>.from(selectedBreakTimeIds);
                            if (isSelected) {
                              // ยกเลิกการเลือก
                              newSelection.remove(option.id);
                            } else {
                              // ลบตัวเลือกเก่าใน group นี้ออกก่อน แล้วเพิ่มตัวใหม่
                              newSelection.removeAll(groupOptionIds);
                              newSelection.add(option.id);
                            }
                            onChanged(newSelection);
                          },
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // สีสำหรับ legend (ใช้เดียวกับ _BreakTimeRow)
  static const Color _legendEmptyColor = Color(0xFF2E7D32); // เขียวเข้ม (invite)
  static const Color _legendSomeColor = Color(0xFFFF9800); // ส้ม
  static const Color _legendFullColor = Color(0xFFD32F2F); // แดงเข้ม (warning)

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend row
        Row(
          children: [
            _LegendItem(
              color: _legendEmptyColor,
              label: 'ว่าง',
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: _legendSomeColor,
              label: 'มีบ้าง',
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: _legendFullColor,
              label: 'เยอะ',
            ),
          ],
        ),
        const SizedBox(height: 6),
        // คำอธิบายเพิ่มเติม
        Text(
          '💡 เลือกช่วงสีเขียว เพื่อไม่ให้พักตรงกับเพื่อน (ป้องกันคนดูแลไม่พอ)',
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDevShiftToggle() {
    final isMorning = devCurrentShift == 'เวรเช้า';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Iconsax.code, size: 16, color: Colors.purple),
          const SizedBox(width: 8),
          Text(
            'DEV:',
            style: AppTypography.caption.copyWith(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                _ShiftToggleButton(
                  label: 'เวรเช้า',
                  isSelected: isMorning,
                  onTap: () => onDevShiftChanged?.call('เวรเช้า'),
                ),
                const SizedBox(width: 8),
                _ShiftToggleButton(
                  label: 'เวรดึก',
                  isSelected: !isMorning,
                  onTap: () => onDevShiftChanged?.call('เวรดึก'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// กำหนดระดับความหนาแน่น
  /// 0 = ว่าง (เขียว), 1-2 = มีบ้าง (เหลือง), 3+ = เยอะ (แดง)
  _OccupancyLevel _getOccupancyLevel(int friendCount) {
    if (friendCount == 0) return _OccupancyLevel.empty;
    if (friendCount <= 2) return _OccupancyLevel.some;
    return _OccupancyLevel.full;
  }
}

enum _OccupancyLevel { empty, some, full }

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

/// Row สำหรับแสดงเวลาพักแต่ละช่อง
class _BreakTimeRow extends StatelessWidget {
  final String breakTime;
  final bool isSelected;
  final List<FriendBreakTime> friends;
  final _OccupancyLevel occupancyLevel;
  final String? currentUserName;
  final VoidCallback onTap;

  const _BreakTimeRow({
    required this.breakTime,
    required this.isSelected,
    this.friends = const [],
    required this.occupancyLevel,
    this.currentUserName,
    required this.onTap,
  });

  // สีสำหรับ indicator dot
  static const Color _emptyColor = Color(0xFF2E7D32); // เขียวเข้ม (invite)
  static const Color _someColor = Color(0xFFFF9800); // ส้ม
  static const Color _fullColor = Color(0xFFD32F2F); // แดงเข้ม (warning)

  // สีพื้นหลัง
  static const Color _emptyBgColor = Color(0xFFC8E6C9); // เขียวอ่อนเข้มขึ้น (invite bg)
  static const Color _someBgColor = Color(0xFFFFF3E0); // ส้มอ่อนพาสเทล
  static const Color _fullBgColor = Color(0xFFFFCDD2); // แดงอ่อนเข้มขึ้น (warning bg)

  Color get _indicatorColor {
    switch (occupancyLevel) {
      case _OccupancyLevel.empty:
        return _emptyColor;
      case _OccupancyLevel.some:
        return _someColor;
      case _OccupancyLevel.full:
        return _fullColor;
    }
  }

  Color get _backgroundColor {
    if (isSelected) {
      return AppColors.primary.withValues(alpha: 0.1);
    }
    switch (occupancyLevel) {
      case _OccupancyLevel.empty:
        return _emptyBgColor;
      case _OccupancyLevel.some:
        return _someBgColor;
      case _OccupancyLevel.full:
        return _fullBgColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : _indicatorColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time slot + status indicator + select button
                Row(
                  children: [
                    // Status indicator dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _indicatorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Time text
                    Expanded(
                      child: Text(
                        breakTime,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                    // ปุ่มเลือก
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.alternate,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected
                                ? Iconsax.tick_circle
                                : Iconsax.record,
                            size: 16,
                            color: isSelected ? Colors.white : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSelected ? 'เลือกแล้ว' : 'เลือก',
                            style: AppTypography.caption.copyWith(
                              color: isSelected ? Colors.white : AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // แสดงรายชื่อเพื่อนที่เลือกเวลานี้
                if (friends.isNotEmpty || currentUserName != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      // แสดงชื่อตัวเองก่อน (ถ้าเลือก)
                      if (currentUserName != null)
                        _PersonChip(
                          name: currentUserName!,
                          isCurrentUser: true,
                        ),
                      // แสดงชื่อเพื่อนพร้อมโซน
                      ...friends.map((friend) => _PersonChip(
                            name: friend.displayName,
                            zoneName: friend.zoneName,
                            isCurrentUser: false,
                          )),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ปุ่มสลับเวร (dev mode)
class _ShiftToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShiftToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.purple.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? Colors.white : Colors.purple,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Chip แสดงชื่อคนพร้อมโซน
class _PersonChip extends StatelessWidget {
  final String name;
  final String? zoneName;
  final bool isCurrentUser;

  const _PersonChip({
    required this.name,
    this.zoneName,
    this.isCurrentUser = false,
  });

  String get _displayText {
    if (zoneName != null && zoneName!.isNotEmpty) {
      return '$name ($zoneName)';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.accent1,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar placeholder
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrentUser ? AppColors.primary : AppColors.tertiary,
            ),
            child: const Icon(
              Iconsax.user,
              size: 10,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _displayText,
            style: AppTypography.caption.copyWith(
              color: isCurrentUser ? AppColors.primary : AppColors.primaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
