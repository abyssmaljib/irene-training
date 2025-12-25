import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../models/zone.dart';

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
          .eq('nursinghome_id', nursinghomeId)
          .order('zone_name');

      return (response as List)
          .map((json) => Zone.fromJson(json))
          .toList();
    } catch (e) {
      // Fallback: ดึงจาก nursinghome_zone โดยตรง (ไม่มี resident count)
      try {
        final fallbackResponse = await Supabase.instance.client
            .from('nursinghome_zone')
            .select()
            .eq('nursinghome_id', nursinghomeId)
            .order('zone');

        return (fallbackResponse as List).map((json) => Zone(
              id: json['id'] as int,
              nursinghomeId: json['nursinghome_id'] as int,
              name: json['zone'] as String? ?? '-',
              residentCount: 0,
            )).toList();
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
}
