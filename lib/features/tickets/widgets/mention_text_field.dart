// MentionTextField — TextField ที่รองรับ @mention autocomplete
//
// เมื่อ user พิมพ์ @ จะแสดง dropdown รายชื่อ staff ให้เลือก
// เลือกแล้วจะแทรก @nickname ลงใน text field อัตโนมัติ
// และเก็บ UUID ของ user ที่ถูก mention ไว้สำหรับส่ง notification
//
// ตัวอย่างการใช้งาน:
// ```dart
// MentionTextField(
//   controller: _commentController,
//   staffList: staffMembers,
//   onMentionsChange: (ids) => setState(() => _mentionedIds = ids),
//   hintText: 'เขียนความคิดเห็น...',
// )
// ```

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/network_image.dart';
import '../models/staff_member.dart';

/// TextField ที่รองรับ @mention — พิมพ์ @ แล้วแสดง dropdown เลือก staff
///
/// วิธีการทำงาน:
/// 1. ตรวจจับเมื่อ user พิมพ์ @ (ที่อยู่หลังช่องว่างหรือต้นบรรทัด)
/// 2. Filter รายชื่อ staff ตาม text ที่พิมพ์หลัง @
/// 3. แสดง overlay dropdown ด้านบนของ text field
/// 4. เมื่อเลือก staff จะแทรก @nickname + ช่องว่าง ลงใน text field
/// 5. เก็บ UUID ของ staff ที่ถูก mention ไว้ใน Set (ไม่ซ้ำ)
///
/// C6 bug prevention: OverlayEntry ถูก remove ใน dispose() เสมอ
/// C14 bug prevention: Match เฉพาะ @nickname ที่ตรงกับ staff list (ไม่ match email)
/// C19 bug prevention: ใช้ CompositedTransformFollower สำหรับ position overlay
class MentionTextField extends StatefulWidget {
  /// TextEditingController ที่ใช้ร่วมกับ text field
  final TextEditingController controller;

  /// รายชื่อ staff ทั้งหมดที่สามารถ mention ได้
  final List<StaffMember> staffList;

  /// Callback เมื่อรายการ mention เปลี่ยน — ส่งกลับเป็น list ของ UUID
  final ValueChanged<List<String>>? onMentionsChange;

  /// Hint text ที่แสดงเมื่อ text field ว่าง
  final String? hintText;

  /// จำนวนบรรทัดสูงสุดที่ text field แสดงได้
  final int maxLines;

  /// Custom InputDecoration (ถ้าไม่ระบุจะใช้ default)
  final InputDecoration? decoration;

  const MentionTextField({
    super.key,
    required this.controller,
    required this.staffList,
    this.onMentionsChange,
    this.hintText,
    this.maxLines = 5,
    this.decoration,
  });

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  // LayerLink เชื่อม CompositedTransformTarget กับ Follower
  // เพื่อให้ overlay อยู่ตำแหน่งเดียวกับ text field เสมอ (C19)
  final _layerLink = LayerLink();

  // FocusNode สำหรับจัดการ focus state ของ text field
  final _focusNode = FocusNode();

  // OverlayEntry ที่แสดง dropdown รายชื่อ staff
  // ต้อง remove ใน dispose() เพื่อป้องกัน memory leak (C6)
  OverlayEntry? _overlayEntry;

  // รายชื่อ staff ที่ผ่านการ filter ตาม query
  List<StaffMember> _filteredStaff = [];

  // ข้อความที่ user พิมพ์หลัง @ (ใช้สำหรับ filter)
  String _currentMentionQuery = '';

  // ตำแหน่ง cursor ที่ @ ถูกพิมพ์ — ใช้สำหรับแทรก @nickname
  int _mentionStartIndex = -1;

  // เก็บ UUID ของ user ที่ถูก mention (C15: ใช้ Set เพื่อไม่ให้ซ้ำ)
  final Set<String> _mentionedUserIds = {};

  /// Getter สำหรับดึงรายการ UUID ที่ถูก mention ทั้งหมด
  List<String> get mentionedUserIds => _mentionedUserIds.toList();

  @override
  void initState() {
    super.initState();

    // เมื่อ focus หาย → ซ่อน overlay dropdown
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideOverlay();
      }
    });
  }

  @override
  void dispose() {
    // CRITICAL: ต้อง remove overlay ก่อน dispose เสมอ
    // ไม่งั้น OverlayEntry จะค้างอยู่ใน Overlay tree → crash (C6)
    _hideOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  // ===========================================================================
  // @ Detection Logic — ตรวจจับเมื่อ user กำลังพิมพ์ @mention
  // ===========================================================================

  /// ตรวจสอบ text ทุกครั้งที่มีการเปลี่ยนแปลง
  /// หา @ ที่อยู่หน้า cursor แล้ว filter รายชื่อ staff
  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    // ถ้า cursor อยู่ต้น text หรือ selection ไม่ valid → ไม่ต้องทำอะไร
    if (cursorPos <= 0) {
      _hideOverlay();
      return;
    }

    // ดึง text ตั้งแต่ต้นจนถึง cursor
    final textBeforeCursor = text.substring(0, cursorPos);

    // หา @ ตัวสุดท้ายก่อน cursor
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    // ถ้าไม่มี @ เลย → ไม่ต้องแสดง dropdown
    if (lastAtIndex == -1) {
      _hideOverlay();
      return;
    }

    // C14: ตรวจสอบว่า @ อยู่ที่ต้นบรรทัดหรือหลังช่องว่าง
    // เพื่อไม่ให้ match กับ email เช่น user@example.com
    if (lastAtIndex > 0 &&
        textBeforeCursor[lastAtIndex - 1] != ' ' &&
        textBeforeCursor[lastAtIndex - 1] != '\n') {
      _hideOverlay();
      return;
    }

    // ดึง query ที่ user พิมพ์หลัง @ (เช่น "@som" → query = "som")
    final query = textBeforeCursor.substring(lastAtIndex + 1);

    // ถ้า query มีช่องว่างหรือขึ้นบรรทัดใหม่ → mention เสร็จแล้ว ไม่ต้องแสดง dropdown
    if (query.contains(' ') || query.contains('\n')) {
      _hideOverlay();
      return;
    }

    _mentionStartIndex = lastAtIndex;
    _currentMentionQuery = query.toLowerCase();

    // Filter staff list ตาม query (match ทั้ง nickname และ fullName)
    // จำกัด 10 คนเพื่อไม่ให้ dropdown ยาวเกินไป (C19 performance)
    _filteredStaff = widget.staffList
        .where((s) =>
            s.nickname.toLowerCase().contains(_currentMentionQuery) ||
            (s.fullName?.toLowerCase().contains(_currentMentionQuery) ?? false))
        .take(10)
        .toList();

    // ถ้าไม่มี staff ที่ match → ซ่อน dropdown
    if (_filteredStaff.isEmpty) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  // ===========================================================================
  // Overlay Management — จัดการ dropdown ที่แสดงรายชื่อ staff
  // ===========================================================================

  /// แสดง overlay dropdown รายชื่อ staff ด้านบนของ text field
  /// ใช้ CompositedTransformFollower เพื่อให้ตำแหน่งตามติด text field (C19)
  void _showOverlay() {
    // Remove overlay ตัวเก่าก่อนสร้างใหม่ เพื่อป้องกัน overlay ซ้อนกัน
    _hideOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          // แสดงด้านบนของ text field โดย offset ขึ้นไป 8px
          offset: const Offset(0, -8),
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              // จำกัดความสูงสูงสุด 200px เพื่อให้ scroll ได้ถ้ามีรายชื่อเยอะ
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.inputBorder,
                  width: 0.5,
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _filteredStaff.length,
                itemBuilder: (context, index) =>
                    _buildStaffItem(_filteredStaff[index]),
              ),
            ),
          ),
        ),
      ),
    );

    // แทรก overlay เข้าไปใน Overlay tree ของ app
    Overlay.of(context).insert(_overlayEntry!);
  }

  /// ซ่อน overlay dropdown
  /// เรียกทุกครั้งที่ไม่ต้องการแสดง dropdown (focus หาย, เลือก staff, etc.)
  void _hideOverlay() {
    // try-catch ป้องกัน crash ถ้า context ไม่ valid แล้ว
    // (เช่น ถูกเรียกหลัง widget unmount ระหว่าง navigation transition)
    try {
      _overlayEntry?.remove();
    } catch (_) {
      // ignore — overlay อาจถูก remove ไปแล้ว
    }
    _overlayEntry = null;
  }

  // ===========================================================================
  // Staff Item & Selection — แสดงรายชื่อ staff และจัดการเมื่อเลือก
  // ===========================================================================

  /// สร้าง widget สำหรับแต่ละ staff ใน dropdown
  /// แสดง avatar + nickname + fullName (ถ้ามี)
  Widget _buildStaffItem(StaffMember staff) {
    return InkWell(
      onTap: () => _selectMention(staff),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // รูปโปรไฟล์ของ staff (วงกลม radius 14)
            IreneNetworkAvatar(
              imageUrl: staff.photoUrl,
              radius: 14,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ชื่อเล่น — ตัวหนา เพราะเป็นชื่อหลักที่ใช้ mention
                  Text(
                    staff.nickname,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // ชื่อ-นามสกุลเต็ม (ถ้ามี) — สีเทา ขนาดเล็กกว่า
                  if (staff.fullName != null && staff.fullName!.isNotEmpty)
                    Text(
                      staff.fullName!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// เมื่อ user เลือก staff จาก dropdown
  /// 1. แทรก @nickname + space ลงใน text field แทนที่ query เดิม
  /// 2. เลื่อน cursor ไปหลัง @nickname
  /// 3. เก็บ UUID ของ staff ที่ถูก mention
  /// 4. แจ้ง parent widget ผ่าน onMentionsChange callback
  void _selectMention(StaffMember staff) {
    final text = widget.controller.text;

    // แยก text ก่อน @ และหลัง cursor
    final beforeMention = text.substring(0, _mentionStartIndex);
    final afterCursor =
        text.substring(widget.controller.selection.baseOffset);

    // สร้าง mention text: @nickname + ช่องว่าง (เพื่อให้พิมพ์ต่อได้สะดวก)
    final mentionText = '@${staff.nickname} ';
    final newText = beforeMention + mentionText + afterCursor;

    // อัพเดต text field และเลื่อน cursor ไปหลัง mention
    widget.controller.text = newText;
    final newCursorPos = beforeMention.length + mentionText.length;
    widget.controller.selection =
        TextSelection.collapsed(offset: newCursorPos);

    // เก็บ UUID ของ staff (C15: Set จะ dedupe อัตโนมัติถ้า mention ซ้ำ)
    _mentionedUserIds.add(staff.id);
    widget.onMentionsChange?.call(_mentionedUserIds.toList());

    _hideOverlay();
  }

  // ===========================================================================
  // Public Methods — สำหรับให้ parent widget เรียกใช้
  // ===========================================================================

  /// ล้างรายการ mention ทั้งหมด
  /// ใช้เมื่อ submit form แล้วต้องการ reset state
  void clearMentions() {
    _mentionedUserIds.clear();
    widget.onMentionsChange?.call([]);
  }

  // ===========================================================================
  // Build — สร้าง UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    // CompositedTransformTarget จับคู่กับ CompositedTransformFollower
    // เพื่อให้ overlay dropdown อยู่ตำแหน่งสัมพันธ์กับ text field
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        // ตรวจจับ @mention ทุกครั้งที่ text เปลี่ยน
        onChanged: (_) => _onTextChanged(),
        maxLines: widget.maxLines,
        style: AppTypography.body,
        decoration: widget.decoration ??
            InputDecoration(
              hintText: widget.hintText ?? 'พิมพ์ @ เพื่อแท็กเพื่อนร่วมงาน',
              hintStyle: AppTypography.body.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.inputFocused,
                  width: 1.5,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
      ),
    );
  }
}
