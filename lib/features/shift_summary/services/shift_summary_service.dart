import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../models/monthly_summary.dart';
import '../models/clock_summary.dart';

/// Service for managing shift summary data
class ShiftSummaryService {
  static final ShiftSummaryService instance = ShiftSummaryService._();
  ShiftSummaryService._();

  final _supabase = Supabase.instance.client;
  final _userService = UserService();

  // Cache for monthly summaries
  List<MonthlySummary>? _cachedMonthlySummaries;
  String? _cachedUserId;
  DateTime? _cacheTime;
  static const _cacheMaxAge = Duration(minutes: 5);

  /// Get monthly summaries for current user
  Future<List<MonthlySummary>> getMonthlySummaries({
    bool forceRefresh = false,
  }) async {
    final userId = _userService.effectiveUserId;
    if (userId == null) return [];

    // Check cache
    if (!forceRefresh &&
        _cachedMonthlySummaries != null &&
        _cachedUserId == userId &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheMaxAge) {
      return _cachedMonthlySummaries!;
    }

    try {
      final response = await _supabase
          .from('clock_in_out_monthly_summary')
          .select()
          .eq('user_id', userId)
          .order('year', ascending: false)
          .order('month', ascending: false);

      final summaries = (response as List)
          .map((json) => MonthlySummary.fromJson(json as Map<String, dynamic>))
          .toList();

      // Update cache
      _cachedMonthlySummaries = summaries;
      _cachedUserId = userId;
      _cacheTime = DateTime.now();

      return summaries;
    } catch (e) {
      return [];
    }
  }

  /// Get shift details for a specific month
  Future<List<ClockSummary>> getShiftDetails({
    required int month,
    required int year,
  }) async {
    final userId = _userService.effectiveUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('clock_in_out_summary')
          .select()
          .eq('user_id', userId)
          .eq('month', month)
          .eq('year', year)
          .order('clock_in_time', ascending: false);

      return (response as List)
          .map((json) => ClockSummary.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Submit sick leave claim
  /// Updates the Clock Special Record with sick_evident and sick_reason
  Future<bool> claimSickLeave({
    required int specialRecordId,
    required String sickEvident,
    required String sickReason,
  }) async {
    try {
      await _supabase.from('Clock Special Record').update({
        'sick_evident': sickEvident,
        'sick_reason': sickReason,
      }).eq('id', specialRecordId);

      // Invalidate cache
      invalidateCache();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Upload sick evidence from bytes
  Future<String?> uploadSickEvidenceFromBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final userId = _userService.effectiveUserId;
    if (userId == null) return null;

    try {
      final storagePath = 'sick_evidence/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await _supabase.storage.from('uploads').uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );

      final publicUrl = _supabase.storage.from('uploads').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      return null;
    }
  }

  /// Invalidate cache
  void invalidateCache() {
    _cachedMonthlySummaries = null;
    _cachedUserId = null;
    _cacheTime = null;
  }
}
