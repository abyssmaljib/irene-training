// Bottom sheet ที่แสดงขณะอัดเสียง + ถอดข้อความ
//
// 2 state:
//   - recording: pulsing mic + elapsed time + ปุ่มยกเลิก/หยุด
//   - processing: spinner + "กำลังถอดเสียง..."
//
// Flow:
//   1. MicButton เรียก show() → sheet เปิด → เริ่มอัดอัตโนมัติ
//   2. user กดหยุด → stop + ส่งไป backend → insert ข้อความเข้า controller → pop
//   3. user กดยกเลิก (หรือ back) → cancel + pop (ไม่ส่ง backend)
//   4. auto-stop ที่ 120s

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:record/record.dart';

import '../services/stt_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_snackbar.dart';

enum _SheetState { recording, processing }

/// แสดง recording sheet — return transcript ที่ได้ (หรือ null ถ้า cancel/error)
/// Caller รับผิดชอบการ insert เข้า controller เอง (ผ่าน onTranscribed ใน sheet)
Future<void> showSttRecordingSheet({
  required BuildContext context,
  required TextEditingController controller,
  required SttContext sttContext,
  int? nursinghomeId,
  int? residentId,
  VoidCallback? onTranscribed,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false, // swipe down ไม่ปิด (ต้องกดปุ่มยกเลิก)
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SttRecordingSheet(
      controller: controller,
      sttContext: sttContext,
      nursinghomeId: nursinghomeId,
      residentId: residentId,
      onTranscribed: onTranscribed,
    ),
  );
}

class SttRecordingSheet extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final SttContext sttContext;
  final int? nursinghomeId;
  final int? residentId;
  final VoidCallback? onTranscribed;

  const SttRecordingSheet({
    super.key,
    required this.controller,
    required this.sttContext,
    this.nursinghomeId,
    this.residentId,
    this.onTranscribed,
  });

  @override
  ConsumerState<SttRecordingSheet> createState() => _SttRecordingSheetState();
}

class _SttRecordingSheetState extends ConsumerState<SttRecordingSheet>
    with SingleTickerProviderStateMixin {
  _SheetState _state = _SheetState.recording;
  String? _recordingPath;
  DateTime? _startedAt;
  Timer? _autoStopTimer;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  StreamSubscription<Amplitude>? _ampSub;
  double _currentLevel = 0; // 0-1 normalized จาก dBFS

  late final AnimationController _pulseController = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    // เริ่มอัดทันทีหลัง frame แรก render (กัน issue กับ showModalBottomSheet context)
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _elapsedTimer?.cancel();
    _ampSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================
  // Recording lifecycle
  // ============================================================

  Future<void> _startRecording() async {
    final stt = ref.read(sttServiceProvider);
    try {
      final path = await stt.startRecording();
      if (!mounted) {
        await stt.cancelRecording();
        return;
      }

      _recordingPath = path;
      _startedAt = DateTime.now();
      HapticFeedback.mediumImpact();

      // Auto-stop 120s
      _autoStopTimer = Timer(SttService.maxDuration, _stopAndTranscribe);

      // Elapsed timer 200ms
      _elapsedTimer =
          Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted && _startedAt != null) {
          setState(() => _elapsed = DateTime.now().difference(_startedAt!));
        }
      });

      // Amplitude stream → แปลง dBFS (-60 to 0) → 0..1
      _ampSub = stt.amplitudeStream().listen((amp) {
        if (!mounted) return;
        // dBFS = -60 (quiet) ถึง 0 (loud); map เป็น 0..1
        final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        setState(() => _currentLevel = normalized);
      });
    } on SttException catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.error(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.error(context, 'เริ่มอัดไม่ได้: $e');
      }
    }
  }

  Future<void> _stopAndTranscribe() async {
    _autoStopTimer?.cancel();
    _elapsedTimer?.cancel();
    _ampSub?.cancel();
    _pulseController.stop();

    if (_state != _SheetState.recording) return;

    HapticFeedback.lightImpact();
    setState(() => _state = _SheetState.processing);

    final stt = ref.read(sttServiceProvider);
    final duration = _elapsed;
    final path = _recordingPath;

    try {
      await stt.stopRecording();
      if (path == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final result = await stt.transcribe(
        audioPath: path,
        context: widget.sttContext,
        nursinghomeId: (widget.nursinghomeId ?? 0) > 0
            ? widget.nursinghomeId
            : null,
        residentId: (widget.residentId ?? 0) > 0
            ? widget.residentId
            : null,
        actualDuration: duration,
      );

      if (!mounted) return;

      _insertTranscript(result.transcript);
      widget.onTranscribed?.call();
      Navigator.of(context).pop();

      // Warn ถ้า quota ใกล้หมด
      if (result.quotaUsed >= result.quotaLimit * 0.8) {
        AppSnackbar.warning(
          context,
          'ใช้ STT ${result.quotaUsed}/${result.quotaLimit} ครั้งวันนี้',
        );
      }
    } on SttException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      final msg = e.isQuotaExceeded
          ? 'ใช้ STT ครบ 100 ครั้งแล้ววันนี้ ลองใหม่พรุ่งนี้'
          : e.isEmptySpeech
              ? 'ไม่ได้ยินคำพูด ลองพูดใหม่ดังขึ้น'
              : e.isUnauthorized
                  ? 'เซสชั่นหมดอายุ login ใหม่'
                  : 'แปลงเสียงไม่สำเร็จ: ${e.message}';
      AppSnackbar.error(context, msg);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.error(context, 'เกิดข้อผิดพลาด: $e');
    }
  }

  Future<void> _cancel() async {
    _autoStopTimer?.cancel();
    _elapsedTimer?.cancel();
    _ampSub?.cancel();
    _pulseController.stop();
    HapticFeedback.lightImpact();

    final stt = ref.read(sttServiceProvider);
    await stt.cancelRecording();
    if (mounted) Navigator.of(context).pop();
  }

  /// แทรก transcript ที่ตำแหน่ง cursor เดิม (หรือ append ท้ายสุดถ้าไม่มี cursor)
  void _insertTranscript(String transcript) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final insertAt = sel.isValid ? sel.start : text.length;

    final before = text.substring(0, insertAt);
    final after = text.substring(insertAt);
    final needsLeadingSpace = before.isNotEmpty &&
        !before.endsWith(' ') &&
        !before.endsWith('\n');
    final needsTrailingSpace = after.isNotEmpty &&
        !after.startsWith(' ') &&
        !after.startsWith('\n');

    final insertText =
        '${needsLeadingSpace ? ' ' : ''}$transcript${needsTrailingSpace ? ' ' : ''}';

    widget.controller.value = TextEditingValue(
      text: before + insertText + after,
      selection: TextSelection.collapsed(offset: insertAt + insertText.length),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // PopScope — block back button ขณะ recording/processing
    // ต้องกดปุ่มยกเลิกเท่านั้น (ไม่งั้นไฟล์เสียงจะค้าง)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_state == _SheetState.recording) {
          _cancel();
        }
        // processing state: ไม่ให้ cancel (รอให้เสร็จ)
      },
      child: Container(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: switch (_state) {
          _SheetState.recording => _buildRecordingView(),
          _SheetState.processing => _buildProcessingView(),
        },
      ),
    );
  }

  Widget _buildRecordingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing mic icon ใหญ่ตรงกลาง + amplitude ring
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Amplitude ring — ขยายตามเสียงที่เข้ามา
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 100 + (_currentLevel * 40),
                height: 100 + (_currentLevel * 40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.15),
                ),
              ),
              // Pulse ring — animation ต่อเนื่อง
              FadeTransition(
                opacity: Tween<double>(begin: 0.3, end: 0.7)
                    .animate(_pulseController),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.25),
                  ),
                ),
              ),
              // Mic icon ตรงกลาง
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMic01,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg),

        // Elapsed time (ใหญ่ อ่านชัด)
        Text(
          _formatElapsed(_elapsed),
          style: AppTypography.heading2.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        SizedBox(height: AppSpacing.xs),

        Text(
          'กำลังฟัง... พูดได้เลย',
          style: AppTypography.body.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          'สูงสุด ${SttService.maxDuration.inSeconds} วินาที',
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        SizedBox(height: AppSpacing.xl),

        // Buttons row
        Row(
          children: [
            Expanded(
              child: _SheetButton(
                icon: HugeIcons.strokeRoundedCancel01,
                label: 'ยกเลิก',
                color: AppColors.error,
                isOutlined: true,
                onTap: _cancel,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: _SheetButton(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                label: 'หยุดและส่ง',
                color: AppColors.primary,
                isOutlined: false,
                onTap: _stopAndTranscribe,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        Text(
          'กำลังถอดเสียงเป็นข้อความ...',
          style: AppTypography.title.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          'ใช้เวลาประมาณ 3-10 วินาที',
          style: AppTypography.body.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _SheetButton extends StatelessWidget {
  final dynamic icon;
  final String label;
  final Color color;
  final bool isOutlined;
  final VoidCallback onTap;

  const _SheetButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isOutlined,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isOutlined ? Colors.transparent : color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isOutlined ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                color: isOutlined ? color : Colors.white,
                size: 20,
              ),
              SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.body.copyWith(
                  color: isOutlined ? color : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
