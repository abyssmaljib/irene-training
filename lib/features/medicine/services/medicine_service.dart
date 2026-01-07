import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicine_summary.dart';
import '../models/med_log.dart';
import '../models/med_error_log.dart';
import '../models/meal_photo_group.dart';
import '../models/med_db.dart';
import '../models/med_atc_level.dart';
import '../models/medicine_list_item.dart';
import '../models/med_history.dart';

/// Service สำหรับจัดการข้อมูลยา
/// ใช้ in-memory cache สำหรับข้อมูลยาเพื่อลด API calls
/// Cache จะ invalidate อัตโนมัติเมื่อ:
/// - เปลี่ยน residentId
/// - เรียก forceRefresh = true
/// - ผ่านไป 5 นาที
class MedicineService {
  static final instance = MedicineService._();
  MedicineService._();

  final _supabase = Supabase.instance.client;

  // Cache สำหรับข้อมูลยา (per resident)
  int? _cachedResidentId;
  List<MedicineSummary>? _cachedMedicines;
  DateTime? _cacheTime;
  static const _cacheMaxAge = Duration(minutes: 5);

  /// ตรวจสอบว่า cache ยังใช้ได้อยู่
  bool _isCacheValid(int residentId) {
    if (_cachedResidentId != residentId) return false;
    if (_cachedMedicines == null) return false;
    if (_cacheTime == null) return false;
    return DateTime.now().difference(_cacheTime!) < _cacheMaxAge;
  }

  /// ล้าง cache (เรียกเมื่อมีการอัพเดตข้อมูลยา)
  void invalidateCache() {
    _cachedMedicines = null;
    _cacheTime = null;
  }

  /// 7 มื้อที่ต้องตรวจสอบ
  /// beforeAfter: 'ก่อนอาหาร' หรือ 'หลังอาหาร' (empty for ก่อนนอน)
  /// bldb: 'เช้า', 'กลางวัน', 'เย็น', 'ก่อนนอน'
  /// mealKey: ใช้ match กับ meal field ใน med_logs
  static const List<Map<String, String>> mealSlots = [
    {'beforeAfter': 'ก่อนอาหาร', 'bldb': 'เช้า', 'label': 'เช้า (ก่อน)', 'mealKey': 'ก่อนอาหารเช้า'},
    {'beforeAfter': 'หลังอาหาร', 'bldb': 'เช้า', 'label': 'เช้า (หลัง)', 'mealKey': 'หลังอาหารเช้า'},
    {'beforeAfter': 'ก่อนอาหาร', 'bldb': 'กลางวัน', 'label': 'กลางวัน (ก่อน)', 'mealKey': 'ก่อนอาหารกลางวัน'},
    {'beforeAfter': 'หลังอาหาร', 'bldb': 'กลางวัน', 'label': 'กลางวัน (หลัง)', 'mealKey': 'หลังอาหารกลางวัน'},
    {'beforeAfter': 'ก่อนอาหาร', 'bldb': 'เย็น', 'label': 'เย็น (ก่อน)', 'mealKey': 'ก่อนอาหารเย็น'},
    {'beforeAfter': 'หลังอาหาร', 'bldb': 'เย็น', 'label': 'เย็น (หลัง)', 'mealKey': 'หลังอาหารเย็น'},
    {'beforeAfter': '', 'bldb': 'ก่อนนอน', 'label': 'ก่อนนอน', 'mealKey': 'ก่อนนอน'},
  ];

  /// ดึงรายการยาทั้งหมดของ Resident
  /// [forceRefresh] = true จะบังคับ fetch ใหม่จาก API
  Future<List<MedicineSummary>> getMedicinesByResident(
    int residentId, {
    bool forceRefresh = false,
  }) async {
    // ใช้ cache ถ้ายังใช้ได้และไม่ได้บังคับ refresh
    if (!forceRefresh && _isCacheValid(residentId)) {
      return _cachedMedicines!;
    }

    try {
      final response = await _supabase
          .from('medicine_summary')
          .select()
          .eq('resident_id', residentId)
          .order('medicine_list_id', ascending: true);

      final medicines = (response as List)
          .map((json) => MedicineSummary.fromJson(json))
          .toList();

      // Update cache
      _cachedResidentId = residentId;
      _cachedMedicines = medicines;
      _cacheTime = DateTime.now();

      return medicines;
    } catch (e) {
      // Return cached data if available even on error
      if (_cachedResidentId == residentId && _cachedMedicines != null) {
        return _cachedMedicines!;
      }
      return [];
    }
  }

  /// ดึงรายการยาที่ active (status = 'on')
  /// ใช้ข้อมูลจาก cache ของ getMedicinesByResident
  Future<List<MedicineSummary>> getActiveMedicines(
    int residentId, {
    bool forceRefresh = false,
  }) async {
    final allMedicines = await getMedicinesByResident(
      residentId,
      forceRefresh: forceRefresh,
    );
    return allMedicines.where((m) => m.isActive).toList();
  }

  /// ดึง med logs ของวันที่กำหนด
  /// Optimized: query ตรงจาก A_Med_logs table พร้อม nested select
  /// เร็วกว่า view เพราะไม่มี WHERE filter 1 month และ 3 LEFT JOINs
  Future<List<MedLog>> getMedLogsForDate(int residentId, DateTime date) async {
    try {
      // Format date เป็น YYYY-MM-DD
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final stopwatch = Stopwatch()..start();

      // Query ตรงจาก A_Med_logs พร้อม nested select สำหรับ nicknames
      // ดึง 2C_completed_by และ 3C_Compleated_by เพื่อใช้ตรวจสอบสิทธิ์ลบรูป
      final response = await _supabase
          .from('A_Med_logs')
          .select('''
            id,
            resident_id,
            meal,
            created_at,
            Created_Date,
            SecondCPictureUrl,
            ThirdCPictureUrl,
            3C_time_stamps,
            2C_completed_by,
            3C_Compleated_by,
            user_2c:2C_completed_by(nickname),
            user_3c:3C_Compleated_by(nickname)
          ''')
          .eq('resident_id', residentId)
          .eq('Created_Date', dateStr);

      stopwatch.stop();

      return (response as List).map((json) {
        // Map nested user data to flat structure for MedLog.fromJson
        final mapped = {
          'id': json['id'],
          'resident_id': json['resident_id'],
          'meal': json['meal'],
          'created_at': json['created_at'],
          'Created_Date': json['Created_Date'],
          '2C_picture_url': json['SecondCPictureUrl'],
          '3C_picture_url': json['ThirdCPictureUrl'],
          '3C_time_stamps': json['3C_time_stamps'],
          'user_nickname_2c': json['user_2c']?['nickname'],
          'user_nickname_3c': json['user_3c']?['nickname'],
          // User IDs สำหรับตรวจสอบสิทธิ์ลบรูป
          '2C_completed_by': json['2C_completed_by'],
          '3C_Compleated_by': json['3C_Compleated_by'],
        };
        return MedLog.fromJson(mapped);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// ดึงสถานะการให้ยาแต่ละมื้อของวันที่กำหนด
  /// ใช้ filter ตามวันที่และความถี่การกินยา (typeOfTime, everyHr, daysOfWeek)
  /// Returns Map โดย key เป็น mealKey เช่น 'ก่อนอาหารเช้า'
  Future<Map<String, MealStatus>> getMealStatusForDate(
    int residentId,
    DateTime date, {
    bool? filterPrn, // กรองยาตามอาการ (null = ไม่กรอง, false = ยาปกติ)
  }) async {
    try {
      // ดึงยาทั้งหมดที่ active
      final medicines = await getActiveMedicines(residentId);

      // ดึง logs ของวันนี้
      final logs = await getMedLogsForDate(residentId, date);

      // สร้าง map ของ logs โดย key เป็น meal
      final logsMap = <String, MedLog>{};
      for (final log in logs) {
        logsMap[log.meal] = log;
      }

      // สร้าง result map
      final result = <String, MealStatus>{};

      for (final slot in mealSlots) {
        final beforeAfter = slot['beforeAfter']!;
        final bldb = slot['bldb']!;
        final mealKey = slot['mealKey']!;

        // กรองยาที่ตรงกับมื้อนี้และวันที่เลือก
        // ใช้ MedicineSummary.filterByDate (เทียบเท่า specDayonWeekReturnListModify7)
        final medicinesInMeal = MedicineSummary.filterByDate(
          medicines: medicines,
          selectedDate: date,
          beforeAfter: beforeAfter.isEmpty ? null : beforeAfter,
          bldb: bldb,
          prn: filterPrn,
        );

        final count = medicinesInMeal.length;
        final log = logsMap[mealKey];
        final hasPhoto = log?.hasPicture3C ?? false;

        result[mealKey] = MealStatus(
          mealKey: mealKey,
          label: slot['label']!,
          medicineCount: count,
          hasPhoto: hasPhoto,
          log: log,
        );
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  /// นับจำนวนยาที่ active
  Future<int> getActiveMedicineCount(int residentId) async {
    try {
      final medicines = await getActiveMedicines(residentId);
      return medicines.length;
    } catch (e) {
      return 0;
    }
  }

  /// ดึงรายการยาพร้อมรูปภาพจาก medicine_summary
  /// ใช้ข้อมูลจาก cache ของ getMedicinesByResident
  Future<List<MedicineSummary>> getMedicinePhotos(
    int residentId, {
    bool forceRefresh = false,
  }) async {
    // ใช้ getActiveMedicines ซึ่งใช้ cache แล้ว
    return getActiveMedicines(residentId, forceRefresh: forceRefresh);
  }

  /// ดึงรายการยาพร้อมรูปภาพ แบ่งตามมื้อ
  /// ใช้ filter ตามวันที่และความถี่การกินยา (typeOfTime, everyHr, daysOfWeek)
  /// [forceRefresh] = true จะบังคับ fetch ข้อมูลยาใหม่จาก API
  Future<List<MealPhotoGroup>> getMedicinePhotosByMeal(
    int residentId,
    DateTime date, {
    bool? filterPrn, // กรองยาตามอาการ (null = ไม่กรอง, false = ยาปกติ)
    bool forceRefresh = false,
  }) async {
    try {
      // ดึงยาพร้อมรูป (ใช้ cache ถ้าไม่ได้ forceRefresh)
      final medicines = await getMedicinePhotos(residentId, forceRefresh: forceRefresh);

      // ดึง logs ของวันที่กำหนด
      final logs = await getMedLogsForDate(residentId, date);

      // ดึง error logs (nurse mark) ของวันที่กำหนด
      final errorLogs = await getMedErrorLogsForDate(residentId, date);

      // สร้าง map ของ logs
      final logsMap = <String, MedLog>{};
      for (final log in logs) {
        logsMap[log.meal] = log;
      }

      // จัดกลุ่มตาม meal slot
      final result = <MealPhotoGroup>[];

      for (final slot in mealSlots) {
        final beforeAfter = slot['beforeAfter']!;
        final bldb = slot['bldb']!;
        final mealKey = slot['mealKey']!;
        final label = slot['label']!;

        // กรองยาที่ตรงกับมื้อนี้และวันที่เลือก
        // ใช้ MedicineSummary.filterByDate แทน matchesMeal
        final medicinesInMeal = MedicineSummary.filterByDate(
          medicines: medicines,
          selectedDate: date,
          beforeAfter: beforeAfter.isEmpty ? null : beforeAfter,
          bldb: bldb,
          prn: filterPrn,
        );

        // หา nurse mark สำหรับมื้อนี้
        // A_Med_error_log meal format: "${beforeAfter}${bldb}" เช่น "ก่อนอาหารเช้า", "หลังอาหารกลางวัน"
        // Database เก็บแบบมี "อาหาร" อยู่ เช่น "ก่อนอาหารเช้า" ไม่ใช่ "ก่อนเช้า"
        final errorLogMealKey = beforeAfter.isEmpty ? bldb : '$beforeAfter$bldb';

        NurseMarkStatus nurseMark2C = NurseMarkStatus.none;
        NurseMarkStatus nurseMark3C = NurseMarkStatus.none;
        String? reviewer2CName;
        String? reviewer3CName;

        for (final errorLog in errorLogs) {
          if (errorLog.meal == errorLogMealKey) {
            if (errorLog.field2CPicture == true && errorLog.replyNurseMark != null) {
              nurseMark2C = NurseMarkStatusExtension.fromString(errorLog.replyNurseMark);
              reviewer2CName = errorLog.reviewerDisplayName;
            }
            if (errorLog.field3CPicture == true && errorLog.replyNurseMark != null) {
              nurseMark3C = NurseMarkStatusExtension.fromString(errorLog.replyNurseMark);
              reviewer3CName = errorLog.reviewerDisplayName;
            }
          }
        }

        result.add(MealPhotoGroup(
          mealKey: mealKey,
          label: label,
          medicines: medicinesInMeal,
          medLog: logsMap[mealKey],
          nurseMark2C: nurseMark2C,
          nurseMark3C: nurseMark3C,
          reviewer2CName: reviewer2CName,
          reviewer3CName: reviewer3CName,
        ));
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  /// นับจำนวนยาที่มีรูป
  Future<int> getMedicinePhotoCount(int residentId) async {
    try {
      final medicines = await getMedicinePhotos(residentId);
      return medicines.where((m) => m.hasPhoto2C || m.hasPhoto3C).length;
    } catch (e) {
      return 0;
    }
  }
}

// Type alias for backwards compatibility
typedef MedicinePhoto = MedicineSummary;

/// Model สำหรับสถานะการให้ยาแต่ละมื้อ
class MealStatus {
  final String mealKey;
  final String label;
  final int medicineCount;
  final bool hasPhoto;
  final MedLog? log;

  MealStatus({
    required this.mealKey,
    required this.label,
    required this.medicineCount,
    required this.hasPhoto,
    this.log,
  });

  /// ไม่มียาในมื้อนี้
  bool get isEmpty => medicineCount == 0;

  /// มียาแต่ยังไม่ได้ให้
  bool get isPending => medicineCount > 0 && !hasPhoto;

  /// ให้ยาแล้ว
  bool get isCompleted => medicineCount > 0 && hasPhoto;
}

/// Model สำหรับสรุปสถานะการจัดยาของผู้พัก (ใช้ในหน้า residents list)
class ResidentMedSummary {
  final int residentId;
  final int totalMealsWithMedicine; // จำนวนมื้อที่มียา
  final int completedMeals; // จำนวนมื้อที่จัดยาแล้ว (มีรูป 2C)
  final String completionFraction; // เช่น "2/5"
  final String completionStatus; // 'completed', 'partial', 'not_started', 'no_medication'

  ResidentMedSummary({
    required this.residentId,
    required this.totalMealsWithMedicine,
    required this.completedMeals,
    required this.completionFraction,
    required this.completionStatus,
  });

  bool get isCompleted => completionStatus == 'completed';
  bool get isPartial => completionStatus == 'partial';
  bool get isNotStarted => completionStatus == 'not_started';
  bool get hasNoMedication => completionStatus == 'no_medication';
}

/// Extension สำหรับดึงสถานะการจัดยาของ residents หลายคน
extension MedicineServiceResidentStatus on MedicineService {
  /// ดึงสถานะการจัดยาของ resident คนเดียว
  /// นับเฉพาะมื้อที่มียาจริงๆ (ไม่ hardcode 7 มื้อ)
  Future<ResidentMedSummary?> getMedCompletionStatusForResident(
    int residentId,
    DateTime date,
  ) async {
    try {
      // ใช้ getMedicinePhotosByMeal ซึ่งมี logic filter ถูกต้อง
      final mealGroups = await getMedicinePhotosByMeal(
        residentId,
        date,
        filterPrn: false, // เฉพาะยาปกติ (ไม่รวมยาตามอาการ)
      );

      // นับเฉพาะมื้อที่มียา
      final mealsWithMedicine = mealGroups.where((g) => g.medicines.isNotEmpty).toList();
      final totalMeals = mealsWithMedicine.length;

      if (totalMeals == 0) {
        return ResidentMedSummary(
          residentId: residentId,
          totalMealsWithMedicine: 0,
          completedMeals: 0,
          completionFraction: '0/0',
          completionStatus: 'no_medication',
        );
      }

      // นับมื้อที่จัดยาแล้ว (มีรูป 2C)
      final completedMeals = mealsWithMedicine.where((g) => g.isArranged).length;

      final String status;
      if (completedMeals == totalMeals) {
        status = 'completed';
      } else if (completedMeals > 0) {
        status = 'partial';
      } else {
        status = 'not_started';
      }

      return ResidentMedSummary(
        residentId: residentId,
        totalMealsWithMedicine: totalMeals,
        completedMeals: completedMeals,
        completionFraction: '$completedMeals/$totalMeals',
        completionStatus: status,
      );
    } catch (e) {
      return null;
    }
  }

  /// ดึงสถานะการจัดยาของ residents หลายคน
  /// Returns Map โดย key = residentId
  Future<Map<int, ResidentMedSummary>> getMedCompletionStatusForResidents(
    List<int> residentIds,
    DateTime date,
  ) async {
    final result = <int, ResidentMedSummary>{};

    // Process ทีละคน (อาจเพิ่ม parallel ในอนาคต)
    for (final residentId in residentIds) {
      final status = await getMedCompletionStatusForResident(residentId, date);
      if (status != null) {
        result[residentId] = status;
      }
    }

    return result;
  }
}

/// Service สำหรับดึงข้อมูล error logs (nurse mark)
extension MedicineServiceErrorLogs on MedicineService {
  /// ดึง error logs ของวันที่กำหนด
  /// ใช้สำหรับแสดง badge สถานะการตรวจสอบรูปยาโดยหัวหน้าเวร
  Future<List<MedErrorLog>> getMedErrorLogsForDate(
    int residentId,
    DateTime date,
  ) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Table name is A_Med_Error_Log (with underscores and capital letters)
      // Column name is CalendarDate (camelCase) in database
      // Join กับ user_info เพื่อดึงชื่อผู้ตรวจสอบ
      final response = await Supabase.instance.client
          .from('A_Med_Error_Log')
          .select('*, user_info:user_id(full_name, nickname)')
          .eq('resident_id', residentId)
          .eq('CalendarDate', dateStr);

      return (response as List)
          .map((json) => MedErrorLog.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

// ==========================================
// Extension สำหรับจัดการ med_DB (ฐานข้อมูลยา)
// ==========================================

extension MedicineServiceMedDB on MedicineService {
  /// Cache สำหรับ med_DB ทั้งหมดของ nursing home
  static List<MedDB>? _cachedMedDB;
  static int? _cachedNursinghomeId;
  static DateTime? _medDBCacheTime;
  static const _medDBCacheMaxAge = Duration(minutes: 10);

  /// ตรวจสอบว่า med_DB cache ยังใช้ได้อยู่
  bool _isMedDBCacheValid(int nursinghomeId) {
    if (_cachedNursinghomeId != nursinghomeId) return false;
    if (_cachedMedDB == null) return false;
    if (_medDBCacheTime == null) return false;
    return DateTime.now().difference(_medDBCacheTime!) < _medDBCacheMaxAge;
  }

  /// ล้าง med_DB cache
  void invalidateMedDBCache() {
    _cachedMedDB = null;
    _medDBCacheTime = null;
  }

  /// ดึงยาทั้งหมดจาก med_DB ของ nursing home
  /// ใช้ cache เพื่อ optimize การค้นหา
  Future<List<MedDB>> getAllMedicinesFromDB(int nursinghomeId, {bool forceRefresh = false}) async {
    debugPrint('[MedicineService] getAllMedicinesFromDB called with nursinghomeId: $nursinghomeId');

    // ใช้ cache ถ้ายังใช้ได้
    if (!forceRefresh && _isMedDBCacheValid(nursinghomeId)) {
      debugPrint('[MedicineService] Using cache: ${_cachedMedDB!.length} medicines');
      return _cachedMedDB!;
    }

    try {
      debugPrint('[MedicineService] Querying med_DB from Supabase...');
      final response = await _supabase
          .from('med_DB')
          .select()
          .eq('nursinghome_id', nursinghomeId)
          .order('brand_name', ascending: true);

      debugPrint('[MedicineService] Response received: ${(response as List).length} items');

      final medicines = (response)
          .map((json) => MedDB.fromJson(json))
          .toList();

      // Update cache
      _cachedNursinghomeId = nursinghomeId;
      _cachedMedDB = medicines;
      _medDBCacheTime = DateTime.now();

      debugPrint('[MedicineService] Cached ${medicines.length} medicines');
      return medicines;
    } catch (e) {
      debugPrint('[MedicineService] Error querying med_DB: $e');
      // Return cached data if available
      if (_cachedNursinghomeId == nursinghomeId && _cachedMedDB != null) {
        return _cachedMedDB!;
      }
      return [];
    }
  }

  /// ค้นหายาจาก med_DB (ค้นหา local จาก cache)
  /// [query] คำค้นหา - ค้นหาจาก brand_name, generic_name, group
  /// Returns รายการยาที่ match (สูงสุด 10 รายการ)
  Future<List<MedDB>> searchMedicinesFromDB(
    String query,
    int nursinghomeId, {
    int limit = 10,
  }) async {
    // โหลด cache ถ้ายังไม่มี
    final allMedicines = await getAllMedicinesFromDB(nursinghomeId);

    if (query.isEmpty) {
      return allMedicines.take(limit).toList();
    }

    final lowerQuery = query.toLowerCase();

    // Filter local จาก cache (เร็วกว่า query ทุกครั้ง)
    final filtered = allMedicines.where((m) {
      final brandMatch = m.brandName?.toLowerCase().contains(lowerQuery) ?? false;
      final genericMatch = m.genericName?.toLowerCase().contains(lowerQuery) ?? false;
      final groupMatch = m.group?.toLowerCase().contains(lowerQuery) ?? false;
      return brandMatch || genericMatch || groupMatch;
    }).take(limit).toList();

    return filtered;
  }

  /// ดึงยาจาก med_DB ตาม ID
  Future<MedDB?> getMedicineById(int medDbId) async {
    try {
      final response = await _supabase
          .from('med_DB')
          .select()
          .eq('id', medDbId)
          .single();

      return MedDB.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// เพิ่มยาใหม่ลง med_DB
  /// Returns ยาที่สร้างใหม่พร้อม ID
  Future<MedDB?> createMedicine({
    required int nursinghomeId,
    String? genericName,
    String? brandName,
    String? strength,
    String? route,
    String? unit,
    String? group,
    String? info,
    String? frontFoiledUrl,
    String? backFoiledUrl,
    String? frontNudeUrl,
    String? backNudeUrl,
    String? atcLevel1Code,
    String? atcLevel2Code,
    String? atcLevel3,
  }) async {
    try {
      // Note: column ใน med_DB ชื่อ atc_level1_id และ atc_level2_id แต่เก็บค่าเป็น text (FK ไปยัง med_atc_level1/2.code)
      final data = <String, dynamic>{
        'nursinghome_id': nursinghomeId,
        if (genericName != null && genericName.isNotEmpty) 'generic_name': genericName,
        if (brandName != null && brandName.isNotEmpty) 'brand_name': brandName,
        if (strength != null && strength.isNotEmpty) 'str': strength,
        if (route != null && route.isNotEmpty) 'route': route,
        if (unit != null && unit.isNotEmpty) 'unit': unit,
        if (group != null && group.isNotEmpty) 'group': group,
        if (info != null && info.isNotEmpty) 'info': info,
        if (frontFoiledUrl != null && frontFoiledUrl.isNotEmpty) 'Front-Foiled': frontFoiledUrl,
        if (backFoiledUrl != null && backFoiledUrl.isNotEmpty) 'Back-Foiled': backFoiledUrl,
        if (frontNudeUrl != null && frontNudeUrl.isNotEmpty) 'Front-Nude': frontNudeUrl,
        if (backNudeUrl != null && backNudeUrl.isNotEmpty) 'Back-Nude': backNudeUrl,
        if (atcLevel1Code != null && atcLevel1Code.isNotEmpty) 'atc_level1_id': atcLevel1Code,
        if (atcLevel2Code != null && atcLevel2Code.isNotEmpty) 'atc_level2_id': atcLevel2Code,
        if (atcLevel3 != null && atcLevel3.isNotEmpty) 'atc_level3': atcLevel3,
      };

      final response = await _supabase
          .from('med_DB')
          .insert(data)
          .select()
          .single();

      // Invalidate cache เพราะมียาใหม่
      invalidateMedDBCache();

      return MedDB.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// อัพเดตข้อมูลยาใน med_DB
  ///
  /// Note: image URLs ที่ null จะไม่ถูก update (ใช้รูปเดิม)
  /// ถ้าต้องการลบรูป ให้ส่ง empty string ''
  Future<MedDB?> updateMedicine({
    required int medDbId,
    String? genericName,
    String? brandName,
    String? strength,
    String? route,
    String? unit,
    String? group,
    String? info,
    String? frontFoiledUrl,
    String? backFoiledUrl,
    String? frontNudeUrl,
    String? backNudeUrl,
    String? atcLevel1Code,
    String? atcLevel2Code,
    String? atcLevel3,
  }) async {
    try {
      final data = <String, dynamic>{};

      // Text fields - update ถ้ามีค่า (empty string = ล้างค่า)
      if (genericName != null) {
        data['generic_name'] = genericName.isEmpty ? null : genericName;
      }
      if (brandName != null) {
        data['brand_name'] = brandName.isEmpty ? null : brandName;
      }
      if (strength != null) {
        data['str'] = strength.isEmpty ? null : strength;
      }
      if (route != null) {
        data['route'] = route.isEmpty ? null : route;
      }
      if (unit != null) {
        data['unit'] = unit.isEmpty ? null : unit;
      }
      if (group != null) {
        data['group'] = group.isEmpty ? null : group;
      }
      if (info != null) {
        data['info'] = info.isEmpty ? null : info;
      }

      // Image URLs - update ถ้ามีค่า (ไม่ใช่ null)
      if (frontFoiledUrl != null) {
        data['Front-Foiled'] = frontFoiledUrl.isEmpty ? null : frontFoiledUrl;
      }
      if (backFoiledUrl != null) {
        data['Back-Foiled'] = backFoiledUrl.isEmpty ? null : backFoiledUrl;
      }
      if (frontNudeUrl != null) {
        data['Front-Nude'] = frontNudeUrl.isEmpty ? null : frontNudeUrl;
      }
      if (backNudeUrl != null) {
        data['Back-Nude'] = backNudeUrl.isEmpty ? null : backNudeUrl;
      }

      // ATC Classification
      if (atcLevel1Code != null) {
        data['atc_level1_id'] = atcLevel1Code.isEmpty ? null : atcLevel1Code;
      }
      if (atcLevel2Code != null) {
        data['atc_level2_id'] = atcLevel2Code.isEmpty ? null : atcLevel2Code;
      }
      if (atcLevel3 != null) {
        data['atc_level3'] = atcLevel3.isEmpty ? null : atcLevel3;
      }

      if (data.isEmpty) {
        // ไม่มีอะไรต้อง update - return ข้อมูลเดิม
        return getMedicineById(medDbId);
      }

      final response = await _supabase
          .from('med_DB')
          .update(data)
          .eq('id', medDbId)
          .select()
          .single();

      // Invalidate cache เพราะข้อมูลยาเปลี่ยน
      invalidateMedDBCache();

      return MedDB.fromJson(response);
    } catch (e) {
      debugPrint('[MedicineService] updateMedicine error: $e');
      return null;
    }
  }

  /// สร้างซ้ำยา (duplicate) จาก med_DB ที่มีอยู่
  ///
  /// Logic:
  /// 1. Fetch ข้อมูลยาต้นฉบับ
  /// 2. สร้างยาใหม่โดย copy ข้อมูลทั้งหมด
  /// 3. เติม "(copy)" ต่อท้ายชื่อ (brandName ก่อน, ถ้าไม่มีใช้ genericName)
  Future<MedDB?> duplicateMedicine({
    required int sourceMedDbId,
    required int nursinghomeId,
  }) async {
    try {
      // 1. Fetch ยาต้นฉบับ
      final source = await getMedicineById(sourceMedDbId);
      if (source == null) {
        debugPrint('[MedicineService] duplicateMedicine: source not found');
        return null;
      }

      // 2. สร้างชื่อใหม่พร้อม "(copy)"
      // ถ้ามี brandName ให้เติมที่ brandName
      // ถ้าไม่มี brandName ให้เติมที่ genericName
      String? newBrandName = source.brandName;
      String? newGenericName = source.genericName;

      if (source.brandName != null && source.brandName!.isNotEmpty) {
        newBrandName = '${source.brandName} (copy)';
      } else if (source.genericName != null && source.genericName!.isNotEmpty) {
        newGenericName = '${source.genericName} (copy)';
      }

      // 3. สร้างยาใหม่โดย copy ข้อมูลทั้งหมด
      return createMedicine(
        nursinghomeId: nursinghomeId,
        genericName: newGenericName,
        brandName: newBrandName,
        strength: source.str,
        route: source.route,
        unit: source.unit,
        group: source.group,
        info: source.info,
        frontFoiledUrl: source.frontFoiled,
        backFoiledUrl: source.backFoiled,
        frontNudeUrl: source.frontNude,
        backNudeUrl: source.backNude,
        atcLevel1Code: source.atcLevel1Id,
        atcLevel2Code: source.atcLevel2Id,
        atcLevel3: source.atcLevel3,
      );
    } catch (e) {
      debugPrint('[MedicineService] duplicateMedicine error: $e');
      return null;
    }
  }

  /// Upload รูปยาขึ้น Supabase Storage
  /// [file] ไฟล์รูปที่ต้องการ upload (dart:io File)
  /// [imageType] ประเภทรูป: 'frontFoiled', 'backFoiled', 'frontNude', 'backNude'
  /// Returns URL ของรูปที่ upload หรือ null ถ้า error
  Future<String?> uploadMedicineImage(
    dynamic file,
    String imageType,
  ) async {
    try {
      debugPrint('[MedicineService] uploadMedicineImage: $imageType');

      // สร้างชื่อไฟล์ unique โดยใช้ timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'medicine_${imageType}_$timestamp.jpg';
      final filePath = 'medicine_images/$fileName';

      // อ่าน bytes จาก file (file ต้องมี method readAsBytes)
      final bytes = await file.readAsBytes();
      debugPrint('[MedicineService] File bytes read: ${bytes.length} bytes');

      // Upload file ไป Supabase Storage (bucket: 'nursingcare')
      await _supabase.storage
          .from('nursingcare')
          .uploadBinary(filePath, bytes, fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ));
      debugPrint('[MedicineService] Upload successful');

      // สร้าง public URL
      final url = _supabase.storage
          .from('nursingcare')
          .getPublicUrl(filePath);

      debugPrint('[MedicineService] Public URL: $url');
      return url;
    } catch (e, st) {
      debugPrint('[MedicineService] uploadMedicineImage error: $e');
      debugPrint('[MedicineService] Stack trace: $st');
      return null;
    }
  }
}

// ==========================================
// Extension สำหรับจัดการ ATC Classification
// ==========================================

extension MedicineServiceATC on MedicineService {
  /// Cache สำหรับ ATC levels
  static List<MedAtcLevel1>? _cachedAtcLevel1;
  static List<MedAtcLevel2>? _cachedAtcLevel2;

  /// ดึง ATC Level 1 ทั้งหมด (14 หมวดหลัก)
  Future<List<MedAtcLevel1>> getAtcLevel1List() async {
    // ใช้ cache ถ้ามี
    if (_cachedAtcLevel1 != null) {
      return _cachedAtcLevel1!;
    }

    try {
      final response = await _supabase
          .from('med_atc_level1')
          .select()
          .order('code', ascending: true);

      _cachedAtcLevel1 = (response as List)
          .map((json) => MedAtcLevel1.fromJson(json))
          .toList();

      return _cachedAtcLevel1!;
    } catch (e) {
      return [];
    }
  }

  /// ดึง ATC Level 2 ทั้งหมด
  Future<List<MedAtcLevel2>> getAtcLevel2List() async {
    // ใช้ cache ถ้ามี
    if (_cachedAtcLevel2 != null) {
      return _cachedAtcLevel2!;
    }

    try {
      final response = await _supabase
          .from('med_atc_level2')
          .select()
          .order('code', ascending: true);

      _cachedAtcLevel2 = (response as List)
          .map((json) => MedAtcLevel2.fromJson(json))
          .toList();

      return _cachedAtcLevel2!;
    } catch (e) {
      return [];
    }
  }

  /// ดึง ATC Level 2 ตาม Level 1 code
  /// เช่น ถ้าเลือก Level 1 = "A" จะได้ Level 2 ที่ขึ้นต้นด้วย "A" เช่น "A01", "A02"
  Future<List<MedAtcLevel2>> getAtcLevel2ByLevel1(String level1Code) async {
    final allLevel2 = await getAtcLevel2List();
    return allLevel2.where((l2) => l2.level1Code == level1Code).toList();
  }
}

// ==========================================
// Extension สำหรับจัดการ medicine_list (ยาของ resident)
// ==========================================

extension MedicineServiceMedicineList on MedicineService {
  /// เพิ่มยาให้ resident
  /// 1. Insert ไปที่ medicine_list
  /// 2. Insert ไปที่ med_history
  /// Returns MedicineListItem ที่สร้างใหม่
  Future<MedicineListItem?> addMedicineToResident({
    required int medDbId,
    required int residentId,
    required double takeTab,
    required List<String> bldb,
    required List<String> beforeAfter,
    int? everyHr,
    String? typeOfTime,
    List<String>? daysOfWeek,
    bool prn = false,
    List<String>? underlyingDiseaseTag,
    // med_history fields
    required DateTime onDate,
    DateTime? offDate,
    String? note,
    String? userId,
    double? reconcile,
  }) async {
    try {
      // 1. Insert medicine_list
      final medicineData = <String, dynamic>{
        'med_DB_id': medDbId,
        'resident_id': residentId,
        'take_tab': takeTab,
        'BLDB': bldb,
        'BeforeAfter': beforeAfter,
        if (everyHr != null) 'every_hr': everyHr,
        if (typeOfTime != null) 'typeOfTime': typeOfTime,
        if (daysOfWeek != null && daysOfWeek.isNotEmpty) 'DaysOfWeek': daysOfWeek,
        'prn': prn,
        if (underlyingDiseaseTag != null && underlyingDiseaseTag.isNotEmpty)
          'underlying_disease_tag': underlyingDiseaseTag,
      };

      final medicineResponse = await _supabase
          .from('medicine_List')
          .insert(medicineData)
          .select()
          .single();

      final newMedicine = MedicineListItem.fromJson(medicineResponse);

      // 2. Insert med_history
      final historyData = <String, dynamic>{
        'med_list_id': newMedicine.id,
        'on_date': _formatDate(onDate),
        if (offDate != null) 'off_date': _formatDate(offDate),
        if (note != null && note.isNotEmpty) 'note': note,
        if (userId != null) 'user_id': userId,
        if (reconcile != null) 'reconcile': reconcile,
      };

      await _supabase.from('med_history').insert(historyData);

      // Invalidate medicines cache เพราะมียาใหม่
      invalidateCache();

      return newMedicine;
    } catch (e) {
      return null;
    }
  }

  /// Helper: Format DateTime เป็น YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// ดึงยาของ resident ตาม medicine_list ID
  Future<MedicineListItem?> getMedicineListItemById(int medicineListId) async {
    try {
      final response = await _supabase
          .from('medicine_List')
          .select()
          .eq('id', medicineListId)
          .single();

      return MedicineListItem.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// ดึงประวัติการใช้ยา (med_history) ของ medicine_list
  Future<List<MedHistory>> getMedHistoryByMedicineListId(int medicineListId) async {
    try {
      final response = await _supabase
          .from('med_history')
          .select()
          .eq('med_list_id', medicineListId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => MedHistory.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// อัพเดต med_history (เช่น เพิ่ม reconcile, เปลี่ยน off_date)
  Future<bool> updateMedHistory({
    required int historyId,
    DateTime? offDate,
    String? note,
    double? reconcile,
    String? newSetting,
  }) async {
    try {
      final data = <String, dynamic>{
        if (offDate != null) 'off_date': _formatDate(offDate),
        if (note != null) 'note': note,
        if (reconcile != null) 'reconcile': reconcile,
        if (newSetting != null) 'new_setting': newSetting,
      };

      if (data.isEmpty) return true;

      await _supabase
          .from('med_history')
          .update(data)
          .eq('id', historyId);

      // Invalidate cache
      invalidateCache();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// อัพเดตข้อมูลยาของ resident ใน medicine_list พร้อมบันทึก history
  ///
  /// Logic:
  /// 1. Update medicine_list ด้วย setting ใหม่
  /// 2. Insert med_history record ใหม่พร้อม new_setting string
  ///
  /// [newSetting] - string สรุปการตั้งค่าใหม่ เช่น "1 เม็ด | เช้า,กลางวัน,เย็น | หลังอาหาร"
  Future<bool> updateMedicineListItem({
    required int medicineListId,
    required double takeTab,
    required List<String> bldb,
    required List<String> beforeAfter,
    int? everyHr,
    String? typeOfTime,
    List<String>? daysOfWeek,
    bool prn = false,
    List<String>? underlyingDiseaseTag,
    // med_history fields
    required DateTime onDate,
    DateTime? offDate,
    required String note,
    required String userId,
    double? reconcile,
    String? newSetting,
  }) async {
    try {
      // 1. Update medicine_list
      final medicineData = <String, dynamic>{
        'take_tab': takeTab,
        'BLDB': bldb,
        'BeforeAfter': beforeAfter,
        'prn': prn,
      };

      // Optional fields - ใช้ค่าใหม่ถ้ามี
      if (everyHr != null) {
        medicineData['every_hr'] = everyHr;
      }
      if (typeOfTime != null) {
        medicineData['typeOfTime'] = typeOfTime;
      }
      if (daysOfWeek != null) {
        medicineData['DaysOfWeek'] = daysOfWeek;
      }
      if (underlyingDiseaseTag != null) {
        medicineData['underlying_disease_tag'] = underlyingDiseaseTag;
      }

      await _supabase
          .from('medicine_List')
          .update(medicineData)
          .eq('id', medicineListId);

      // 2. Insert med_history record ใหม่ (บันทึกการเปลี่ยนแปลง)
      final historyData = <String, dynamic>{
        'med_list_id': medicineListId,
        'on_date': _formatDate(onDate),
        'note': note,
        'user_id': userId,
      };

      if (offDate != null) {
        historyData['off_date'] = _formatDate(offDate);
      }
      if (reconcile != null) {
        historyData['reconcile'] = reconcile;
      }
      if (newSetting != null && newSetting.isNotEmpty) {
        historyData['new_setting'] = newSetting;
      }

      await _supabase.from('med_history').insert(historyData);

      // Invalidate cache เพราะข้อมูลยาเปลี่ยน
      invalidateCache();

      return true;
    } catch (e) {
      debugPrint('[MedicineService] updateMedicineListItem error: $e');
      return false;
    }
  }
}
