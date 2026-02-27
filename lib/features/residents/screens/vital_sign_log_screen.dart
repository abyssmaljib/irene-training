import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../models/vital_sign.dart';
import '../services/resident_detail_service.dart';
import 'edit_vital_sign_screen.dart';
import '../../../core/widgets/shimmer_loading.dart';

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
  bool _hasUpdates = false; // Track if any update occurred

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_hasUpdates);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: IreneSecondaryAppBar(
          backgroundColor: AppColors.surface,
          onBack: () => Navigator.of(context).pop(_hasUpdates),
          // ใช้ titleWidget สำหรับ 2 บรรทัด
          titleWidget: Column(
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
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return ShimmerWrapper(
        isLoading: true,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: List.generate(5, (_) => const SkeletonListItem()),
          ),
        ),
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
            residentId: widget.residentId,
            residentName: widget.residentName,
            onUpdated: () {
              _hasUpdates = true;
              _refresh();
            },
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
            HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: AppIconSize.xxxl, color: AppColors.error),
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
              icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: AppIconSize.md),
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
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedFavourite,
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
  final int residentId;
  final String residentName;
  final VoidCallback? onUpdated;

  const _VitalSignRow({
    required this.vitalSign,
    required this.backgroundColor,
    required this.residentId,
    required this.residentName,
    this.onUpdated,
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
      onTap: () async {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => EditVitalSignScreen(
              vitalSignId: vitalSign.id,
              residentId: residentId,
              residentName: residentName,
            ),
          ),
        );
        // Refresh list if vital sign was updated or deleted
        if (result == true) {
          onUpdated?.call();
        }
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
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent1,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedShare01,
                      color: AppColors.primary,
                      size: AppIconSize.md,
                    ),
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
    AppToast.info(context, 'แชร์สัญญาณชีพ - Coming Soon');
  }
}

/// Navigate to Vital Sign Log Screen
/// Returns true if any vital sign was updated/deleted
Future<bool?> navigateToVitalSignLog(
  BuildContext context, {
  required int residentId,
  required String residentName,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => VitalSignLogScreen(
        residentId: residentId,
        residentName: residentName,
      ),
    ),
  );
}
