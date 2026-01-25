import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service สำหรับเล่นเสียง effect ต่างๆ ในแอป
/// ใช้ Singleton pattern เพื่อให้มี AudioPlayer instance เดียว
class SoundService {
  SoundService._internal();

  static final SoundService _instance = SoundService._internal();

  /// Singleton instance
  static SoundService get instance => _instance;

  /// AudioPlayer instance สำหรับเล่นเสียงสั้นๆ
  final AudioPlayer _player = AudioPlayer();

  /// เสียง "หยดน้ำ" เมื่อ complete task
  static const String _taskCompleteSound = 'sound/water drop.mp3';

  /// เล่นเสียง complete task (เสียงหยดน้ำ)
  /// เล่นเมื่อ user กด "เรียบร้อย" และ task complete สำเร็จ
  Future<void> playTaskComplete() async {
    try {
      // ใช้ AssetSource เพื่อเล่นไฟล์จาก assets
      await _player.play(AssetSource(_taskCompleteSound));
    } catch (e) {
      // ไม่ต้อง throw error ถ้าเล่นเสียงไม่ได้
      // เพราะไม่ใช่ critical feature
      debugPrint('SoundService: Error playing task complete sound: $e');
    }
  }

  /// ปล่อย resources เมื่อไม่ใช้แล้ว
  void dispose() {
    _player.dispose();
  }
}
