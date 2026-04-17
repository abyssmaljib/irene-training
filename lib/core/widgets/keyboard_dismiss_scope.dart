import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Widget สำหรับ wrap body เพื่อจัดการ keyboard ให้ UX ดีขึ้น
///
/// **ทำ 2 อย่าง:**
/// 1. **Tap outside to dismiss** — แตะพื้นที่ว่างนอก TextField → keyboard ปิด
/// 2. **Done toolbar** — แสดงแถบ "ตกลง" เหนือ keyboard เมื่อ keyboard เปิด
///    (แก้ปัญหา iOS numeric keyboard ไม่มีปุ่ม Done)
///
/// **ใช้ Overlay (global)** แทนการใส่ Stack ใน body เพราะ:
/// - Scaffold ปรับ MediaQuery ของ body → viewInsets.bottom = 0 ภายใน body
///   ทำให้ตรวจ keyboard visibility ไม่ได้ถ้าอยู่ใน Stack ของ body
/// - Overlay อยู่ที่ root (เหนือ Navigator/Scaffold) จึงเห็น viewInsets จริง
/// - Done bar ลอยเหนือ keyboard ตรงๆ ไม่ถูก bottomNav บัง ไม่ถูก keyboard บัง
///
/// **Singleton guard:** ใช้ static `_activeOwner` ป้องกันหลาย KDS insert Done bar
/// ซ้อนกัน เช่นในกรณี nested ไม่ตั้งใจ หรือ previous screen's KDS ยังไม่ dispose
class KeyboardDismissScope extends StatefulWidget {
  /// เนื้อหาที่จะ wrap
  final Widget child;

  /// แสดงแถบ "ตกลง" เหนือ keyboard หรือไม่ (default: true)
  /// ปิดได้ถ้าหน้านั้นไม่ต้องการ (เช่น BottomSheet ที่มีปุ่ม Save visible แล้ว)
  final bool showDoneBar;

  const KeyboardDismissScope({
    super.key,
    required this.child,
    this.showDoneBar = true,
  });

  @override
  State<KeyboardDismissScope> createState() => _KeyboardDismissScopeState();
}

class _KeyboardDismissScopeState extends State<KeyboardDismissScope>
    with WidgetsBindingObserver {
  /// OverlayEntry ของ instance นี้ — เก็บไว้เพื่อ remove เวลา dispose
  OverlayEntry? _doneBarEntry;

  /// flag ป้องกัน initial sync รันซ้ำ
  /// didChangeDependencies fires หลาย event (mount + inherited widgets change)
  /// เราอยาก sync แค่ครั้ง mount เท่านั้น ที่เหลือปล่อยให้ didChangeMetrics จัดการ
  /// **สำคัญ:** ถ้าไม่มี flag นี้ + ถ้า _syncDoneBar เผลอ subscribe inherited widget
  /// ที่เปลี่ยนบ่อย (เช่น MediaQuery) → postFrameCallback จะ fire ทุกเฟรม animation
  /// → Done bar lag 1 frame กระตุกกลับมา
  bool _didInitialSync = false;

  // ============================================================
  // Singleton guards — shared across all KDS instances in the app
  // ============================================================

  /// KDS instance ที่เป็นเจ้าของ Done bar ปัจจุบัน (only 1 Done bar at a time globally)
  /// ถ้า null = ไม่มี Done bar อยู่
  static _KeyboardDismissScopeState? _activeOwner;

  @override
  void initState() {
    super.initState();
    // subscribe เพื่อรับ didChangeMetrics callback ตอน keyboard เปิด/ปิด
    WidgetsBinding.instance.addObserver(this);
  }

  /// Fix: sync Done bar หลัง dependencies (รวม Overlay ancestor) พร้อมใช้งาน
  /// รองรับกรณี widget mount ขณะ keyboard เปิดอยู่แล้ว (เช่น navigate ทับ keyboard)
  /// ซึ่ง didChangeMetrics จะไม่ fire เพราะ metrics ไม่เปลี่ยน
  ///
  /// ใช้ flag ให้รันเฉพาะครั้ง mount แรก เพื่อป้องกัน postFrameCallback
  /// รันหลายครั้งตอน keyboard animate (ทำให้กระตุก)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialSync) return;
    _didInitialSync = true;
    // ใช้ post-frame เพราะ Overlay อาจยังไม่พร้อม insert ตอน mount แรก
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncDoneBar();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeDoneBar();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KeyboardDismissScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ถ้า showDoneBar prop เปลี่ยน → sync Overlay
    if (widget.showDoneBar != oldWidget.showDoneBar) {
      _syncDoneBar();
    }
  }

  /// Callback จาก Flutter เมื่อ window metrics เปลี่ยน (เช่น keyboard เปิด/ปิด)
  /// **ห้ามใช้ addPostFrameCallback** — จะทำให้ Done bar ตามหลัง keyboard 1-2 เฟรม
  /// เห็นเป็น "ช่องว่าง" ระหว่าง Done bar กับ keyboard ตอน animate
  /// sync ทันที แล้วให้ MediaQuery subscription ใน OverlayEntry builder
  /// จัดการ reposition ทุกเฟรมต่อไปเอง
  @override
  void didChangeMetrics() {
    if (!mounted) return;
    _syncDoneBar();
  }

  /// Sync state ของ Done bar ให้ตรงกับ keyboard visibility
  void _syncDoneBar() {
    // ถ้า widget ปิด showDoneBar → ไม่ต้องแสดง
    if (!widget.showDoneBar) {
      _removeDoneBar();
      return;
    }

    // Guard: ถ้า route ของ KDS นี้ไม่ใช่ current route (เช่นมี dialog/sheet ทับ)
    // → ไม่ต้อง insert Done bar ป้องกันซ้อน 2 ตัวจากหลายหน้าที่ active พร้อมกัน
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) {
      _removeDoneBar();
      return;
    }

    // อ่าน viewInsets จาก platformDispatcher (ค่า raw ไม่ถูก Scaffold ปรับ)
    final view = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
        ? WidgetsBinding.instance.platformDispatcher.views.first
        : null;
    if (view == null) return;

    final keyboardVisible = view.viewInsets.bottom > 0;

    if (keyboardVisible) {
      if (_doneBarEntry == null) {
        _insertDoneBar();
      } else {
        // keyboard เปิดอยู่แล้ว แต่สูงอาจเปลี่ยน (เช่น switch keyboard) → refresh position
        _doneBarEntry!.markNeedsBuild();
      }
    } else {
      _removeDoneBar();
    }
  }

  /// Insert Done bar เข้า root Overlay (เหนือ Scaffold + Navigator)
  /// Singleton guard: ถ้ามี KDS อื่น own Done bar อยู่แล้ว → skip
  /// ถ้า owner อยู่แต่ยังไม่ disposed → ให้ owner เป็นคน show
  void _insertDoneBar() {
    // Singleton guard: มี instance อื่น own อยู่แล้ว → ไม่ insert ซ้ำ
    if (_activeOwner != null && _activeOwner != this) {
      // ถ้า owner เดิม route ไม่ใช่ current แล้ว (เช่นมี screen ใหม่ทับ)
      // → steal ownership
      final ownerCurrent =
          _activeOwner!.mounted && (ModalRoute.of(_activeOwner!.context)?.isCurrent ?? false);
      if (ownerCurrent) {
        // Owner ยัง active อยู่ — เรารออีกสักพัก (skip this insert)
        return;
      }
      // Owner ไม่ active แล้ว — force remove และ take over
      _activeOwner!._removeDoneBar();
    }

    // rootOverlay: true → ใช้ Overlay ที่อยู่นอก Navigator ทุกชั้น
    // ป้องกัน Done bar หายเมื่อเปิด modal route/dialog
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _doneBarEntry = OverlayEntry(
      builder: (ctx) {
        // MediaQuery ที่ overlay context = root MediaQuery → viewInsets ถูกต้อง
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return Positioned(
          left: 0,
          right: 0,
          // bottom = keyboard height → Done bar ลอยเหนือ keyboard พอดี
          bottom: viewInsets.bottom,
          child: const _KeyboardDoneBar(),
        );
      },
    );
    overlay.insert(_doneBarEntry!);
    _activeOwner = this;
  }

  void _removeDoneBar() {
    _doneBarEntry?.remove();
    _doneBarEntry = null;
    // clear owner ก็ต่อเมื่อเราเป็นเจ้าของ
    if (_activeOwner == this) {
      _activeOwner = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // translucent = กด TextField/button ได้ปกติ (child handle ก่อน)
      // แต่ถ้ากดพื้นที่ว่างที่ไม่มีใคร handle → GestureDetector รับ → unfocus
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: widget.child,
    );
  }
}

/// แถบปุ่ม "ตกลง" เหนือ keyboard — เด่นชัดสีขาว + ปุ่ม primary tint
class _KeyboardDoneBar extends StatelessWidget {
  const _KeyboardDoneBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      // elevation สูงเพื่อให้เห็น shadow แยกจาก keyboard
      elevation: 8,
      // พื้นขาวตัดกับ keyboard สีดำ/เทา — เด่นชัดทั้ง iOS และ Android
      color: AppColors.surface,
      child: Container(
        decoration: const BoxDecoration(
          // ขอบบนเพื่อแบ่งจาก content ด้านบน
          border: Border(
            top: BorderSide(
              color: AppColors.inputBorder,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          // ปุ่มอยู่ขวา — ตาม iOS convention
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                // พื้นเทา primary อ่อน → ปุ่มเด่นจากพื้นหลังขาว
                backgroundColor: AppColors.accent1,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                // ขนาด touch target อย่างน้อย 44x44 ตาม WCAG a11y
                minimumSize: const Size(80, 44),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedKeyboard,
                color: AppColors.primary,
                size: 18,
              ),
              label: Text(
                'ตกลง',
                style: AppTypography.button.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
