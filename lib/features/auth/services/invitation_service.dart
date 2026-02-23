import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invitation.dart';

/// Service สำหรับจัดการ invitation
///
/// ใช้สำหรับ:
/// 1. ค้นหา invitations ตาม email
/// 2. เช็คว่า user มี account แล้วหรือยัง
/// 3. Register user ใหม่
/// 4. อัพเดต user_info ให้เข้าร่วม nursinghome
class InvitationService {
  // Singleton instance
  static final InvitationService _instance = InvitationService._internal();
  factory InvitationService() => _instance;
  InvitationService._internal();

  // Supabase client
  SupabaseClient get _client => Supabase.instance.client;

  /// ค้นหา invitations ตาม email
  ///
  /// ใช้ RPC `search_invitations_by_email` (SECURITY DEFINER)
  /// เพื่อ bypass RLS บน invitations table
  /// ทำให้ทั้ง user ใหม่ (unauthenticated) และ user ที่ resigned/ไม่มี nursinghome
  /// สามารถค้นหา invitation ได้
  ///
  /// [email] - email ที่ต้องการค้นหา (case-insensitive)
  /// Returns - List ของ Invitation ที่พบ (เฉพาะที่ยังไม่ accept)
  Future<List<Invitation>> getInvitationsByEmail(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      debugPrint('InvitationService: Searching invitations for $normalizedEmail');

      // ใช้ RPC แทน direct view query เพื่อ bypass RLS
      // RPC จะ return เฉพาะ invitations ที่ยังไม่ accepted
      final response = await _client.rpc(
        'search_invitations_by_email',
        params: {'p_email': normalizedEmail},
      );

      final data = response as List;
      debugPrint('InvitationService: Found ${data.length} invitations');

      // แปลง JSON เป็น List<Invitation>
      return data
          .map((json) => Invitation.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('InvitationService: Error searching invitations: $e');
      rethrow;
    }
  }

  /// เช็คว่า user มี account (user_info) อยู่แล้วหรือยัง
  ///
  /// [email] - email ที่ต้องการเช็ค
  /// Returns - true ถ้ามี account อยู่แล้ว, false ถ้าไม่มี
  Future<bool> checkUserExists(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      debugPrint('InvitationService: Checking if user exists: $normalizedEmail');

      // Query user_info table โดยใช้ ilike เพื่อ case-insensitive
      final response = await _client
          .from('user_info')
          .select('id')
          .ilike('email', normalizedEmail)
          .maybeSingle();

      final exists = response != null;
      debugPrint('InvitationService: User exists = $exists');

      return exists;
    } catch (e) {
      debugPrint('InvitationService: Error checking user: $e');
      rethrow;
    }
  }

  /// Register user ใหม่ (สร้าง auth user)
  ///
  /// Note: หลัง signUp สำเร็จ Supabase จะสร้าง session ให้อัตโนมัติ (ไม่ต้อง verify email)
  /// และ AuthWrapper ใน main.dart จะ navigate ไป MainNavigationScreen
  ///
  /// [email] - email สำหรับ account ใหม่
  /// [password] - password สำหรับ account ใหม่
  Future<AuthResponse> registerUser(String email, String password) async {
    try {
      debugPrint('=== InvitationService.registerUser() START ===');
      debugPrint('Email: $email');

      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );

      debugPrint('InvitationService.registerUser: signUp response received');
      debugPrint('User ID: ${response.user?.id}');
      debugPrint('Session: ${response.session != null ? "EXISTS" : "NULL"}');
      debugPrint('=== InvitationService.registerUser() END ===');

      return response;
    } catch (e) {
      debugPrint('InvitationService.registerUser ERROR: $e');
      rethrow;
    }
  }

  /// Login user ที่มีอยู่แล้ว
  ///
  /// [email] - email ของ user
  /// [password] - password ของ user
  Future<AuthResponse> loginUser(String email, String password) async {
    try {
      debugPrint('InvitationService: Logging in user: $email');

      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      debugPrint('InvitationService: Login successful, user id: ${response.user?.id}');

      return response;
    } catch (e) {
      debugPrint('InvitationService: Error logging in: $e');
      rethrow;
    }
  }

  /// Accept invitation และ rejoin nursinghome ผ่าน RPC
  ///
  /// ใช้ RPC `accept_invitation_and_rejoin` (SECURITY DEFINER)
  /// เพื่อ bypass RLS บน user_info table
  /// RPC จะทำทุกอย่างใน 1 call:
  /// - Update nursinghome_id + reset employment_type เป็น NULL
  /// - หรือสร้าง user_info ใหม่ (ถ้ายังไม่มี)
  /// - ลบ invitation (ป้องกันใช้ซ้ำ)
  ///
  /// [invitationId] - ID ของ invitation ที่ต้องการ accept
  Future<void> acceptInvitationAndRejoin(int invitationId) async {
    try {
      debugPrint('InvitationService: Accepting invitation $invitationId via RPC');

      final response = await _client.rpc(
        'accept_invitation_and_rejoin',
        params: {'p_invitation_id': invitationId},
      );

      debugPrint('InvitationService: Accept invitation response: $response');
    } catch (e) {
      debugPrint('InvitationService: Error accepting invitation: $e');
      rethrow;
    }
  }

  /// อัพเดต user_info ให้เข้าร่วม nursinghome (backup path)
  ///
  /// Note: ควรใช้ acceptInvitationAndRejoin() แทน เพราะ bypass RLS ได้
  /// method นี้เก็บไว้เป็น fallback
  ///
  /// [nursinghomeId] - ID ของ nursinghome ที่ต้องการเข้าร่วม
  Future<void> joinNursinghome(int nursinghomeId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      debugPrint('InvitationService: Joining nursinghome $nursinghomeId for user $userId');

      // อัพเดต user_info พร้อม reset employment_type เป็น NULL
      // เพื่อให้ user ที่เคย resigned กลับมาใช้งานได้
      await _client.from('user_info').update({
        'nursinghome_id': nursinghomeId,
        'employment_type': null, // reset จาก 'resigned' เป็น active
      }).eq('id', userId);

      debugPrint('InvitationService: Successfully joined nursinghome');
    } catch (e) {
      debugPrint('InvitationService: Error joining nursinghome: $e');
      rethrow;
    }
  }

  /// สร้าง user_info record ใหม่สำหรับ user ที่เพิ่ง register
  ///
  /// [email] - email ของ user
  /// [nursinghomeId] - ID ของ nursinghome ที่ต้องการเข้าร่วม
  /// [roleId] - Role ID จาก invitation (ถ้ามี) จะกำหนด role ให้ user
  Future<void> createUserInfoAndJoin(
    String email,
    int nursinghomeId, {
    int? roleId,
  }) async {
    try {
      debugPrint('=== InvitationService.createUserInfoAndJoin() START ===');

      // ดึง current user id จาก auth
      final userId = _client.auth.currentUser?.id;
      debugPrint('Current user id: $userId');

      if (userId == null) {
        debugPrint('ERROR: User not logged in!');
        throw Exception('User not logged in');
      }

      debugPrint('Checking for existing user_info...');

      // เช็คว่ามี user_info อยู่แล้วหรือไม่
      // Note: user_info.id = auth user id (UUID)
      final existing = await _client
          .from('user_info')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      debugPrint('Existing user_info: ${existing != null ? "FOUND" : "NOT FOUND"}');

      // เตรียมข้อมูลที่จะ update/insert
      final userData = <String, dynamic>{
        'nursinghome_id': nursinghomeId,
        'email': email.trim().toLowerCase(),
      };
      // เพิ่ม role_id ถ้ามีค่าจาก invitation
      if (roleId != null) {
        userData['role_id'] = roleId;
      }
      debugPrint('userData to save: $userData');

      if (existing != null) {
        // ถ้ามีอยู่แล้ว ให้ update nursinghome_id และ role_id
        debugPrint('Updating existing user_info...');
        await _client.from('user_info').update(userData).eq('id', userId);
        debugPrint('Update SUCCESS');
      } else {
        // ถ้ายังไม่มี ให้สร้างใหม่
        // Note: id column = auth user UUID
        debugPrint('Inserting new user_info...');
        await _client.from('user_info').insert({
          'id': userId,
          ...userData,
        });
        debugPrint('Insert SUCCESS');
      }

      debugPrint('=== InvitationService.createUserInfoAndJoin() END ===');
    } catch (e) {
      debugPrint('=== InvitationService.createUserInfoAndJoin() ERROR ===');
      debugPrint('Error: $e');
      rethrow;
    }
  }

  /// ลบ invitation หลังจาก user accept สำเร็จแล้ว
  ///
  /// เรียกหลังจาก createUserInfoAndJoin สำเร็จ
  /// เพื่อป้องกันไม่ให้ invitation ถูกใช้ซ้ำ
  ///
  /// [invitationId] - ID ของ invitation ที่ต้องการลบ
  Future<void> deleteInvitation(int invitationId) async {
    try {
      debugPrint('InvitationService: Deleting invitation $invitationId');

      await _client
          .from('invitations')
          .delete()
          .eq('id', invitationId);

      debugPrint('InvitationService: Successfully deleted invitation');
    } catch (e) {
      // ถ้าลบไม่สำเร็จ ไม่ต้อง throw error
      // เพราะ user เข้าร่วมสำเร็จแล้ว แค่ลบ invitation ไม่ได้
      debugPrint('InvitationService: Error deleting invitation (non-critical): $e');
    }
  }
}
