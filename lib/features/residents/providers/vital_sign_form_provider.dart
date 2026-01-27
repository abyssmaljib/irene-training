import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      // 1. Load last vital sign for constipation calculation
      final lastVital = await _service.getLastVitalSign(residentId);
      _lastConstipation = lastVital?.constipation;

      // 2. Get report amount for constipation increment
      _reportAmount = await _service.getResidentReportAmount(residentId);

      // 3. Load templates
      final templates = await _service.getReportTemplates(residentId);

      // 4. Detect current shift
      final now = DateTime.now();
      final shift = _detectShift(now);

      // 5. Load report subjects for shift
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
      // Get current user info
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      // TODO: Get nursinghomeId from user profile or context
      const nursinghomeId = 1; // Placeholder

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
      // 1. Load existing vital sign with ratings
      final data = await _service.getVitalSignWithRatings(vitalSignId);
      if (data == null) {
        state = AsyncValue.error('ไม่พบข้อมูล Vital Sign', StackTrace.current);
        return;
      }

      final vitalSign = data['vitalSign'] as Map<String, dynamic>;
      final existingRatings = data['ratings'] as List<dynamic>;

      // 2. Load last vital sign for constipation calculation
      final lastVital = await _service.getLastVitalSign(residentId);
      _lastConstipation = lastVital?.constipation;

      // 3. Get report amount for constipation increment
      _reportAmount = await _service.getResidentReportAmount(residentId);

      // 4. Get shift from existing data
      final shift = vitalSign['shift'] as String? ?? 'เวรเช้า';
      final isFullReport = vitalSign['isFullReport'] as bool? ?? true;

      // 5. Load report subjects for shift (for rating options)
      final subjectRows = await _service.getReportSubjects(residentId, shift);
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
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      const nursinghomeId = 1; // TODO: Get from user profile

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
