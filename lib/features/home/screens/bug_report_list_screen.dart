// หน้า List แสดงรายการ Bug Reports ที่เคย submit
// แสดง status ของแต่ละ ticket และมีปุ่มสร้าง report ใหม่

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../models/bug_report.dart';
import '../services/bug_report_service.dart';
import '../widgets/bug_report_form.dart';

/// หน้า List แสดง Bug Reports ที่เคย submit ทั้งหมด
class BugReportListScreen extends StatefulWidget {
  const BugReportListScreen({super.key});

  @override
  State<BugReportListScreen> createState() => _BugReportListScreenState();
}

class _BugReportListScreenState extends State<BugReportListScreen> {
  // ใช้ Future เพื่อโหลดข้อมูลครั้งแรกและ refresh ได้
  late Future<List<BugReport>> _bugReportsFuture;

  @override
  void initState() {
    super.initState();
    _loadBugReports();
  }

  /// โหลด bug reports จาก service
  void _loadBugReports() {
    _bugReportsFuture = BugReportService.instance.getMyBugReports();
  }

  /// Refresh list
  Future<void> _refreshList() async {
    setState(() {
      _loadBugReports();
    });
  }

  /// เปิด dialog สร้าง bug report ใหม่
  void _openCreateDialog() {
    showBugReportDialog(context).then((_) {
      // Refresh list เมื่อปิด dialog (อาจมี report ใหม่)
      _refreshList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: IreneSecondaryAppBar(
        title: 'รายงานปัญหา/Bug',
        titleIcon: HugeIcons.strokeRoundedBug01,
      ),
      // FAB สำหรับสร้าง bug report ใหม่
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedAdd01,
          color: Colors.white,
          size: AppIconSize.md,
        ),
        label: const Text('รายงานใหม่'),
      ),
      body: FutureBuilder<List<BugReport>>(
        future: _bugReportsFuture,
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          // Data state
          final reports = snapshot.data ?? [];

          // Empty state
          if (reports.isEmpty) {
            return _buildEmptyState();
          }

          // List of bug reports
          return RefreshIndicator(
            onRefresh: _refreshList,
            child: ListView.builder(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 100, // เว้นที่ให้ FAB
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                return _BugReportCard(
                  report: reports[index],
                  onTap: () => _showReportDetail(reports[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// แสดงรายละเอียด bug report (bottom sheet)
  void _showReportDetail(BugReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _BugReportDetailSheet(report: report),
    );
  }

  /// Empty state - ยังไม่เคยรายงานปัญหา
  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _refreshList,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  size: AppIconSize.display,
                  color: AppColors.alternate,
                ),
                AppSpacing.verticalGapMd,
                Text(
                  'ยังไม่มีรายงานปัญหา',
                  style: AppTypography.title.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                AppSpacing.verticalGapSm,
                Text(
                  'กดปุ่ม "รายงานใหม่" เพื่อแจ้งปัญหาที่พบ',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Error state
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: AppIconSize.display,
            color: AppColors.error,
          ),
          AppSpacing.verticalGapMd,
          Text('เกิดข้อผิดพลาด', style: AppTypography.title),
          AppSpacing.verticalGapSm,
          Padding(
            padding: AppSpacing.paddingHorizontalMd,
            child: Text(
              error,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          AppSpacing.verticalGapLg,
          ElevatedButton.icon(
            onPressed: _refreshList,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Bug Report Card Widget
// =============================================================================

/// Card สำหรับแสดง Bug Report ในหน้า list
class _BugReportCard extends StatelessWidget {
  final BugReport report;
  final VoidCallback onTap;

  const _BugReportCard({
    required this.report,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _getCardBackgroundColor(),
        borderRadius: AppRadius.smallRadius,
        border: Border.all(
          color: report.statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smallRadius,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status indicator (แถบสีด้านซ้าย)
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: report.statusColor,
                    borderRadius: AppRadius.smallRadius,
                  ),
                ),
                AppSpacing.horizontalGapMd,

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Activity description + Status badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              report.activityDescription,
                              style: AppTypography.title.copyWith(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AppSpacing.horizontalGapSm,
                          _buildStatusBadge(),
                        ],
                      ),

                      AppSpacing.verticalGapXs,

                      // เวลาที่เกิดบัค + วันที่รายงาน
                      Text(
                        _buildSubtitle(),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      AppSpacing.verticalGapSm,

                      // Platform + Version + Attachments count
                      Row(
                        children: [
                          // Platform badge
                          _buildPlatformBadge(),
                          AppSpacing.horizontalGapSm,
                          // Version
                          Text(
                            'v${report.appVersion}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const Spacer(),
                          // Attachments count
                          if (report.hasAttachments) ...[
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedAttachment01,
                              size: AppIconSize.sm,
                              color: AppColors.secondaryText,
                            ),
                            AppSpacing.horizontalGapXs,
                            Text(
                              '${report.attachmentCount}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                AppSpacing.horizontalGapSm,

                // Arrow
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: AppIconSize.md,
                  color: AppColors.secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// สร้างข้อความ subtitle (เวลาที่เกิดบัค + วันที่รายงาน)
  String _buildSubtitle() {
    final dateFormat = DateFormat('dd/MM/yy HH:mm');
    final parts = <String>[];

    parts.add('เกิดเมื่อ ${dateFormat.format(report.bugOccurredAt)}');

    if (report.createdAt != null) {
      parts.add('รายงาน ${dateFormat.format(report.createdAt!)}');
    }

    return parts.join(' | ');
  }

  /// สร้าง status badge
  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: report.statusColor.withValues(alpha: 0.15),
        borderRadius: AppRadius.smallRadius,
        border: Border.all(
          color: report.statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        report.statusText,
        style: AppTypography.caption.copyWith(
          color: report.statusColor,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  /// สร้าง platform badge (android/ios/etc)
  Widget _buildPlatformBadge() {
    final icon = _getPlatformIcon();
    final color = _getPlatformColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.smallRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            report.platform,
            style: AppTypography.caption.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// ดึง icon ตาม platform
  dynamic _getPlatformIcon() {
    switch (report.platform.toLowerCase()) {
      case 'android':
        return HugeIcons.strokeRoundedSmartPhone01;
      case 'ios':
        return HugeIcons.strokeRoundedApple;
      case 'web':
        return HugeIcons.strokeRoundedBrowser;
      case 'windows':
        return HugeIcons.strokeRoundedComputer;
      default:
        return HugeIcons.strokeRoundedSmartPhone01;
    }
  }

  /// ดึงสีตาม platform
  Color _getPlatformColor() {
    switch (report.platform.toLowerCase()) {
      case 'android':
        return const Color(0xFF3DDC84); // Android green
      case 'ios':
        return const Color(0xFF007AFF); // iOS blue
      case 'web':
        return const Color(0xFFFF6D00); // Web orange
      case 'windows':
        return const Color(0xFF0078D4); // Windows blue
      default:
        return AppColors.secondaryText;
    }
  }

  /// สีพื้นหลัง card ตาม status
  Color _getCardBackgroundColor() {
    switch (report.status) {
      case 'open':
        return const Color(0xFFFFF7ED); // Warm orange tint
      case 'in_progress':
        return const Color(0xFFEFF6FF); // Light blue tint
      case 'resolved':
        return const Color(0xFFF0FDF4); // Light green tint
      case 'wont_fix':
        return const Color(0xFFF9FAFB); // Light gray tint
      default:
        return AppColors.secondaryBackground;
    }
  }
}

// =============================================================================
// Bug Report Detail Sheet
// =============================================================================

/// Bottom sheet แสดงรายละเอียด Bug Report
class _BugReportDetailSheet extends StatelessWidget {
  final BugReport report;

  const _BugReportDetailSheet({required this.report});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.alternate,
                      borderRadius: AppRadius.fullRadius,
                    ),
                  ),
                ),
                AppSpacing.verticalGapMd,

                // Header: Status badge + ID
                Row(
                  children: [
                    _buildStatusBadge(),
                    const Spacer(),
                    if (report.id != null)
                      Text(
                        '#${report.id!.substring(0, 8)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryText,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),

                AppSpacing.verticalGapMd,

                // Activity description (title)
                Text(
                  report.activityDescription,
                  style: AppTypography.heading3,
                ),

                AppSpacing.verticalGapMd,

                // Info rows
                _buildInfoRow(
                  icon: HugeIcons.strokeRoundedClock01,
                  label: 'เวลาที่เกิดบัค',
                  value: _formatDateTime(report.bugOccurredAt),
                ),
                _buildInfoRow(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  label: 'วันที่รายงาน',
                  value: report.createdAt != null
                      ? _formatDateTime(report.createdAt!)
                      : '-',
                ),
                _buildInfoRow(
                  icon: HugeIcons.strokeRoundedSmartPhone01,
                  label: 'Platform',
                  value: '${report.platform} • v${report.appVersion}',
                ),
                if (report.buildNumber != null)
                  _buildInfoRow(
                    icon: HugeIcons.strokeRoundedCode,
                    label: 'Build',
                    value: report.buildNumber!,
                  ),

                // Additional notes
                if (report.additionalNotes != null &&
                    report.additionalNotes!.isNotEmpty) ...[
                  AppSpacing.verticalGapMd,
                  Text('รายละเอียดเพิ่มเติม', style: AppTypography.subtitle),
                  AppSpacing.verticalGapSm,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: AppRadius.smallRadius,
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Text(
                      report.additionalNotes!,
                      style: AppTypography.body.copyWith(
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ],

                // Admin notes (ถ้ามี)
                if (report.adminNotes != null &&
                    report.adminNotes!.isNotEmpty) ...[
                  AppSpacing.verticalGapMd,
                  Text('หมายเหตุจากทีมงาน', style: AppTypography.subtitle),
                  AppSpacing.verticalGapSm,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.smallRadius,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      report.adminNotes!,
                      style: AppTypography.body.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],

                // Attachments
                if (report.hasAttachments) ...[
                  AppSpacing.verticalGapMd,
                  Text(
                    'ไฟล์แนบ (${report.attachmentCount})',
                    style: AppTypography.subtitle,
                  ),
                  AppSpacing.verticalGapSm,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: report.attachmentUrls.map((url) {
                      return _buildAttachmentThumbnail(context, url);
                    }).toList(),
                  ),
                ],

                // เว้นที่ด้านล่าง
                AppSpacing.verticalGapXl,
              ],
            ),
          ),
        );
      },
    );
  }

  /// สร้าง status badge แบบใหญ่
  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: report.statusColor.withValues(alpha: 0.15),
        borderRadius: AppRadius.smallRadius,
        border: Border.all(
          color: report.statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: report.statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            report.statusText,
            style: AppTypography.subtitle.copyWith(
              color: report.statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// สร้าง info row
  Widget _buildInfoRow({
    required dynamic icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          HugeIcon(
            icon: icon,
            size: AppIconSize.md,
            color: AppColors.secondaryText,
          ),
          AppSpacing.horizontalGapSm,
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// สร้าง thumbnail สำหรับไฟล์แนบ
  Widget _buildAttachmentThumbnail(BuildContext context, String url) {
    final isVideo = url.toLowerCase().contains('.mp4') ||
        url.toLowerCase().contains('.mov') ||
        url.toLowerCase().contains('.avi');

    return GestureDetector(
      onTap: () => _openFullImage(context, url),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadius.smallRadius,
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.smallRadius,
          child: isVideo
              ? Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedVideo01,
                    size: AppIconSize.lg,
                    color: AppColors.secondaryText,
                  ),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedImage01,
                      size: AppIconSize.lg,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// เปิดรูปขนาดเต็ม
  void _openFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(url),
          ),
        ),
      ),
    );
  }

  /// Format DateTime
  String _formatDateTime(DateTime dt) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }
}
