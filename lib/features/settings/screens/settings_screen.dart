import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/services/user_service.dart';
import '../../checklist/models/system_role.dart';
import '../../checklist/providers/task_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../learning/screens/directory_screen.dart';
import '../../learning/screens/badge_collection_screen.dart';
import '../models/user_profile.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../shift_summary/screens/shift_summary_screen.dart';
import '../../shift_summary/services/shift_summary_service.dart';
import '../../shift_summary/providers/shift_summary_provider.dart';
import '../../home/services/home_service.dart';
import '../../home/services/clock_service.dart';
import '../../dd_handover/screens/dd_list_screen.dart';
import '../../dd_handover/providers/dd_provider.dart';
import '../../dd_handover/services/dd_service.dart';
import '../../notifications/screens/notification_center_screen.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../incident_reflection/screens/incident_list_screen.dart';
import '../../incident_reflection/providers/incident_provider.dart';
import '../../profile_setup/screens/unified_profile_setup_screen.dart';
import '../../profile_setup/providers/profile_setup_provider.dart';
import '../../points/points.dart';
import '../../home/screens/bug_report_list_screen.dart';
import '../services/clockin_verification_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  UserProfile? _userProfile;
  UserRole? _userRole;
  SystemRole? _systemRole;
  List<SystemRole> _allSystemRoles = [];
  List<DevUserInfo> _allUsers = [];
  String? _userEmail;
  // ใช้ TextEditingController แทน String _userSearchQuery
  // เพื่อใช้กับ ValueListenableBuilder และลด rebuild
  final _userSearchController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  String _appVersion = '';

  // ผลการตรวจสอบ Clock-In (WiFi + GPS)
  ClockInVerificationResult? _clockInResult;
  bool _isVerifying = false;

  // Dev emails that can change role
  static const _devEmails = ['beautyheechul@gmail.com'];

  bool get _isDevMode => _devEmails.contains(_userEmail);
  bool get _isImpersonating => UserService().isImpersonating;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // โหลด version แยกต่างหาก (ไม่ต้องรอ)
    _loadAppVersion();

    await Future.wait([
      _loadUserProfile(),
      _loadUserRole(),
      _loadSystemRole(),
      _loadAllUsers(),
    ]);

    // โหลดสถานะ Clock-In หลังจากได้ user profile (ต้องใช้ nursinghomeId)
    _loadClockInVerification();
  }

  /// โหลด version ของแอปจาก package_info_plus
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version}';
        });
      }
    } catch (e) {
      debugPrint('Load app version error: $e');
    }
  }

  /// โหลดสถานะ Clock-In Verification (GPS + WiFi)
  /// ตรวจสอบว่าเครื่องปัจจุบันอยู่ในรัศมี GPS และเชื่อมต่อ WiFi ที่ลงทะเบียนหรือไม่
  Future<void> _loadClockInVerification() async {
    // ต้องมี nursinghomeId จึงจะตรวจสอบได้
    final nursinghomeId = _userProfile?.nursinghomeId;
    if (nursinghomeId == null) return;

    if (mounted) {
      setState(() => _isVerifying = true);
    }

    try {
      final service = ClockInVerificationService();
      final result = await service.verify(nursinghomeId);
      if (mounted) {
        setState(() {
          _clockInResult = result;
          _isVerifying = false;
        });
      }
    } catch (e) {
      debugPrint('[Settings] Clock-In verification error: $e');
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _loadAllUsers() async {
    try {
      final users = await UserService().getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
        });
      }
    } catch (e) {
      debugPrint('Load all users error: $e');
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      _userEmail = user?.email; // email ดึงจาก auth user จริงเท่านั้น (ไม่ใช้ impersonate)

      final role = await UserService().getRole(forceRefresh: true);
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }
    } catch (e) {
      debugPrint('Load user role error: $e');
    }
  }

  Future<void> _loadSystemRole() async {
    try {
      final userService = UserService();
      final results = await Future.wait([
        userService.getSystemRole(forceRefresh: true),
        userService.getAllSystemRoles(),
      ]);

      if (mounted) {
        setState(() {
          _systemRole = results[0] as SystemRole?;
          _allSystemRoles = results[1] as List<SystemRole>;
        });
      }
    } catch (e) {
      debugPrint('Load system role error: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      // Use effectiveUserId to support dev mode impersonation
      final userId = UserService().effectiveUserId;
      if (userId == null) {
        setState(() {
          _error = 'กรุณาเข้าสู่ระบบก่อน';
          _isLoading = false;
        });
        return;
      }

      // เพิ่ม employment_type เพื่อแสดงสถานะการทำงานใน profile
      final response = await Supabase.instance.client
          .from('user_info')
          .select('id, photo_url, nickname, full_name, prefix, nursinghome_id, employment_type')
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (response != null) {
            _userProfile = UserProfile.fromJson(response);
          } else {
            // Fallback with just user id
            _userProfile = UserProfile(id: userId);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    final shouldLogout = await ConfirmDialog.show(
      context,
      type: ConfirmDialogType.logout,
      imageAsset: 'assets/images/confirm_cat.webp',
      imageSize: 120,
    );

    if (shouldLogout && mounted) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  /// Pull to refresh — โหลดข้อมูลทั้งหมดใหม่ + invalidate providers ที่แสดง badge
  Future<void> _onRefresh() async {
    // Invalidate Riverpod providers เพื่อให้ badge counts โหลดใหม่
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidate(pendingDDCountProvider);
    ref.invalidate(pendingIncidentCountProvider);
    ref.invalidate(profileCompletionStatusProvider);
    ref.invalidate(pendingAbsenceCountProvider);

    // โหลดข้อมูล profile, role, system role, all users ใหม่
    await Future.wait([
      _loadUserProfile(),
      _loadUserRole(),
      _loadSystemRole(),
      _loadAllUsers(),
    ]);

    // โหลดสถานะ Clock-In ใหม่
    _loadClockInVerification();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: CustomScrollView(
          // ต้องใช้ AlwaysScrollableScrollPhysics เพื่อให้ pull-to-refresh ทำงาน
          // แม้ content สั้นกว่าหน้าจอ
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            IreneAppBar(
              title: 'โปรไฟล์',
            ),
            SliverToBoxAdapter(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
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

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'เกิดข้อผิดพลาด',
              style: AppTypography.body,
            ),
            AppSpacing.verticalGapSm,
            Text(
              _error!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error,
              ),
            ),
            AppSpacing.verticalGapMd,
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadUserProfile();
              },
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: [
          AppSpacing.verticalGapMd,
            // Profile Picture
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent1,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              child: _userProfile?.photoUrl != null &&
                      _userProfile!.photoUrl!.isNotEmpty
                  ? IreneNetworkImage(
                      imageUrl: _userProfile!.photoUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      memCacheWidth: 200,
                      borderRadius: AppRadius.fullRadius,
                      errorPlaceholder: _buildDefaultAvatar(),
                    )
                  : _buildDefaultAvatar(),
            ),
            AppSpacing.verticalGapSm,
            // Nickname
            Text(
              _userProfile?.displayName ?? '-',
              style: AppTypography.heading3,
            ),
            AppSpacing.verticalGapXs,
            // Full name with prefix
            Text(
              _userProfile?.fullNameWithPrefix ?? '-',
              style: AppTypography.body.copyWith(
                color: AppColors.primary,
              ),
            ),
            // System Role Badge (ตำแหน่ง) และ Employment Type Badge
            if (_systemRole != null || _userProfile?.employmentTypeDisplay != null) ...[
              AppSpacing.verticalGapSm,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // System Role Badge
                  if (_systemRole != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smallRadius,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedUserAccount,
                            size: AppIconSize.sm,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _systemRole!.name,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Employment Type Badge (ข้างๆ system role)
                  if (_userProfile?.employmentTypeDisplay != null) ...[
                    if (_systemRole != null) SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        // สีแดงถ้าลาออก สีเทาถ้าเป็นสถานะอื่น
                        color: _userProfile!.isResigned
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smallRadius,
                        border: Border.all(
                          color: _userProfile!.isResigned
                              ? Colors.red.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedBriefcase01,
                            size: AppIconSize.sm,
                            color: _userProfile!.isResigned
                                ? Colors.red
                                : Colors.grey.shade600,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _userProfile!.employmentTypeDisplay!,
                            style: AppTypography.caption.copyWith(
                              color: _userProfile!.isResigned
                                  ? Colors.red
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
            AppSpacing.verticalGapMd,
            // สถานะ Clock-In (GPS + WiFi) - แสดงผลการตรวจสอบ
            _buildClockInStatusSection(),
            // Menu Section
            _buildMenuSection(),
            AppSpacing.verticalGapMd,
            // Dev Mode Sections - only for dev emails
            if (_isDevMode) ...[
              // Impersonation warning banner
              if (_isImpersonating) ...[
                _buildImpersonationBanner(),
                AppSpacing.verticalGapMd,
              ],
              _buildDevUserSelector(),
              AppSpacing.verticalGapMd,
              _buildDevRoleSelector(),
              AppSpacing.verticalGapMd,
              _buildDevSystemRoleSelector(),
              AppSpacing.verticalGapMd,
            ],
            AppSpacing.verticalGapMd,
            // Log Out Button
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pastelRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.smallRadius,
                  ),
                ),
                onPressed: _showLogoutDialog,
                child: Text(
                  'ออกจากระบบ',
                  style: AppTypography.button.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            AppSpacing.verticalGapLg,
          ],
        ),
    );
  }

  Widget _buildDefaultAvatar() {
    // ไม่ต้องมี Container กับ color เพราะ parent Container มี decoration circle
    // กับ color อยู่แล้ว - ถ้าใส่ color ตรงนี้จะเป็นสี่เหลี่ยมเกินออกมานอกวงกลม
    return Center(
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedUser,
        size: 40,
        color: AppColors.primary,
      ),
    );
  }

  // ============================================
  // Clock-In Status Section
  // ============================================
  // แสดงสถานะ GPS + WiFi สำหรับ Clock-In
  // ตรวจสอบว่าเครื่องปัจจุบันผ่านเงื่อนไขที่ admin ตั้งไว้หรือไม่

  Widget _buildClockInStatusSection() {
    // ถ้ากำลังตรวจสอบ → แสดง loading
    if (_isVerifying) {
      return _buildSettingsSection(
        title: 'สถานะ Clock-In',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'กำลังตรวจสอบ...',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ถ้าไม่มีผลลัพธ์ (ยังไม่ได้ตรวจ หรือไม่มี nursinghomeId) → ไม่แสดง
    if (_clockInResult == null) return const SizedBox.shrink();

    final result = _clockInResult!;

    // ถ้าทั้ง GPS และ WiFi ไม่ได้เปิดใช้ (null = ไม่ได้ตั้งค่า) → ไม่แสดง
    if (result.gpsMatch == null && result.wifiMatch == null &&
        result.gpsError == null && result.wifiError == null) {
      return const SizedBox.shrink();
    }

    // สร้างรายการ status items ที่จะแสดง
    final List<Widget> statusItems = [];

    // --- GPS Status ---
    if (result.gpsMatch != null || result.gpsError != null) {
      statusItems.add(
        _buildStatusRow(
          icon: HugeIcons.strokeRoundedLocation01,
          label: 'ตำแหน่ง GPS',
          isMatch: result.gpsMatch,
          detail: _buildGpsDetail(result),
          error: result.gpsError,
        ),
      );
    }

    // --- WiFi Status ---
    if (result.wifiMatch != null || result.wifiError != null) {
      // เพิ่ม divider ระหว่าง GPS กับ WiFi
      if (statusItems.isNotEmpty) {
        statusItems.add(Divider(height: 1, color: AppColors.alternate));
      }
      statusItems.add(
        _buildStatusRow(
          icon: HugeIcons.strokeRoundedWifi01,
          label: 'WiFi',
          isMatch: result.wifiMatch,
          detail: _buildWifiDetail(result),
          error: result.wifiError,
        ),
      );
    }

    // ถ้าไม่มี items → ไม่แสดง
    if (statusItems.isEmpty) return const SizedBox.shrink();

    return _buildSettingsSection(
      title: 'สถานะ Clock-In',
      children: [
        // แสดงแต่ละ status item
        ...statusItems,
        // ปุ่ม refresh สำหรับตรวจสอบใหม่
        Divider(height: 1, color: AppColors.alternate),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loadClockInVerification,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    size: AppIconSize.sm,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    'ตรวจสอบอีกครั้ง',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// แต่ละ row ใน Clock-In Status Section
  /// แสดง icon, label, สถานะ (true/false/error), และรายละเอียด
  Widget _buildStatusRow({
    required dynamic icon,
    required String label,
    required bool? isMatch,
    String? detail,
    String? error,
  }) {
    // กำหนดสีตามสถานะ
    final Color statusColor;
    final String statusText;
    final dynamic statusIcon;

    if (error != null) {
      // มี error → สีเหลืองเตือน
      statusColor = Colors.orange;
      statusText = 'ไม่ทราบ';
      statusIcon = HugeIcons.strokeRoundedAlert02;
    } else if (isMatch == true) {
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
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          // Icon container
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
          SizedBox(width: AppSpacing.md),
          // Label + Detail
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.body),
                if (detail != null || error != null) ...[
                  SizedBox(height: 2),
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
          // Status badge
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
                SizedBox(width: 4),
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

  /// สร้าง detail text สำหรับ GPS status
  /// เช่น "ห่างจาก 'ศูนย์ดูแลฯ' 120 ม. (รัศมี 500 ม.)"
  String? _buildGpsDetail(ClockInVerificationResult result) {
    if (result.distanceMeters == null) return result.locationName;

    final distance = result.distanceMeters!.round();
    final radius = result.registeredRadius?.round();
    final name = result.locationName;

    // สร้างข้อความแสดงระยะทาง
    String text = '';
    if (name != null) text += '$name - ';
    text += 'ห่าง $distance ม.';
    if (radius != null) text += ' (รัศมี $radius ม.)';

    return text;
  }

  /// สร้าง detail text สำหรับ WiFi status
  /// เช่น "เชื่อมต่อ: IreneNH-5G" หรือ "ไม่ได้เชื่อมต่อ WiFi"
  String? _buildWifiDetail(ClockInVerificationResult result) {
    if (result.currentSsid == null || result.currentSsid!.isEmpty) {
      return 'ไม่ได้เชื่อมต่อ WiFi';
    }

    if (result.wifiMatch == true) {
      // เชื่อมต่อ WiFi ที่ลงทะเบียน
      return 'เชื่อมต่อ: ${result.currentSsid}';
    } else {
      // เชื่อมต่อ WiFi อื่นที่ไม่ได้ลงทะเบียน
      return 'เชื่อมต่อ: ${result.currentSsid} (ไม่ได้ลงทะเบียน)';
    }
  }

  /// สร้างเมนูทั้งหมดโดยจัดกลุ่มเป็น 4 sections
  Widget _buildMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== Section 1: งานของฉัน =====
        // เมนูที่ใช้บ่อยที่สุด - เกี่ยวกับการทำงานประจำวัน
        _buildSettingsSection(
          title: 'งานของฉัน',
          children: [
            _buildShiftMenuItem(),
            _buildDDMenuItem(),
            _buildIncidentReflectionMenuItem(),
          ],
        ),

        // ===== Section 2: พัฒนาตัวเอง =====
        // เมนูเกี่ยวกับการเรียนรู้และ gamification
        _buildSettingsSection(
          title: 'พัฒนาตัวเอง',
          children: [
            _buildMenuItem(
              icon: HugeIcons.strokeRoundedBook02,
              label: 'เรียนรู้',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DirectoryScreen()),
                );
              },
            ),
            _buildPointsMenuItem(),
            _buildBadgesMenuItem(),
          ],
        ),

        // ===== Section 3: บัญชีของฉัน =====
        // เมนูเกี่ยวกับ account และ profile
        _buildSettingsSection(
          title: 'บัญชีของฉัน',
          children: [
            _buildProfileMenuItem(),
            _buildNotificationMenuItem(),
          ],
        ),

        // ===== Section 4: แอปและความช่วยเหลือ =====
        // เมนูเกี่ยวกับ app settings และ support
        _buildSettingsSection(
          title: 'แอปและความช่วยเหลือ',
          children: [
            _buildMenuItem(
              icon: HugeIcons.strokeRoundedBug01,
              label: 'รายงานปัญหา/Bug',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BugReportListScreen(),
                  ),
                );
              },
            ),
            _buildAboutMenuItem(),
          ],
        ),
      ],
    );
  }

  /// Build shift menu item with badge for pending absences
  Widget _buildShiftMenuItem() {
    final pendingAbsenceAsync = ref.watch(pendingAbsenceCountProvider);
    final badgeCount = pendingAbsenceAsync.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );

    return _buildMenuItem(
      icon: HugeIcons.strokeRoundedCalendar01,
      label: 'เวรของฉัน',
      badgeCount: badgeCount,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShiftSummaryScreen()),
        );
      },
    );
  }

  /// Build DD menu item with badge for pending DD tasks
  Widget _buildDDMenuItem() {
    final pendingDDAsync = ref.watch(pendingDDCountProvider);
    final badgeCount = pendingDDAsync.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );

    return _buildMenuItem(
      icon: HugeIcons.strokeRoundedHospital01,
      label: 'งาน DD',
      badgeCount: badgeCount,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DDListScreen()),
        );
      },
    );
  }

  /// Build incident reflection menu item with badge for pending incidents
  Widget _buildIncidentReflectionMenuItem() {
    final badgeCount = ref.watch(pendingIncidentCountProvider);

    return _buildMenuItem(
      icon: HugeIcons.strokeRoundedBrain,
      label: 'ถอดบทเรียน',
      badgeCount: badgeCount,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IncidentListScreen()),
        );
      },
    );
  }

  /// Build points menu item - แสดงคะแนนสะสมและ tier ปัจจุบัน
  /// กดเพื่อไปหน้า Leaderboard
  Widget _buildPointsMenuItem() {
    // ดึงข้อมูล points summary จาก provider
    final summaryAsync = ref.watch(userPointsSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        // แสดงคะแนนใน subtitle ถ้ามีข้อมูล
        final pointsText = summary != null
            ? '${summary.totalPoints} คะแนน'
            : null;

        return _buildMenuItemWithSubtitle(
          icon: HugeIcons.strokeRoundedRanking,
          label: 'คะแนนของฉัน',
          subtitle: pointsText,
          tierIcon: summary?.tierIcon,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            );
          },
        );
      },
      loading: () => _buildMenuItem(
        icon: HugeIcons.strokeRoundedRanking,
        label: 'คะแนนของฉัน',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
          );
        },
      ),
      error: (error, stack) => _buildMenuItem(
        icon: HugeIcons.strokeRoundedRanking,
        label: 'คะแนนของฉัน',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
          );
        },
      ),
    );
  }

  /// Menu item พร้อม subtitle และ tier icon (สำหรับ Points menu)
  Widget _buildMenuItemWithSubtitle({
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
    String? subtitle,
    String? tierIcon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mediumRadius,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(icon: icon, color: AppColors.primary, size: AppIconSize.lg),
                ),
              ),
              AppSpacing.horizontalGapMd,
              // Label และ subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTypography.body),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (tierIcon != null) ...[
                            Text(tierIcon, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            subtitle,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Arrow icon
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: AppIconSize.md,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build notification menu item with badge count for unread notifications
  Widget _buildNotificationMenuItem() {
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);
    final unreadCount = unreadCountAsync.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );

    return _buildMenuItem(
      icon: HugeIcons.strokeRoundedNotification02,
      label: 'การแจ้งเตือน',
      badgeCount: unreadCount,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
        );
      },
    );
  }

  /// Build badges menu item - กดเพื่อไปหน้า BadgeCollectionScreen
  Widget _buildBadgesMenuItem() {
    return _buildMenuItem(
      icon: HugeIcons.strokeRoundedMedal01,
      label: 'Badges ที่ได้รับ',
      // ไม่แสดง badge count เพราะเป็น total count ไม่ใช่ new/unread
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BadgeCollectionScreen()),
        );
      },
    );
  }

  /// Build about app menu item - แสดง version ของแอป
  Widget _buildAboutMenuItem() {
    return _buildMenuItemWithSubtitle(
      icon: HugeIcons.strokeRoundedInformationCircle,
      label: 'เกี่ยวกับแอป',
      subtitle: _appVersion.isNotEmpty ? _appVersion : null,
      onTap: () {
        // แสดง dialog ข้อมูลแอป
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Image.asset(
                  'assets/app_icon.png',
                  width: 40,
                  height: 40,
                ),
                AppSpacing.horizontalGapMd,
                const Text('Irene Training'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version: $_appVersion',
                  style: AppTypography.body,
                ),
                AppSpacing.verticalGapSm,
                Text(
                  'แอปสำหรับฝึกอบรมและพัฒนาทักษะ\nผู้ดูแลผู้สูงอายุ',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ปิด'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build profile menu item with badge showing incomplete profile pages
  /// แสดง badge ถ้ายังกรอกข้อมูลไม่ครบทั้ง 3 หน้า
  Widget _buildProfileMenuItem() {
    final completionAsync = ref.watch(profileCompletionStatusProvider);
    final incompleteCount = completionAsync.maybeWhen(
      data: (status) => status.isComplete ? 0 : status.incompleteCount,
      orElse: () => 0,
    );

    return _buildMenuItem(
      icon: HugeIcons.strokeRoundedUserEdit01,
      label: 'แก้ไขโปรไฟล์',
      badgeCount: incompleteCount,
      onTap: () {
        Navigator.push(
          context,
          // showAsOnboarding: false → ไม่มี header gradient, มีปุ่มกลับ
          MaterialPageRoute(builder: (_) => const UnifiedProfileSetupScreen()),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mediumRadius,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent1,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: HugeIcon(icon: icon, color: AppColors.primary, size: AppIconSize.lg),
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : badgeCount.toString(),
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              AppSpacing.horizontalGapMd,
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body,
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: AppIconSize.md,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Section container สำหรับจัดกลุ่มเมนู
  /// มี header text สีเทา และ container สีขาวสำหรับ menu items
  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    // สร้าง list ของ children พร้อม dividers
    final List<Widget> itemsWithDividers = [];
    for (int i = 0; i < children.length; i++) {
      itemsWithDividers.add(children[i]);
      // เพิ่ม divider ระหว่าง items (ไม่เพิ่มหลังตัวสุดท้าย)
      if (i < children.length - 1) {
        itemsWithDividers.add(Divider(height: 1, color: AppColors.alternate));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header (label style, สีเทา)
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xs, // left - เยื้องเล็กน้อย
            AppSpacing.lg, // top - เว้นระยะจาก section ก่อนหน้า
            AppSpacing.xs, // right
            AppSpacing.sm, // bottom
          ),
          child: Text(
            title,
            style: AppTypography.label.copyWith(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Menu Items Container
        Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadius.mediumRadius,
            border: Border.all(color: AppColors.alternate),
          ),
          child: Column(children: itemsWithDividers),
        ),
      ],
    );
  }

  Widget _buildImpersonationBanner() {
    final userService = UserService();
    final impersonatedUser = _allUsers.where(
      (u) => u.id == userService.effectiveUserId,
    ).firstOrNull;

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: Colors.red.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: AppIconSize.lg, color: Colors.red.shade700),
              AppSpacing.horizontalGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'กำลังใช้งานในนามของ: ${impersonatedUser?.displayName ?? "Unknown"}',
                      style: AppTypography.label.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                    // แสดง employment_type ของ user ที่กำลัง impersonate
                    if (impersonatedUser?.employmentTypeDisplay != null)
                      Text(
                        'สถานะ: ${impersonatedUser!.employmentTypeDisplay}',
                        style: AppTypography.caption.copyWith(
                          color: impersonatedUser.isResigned
                              ? Colors.red.shade900
                              : Colors.red.shade600,
                          fontWeight: impersonatedUser.isResigned
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _stopImpersonating,
              icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowTurnBackward, size: AppIconSize.md),
              label: Text('กลับมาเป็นตัวฉันเอง'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.smallRadius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _stopImpersonating() async {
    UserService().stopImpersonating();

    // Invalidate all service caches
    _invalidateAllCaches();

    // Increment user change counter to refresh Riverpod providers
    ref.read(userChangeCounterProvider.notifier).state++;

    // Reload all data
    setState(() {
      _isLoading = true;
    });
    await _loadData();

    if (!mounted) return;

    AppSnackbar.info(context, 'กลับมาเป็นตัวคุณเองแล้ว');
  }

  /// Invalidate all service caches when switching users
  void _invalidateAllCaches() {
    HomeService.instance.invalidateCache();
    ClockService.instance.invalidateCache();
    ShiftSummaryService.instance.invalidateCache();
    DDService.instance.invalidateCache();
  }

  Widget _buildDevUserSelector() {
    final userService = UserService();
    final currentEffectiveUserId = userService.effectiveUserId;

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.cyan.shade50,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: Colors.cyan.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedUserEdit01,
                size: AppIconSize.sm,
                color: Colors.cyan.shade700,
              ),
              AppSpacing.horizontalGapSm,
              Text(
                'Dev Mode - สวมรอยเป็น User อื่น',
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.cyan.shade700,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapSm,
          Text(
            'User ปัจจุบัน: ${_userProfile?.displayName ?? "-"}',
            style: AppTypography.bodySmall.copyWith(
              color: Colors.purple.shade900,
            ),
          ),
          AppSpacing.verticalGapMd,
          // Search field - ใช้ controller แทน onChanged + setState
          TextField(
            controller: _userSearchController,
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อ...',
              hintStyle: AppTypography.bodySmall.copyWith(
                color: Colors.purple.shade300,
              ),
              prefixIcon: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  size: AppIconSize.md,
                  color: Colors.purple.shade400,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide(color: Colors.purple.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide(color: Colors.purple.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide(color: Colors.purple, width: 2),
              ),
            ),
            style: AppTypography.body.copyWith(
              color: Colors.purple.shade900,
            ),
          ),
          AppSpacing.verticalGapMd,
          // ใช้ ValueListenableBuilder เพื่อ rebuild เฉพาะ list เมื่อ search text เปลี่ยน
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _userSearchController,
            builder: (context, textValue, child) {
              final searchQuery = textValue.text;

              // Filter users by search query
              final filteredUsers = searchQuery.isEmpty
                  ? _allUsers
                  : _allUsers.where((user) {
                      final query = searchQuery.toLowerCase();
                      final nickname = user.nickname?.toLowerCase() ?? '';
                      final fullName = user.fullName?.toLowerCase() ?? '';
                      return nickname.contains(query) ||
                          fullName.contains(query);
                    }).toList();

              if (_isLoading) {
                return Text(
                  'กำลังโหลดรายชื่อ...',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.purple.shade600,
                  ),
                );
              }

              if (_allUsers.isEmpty) {
                return Text(
                  'ไม่พบรายชื่อพนักงาน',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.purple.shade600,
                  ),
                );
              }

              if (filteredUsers.isEmpty) {
                return Text(
                  'ไม่พบผู้ใช้ที่ค้นหา',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.purple.shade600,
                  ),
                );
              }

              return Container(
                constraints: BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.smallRadius,
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredUsers.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.purple.shade100,
                  ),
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final isSelected = user.id == currentEffectiveUserId;

                    return _buildUserListTile(
                        user: user, isSelected: isSelected);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserListTile({
    required DevUserInfo user,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _impersonateUser(user),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.purple.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Avatar with clocked-in indicator
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.purple, width: 2)
                        : null,
                  ),
                  // ใช้ IreneNetworkAvatar แทน Image.network
                  // เพื่อให้มี timeout, retry และ error handling ที่ดีกว่า
                  child: IreneNetworkAvatar(
                    imageUrl: user.photoUrl,
                    radius: 20,
                    fallbackIcon: HugeIcon(
                      icon: HugeIcons.strokeRoundedUser,
                      size: AppIconSize.lg,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
                // Clocked-in indicator (green dot)
                if (user.isClockedIn)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.horizontalGapMd,
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.nickname ?? '-',
                          style: AppTypography.body.copyWith(
                            color: Colors.purple.shade900,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // แสดง badge สถานะการทำงาน
                      if (user.employmentTypeDisplay != null) ...[
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            // สีแดงถ้าลาออก สีเทาถ้าเป็นสถานะอื่น
                            color: user.isResigned
                                ? Colors.red.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user.employmentTypeDisplay!,
                            style: AppTypography.caption.copyWith(
                              fontSize: 9,
                              color: user.isResigned
                                  ? Colors.red.shade700
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (user.isClockedIn) ...[
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user.clockedInZones.isNotEmpty
                                ? user.clockedInZones.join(', ')
                                : 'ขึ้นเวร',
                            style: AppTypography.caption.copyWith(
                              fontSize: 9,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (user.fullName != null)
                    Text(
                      user.fullName!,
                      style: AppTypography.caption.copyWith(
                        color: Colors.purple.shade600,
                      ),
                    ),
                ],
              ),
            ),
            // Check icon
            if (isSelected)
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                size: AppIconSize.lg,
                color: Colors.purple,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _impersonateUser(DevUserInfo user) async {
    final success = await UserService().impersonateUser(user.id);

    if (!success) {
      if (!mounted) return;
      AppSnackbar.error(context, 'เกิดข้อผิดพลาดในการสวมรอย');
      return;
    }

    // Invalidate all service caches
    _invalidateAllCaches();

    // Increment user change counter to refresh Riverpod providers
    ref.read(userChangeCounterProvider.notifier).state++;

    // Reload all data for the impersonated user
    setState(() {
      _isLoading = true;
    });
    await _loadData();

    if (!mounted) return;

    AppSnackbar.info(context, 'สวมรอยเป็น: ${user.displayName}');
  }

  Widget _buildDevRoleSelector() {
    final roles = [
      {'name': null, 'display': 'พนักงาน (ไม่มี role)', 'color': Colors.grey},
      {'name': 'admin', 'display': 'Admin (หัวหน้าเวร)', 'color': Colors.indigo},
      {'name': 'superAdmin', 'display': 'Super Admin', 'color': Colors.red},
    ];

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedSourceCode, size: AppIconSize.sm, color: Colors.amber.shade700),
              AppSpacing.horizontalGapSm,
              Text(
                'Dev Mode - เลือก Role',
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapSm,
          Text(
            'Role ปัจจุบัน: ${_userRole?.displayName ?? "พนักงาน"}',
            style: AppTypography.bodySmall.copyWith(
              color: Colors.amber.shade900,
            ),
          ),
          AppSpacing.verticalGapMd,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: roles.map((role) {
              final isSelected = _userRole?.name == role['name'];
              final color = role['color'] as Color;

              return InkWell(
                onTap: () => _changeRole(role['name'] as String?),
                borderRadius: AppRadius.smallRadius,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.2)
                        : color.withValues(alpha: 0.05),
                    borderRadius: AppRadius.smallRadius,
                    border: Border.all(
                      color: isSelected
                          ? color
                          : color.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                          size: AppIconSize.sm,
                          color: color,
                        ),
                        SizedBox(width: 4),
                      ],
                      Text(
                        role['display'] as String,
                        style: AppTypography.bodySmall.copyWith(
                          color: color,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _changeRole(String? roleName) async {
    final success = await UserService().updateRole(roleName);
    if (!mounted) return;

    if (success) {
      // Reload role
      await _loadUserRole();
      if (!mounted) return;

      AppSnackbar.success(context, 'เปลี่ยน role เป็น: ${roleName ?? "พนักงาน"}');
    } else {
      AppSnackbar.error(context, 'ไม่สามารถเปลี่ยน role ได้');
    }
  }

  Widget _buildDevSystemRoleSelector() {
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedUserAccount, size: AppIconSize.sm, color: Colors.teal.shade700),
              AppSpacing.horizontalGapSm,
              Text(
                'Dev Mode - เลือก System Role (ตำแหน่ง)',
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade700,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapSm,
          Text(
            'ตำแหน่งปัจจุบัน: ${_systemRole?.name ?? "ไม่ระบุ"}',
            style: AppTypography.bodySmall.copyWith(
              color: Colors.teal.shade900,
            ),
          ),
          AppSpacing.verticalGapMd,
          if (_allSystemRoles.isEmpty)
            Column(
              children: [
                Image.asset(
                  'assets/images/not_found.webp',
                  width: 80,
                  height: 80,
                ),
                AppSpacing.verticalGapSm,
                Text(
                  'ไม่พบ system roles ในระบบ',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.teal.shade600,
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                // Option: ไม่มี role
                _buildSystemRoleChip(
                  id: null,
                  name: 'ไม่ระบุ',
                  isSelected: _systemRole == null,
                ),
                // All available roles
                ..._allSystemRoles.map((role) => _buildSystemRoleChip(
                      id: role.id,
                      name: role.name,
                      isSelected: _systemRole?.id == role.id,
                    )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSystemRoleChip({
    required int? id,
    required String name,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _changeSystemRole(id),
      borderRadius: AppRadius.smallRadius,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.teal.withValues(alpha: 0.2)
              : Colors.teal.withValues(alpha: 0.05),
          borderRadius: AppRadius.smallRadius,
          border: Border.all(
            color: isSelected
                ? Colors.teal
                : Colors.teal.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                size: AppIconSize.sm,
                color: Colors.teal,
              ),
              SizedBox(width: 4),
            ],
            Text(
              name,
              style: AppTypography.bodySmall.copyWith(
                color: Colors.teal.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeSystemRole(int? roleId) async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) return;

      await Supabase.instance.client
          .from('user_info')
          .update({'role_id': roleId})
          .eq('id', userId);

      // Clear cached role in UserService
      UserService().clearCache();

      // Invalidate Riverpod providers to refresh role in other screens
      ref.invalidate(currentUserSystemRoleProvider);
      ref.invalidate(effectiveRoleFilterProvider);

      // Reload system role for local state
      await _loadSystemRole();
      if (!mounted) return;

      final roleName = roleId == null
          ? 'ไม่ระบุ'
          : _allSystemRoles.firstWhere((r) => r.id == roleId).name;

      AppSnackbar.success(context, 'เปลี่ยนตำแหน่งเป็น: $roleName');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'ไม่สามารถเปลี่ยนตำแหน่งได้');
    }
  }

}
