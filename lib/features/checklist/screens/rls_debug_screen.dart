import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';

/// หน้า Debug สำหรับดูข้อมูลจาก 3 tables ที่ยังไม่มี RLS ที่ถูกต้อง:
/// 1. user_task_seen (RLS ปิด)
/// 2. task_log_line_queue (RLS ปิด)
/// 3. A_Task_logs_ver2 (RLS เปิด แต่ policy = allow_all_temp)
///
/// ใช้เพื่อทดสอบว่าเมื่อเปิด/แก้ RLS แล้ว ข้อมูลยังเข้าถึงได้ถูกต้องไหม
class RlsDebugScreen extends StatefulWidget {
  const RlsDebugScreen({super.key});

  @override
  State<RlsDebugScreen> createState() => _RlsDebugScreenState();
}

class _RlsDebugScreenState extends State<RlsDebugScreen> {
  final _supabase = Supabase.instance.client;

  // สถานะ loading/error
  bool _isLoading = true;
  String? _error;

  // ข้อมูลจากแต่ละ table
  List<Map<String, dynamic>> _userTaskSeenRows = [];
  List<Map<String, dynamic>> _taskLogLineQueueRows = [];
  List<Map<String, dynamic>> _taskLogsRows = [];

  // จำนวน records ทั้งหมด (count)
  int _userTaskSeenCount = 0;
  int _taskLogLineQueueCount = 0;
  int _taskLogsCount = 0;

  // เปิด/ปิด แต่ละ section
  final Map<String, bool> _expanded = {
    'user_task_seen': false,
    'task_log_line_queue': false,
    'A_Task_logs_ver2': false,
  };

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  /// โหลดข้อมูลจาก 3 tables พร้อมกัน
  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Query ข้อมูล 3 tables พร้อมกัน (parallel)
      final dataResults = await Future.wait([
        _supabase
            .from('user_task_seen')
            .select()
            .order('created_at', ascending: false)
            .limit(20),
        _supabase
            .from('task_log_line_queue')
            .select()
            .order('created_at', ascending: false)
            .limit(20),
        _supabase
            .from('A_Task_logs_ver2')
            .select()
            .order('created_at', ascending: false)
            .limit(20),
      ]);

      // Count queries แยก เพราะ return type ต่างจาก select()
      final countResults = await Future.wait([
        _supabase
            .from('user_task_seen')
            .select('id')
            .count(CountOption.exact),
        _supabase
            .from('task_log_line_queue')
            .select('id')
            .count(CountOption.exact),
        _supabase
            .from('A_Task_logs_ver2')
            .select('id')
            .count(CountOption.exact),
      ]);

      if (!mounted) return;

      setState(() {
        _userTaskSeenRows =
            List<Map<String, dynamic>>.from(dataResults[0]);
        _taskLogLineQueueRows =
            List<Map<String, dynamic>>.from(dataResults[1]);
        _taskLogsRows =
            List<Map<String, dynamic>>.from(dataResults[2]);

        _userTaskSeenCount = countResults[0].count;
        _taskLogLineQueueCount = countResults[1].count;
        _taskLogsCount = countResults[2].count;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// สลับเปิด/ปิด section
  void _toggleSection(String key) {
    setState(() {
      _expanded[key] = !(_expanded[key] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('RLS Debug'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadAllData,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: AppSpacing.md),

                      // Table 1: user_task_seen
                      _buildExpandableSection(
                        key: 'user_task_seen',
                        title: 'user_task_seen',
                        rlsStatus: 'RLS ปิด',
                        rlsColor: Colors.red,
                        policyInfo: '6 policies รอเปิด',
                        totalCount: _userTaskSeenCount,
                        rows: _userTaskSeenRows,
                        columns: [
                          'id',
                          'user_id',
                          'Task_seen_id',
                          'created_at'
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Table 2: task_log_line_queue
                      _buildExpandableSection(
                        key: 'task_log_line_queue',
                        title: 'task_log_line_queue',
                        rlsStatus: 'RLS ปิด',
                        rlsColor: Colors.red,
                        policyInfo: '2 policies รอเปิด',
                        totalCount: _taskLogLineQueueCount,
                        rows: _taskLogLineQueueRows,
                        columns: [
                          'id',
                          'log_id',
                          'status',
                          'nursinghome_id',
                          'created_at'
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Table 3: A_Task_logs_ver2
                      _buildExpandableSection(
                        key: 'A_Task_logs_ver2',
                        title: 'A_Task_logs_ver2',
                        rlsStatus: 'allow_all_temp',
                        rlsColor: Colors.orange,
                        policyInfo: 'RLS เปิด แต่ policy = true',
                        totalCount: _taskLogsCount,
                        rows: _taskLogsRows,
                        columns: [
                          'id',
                          'task_id',
                          'status',
                          'nursinghome_id',
                          'completed_by',
                          'created_at'
                        ],
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
    );
  }

  /// Card อธิบายว่าหน้านี้ใช้ทำอะไร
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RLS Debug - ตรวจสอบข้อมูล',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'แสดงข้อมูลจาก 3 tables ที่ยังไม่มี RLS ที่ถูกต้อง\n'
            'ใช้ทดสอบว่าเมื่อแก้ RLS แล้ว ข้อมูลยังเข้าถึงได้ถูกต้อง',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Section แบบ expandable สำหรับแต่ละ table
  /// กดที่ header เพื่อเปิด/ปิด ดู data table ด้านใน
  Widget _buildExpandableSection({
    required String key,
    required String title,
    required String rlsStatus,
    required Color rlsColor,
    required String policyInfo,
    required int totalCount,
    required List<Map<String, dynamic>> rows,
    required List<String> columns,
  }) {
    final isExpanded = _expanded[key] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [AppShadows.subtle],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ===== Header (กดเพื่อ expand/collapse) =====
          InkWell(
            onTap: () => _toggleSection(key),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: rlsColor.withValues(alpha: 0.08),
              ),
              child: Row(
                children: [
                  // ชื่อ table + policy info + row count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.subtitle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$policyInfo  |  $totalCount records'
                          '${rows.isEmpty ? "  (BLOCKED!)" : ""}',
                          style: AppTypography.caption.copyWith(
                            color: rows.isEmpty
                                ? Colors.red
                                : AppColors.secondaryText,
                            fontWeight:
                                rows.isEmpty ? FontWeight.bold : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // RLS badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: rlsColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      rlsStatus,
                      style: AppTypography.caption.copyWith(
                        color: rlsColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ลูกศรเปิด/ปิด
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ===== Body (DataTable - แสดงเมื่อ expand) =====
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildDataTableBody(rows, columns),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  /// เนื้อหา DataTable ด้านใน
  Widget _buildDataTableBody(
    List<Map<String, dynamic>> rows,
    List<String> columns,
  ) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'ไม่มีข้อมูล (อาจถูก RLS block)',
            style: AppTypography.body.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: DataTable(
        columnSpacing: 16,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 48,
        headingRowHeight: 40,
        horizontalMargin: AppSpacing.md,
        columns: columns
            .map((col) => DataColumn(
                  label: Text(
                    col,
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                ))
            .toList(),
        rows: rows.map((row) {
          return DataRow(
            cells: columns.map((col) {
              final value = row[col];
              final display = _formatValue(value, col);
              return DataCell(
                Text(
                  display,
                  style: AppTypography.caption.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  /// Format ค่าให้อ่านง่าย
  String _formatValue(dynamic value, String columnName) {
    if (value == null) return '-';

    // ตัด timezone ออกจาก timestamp ให้สั้นลง
    if (columnName.contains('created_at') || columnName.contains('at')) {
      final str = value.toString();
      if (str.length > 16) {
        return str.substring(0, 16).replaceFirst('T', ' ');
      }
    }

    // ตัด UUID ให้สั้นลง (แสดงแค่ 8 ตัวแรก)
    if (columnName.contains('_by') || columnName == 'user_id') {
      final str = value.toString();
      if (str.length > 8) {
        return '${str.substring(0, 8)}...';
      }
    }

    return value.toString();
  }

  /// แสดง error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: AppSpacing.md),
            Text(
              'เกิดข้อผิดพลาด',
              style: AppTypography.subtitle.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error ?? '',
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loadAllData,
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}
