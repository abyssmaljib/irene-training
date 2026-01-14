import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/services/user_service.dart';
import '../../checklist/models/system_role.dart';
import '../../checklist/providers/task_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../learning/screens/directory_screen.dart';
import '../../learning/models/badge.dart';
import '../../learning/models/thinking_skill_data.dart';
import '../../learning/services/badge_service.dart';
import '../../learning/screens/badge_collection_screen.dart';
// TODO: Temporarily hidden - import '../../learning/widgets/skill_visualization_section.dart';
import '../models/user_profile.dart';
import '../../../core/widgets/irene_app_bar.dart';
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
// NOTE: Tutorial feature ถูกซ่อนไว้ชั่วคราว
// import '../../navigation/screens/main_navigation_screen.dart';

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
  String _userSearchQuery = '';
  // NOTE: _skillsData temporarily unused - skill visualization hidden for review
  // ignore: unused_field
  ThinkingSkillsData? _skillsData;
  List<Badge> _earnedBadges = [];
  bool _isLoading = true;
  String? _error;

  // Dev emails that can change role
  static const _devEmails = ['beautyheechul@gmail.com'];

  bool get _isDevMode => _devEmails.contains(_userEmail);
  bool get _isImpersonating => UserService().isImpersonating;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUserProfile(),
      _loadUserRole(),
      _loadSystemRole(),
      _loadThinkingSkills(),
      _loadBadges(),
      _loadAllUsers(),
    ]);
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

  Future<void> _loadBadges() async {
    try {
      final badgeService = BadgeService();
      final badges = await badgeService.getUserBadges();
      if (mounted) {
        setState(() {
          _earnedBadges = badges;
        });
      }
    } catch (e) {
      debugPrint('Load badges error: $e');
    }
  }

  Future<void> _loadThinkingSkills() async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('training_v_thinking_analysis')
          .select('*');

      if (mounted && response.isNotEmpty) {
        final Map<String, dynamic> breakdown = {};
        for (final row in response) {
          breakdown[row['thinking_type'] as String] = {
            'total': row['total_questions'],
            'correct': row['correct_count'],
            'percent': row['percent_correct'],
          };
        }

        setState(() {
          _skillsData = ThinkingSkillsData.fromThinkingBreakdown(breakdown);
        });
      }
    } catch (e) {
      debugPrint('Thinking skills error: $e');
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

      final response = await Supabase.instance.client
          .from('user_info')
          .select('id, photo_url, nickname, full_name, prefix, nursinghome_id')
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: CustomScrollView(
        slivers: [
          IreneAppBar(
            title: 'โปรไฟล์',
          ),
          SliverToBoxAdapter(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
              child: ClipRRect(
                borderRadius: AppRadius.fullRadius,
                child: _userProfile?.photoUrl != null &&
                        _userProfile!.photoUrl!.isNotEmpty
                    ? Image.network(
                        _userProfile!.photoUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultAvatar();
                        },
                      )
                    : _buildDefaultAvatar(),
              ),
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
            // System Role Badge (ตำแหน่ง)
            if (_systemRole != null) ...[
              AppSpacing.verticalGapSm,
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
            ],
            AppSpacing.verticalGapMd,
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
            // Badges Section - แสดงเสมอ
            _buildBadgesSection(),
            AppSpacing.verticalGapMd,
            // TODO: Thinking Skills Section temporarily hidden for review
            // if (_skillsData != null && _skillsData!.hasData)
            //   SkillVisualizationSection(
            //     skillsData: _skillsData,
            //   ),
            AppSpacing.verticalGapXl,
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
    return Container(
      width: 80,
      height: 80,
      color: AppColors.accent1,
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedUser,
          size: 40,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: AppColors.alternate),
      ),
      child: Column(
        children: [
          _buildNotificationMenuItem(),
          Divider(height: 1, color: AppColors.alternate),
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
          Divider(height: 1, color: AppColors.alternate),
          _buildShiftMenuItem(),
          Divider(height: 1, color: AppColors.alternate),
          _buildDDMenuItem(),
          Divider(height: 1, color: AppColors.alternate),
          _buildMenuItem(
            icon: HugeIcons.strokeRoundedAlert02,
            label: 'ใบเตือน',
            onTap: () {
              // TODO: Navigate to warnings screen
            },
          ),
          Divider(height: 1, color: AppColors.alternate),
          _buildMenuItem(
            icon: HugeIcons.strokeRoundedSettings02,
            label: 'ตั้งค่า',
            onTap: () {
              // TODO: Navigate to app settings
            },
          ),
          // NOTE: Tutorial feature ถูกซ่อนไว้ชั่วคราว
          // Divider(height: 1, color: AppColors.alternate),
          // _buildMenuItem(
          //   icon: HugeIcons.strokeRoundedHelpCircle,
          //   label: 'ดู Tutorial อีกครั้ง',
          //   onTap: () {
          //     Navigator.pop(context);
          //     MainNavigationScreen.navigateToTab(context, 0);
          //     MainNavigationScreen.replayTutorial(context);
          //   },
          // ),
        ],
      ),
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
                child: Text(
                  'กำลังใช้งานในนามของ: ${impersonatedUser?.displayName ?? "Unknown"}',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('กลับมาเป็นตัวคุณเองแล้ว'),
        backgroundColor: AppColors.primary,
      ),
    );
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

    // Filter users by search query
    final filteredUsers = _userSearchQuery.isEmpty
        ? _allUsers
        : _allUsers.where((user) {
            final query = _userSearchQuery.toLowerCase();
            final nickname = user.nickname?.toLowerCase() ?? '';
            final fullName = user.fullName?.toLowerCase() ?? '';
            return nickname.contains(query) || fullName.contains(query);
          }).toList();

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
              HugeIcon(icon: HugeIcons.strokeRoundedUserEdit01, size: AppIconSize.sm, color: Colors.cyan.shade700),
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
          // Search field
          TextField(
            onChanged: (value) => setState(() => _userSearchQuery = value),
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
          if (_isLoading)
            Text(
              'กำลังโหลดรายชื่อ...',
              style: AppTypography.bodySmall.copyWith(
                color: Colors.purple.shade600,
              ),
            )
          else if (_allUsers.isEmpty)
             Text(
              'ไม่พบรายชื่อพนักงาน',
              style: AppTypography.bodySmall.copyWith(
                color: Colors.purple.shade600,
              ),
            )
          else if (filteredUsers.isEmpty)
            Text(
              'ไม่พบผู้ใช้ที่ค้นหา',
              style: AppTypography.bodySmall.copyWith(
                color: Colors.purple.shade600,
              ),
            )
          else
            Container(
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

                  return _buildUserListTile(user: user, isSelected: isSelected);
                },
              ),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? Image.network(
                            user.photoUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedUser,
                                size: AppIconSize.lg,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          )
                        : Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedUser,
                              size: AppIconSize.lg,
                              color: Colors.purple.shade700,
                            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการสวมรอย'),
          backgroundColor: AppColors.error,
        ),
      );
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('สวมรอยเป็น: ${user.displayName}'),
        backgroundColor: Colors.purple,
      ),
    );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'เปลี่ยน role เป็น: ${roleName ?? "พนักงาน"}',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ไม่สามารถเปลี่ยน role ได้'),
          backgroundColor: AppColors.error,
        ),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เปลี่ยนตำแหน่งเป็น: $roleName'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ไม่สามารถเปลี่ยนตำแหน่งได้'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// สร้าง section แสดง badges ที่ได้รับ
  /// เมื่อกดจะ navigate ไปหน้า BadgeCollectionScreen
  Widget _buildBadgesSection() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // เมื่อกดจะไปหน้า Badge Collection
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BadgeCollectionScreen(),
            ),
          );
        },
        borderRadius: AppRadius.mediumRadius,
        child: Container(
          width: double.infinity,
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadius.mediumRadius,
            border: Border.all(color: AppColors.alternate),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedMedal01,
                    color: AppColors.primary,
                    size: AppIconSize.lg,
                  ),
                  AppSpacing.horizontalGapSm,
                  Text(
                    'Badges ที่ได้รับ',
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.smallRadius,
                    ),
                    child: Text(
                      '${_earnedBadges.length}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Arrow icon แสดงว่ากดได้
                  const SizedBox(width: 8),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: AppColors.secondaryText,
                    size: AppIconSize.md,
                  ),
                ],
              ),
              AppSpacing.verticalGapMd,
              if (_earnedBadges.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'ยังไม่มี badge - ทำแบบทดสอบเพื่อรับ badge!',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _earnedBadges.map((badge) => _buildBadgeItem(badge)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeItem(Badge badge) {
    final rarityColor = _getRarityColor(badge.rarity);

    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: rarityColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: rarityColor, width: 2),
            ),
            child: Center(
              child: badge.imageUrl != null
                  ? ClipOval(
                      child: Image.network(
                        badge.imageUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Text(
                          badge.icon ?? badge.rarityEmoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    )
                  : Text(
                      badge.icon ?? badge.rarityEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge.name,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              color: AppColors.primaryText,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'legendary':
        return const Color(0xFFFFD700);
      case 'epic':
        return const Color(0xFF9B59B6);
      case 'rare':
        return const Color(0xFF3498DB);
      default:
        return AppColors.primary;
    }
  }
}
