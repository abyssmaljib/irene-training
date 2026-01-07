import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../learning/screens/directory_screen.dart';
import '../../navigation/screens/main_navigation_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/zone.dart';
import '../models/clock_in_out.dart';
import '../models/resident_simple.dart';
import '../models/break_time_option.dart';
import '../models/friend_break_time.dart';
import '../../../core/services/user_service.dart';
import '../services/zone_service.dart';
import '../services/home_service.dart';
import '../services/clock_service.dart';
import '../widgets/clock_in_section.dart';
import '../widgets/on_shift_card.dart';
import '../widgets/clock_out_dialog.dart';
import '../widgets/shift_activity_card.dart';
import '../widgets/monthly_summary_card.dart';
import '../../board/screens/required_posts_screen.dart';
import '../../shift_summary/services/shift_summary_service.dart';
import '../../shift_summary/models/monthly_summary.dart';
import '../../shift_summary/screens/shift_summary_screen.dart';
import 'time_block_detail_screen.dart';
import 'tarot_card_screen.dart';
import '../models/tarot_card.dart';
import '../widgets/tarot_core_value_card.dart';
import '../../dd_handover/widgets/dd_summary_card.dart';
import '../../dd_handover/screens/dd_list_screen.dart';
import '../../dd_handover/services/dd_service.dart';

/// หน้าหลัก - Dashboard with Clock-in/Clock-out
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _zoneService = ZoneService();
  final _homeService = HomeService.instance;
  final _clockService = ClockService.instance;
  final _userService = UserService();
  final _shiftSummaryService = ShiftSummaryService.instance;

  // Zone data
  List<Zone> _zones = [];
  bool _isLoadingZones = true;

  // Clock state
  ClockInOut? _currentShift;
  bool _isLoadingShift = true;
  bool _isClockingIn = false;
  final bool _isClockingOut = false;

  // Clock-in form state
  Set<int> _selectedZoneIds = {};
  Set<int> _selectedResidentIds = {};
  Set<int> _selectedBreakTimeIds = {};
  List<ResidentSimple> _availableResidents = [];
  List<BreakTimeOption> _breakTimeOptions = [];
  Set<int> _occupiedResidentIds = {}; // คนไข้ที่เพื่อนเลือกไปแล้ว
  Map<int, List<FriendBreakTime>> _occupiedBreakTimes = {}; // เวลาพักที่เพื่อนร่วมโซนเลือกไปแล้ว
  String? _currentUserName; // ชื่อ user ปัจจุบัน
  bool _isLoadingResidents = false;
  bool _isLoadingBreakTimes = false;

  // Dev mode: สลับเวรสำหรับดูเวลาพัก และ skip validations
  bool _devMode = true; // ตั้งเป็น false เมื่อ production
  String? _devShiftOverride; // null = ใช้เวลาจริง, 'เวรเช้า' หรือ 'เวรดึก'

  // Dashboard stats
  double _learningProgress = 0.0;
  int _topicsNotTested = 0;
  List<RecentNews> _recentNews = [];
  bool _isLoadingStats = true;

  // On-shift data (สำหรับแสดงข้อมูลเวรปัจจุบัน)
  List<ResidentSimple> _shiftResidents = [];
  List<BreakTimeOption> _shiftBreakTimeOptions = [];

  // Monthly summary data
  MonthlySummary? _currentMonthSummary;

  // Clock out requirements
  int _remainingTasksCount = 0;
  int _unreadPostsCount = 0;
  bool _hasHandover = false;

  // Tarot card received during clock-in
  TarotCard? _selectedTarotCard;

  bool get _isClockedIn => _currentShift?.isClockedIn ?? false;
  bool get _canClockOut => _devMode || _remainingTasksCount == 0;

  String? get _clockOutDisabledReason {
    if (_devMode) return null; // Dev mode: ไม่แสดง reason
    final reasons = <String>[];
    if (_remainingTasksCount > 0) {
      reasons.add('$_remainingTasksCount งานค้าง');
    }
    if (_unreadPostsCount > 0) {
      reasons.add('$_unreadPostsCount โพสยังไม่อ่าน');
    }
    if (!_hasHandover) {
      reasons.add('ยังไม่ handover');
    }
    return reasons.isEmpty ? null : reasons.join(' • ');
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // Listen for user changes (dev mode impersonation)
    _userService.userChangedNotifier.addListener(_onUserChanged);
  }

  @override
  void dispose() {
    _userService.userChangedNotifier.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onUserChanged() {
    // Reload all data when user changes
    _homeService.invalidateCache();
    _clockService.invalidateCache();
    DDService.instance.invalidateCache();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadZones(),
      _loadCurrentShift(),
      _loadDashboardStats(),
      _loadBreakTimeOptions(),
      _loadCurrentUserName(),
      _loadOccupiedBreakTimes(),
      _loadMonthlySummary(),
    ]);
  }

  Future<void> _loadClockOutRequirements() async {
    if (!_isClockedIn || _currentShift == null) return;

    final results = await Future.wait([
      // งานทั้งหมดทั้งบ้าน ทุกโซน (ใช้เวลา clock in คำนวณ adjust_date)
      _homeService.getRemainingTasksCount(
        shift: _currentShift!.shift,
        clockInTime: _currentShift!.clockInTimestamp,
      ),
      _clockService.getUnreadAnnouncementsCount(),
      _clockService.hasHandoverPost(),
    ]);

    if (mounted) {
      setState(() {
        _remainingTasksCount = results[0] as int;
        _unreadPostsCount = results[1] as int;
        _hasHandover = results[2] as bool;
      });
    }
  }

  Future<void> _loadMonthlySummary() async {
    final summaries = await _shiftSummaryService.getMonthlySummaries();
    if (mounted && summaries.isNotEmpty) {
      // Get current month summary
      final now = DateTime.now();
      final currentMonthSummary = summaries.where(
        (s) => s.month == now.month && s.year == now.year,
      ).firstOrNull;
      setState(() => _currentMonthSummary = currentMonthSummary);
    }
  }

  Future<void> _loadCurrentUserName() async {
    final name = await _userService.getUserName();
    if (mounted) {
      setState(() => _currentUserName = name);
    }
  }

  Future<void> _loadCurrentShift({bool forceRefresh = false}) async {
    setState(() => _isLoadingShift = true);
    final shift = await _clockService.getCurrentShift(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _currentShift = shift;
        _isLoadingShift = false;
      });
      // โหลดข้อมูล residents และ break times สำหรับแสดงใน OnShiftCard
      if (shift != null && shift.isClockedIn) {
        _loadShiftData(shift);
      }
    }
  }

  Future<void> _loadShiftData(ClockInOut shift) async {
    debugPrint('_loadShiftData: shift.shift = ${shift.shift}');
    debugPrint('_loadShiftData: shift.zones = ${shift.zones}');
    debugPrint('_loadShiftData: shift.selectedResidentIdList = ${shift.selectedResidentIdList}');

    // โหลด residents - ถ้ามี zones ให้โหลดจาก zones, ถ้าไม่มีให้โหลดจาก resident IDs โดยตรง
    List<ResidentSimple> residents = [];
    if (shift.zones.isNotEmpty) {
      residents = await _zoneService.getResidentsByZones(shift.zones);
      debugPrint('_loadShiftData: loaded ${residents.length} residents from zones');
    }

    // ถ้าไม่มี residents จาก zones แต่มี selectedResidentIdList ให้โหลดจาก IDs โดยตรง
    // (กรณี dev mode หรือข้อมูลเก่าที่ zones ว่าง)
    if (residents.isEmpty && shift.selectedResidentIdList.isNotEmpty) {
      residents = await _zoneService.getResidentsByIds(shift.selectedResidentIdList);
      debugPrint('_loadShiftData: loaded ${residents.length} residents from IDs');
    }

    debugPrint('_loadShiftData: resident ids = ${residents.map((r) => r.id).toList()}');
    if (mounted) {
      setState(() => _shiftResidents = residents);
    }

    // โหลด break time options ตาม shift
    final breakTimeOptions = await _clockService.getBreakTimeOptions(shift: shift.shift);
    debugPrint('_loadShiftData: breakTimeOptions count = ${breakTimeOptions.length}');
    debugPrint('_loadShiftData: breakTimeOptions ids = ${breakTimeOptions.map((b) => b.id).toList()}');
    debugPrint('_loadShiftData: shift.selectedBreakTime = ${shift.selectedBreakTime}');
    if (mounted) {
      setState(() => _shiftBreakTimeOptions = breakTimeOptions);
    }
    // โหลด clock out requirements (tasks, posts, handover)
    _loadClockOutRequirements();
  }

  Future<void> _loadDashboardStats() async {
    final stats = await _homeService.getDashboardStats();
    final news = await _homeService.getRecentNews();
    if (mounted) {
      setState(() {
        _learningProgress = stats.learningProgress;
        _topicsNotTested = stats.topicsNotTested;
        _recentNews = news;
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadZones() async {
    final zones = await _zoneService.getZones();
    if (mounted) {
      setState(() {
        _zones = zones;
        _isLoadingZones = false;
      });
    }
  }

  Future<void> _loadBreakTimeOptions() async {
    setState(() => _isLoadingBreakTimes = true);

    // Dev mode: ใช้ shift ที่กำหนดแทนเวลาจริง
    List<BreakTimeOption> options;
    if (_devMode && _devShiftOverride != null) {
      options = await _clockService.getBreakTimeOptions(shift: _devShiftOverride);
    } else {
      options = await _clockService.getBreakTimeOptionsForCurrentShift();
    }

    if (mounted) {
      setState(() {
        _breakTimeOptions = options;
        _isLoadingBreakTimes = false;
      });
    }
  }

  Future<void> _loadOccupiedBreakTimes() async {
    final occupiedBreakTimes = await _clockService.getOccupiedBreakTimes();
    if (mounted) {
      setState(() {
        _occupiedBreakTimes = occupiedBreakTimes;
      });
    }
  }

  Future<void> _loadResidentsByZones() async {
    if (_selectedZoneIds.isEmpty) {
      setState(() {
        _availableResidents = [];
        _selectedResidentIds = {};
        _occupiedResidentIds = {};
      });
      return;
    }

    setState(() => _isLoadingResidents = true);

    // โหลด residents และ occupied IDs พร้อมกัน
    final results = await Future.wait([
      _zoneService.getResidentsByZones(_selectedZoneIds.toList()),
      _clockService.getOccupiedResidentIds(),
    ]);

    final residents = (results[0] as List<ResidentSimple>?) ?? [];
    final occupiedIds = (results[1] as Set<int>?) ?? {};

    if (mounted) {
      setState(() {
        _availableResidents = residents;
        _occupiedResidentIds = occupiedIds;
        // เลือก residents ที่ยังไม่ถูกเลือกโดยคนอื่น
        _selectedResidentIds = residents
            .where((r) => !occupiedIds.contains(r.id))
            .map((r) => r.id)
            .toSet();
        _isLoadingResidents = false;
      });
    }
  }

  void _onZonesChanged(Set<int> newZoneIds) {
    setState(() {
      _selectedZoneIds = newZoneIds;
    });
    _loadResidentsByZones();
  }

  Future<void> _handleClockIn() async {
    // Dev mode: skip validation - ใช้ค่าที่เลือกหรือค่าว่าง
    if (!_devMode) {
      if (_selectedZoneIds.isEmpty ||
          _selectedResidentIds.isEmpty ||
          _selectedBreakTimeIds.isEmpty) {
        return;
      }
    }

    // แสดงหน้าไพ่ทาโร่ก่อนขึ้นเวร
    final selectedCard = await TarotCardScreen.show(context);
    if (selectedCard == null || !mounted) return;

    // เก็บไพ่ที่เลือกไว้แสดงระหว่างขึ้นเวร
    setState(() => _selectedTarotCard = selectedCard);

    setState(() => _isClockingIn = true);
    try {
      final result = await _clockService.clockIn(
        zoneIds: _selectedZoneIds.toList(),
        residentIds: _selectedResidentIds.toList(),
        breakTimeIds: _selectedBreakTimeIds.toList(),
      );

      if (result != null && mounted) {
        setState(() {
          _currentShift = result;
          // Reset form
          _selectedZoneIds = {};
          _selectedResidentIds = {};
          _selectedBreakTimeIds = {};
          _availableResidents = [];
        });
        // Reload dashboard stats
        _loadDashboardStats();
      }
    } finally {
      if (mounted) {
        setState(() => _isClockingIn = false);
      }
    }
  }

  Future<void> _handleClockOut() async {
    if (_currentShift == null || _currentShift!.id == null) return;

    final result = await ClockOutDialog.show(
      context,
      clockRecordId: _currentShift!.id!,
      shift: _currentShift!.shift,
      residentIds: _currentShift!.selectedResidentIdList,
      clockInTime: _currentShift!.clockInTimestamp,
      devMode: _devMode, // ส่ง dev mode เพื่อ skip checks
      onCreateHandover: () {
        // Navigate to create post screen with handover flag
        MainNavigationScreen.navigateToTab(context, 3); // Board tab
      },
      onViewPosts: () {
        debugPrint('onViewPosts called!');
        // Use Future.microtask to ensure this runs after dialog is closed
        Future.microtask(() async {
          debugPrint('Future.microtask started');
          // Get unread post IDs and navigate to RequiredPostsScreen
          final unreadPosts = await _clockService.getUnreadAnnouncements();
          debugPrint('getUnreadAnnouncements: ${unreadPosts.length} posts');
          final postIds = unreadPosts
              .map((p) => p['post_id'] as int?)
              .whereType<int>()
              .toList();
          debugPrint('postIds: $postIds');

          if (postIds.isNotEmpty && mounted) {
            debugPrint('Navigating to RequiredPostsScreen');
            final allRead = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => RequiredPostsScreen(
                  postIds: postIds,
                  onAllPostsRead: () {
                    // Refresh clock out requirements after reading all posts
                    _loadClockOutRequirements();
                  },
                ),
              ),
            );

            // If all posts read, re-open clock out dialog
            if (allRead == true && mounted) {
              _handleClockOut();
            }
          } else {
            debugPrint('postIds empty or not mounted');
          }
        });
      },
    );

    if (result == true && mounted) {
      setState(() {
        _currentShift = null;
        _selectedTarotCard = null; // ล้างไพ่เมื่อลงเวร
      });
      // Reload data
      _loadCurrentShift(forceRefresh: true);
      _loadDashboardStats();
      _loadMonthlySummary();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลงเวรเรียบร้อย')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          _homeService.invalidateCache();
          _clockService.invalidateCache();
          await Future.wait([
            _loadZones(),
            _loadCurrentShift(forceRefresh: true),
            _loadDashboardStats(),
            _loadBreakTimeOptions(),
            _loadOccupiedBreakTimes(),
          ]);
        },
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // IreneAppBar
            IreneAppBar(
              title: 'IRENE',
              showDevBadge: _devMode,
              actions: [
                // Dev mode toggle button
                GestureDetector(
                  onTap: () {
                    setState(() => _devMode = !_devMode);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_devMode ? 'DEV Mode: ON' : 'DEV Mode: OFF'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: _devMode ? const Color(0xFFFFB300) : AppColors.secondaryText,
                      ),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _devMode
                          ? const Color(0xFFFFE082)
                          : AppColors.alternate,
                      borderRadius: BorderRadius.circular(12),
                      border: _devMode
                          ? Border.all(color: const Color(0xFFFFB300), width: 1.5)
                          : null,
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedSourceCode,
                      color: _devMode
                          ? const Color(0xFFE65100)
                          : AppColors.secondaryText,
                      size: AppIconSize.lg,
                    ),
                  ),
                ),
              ],
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
                  if (_isLoadingShift)
                    _buildShiftLoadingSkeleton()
                  else if (_isClockedIn)
                    _buildOnShiftContent()
                  else
                    _buildClockInContent(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftLoadingSkeleton() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.alternate,
              borderRadius: AppRadius.smallRadius,
            ),
          ),
          AppSpacing.verticalGapMd,
          Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.alternate,
              borderRadius: AppRadius.smallRadius,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockInContent() {
    return Column(
      children: [
        // Monthly Summary Card
        if (_currentMonthSummary != null)
          MonthlySummaryCard(
            morningShifts: _currentMonthSummary!.totalDayShifts,
            nightShifts: _currentMonthSummary!.totalNightShifts,
            targetShifts: _currentMonthSummary!.workdayTotal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShiftSummaryScreen()),
              );
            },
          ),
        if (_currentMonthSummary != null) AppSpacing.verticalGapMd,

        // DD Summary Card (อยู่ระหว่าง Monthly Summary และ Clock In)
        DDSummaryCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DDListScreen()),
            );
          },
        ),

        // Clock In Section
        ClockInSection(
          zones: _zones,
          selectedZoneIds: _selectedZoneIds,
          onZonesChanged: _onZonesChanged,
          isLoadingZones: _isLoadingZones,
          residents: _availableResidents,
          selectedResidentIds: _selectedResidentIds,
          disabledResidentIds: _occupiedResidentIds,
          onResidentsChanged: (ids) => setState(() => _selectedResidentIds = ids),
          isLoadingResidents: _isLoadingResidents,
          breakTimeOptions: _breakTimeOptions,
          selectedBreakTimeIds: _selectedBreakTimeIds,
          occupiedBreakTimes: _occupiedBreakTimes,
          currentUserName: _currentUserName,
          onBreakTimesChanged: (ids) => setState(() => _selectedBreakTimeIds = ids),
          isLoadingBreakTimes: _isLoadingBreakTimes,
          devMode: _devMode,
          devCurrentShift: _devShiftOverride ?? _clockService.getCurrentShiftType(),
          onDevShiftChanged: _handleDevShiftChanged,
          onClockIn: _handleClockIn,
          isClockingIn: _isClockingIn,
        ),
      ],
    );
  }

  void _handleDevShiftChanged(String shift) {
    setState(() {
      _devShiftOverride = shift;
      _selectedBreakTimeIds = {}; // Reset selection เมื่อเปลี่ยนเวร
    });
    _loadBreakTimeOptions();
  }

  Widget _buildOnShiftContent() {
    return Column(
      children: [
        // Tarot Core Value Card - แสดงไพ่ที่ได้รับตอนขึ้นเวร
        if (_selectedTarotCard != null) ...[
          TarotCoreValueCard(card: _selectedTarotCard!),
          AppSpacing.verticalGapMd,
        ],
        OnShiftCard(
          currentShift: _currentShift!,
          zones: _zones,
          residents: _shiftResidents,
          breakTimeOptions: _shiftBreakTimeOptions,
          onClockOut: _handleClockOut,
          isClockingOut: _isClockingOut,
          canClockOut: _canClockOut,
          disabledReason: _clockOutDisabledReason,
        ),
        AppSpacing.verticalGapMd,
        // Shift Activity Card - แสดง stats ความตรงเวลา + recent activities
        if (_currentShift!.selectedResidentIdList.isNotEmpty)
          Builder(builder: (context) {
            final filteredBreakTimes = _shiftBreakTimeOptions
                .where((b) => _currentShift!.selectedBreakTime.contains(b.id))
                .toList();
            debugPrint('ShiftActivityCard build: _shiftBreakTimeOptions=${_shiftBreakTimeOptions.length}, selectedBreakTime=${_currentShift!.selectedBreakTime}, filtered=${filteredBreakTimes.length}');
            return ShiftActivityCard(
              residentIds: _currentShift!.selectedResidentIdList,
              clockInTime: _currentShift!.clockInTimestamp ?? DateTime.now(),
              selectedBreakTimes: filteredBreakTimes,
              recentItemsLimit: 3,
              onViewAllTap: () {
                // Navigate to Checklist tab (index 1)
                MainNavigationScreen.navigateToTab(context, 1);
              },
              onCardTap: () {
                // Navigate to Time Block Detail Screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TimeBlockDetailScreen(
                      residentIds: _currentShift!.selectedResidentIdList,
                    ),
                  ),
                );
              },
            );
          }),
        if (_currentShift!.selectedResidentIdList.isNotEmpty)
          AppSpacing.verticalGapMd,
        // _buildTaskProgressCard() - รวมเข้ากับ ShiftActivityCard แล้ว
        _buildLearningCard(context),
        AppSpacing.verticalGapMd,
        _buildNewsCard(),
      ],
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
                    HugeIcon(icon: HugeIcons.strokeRoundedBook01, color: AppColors.secondary, size: AppIconSize.lg),
                    AppSpacing.horizontalGapSm,
                    Text('เรียนรู้ไตรมาสนี้', style: AppTypography.title),
                  ],
                ),
                _isLoadingStats
                    ? SizedBox(
                        width: 30,
                        height: 14,
                        child: LinearProgressIndicator(
                          backgroundColor: AppColors.alternate,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                        ),
                      )
                    : Text('${(_learningProgress * 100).toInt()}%',
                        style: AppTypography.body.copyWith(color: AppColors.secondaryText)),
              ],
            ),
            AppSpacing.verticalGapMd,
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _learningProgress,
                backgroundColor: AppColors.alternate,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                minHeight: 8,
              ),
            ),
            if (_topicsNotTested > 0) ...[
              AppSpacing.verticalGapSm,
              Row(
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedAlert02, color: AppColors.warning, size: AppIconSize.sm),
                  AppSpacing.horizontalGapXs,
                  Text(
                    'มี $_topicsNotTested บทยังไม่สอบ',
                    style: AppTypography.caption.copyWith(color: AppColors.warning),
                  ),
                ],
              ),
            ],
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
                  HugeIcon(icon: HugeIcons.strokeRoundedFileEdit, color: AppColors.tertiary, size: AppIconSize.lg),
                  AppSpacing.horizontalGapSm,
                  Text('ข่าวล่าสุด', style: AppTypography.title),
                ],
              ),
              TextButton(
                onPressed: () {
                  MainNavigationScreen.navigateToTab(context, 3); // Board tab
                },
                child: Text('ดูทั้งหมด'),
              ),
            ],
          ),
          AppSpacing.verticalGapSm,
          if (_isLoadingStats)
            ...[
              _buildNewsItemSkeleton(),
              _buildNewsItemSkeleton(),
            ]
          else if (_recentNews.isEmpty)
            Text(
              'ไม่มีข่าวล่าสุด',
              style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
            )
          else
            ..._recentNews.map((news) => _buildNewsItem(
                  news.residentName != null
                      ? '${news.residentName} - ${news.title}'
                      : news.title,
                  news.timeAgo,
                  onTap: () {
                    MainNavigationScreen.navigateToTab(context, 3); // Board tab
                  },
                )),
        ],
      ),
    );
  }

  Widget _buildNewsItemSkeleton() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.alternate,
                borderRadius: AppRadius.smallRadius,
              ),
            ),
          ),
          AppSpacing.horizontalGapMd,
          Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.alternate,
              borderRadius: AppRadius.smallRadius,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsItem(String title, String time, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
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
      ),
    );
  }
}
