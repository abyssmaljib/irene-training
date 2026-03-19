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

  // joinNursinghome(), createUserInfoAndJoin(), deleteInvitation() ถูกลบแล้ว
  // เหตุผล:
  // 1. ทุก flow ใช้ acceptInvitationAndRejoin() (RPC SECURITY DEFINER) แทนแล้ว
  // 2. joinNursinghome() จะถูก RLS block เพราะ WITH CHECK ไม่ให้เปลี่ยน nursinghome_id
  // 3. createUserInfoAndJoin() จะถูก RLS block เพราะ WITH CHECK ไม่ให้เปลี่ยน role_id + nursinghome_id
  // 4. deleteInvitation() จะถูก RLS block เพราะ invitations ต้อง Manager+ ถึงลบได้
}
