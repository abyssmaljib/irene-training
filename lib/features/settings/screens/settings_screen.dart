import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
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
import '../../learning/widgets/badge_info_dialog.dart';
// TODO: Temporarily hidden - import '../../learning/widgets/skill_visualization_section.dart';
import '../models/user_profile.dart';
import '../../../core/widgets/irene_app_bar.dart';

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
  String? _userEmail;
  // NOTE: _skillsData temporarily unused - skill visualization hidden for review
  // ignore: unused_field
  ThinkingSkillsData? _skillsData;
  List<Badge> _earnedBadges = [];
  bool _isLoading = true;
  String? _error;

  // Dev emails that can change role
  static const _devEmails = ['beautyheechul@gmail.com'];

  bool get _isDevMode => _devEmails.contains(_userEmail);

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
    ]);
  }

  Future<void> _loadUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      _userEmail = user?.email;

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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'กรุณาเข้าสู่ระบบก่อน';
          _isLoading = false;
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('user_info')
          .select('id, photo_url, nickname, full_name, prefix, nursinghome_id')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (response != null) {
            _userProfile = UserProfile.fromJson(response);
          } else {
            // Fallback with just user id
            _userProfile = UserProfile(id: user.id);
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
      appBar: const IreneSecondaryAppBar(title: 'โปรไฟล์'),
      body: _buildBody(),
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          children: [
            AppSpacing.verticalGapXl,
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
            // User Role Badge
            if (_userRole != null) ...[
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
                    Icon(
                      Iconsax.user_tag,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _userRole!.displayName,
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
            // Dev Role Selector - only for dev emails
            if (_isDevMode) ...[
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
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 80,
      height: 80,
      color: AppColors.accent1,
      child: const Icon(
        Icons.person,
        size: 40,
        color: AppColors.primary,
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
          _buildMenuItem(
            icon: Iconsax.book_1,
            label: 'เรียนรู้',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DirectoryScreen()),
              );
            },
          ),
          Divider(height: 1, color: AppColors.alternate),
          _buildMenuItem(
            icon: Iconsax.calendar_1,
            label: 'เวรของฉัน',
            onTap: () {
              // TODO: Navigate to shift screen
            },
          ),
          Divider(height: 1, color: AppColors.alternate),
          _buildMenuItem(
            icon: Iconsax.warning_2,
            label: 'ใบเตือน',
            onTap: () {
              // TODO: Navigate to warnings screen
            },
          ),
          Divider(height: 1, color: AppColors.alternate),
          _buildMenuItem(
            icon: Iconsax.setting_2,
            label: 'ตั้งค่า',
            onTap: () {
              // TODO: Navigate to app settings
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              AppSpacing.horizontalGapMd,
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body,
                ),
              ),
              Icon(
                Iconsax.arrow_right_3,
                size: 18,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
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
              Icon(Iconsax.code, size: 16, color: Colors.amber.shade700),
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
                        Icon(
                          Iconsax.tick_circle,
                          size: 16,
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
              Icon(Iconsax.user_tag, size: 16, color: Colors.teal.shade700),
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
            Text(
              'ไม่พบ system roles ในระบบ',
              style: AppTypography.bodySmall.copyWith(
                color: Colors.teal.shade600,
              ),
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
              Icon(
                Iconsax.tick_circle,
                size: 16,
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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('user_info')
          .update({'role_id': roleId})
          .eq('id', user.id);

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

  Widget _buildBadgesSection() {
    return Container(
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
              const Icon(
                Icons.workspace_premium,
                color: AppColors.primary,
                size: 20,
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
              // Info button - min 48px tap target
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  onPressed: () => BadgeInfoDialog.show(context),
                  icon: const Icon(
                    Iconsax.info_circle,
                    color: AppColors.secondaryText,
                    size: 20,
                  ),
                ),
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
