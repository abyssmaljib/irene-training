import 'package:shared_preferences/shared_preferences.dart';

import '../models/post_draft.dart';

/// Service สำหรับจัดการ draft ของ post ที่ยังไม่ได้โพส
/// ใช้ SharedPreferences เก็บ draft เป็น JSON string ในเครื่อง
///
/// Keys ที่ใช้:
/// - `create_post_draft_{odooUserId}`: String (JSON) - draft ของ user
///
/// Note: ใช้ odooUserId เพื่อแยก draft ของแต่ละ user
/// ถ้า user logout แล้ว login ใหม่ จะได้ draft เดิมกลับมา
class PostDraftService {
  final SharedPreferences _prefs;

  // SharedPreferences key prefix
  static const _keyPrefix = 'create_post_draft_';

  PostDraftService(this._prefs);

  /// สร้าง key สำหรับ user
  String _getKey(String odooUserId) => '$_keyPrefix$odooUserId';

  /// บันทึก draft ลง SharedPreferences
  /// ถ้า draft ไม่มี content จะลบ draft เดิมออก
  Future<void> saveDraft(String odooUserId, PostDraft draft) async {
    final key = _getKey(odooUserId);

    // ถ้าไม่มี content ไม่ต้องบันทึก (ลบ draft เดิมถ้ามี)
    if (!draft.hasContent) {
      await _prefs.remove(key);
      return;
    }

    // บันทึก draft เป็น JSON string
    await _prefs.setString(key, draft.toJsonString());
  }

  /// โหลด draft จาก SharedPreferences
  /// Returns null ถ้าไม่มี draft หรือ parse ไม่ได้
  PostDraft? loadDraft(String odooUserId) {
    final key = _getKey(odooUserId);
    final jsonString = _prefs.getString(key);

    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }

    try {
      return PostDraft.fromJsonString(jsonString);
    } catch (e) {
      // ถ้า parse ไม่ได้ ลบ draft เสียออก
      _prefs.remove(key);
      return null;
    }
  }

  /// ตรวจสอบว่ามี draft หรือไม่
  bool hasDraft(String odooUserId) {
    final key = _getKey(odooUserId);
    final jsonString = _prefs.getString(key);
    return jsonString != null && jsonString.isNotEmpty;
  }

  /// ลบ draft ออกจาก SharedPreferences
  /// เรียกเมื่อ:
  /// - user โพสสำเร็จ
  /// - user กด "ยกเลิก" ใน confirmation dialog
  /// - user กด "เริ่มใหม่" เมื่อมี draft ค้างอยู่
  Future<void> clearDraft(String odooUserId) async {
    final key = _getKey(odooUserId);
    await _prefs.remove(key);
  }
}
