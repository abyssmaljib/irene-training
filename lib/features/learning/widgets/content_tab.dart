import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/user_service.dart';
import '../../points/services/points_service.dart';
import '../models/topic_detail.dart';

class ContentTab extends StatefulWidget {
  final TopicDetail topicDetail;
  final VoidCallback onMarkAsRead;

  const ContentTab({
    super.key,
    required this.topicDetail,
    required this.onMarkAsRead,
  });

  @override
  State<ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<ContentTab> {
  bool _isMarking = false;
  double _holdProgress = 0.0;
  bool _isHolding = false;
  static const int _holdDurationMs = 3000; // 3 วินาที

  void _startHold() {
    // ถ้าอ่านแล้วและไม่มี update → ต้องกดค้าง
    final showAsRead = widget.topicDetail.isRead && !widget.topicDetail.hasContentUpdate;
    if (!showAsRead) {
      // ถ้ายังไม่อ่าน → toggle ทันที
      _toggleReadStatus();
      return;
    }

    // เริ่มกดค้าง
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });
    _animateHold();
  }

  void _animateHold() async {
    const int steps = 60; // 60 fps
    const int stepDurationMs = _holdDurationMs ~/ steps;

    for (int i = 0; i <= steps; i++) {
      if (!_isHolding) return;

      await Future.delayed(const Duration(milliseconds: stepDurationMs));

      if (!mounted || !_isHolding) return;

      setState(() {
        _holdProgress = i / steps;
      });

      if (i == steps) {
        // กดค้างครบแล้ว → toggle
        _isHolding = false;
        _toggleReadStatus();
      }
    }
  }

  void _cancelHold() {
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  Future<void> _toggleReadStatus() async {
    if (_isMarking) return;

    setState(() => _isMarking = true);

    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) return;

      // Get active season
      final seasonResponse = await Supabase.instance.client
          .from('training_seasons')
          .select('id')
          .eq('is_active', true)
          .single();

      final seasonId = seasonResponse['id'];

      // ถ้ามี content update หรือยังไม่เคยอ่าน → mark as read
      // ถ้าอ่านแล้วและไม่มี update → unmark
      final shouldMarkAsRead =
          !widget.topicDetail.isRead || widget.topicDetail.hasContentUpdate;

      if (shouldMarkAsRead) {
        // Mark as read and save current content version
        await Supabase.instance.client.from('training_user_progress').upsert({
          'user_id': userId,
          'topic_id': widget.topicDetail.topicId,
          'season_id': seasonId,
          'content_read_at': DateTime.now().toIso8601String(),
          'content_read_count': widget.topicDetail.readCount + 1,
          'content_version_read': widget.topicDetail.contentVersion,
        }, onConflict: 'user_id,topic_id,season_id');

        // บันทึก points สำหรับการอ่าน (ให้เฉพาะครั้งแรกต่อ topic)
        // PointsService มี duplicate check อยู่แล้ว - ถ้าเคยได้ points แล้วจะไม่ให้ซ้ำ
        await PointsService().recordContentRead(
          userId: userId,
          topicId: widget.topicDetail.topicId,
          topicName: widget.topicDetail.topicName,
          seasonId: seasonId as String?,
        );
      } else {
        // Unmark as read - set content_read_at to null
        await Supabase.instance.client.from('training_user_progress').upsert({
          'user_id': userId,
          'topic_id': widget.topicDetail.topicId,
          'season_id': seasonId,
          'content_read_at': null,
        }, onConflict: 'user_id,topic_id,season_id');
      }

      widget.onMarkAsRead();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'เกิดข้อผิดพลาด: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isMarking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.topicDetail.hasContent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedFileEdit,
              size: AppIconSize.display,
              color: AppColors.secondaryText.withValues(alpha: 0.5),
            ),
            AppSpacing.verticalGapMd,
            Text(
              'ยังไม่มีเนื้อหา',
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Reading time info
        if (widget.topicDetail.readingTimeMinutes != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 4,
            ),
            color: AppColors.primaryBackground,
            child: Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: AppIconSize.xl, color: AppColors.secondaryText),
                AppSpacing.horizontalGapSm,
                Text(
                  'ใช้เวลาอ่านประมาณ ${widget.topicDetail.readingTimeMinutes} นาที',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),

        // Markdown content
        Expanded(
          child: Markdown(
            data: widget.topicDetail.contentMarkdown ?? '',
            selectable: true,
            padding: AppSpacing.paddingMd,
            styleSheet: MarkdownStyleSheet(
              h1: AppTypography.heading2.copyWith(color: AppColors.primaryText),
              h2: AppTypography.heading3.copyWith(color: AppColors.primaryText),
              h3: AppTypography.title.copyWith(color: AppColors.primaryText),
              p: AppTypography.body.copyWith(
                fontSize: 15,
                height: 1.6,
                color: AppColors.primaryText,
              ),
              listBullet: AppTypography.body.copyWith(
                fontSize: 15,
                color: AppColors.primaryText,
              ),
              code: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                backgroundColor: AppColors.primaryBackground,
                color: AppColors.primary,
              ),
              codeblockDecoration: BoxDecoration(
                color: AppColors.primaryBackground,
                borderRadius: AppRadius.smallRadius,
              ),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.primary, width: 4),
                ),
                color: AppColors.accent1,
              ),
            ),
          ),
        ),

        // Mark as read button
        // ถ้ามี content update ให้แสดงเหมือนยังไม่อ่าน (ต้องกดอ่านอีกรอบ)
        Builder(
          builder: (context) {
            final showAsRead =
                widget.topicDetail.isRead &&
                !widget.topicDetail.hasContentUpdate;
            return Container(
              width: double.infinity,
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                boxShadow: AppShadows.cardShadow,
              ),
              child: SafeArea(
                child: GestureDetector(
                  onTapDown: (_) => _startHold(),
                  onTapUp: (_) => _cancelHold(),
                  onTapCancel: _cancelHold,
                  child: Container(
                    height: AppSpacing.buttonHeight,
                    decoration: BoxDecoration(
                      color: showAsRead
                          ? AppColors.tagPassedBg
                          : AppColors.primaryBackground,
                      borderRadius: AppRadius.smallRadius,
                      border: Border.all(
                        color: showAsRead
                            ? AppColors.success
                            : AppColors.alternate,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Progress bar สำหรับกดค้าง
                        if (_isHolding)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: AppRadius.smallRadius,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: _holdProgress,
                                  heightFactor: 1.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Content
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isMarking)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                HugeIcon(
                                  icon: showAsRead
                                      ? HugeIcons.strokeRoundedCheckmarkSquare02
                                      : HugeIcons.strokeRoundedCheckmarkSquare02,
                                  size: AppIconSize.xl,
                                  color: _isHolding
                                      ? AppColors.error
                                      : showAsRead
                                          ? AppColors.success
                                          : AppColors.primary,
                                ),
                              AppSpacing.horizontalGapSm,
                              Text(
                                _isHolding
                                    ? 'กดค้างเพื่อยกเลิก...'
                                    : showAsRead
                                        ? 'อ่านแล้ว'
                                        : 'ทำเครื่องหมายว่าอ่านแล้ว',
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: _isHolding
                                      ? AppColors.error
                                      : showAsRead
                                          ? AppColors.success
                                          : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
