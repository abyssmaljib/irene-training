import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/resident_detail.dart';
import '../providers/resident_detail_provider.dart';
import '../widgets/resident_detail/collapsible_header.dart';
import '../widgets/resident_detail/view_segmented_control.dart';
import '../widgets/resident_detail/care_dashboard_view.dart';
import '../widgets/resident_detail/clinical_view_placeholder.dart';
import '../widgets/resident_detail/profile_info_view.dart';
import '../widgets/resident_detail/quick_action_fab.dart';

/// หน้า Resident Detail - แสดงข้อมูลรายละเอียดของ Resident
/// มี 3 Views: Care Dashboard, Clinical, Profile & Info
class ResidentDetailScreen extends ConsumerStatefulWidget {
  final int residentId;

  const ResidentDetailScreen({
    super.key,
    required this.residentId,
  });

  @override
  ConsumerState<ResidentDetailScreen> createState() => _ResidentDetailScreenState();
}

class _ResidentDetailScreenState extends ConsumerState<ResidentDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final residentAsync = ref.watch(residentDetailProvider(widget.residentId));
    final selectedView = ref.watch(selectedViewProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: residentAsync.when(
        loading: () => _buildLoading(),
        error: (error, stack) => _buildError(error.toString()),
        data: (resident) {
          if (resident == null) {
            return _buildError('ไม่พบข้อมูล Resident');
          }
          return _buildContent(resident, selectedView);
        },
      ),
      floatingActionButton: residentAsync.whenOrNull(
        data: (resident) => selectedView == DetailViewType.care && resident != null
            ? QuickActionFab(
                residentId: widget.residentId,
                residentName: resident.name,
              )
            : null,
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'กำลังโหลดข้อมูล...',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
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
            Icon(
              Iconsax.warning_2,
              size: 64,
              color: AppColors.error,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'เกิดข้อผิดพลาด',
              style: AppTypography.heading2.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(residentDetailProvider(widget.residentId));
              },
              icon: Icon(Iconsax.refresh),
              label: Text('ลองใหม่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ResidentDetail resident, DetailViewType selectedView) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          // Collapsible Header with Avatar + Info
          CollapsibleResidentHeader(
            resident: resident,
            expandedHeight: 148,
            onBackPressed: () => Navigator.of(context).pop(),
            onCallPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('โทรหาญาติ - Coming Soon')),
              );
            },
            onMorePressed: () => _showMoreOptions(context),
            onShowMoreDiseases: () {
              // ไปที่ INFO tab เพื่อดูโรคประจำตัวทั้งหมด
              ref.read(selectedViewProvider.notifier).state = DetailViewType.info;
              // Trigger highlight animation
              ref.read(highlightUnderlyingDiseasesProvider.notifier).state = true;
            },
          ),
          // Sticky Segmented Control
          SliverPersistentHeader(
            pinned: true,
            delegate: _SegmentedControlDelegate(
              child: ViewSegmentedControl(
                selectedView: selectedView,
                onViewChanged: (view) {
                  ref.read(selectedViewProvider.notifier).state = view;
                },
              ),
            ),
          ),
        ];
      },
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(residentDetailProvider(widget.residentId));
          ref.invalidate(latestVitalSignProvider(widget.residentId));
        },
        color: AppColors.primary,
        child: _buildViewContent(resident, selectedView),
      ),
    );
  }

  Widget _buildViewContent(ResidentDetail resident, DetailViewType view) {
    final vitalSignAsync = ref.watch(latestVitalSignProvider(widget.residentId));

    switch (view) {
      case DetailViewType.care:
        return CareDashboardView(
          resident: resident,
          vitalSign: vitalSignAsync.valueOrNull,
          isLoadingVitalSign: vitalSignAsync.isLoading,
        );
      case DetailViewType.clinical:
        return ClinicalViewPlaceholder();
      case DetailViewType.info:
        return ProfileInfoView(resident: resident);
    }
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                _buildOptionItem(
                  icon: Iconsax.edit,
                  label: 'แก้ไขข้อมูล',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('แก้ไขข้อมูล - Coming Soon')),
                    );
                  },
                ),
                _buildOptionItem(
                  icon: Iconsax.document_text,
                  label: 'ดูประวัติทั้งหมด',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('ประวัติทั้งหมด - Coming Soon')),
                    );
                  },
                ),
                _buildOptionItem(
                  icon: Iconsax.printer,
                  label: 'พิมพ์รายงาน',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('พิมพ์รายงาน - Coming Soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        label,
        style: AppTypography.body.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

/// Delegate สำหรับ Sticky Segmented Control
class _SegmentedControlDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SegmentedControlDelegate({required this.child});

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SegmentedControlDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
