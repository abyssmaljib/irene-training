// หน้า Chat กับ AI Coach สำหรับการถอดบทเรียน (5 Whys)
// แสดง chat messages, pillar progress, และ input bar

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/coin_reward_overlay.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../models/incident.dart';
import '../models/reflection_pillars.dart';
import '../providers/chat_provider.dart';
import '../providers/incident_provider.dart';
import '../services/incident_service.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/pillar_progress_indicator.dart';
import '../widgets/root_cause_depth_indicator.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/core_value_picker.dart';
import '../widgets/reflection_summary_popup.dart';

/// หน้า Chat กับ AI Coach
class IncidentChatScreen extends ConsumerStatefulWidget {
  final Incident incident;

  const IncidentChatScreen({
    super.key,
    required this.incident,
  });

  @override
  ConsumerState<IncidentChatScreen> createState() => _IncidentChatScreenState();
}

class _IncidentChatScreenState extends ConsumerState<IncidentChatScreen> {
  final _scrollController = ScrollController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // โหลด chat history เมื่อเปิดหน้า
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // โหลด chat history จาก incident
    await ref.read(chatProvider.notifier).loadFromIncident(widget.incident);

    // Scroll to bottom หลังโหลดเสร็จ
    _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Reset chat state เมื่อออกจากหน้า
    // ใช้ try-catch เพราะ ref อาจใช้ไม่ได้ใน dispose() (widget disposed ก่อน)
    try {
      ref.read(chatProvider.notifier).reset();
    } catch (_) {
      // ignore — reset ไม่สำคัญแล้วเพราะ wasAlreadyCompleteOnLoad
      // จะ detect ให้ถูกต้องตอน loadFromIncident() ครั้งถัดไป
    }
    super.dispose();
  }

  void _scrollToBottom() {
    // Delay เล็กน้อยเพื่อให้ UI render ข้อความใหม่เสร็จก่อน
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(String message) {
    ref.read(chatProvider.notifier).sendMessage(message);
    _scrollToBottom();
  }

  /// Handle เมื่อ user เลือก Core Values เสร็จแล้ว
  /// บันทึกลง DB โดยตรง แล้วส่งข้อความให้ AI
  void _handleCoreValuesSelected(List<String> selectedValues) {
    // ใช้ method ใหม่ที่บันทึก Core Values ลง DB โดยตรง
    // ไม่พึ่งพา AI parse เพราะอาจพลาดได้
    ref.read(chatProvider.notifier).sendCoreValuesSelection(selectedValues);
    _scrollToBottom();
  }

  /// แสดง dialog ยืนยันการ reset บทสนทนา
  Future<void> _handleResetConversation() async {
    // ใช้ ConfirmDialog reusable widget
    final confirmed = await ConfirmDialog.show(
      context,
      type: ConfirmDialogType.warning,
      title: 'เริ่มบทสนทนาใหม่ทั้งหมด',
      message: 'คุณต้องการเริ่มบทสนทนาใหม่ทั้งหมดหรือไม่?\nข้อความทั้งหมดจะถูกลบและเริ่มถอดบทเรียนใหม่ตั้งแต่ต้น',
      icon: HugeIcons.strokeRoundedRefresh,
      confirmText: 'เริ่มใหม่ทั้งหมด',
    );

    if (!confirmed) return;

    // Reset บทสนทนา
    await ref.read(chatProvider.notifier).resetConversation();
  }

  Future<void> _handleGenerateSummary() async {
    // ใช้ ConfirmDialog reusable widget
    final confirmed = await ConfirmDialog.show(
      context,
      type: ConfirmDialogType.custom,
      title: 'สรุปการถอดบทเรียน',
      message: 'คุณต้องการสรุปผลการถอดบทเรียนหรือไม่?\nAI จะสรุป 4 ประเด็นสำคัญจากบทสนทนา และบันทึกลงระบบ',
      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
      iconColor: AppColors.primary,
      iconBackgroundColor: AppColors.accent1,
      confirmText: 'สรุป',
    );

    if (!confirmed) return;

    // Generate summary
    debugPrint('🖥️ _handleGenerateSummary: calling generateSummary...');
    final summary = await ref.read(chatProvider.notifier).generateSummary();
    debugPrint('🖥️ _handleGenerateSummary: summary=${summary != null ? "OK" : "null"}, mounted=$mounted');

    if (summary != null && mounted) {
      // แสดง success dialog พร้อมสรุป
      await showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: AppColors.primary,
                size: 24,
              ),
              AppSpacing.horizontalGapSm,
              const Text('สรุปเสร็จสิ้น'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSummarySection('ความสำคัญ', summary.whyItMatters),
                AppSpacing.verticalGapMd,
                _buildSummarySection('สาเหตุที่แท้จริง', summary.rootCause),
                AppSpacing.verticalGapMd,
                _buildSummarySection('Core Values ที่เกี่ยวข้อง',
                    summary.violatedCoreValues.join(', ')),
                AppSpacing.verticalGapMd,
                _buildSummarySection('แนวทางป้องกัน', summary.preventionPlan),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('เสร็จสิ้น'),
            ),
          ],
        ),
      );

      // หลัง dialog ปิด → แสดง bonus dialog ก่อนกลับหน้า list
      if (mounted) {
        final bonus = ref.read(chatProvider.notifier).lastBonusAwarded;
        debugPrint('🖥️ _handleGenerateSummary: lastBonusAwarded=$bonus, mounted=$mounted');
        if (bonus > 0) {
          // เคลียร์ bonus ทันทีก่อนแสดง coin overlay (ป้องกันแสดงซ้ำ)
          ref.read(chatProvider.notifier).clearBonusAwarded();
          debugPrint('🖥️ _handleGenerateSummary: showing coin overlay...');
          await _showBonusPointsDialog(bonus);
          debugPrint('🖥️ _handleGenerateSummary: coin overlay closed');
        } else {
          debugPrint('🖥️ _handleGenerateSummary: bonus <= 0, SKIPPING overlay');
        }
      }
      if (mounted) {
        debugPrint('🖥️ _handleGenerateSummary: popping back to list');
        Navigator.pop(context); // กลับไปหน้า list
      }
    }
  }

  /// แสดง coin animation แจ้งคะแนนที่ได้คืนหลังถอดบทเรียนเสร็จ
  /// [bonusPerPerson] คะแนนที่ได้คืนต่อคน (เช่น 50, 150, 250)
  Future<void> _showBonusPointsDialog(int bonusPerPerson) async {
    await CoinRewardOverlay.show(
      context,
      points: bonusPerPerson,
      title: 'ได้รับคะแนนคืน!',
      pointsLabel: '+$bonusPerPerson คะแนน',
      subtitle: 'ถอดบทเรียนเสร็จ ได้คืน 50%',
    );
  }

  Widget _buildSummarySection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        AppSpacing.verticalGapXs,
        Text(
          content.isNotEmpty ? content : '-',
          style: AppTypography.body,
        ),
      ],
    );
  }

  /// แสดง coin overlay + popup สรุปเมื่อกดปุ่ม "การถอดบทเรียนเสร็จสิ้นแล้ว"
  /// ครั้งแรก (เพิ่ง complete): coin overlay → summary popup → navigate back
  /// ครั้งต่อไป (เปิดดูทีหลัง): summary popup → navigate back (ไม่มี coin)
  Future<void> _showCompletedSummaryAndGoBack() async {
    // 1) แสดง coin overlay เฉพาะ "เพิ่ง complete ใน session นี้"
    // ตรวจจาก wasAlreadyCompleteOnLoad:
    //   false = เพิ่ง complete ใน session นี้ → แสดง coin
    //   true  = เปิดดู incident ที่เสร็จแล้ว (ครั้งที่ 2+) → ข้าม coin
    final notifier = ref.read(chatProvider.notifier);
    final justCompletedNow = !notifier.wasAlreadyCompleteOnLoad;
    final bonus = notifier.lastBonusAwarded;

    if (justCompletedNow && bonus > 0) {
      // เคลียร์ bonus ทันทีก่อนแสดง เพื่อป้องกันกด banner ซ้ำแล้วเห็น coin อีก
      notifier.clearBonusAwarded();
      await _showBonusPointsDialog(bonus);
      if (!mounted) return;
    }

    // 2) ดึงข้อมูลล่าสุดจาก DB (ไม่ใช้ widget.incident เพราะเป็นข้อมูลเก่า)
    final incidentService = IncidentService.instance;
    final latestIncident = await incidentService.getIncidentById(widget.incident.id);

    if (!mounted) return;

    final incident = latestIncident ?? widget.incident;

    final summary = ReflectionSummary(
      whyItMatters: incident.whyItMatters ?? '',
      rootCause: incident.rootCause ?? '',
      coreValueAnalysis: incident.coreValueAnalysis ?? '',
      violatedCoreValues: incident.violatedCoreValues,
      preventionPlan: incident.preventionPlan ?? '',
    );

    // 3) แสดง summary popup
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ReflectionSummaryPopup(
        summary: summary,
        isViewMode: true,
        onEdit: () => Navigator.of(dialogContext).pop(),
        onConfirm: () {
          Navigator.of(dialogContext).pop();
          ref.invalidate(myIncidentsProvider);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final canGenerateSummary = ref.watch(canGenerateSummaryProvider);

    // Scroll to bottom เมื่อมีข้อความใหม่ หรือเมื่อ AI ตอบเสร็จ
    ref.listen<ChatState>(chatProvider, (previous, next) {
      // Scroll เมื่อจำนวน messages เปลี่ยน
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
      // Scroll เมื่อ AI ตอบเสร็จ (isSending: true -> false)
      if (previous?.isSending == true && next.isSending == false) {
        _scrollToBottom();
      }

      // ไม่ auto-trigger ทั้ง coin overlay และ summary popup
      // user กด banner "การถอดบทเรียนเสร็จสิ้นแล้ว" → _showCompletedSummaryAndGoBack()
      // จัดการทั้ง coin (ครั้งแรก) + summary popup
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: IreneSecondaryAppBar(
        title: widget.incident.title ?? 'ถอดบทเรียน',
        actions: [
          // ปุ่ม Reset บทสนทนา (ไม่แสดงเมื่อสรุปเสร็จแล้ว)
          if (!chatState.isComplete)
            TextButton.icon(
              onPressed: chatState.isSending ? null : _handleResetConversation,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                color: chatState.isSending
                    ? AppColors.secondaryText
                    : AppColors.primaryText,
                size: 18,
              ),
              label: Text(
                'เริ่มบทสนทนาอีกครั้ง',
                style: AppTypography.bodySmall.copyWith(
                  color: chatState.isSending
                      ? AppColors.secondaryText
                      : AppColors.primaryText,
                ),
              ),
            ),
          // ปุ่มสรุป (แสดงเมื่อครบ 4 pillars และยังไม่สรุป)
          if (canGenerateSummary)
            TextButton.icon(
              onPressed:
                  chatState.isGeneratingSummary ? null : _handleGenerateSummary,
              icon: chatState.isGeneratingSummary
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                      color: AppColors.primary,
                      size: 18,
                    ),
              label: Text(
                chatState.isGeneratingSummary ? 'กำลังสรุป...' : 'สรุป',
                style: AppTypography.body.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Pillar progress indicator พร้อม highlight pillar ที่กำลังถามอยู่
          PillarProgressIndicator(
            progress: chatState.pillarsProgress,
            currentPillar: chatState.currentPillar,
          ),

          // แสดง Root Cause Depth Indicator เมื่อกำลังวิเคราะห์สาเหตุ (Pillar 2)
          // หรือเมื่อมี depth data อยู่แล้ว
          if (chatState.rootCauseDepth != null)
            RootCauseDepthIndicator(
              currentDepth: chatState.rootCauseDepth,
              exploredCategories: chatState.exploredCategories,
              analysisQuality: chatState.analysisQuality,
            ),

          // Chat messages พร้อม Core Value picker (ถ้ามี)
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildInitialLoading()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    // เพิ่ม 1 item ถ้าต้องแสดง Core Value picker
                    itemCount: chatState.messages.length +
                        (chatState.showCoreValuePicker &&
                                chatState.availableCoreValues.isNotEmpty
                            ? 1
                            : 0),
                    itemBuilder: (context, index) {
                      // ถ้าเป็น item สุดท้ายและต้องแสดง picker
                      if (index == chatState.messages.length &&
                          chatState.showCoreValuePicker &&
                          chatState.availableCoreValues.isNotEmpty) {
                        // แสดง Core Value picker ใน chat
                        return _buildInlineCoreValuePicker(chatState);
                      }
                      return ChatMessageBubble(
                        message: chatState.messages[index],
                      );
                    },
                  ),
          ),

          // Error message พร้อมปุ่ม retry (ถ้ามี failed message)
          if (chatState.error != null)
            Container(
              padding: AppSpacing.paddingMd,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedAlert02,
                        color: AppColors.error,
                        size: 18,
                      ),
                      AppSpacing.horizontalGapSm,
                      Expanded(
                        child: Text(
                          chatState.error!,
                          style: AppTypography.body.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // แสดงปุ่ม retry ถ้ามี failed message
                  if (chatState.failedMessage != null) ...[
                    AppSpacing.verticalGapSm,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // ปุ่มปิด
                        TextButton(
                          onPressed: () =>
                              ref.read(chatProvider.notifier).clearError(),
                          child: Text(
                            'ปิด',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                        AppSpacing.horizontalGapSm,
                        // ปุ่มส่งอีกครั้ง
                        ElevatedButton.icon(
                          onPressed: chatState.isSending
                              ? null
                              : () {
                                  ref
                                      .read(chatProvider.notifier)
                                      .retryFailedMessage();
                                  _scrollToBottom();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedRefresh,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: const Text('ส่งอีกครั้ง'),
                        ),
                      ],
                    ),
                  ] else ...[
                    // ถ้าไม่มี failed message แสดงแค่ปุ่มปิด
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            ref.read(chatProvider.notifier).clearError(),
                        child: Text(
                          'ปิด',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Completed button (ถ้าสรุปเสร็จแล้ว) - กดเพื่อดูสรุปและกลับหน้า list
          if (chatState.isComplete)
            Container(
              padding: AppSpacing.paddingMd,
              color: AppColors.tagPassedBg,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showCompletedSummaryAndGoBack,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                          color: AppColors.tagPassedText,
                          size: 20,
                        ),
                        AppSpacing.horizontalGapSm,
                        Expanded(
                          child: Text(
                            'การถอดบทเรียนเสร็จสิ้นแล้ว',
                            style: AppTypography.body.copyWith(
                              color: AppColors.tagPassedText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // ลูกศรบอกว่ากดได้
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowRight01,
                          color: AppColors.tagPassedText,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // DEV MODE: ปุ่ม auto-generate คำตอบสำหรับทดสอบ
          // แสดงเฉพาะใน debug mode และยังไม่เสร็จ
          if (kDebugMode &&
              !chatState.isComplete &&
              !(chatState.showCoreValuePicker &&
                  chatState.availableCoreValues.isNotEmpty))
            _buildDevAutoResponseButton(chatState),

          // Chat input bar (ซ่อนถ้าสรุปเสร็จแล้ว หรือกำลังแสดง Core Value picker)
          if (!chatState.isComplete &&
              !(chatState.showCoreValuePicker &&
                  chatState.availableCoreValues.isNotEmpty))
            ChatInputBar(
              onSend: _handleSend,
              enabled: !chatState.isSending,
              hintText: chatState.isSending
                  ? 'กำลังส่ง...'
                  : 'พิมพ์ข้อความตอบ AI Coach...',
              // เมื่อ autofocus เกิดขึ้น (keyboard โผล่) ให้ scroll ลงล่างสุด
              // เพื่อให้ user เห็นข้อความล่าสุดเสมอ
              onAutofocused: _scrollToBottom,
            ),
        ],
      ),
    );
  }

  /// สร้าง Core Value picker แบบ inline ใน chat
  /// แสดงเป็น card ใน chat list แทนที่จะเป็น fixed widget ด้านล่าง
  Widget _buildInlineCoreValuePicker(ChatState chatState) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: CoreValuePicker(
        coreValues: chatState.availableCoreValues,
        isLoading: chatState.isSending,
        onConfirm: _handleCoreValuesSelected,
      ),
    );
  }

  /// DEV MODE: ปุ่ม auto-generate คำตอบตาม pillar ปัจจุบัน
  /// แสดงเฉพาะใน debug mode สำหรับทดสอบ flow
  Widget _buildDevAutoResponseButton(ChatState chatState) {
    // คำตอบ sample สำหรับแต่ละ pillar
    final sampleResponses = {
      1: 'เหตุการณ์นี้สำคัญเพราะอาจส่งผลต่อความปลอดภัยของผู้สูงอายุ และทำให้ครอบครัวไม่ไว้วางใจในการดูแล',
      2: 'สาเหตุที่แท้จริงคือ การขาดการสื่อสารระหว่างทีม และไม่มีระบบตรวจสอบซ้ำก่อนให้ยา',
      3: 'ฉันคิดว่าเกี่ยวข้องกับ: Speak Up (กล้าพูด กล้าสื่อสาร), System Focus (ใช้ระบบแทนความจำ เพื่อใช้ศักยภาพทำเรื่องสำคัญ)',
      4: 'แนวทางป้องกัน: 1) ใช้ระบบ double-check ก่อนให้ยา 2) สร้างช่องทางสื่อสารที่ชัดเจนในทีม 3) ทบทวน protocol ทุกเดือน',
    };

    // หาคำตอบที่เหมาะสมตาม pillar ปัจจุบัน
    final currentPillar = chatState.currentPillar ?? 1;
    final response = sampleResponses[currentPillar] ?? sampleResponses[1]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: chatState.isSending
                  ? null
                  : () {
                      _handleSend(response);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6), // Purple
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedMagicWand01,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                'DEV: Auto Response (Pillar $currentPillar)',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Loading state ตอนเริ่มต้น
  Widget _buildInitialLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          AppSpacing.verticalGapMd,
          Text(
            'กำลังโหลด...',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
