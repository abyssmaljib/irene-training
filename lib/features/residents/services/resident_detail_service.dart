import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/resident_detail.dart';
import '../models/vital_sign.dart';

/// Service สำหรับดึงข้อมูล Resident Detail
class ResidentDetailService {
  static final instance = ResidentDetailService._();
  ResidentDetailService._();

  final _supabase = Supabase.instance.client;

  /// ดึงข้อมูล Resident ตาม ID
  Future<ResidentDetail?> getResidentById(int id) async {
    try {
      final response = await _supabase
          .from('residents')
          .select('''
            id,
            i_Name_Surname,
            i_gender,
            i_DOB,
            i_picture_url,
            i_National_ID_num,
            s_zone,
            s_bed,
            s_status,
            s_special_status,
            s_contract_date,
            m_past_history,
            m_dietary,
            m_fooddrug_allergy,
            underlying_disease_list,
            nursinghome_zone!s_zone(id, zone)
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return ResidentDetail.fromJson(response);
    } catch (e) {
      debugPrint('getResidentById error: $e');
      return null;
    }
  }

  /// ดึง Vital Sign ล่าสุดของ Resident
  Future<VitalSign?> getLatestVitalSign(int residentId) async {
    try {
      final response = await _supabase
          .from('vitalSign')
          .select('''
            id,
            resident_id,
            sBP,
            dBP,
            PR,
            O2,
            Temp,
            RR,
            created_at
          ''')
          .eq('resident_id', residentId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return VitalSign.fromJson(response);
    } catch (e) {
      debugPrint('getLatestVitalSign error: $e');
      return null;
    }
  }

  /// ดึง Vital Signs ย้อนหลัง (สำหรับ chart - Future use)
  Future<List<VitalSign>> getVitalSignHistory(
    int residentId, {
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('vitalSign')
          .select('''
            id,
            resident_id,
            sBP,
            dBP,
            PR,
            O2,
            Temp,
            RR,
            created_at
          ''')
          .eq('resident_id', residentId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => VitalSign.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getVitalSignHistory error: $e');
      return [];
    }
  }

  /// ดึงรายการโรคประจำตัว (underlying diseases) จาก relation table
  Future<List<String>> getUnderlyingDiseases(int residentId) async {
    try {
      final response = await _supabase
          .from('resident_underlying_disease')
          .select('''
            underlying_disease!inner(name)
          ''')
          .eq('resident_id', residentId);

      return (response as List)
          .map((item) => item['underlying_disease']['name'] as String)
          .toList();
    } catch (e) {
      debugPrint('getUnderlyingDiseases error: $e');
      return [];
    }
  }

  /// ดึงข้อมูลญาติ (relatives) - Future use
  Future<List<Map<String, dynamic>>> getRelatives(int residentId) async {
    try {
      final response = await _supabase
          .from('resident_relatives')
          .select('''
            relatives!inner(
              id,
              r_name_surname,
              r_phone,
              r_detail,
              key_person,
              r_nickname
            )
          ''')
          .eq('resident_id', residentId);

      return (response as List)
          .map((item) => item['relatives'] as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('getRelatives error: $e');
      return [];
    }
  }
}
