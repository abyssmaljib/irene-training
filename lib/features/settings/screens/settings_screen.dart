import 'package:flutter/material.dart' hide Badge;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../auth/screens/login_screen.dart';
import '../../learning/models/badge.dart';
import '../../learning/models/thinking_skill_data.dart';
import '../../learning/services/badge_service.dart';
// TODO: Temporarily hidden - import '../../learning/widgets/skill_visualization_section.dart';
import '../models/user_profile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserProfile? _userProfile;
  // NOTE: _skillsData temporarily unused - skill visualization hidden for review
  // ignore: unused_field
  ThinkingSkillsData? _skillsData;
  List<Badge> _earnedBadges = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUserProfile(),
      _loadThinkingSkills(),
      _loadBadges(),
    ]);
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
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mediumRadius,
        ),
        title: Text(
          'ออกจากระบบ',
          style: AppTypography.title,
        ),
        content: Text(
          'คุณต้องการออกจากระบบหรือไม่?',
          style: AppTypography.body,
        ),
        actions: [
          SecondaryButton(
            text: 'ยกเลิก',
            onPressed: () => Navigator.pop(context, false),
          ),
          AppSpacing.horizontalGapSm,
          DangerButton(
            text: 'ออกจากระบบ',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
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
      appBar: AppBar(
        backgroundColor: AppColors.secondaryBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'ตั้งค่า',
          style: AppTypography.title,
        ),
        centerTitle: false,
      ),
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
      child: Padding(
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
            AppSpacing.verticalGapMd,
            // Badges Section - แสดงเสมอ
            _buildBadgesSection(),
            AppSpacing.verticalGapMd,
            // TODO: Thinking Skills Section temporarily hidden for review
            // if (_skillsData != null && _skillsData!.hasData)
            //   Expanded(
            //     child: SingleChildScrollView(
            //       child: SkillVisualizationSection(
            //         skillsData: _skillsData,
            //       ),
            //     ),
            //   )
            // else
            const Spacer(),
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
