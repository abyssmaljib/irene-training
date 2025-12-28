import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicine_summary.dart';
import '../models/med_log.dart';
import '../models/meal_photo_group.dart';

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
    debugPrint('MedicineService: cache invalidated');
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
      debugPrint('getMedicinesByResident: using cached data (${_cachedMedicines!.length} medicines)');
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

      debugPrint('getMedicinesByResident: fetched ${medicines.length} medicines (cache updated)');
      return medicines;
    } catch (e) {
      debugPrint('getMedicinesByResident error: $e');
      // Return cached data if available even on error
      if (_cachedResidentId == residentId && _cachedMedicines != null) {
        debugPrint('getMedicinesByResident: returning stale cache on error');
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
    final activeMedicines = allMedicines.where((m) => m.isActive).toList();
    debugPrint('getActiveMedicines: ${activeMedicines.length} active out of ${allMedicines.length}');
    return activeMedicines;
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
            user_2c:2C_completed_by(nickname),
            user_3c:3C_Compleated_by(nickname)
          ''')
          .eq('resident_id', residentId)
          .eq('Created_Date', dateStr);

      stopwatch.stop();
      debugPrint('getMedLogsForDate: got ${(response as List).length} logs for $dateStr in ${stopwatch.elapsedMilliseconds}ms');

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
        };
        return MedLog.fromJson(mapped);
      }).toList();
    } catch (e) {
      debugPrint('getMedLogsForDate error: $e');
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
      debugPrint('getMealStatusForDate: ${medicines.length} active medicines');

      // ดึง logs ของวันนี้
      final logs = await getMedLogsForDate(residentId, date);
      debugPrint('getMealStatusForDate: ${logs.length} logs for today');

      // สร้าง map ของ logs โดย key เป็น meal
      final logsMap = <String, MedLog>{};
      for (final log in logs) {
        logsMap[log.meal] = log;
        debugPrint('Log meal: "${log.meal}", has3C: ${log.hasPicture3C}');
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

        debugPrint('Slot "$mealKey": $count medicines (filtered by date), hasPhoto: $hasPhoto');

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
      debugPrint('getMealStatusForDate error: $e');
      return {};
    }
  }

  /// นับจำนวนยาที่ active
  Future<int> getActiveMedicineCount(int residentId) async {
    try {
      final medicines = await getActiveMedicines(residentId);
      return medicines.length;
    } catch (e) {
      debugPrint('getActiveMedicineCount error: $e');
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

        result.add(MealPhotoGroup(
          mealKey: mealKey,
          label: label,
          medicines: medicinesInMeal,
          medLog: logsMap[mealKey],
        ));
      }

      return result;
    } catch (e) {
      debugPrint('getMedicinePhotosByMeal error: $e');
      return [];
    }
  }

  /// นับจำนวนยาที่มีรูป
  Future<int> getMedicinePhotoCount(int residentId) async {
    try {
      final medicines = await getMedicinePhotos(residentId);
      return medicines.where((m) => m.hasPhoto2C || m.hasPhoto3C).length;
    } catch (e) {
      debugPrint('getMedicinePhotoCount error: $e');
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
