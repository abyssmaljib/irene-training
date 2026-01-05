import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/vital_sign.dart';
import '../services/resident_detail_service.dart';

/// หน้าแสดงประวัติสัญญาณชีพของ resident (Infinite scroll)
class VitalSignLogScreen extends ConsumerStatefulWidget {
  final int residentId;
  final String residentName;

  const VitalSignLogScreen({
    super.key,
    required this.residentId,
    required this.residentName,
  });

  @override
  ConsumerState<VitalSignLogScreen> createState() => _VitalSignLogScreenState();
}

class _VitalSignLogScreenState extends ConsumerState<VitalSignLogScreen> {
  final _scrollController = ScrollController();
  final List<VitalSign> _vitalSigns = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isInitialLoading = true;
  String? _error;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final newItems = await ResidentDetailService.instance
          .getVitalSignHistoryPaginated(
        widget.residentId,
        offset: _vitalSigns.length,
        limit: _pageSize,
      );

      setState(() {
        _vitalSigns.addAll(newItems);
        _hasMore = newItems.length == _pageSize;
        _isLoading = false;
        _isInitialLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _vitalSigns.clear();
      _hasMore = true;
      _isInitialLoading = true;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.residentName,
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'สัญญาณชีพ',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null && _vitalSigns.isEmpty) {
      return _buildError(_error!);
    }

    if (_vitalSigns.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: _vitalSigns.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _vitalSigns.length) {
            return _buildLoadingIndicator();
          }

          final isEven = index % 2 == 0;
          return _VitalSignRow(
            vitalSign: _vitalSigns[index],
            backgroundColor:
                isEven ? AppColors.surface : AppColors.background,
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      alignment: Alignment.center,
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.warning_2, size: 48, color: AppColors.error),
            AppSpacing.verticalGapMd,
            Text(
              'เกิดข้อผิดพลาด',
              style: AppTypography.title.copyWith(color: AppColors.error),
            ),
            AppSpacing.verticalGapSm,
            Text(
              message,
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalGapLg,
            TextButton.icon(
              onPressed: _refresh,
              icon: Icon(Iconsax.refresh, size: 18),
              label: Text('ลองใหม่'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent1,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.monitor_heart_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            AppSpacing.verticalGapLg,
            Text(
              'ยังไม่มีข้อมูลสัญญาณชีพ',
              style: AppTypography.title,
            ),
            AppSpacing.verticalGapSm,
            Text(
              'ข้อมูลสัญญาณชีพจะแสดงที่นี่',
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row แสดงข้อมูลสัญญาณชีพแต่ละรายการ (แบบ list)
class _VitalSignRow extends StatelessWidget {
  final VitalSign vitalSign;
  final Color backgroundColor;

  const _VitalSignRow({
    required this.vitalSign,
    required this.backgroundColor,
  });

  String _formatDateTime(DateTime dateTime) {
    final thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final day = dateTime.day;
    final month = thaiMonths[dateTime.month - 1];
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day $month $hour:$minute น.';
  }

  /// คำนวณเวรจากเวลา
  String _getShift(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour >= 7 && hour < 15) {
      return 'เวรเช้า';
    } else if (hour >= 15 && hour < 23) {
      return 'เวรบ่าย';
    } else {
      return 'เวรดึก';
    }
  }

  /// สีของแถบเวร
  Color _getShiftColor(String shift) {
    switch (shift) {
      case 'เวรเช้า':
        return AppColors.warning;
      case 'เวรบ่าย':
        return AppColors.tertiary;
      case 'เวรดึก':
        return AppColors.secondary;
      default:
        return AppColors.secondaryText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = _getShift(vitalSign.createdAt);
    final shiftColor = _getShiftColor(shift);

    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('แก้ไขสัญญาณชีพ - Coming Soon'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        color: backgroundColor,
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            // Shift indicator bar
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Container(
                width: 6,
                height: 44,
                decoration: BoxDecoration(
                  color: shiftColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date time row
                  Row(
                    children: [
                      Text(
                        _formatDateTime(vitalSign.createdAt),
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Vital signs values
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildVitalText(
                        'BP ${vitalSign.bpDisplay}',
                        vitalSign.bpStatus,
                      ),
                      _buildVitalText(
                        'T ${vitalSign.tempDisplay}',
                        vitalSign.tempStatus,
                      ),
                      _buildVitalText(
                        'PR ${vitalSign.pulseDisplay}',
                        vitalSign.pulseStatus,
                      ),
                      if (vitalSign.respiratoryRate != null)
                        _buildVitalText(
                          'RR ${vitalSign.rrDisplay}',
                          vitalSign.rrStatus,
                        ),
                      _buildVitalText(
                        'O2 ${vitalSign.spO2Display}',
                        vitalSign.spO2Status,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Share button
            Padding(
              padding: EdgeInsets.only(left: 12),
              child: InkWell(
                onTap: () => _showShareOptions(context),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent1,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Iconsax.export_1,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalText(String text, VitalStatus status) {
    return Text(
      text,
      style: AppTypography.bodySmall.copyWith(
        color: status.textColor,
      ),
    );
  }

  void _showShareOptions(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('แชร์สัญญาณชีพ - Coming Soon'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Navigate to Vital Sign Log Screen
void navigateToVitalSignLog(
  BuildContext context, {
  required int residentId,
  required String residentName,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => VitalSignLogScreen(
        residentId: residentId,
        residentName: residentName,
      ),
    ),
  );
}
