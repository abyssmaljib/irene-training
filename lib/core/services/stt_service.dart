// Speech-to-Text service — wrap record package + Supabase edge function
//
// Flow:
//   1. startRecording() → อัดเสียงลงไฟล์ temp (AAC-LC .m4a, mono, 16kHz, 64kbps)
//   2. stopRecording() → หยุดอัด, return path
//   3. transcribe(path, context, nursinghomeId) → ส่งไป edge function 'transcribe-audio'
//      - ฝั่ง server: Whisper Large v3 Turbo → raw, แล้ว Llama 3.3 70B → cleanup
//   4. ลบไฟล์ temp ทิ้งหลังส่งเสร็จ (ไม่เก็บเสียงไว้บนเครื่อง เพื่อ PDPA)
//
// Error handling:
//   - ถ้าไม่มี mic permission → throw SttException
//   - ถ้า quota เกิน (100/วัน) → backend return 429 → throw SttException(isQuotaExceeded)
//   - ถ้าเสียงเงียบ/ไม่ชัด → backend return 422 → throw SttException(isEmptySpeech)

import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// บริบทการใช้งาน STT — กำหนด prompt + cleanup rules ที่ backend
/// - post: โพสต์ board ทั่วไป (ปรับประโยคให้อ่านง่าย)
/// - vitalsign: รายงานสัญญาณชีพ (ห้ามแก้ตัวเลข)
enum SttContext { post, vitalsign }

extension SttContextX on SttContext {
  /// ค่าที่ส่งไป backend (ต้องตรงกับ enum ฝั่ง edge function)
  String get value => name;
}

/// ผลลัพธ์จาก STT (หลัง cleanup)
class SttResult {
  final String transcript; // ข้อความที่ใช้ (หลัง Llama cleanup)
  final String raw; // ข้อความดิบจาก Whisper (debug only)
  final int durationMs; // เวลา end-to-end ของ edge function
  final double costEstimateUsd; // ต้นทุนโดยประมาณของ call นี้
  final int quotaUsed; // quota ที่ใช้ไปแล้ว (รวม call ปัจจุบัน)
  final int quotaLimit; // quota สูงสุดต่อวัน

  const SttResult({
    required this.transcript,
    required this.raw,
    required this.durationMs,
    required this.costEstimateUsd,
    required this.quotaUsed,
    required this.quotaLimit,
  });

  factory SttResult.fromJson(Map<String, dynamic> json) {
    final quota = json['quota'] as Map<String, dynamic>;
    return SttResult(
      transcript: json['transcript'] as String,
      raw: json['raw'] as String? ?? '',
      durationMs: json['duration_ms'] as int? ?? 0,
      costEstimateUsd: (json['cost_estimate_usd'] as num?)?.toDouble() ?? 0,
      quotaUsed: quota['used'] as int? ?? 0,
      quotaLimit: quota['limit'] as int? ?? 100,
    );
  }
}

/// Exception จาก STT service — แยก case ที่ต้องแสดง message ต่างกัน
class SttException implements Exception {
  final String message;
  final int? statusCode;
  const SttException(this.message, {this.statusCode});

  /// 429 — เกิน quota ต่อวัน
  bool get isQuotaExceeded => statusCode == 429;

  /// 422 — Whisper คืนข้อความเปล่า (เสียงเงียบ/ไม่ชัด)
  bool get isEmptySpeech => statusCode == 422;

  /// 401 — JWT expired / missing
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'SttException($statusCode): $message';
}

class SttService {
  final SupabaseClient supabase;

  /// AudioRecorder เป็น nullable — สร้างใหม่ทุกครั้งที่ startRecording()
  /// เหตุผล: บาง implementation (โดยเฉพาะ Android MediaRecorder) ไม่ reset
  /// internal state ให้ clean หลัง stop() → session ที่ 2 start ไม่ติด
  /// วิธีแก้ = dispose + สร้างใหม่ทุก session
  AudioRecorder? _recorder;

  SttService(this.supabase);

  /// Max recording duration ฝั่ง client (backend ก็มี cap 180s)
  /// กัน user กดค้างลืม = ไฟล์ใหญ่, ค่าใช้จ่ายพุ่ง
  static const Duration maxDuration = Duration(seconds: 120);

  /// Timeout สำหรับ HTTP call ไป edge function
  /// - Whisper Large v3 Turbo ~2-5s สำหรับ audio 60s
  /// - Llama cleanup ~1-3s
  /// - + network → ให้เผื่อไว้ 45s
  static const Duration transcribeTimeout = Duration(seconds: 45);

  /// เริ่มอัดเสียง → return path ของไฟล์ temp ที่กำลังอัด
  /// Throws [SttException] ถ้าไม่มี mic permission
  ///
  /// **สำคัญ:** dispose recorder เก่า + สร้างใหม่ทุกครั้ง
  /// เพื่อกัน internal state ค้าง (Android MediaRecorder, iOS AVAudioRecorder
  /// บางเวอร์ชัน reset ไม่ clean ทำให้ session ที่ 2 start ไม่ติด)
  Future<String> startRecording() async {
    // Dispose recorder เก่า (ถ้ามี) + สร้าง instance ใหม่
    try {
      await _recorder?.dispose();
    } catch (_) {}
    _recorder = AudioRecorder();
    final recorder = _recorder!;

    // AudioRecorder.hasPermission() ครั้งแรกจะขอ system permission ให้เอง
    // ครั้งที่สอง+ ถ้า denied → return false เฉยๆ (ไม่เด้งขอซ้ำ)
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      throw const SttException('ไม่ได้รับอนุญาตให้ใช้ไมโครโฟน ไปเปิดที่ Settings');
    }

    // ใช้ temp dir — ไฟล์หายเองเมื่อ OS cleanup
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/stt_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // AAC-LC (m4a) — รองรับทั้ง iOS/Android + Whisper decode ได้
    // 64kbps mono 16kHz = เพียงพอสำหรับเสียงพูด, ไฟล์เล็ก (~8KB/วินาที)
    // 120s = ~960KB → base64 ~1.3MB → ส่งผ่าน edge function body ได้สบาย (limit 6MB)
    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000, // Whisper ใช้ 16kHz internally อยู่แล้ว
        numChannels: 1, // mono
      ),
      path: path,
    );

    return path;
  }

  /// หยุดอัด → return path ของไฟล์ (ยังไม่ส่งไป backend)
  /// Return null ถ้าไม่ได้อัดอยู่
  Future<String?> stopRecording() async {
    return _recorder?.stop();
  }

  /// ยกเลิกการอัด + ลบไฟล์ทิ้ง (ไม่ส่งไป backend)
  Future<void> cancelRecording() async {
    final path = await _recorder?.stop();
    if (path != null) {
      // ลบไฟล์ทิ้ง — ถ้าลบไม่สำเร็จไม่เป็นไร (temp dir OS cleanup เอง)
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  /// Check ว่ากำลังอัดอยู่มั้ย
  Future<bool> isRecording() async =>
      await _recorder?.isRecording() ?? false;

  /// Stream amplitude (dBFS) สำหรับแสดง waveform/level ขณะอัด (optional)
  /// ถ้ายังไม่ได้ start → คืน empty stream
  Stream<Amplitude> amplitudeStream({
    Duration interval = const Duration(milliseconds: 100),
  }) {
    final r = _recorder;
    if (r == null) return const Stream.empty();
    return r.onAmplitudeChanged(interval);
  }

  /// ส่งไฟล์เสียงไป edge function → return transcript ที่ cleanup แล้ว
  ///
  /// - [audioPath]: path ที่ได้จาก [stopRecording]
  /// - [context]: 'post' หรือ 'vitalsign' (กำหนด cleanup rules ที่ backend)
  /// - [nursinghomeId]: ใช้ดึงรายชื่อ resident ทั้งบ้าน → bias Gemini ถอดชื่อถูก
  /// - [residentId]: ถ้ารู้ว่ากำลังพูดถึงคนไหน → backend จะดึงข้อมูลคนนั้น
  ///   (อายุ, เพศ, โรคประจำตัว, แพ้ยา) มาเป็น context เพิ่ม ช่วยให้ transcribe แม่นขึ้น
  /// - [actualDuration]: ระยะเวลาที่อัดจริง (ถ้าไม่ส่ง ประมาณจาก file size)
  ///
  /// หลังส่งเสร็จ (สำเร็จหรือไม่) — ลบไฟล์ temp ทิ้ง
  Future<SttResult> transcribe({
    required String audioPath,
    required SttContext context,
    int? nursinghomeId,
    int? residentId,
    Duration? actualDuration,
  }) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw const SttException('ไฟล์เสียงหาย — ลองอัดใหม่');
    }

    // อ่านไฟล์ → base64
    final bytes = await file.readAsBytes();
    final base64Audio = base64Encode(bytes);

    // ลบไฟล์ทิ้งทันที — ไม่รอ response เพราะถ้า error ก็ลบอยู่ดี (PDPA)
    try {
      await file.delete();
    } catch (_) {}

    // ประมาณ duration ถ้าไม่ส่งมา (64kbps = 8KB/sec → bytes/8000 ≈ วินาที)
    final durationSec =
        actualDuration?.inSeconds ?? (bytes.length / 8000).round();

    try {
      final response = await supabase.functions.invoke(
        'transcribe-audio',
        body: {
          'audio': base64Audio,
          'audio_mime': 'audio/m4a',
          'audio_duration_sec': durationSec,
          'context': context.value,
          if (nursinghomeId != null) 'nursinghome_id': nursinghomeId,
          if (residentId != null) 'resident_id': residentId,
          'cleanup': true,
        },
      ).timeout(transcribeTimeout);

      final data = response.data as Map<String, dynamic>;
      return SttResult.fromJson(data);
    } on FunctionException catch (e) {
      // Edge function return non-2xx → FunctionException
      // details อาจเป็น Map ที่มี 'error' key (ตาม jsonResponse ใน edge fn)
      final details = e.details;
      String errMsg = 'STT failed';
      if (details is Map && details['error'] is String) {
        errMsg = details['error'] as String;
      } else if (details is String) {
        errMsg = details;
      }
      throw SttException(errMsg, statusCode: e.status);
    } on Exception catch (e) {
      // Timeout, network error, JSON parse error ฯลฯ
      throw SttException('แปลงเสียงไม่สำเร็จ: $e');
    }
  }

  /// ปิด recorder — เรียกตอน dispose provider
  Future<void> dispose() async {
    try {
      await _recorder?.dispose();
    } catch (_) {}
    _recorder = null;
  }
}

// ============================================================
// Riverpod provider
// ============================================================

// โปรเจกต์นี้ไม่มี global supabaseClientProvider — ใช้ Supabase.instance.client ตรงๆ
final sttServiceProvider = Provider<SttService>((ref) {
  final service = SttService(Supabase.instance.client);
  ref.onDispose(() => service.dispose());
  return service;
});
