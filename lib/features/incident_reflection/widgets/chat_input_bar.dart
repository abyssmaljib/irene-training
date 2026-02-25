// Widget สำหรับ input bar ในหน้า chat
// มีช่องพิมพ์ข้อความและปุ่มส่ง

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';

/// Input bar สำหรับหน้า chat
class ChatInputBar extends StatefulWidget {
  final Function(String) onSend;
  final bool enabled;
  final String hintText;

  /// Callback เมื่อ autofocus เกิดขึ้น (enabled เปลี่ยนจาก false -> true)
  /// ใช้เพื่อให้ parent scroll ลงมาล่างสุดหลังจาก keyboard โผล่ขึ้นมา
  final VoidCallback? onAutofocused;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.hintText = 'พิมพ์ข้อความ...',
    this.onAutofocused,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Autofocus เมื่อ enabled เปลี่ยนจาก false เป็น true (AI ตอบกลับมาแล้ว)
    if (!oldWidget.enabled && widget.enabled) {
      // Delay เล็กน้อยเพื่อให้ UI update ก่อน
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _focusNode.requestFocus();
          // Delay อีกนิดให้ keyboard โผล่ขึ้นมาก่อน แล้วค่อยเรียก callback
          // เพื่อให้ parent scroll ลงล่างสุดหลัง keyboard พร้อมแล้ว
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              widget.onAutofocused?.call();
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && widget.enabled) {
      widget.onSend(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && widget.enabled;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        // เพิ่ม padding ด้านล่างสำหรับ safe area
        // ใช้ viewPaddingOf แทน .of().viewPadding เพื่อลดการ rebuild ตอน keyboard animation
        bottom: MediaQuery.viewPaddingOf(context).bottom + AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.alternate,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 44,
                maxHeight: 120,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: AppRadius.mediumRadius,
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                style: AppTypography.body,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.secondaryText.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),

          AppSpacing.horizontalGapSm,

          // Send button
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(bottom: 0),
            child: Material(
              color: canSend ? AppColors.primary : AppColors.alternate,
              borderRadius: AppRadius.mediumRadius,
              child: InkWell(
                onTap: canSend ? _handleSend : null,
                borderRadius: AppRadius.mediumRadius,
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedSent,
                    size: 20,
                    color: canSend ? Colors.white : AppColors.secondaryText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
