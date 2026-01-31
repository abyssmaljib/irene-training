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
  /// Query จาก view `invitations_with_nursinghomes`
  /// โดยกรองเฉพาะที่ยังไม่ได้ accept (accepted_user_info = false)
  ///
  /// [email] - email ที่ต้องการค้นหา (case-insensitive)
  /// Returns - List ของ Invitation ที่พบ
  Future<List<Invitation>> getInvitationsByEmail(String email) async {
    try {
      // Normalize email to lowercase ก่อน query
      final normalizedEmail = email.trim().toLowerCase();

      debugPrint('InvitationService: Searching invitations for $normalizedEmail');

      // Query invitations_with_nursinghomes view
      // View นี้มีการ JOIN invitations + nursinghomes + user_info
      final response = await _client
          .from('invitations_with_nursinghomes')
          .select()
          .ilike('user_email', normalizedEmail) // case-insensitive match
          .eq('accepted_user_info', false); // เฉพาะที่ยังไม่ accept

      debugPrint('InvitationService: Found ${response.length} invitations');

      // แปลง JSON เป็น List<Invitation>
      return response
          .map((json) => Invitation.fromJson(json))
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

  /// อัพเดต user_info ให้เข้าร่วม nursinghome
  ///
  /// Note: ฟังก์ชันนี้จะ switch nursinghome โดยตรง ไม่ต้อง confirm
  ///
  /// [nursinghomeId] - ID ของ nursinghome ที่ต้องการเข้าร่วม
  Future<void> joinNursinghome(int nursinghomeId) async {
    try {
      // ดึง current user id จาก auth
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      debugPrint('InvitationService: Joining nursinghome $nursinghomeId for user $userId');

      // อัพเดต user_info โดยใช้ auth user id
      // Note: user_info.id = auth user id (UUID)
      await _client.from('user_info').update({
        'nursinghome_id': nursinghomeId,
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
