// หน้า List แสดงรายการ Tickets พร้อม Tab แบ่งตามสถานะ
// มี 5 tabs: ทั้งหมด, เปิด, ดำเนินการ, รอติดตาม, เสร็จสิ้น
// ใช้ pattern เดียวกับ incident_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';
import '../widgets/ticket_list_card.dart';
import 'ticket_detail_screen.dart';
import 'create_ticket_screen.dart';

/// หน้ารายการ Tickets พร้อม Tab แบ่งตามสถานะ
/// - ทั้งหมด: แสดง ticket ทุกสถานะ
/// - เปิด: แสดงเฉพาะ ticket ที่ยังไม่มีใครรับ
/// - ดำเนินการ: แสดงเฉพาะ ticket ที่กำลังทำอยู่
/// - รอติดตาม: แสดงเฉพาะ ticket ที่รอผลลัพธ์
/// - เสร็จสิ้น: แสดงเฉพาะ ticket ที่จบแล้ว
class TicketListScreen extends ConsumerStatefulWidget {
  const TicketListScreen({super.key});

  @override
  ConsumerState<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends ConsumerState<TicketListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // สถานะที่สัมพันธ์กับแต่ละ tab
  // null = ทั้งหมด (ไม่กรอง)
  static const _tabStatuses = [
    null, // ทั้งหมด
    TicketStatus.open, // เปิด
    TicketStatus.inProgress, // กำลังดำเนินการ
    TicketStatus.awaitingFollowUp, // รอติดตาม
    TicketStatus.resolved, // เสร็จสิ้น
  ];

  // ข้อมูล tab แต่ละอัน (label, icon, key สำหรับนับจำนวน)
  static const _tabs = [
    _TabData(
      label: 'ทั้งหมด',
      icon: HugeIcons.strokeRoundedDashboardSquare01,
      countKey: 'all',
    ),
    _TabData(
      label: 'เปิด',
      icon: HugeIcons.strokeRoundedCircle,
      countKey: 'open',
    ),
    _TabData(
      label: 'ดำเนินการ',
      icon: HugeIcons.strokeRoundedLoading03,
      countKey: 'in_progress',
    ),
    _TabData(
      label: 'รอติดตาม',
      icon: HugeIcons.strokeRoundedClock01,
      countKey: 'awaiting_follow_up',
    ),
    _TabData(
      label: 'เสร็จสิ้น',
      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
      countKey: 'resolved',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // สร้าง TabController สำหรับ 5 tabs
    _tabController = TabController(length: _tabs.length, vsync: this);
    // ฟัง tab change เพื่ออัปเดต filter provider
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    // ลบ listener ก่อน dispose เพื่อป้องกัน memory leak
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// เมื่อ tab เปลี่ยน → อัปเดต ticketFilterTabProvider
  /// ใช้ indexIsChanging เพื่อให้ trigger เฉพาะตอนเปลี่ยนเสร็จ
  /// (ไม่ใช่ตอน animation กำลังเล่น)
  void _onTabChanged() {
    // ตรวจ mounted ก่อน — listener อาจ fire หลัง dispose ระหว่าง animation
    if (!mounted) return;
    if (!_tabController.indexIsChanging) {
      // อัปเดต filter status ตาม tab ที่เลือก
      ref.read(ticketFilterTabProvider.notifier).state =
          _tabStatuses[_tabController.index];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch filtered tickets เพื่อแสดงใน list
    final ticketsAsync = ref.watch(filteredTicketsProvider);

    // Watch counts เพื่อแสดง badge บน tab
    final counts = ref.watch(ticketCountsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: IreneSecondaryAppBar(
        title: 'ตั๋วงาน',
        titleIcon: HugeIcons.strokeRoundedTicket02,
        // TabBar อยู่ใต้ AppBar — scroll ได้เพราะมี 5 tabs
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // tabs เยอะ ต้อง scroll ได้
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle:
              AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTypography.body,
          tabAlignment: TabAlignment.start, // จัด tabs ชิดซ้าย
          tabs: _tabs.map((tab) {
            // ดึงจำนวน ticket ของ tab นี้จาก counts map
            final count = counts[tab.countKey] ?? 0;
            return Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab.label),
                  // แสดง badge count ถ้ามี ticket > 0
                  if (count > 0) ...[
                    AppSpacing.horizontalGapXs,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _getCountBadgeColor(tab.countKey),
                        borderRadius: AppRadius.fullRadius,
                      ),
                      child: Text(
                        '$count',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      // Body: แสดง list ตาม AsyncValue state (loading/error/data)
      body: ticketsAsync.when(
        data: (tickets) => _buildList(tickets),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(error.toString()),
      ),
      // FAB สำหรับสร้าง ticket ใหม่ (Sprint 3)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
          ).then((result) {
            if (!mounted) return;
            // ถ้าสร้าง ticket สำเร็จ (result = true) → refresh list
            if (result == true) {
              ref.read(refreshTicketsProvider)();
            }
          });
        },
        backgroundColor: AppColors.primary,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedAdd01,
          color: Colors.white,
          size: AppIconSize.xl,
        ),
      ),
    );
  }

  /// สร้าง list ของ tickets พร้อม pull-to-refresh
  /// ถ้า list ว่าง → แสดง empty state ที่ยังดึง refresh ได้
  Widget _buildList(List<Ticket> tickets) {
    return RefreshIndicator(
      onRefresh: () async {
        // เรียก refreshTicketsProvider เพื่อ force reload จาก Supabase
        await ref.read(refreshTicketsProvider)();
      },
      child: tickets.isEmpty
          ? _buildEmptyScrollable()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              // AlwaysScrollableScrollPhysics เพื่อให้ pull-to-refresh ทำงาน
              // แม้ content จะไม่เต็มหน้าจอ
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                return TicketListCard(
                  ticket: ticket,
                  onTap: () => _openDetailScreen(ticket),
                );
              },
            ),
    );
  }

  /// เปิดหน้า detail ของ ticket
  /// หลัง navigate กลับมา → refresh list เพื่อแสดงข้อมูลล่าสุด
  /// (เช่น ถ้า user เปลี่ยนสถานะ ticket ในหน้า detail)
  void _openDetailScreen(Ticket ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailScreen(ticket: ticket),
      ),
    ).then((_) {
      if (!mounted) return;
      // Refresh list เมื่อกลับมาจากหน้า detail
      // (เผื่อ user เปลี่ยนสถานะ/เพิ่ม comment)
      ref.read(refreshTicketsProvider)();
    });
  }

  /// Empty state ที่ scrollable ได้ เพื่อให้ RefreshIndicator ทำงาน
  /// ใช้ ListView แทน SingleChildScrollView เพื่อ compatibility กับ RefreshIndicator
  Widget _buildEmptyScrollable() {
    // กำหนดข้อความตาม tab ที่เลือกอยู่
    final currentTab = _tabController.index;
    String message;
    dynamic icon;

    switch (currentTab) {
      case 0: // ทั้งหมด
        message = 'ยังไม่มีตั๋วงาน';
        icon = HugeIcons.strokeRoundedInbox;
        break;
      case 1: // เปิด
        message = 'ไม่มีตั๋วที่เปิดอยู่';
        icon = HugeIcons.strokeRoundedCheckmarkCircle02;
        break;
      case 2: // ดำเนินการ
        message = 'ไม่มีตั๋วที่กำลังดำเนินการ';
        icon = HugeIcons.strokeRoundedLoading03;
        break;
      case 3: // รอติดตาม
        message = 'ไม่มีตั๋วที่รอติดตาม';
        icon = HugeIcons.strokeRoundedClock01;
        break;
      case 4: // เสร็จสิ้น
        message = 'ยังไม่มีตั๋วที่เสร็จสิ้น';
        icon = HugeIcons.strokeRoundedTaskDone01;
        break;
      default:
        message = 'ไม่มีตั๋วในหมวดนี้';
        icon = HugeIcons.strokeRoundedInbox;
    }

    return ListView(
      // ต้องใส่ AlwaysScrollableScrollPhysics เพื่อให้ RefreshIndicator ทำงาน
      // บน empty list (ถ้าไม่ใส่ จะ pull-to-refresh ไม่ได้)
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // เว้นระยะจากด้านบน ~25% ของหน้าจอ เพื่อให้ icon อยู่กลางๆ
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                size: AppIconSize.display,
                color: AppColors.alternate,
              ),
              AppSpacing.verticalGapMd,
              Text(
                message,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Error state — แสดงเมื่อโหลด tickets ไม่ได้
  /// มีปุ่ม "ลองใหม่" เพื่อ retry
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
          Text(
            'เกิดข้อผิดพลาด',
            style: AppTypography.title,
          ),
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
          // ปุ่ม retry — invalidate provider เพื่อ fetch ใหม่
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(allTicketsProvider),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              color: Colors.white,
              size: AppIconSize.md,
            ),
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

  /// กำหนดสี badge count ตาม tab
  /// - เปิด: สีเตือน (warning) เพราะต้องรีบจัดการ
  /// - ดำเนินการ: สีน้ำเงิน (info) แสดงว่ากำลังทำ
  /// - รอติดตาม: สีส้ม (warning) ต้องจับตา
  /// - เสร็จสิ้น: สีเขียว (primary) จบแล้ว
  /// - ทั้งหมด: สีเทา (neutral)
  Color _getCountBadgeColor(String countKey) {
    switch (countKey) {
      case 'open':
        return AppColors.error; // สีแดง — ยังไม่มีคนรับ
      case 'in_progress':
        return AppColors.info; // สีน้ำเงิน — กำลังทำ
      case 'awaiting_follow_up':
        return AppColors.warning; // สีส้ม — รอติดตาม
      case 'resolved':
        return AppColors.primary; // สีเขียว — เสร็จแล้ว
      case 'all':
      default:
        return AppColors.secondaryText; // สีเทา — แสดงจำนวนรวม
    }
  }
}

/// Data class สำหรับ Tab — เก็บข้อมูล label, icon, และ key สำหรับดึง count
class _TabData {
  /// ข้อความที่แสดงบน tab (ภาษาไทย)
  final String label;

  /// Icon ของ tab (ใช้ HugeIcons)
  final dynamic icon;

  /// Key สำหรับดึงจำนวนจาก ticketCountsProvider map
  /// เช่น 'all', 'open', 'in_progress', 'awaiting_follow_up', 'resolved'
  final String countKey;

  const _TabData({
    required this.label,
    required this.icon,
    required this.countKey,
  });
}
