
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../models/clock_in_out.dart';
import '../models/shift_activity_stats.dart';
import '../services/clock_service.dart';
import '../services/home_service.dart';
import '../../navigation/screens/main_navigation_screen.dart';

class ShiftSummaryScreen extends StatefulWidget {
  final ClockInOut currentShift;

  const ShiftSummaryScreen({
    super.key,
    required this.currentShift,
  });

  @override
  State<ShiftSummaryScreen> createState() => _ShiftSummaryScreenState();
}

class _ShiftSummaryScreenState extends State<ShiftSummaryScreen> {
  final _clockService = ClockService.instance;
  final _homeService = HomeService.instance;

  // Data
  ShiftActivityStats? _stats;
  List<Map<String, dynamic>> _remainingTasksList = [];

  // Ratings & Survey
  int _shiftScore = 3;
  int _selfScore = 3;
  final _shiftSurveyController = TextEditingController();
  final _bugSurveyController = TextEditingController();

  // State
  int _remainingTasks = 0;
  bool _isLoading = true;
  bool _isClockingOut = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _shiftSurveyController.dispose();
    _bugSurveyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final remaining = await _homeService.getRemainingTasksCount(
        shift: widget.currentShift.shift,
      );

      final remainingList = await _homeService.getRemainingTasks(
         shift: widget.currentShift.shift,
         limit: 5,
      );

      // ดึง break time options ตาม shift แล้ว filter ตาม ID ที่ user เลือก
      final allBreakTimeOptions = await _clockService.getBreakTimeOptions(
        shift: widget.currentShift.shift,
      );
      final selectedBreakTimes = allBreakTimeOptions
          .where((b) => widget.currentShift.selectedBreakTime.contains(b.id))
          .toList();

      final stats = await _homeService.getShiftActivityStats(
        residentIds: widget.currentShift.selectedResidentIdList,
        clockInTime: widget.currentShift.clockInTimestamp ?? DateTime.now(),
        selectedBreakTimes: selectedBreakTimes,
      );

      if (mounted) {
        setState(() {
          _remainingTasks = remaining;
          _remainingTasksList = remainingList;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleClockOut() async {
    if (_remainingTasks > 0) return;
    
    if (_shiftSurveyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเขียนสรุปเวรด้วยนะคะ')),
      );
      return;
    }

    setState(() => _isClockingOut = true);
    
    // Check for unread announcements
    final unreadCount = await _clockService.getUnreadAnnouncementsCount();
    if (unreadCount > 0 && mounted) {
      setState(() => _isClockingOut = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ มีประกาศสำคัญที่ยังไม่ได้อ่าน'),
          content: const Text('กรุณาไปที่หน้าบอร์ดเพื่ออ่านและรับทราบประกาศก่อนลงเวร'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                MainNavigationScreen.navigateToTab(context, 3);
              },
              child: const Text('ไปหน้าบอร์ด'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      );
      return;
    }

    final success = await _clockService.clockOutWithSurvey(
      clockRecordId: widget.currentShift.id!,
      shiftScore: _shiftScore,
      selfScore: _selfScore,
      shiftSurvey: _shiftSurveyController.text.trim(),
      bugSurvey: _bugSurveyController.text.trim(),
    );

    if (mounted) {
      setState(() => _isClockingOut = false);
      if (success) {
        if (context.canPop()) {
           context.pop(true);
        } else {
           Navigator.of(context).pop(true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาดในการลงเวร')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   _buildHeader(context),
                   
                   Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Column(
                       children: [
                          _buildThankYouSection(),
                          const SizedBox(height: 24),
                          
                          if (_stats != null) _buildSummaryGrid(),
                          const SizedBox(height: 24),
                          
                          _buildComparisonSection(),
                          const SizedBox(height: 24),
                          
                          _buildRankingSection(),
                          const SizedBox(height: 24),
                          
                          _buildSurveySection(),
                          const SizedBox(height: 24),
                          
                          if (_remainingTasksList.isNotEmpty) ...[
                            _buildRemainingTasksList(),
                            const SizedBox(height: 24),
                          ],
                          
                          _buildOffDutyButton(),
                       ],
                     ),
                   ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 48, bottom: 24, left: 16, right: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            blurRadius: 4.0,
            color: AppColors.primary.withValues(alpha: 0.1),
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).pop(); 
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: [
                    AppColors.tertiary,
                    AppColors.secondary,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.arrow_up_1, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'กลับไปดูรายละเอียดในเวร',
                    style: AppTypography.title.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Iconsax.arrow_up_1, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThankYouSection() {
    return Column(
      children: [
        _GradientText(
          'THANK YOU FOR YOUR SERVICE',
          gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
          style: AppTypography.heading3.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _GradientText(
          'ขอบคุณที่ทำงานอย่างหนักในวันนี้',
          gradient: LinearGradient(colors: [Colors.redAccent, AppColors.tertiary]),
          style: AppTypography.heading3.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid() {
    return Column(
      children: [
        Row(
          children: [
             Expanded(child: _buildStatCard(_stats!.totalCompleted.toString(), '📋งานทั้งหมด')),
             const SizedBox(width: 8),
             Expanded(child: _buildStatCard(_stats!.onTimeCount.toString(), '⏱️ตรงเวลา')),
             const SizedBox(width: 8),
             Expanded(child: _buildStatCard((_stats!.slightlyLateCount + _stats!.veryLateCount).toString(), '⚠️เลท/ปัญหา')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard('-', '🩺วัด v/s')),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('-', '📝สร้างโพส')),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('-', '💊จัดการยา')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.heading3.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(
             label,
             style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
  
  Widget _buildComparisonSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📈เปรียบเทียบ', style: AppTypography.heading3),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompItem('+47', 'จากเมื่อวาน', AppColors.primary),
              Container(width: 1, height: 40, color: AppColors.alternate),
              _buildCompItem('+23', 'vs เพื่อนเวร', AppColors.primary),
              Container(width: 1, height: 40, color: AppColors.alternate),
              _buildCompItem('-18', 'จากสัปดาห์ที่แล้ว', Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: AppTypography.title.copyWith(color: color)),
        Text(label, style: AppTypography.bodySmall),
      ],
    );
  }

  Widget _buildRankingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🏆ลำดับคะแนนวันนี้', style: AppTypography.heading3),
          Text(
            'ยินดีกับ 3 ลำดับแรกนะคะ ส่วนลำดับอื่นๆไม่ต้องเสียใจ ไว้เก็บคะแนนใหม่เวรถัดไปกันนะ😆🎖️',
            style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 12),
          _buildRankRow('🥇', 'นี่ฉันเอง', '723', true),
          _buildRankRow('🥈', 'นางสาว B', '711', false),
          _buildRankRow('🥉', 'นาย A', '649', false),
          _buildRankRow('4', 'นาย C', '543', false),
          _buildRankRow('5', 'นาย D', '450', false),
          _buildRankRow('6', 'นาย E', '389', false),
        ],
      ),
    );
  }

  Widget _buildRankRow(String rank, String name, String score, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFFFFFCD) : AppColors.surface,
        border: isMe ? Border.all(color: Colors.amber.shade100) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30, 
            child: Text(rank, style: AppTypography.title),
          ),
          const SizedBox(width: 8),
          Container(
            width: 35, height: 35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.alternate,
              border: Border.all(color: AppColors.primary),
            ),
             child: const Icon(Iconsax.user, size: 20, color: AppColors.secondaryText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: AppTypography.body.copyWith(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
          ),
          Text(score, style: AppTypography.title.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildSurveySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, const Color(0xFFF1F4F8).withValues(alpha: 0.5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surface),
      ),
      child: Column(
        children: [
          Text('🩷วันนี้เราทำงานมีความสุขแค่ไหน?🩷', style: AppTypography.title),
          const SizedBox(height: 8),
          _SimpleRatingBar(
            value: _shiftScore,
            icon: Iconsax.heart5,
            color: AppColors.tertiary,
            onChanged: (v) => setState(() => _shiftScore = v),
          ),
          const SizedBox(height: 16),
          Text('⭐ให้คะแนนตัวเราในวันนี้⭐', style: AppTypography.title),
          const SizedBox(height: 8),
          _SimpleRatingBar(
            value: _selfScore,
            icon: Iconsax.star1,
            color: AppColors.primary,
            onChanged: (v) => setState(() => _selfScore = v),
          ),
          const SizedBox(height: 16),
          Text(
            'ในเวรนี้ มีปัญหาหน้างาน/คนไข้ หรืออย่างอื่นบ้างมั้ย?',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _shiftSurveyController,
            decoration: InputDecoration(
              labelText: 'เขียนอะไรสักหน่อยนะ...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: AppColors.surface,
            ),
            minLines: 3,
            maxLines: 5,
            onChanged: (v) => setState((){}), 
          ),
          const SizedBox(height: 16),
          Text(
            'วันนี้ APP IRENE+ มีปัญหา (เช่น ค้าง, เด้ง) ไหม ?',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bugSurveyController,
            decoration: InputDecoration(
              labelText: 'มี/ไม่มี หน้าไหน ยังไง บอกมานะ!',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: AppColors.surface,
            ),
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRemainingTasksList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Icon(Iconsax.warning_2, color: Colors.redAccent),
               const SizedBox(width: 8),
               Text('งานที่ยังไม่เสร็จ ($_remainingTasks)', style: AppTypography.title.copyWith(color: Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _remainingTasksList.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final task = _remainingTasksList[index];
              return ListTile(
                title: Text(task['task_title'] ?? '-', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text('${task['resident_name'] ?? '-'} • ${task['timeBlock'] ?? '-'}', style: AppTypography.caption),
                trailing: const Icon(Iconsax.arrow_right_3, size: 16),
                dense: true,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOffDutyButton() {
    final isDisabled = _remainingTasks > 0 || _shiftSurveyController.text.trim().isEmpty || _isClockingOut;
    
    return PrimaryButton(
      text: 'ลงเวร (เหลืออีก $_remainingTasks)',
      onPressed: isDisabled ? null : _handleClockOut,
      isLoading: _isClockingOut,
      icon: Iconsax.logout,
    );
  }
}

class _GradientText extends StatelessWidget {
  final String text;
  final Gradient gradient;
  final TextStyle style;

  const _GradientText(this.text, {required this.gradient, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(Offset.zero & bounds.size),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

class _SimpleRatingBar extends StatelessWidget {
  final int value;
  final IconData icon;
  final Color color;
  final ValueChanged<int> onChanged;

  const _SimpleRatingBar({
    required this.value,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final i = index + 1;
        return IconButton(
          icon: Icon(
            icon,
            color: i <= value ? color : AppColors.alternate,
            size: 32,
          ),
          onPressed: () => onChanged(i),
        );
      }),
    );
  }
}
