import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// สถานะของ Vital Sign
enum VitalStatus {
  normal,
  warning,
  critical,
}

/// Extension สำหรับ VitalStatus
extension VitalStatusExtension on VitalStatus {
  /// สีพื้นหลัง
  Color get backgroundColor {
    switch (this) {
      case VitalStatus.normal:
        return AppColors.tagPassedBg;
      case VitalStatus.warning:
        return AppColors.tagPendingBg;
      case VitalStatus.critical:
        return AppColors.tagFailedBg;
    }
  }

  /// สีข้อความ
  Color get textColor {
    switch (this) {
      case VitalStatus.normal:
        return AppColors.tagPassedText;
      case VitalStatus.warning:
        return AppColors.tagPendingText;
      case VitalStatus.critical:
        return AppColors.tagFailedText;
    }
  }

  /// ข้อความแสดงสถานะ
  String get label {
    switch (this) {
      case VitalStatus.normal:
        return 'ปกติ';
      case VitalStatus.warning:
        return 'เฝ้าระวัง';
      case VitalStatus.critical:
        return 'ผิดปกติ';
    }
  }

  /// Icon indicator (ใช้ Unicode circle แทน emoji)
  String get indicator {
    switch (this) {
      case VitalStatus.normal:
        return '●'; // Unicode filled circle
      case VitalStatus.warning:
        return '●';
      case VitalStatus.critical:
        return '●';
    }
  }
}

/// Model สำหรับข้อมูล Vital Sign
class VitalSign {
  final int id;
  final int residentId;
  final int? sBP; // Systolic Blood Pressure
  final int? dBP; // Diastolic Blood Pressure
  final int? pulse; // PR - Pulse Rate
  final int? spO2; // Oxygen Saturation
  final double? temp; // Temperature
  final int? respiratoryRate; // RR
  final DateTime createdAt;

  VitalSign({
    required this.id,
    required this.residentId,
    this.sBP,
    this.dBP,
    this.pulse,
    this.spO2,
    this.temp,
    this.respiratoryRate,
    required this.createdAt,
  });

  /// สร้างจาก JSON (Supabase response)
  factory VitalSign.fromJson(Map<String, dynamic> json) {
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(json['created_at'] as String);
    } catch (_) {
      createdAt = DateTime.now();
    }

    return VitalSign(
      id: json['id'] as int,
      residentId: json['resident_id'] as int,
      sBP: json['sBP'] as int?,
      dBP: json['dBP'] as int?,
      pulse: json['PR'] as int?,
      spO2: json['O2'] as int?,
      temp: (json['Temp'] as num?)?.toDouble(),
      respiratoryRate: json['RR'] as int?,
      createdAt: createdAt,
    );
  }

  // ==========================================
  // Vital Sign Status Calculations
  // ==========================================

  /// สถานะความดันโลหิต (Systolic)
  VitalStatus get systolicStatus {
    if (sBP == null) return VitalStatus.normal;
    if (sBP! > 160 || sBP! < 80) return VitalStatus.critical;
    if ((sBP! >= 140 && sBP! <= 160) || (sBP! >= 80 && sBP! < 90)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  /// สถานะความดันโลหิต (Diastolic)
  VitalStatus get diastolicStatus {
    if (dBP == null) return VitalStatus.normal;
    if (dBP! > 100 || dBP! < 50) return VitalStatus.critical;
    if ((dBP! >= 90 && dBP! <= 100) || (dBP! >= 50 && dBP! < 60)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  /// สถานะความดันโลหิตรวม (ใช้ค่าที่แย่กว่า)
  VitalStatus get bpStatus {
    if (systolicStatus == VitalStatus.critical ||
        diastolicStatus == VitalStatus.critical) {
      return VitalStatus.critical;
    }
    if (systolicStatus == VitalStatus.warning ||
        diastolicStatus == VitalStatus.warning) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  /// สถานะชีพจร
  VitalStatus get pulseStatus {
    if (pulse == null) return VitalStatus.normal;
    if (pulse! > 120 || pulse! < 50) return VitalStatus.critical;
    if ((pulse! >= 100 && pulse! <= 120) || (pulse! >= 50 && pulse! < 60)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  /// สถานะ SpO2
  VitalStatus get spO2Status {
    if (spO2 == null) return VitalStatus.normal;
    if (spO2! < 90) return VitalStatus.critical;
    if (spO2! >= 90 && spO2! < 95) return VitalStatus.warning;
    return VitalStatus.normal;
  }

  /// สถานะอุณหภูมิ
  VitalStatus get tempStatus {
    if (temp == null) return VitalStatus.normal;
    if (temp! > 38.5 || temp! < 36.0) return VitalStatus.critical;
    if (temp! >= 37.5 && temp! <= 38.5) return VitalStatus.warning;
    return VitalStatus.normal;
  }

  /// สถานะอัตราการหายใจ
  VitalStatus get rrStatus {
    if (respiratoryRate == null) return VitalStatus.normal;
    if (respiratoryRate! > 24 || respiratoryRate! < 12) {
      return VitalStatus.critical;
    }
    if ((respiratoryRate! >= 20 && respiratoryRate! <= 24) ||
        (respiratoryRate! >= 12 && respiratoryRate! < 14)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  // ==========================================
  // Display Helpers
  // ==========================================

  /// แสดงความดันโลหิต
  String get bpDisplay {
    if (sBP == null && dBP == null) return '-';
    return '${sBP ?? '-'}/${dBP ?? '-'}';
  }

  /// แสดงชีพจร
  String get pulseDisplay => pulse != null ? '$pulse' : '-';

  /// แสดง SpO2
  String get spO2Display => spO2 != null ? '$spO2%' : '-';

  /// แสดงอุณหภูมิ
  String get tempDisplay =>
      temp != null ? '${temp!.toStringAsFixed(1)}°C' : '-';

  /// แสดงอัตราการหายใจ
  String get rrDisplay => respiratoryRate != null ? '$respiratoryRate' : '-';

  /// แสดงเวลาที่ผ่านมา
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'เมื่อกี้';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ชม.ที่แล้ว';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} วันที่แล้ว';
    } else {
      return '${(difference.inDays / 7).floor()} สัปดาห์ที่แล้ว';
    }
  }

  /// ตรวจสอบว่ามีข้อมูลหรือไม่
  bool get hasData =>
      sBP != null ||
      dBP != null ||
      pulse != null ||
      spO2 != null ||
      temp != null;
}
