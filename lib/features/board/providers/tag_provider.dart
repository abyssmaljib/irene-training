import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/new_tag.dart';

/// Provider สำหรับดึง tags จาก new_tags table
final tagsProvider = FutureProvider<List<NewTag>>((ref) async {
  final supabase = Supabase.instance.client;

  // ดึงเฉพาะ tag ที่ is_visible = true (ซ่อนจาก UI แต่ยังใช้งานได้)
  final response = await supabase
      .from('new_tags')
      .select('id, name, icon, emoji, handover_mode, legacy_tags, sort_order, is_visible')
      .eq('is_visible', true)
      .order('sort_order', ascending: true)
      .order('name', ascending: true);

  return (response as List)
      .map((json) => NewTag.fromJson(json as Map<String, dynamic>))
      .toList();
});

/// Provider สำหรับ tag ที่เลือก (single select)
final selectedTagProvider = StateProvider<NewTag?>((ref) => null);

/// Provider สำหรับ handover toggle state
final isHandoverProvider = StateProvider<bool>((ref) {
  final selectedTag = ref.watch(selectedTagProvider);

  // ถ้าเป็น force → default true (บังคับ)
  // ถ้าเป็น optional/none → default false (เลือกได้)
  if (selectedTag == null) return false;
  return selectedTag.defaultHandover;
});

/// Helper class สำหรับจัดการ tag selection
class TagSelectionNotifier {
  final Ref ref;

  TagSelectionNotifier(this.ref);

  /// เลือก tag
  void selectTag(NewTag tag) {
    ref.read(selectedTagProvider.notifier).state = tag;

    // Auto-set handover based on mode
    if (tag.isForceHandover) {
      ref.read(isHandoverProvider.notifier).state = true;
    } else if (tag.isOptionalHandover) {
      // Keep current value or default to false
      // User can toggle
    } else {
      ref.read(isHandoverProvider.notifier).state = false;
    }
  }

  /// ยกเลิกการเลือก tag
  void clearTag() {
    ref.read(selectedTagProvider.notifier).state = null;
    ref.read(isHandoverProvider.notifier).state = false;
  }

  /// Toggle handover (only for optional mode)
  void toggleHandover(bool value) {
    final selectedTag = ref.read(selectedTagProvider);
    if (selectedTag == null) return;

    // ไม่สามารถปิดได้ถ้าเป็น force
    if (selectedTag.isForceHandover) return;

    ref.read(isHandoverProvider.notifier).state = value;
  }

  /// ตรวจสอบว่า handover toggle สามารถเปลี่ยนได้หรือไม่
  /// (ทุก tag ที่ไม่ใช่ force สามารถ toggle ได้)
  bool canToggleHandover() {
    final selectedTag = ref.read(selectedTagProvider);
    if (selectedTag == null) return false;
    return selectedTag.isOptionalHandover; // รวม none ด้วย
  }

  /// ตรวจสอบว่าควรแสดง handover toggle หรือไม่
  /// (แสดงเสมอเมื่อเลือก tag เพราะทุก tag สามารถส่งเวรได้)
  bool shouldShowHandoverToggle() {
    final selectedTag = ref.read(selectedTagProvider);
    return selectedTag != null;
  }
}
