import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../models/zone.dart';
import '../models/resident_simple.dart';

class ZoneService {
  static final ZoneService _instance = ZoneService._internal();
  factory ZoneService() => _instance;
  ZoneService._internal();

  final _userService = UserService();

  /// Get all zones for current user's nursinghome with resident count
  Future<List<Zone>> getZones() async {
    final nursinghomeId = await _userService.getNursinghomeId();
    if (nursinghomeId == null) return [];

    try {
      // ใช้ view nursinghome_zone_resident_count ที่มีข้อมูล zone + จำนวน resident
      final response = await Supabase.instance.client
          .from('nursinghome_zone_resident_count')
          .select()
          .eq('nursinghome_id', nursinghomeId);

      final zones = (response as List)
          .map((json) => Zone.fromJson(json))
          .toList();

      // Sort ตามตัวอักษร (A-Z)
      zones.sort((a, b) => a.name.compareTo(b.name));
      return zones;
    } catch (e) {
      // Fallback: ดึงจาก nursinghome_zone โดยตรง (ไม่มี resident count)
      try {
        final fallbackResponse = await Supabase.instance.client
            .from('nursinghome_zone')
            .select()
            .eq('nursinghome_id', nursinghomeId);

        final zones = (fallbackResponse as List).map((json) => Zone(
              id: json['id'] as int,
              nursinghomeId: json['nursinghome_id'] as int,
              name: json['zone'] as String? ?? '-',
              residentCount: 0,
            )).toList();

        // Sort ตามตัวอักษร (A-Z)
        zones.sort((a, b) => a.name.compareTo(b.name));
        return zones;
      } catch (_) {
        return [];
      }
    }
  }

  /// Get a single zone by id with resident count
  Future<Zone?> getZoneById(int zoneId) async {
    try {
      final response = await Supabase.instance.client
          .from('nursinghome_zone_resident_count')
          .select()
          .eq('zone_id', zoneId)
          .maybeSingle();

      if (response != null) {
        return Zone.fromJson(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get residents by zone IDs for clock-in selection
  /// ดึงจาก residents table โดยตรงเพราะ combined_resident_details_view ไม่มี zone_id (int)
  Future<List<ResidentSimple>> getResidentsByZones(List<int> zoneIds) async {
    final nursinghomeId = await _userService.getNursinghomeId();
    if (nursinghomeId == null || zoneIds.isEmpty) return [];

    try {
      // ดึงจาก residents table โดยตรง พร้อม join zone name
      final response = await Supabase.instance.client
          .from('residents')
          .select('''
            id,
            i_Name_Surname,
            s_zone,
            i_gender,
            i_DOB,
            i_picture_url,
            nursinghome_zone!inner(zone)
          ''')
          .eq('nursinghome_id', nursinghomeId)
          .eq('s_status', 'Stay')
          .inFilter('s_zone', zoneIds)
          .order('i_Name_Surname');

      return (response as List).map((json) {
        final zoneData = json['nursinghome_zone'] as Map<String, dynamic>?;
        return ResidentSimple(
          id: json['id'] as int,
          name: json['i_Name_Surname'] as String? ?? 'ไม่ระบุชื่อ',
          zoneId: json['s_zone'] as int?,
          zoneName: zoneData?['zone'] as String?,
          gender: json['i_gender'] as String?,
          age: _calculateAge(json['i_DOB']),
          photoUrl: json['i_picture_url'] as String?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static int? _calculateAge(dynamic birthday) {
    if (birthday == null) return null;
    DateTime? birthDate;
    if (birthday is DateTime) {
      birthDate = birthday;
    } else if (birthday is String) {
      birthDate = DateTime.tryParse(birthday);
    }
    if (birthDate == null) return null;

    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Get all residents for current nursinghome (for clock-in when no zone selected)
  Future<List<ResidentSimple>> getAllResidents() async {
    final nursinghomeId = await _userService.getNursinghomeId();
    if (nursinghomeId == null) return [];

    try {
      final response = await Supabase.instance.client
          .from('combined_resident_details_view')
          .select('resident_id, i_Name_Surname, zone_id, s_zone, s_sex, i_Birthday, profile_url')
          .eq('nursinghome_id', nursinghomeId)
          .eq('s_status', 'Stay')
          .order('i_Name_Surname');

      return (response as List)
          .map((json) => ResidentSimple.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get residents by list of IDs (สำหรับกรณี dev mode หรือข้อมูลเก่า)
  Future<List<ResidentSimple>> getResidentsByIds(List<int> residentIds) async {
    if (residentIds.isEmpty) return [];

    try {
      final response = await Supabase.instance.client
          .from('residents')
          .select('''
            id,
            i_Name_Surname,
            s_zone,
            i_gender,
            i_DOB,
            i_picture_url,
            nursinghome_zone(zone)
          ''')
          .inFilter('id', residentIds)
          .order('i_Name_Surname');

      return (response as List).map((json) {
        final zoneData = json['nursinghome_zone'] as Map<String, dynamic>?;
        return ResidentSimple(
          id: json['id'] as int,
          name: json['i_Name_Surname'] as String? ?? 'ไม่ระบุชื่อ',
          zoneId: json['s_zone'] as int?,
          zoneName: zoneData?['zone'] as String?,
          gender: json['i_gender'] as String?,
          age: _calculateAge(json['i_DOB']),
          photoUrl: json['i_picture_url'] as String?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
