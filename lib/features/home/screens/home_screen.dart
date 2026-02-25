import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../widgets/clock_out_survey_form.dart';
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
import '../widgets/profile_completion_card.dart';
import '../../dd_handover/screens/dd_list_screen.dart';
import '../../dd_handover/services/dd_service.dart';
import '../../incident_reflection/widgets/incident_summary_card.dart';
import '../../incident_reflection/screens/incident_list_screen.dart';
import '../../incident_reflection/screens/incident_chat_screen.dart';
import '../../incident_reflection/models/incident.dart';
import '../../incident_reflection/providers/incident_provider.dart';
import '../../dd_handover/providers/dd_provider.dart';
import '../services/clock_realtime_service.dart';
import '../../../main.dart' show globalRefreshNotifier;
import '../../points/widgets/points_summary_card.dart';
import '../../points/models/models.dart'; // สำหรับ Tier, UserTierInfo
import '../../learning/models/badge.dart' as learning; // สำหรับ mock badges (ป้องกัน conflict กับ material Badge)
import '../services/shift_summary_service.dart' as clock_out_summary; // สำหรับ ShiftSummary (clock out)
import '../widgets/clock_out_summary_modal.dart'; // สำหรับ dev test
import '../models/shift_leader.dart'; // สำหรับ mock ShiftLeader ใน dev button
import '../../settings/services/clockin_verification_service.dart'; // สำหรับตรวจ GPS+WiFi ก่อนขึ้นเวร
import '../../../core/widgets/buttons.dart'; // สำหรับ PrimaryButton ใน verification dialog

/// หน้าหลัก - Dashboard with Clock-in/Clock-out
/// ใช้ ConsumerStatefulWidget เพื่อให้ pull to refresh สามารถ invalidate
/// Riverpod providers (DDSummaryCard, IncidentSummaryCard) ได้
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _zoneService = ZoneService();
  final _homeService = HomeService.instance;
  final _clockService = ClockService.instance;
  final _userService = UserService();
  final _shiftSummaryService = ShiftSummaryService.instance;
  final _clockRealtimeService = ClockRealtimeService.instance;

  // Dev mode - แสดงปุ่ม dev เฉพาะ user นี้เท่านั้น
  bool get _isDevUser =>
      Supabase.instance.client.auth.currentUser?.email == 'beautyheechul@gmail.com';

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

  // Dashboard stats
  double _learningProgress = 0.0;
  int _topicsNotTested = 0;
  List<RecentNews> _recentNews = [];
  bool _isLoadingStats = true;

  // On-shift data (สำหรับแสดงข้อมูลเวรปัจจุบัน)
  List<ResidentSimple> _shiftResidents = [];
  List<BreakTimeOption> _shiftBreakTimeOptions = [];
  bool _isLoadingShiftResidents = false; // loading state สำหรับ residents ในเวร

  // Monthly summary data
  MonthlySummary? _currentMonthSummary;

  // Clock out requirements
  // เริ่มต้น loading = true เพื่อให้ปุ่มลงเวร disabled ไว้ก่อนจนกว่าจะโหลดข้อมูลเสร็จ
  bool _isLoadingClockOutRequirements = true;
  int _remainingTasksCount = 0;
  int _unreadPostsCount = 0;
  bool _hasHandover = false;

  // Tarot card received during clock-in
  TarotCard? _selectedTarotCard;

  bool get _isClockedIn => _currentShift?.isClockedIn ?? false;
  // ปุ่มลงเวรจะ enabled ก็ต่อเมื่อ: โหลดข้อมูลเสร็จแล้ว + ไม่มีงานค้าง
  bool get _canClockOut =>
      !_isLoadingClockOutRequirements && _remainingTasksCount == 0;

  String? get _clockOutDisabledReason {
    // ถ้ากำลังโหลดข้อมูล แสดงข้อความ loading
    if (_isLoadingClockOutRequirements) {
      return 'กำลังตรวจสอบ...';
    }
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
    // Subscribe to clock_in_out_ver2 realtime updates
    _subscribeToClockUpdates();
    // Listen for global refresh (เมื่อ user กด push notification เข้ามา)
    globalRefreshNotifier.addListener(_onGlobalRefresh);
  }

  @override
  void dispose() {
    _userService.userChangedNotifier.removeListener(_onUserChanged);
    _clockRealtimeService.unsubscribe();
    globalRefreshNotifier.removeListener(_onGlobalRefresh);
    super.dispose();
  }

  /// เมื่อได้รับ signal ให้ refresh จาก push notification deep link
  void _onGlobalRefresh() {
    debugPrint('HomeScreen: Received global refresh signal');
    // Invalidate cache และโหลดข้อมูลใหม่ทั้งหมด
    _homeService.invalidateCache();
    _clockService.invalidateCache();
    DDService.instance.invalidateCache();
    _loadInitialData();
  }

  // NOTE: Tutorial feature ถูกซ่อนไว้ชั่วคราว
  // /// เริ่ม Tutorial ใหม่ (replay)
  // void _replayTutorial() {
  //   MainNavigationScreen.replayTutorial(context);
  // }

  void _subscribeToClockUpdates() {
    _clockRealtimeService.subscribe(
      onClockUpdated: () {
        // เมื่อเพื่อนขึ้น/ลงเวร ให้ refresh occupied residents และ break times
        if (!_isClockedIn && mounted) {
          _loadResidentsByZones();
          _loadOccupiedBreakTimes();
        }
      },
    );
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
    // ถ้าไม่ได้อยู่ในเวร ไม่ต้องโหลด และ set loading = false
    if (!_isClockedIn || _currentShift == null) {
      if (mounted) {
        setState(() => _isLoadingClockOutRequirements = false);
      }
      return;
    }

    // เริ่มโหลด (ถ้าเป็นการ refresh จะ reset loading state)
    if (mounted) {
      setState(() => _isLoadingClockOutRequirements = true);
    }

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
        // โหลดเสร็จแล้ว
        _isLoadingClockOutRequirements = false;
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
      // ถ้ามี shift ที่ clock in อยู่ → set loading residents ก่อน UI rebuild
      final needLoadResidents = shift != null && shift.isClockedIn;
      setState(() {
        _currentShift = shift;
        _isLoadingShift = false;
        if (needLoadResidents) {
          _isLoadingShiftResidents = true; // set ก่อน UI rebuild
        }
      });
      // โหลดข้อมูล residents และ break times สำหรับแสดงใน OnShiftCard
      if (needLoadResidents) {
        _loadShiftData(shift);
      }
    }
  }

  Future<void> _loadShiftData(ClockInOut shift) async {
    // หมายเหตุ: _isLoadingShiftResidents ถูก set เป็น true ใน _loadCurrentShift แล้ว
    // เพื่อให้ UI แสดง loading ก่อนที่จะเริ่มโหลดข้อมูล

    debugPrint('_loadShiftData: shift.shift = ${shift.shift}');
    debugPrint('_loadShiftData: shift.zones = ${shift.zones}');
    debugPrint('_loadShiftData: shift.selectedResidentIdList = ${shift.selectedResidentIdList}');

    // โหลด residents จาก selectedResidentIdList โดยตรงเสมอ
    // เพราะต้องการแสดงชื่อ residents ที่เลือกไว้ตอน clock in
    // ไม่ใช่ทุกคนใน zone (ซึ่งอาจ filter s_status='Stay' ทำให้บาง resident หายไป)
    List<ResidentSimple> residents = [];
    if (shift.selectedResidentIdList.isNotEmpty) {
      residents = await _zoneService.getResidentsByIds(shift.selectedResidentIdList);
      debugPrint('_loadShiftData: loaded ${residents.length} residents from IDs');
    }

    debugPrint('_loadShiftData: resident ids = ${residents.map((r) => r.id).toList()}');
    if (mounted) {
      setState(() {
        _shiftResidents = residents;
        _isLoadingShiftResidents = false; // โหลดเสร็จแล้ว
      });
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

    final options = await _clockService.getBreakTimeOptionsForCurrentShift();

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
    // Validation: ต้องเลือกครบทุก field
    if (_selectedZoneIds.isEmpty ||
        _selectedResidentIds.isEmpty ||
        _selectedBreakTimeIds.isEmpty) {
      return;
    }

    // ตรวจสอบ occupied residents อีกครั้งก่อนขึ้นเวร (ป้องกัน race condition)
    final latestOccupiedIds = await _clockService.getOccupiedResidentIds();
    final conflictIds = _selectedResidentIds.intersection(latestOccupiedIds);
    if (conflictIds.isNotEmpty) {
      // มี resident ที่ถูกเลือกไปแล้ว → refresh และแจ้งเตือน
      await _loadResidentsByZones();
      await _loadOccupiedBreakTimes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('มีคนไข้ที่เพื่อนเลือกไปแล้ว กรุณาเลือกใหม่'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ============================================
    // ตรวจสอบ GPS + WiFi ก่อนอนุญาตให้ขึ้นเวร
    // ============================================
    // ดึง nursinghomeId เพื่อใช้ query ค่า GPS/WiFi ที่ admin ตั้งไว้
    final nursinghomeId = await _userService.getNursinghomeId();
    if (nursinghomeId == null || !mounted) return;

    // แสดง loading บนปุ่มขณะตรวจสอบ
    setState(() => _isClockingIn = true);

    ClockInVerificationResult? verificationResult;
    try {
      // เรียก service ตรวจ GPS + WiFi พร้อมกัน
      verificationResult = await ClockInVerificationService().verify(nursinghomeId);
    } catch (e) {
      debugPrint('[HomeScreen] Clock-in verification error: $e');
    }

    if (!mounted) return;
    // ปิด loading หลังตรวจเสร็จ (จะเปิดใหม่ตอน clock-in จริง)
    setState(() => _isClockingIn = false);

    // ตรวจผลลัพธ์: ต้องผ่านทั้ง GPS AND WiFi
    // null = admin ไม่ได้ตั้งค่า → ข้ามเงื่อนไขนั้น (ถือว่าผ่าน)
    if (verificationResult != null) {
      final gps = verificationResult.gpsMatch;
      final wifi = verificationResult.wifiMatch;
      final gpsErr = verificationResult.gpsError;
      final wifiErr = verificationResult.wifiError;

      // เช็คว่ามีเงื่อนไขที่ fail หรือ error ไหม
      // gps == false หรือ gpsErr != null → GPS ไม่ผ่าน
      // wifi == false หรือ wifiErr != null → WiFi ไม่ผ่าน
      final gpsFailed = gps == false || gpsErr != null;
      final wifiFailed = wifi == false || wifiErr != null;

      if (gpsFailed || wifiFailed) {
        // มีเงื่อนไขไม่ผ่าน → แสดง dialog แจ้ง user
        if (mounted) {
          _showVerificationFailedDialog(verificationResult);
        }
        return;
      }
    }

    // แสดงหน้าไพ่ทาโร่ก่อนขึ้นเวร
    if (!mounted) return;
    final selectedCard = await TarotCardScreen.show(context);
    if (selectedCard == null || !mounted) return;

    // เก็บไพ่ที่เลือกไว้แสดงระหว่างขึ้นเวร
    setState(() => _selectedTarotCard = selectedCard);

    setState(() => _isClockingIn = true);
    try {
      // ไม่ต้อง set Incharge ตอน clock in แล้ว
      // scheduled job (pg_cron) จะ assign Incharge ให้ตอน 08:00/20:00
      // เพื่อให้ทุกคนมีเวลาขึ้นเวรก่อน แล้วค่อยตัดสินใจว่าใครเป็น Incharge
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
        // Reload all data after clock in
        _clockService.invalidateCache();
        _homeService.invalidateCache();
        await Future.wait([
          _loadCurrentShift(forceRefresh: true),
          _loadDashboardStats(),
          _loadMonthlySummary(),
        ]);
      }
    } finally {
      if (mounted) {
        setState(() => _isClockingIn = false);
      }
    }
  }

  // ============================================
  // Dialog แจ้งผลตรวจ GPS/WiFi ไม่ผ่าน
  // ============================================
  // แสดงเมื่อ user กดขึ้นเวรแต่ไม่ผ่านเงื่อนไข GPS หรือ WiFi
  // ใช้ pattern คล้าย ConfirmDialog (icon + title + image + message + button)
  void _showVerificationFailedDialog(ClockInVerificationResult result) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.largeRadius,
        ),
        backgroundColor: AppColors.surface,
        contentPadding: EdgeInsets.zero,
        content: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: AppSpacing.lg),

              // Icon เตือน (สีส้ม)
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.tagPendingBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    color: const Color(0xFFF59E0B),
                    size: AppIconSize.lg,
                  ),
                ),
              ),

              SizedBox(height: AppSpacing.sm),

              // Title
              Text(
                'ไม่สามารถขึ้นเวรได้',
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppSpacing.xs),

              // รูปแมว (ตาม pattern ConfirmDialog)
              Image.asset(
                'assets/images/confirm_cat.webp',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),

              SizedBox(height: AppSpacing.sm),

              // ข้อความอธิบาย
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'กรุณาตรวจสอบเงื่อนไขต่อไปนี้',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: AppSpacing.md),

              // รายการสถานะ GPS / WiFi
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  children: [
                    // --- GPS Status ---
                    if (result.gpsMatch != null || result.gpsError != null)
                      _buildVerificationRow(
                        icon: HugeIcons.strokeRoundedLocation01,
                        label: 'ตำแหน่ง GPS',
                        passed: result.gpsMatch == true,
                        detail: _buildGpsDetailText(result),
                        error: result.gpsError,
                      ),

                    // --- WiFi Status ---
                    if (result.wifiMatch != null || result.wifiError != null) ...[
                      // เพิ่ม divider ระหว่าง GPS กับ WiFi (ถ้ามีทั้งคู่)
                      if (result.gpsMatch != null || result.gpsError != null)
                        Divider(height: 1, color: AppColors.alternate),
                      _buildVerificationRow(
                        icon: HugeIcons.strokeRoundedWifi01,
                        label: 'WiFi',
                        passed: result.wifiMatch == true,
                        detail: _buildWifiDetailText(result),
                        error: result.wifiError,
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.md),

              // ปุ่ม "รับทราบ" (ปุ่มเดียว)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'รับทราบ',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// แต่ละ row แสดงสถานะ GPS หรือ WiFi ใน verification dialog
  /// คล้าย pattern _buildStatusRow ในหน้า Settings
  Widget _buildVerificationRow({
    required dynamic icon,
    required String label,
    required bool passed,
    String? detail,
    String? error,
  }) {
    // กำหนดสีและ icon ตามสถานะ
    final Color statusColor;
    final String statusText;
    final dynamic statusIcon;

    if (error != null) {
      // มี error (เช่น ไม่ได้รับสิทธิ์) → สีส้มเตือน
      statusColor = Colors.orange;
      statusText = 'ไม่ทราบ';
      statusIcon = HugeIcons.strokeRoundedAlert02;
    } else if (passed) {
      // ผ่าน → สีเขียว
      statusColor = AppColors.success;
      statusText = 'ผ่าน';
      statusIcon = HugeIcons.strokeRoundedCheckmarkCircle02;
    } else {
      // ไม่ผ่าน → สีแดง
      statusColor = AppColors.error;
      statusText = 'ไม่ผ่าน';
      statusIcon = HugeIcons.strokeRoundedCancelCircle;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          // Icon container (วงกลมสี)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: HugeIcon(
                icon: icon,
                color: statusColor,
                size: AppIconSize.lg,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          // Label + Detail text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.body),
                if (detail != null || error != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    error ?? detail ?? '',
                    style: AppTypography.caption.copyWith(
                      color: error != null
                          ? Colors.orange.shade700
                          : AppColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Status badge (ผ่าน/ไม่ผ่าน)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.smallRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: statusIcon,
                  size: AppIconSize.sm,
                  color: statusColor,
                ),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: AppTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// สร้าง detail text สำหรับ GPS ใน verification dialog
  /// เช่น "ศูนย์ดูแลฯ - ห่าง 120 ม. (รัศมี 500 ม.)"
  String? _buildGpsDetailText(ClockInVerificationResult result) {
    if (result.distanceMeters == null) return result.locationName;

    final distance = result.distanceMeters!.round();
    final radius = result.registeredRadius?.round();
    final name = result.locationName;

    String text = '';
    if (name != null) text += '$name - ';
    text += 'ห่าง $distance ม.';
    if (radius != null) text += ' (รัศมี $radius ม.)';
    return text;
  }

  /// สร้าง detail text สำหรับ WiFi ใน verification dialog
  /// เช่น "เชื่อมต่อ: IreneNH-5G (ไม่ได้ลงทะเบียน)"
  String? _buildWifiDetailText(ClockInVerificationResult result) {
    if (result.currentSsid == null || result.currentSsid!.isEmpty) {
      return 'ไม่ได้เชื่อมต่อ WiFi';
    }
    if (result.wifiMatch == true) {
      return 'เชื่อมต่อ: ${result.currentSsid}';
    } else {
      return 'เชื่อมต่อ: ${result.currentSsid} (ไม่ได้ลงทะเบียน)';
    }
  }

  Future<void> _handleClockOut() async {
    if (_currentShift == null || _currentShift!.id == null) return;

    // ดึง userId และ nursinghomeId สำหรับเช็ค incidents
    final userId = _userService.effectiveUserId;
    final nursinghomeId = await _userService.getNursinghomeId();

    if (userId == null || nursinghomeId == null) {
      debugPrint('_handleClockOut: userId or nursinghomeId is null');
      return;
    }

    if (!mounted) return;

    final result = await ClockOutDialog.show(
      context,
      clockRecordId: _currentShift!.id!,
      shift: _currentShift!.shift,
      residentIds: _currentShift!.selectedResidentIdList,
      clockInTime: _currentShift!.clockInTimestamp,
      userId: userId,
      nursinghomeId: nursinghomeId,
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
      onViewIncidents: (Incident incident) {
        debugPrint('onViewIncidents called! incident: ${incident.id}');
        // Navigate ไปหน้า chat ของ incident โดยตรง
        // ใช้ Future.delayed เล็กน้อยเพื่อให้ dialog ปิดเสร็จก่อน แล้วค่อย navigate
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            debugPrint('Navigating to IncidentChatScreen...');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => IncidentChatScreen(incident: incident),
              ),
            ).then((_) {
              // หลังจากกลับมาจากหน้า chat ให้เปิด clock out dialog อีกครั้ง
              // เพื่อให้ user ลงเวรต่อได้ (ถ้าเคลียร์ incidents ครบแล้ว)
              if (mounted) {
                debugPrint('Back from chat, re-opening clock out dialog...');
                _handleClockOut();
              }
            });
          } else {
            debugPrint('Widget not mounted, cannot navigate');
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
          // 1. Invalidate ALL service caches
          // เพื่อให้ทุก service โหลดข้อมูลใหม่จาก server
          _homeService.invalidateCache();
          _clockService.invalidateCache();
          DDService.instance.invalidateCache();

          // 2. Invalidate Riverpod providers
          // สำหรับ widgets ที่ใช้ Riverpod (DDSummaryCard, IncidentSummaryCard)
          ref.invalidate(ddRecordsProvider);
          ref.invalidate(myIncidentsProvider);

          // 3. Reload ALL data รวมถึง MonthlySummary
          await Future.wait([
            _loadZones(),
            _loadCurrentShift(forceRefresh: true),
            _loadDashboardStats(),
            _loadBreakTimeOptions(),
            _loadOccupiedBreakTimes(),
            _loadMonthlySummary(), // เพิ่มเพื่อให้ MonthlySummaryCard refresh ด้วย
          ]);
        },
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // IreneAppBar
            IreneAppBar(
              title: 'IRENE',
              // NOTE: Tutorial feature ถูกซ่อนไว้ชั่วคราว
              // actions: [
              //   ReplayTutorialButton(
              //     onPressed: _replayTutorial,
              //   ),
              // ],
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
        // ปุ่ม Dev สำหรับทดสอบ clock out flow โดยไม่ต้องขึ้นเวรจริง
        if (_isDevUser) ...[
          _buildDevClockOutCheckButton(),
          AppSpacing.verticalGapSm,
          _buildDevSurveyFormButton(),
          AppSpacing.verticalGapSm,
          _buildDevSummaryModalButton(),
          AppSpacing.verticalGapMd,
        ],

        // Monthly Summary Card
        if (_currentMonthSummary != null)
          MonthlySummaryCard(
            morningShifts: _currentMonthSummary!.totalDayShifts,
            nightShifts: _currentMonthSummary!.totalNightShifts,
            targetShifts: _currentMonthSummary!.workdayTotal,
            absentCount: _currentMonthSummary!.absentCount,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShiftSummaryScreen()),
              );
            },
          ),
        if (_currentMonthSummary != null) AppSpacing.verticalGapMd,

        // Points Summary Card - แสดงคะแนนสะสมและ Tier
        // กดเพื่อไปหน้า Leaderboard
        const PointsSummaryCard(),

        // Profile Completion Card - ชวน user กรอกข้อมูลโปรไฟล์ให้ครบ
        // จะแสดงเฉพาะเมื่อยังกรอกไม่ครบทั้ง 3 หน้า
        const ProfileCompletionCard(),

        // DD Summary Card (อยู่ระหว่าง Monthly Summary และ Clock In)
        // Card มี margin bottom ของตัวเอง ไม่ต้องเพิ่ม gap
        DDSummaryCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DDListScreen()),
            );
          },
        ),

        // Incident Reflection Summary Card (Shortcut ไปหน้าถอดบทเรียน)
        IncidentSummaryCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IncidentListScreen()),
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
          onClockIn: _handleClockIn,
          isClockingIn: _isClockingIn,
        ),
      ],
    );
  }

  Widget _buildOnShiftContent() {
    return Column(
      children: [
        // ปุ่ม Dev สำหรับทดสอบ clock out flow ขณะขึ้นเวรอยู่
        if (_isDevUser) ...[
          _buildDevClockOutCheckButton(),
          AppSpacing.verticalGapSm,
          _buildDevSummaryModalButton(),
          AppSpacing.verticalGapMd,
        ],

        // Tarot Core Value Card - แสดงไพ่ที่ได้รับตอนขึ้นเวร
        if (_selectedTarotCard != null) ...[
          TarotCoreValueCard(card: _selectedTarotCard!),
          AppSpacing.verticalGapMd,
        ],

        // Incident Reflection Summary Card - แสดงทั้งตอนขึ้นเวรและลงเวร
        // Card มี margin bottom ของตัวเอง ไม่ต้องเพิ่ม gap
        IncidentSummaryCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IncidentListScreen()),
            );
          },
        ),

        OnShiftCard(
          currentShift: _currentShift!,
          zones: _zones,
          residents: _shiftResidents,
          breakTimeOptions: _shiftBreakTimeOptions,
          onClockOut: _handleClockOut,
          isClockingOut: _isClockingOut,
          canClockOut: _canClockOut,
          disabledReason: _clockOutDisabledReason,
          isLoadingResidents: _isLoadingShiftResidents, // ส่ง loading state ไป
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
              // ส่ง deadAirMinutes จาก backend (database trigger calculation)
              deadAirMinutes: _currentShift!.deadAirMinutes,
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

  /// ปุ่ม Dev สำหรับทดสอบ flow ตรวจสอบก่อนลงเวร (ClockOutDialog)
  /// แสดงเฉพาะใน debug mode เพื่อให้ dev ทดสอบ check flow ได้
  // ignore: unused_element
  Widget _buildDevClockOutCheckButton() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCheckList,
            color: Colors.blue.shade700,
            size: AppIconSize.lg,
          ),
          AppSpacing.horizontalGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEV: ตรวจสอบก่อนลงเวร',
                  style: AppTypography.subtitle.copyWith(
                    color: Colors.blue.shade700,
                  ),
                ),
                Text(
                  'เปิดดู ClockOutDialog (check flow ทั้งหมด)',
                  style: AppTypography.caption.copyWith(
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.horizontalGapSm,
          ElevatedButton(
            onPressed: _showDevClockOutCheckDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('เปิด'),
          ),
        ],
      ),
    );
  }

  /// เปิด ClockOutDialog สำหรับทดสอบ - ใช้ข้อมูลจริงของ user
  /// ถ้ายังไม่ได้ขึ้นเวร จะใช้ mock clockRecordId
  // ignore: unused_element
  Future<void> _showDevClockOutCheckDialog() async {
    final userId = _userService.effectiveUserId;
    final nursinghomeId = await _userService.getNursinghomeId();

    if (userId == null || nursinghomeId == null || !mounted) return;

    // ใช้ข้อมูลจริงถ้ามี shift อยู่ หรือ mock ถ้ายังไม่ได้ขึ้นเวร
    final clockRecordId = _currentShift?.id ?? 0;
    final shift = _currentShift?.shift ?? 'เวรเช้า';
    final residentIds = _currentShift?.selectedResidentIdList ?? [];
    final clockInTime = _currentShift?.clockInTimestamp ?? DateTime.now();

    await ClockOutDialog.show(
      context,
      clockRecordId: clockRecordId,
      shift: shift,
      residentIds: residentIds,
      clockInTime: clockInTime,
      userId: userId,
      nursinghomeId: nursinghomeId,
      onCreateHandover: () {
        MainNavigationScreen.navigateToTab(context, 3);
      },
      onViewPosts: () {
        debugPrint('DEV: onViewPosts called');
      },
      onViewIncidents: (incident) {
        debugPrint('DEV: onViewIncidents called - ${incident.id}');
      },
    );
  }

  /// ปุ่ม Dev สำหรับทดสอบฟอร์มหลังลงเวร (ClockOutSurveyForm)
  /// แสดงเฉพาะใน debug mode เพื่อให้ dev ทดสอบ UI ได้โดยไม่ต้องขึ้นเวรจริง
  // ignore: unused_element
  Widget _buildDevSurveyFormButton() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedTestTube,
            color: Colors.orange.shade700,
            size: AppIconSize.lg,
          ),
          AppSpacing.horizontalGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEV: ทดสอบฟอร์มหลังลงเวร',
                  style: AppTypography.subtitle.copyWith(
                    color: Colors.orange.shade700,
                  ),
                ),
                Text(
                  'เปิดดู ClockOutSurveyForm โดยไม่ต้องขึ้นเวร',
                  style: AppTypography.caption.copyWith(
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.horizontalGapSm,
          ElevatedButton(
            onPressed: _showDevSurveyFormDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('เปิด'),
          ),
        ],
      ),
    );
  }

  /// แสดง Dialog สำหรับทดสอบ ClockOutSurveyForm
  /// ใช้ mock ShiftLeader เพื่อให้เห็นส่วนประเมินหัวหน้าเวรด้วย
  // ignore: unused_element
  void _showDevSurveyFormDialog() {
    // Mock หัวหน้าเวร เพื่อทดสอบ UI ส่วนประเมินหัวหน้าเวร
    const mockLeader = ShiftLeader(
      id: 'dev-leader-001',
      nickname: 'พี่แมว',
      fullName: 'สมชาย แมวดี',
      photoUrl: null, // ไม่มีรูป - จะแสดง fallback icon แทน
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface, // พื้นหลังขาว
        insetPadding: EdgeInsets.all(AppSpacing.md),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header พร้อมปุ่มปิด
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DEV: ทดสอบฟอร์ม',
                    style: AppTypography.subtitle.copyWith(
                      color: Colors.orange.shade700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      color: AppColors.secondaryText,
                      size: AppIconSize.md,
                    ),
                  ),
                ],
              ),
              const Divider(),
              // ClockOutSurveyForm พร้อม mock shiftLeader
              Flexible(
                child: ClockOutSurveyForm(
                  shiftLeader: mockLeader, // ส่ง mock leader เพื่อแสดงส่วนประเมินหัวหน้าเวร
                  onSubmit: ({
                    required int shiftScore,
                    required int selfScore,
                    required String shiftSurvey,
                    String? bugSurvey,
                    int? leaderScore,
                  }) {
                    // แสดงผลลัพธ์ใน SnackBar แทนการบันทึกจริง
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'DEV: shiftScore=$shiftScore, selfScore=$selfScore, '
                          'leaderScore=$leaderScore, '
                          'survey="${shiftSurvey.substring(0, shiftSurvey.length.clamp(0, 30))}..."',
                        ),
                        backgroundColor: Colors.orange.shade600,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ปุ่ม Dev สำหรับทดสอบ ClockOutSummaryModal
  /// แสดงเฉพาะใน debug mode เพื่อให้ dev ทดสอบ UI ได้โดยไม่ต้องลงเวรจริง
  // ignore: unused_element
  Widget _buildDevSummaryModalButton() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedGift,
            color: Colors.purple.shade700,
            size: AppIconSize.lg,
          ),
          AppSpacing.horizontalGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEV: ทดสอบ Summary Modal',
                  style: AppTypography.subtitle.copyWith(
                    color: Colors.purple.shade700,
                  ),
                ),
                Text(
                  'เปิดดู ClockOutSummaryModal พร้อม Confetti',
                  style: AppTypography.caption.copyWith(
                    color: Colors.purple.shade600,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.horizontalGapSm,
          ElevatedButton(
            onPressed: _showDevSummaryModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('เปิด'),
          ),
        ],
      ),
    );
  }

  /// แสดง ClockOutSummaryModal พร้อม mock data
  // ignore: unused_element
  void _showDevSummaryModal() {
    // สร้าง mock ShiftSummary สำหรับทดสอบ
    final mockSummary = clock_out_summary.ShiftSummary(
      points: const clock_out_summary.ShiftPointsSummary(
        totalPoints: 85,
        taskPoints: 60,
        quizPoints: 15,
        contentPoints: 10,
        badgePoints: 0,
        deadAirPenalty: 5,
        transactionCount: 12,
      ),
      newBadges: [
        // Mock badges สำหรับทดสอบ
        // ใช้ learning.Badge เพื่อหลีกเลี่ยง conflict กับ material Badge
        learning.Badge(
          id: 'badge_1',
          name: 'ตรงเวลา 7 วัน',
          description: 'มาทำงานตรงเวลา 7 วันติดต่อกัน',
          imageUrl: null,
          rarity: 'common',
          category: 'punctuality',
          points: 10,
          requirementType: 'streak',
          isEarned: true,
        ),
        learning.Badge(
          id: 'badge_2',
          name: 'Quiz Master',
          description: 'ทำ Quiz ได้คะแนนเต็ม 5 ครั้ง',
          imageUrl: null,
          rarity: 'rare',
          category: 'learning',
          points: 20,
          requirementType: 'quiz_perfect',
          isEarned: true,
        ),
      ],
      tierInfo: UserTierInfo(
        currentTier: Tier.defaultTier,
        nextTier: const Tier(
          id: 'silver',
          name: 'Silver',
          nameTh: 'ซิลเวอร์',
          minPoints: 500,
          icon: '🥈',
        ),
        totalPoints: 350,
      ),
      leaderboardRank: 5,
      totalUsers: 25,
      workStreak: 7,
      deadAirMinutes: 45,
    );

    // แสดง Modal
    ClockOutSummaryModal.show(
      context,
      summary: mockSummary,
    );
  }
}
