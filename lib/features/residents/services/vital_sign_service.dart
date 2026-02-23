import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vital_sign.dart';
import '../models/vital_sign_form_state.dart';

/// Service for Vital Sign CRUD operations
class VitalSignService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get last vital sign for a resident (for constipation calculation)
  Future<VitalSign?> getLastVitalSign(int residentId) async {
    try {
      final rows = await _supabase
          .from('vitalSign')
          .select()
          .eq('resident_id', residentId)
          .order('created_at', ascending: false)
          .limit(1);

      if (rows.isEmpty) return null;
      return VitalSign.fromJson(rows.first);
    } catch (_) {
      return null;
    }
  }

  /// Get report templates for pre-filling
  Future<Map<String, String>?> getReportTemplates(int residentId) async {
    try {
      final rows = await _supabase
          .from('Resident_Template_Gen_Report')
          .select('template_D, template_N')
          .eq('resident_id', residentId)
          .limit(1);

      if (rows.isEmpty) return null;
      return {
        'templateD': rows[0]['template_D'] ?? '',
        'templateN': rows[0]['template_N'] ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  /// Get report subjects by shift with choices
  /// ดึง relations + choices ทั้งหมดใน 2 queries (แทน N+1)
  Future<List<Map<String, dynamic>>> getReportSubjects(
    int residentId,
    String shift,
  ) async {
    try {
      // Query 1: ดึง relations ทั้งหมดของ resident + shift
      final relations = await _supabase
          .from('vw_resident_report_relation')
          .select()
          .eq('resident_id', residentId)
          .eq('shift', shift)
          .order('subject_id', ascending: true);

      if (relations.isEmpty) return [];

      // รวม subject_id ทั้งหมดที่ต้องดึง choices
      final subjectIds = relations
          .map((r) => r['subject_id'] as int)
          .toSet()
          .toList();

      // Query 2: ดึง choices ทั้งหมดในครั้งเดียว (แทนที่จะวน loop ทีละ subject)
      final allChoices = await _supabase
          .from('Report_Choice')
          .select('Choice, Scale, Subject')
          .inFilter('Subject', subjectIds)
          .order('Scale', ascending: true);

      // สร้าง map: subjectId -> [choice texts sorted by scale]
      final choicesMap = <int, List<String>>{};
      for (final c in allChoices) {
        final subjectId = c['Subject'] as int;
        choicesMap.putIfAbsent(subjectId, () => []);
        choicesMap[subjectId]!.add(c['Choice'] as String);
      }

      // รวม relations + choices เข้าด้วยกัน
      return relations.map((relation) {
        final subjectId = relation['subject_id'] as int;
        return {
          ...relation,
          'choices': choicesMap[subjectId] ?? [],
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get resident's report amount (for constipation calculation)
  Future<int> getResidentReportAmount(int residentId) async {
    try {
      final rows = await _supabase
          .from('residents')
          .select('Report_Amount')
          .eq('id', residentId)
          .limit(1);

      if (rows.isEmpty) return 2;
      return (rows[0]['Report_Amount'] as int?) ?? 2;
    } catch (_) {
      return 2;
    }
  }

  /// Create vital sign + ratings (2-step transaction)
  Future<int> createVitalSign({
    required int residentId,
    required int nursinghomeId,
    required String userId,
    required VitalSignFormState formState,
  }) async {
    try {
      // Get last vital sign for constipation value (for abbreviated report)
      double? lastConstipation;
      if (!formState.isFullReport) {
        final lastVital = await getLastVitalSign(residentId);
        lastConstipation = lastVital?.constipation;
      }

      // Step 1: Insert vital sign
      final vitalSignRow = await _supabase
          .from('vitalSign')
          .insert({
            'resident_id': residentId,
            'nursinghome_id': nursinghomeId,
            'user_id': userId,
            'Temp': double.tryParse(formState.temp ?? ''),
            'RR': int.tryParse(formState.rr ?? ''),
            'O2': int.tryParse(formState.o2 ?? ''),
            'sBP': int.tryParse(formState.sBP ?? ''),
            'dBP': int.tryParse(formState.dBP ?? ''),
            'PR': int.tryParse(formState.pr ?? ''),
            'DTX': int.tryParse(formState.dtx ?? ''),
            'Insulin': int.tryParse(formState.insulin ?? ''),
            'Input': int.tryParse(formState.input ?? ''),
            'output': formState.output,
            // รายงานย่อ: defecation = false (ไม่บันทึกข้อมูลอุจจาระ แต่ไม่ใช่ null)
            // รายงานเต็ม: ใช้ค่าที่ user เลือก
            'Defecation': formState.isFullReport ? formState.defecation : false,
            // รายงานย่อ: ใช้ค่า constipation เดิมจาก record ล่าสุด
            // รายงานเต็ม: ใช้ค่าที่ user กรอก/ระบบคำนวณ
            'constipation': formState.isFullReport
                ? double.tryParse(formState.constipation ?? '')
                : lastConstipation,
            'napkin': int.tryParse(formState.napkin ?? ''),
            'generalReport': formState.isFullReport
                ? (formState.shift == 'เวรเช้า'
                    ? (formState.reportD ?? '-')
                    : (formState.reportN ?? '-'))
                : '-',
            'shift': formState.isFullReport ? formState.shift : null,
            'isFullReport': formState.isFullReport,
            'created_at': formState.selectedDateTime.toIso8601String(),
          })
          .select('id')
          .single();

      final vitalSignId = vitalSignRow['id'] as int;

      // Step 2: Insert Scale_Report_Log entries (only for full report and rated items)
      if (formState.isFullReport) {
        final ratedItems = formState.ratings.values
            .where((r) => r.isComplete)
            .toList();

        if (ratedItems.isNotEmpty) {
          await _supabase.from('Scale_Report_Log').insert(
            ratedItems.map((r) => {
              'vital_sign_id': vitalSignId,
              'Subject_id': r.subjectId,
              'Choice_id': r.rating,
              'Relation_id': r.relationId,
              'resident_id': residentId,
              'report_description': r.description ?? '',
            }).toList(),
          );
        }
      }

      return vitalSignId;
    } catch (_) {
      rethrow;
    }
  }

  /// Get vital sign by ID with ratings
  Future<Map<String, dynamic>?> getVitalSignWithRatings(int id) async {
    try {
      // Get vital sign
      final vitalSignRows = await _supabase
          .from('vitalSign')
          .select()
          .eq('id', id)
          .limit(1);

      if (vitalSignRows.isEmpty) return null;
      final vitalSign = vitalSignRows.first;

      // Get ratings (Scale_Report_Log entries)
      final ratingsRows = await _supabase
          .from('Scale_Report_Log')
          .select()
          .eq('vital_sign_id', id);

      return {
        'vitalSign': vitalSign,
        'ratings': ratingsRows,
      };
    } catch (_) {
      return null;
    }
  }

  /// Update vital sign + ratings
  Future<void> updateVitalSign({
    required int id,
    required int residentId,
    required int nursinghomeId,
    required String userId,
    required VitalSignFormState formState,
  }) async {
    try {
      // Get last vital sign for constipation value (for abbreviated report)
      double? lastConstipation;
      if (!formState.isFullReport) {
        final lastVital = await getLastVitalSign(residentId);
        lastConstipation = lastVital?.constipation;
      }

      // Step 1: Update vital sign
      await _supabase.from('vitalSign').update({
        'Temp': double.tryParse(formState.temp ?? ''),
        'RR': int.tryParse(formState.rr ?? ''),
        'O2': int.tryParse(formState.o2 ?? ''),
        'sBP': int.tryParse(formState.sBP ?? ''),
        'dBP': int.tryParse(formState.dBP ?? ''),
        'PR': int.tryParse(formState.pr ?? ''),
        'DTX': int.tryParse(formState.dtx ?? ''),
        'Insulin': int.tryParse(formState.insulin ?? ''),
        'Input': int.tryParse(formState.input ?? ''),
        'output': formState.output,
        // รายงานย่อ: defecation = false, รายงานเต็ม: ใช้ค่าที่ user เลือก
        'Defecation': formState.isFullReport ? formState.defecation : false,
        // รายงานย่อ: ใช้ค่า constipation เดิม, รายงานเต็ม: ใช้ค่าที่ user กรอก
        'constipation': formState.isFullReport
            ? double.tryParse(formState.constipation ?? '')
            : lastConstipation,
        'napkin': int.tryParse(formState.napkin ?? ''),
        'generalReport': formState.isFullReport
            ? (formState.shift == 'เวรเช้า'
                ? (formState.reportD ?? '-')
                : (formState.reportN ?? '-'))
            : '-',
        'shift': formState.isFullReport ? formState.shift : null,
        'isFullReport': formState.isFullReport,
        'created_at': formState.selectedDateTime.toIso8601String(),
      }).eq('id', id);

      // Step 2: Delete old Scale_Report_Log entries
      await _supabase.from('Scale_Report_Log').delete().eq('vital_sign_id', id);

      // Step 3: Insert new Scale_Report_Log entries (only for full report)
      if (formState.isFullReport) {
        final ratedItems = formState.ratings.values
            .where((r) => r.isComplete)
            .toList();

        if (ratedItems.isNotEmpty) {
          await _supabase.from('Scale_Report_Log').insert(
            ratedItems.map((r) => {
              'vital_sign_id': id,
              'Subject_id': r.subjectId,
              'Choice_id': r.rating,
              'Relation_id': r.relationId,
              'resident_id': residentId,
              'report_description': r.description ?? '',
            }).toList(),
          );
        }
      }
    } catch (_) {
      rethrow;
    }
  }

  /// Delete vital sign (ratings will cascade delete if FK is set, or delete manually)
  Future<void> deleteVitalSign(int id) async {
    try {
      // Delete ratings first (in case FK cascade is not set)
      await _supabase.from('Scale_Report_Log').delete().eq('vital_sign_id', id);

      // Delete vital sign
      await _supabase.from('vitalSign').delete().eq('id', id);
    } catch (_) {
      rethrow;
    }
  }
}
