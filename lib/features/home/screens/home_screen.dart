import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../learning/screens/directory_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/zone.dart';
import '../services/zone_service.dart';

/// หน้าหลัก - Dashboard
/// แสดง Zone, คนไข้, งาน, ข่าว, เวร
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _zoneService = ZoneService();

  List<Zone> _zones = [];
  Zone? _selectedZone;
  bool _isLoadingZones = true;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    final zones = await _zoneService.getZones();
    if (mounted) {
      setState(() {
        _zones = zones;
        // ถ้ายังไม่ได้เลือก zone ให้เลือก zone แรก
        if (_selectedZone == null && zones.isNotEmpty) {
          _selectedZone = zones.first;
        }
        _isLoadingZones = false;
      });
    }
  }

  void _showZoneSelector() {
    if (_zones.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.alternate,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AppSpacing.verticalGapLg,
            Text('เลือก Zone', style: AppTypography.heading3),
            AppSpacing.verticalGapMd,
            ..._zones.map((zone) => ListTile(
              leading: Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: _selectedZone?.id == zone.id
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.accent1,
                  borderRadius: AppRadius.smallRadius,
                ),
                child: Icon(
                  Iconsax.location,
                  color: _selectedZone?.id == zone.id
                      ? AppColors.primary
                      : AppColors.secondaryText,
                  size: 20,
                ),
              ),
              title: Text(
                zone.name,
                style: AppTypography.body.copyWith(
                  fontWeight: _selectedZone?.id == zone.id
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                '${zone.residentCount} คนไข้',
                style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
              ),
              trailing: _selectedZone?.id == zone.id
                  ? Icon(Iconsax.tick_circle5, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() {
                  _selectedZone = zone;
                });
                Navigator.pop(context);
              },
            )),
            AppSpacing.verticalGapMd,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadZones,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // IreneAppBar
            IreneAppBar(
              title: 'IRENE',
              onProfileTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            // Body content
            SliverPadding(
              padding: EdgeInsets.all(AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildZoneCard(),
                  AppSpacing.verticalGapMd,
                  _buildBreakTimeCard(),
                  AppSpacing.verticalGapMd,
                  _buildTaskProgressCard(),
                  AppSpacing.verticalGapMd,
                  _buildLearningCard(context),
                  AppSpacing.verticalGapMd,
                  _buildNewsCard(),
                  AppSpacing.verticalGapMd,
                  _buildShiftCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildZoneCard() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: [AppShadows.subtle],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.accent1,
              borderRadius: AppRadius.smallRadius,
            ),
            child: Icon(Iconsax.location, color: AppColors.primary),
          ),
          AppSpacing.horizontalGapMd,
          Expanded(
            child: _isLoadingZones
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.alternate,
                          borderRadius: AppRadius.smallRadius,
                        ),
                      ),
                      AppSpacing.verticalGapXs,
                      Container(
                        width: 60,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.alternate,
                          borderRadius: AppRadius.smallRadius,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedZone?.name ?? 'ยังไม่ได้เลือก Zone',
                        style: AppTypography.title,
                      ),
                      Text(
                        _selectedZone != null
                            ? '${_selectedZone!.residentCount} คนไข้'
                            : '-',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
                      ),
                    ],
                  ),
          ),
          TextButton(
            onPressed: _zones.isNotEmpty ? _showZoneSelector : null,
            child: Text('เปลี่ยน'),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakTimeCard() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.pastelYellow1.withValues(alpha: 0.5),
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Row(
        children: [
          Icon(Iconsax.coffee, color: AppColors.tagPendingText),
          AppSpacing.horizontalGapMd,
          Text(
            'เวลาพักวันนี้: 12:00 - 12:20 น.',
            style: AppTypography.body.copyWith(color: AppColors.tagPendingText),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskProgressCard() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: [AppShadows.subtle],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Iconsax.task_square, color: AppColors.primary, size: 20),
                  AppSpacing.horizontalGapSm,
                  Text('งานในเวรนี้', style: AppTypography.title),
                ],
              ),
              Text('89/120', style: AppTypography.body.copyWith(color: AppColors.secondaryText)),
            ],
          ),
          AppSpacing.verticalGapMd,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 89 / 120,
              backgroundColor: AppColors.alternate,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
          AppSpacing.verticalGapMd,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ดูเช็คลิสต์'),
                  AppSpacing.horizontalGapXs,
                  Icon(Iconsax.arrow_right_3, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DirectoryScreen()),
        );
      },
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          boxShadow: [AppShadows.subtle],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.book_1, color: AppColors.secondary, size: 20),
                    AppSpacing.horizontalGapSm,
                    Text('เรียนรู้ไตรมาสนี้', style: AppTypography.title),
                  ],
                ),
                Text('40%', style: AppTypography.body.copyWith(color: AppColors.secondaryText)),
              ],
            ),
            AppSpacing.verticalGapMd,
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.4,
                backgroundColor: AppColors.alternate,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                minHeight: 8,
              ),
            ),
            AppSpacing.verticalGapSm,
            Row(
              children: [
                Icon(Iconsax.warning_2, color: AppColors.warning, size: 14),
                AppSpacing.horizontalGapXs,
                Text(
                  'มี 2 บทยังไม่สอบ',
                  style: AppTypography.caption.copyWith(color: AppColors.warning),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: [AppShadows.subtle],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Iconsax.document_text, color: AppColors.tertiary, size: 20),
                  AppSpacing.horizontalGapSm,
                  Text('ข่าวล่าสุด', style: AppTypography.title),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: Text('ดูทั้งหมด'),
              ),
            ],
          ),
          AppSpacing.verticalGapSm,
          _buildNewsItem('คุณสมศรี - อัพเดตอาการวันนี้', '10 นาทีที่แล้ว'),
          _buildNewsItem('ประกาศ: ตารางเวรเดือนมกราคม', '1 ชั่วโมงที่แล้ว'),
        ],
      ),
    );
  }

  Widget _buildNewsItem(String title, String time) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            time,
            style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: [AppShadows.subtle],
      ),
      child: Row(
        children: [
          Icon(Iconsax.calendar_1, color: AppColors.primary, size: 20),
          AppSpacing.horizontalGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('เวรของฉัน', style: AppTypography.title),
                Text(
                  'เดือนนี้: ทำแล้ว 12 / เหลือ 8 เวร',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          Icon(Iconsax.arrow_right_3, size: 16, color: AppColors.secondaryText),
        ],
      ),
    );
  }
}
