import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../models/clock_in_out.dart';
import '../models/break_time_option.dart';
import '../models/friend_break_time.dart';
import '../models/shift_leader.dart';

/// Service สำหรับจัดการ Clock In/Out
class ClockService {
  static final ClockService instance = ClockService._();
  ClockService._();

  final _supabase = Supabase.instance.client;
  final _userService = UserService();

  // Cache
  ClockInOut? _cachedCurrentShift;
  DateTime? _shiftCacheTime;
  String? _cachedUserId; // Track user ID for cache validation
  static const _cacheMaxAge = Duration(minutes: 2);

  /// ดึงเวรปัจจุบันของ user (ถ้ายังไม่ลงเวร)
  Future<ClockInOut?> getCurrentShift({bool forceRefresh = false}) async {
    final userId = _userService.effectiveUserId;
    final nursinghomeId = await _userService.getNursinghomeId();
    if (userId == null || nursinghomeId == null) return null;

    // Check cache - also validate user ID matches
    if (!forceRefresh &&
        _cachedCurrentShift != null &&
        _shiftCacheTime != null &&
        _cachedUserId == userId &&
        DateTime.now().difference(_shiftCacheTime!) < _cacheMaxAge) {
      // ถ้า cached shift ยัง clocked in อยู่ให้ใช้ cache
      if (_cachedCurrentShift!.isClockedIn) {
        return _cachedCurrentShift;
      }
    }

    try {
      final response = await _supabase
          .from('clock_in_out_ver2')
          .select()
          .eq('user_id', userId)
          .eq('nursinghome_id', nursinghomeId)
          .isFilter('clock_out_timestamp', null)
          .order('clock_in_timestamp', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        _cachedCurrentShift = null;
        _shiftCacheTime = DateTime.now();
        _cachedUserId = userId;
        return null;
      }

      _cachedCurrentShift = ClockInOut.fromJson(response);
      _shiftCacheTime = DateTime.now();
      _cachedUserId = userId;
      return _cachedCurrentShift;
    } catch (e) {
      return null;
    }
  }

  /// ขึ้นเวร (Clock In)
  Future<ClockInOut?> clockIn({
    required List<int> zoneIds,
    required List<int> residentIds,
    required List<int> breakTimeIds,
    bool isIncharge = false,
  }) async {
    final userId = _userService.effectiveUserId;
    final nursinghomeId = await _userService.getNursinghomeId();
    if (userId == null || nursinghomeId == null) return null;

    try {
      // กำหนด shift ตามเวลาปัจจุบัน
      // AM (00:00-11:59) = เวรเช้า, PM (12:00-23:59) = เวรดึก
      final now = DateTime.now();
      final hour = now.hour;
      final shift = hour < 12 ? 'เวรเช้า' : 'เวรดึก';

      final response = await _supabase.from('clock_in_out_ver2').insert({
        'user_id': userId,
        'nursinghome_id': nursinghomeId,
        'isAuto': false,
        'Incharge': isIncharge,
        'zones': zoneIds,
        'clock_in_timestamp': now.toIso8601String(),
        'shift': shift,
        'selected_resident_id_list': residentIds,
        'selected_break_time': breakTimeIds,
      }).select().single();

      // Clear cache
      invalidateCache();

      return ClockInOut.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// ลงเวร (Clock Out)
  Future<bool> clockOut(int clockRecordId) async {
    try {
      await _supabase.from('clock_in_out_ver2').update({
        'clock_out_timestamp': DateTime.now().toIso8601String(),
      }).eq('id', clockRecordId);

      // Clear cache
      invalidateCache();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// ดึงตัวเลือกเวลาพักตาม shift
  Future<List<BreakTimeOption>> getBreakTimeOptions({String? shift}) async {
    final nursinghomeId = await _userService.getNursinghomeId();
    if (nursinghomeId == null) return [];

    try {
      var query = _supabase
          .from('clock_break_time_nursinghome')
          .select()
          .eq('nursinghome_id', nursinghomeId);

      if (shift != null) {
        query = query.eq('shift', shift);
      }

      final response = await query.order('index');

      return (response as List)
          .map((json) => BreakTimeOption.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// ดึงตัวเลือกเวลาพักสำหรับ shift ปัจจุบัน
  /// - AM (00:00-11:59) = เวรเช้า (มาทำงานตอนเช้า)
  /// - PM (12:00-23:59) = เวรดึก (มาทำงานตอนบ่าย/เย็น)
  Future<List<BreakTimeOption>> getBreakTimeOptionsForCurrentShift() async {
    final hour = DateTime.now().hour;
    // AM = เวรเช้า, PM = เวรดึก
    final shift = hour < 12 ? 'เวรเช้า' : 'เวรดึก';
    return getBreakTimeOptions(shift: shift);
  }

  /// ตรวจสอบว่ามีโพสต์ handover หรือยัง
  Future<bool> hasHandoverPost() async {
    final userId = _userService.effectiveUserId;
    final nursinghomeId = await _userService.getNursinghomeId();
    if (userId == null || nursinghomeId == null) return false;

    try {
      // คำนวณ working day start (07:00 ของวันนี้ หรือวันก่อนหน้าถ้าก่อน 07:00)
      final now = DateTime.now();
      DateTime workingDayStart;
      if (now.hour < 7) {
        // ก่อน 07:00 ใช้วันก่อนหน้า
        final yesterday = now.subtract(const Duration(days: 1));
        workingDayStart = DateTime(yesterday.year, yesterday.month, yesterday.day, 7);
      } else {
        workingDayStart = DateTime(now.year, now.month, now.day, 7);
      }

      final response = await _supabase
          .from('Post')
          .select('id')
          .eq('creator_id', userId)
          .eq('is_handover', true)
          .gte('post_created_at', workingDayStart.toIso8601String())
          .limit(1)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// กำหนด shift จากเวลาปัจจุบัน
  /// - AM (00:00-11:59) = เวรเช้า (มาทำงานตอนเช้า)
  /// - PM (12:00-23:59) = เวรดึก (มาทำงานตอนบ่าย/เย็น)
  String getCurrentShiftType() {
    final hour = DateTime.now().hour;
    // AM = เวรเช้า, PM = เวรดึก
    return hour < 12 ? 'เวรเช้า' : 'เวรดึก';
  }

  /// ดึงเวลาพักที่เพื่อนทั้งหมดในเวรปัจจุบันเลือกไปแล้ว
  /// Returns Map of breakTimeId to List of FriendBreakTime (ชื่อเพื่อน + โซน)
  Future<Map<int, List<FriendBreakTime>>> getOccupiedBreakTimes() async {
    final userId = _userService.effectiveUserId;
    final nursinghomeId = await _userService.getNursinghomeId();
    if (userId == null || nursinghomeId == null) return {};

    try {
      // กำหนด shift ปัจจุบัน (AM = เวรเช้า, PM = เวรดึก)
      final currentShift = getCurrentShiftType();

      // ดึง clock_in_out ที่ยังไม่ลงเวร (ของคนอื่น) เฉพาะ shift เดียวกัน
      final response = await _supabase
          .from('clock_in_out_ver2')
          .select('''
            selected_break_time,
            zones,
            user_info:user_id(nickname)
          ''')
          .eq('nursinghome_id', nursinghomeId)
          .eq('shift', currentShift)
          .neq('user_id', userId)
          .isFilter('clock_out_timestamp', null);

      // ดึงรายชื่อ zone ทั้งหมดเพื่อ map id -> name
      final zonesResponse = await _supabase
          .from('nursinghome_zone')
          .select('id, zone')
          .eq('nursinghome_id', nursinghomeId);

      final zoneMap = <int, String>{};
      for (final zone in zonesResponse as List) {
        zoneMap[zone['id'] as int] = zone['zone'] as String? ?? '-';
      }

      final occupiedBreakTimes = <int, List<FriendBreakTime>>{};

      for (final row in response as List) {
        // ดึงชื่อเพื่อน (nickname จาก user_info)
        final userData = row['user_info'] as Map<String, dynamic>?;
        final friendName = userData?['nickname'] as String? ?? 'เพื่อน';

        // ดึง zone names จาก zones array
        final zoneIds = row['zones'] as List?;
        String? zoneName;
        if (zoneIds != null && zoneIds.isNotEmpty) {
          // รวมชื่อ zone ทั้งหมด (กรณีมีหลาย zone)
          final zoneNames = zoneIds
              .map((id) => zoneMap[id as int])
              .where((name) => name != null)
              .toList();
          if (zoneNames.isNotEmpty) {
            zoneName = zoneNames.join(', ');
          }
        }

        // ดึง break time IDs
        final breakTimeIds = row['selected_break_time'];
        if (breakTimeIds != null && breakTimeIds is List) {
          for (final id in breakTimeIds) {
            if (id is int) {
              occupiedBreakTimes.putIfAbsent(id, () => []).add(
                FriendBreakTime(name: friendName, zoneName: zoneName),
              );
            }
          }
        }
      }

      return occupiedBreakTimes;
    } catch (e) {
      return {};
    }
  }

  /// ดึง ID คนไข้ที่ถูกเลือกโดยคนอื่นแล้ว (ในเวรปัจจุบัน)
  /// ใช้เพื่อ disable คนไข้ที่เพื่อนเลือกไปแล้ว
  Future<Set<int>> getOccupiedResidentIds() async {
    final userId = _userService.effectiveUserId;
    final nursinghomeId = await _userService.getNursinghomeId();
    if (userId == null || nursinghomeId == null) return {};

    try {
      // กำหนด shift ปัจจุบัน (AM = เวรเช้า, PM = เวรดึก)
      final currentShift = getCurrentShiftType();

      // ดึง clock_in_out ที่ยังไม่ลงเวร (ของคนอื่น) เฉพาะ shift เดียวกัน
      final response = await _supabase
          .from('clock_in_out_ver2')
          .select('selected_resident_id_list')
          .eq('nursinghome_id', nursinghomeId)
          .eq('shift', currentShift)
          .neq('user_id', userId)
          .isFilter('clock_out_timestamp', null);

      final occupiedIds = <int>{};
      for (final row in response as List) {
        final residentIds = row['selected_resident_id_list'];
        if (residentIds != null && residentIds is List) {
          for (final id in residentIds) {
            if (id is int) {
              occupiedIds.add(id);
            }
          }
        }
      }

      return occupiedIds;
    } catch (e) {
      return {};
    }
  }

  /// ดึงรายชื่อเพื่อนร่วมเวรที่ขึ้นเวรเดียวกันอยู่ตอนนี้
  /// ใช้สำหรับ batch task mode — เลือกเพื่อนร่วมเวรเพื่อหาร point
  ///
  /// Query: clock_in_out_ver2 ที่ nursinghome_id + shift เดียวกัน
  /// + ยังไม่ clock out (clock_out_timestamp IS NULL)
  /// + ไม่ใช่ตัวเอง
  Future<List<Map<String, dynamic>>> getCoWorkersInCurrentShift() async {
    final userId = _userService.effectiveUserId;
    final nursinghomeId = await _userService.getNursinghomeId();
    if (userId == null || nursinghomeId == null) return [];

    // ดึงเวรปัจจุบันเพื่อหา shift type
    final currentShift = await getCurrentShift();
    if (currentShift == null) return [];

    try {
      // กรองเฉพาะวันนี้ เพื่อไม่ให้ดึง clock-in ค้างจากวันก่อนๆ
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final response = await _supabase
          .from('clock_in_out_ver2')
          .select('''
            user_id,
            user_info:user_id(
              nickname,
              photo_url
            )
          ''')
          .eq('nursinghome_id', nursinghomeId)
          .eq('shift', currentShift.shift)
          .neq('user_id', userId)
          .isFilter('clock_out_timestamp', null)
          .gte('clock_in_timestamp', todayStart.toIso8601String());

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error fetching co-workers: $e');
      return [];
    }
  }

  /// ล้าง cache เพื่อบังคับ fetch ข้อมูลใหม่จาก server
  void invalidateCache() {
    _cachedCurrentShift = null;
    _shiftCacheTime = null;
    _cachedUserId = null;
  }

  /// ลงเวร (Clock Out) พร้อม survey data
  /// - leaderScore: คะแนนประเมินหัวหน้าเวร (1-10) - จะ insert ไปที่ leader_evaluations table
  /// - leaderId: user_id ของหัวหน้าเวรที่ถูกประเมิน
  Future<bool> clockOutWithSurvey({
    required int clockRecordId,
    required int shiftScore,
    required int selfScore,
    required String shiftSurvey,
    String? bugSurvey,
    int? leaderScore,
    String? leaderId,
  }) async {
    final userId = _userService.effectiveUserId;
    final nursinghomeId = await _userService.getNursinghomeId();
    if (userId == null || nursinghomeId == null) return false;

    try {
      final now = DateTime.now();

      // 1. Update clock_in_out_ver2 (ไม่เก็บ leader_score ที่นี่แล้ว)
      await _supabase.from('clock_in_out_ver2').update({
        'clock_out_timestamp': now.toIso8601String(),
        'shift_score': shiftScore,
        'self_score': selfScore,
        'shift_survey': shiftSurvey,
        'bug_survey': bugSurvey,
      }).eq('id', clockRecordId);

      // 2. Insert leader evaluation ไปที่ table แยก (ถ้ามี)
      // เก็บ evaluator_id ไว้เพื่อป้องกันซ้ำ แต่ไม่แสดงที่ frontend
      if (leaderScore != null && leaderId != null) {
        final shiftType = getCurrentShiftType();
        // shift_date = วันที่ของเวร (ถ้าเวรดึกก่อน 07:00 ให้ใช้วันก่อนหน้า)
        final shiftDate = now.hour < 7
            ? now.subtract(const Duration(days: 1))
            : now;

        await _supabase.from('leader_evaluations').upsert({
          'leader_id': leaderId,
          'evaluator_id': userId,
          'nursinghome_id': nursinghomeId,
          'shift': shiftType,
          'shift_date': '${shiftDate.year}-${shiftDate.month.toString().padLeft(2, '0')}-${shiftDate.day.toString().padLeft(2, '0')}',
          'score': leaderScore,
        }, onConflict: 'leader_id,evaluator_id,shift_date,shift');
      }

      // Clear cache
      invalidateCache();

      return true;
    } catch (e) {
      debugPrint('clockOutWithSurvey error: $e');
      return false;
    }
  }

  /// นับ Posts ที่ยังไม่ได้อ่าน (like = อ่านแล้ว)
  /// เงื่อนไข: is_handover = true หรือ resident_id IS NULL (14 วันล่าสุด)
  Future<int> getUnreadAnnouncementsCount() async {
    final userId = _userService.effectiveUserId;
    final nursinghomeId = await _userService.getNursinghomeId();
    if (userId == null || nursinghomeId == null) return 0;

    try {
      // ดึงโพส 14 วันล่าสุดที่ต้องอ่าน
      final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));

      final response = await _supabase
          .from('postwithuserinfo')
          .select('id, like_user_ids, is_handover, resident_id')
          .eq('nursinghome_id', nursinghomeId)
          .gte('post_created_at', fourteenDaysAgo.toIso8601String());

      // Filter: (is_handover = true OR resident_id IS NULL) AND user ยังไม่ได้ like
      final unreadPosts = (response as List).where((post) {
        final isHandover = post['is_handover'] as bool? ?? false;
        final residentId = post['resident_id'];
        final likeUserIds = post['like_user_ids'] as List? ?? [];

        // ต้องเป็นโพสที่บังคับอ่าน (handover หรือ ไม่มี resident)
        final isRequiredPost = isHandover || residentId == null;

        return isRequiredPost && !likeUserIds.contains(userId);
      }).toList();

      return unreadPosts.length;
    } catch (e) {
      return 0;
    }
  }

  /// ดึงข้อมูลหัวหน้าเวรของเวรที่ระบุ (คนที่ Incharge = true)
  /// - [shift] = เวรที่ user กำลังจะลงเวร (เช่น 'เวรเช้า' หรือ 'เวรดึก')
  ///   ต้องส่งค่าจริงจาก clock record ไม่ใช่คำนวณจากเวลาปัจจุบัน
  ///   เพราะ เวรเช้าลงเวรตอน 19:00+ (getCurrentShiftType จะได้ 'เวรดึก' ผิด)
  /// - ต้องยังไม่ลงเวร (clock_out_timestamp IS NULL)
  /// - ต้องไม่ใช่ตัวเอง
  /// Returns null ถ้าไม่มีหัวหน้าเวร หรือตัวเองเป็นหัวหน้าเวร
  Future<ShiftLeader?> getShiftLeader(String shift) async {
    final userId = _userService.effectiveUserId;
    final nursinghomeId = await _userService.getNursinghomeId();
    if (userId == null || nursinghomeId == null) return null;

    try {
      // ค้นหาคนที่ Incharge = true ในเวรเดียวกัน (ไม่ใช่ตัวเอง)
      // ใช้ shift ที่ส่งมาจาก clock record จริง ไม่ใช้ getCurrentShiftType()
      // เพราะ user เวรเช้าที่ลงเวรตอน 19:00+ จะได้ shift ผิดถ้าดูจากเวลา
      final response = await _supabase
          .from('clock_in_out_ver2')
          .select('''
            user_id,
            user_info:user_id(nickname, full_name, photo_url)
          ''')
          .eq('nursinghome_id', nursinghomeId)
          .eq('shift', shift)
          .eq('Incharge', true)
          .neq('user_id', userId)
          .isFilter('clock_out_timestamp', null)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return ShiftLeader.fromJson(response);
    } catch (e) {
      debugPrint('getShiftLeader error: $e');
      return null;
    }
  }

  /// ดึงรายการ Posts ที่ยังไม่ได้อ่าน (สำหรับแสดงใน dialog)
  /// เงื่อนไข: is_handover = true หรือ resident_id IS NULL (14 วันล่าสุด)
  /// เรียงจากใหม่ไปเก่า เพื่อให้อ่านโพสใหม่ก่อน
  Future<List<Map<String, dynamic>>> getUnreadAnnouncements() async {
    final userId = _userService.effectiveUserId;
    final nursinghomeId = await _userService.getNursinghomeId();
    debugPrint('getUnreadAnnouncements: userId=$userId, nursinghomeId=$nursinghomeId');
    if (userId == null || nursinghomeId == null) return [];

    try {
      // ดึงโพส 14 วันล่าสุดที่ต้องอ่าน เรียงจากใหม่ไปเก่า
      final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));

      final response = await _supabase
          .from('postwithuserinfo')
          .select('id, prioritized_tab, like_user_ids, is_handover, resident_id, post_created_at')
          .eq('nursinghome_id', nursinghomeId)
          .gte('post_created_at', fourteenDaysAgo.toIso8601String())
          .order('post_created_at', ascending: false);

      debugPrint('getUnreadAnnouncements: raw response length=${(response as List).length}');

      // Filter: (is_handover = true OR resident_id IS NULL) AND user ยังไม่ได้ like
      final unreadPosts = response.where((post) {
        final isHandover = post['is_handover'] as bool? ?? false;
        final residentId = post['resident_id'];
        final likeUserIds = post['like_user_ids'] as List? ?? [];

        // ต้องเป็นโพสที่บังคับอ่าน (handover หรือ ไม่มี resident)
        final isRequiredPost = isHandover || residentId == null;

        return isRequiredPost && !likeUserIds.contains(userId);
      }).map((post) => {
        // แปลง field name ให้ตรงกับที่ใช้อยู่ (post_id)
        'post_id': post['id'],
        'tab': post['prioritized_tab'],
      }).toList();

      debugPrint('getUnreadAnnouncements: unread count=${unreadPosts.length}');
      return unreadPosts;
    } catch (e) {
      debugPrint('getUnreadAnnouncements error: $e');
      return [];
    }
  }
}
