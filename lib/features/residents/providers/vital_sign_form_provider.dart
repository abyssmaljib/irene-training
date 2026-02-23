import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/user_service.dart';
import '../../board/services/ai_helper_service.dart';
import '../models/vital_sign.dart';
import '../models/vital_sign_form_state.dart';
import '../services/vital_sign_service.dart';

/// Provider for VitalSignService
final vitalSignServiceProvider = Provider<VitalSignService>((ref) {
  return VitalSignService();
});

/// Provider for Vital Sign form state
/// ใช้ autoDispose เพื่อ reset state เมื่อออกจากหน้า create
final vitalSignFormProvider = StateNotifierProvider.family.autoDispose<
    VitalSignFormNotifier,
    AsyncValue<VitalSignFormState>,
    int>((ref, residentId) {
  return VitalSignFormNotifier(ref, residentId);
});

/// Parameter type for edit provider
typedef EditVitalSignParams = ({int residentId, int vitalSignId});

/// Provider for Edit Vital Sign form state
final editVitalSignFormProvider = StateNotifierProvider.family.autoDispose<
    EditVitalSignFormNotifier,
    AsyncValue<VitalSignFormState>,
    EditVitalSignParams>((ref, params) {
  return EditVitalSignFormNotifier(ref, params.residentId, params.vitalSignId);
});

class VitalSignFormNotifier
    extends StateNotifier<AsyncValue<VitalSignFormState>> {
  VitalSignFormNotifier(Ref ref, this.residentId)
      : super(const AsyncValue.loading()) {
    _initialize();
  }

  final int residentId;
  final _service = VitalSignService();

  // Cache for constipation calculation
  double? _lastConstipation;
  int? _reportAmount;

  /// Initialize form with default values and loaded data
  Future<void> _initialize() async {
    try {
      // Detect shift ก่อน (ใช้แค่เวลา ไม่ต้อง query)
      final now = DateTime.now();
      final shift = _detectShift(now);

      // ยิง 4 queries พร้อมกัน — ไม่มีตัวไหนพึ่งกัน
      final results = await Future.wait([
        _service.getLastVitalSign(residentId),       // [0] last vital
        _service.getResidentReportAmount(residentId), // [1] report amount
        _service.getReportTemplates(residentId),      // [2] templates
        _service.getReportSubjects(residentId, shift), // [3] subjects + choices
      ]);

      final lastVital = results[0] as VitalSign?;
      _lastConstipation = lastVital?.constipation;
      _reportAmount = results[1] as int;
      final templates = results[2] as Map<String, String>?;
      final subjectRows = results[3] as List<Map<String, dynamic>>;
      final ratings = <int, RatingData>{};
      for (final row in subjectRows) {
        final relationId = row['id'] as int;
        final choicesList = row['choices'] as List<dynamic>?;
        final choices = choicesList?.map((e) => e.toString()).toList();
        ratings[relationId] = RatingData(
          relationId: relationId,
          subjectId: row['subject_id'] as int,
          subjectName: row['report_subject'] as String,
          subjectDescription: row['subject_description'] as String?,
          choices: choices,
        );
      }

      // 6. Set initial state (defecation default = null, ยังไม่ได้เลือก)
      state = AsyncValue.data(VitalSignFormState(
        selectedDateTime: now,
        shift: shift,
        defecation: null, // ยังไม่ได้เลือก - user ต้องเลือกเอง
        constipation: null, // ยังไม่คำนวณจนกว่า user จะเลือก defecation
        ratings: ratings,
        reportD: templates?['templateD'] ?? '',
        reportN: templates?['templateN'] ?? '',
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  String _detectShift(DateTime dt) {
    // AM (00:00-11:59) = เวรดึก, PM (12:00-23:59) = เวรเช้า
    return dt.hour < 12 ? 'เวรดึก' : 'เวรเช้า';
  }

  // ==========================================
  // Field Update Methods
  // ==========================================

  Future<void> setIsFullReport(bool isFullReport) async {
    final currentData = state.value;
    if (currentData == null) return;

    if (isFullReport) {
      // Load ratings when switching to full report
      final subjectRows = await _service.getReportSubjects(residentId, currentData.shift);
      final ratings = <int, RatingData>{};
      for (final row in subjectRows) {
        final relationId = row['id'] as int;
        final choicesList = row['choices'] as List<dynamic>?;
        final choices = choicesList?.map((e) => e.toString()).toList();
        ratings[relationId] = RatingData(
          relationId: relationId,
          subjectId: row['subject_id'] as int,
          subjectName: row['report_subject'] as String,
          subjectDescription: row['subject_description'] as String?,
          choices: choices,
        );
      }

      state = AsyncValue.data(currentData.copyWith(
        isFullReport: isFullReport,
        ratings: ratings,
      ));
    } else {
      // Clear ratings when switching to abbreviated report
      state = AsyncValue.data(currentData.copyWith(
        isFullReport: isFullReport,
        ratings: {},
      ));
    }
  }

  void setDateTime(DateTime dateTime) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(selectedDateTime: dateTime));
    });
  }

  Future<void> setShift(String shift) async {
    final currentData = state.value;
    if (currentData == null) return;

    // Reload ratings when shift changes
    final subjectRows = await _service.getReportSubjects(residentId, shift);
    final ratings = <int, RatingData>{};
    for (final row in subjectRows) {
      final relationId = row['id'] as int;
      final choicesList = row['choices'] as List<dynamic>?;
      final choices = choicesList?.map((e) => e.toString()).toList();
      ratings[relationId] = RatingData(
        relationId: relationId,
        subjectId: row['subject_id'] as int,
        subjectName: row['report_subject'] as String,
        subjectDescription: row['subject_description'] as String?,
        choices: choices,
      );
    }

    state = AsyncValue.data(currentData.copyWith(
      shift: shift,
      ratings: ratings,
    ));
  }

  void setTemp(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(temp: value));
    });
  }

  void setRR(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(rr: value));
    });
  }

  void setO2(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(o2: value));
    });
  }

  void setSBP(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(sBP: value));
    });
  }

  void setDBP(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(dBP: value));
    });
  }

  void setPR(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(pr: value));
    });
  }

  void setDTX(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(dtx: value));
    });
  }

  void setInsulin(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(insulin: value));
    });
  }

  void setInput(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(input: value));
    });
  }

  void setOutput(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(output: value));
    });
  }

  void setNapkin(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(napkin: value));
    });
  }

  void setDefecation(bool? value) {
    state.whenData((data) {
      String? newConstipation;

      if (value == null) {
        // ยังไม่ได้เลือก
        newConstipation = null;
      } else if (value) {
        // Defecated -> reset to '0'
        newConstipation = '0';
      } else {
        // Not defecated -> calculate from last vital
        final lastConst = _lastConstipation ?? 0.0;
        final reportAmt = _reportAmount ?? 2;
        final calculated = lastConst + (1 / reportAmt);
        newConstipation = calculated.toStringAsFixed(2);
      }

      state = AsyncValue.data(data.copyWith(
        defecation: value,
        constipation: newConstipation,
      ));
    });
  }

  void setConstipation(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(constipation: value));
    });
  }

  void setRating(int relationId, int rating) {
    state.whenData((data) {
      final updatedRatings = Map<int, RatingData>.from(data.ratings);
      final current = updatedRatings[relationId];
      if (current != null) {
        updatedRatings[relationId] = current.copyWith(rating: rating);
      }
      state = AsyncValue.data(data.copyWith(ratings: updatedRatings));
    });
  }

  void setRatingDescription(int relationId, String description) {
    state.whenData((data) {
      final updatedRatings = Map<int, RatingData>.from(data.ratings);
      final current = updatedRatings[relationId];
      if (current != null) {
        updatedRatings[relationId] = current.copyWith(description: description);
      }
      state = AsyncValue.data(data.copyWith(ratings: updatedRatings));
    });
  }

  void setReportD(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(reportD: value));
    });
  }

  void setReportN(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(reportN: value));
    });
  }

  // ==========================================
  // AI Shift Summary
  // ==========================================

  /// สร้างสรุปเวรโดย AI แล้ว auto-fill ลงช่อง reportD/reportN
  /// เรียก Edge Function ที่ query ข้อมูลทุกตารางแล้วส่ง Gemini สรุป
  /// รวมข้อมูลจากฟอร์มปัจจุบัน (vital signs, ratings) ที่ยังไม่ได้ save ด้วย
  Future<void> generateAIShiftSummary({
    required String residentName,
    required int nursinghomeId,
  }) async {
    final currentData = state.value;
    if (currentData == null) return;

    // เปิด loading state
    state = AsyncValue.data(currentData.copyWith(isLoadingAI: true));

    final aiService = AiHelperService();
    try {
      // แปลง DateTime เป็น 'YYYY-MM-DD'
      final date = currentData.selectedDateTime;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // รวบรวมข้อมูลที่ user กรอกในฟอร์ม (ยังไม่ save) เพื่อส่งให้ AI รวมในสรุป
      final formData = _buildCurrentFormData(currentData);

      final result = await aiService.generateShiftSummary(
        residentId: residentId,
        residentName: residentName,
        date: dateStr,
        shift: currentData.shift,
        nursinghomeId: nursinghomeId,
        currentFormData: formData,
      );

      // อ่าน state ล่าสุดอีกครั้ง (อาจเปลี่ยนระหว่างรอ)
      final latestData = state.value;
      if (latestData == null) return;

      if (result != null && result.isNotEmpty) {
        // Auto-fill ลงช่อง report ตามเวร
        if (latestData.shift == 'เวรเช้า') {
          state = AsyncValue.data(latestData.copyWith(
            reportD: result,
            isLoadingAI: false,
          ));
        } else {
          state = AsyncValue.data(latestData.copyWith(
            reportN: result,
            isLoadingAI: false,
          ));
        }
      } else {
        state = AsyncValue.data(latestData.copyWith(isLoadingAI: false));
      }
    } catch (e) {
      final latestData = state.value;
      if (latestData != null) {
        state = AsyncValue.data(latestData.copyWith(isLoadingAI: false));
      }
    } finally {
      aiService.dispose();
    }
  }

  /// รวบรวมข้อมูลจากฟอร์มปัจจุบัน (ยังไม่ save) เพื่อส่งให้ Edge Function
  /// รวมเข้ากับข้อมูลจาก DB แล้วให้ AI สรุปรวมกัน
  Map<String, dynamic> _buildCurrentFormData(VitalSignFormState data) {
    final Map<String, dynamic> formData = {};

    // --- Vital Signs ที่ user กรอกในฟอร์ม ---
    final Map<String, dynamic> vitalSigns = {};
    if (data.sBP != null && data.sBP!.isNotEmpty) vitalSigns['sBP'] = data.sBP;
    if (data.dBP != null && data.dBP!.isNotEmpty) vitalSigns['dBP'] = data.dBP;
    if (data.pr != null && data.pr!.isNotEmpty) vitalSigns['PR'] = data.pr;
    if (data.rr != null && data.rr!.isNotEmpty) vitalSigns['RR'] = data.rr;
    if (data.temp != null && data.temp!.isNotEmpty) {
      vitalSigns['Temp'] = data.temp;
    }
    if (data.o2 != null && data.o2!.isNotEmpty) vitalSigns['O2'] = data.o2;
    if (data.dtx != null && data.dtx!.isNotEmpty) vitalSigns['DTX'] = data.dtx;
    if (data.insulin != null && data.insulin!.isNotEmpty) {
      vitalSigns['Insulin'] = data.insulin;
    }
    if (data.input != null && data.input!.isNotEmpty) {
      vitalSigns['Input'] = data.input;
    }
    if (data.output != null && data.output!.isNotEmpty) {
      vitalSigns['Output'] = data.output;
    }
    if (data.napkin != null && data.napkin!.isNotEmpty) {
      vitalSigns['napkin'] = data.napkin;
    }
    if (data.defecation != null) {
      vitalSigns['defecation'] = data.defecation! ? 'ถ่ายแล้ว' : 'ยังไม่ถ่าย';
    }
    if (data.constipation != null && data.constipation!.isNotEmpty) {
      vitalSigns['constipation'] = data.constipation;
    }
    if (vitalSigns.isNotEmpty) formData['vital_signs'] = vitalSigns;

    // --- Ratings (Scale ประเมินสุขภาพ) ---
    // ส่งเฉพาะที่ user กรอกแล้ว (rating != null)
    final List<Map<String, dynamic>> ratingsList = [];
    for (final entry in data.ratings.entries) {
      final r = entry.value;
      if (r.rating != null && r.rating! > 0) {
        ratingsList.add({
          'subject': r.subjectName,
          'rating': r.rating,
          // ข้อความ choice เช่น "ดี", "ปานกลาง" ถ้ามี
          if (r.selectedChoiceText != null) 'choice': r.selectedChoiceText,
          if (r.description != null && r.description!.isNotEmpty)
            'note': r.description,
        });
      }
    }
    if (ratingsList.isNotEmpty) formData['ratings'] = ratingsList;

    // --- บันทึกที่ NA เขียนไว้แล้วในช่องรายงาน ---
    // ส่งเนื้อหาที่ NA พิมพ์ไว้ (เช่น "วันนี้อารมณ์ดี ยิ้มแย้ม...") ให้ AI เอาไปรวมในสรุป
    // ใช้ key 'report_template' เพื่อ backward compat กับ Edge Function
    final report = data.shift == 'เวรเช้า' ? data.reportD : data.reportN;
    if (report != null && report.trim().isNotEmpty) {
      formData['report_template'] = report;
    }

    return formData;
  }

  // ==========================================
  // Validation
  // ==========================================

  /// ตรวจสอบว่ามี vital sign อย่างน้อย 1 ค่าหรือไม่
  bool _hasAnyVitalSign() {
    final currentState = state.value;
    if (currentState == null) return false;

    return (currentState.temp != null && currentState.temp!.isNotEmpty) ||
        (currentState.rr != null && currentState.rr!.isNotEmpty) ||
        (currentState.o2 != null && currentState.o2!.isNotEmpty) ||
        (currentState.sBP != null && currentState.sBP!.isNotEmpty) ||
        (currentState.dBP != null && currentState.dBP!.isNotEmpty) ||
        (currentState.pr != null && currentState.pr!.isNotEmpty);
  }

  /// Validate form ก่อนแสดง Preview
  /// Return error message ถ้ามี, null ถ้า valid
  String? validateForPreview() {
    final currentState = state.value;
    if (currentState == null) return 'ไม่พบข้อมูล';

    // ต้องกรอกสัญญาณชีพอย่างน้อย 1 รายการ
    if (!_hasAnyVitalSign()) {
      return 'กรุณากรอกสัญญาณชีพอย่างน้อย 1 รายการ';
    }

    // Full Report: ต้องเลือกสถานะการขับถ่าย
    if (currentState.isFullReport && currentState.defecation == null) {
      return 'กรุณาเลือกสถานะการขับถ่าย';
    }

    // Full Report: ต้องให้คะแนนครบทุกหัวข้อ
    if (currentState.isFullReport && !currentState.allRatingsComplete) {
      final incompleteCount = currentState.ratings.values
          .where((r) => !r.isComplete)
          .length;
      return 'กรุณาให้คะแนนครบทุกหัวข้อ (เหลืออีก $incompleteCount หัวข้อ)';
    }

    return null; // Valid
  }

  // ==========================================
  // Submit
  // ==========================================

  Future<bool> submit() async {
    final currentState = state.value;
    if (currentState == null) return false;

    // Validate: At least one vital sign must be filled
    final hasAnyVitalSign = currentState.temp != null && currentState.temp!.isNotEmpty ||
        currentState.rr != null && currentState.rr!.isNotEmpty ||
        currentState.o2 != null && currentState.o2!.isNotEmpty ||
        currentState.sBP != null && currentState.sBP!.isNotEmpty ||
        currentState.dBP != null && currentState.dBP!.isNotEmpty ||
        currentState.pr != null && currentState.pr!.isNotEmpty;

    if (!hasAnyVitalSign) {
      state = AsyncValue.data(
        currentState.copyWith(
          errorMessage: 'กรุณากรอกสัญญาณชีพอย่างน้อย 1 รายการ',
        ),
      );
      return false;
    }

    // Validate defecation - ต้องเลือกสถานะการขับถ่าย (Full Report only)
    if (currentState.isFullReport && currentState.defecation == null) {
      state = AsyncValue.data(
        currentState.copyWith(
          errorMessage: 'กรุณาเลือกสถานะการขับถ่าย (ถ่ายแล้ว/ยังไม่ถ่าย)',
        ),
      );
      return false;
    }

    // Validate ratings for full report
    if (currentState.isFullReport) {
      // Check if all ratings are complete
      final incompleteRatings = currentState.ratings.values
          .where((r) => !r.isComplete)
          .toList();

      if (incompleteRatings.isNotEmpty) {
        state = AsyncValue.data(
          currentState.copyWith(
            errorMessage: 'กรุณาให้คะแนนครบทุกหัวข้อ (เหลืออีก ${incompleteRatings.length} หัวข้อ)',
          ),
        );
        return false;
      }
    }

    state = AsyncValue.data(currentState.copyWith(isLoading: true, errorMessage: null));

    try {
      // Get current user info (รองรับ impersonation)
      final userId = UserService().effectiveUserId ?? '';
      final nursinghomeId = await UserService().getNursinghomeId() ?? 1;

      await _service.createVitalSign(
        residentId: residentId,
        nursinghomeId: nursinghomeId,
        userId: userId,
        formState: currentState,
      );

      state = AsyncValue.data(
        currentState.copyWith(
          isLoading: false,
          errorMessage: null,
        ),
      );

      return true;
    } catch (e) {
      state = AsyncValue.data(
        currentState.copyWith(
          isLoading: false,
          errorMessage: 'เกิดข้อผิดพลาด: ${e.toString()}',
        ),
      );
      return false;
    }
  }
}

/// Notifier for Edit Vital Sign form
class EditVitalSignFormNotifier
    extends StateNotifier<AsyncValue<VitalSignFormState>> {
  EditVitalSignFormNotifier(Ref ref, this.residentId, this.vitalSignId)
      : super(const AsyncValue.loading()) {
    _initialize();
  }

  final int residentId;
  final int vitalSignId;
  final _service = VitalSignService();

  // Cache for constipation calculation
  double? _lastConstipation;
  int? _reportAmount;

  /// Initialize form with existing vital sign data
  Future<void> _initialize() async {
    try {
      // Step 1: ต้องดึง vital sign ก่อน เพราะต้องรู้ shift ก่อนถึงจะ query subjects ได้
      final data = await _service.getVitalSignWithRatings(vitalSignId);
      if (data == null) {
        state = AsyncValue.error('ไม่พบข้อมูล Vital Sign', StackTrace.current);
        return;
      }

      final vitalSign = data['vitalSign'] as Map<String, dynamic>;
      final existingRatings = data['ratings'] as List<dynamic>;
      final shift = vitalSign['shift'] as String? ?? 'เวรเช้า';
      final isFullReport = vitalSign['isFullReport'] as bool? ?? true;

      // Step 2: ยิง 3 queries พร้อมกัน (ไม่พึ่งกัน แต่ต้องรู้ shift จาก step 1)
      final results = await Future.wait([
        _service.getLastVitalSign(residentId),        // [0] last vital
        _service.getResidentReportAmount(residentId),  // [1] report amount
        _service.getReportSubjects(residentId, shift), // [2] subjects + choices
      ]);

      final lastVital = results[0] as VitalSign?;
      _lastConstipation = lastVital?.constipation;
      _reportAmount = results[1] as int;
      final subjectRows = results[2] as List<Map<String, dynamic>>;
      final ratings = <int, RatingData>{};

      for (final row in subjectRows) {
        final relationId = row['id'] as int;
        final subjectId = row['subject_id'] as int;
        final choicesList = row['choices'] as List<dynamic>?;
        final choices = choicesList?.map((e) => e.toString()).toList();

        // Find existing rating for this relation
        Map<String, dynamic>? existingRating;
        for (final r in existingRatings) {
          if (r['Relation_id'] == relationId) {
            existingRating = r as Map<String, dynamic>;
            break;
          }
        }

        ratings[relationId] = RatingData(
          relationId: relationId,
          subjectId: subjectId,
          subjectName: row['report_subject'] as String,
          subjectDescription: row['subject_description'] as String?,
          choices: choices,
          rating: existingRating?['Choice_id'] as int?,
          description: existingRating?['report_description'] as String?,
        );
      }

      // 6. Parse datetime
      final createdAt = vitalSign['created_at'] as String?;
      final selectedDateTime = createdAt != null
          ? DateTime.tryParse(createdAt) ?? DateTime.now()
          : DateTime.now();

      // 7. Set initial state with existing data
      state = AsyncValue.data(VitalSignFormState(
        vitalSignId: vitalSignId,
        selectedDateTime: selectedDateTime,
        shift: shift,
        isFullReport: isFullReport,
        temp: vitalSign['Temp']?.toString(),
        rr: vitalSign['RR']?.toString(),
        o2: vitalSign['O2']?.toString(),
        sBP: vitalSign['sBP']?.toString(),
        dBP: vitalSign['dBP']?.toString(),
        pr: vitalSign['PR']?.toString(),
        dtx: vitalSign['DTX']?.toString(),
        insulin: vitalSign['Insulin']?.toString(),
        input: vitalSign['Input']?.toString(),
        output: vitalSign['output'] as String?,
        napkin: vitalSign['napkin']?.toString(),
        defecation: vitalSign['Defecation'] as bool? ?? true,
        constipation: vitalSign['constipation']?.toString(),
        ratings: ratings,
        reportD: shift == 'เวรเช้า' ? vitalSign['generalReport'] as String? : null,
        reportN: shift == 'เวรดึก' ? vitalSign['generalReport'] as String? : null,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ==========================================
  // Field Update Methods (same as create)
  // ==========================================

  Future<void> setIsFullReport(bool isFullReport) async {
    final currentData = state.value;
    if (currentData == null) return;

    if (isFullReport) {
      final subjectRows = await _service.getReportSubjects(residentId, currentData.shift);
      final ratings = <int, RatingData>{};
      for (final row in subjectRows) {
        final relationId = row['id'] as int;
        final choicesList = row['choices'] as List<dynamic>?;
        final choices = choicesList?.map((e) => e.toString()).toList();
        ratings[relationId] = RatingData(
          relationId: relationId,
          subjectId: row['subject_id'] as int,
          subjectName: row['report_subject'] as String,
          subjectDescription: row['subject_description'] as String?,
          choices: choices,
        );
      }

      state = AsyncValue.data(currentData.copyWith(
        isFullReport: isFullReport,
        ratings: ratings,
      ));
    } else {
      state = AsyncValue.data(currentData.copyWith(
        isFullReport: isFullReport,
        ratings: {},
      ));
    }
  }

  void setDateTime(DateTime dateTime) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(selectedDateTime: dateTime));
    });
  }

  Future<void> setShift(String shift) async {
    final currentData = state.value;
    if (currentData == null) return;

    final subjectRows = await _service.getReportSubjects(residentId, shift);
    final ratings = <int, RatingData>{};
    for (final row in subjectRows) {
      final relationId = row['id'] as int;
      final choicesList = row['choices'] as List<dynamic>?;
      final choices = choicesList?.map((e) => e.toString()).toList();
      ratings[relationId] = RatingData(
        relationId: relationId,
        subjectId: row['subject_id'] as int,
        subjectName: row['report_subject'] as String,
        subjectDescription: row['subject_description'] as String?,
        choices: choices,
      );
    }

    state = AsyncValue.data(currentData.copyWith(
      shift: shift,
      ratings: ratings,
    ));
  }

  void setTemp(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(temp: value));
    });
  }

  void setRR(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(rr: value));
    });
  }

  void setO2(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(o2: value));
    });
  }

  void setSBP(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(sBP: value));
    });
  }

  void setDBP(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(dBP: value));
    });
  }

  void setPR(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(pr: value));
    });
  }

  void setDTX(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(dtx: value));
    });
  }

  void setInsulin(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(insulin: value));
    });
  }

  void setInput(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(input: value));
    });
  }

  void setOutput(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(output: value));
    });
  }

  void setNapkin(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(napkin: value));
    });
  }

  void setDefecation(bool? value) {
    state.whenData((data) {
      String? newConstipation;

      if (value == null) {
        // ยังไม่ได้เลือก
        newConstipation = null;
      } else if (value) {
        newConstipation = '0';
      } else {
        final lastConst = _lastConstipation ?? 0.0;
        final reportAmt = _reportAmount ?? 2;
        final calculated = lastConst + (1 / reportAmt);
        newConstipation = calculated.toStringAsFixed(2);
      }

      state = AsyncValue.data(data.copyWith(
        defecation: value,
        constipation: newConstipation,
      ));
    });
  }

  void setConstipation(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(constipation: value));
    });
  }

  void setRating(int relationId, int rating) {
    state.whenData((data) {
      final updatedRatings = Map<int, RatingData>.from(data.ratings);
      final current = updatedRatings[relationId];
      if (current != null) {
        updatedRatings[relationId] = current.copyWith(rating: rating);
      }
      state = AsyncValue.data(data.copyWith(ratings: updatedRatings));
    });
  }

  void setRatingDescription(int relationId, String description) {
    state.whenData((data) {
      final updatedRatings = Map<int, RatingData>.from(data.ratings);
      final current = updatedRatings[relationId];
      if (current != null) {
        updatedRatings[relationId] = current.copyWith(description: description);
      }
      state = AsyncValue.data(data.copyWith(ratings: updatedRatings));
    });
  }

  void setReportD(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(reportD: value));
    });
  }

  void setReportN(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(reportN: value));
    });
  }

  // ==========================================
  // Update (instead of Submit)
  // ==========================================

  Future<bool> update() async {
    final currentState = state.value;
    if (currentState == null) return false;

    // Validate: At least one vital sign must be filled
    final hasAnyVitalSign = currentState.temp != null && currentState.temp!.isNotEmpty ||
        currentState.rr != null && currentState.rr!.isNotEmpty ||
        currentState.o2 != null && currentState.o2!.isNotEmpty ||
        currentState.sBP != null && currentState.sBP!.isNotEmpty ||
        currentState.dBP != null && currentState.dBP!.isNotEmpty ||
        currentState.pr != null && currentState.pr!.isNotEmpty;

    if (!hasAnyVitalSign) {
      state = AsyncValue.data(
        currentState.copyWith(
          errorMessage: 'กรุณากรอกสัญญาณชีพอย่างน้อย 1 รายการ',
        ),
      );
      return false;
    }

    // Validate defecation - ต้องเลือกสถานะการขับถ่าย (Full Report only)
    if (currentState.isFullReport && currentState.defecation == null) {
      state = AsyncValue.data(
        currentState.copyWith(
          errorMessage: 'กรุณาเลือกสถานะการขับถ่าย (ถ่ายแล้ว/ยังไม่ถ่าย)',
        ),
      );
      return false;
    }

    // Validate ratings for full report
    if (currentState.isFullReport) {
      final incompleteRatings = currentState.ratings.values
          .where((r) => !r.isComplete)
          .toList();

      if (incompleteRatings.isNotEmpty) {
        state = AsyncValue.data(
          currentState.copyWith(
            errorMessage: 'กรุณาให้คะแนนครบทุกหัวข้อ (เหลืออีก ${incompleteRatings.length} หัวข้อ)',
          ),
        );
        return false;
      }
    }

    state = AsyncValue.data(currentState.copyWith(isLoading: true, errorMessage: null));

    try {
      // Get current user info (รองรับ impersonation)
      final userId = UserService().effectiveUserId ?? '';
      final nursinghomeId = await UserService().getNursinghomeId() ?? 1;

      await _service.updateVitalSign(
        id: vitalSignId,
        residentId: residentId,
        nursinghomeId: nursinghomeId,
        userId: userId,
        formState: currentState,
      );

      state = AsyncValue.data(
        currentState.copyWith(
          isLoading: false,
          errorMessage: null,
        ),
      );

      return true;
    } catch (e) {
      state = AsyncValue.data(
        currentState.copyWith(
          isLoading: false,
          errorMessage: 'เกิดข้อผิดพลาด: ${e.toString()}',
        ),
      );
      return false;
    }
  }

  // ==========================================
  // Delete
  // ==========================================

  Future<bool> delete() async {
    final currentState = state.value;
    if (currentState == null) return false;

    state = AsyncValue.data(currentState.copyWith(isLoading: true, errorMessage: null));

    try {
      await _service.deleteVitalSign(vitalSignId);

      state = AsyncValue.data(
        currentState.copyWith(
          isLoading: false,
          errorMessage: null,
        ),
      );

      return true;
    } catch (e) {
      state = AsyncValue.data(
        currentState.copyWith(
          isLoading: false,
          errorMessage: 'เกิดข้อผิดพลาดในการลบ: ${e.toString()}',
        ),
      );
      return false;
    }
  }
}
