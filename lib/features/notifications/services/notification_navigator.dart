import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/app_toast.dart';

import '../../board/screens/board_screen.dart';
import '../../checklist/services/task_service.dart';
import '../../incident_reflection/screens/incident_chat_screen.dart';
import '../../incident_reflection/services/incident_service.dart';
import '../../learning/models/topic_with_progress.dart';
import '../../learning/screens/topic_detail_screen.dart';
import '../../learning/screens/badge_collection_screen.dart';
import '../../navigation/screens/main_navigation_screen.dart';
import '../../points/screens/leaderboard_screen.dart';
import '../../residents/screens/resident_detail_screen.dart';
import '../../checklist/screens/task_detail_screen.dart';
import '../models/app_notification.dart';

/// Utility class สำหรับ navigate จาก notification ไปหน้าที่เกี่ยวข้อง
///
/// รองรับทุก NotificationType:
/// - post/comment → PostDetailScreen (ใช้ postId)
/// - task → TaskDetailScreen (ต้อง fetch TaskLog ก่อน)
/// - badge → BadgeCollectionScreen (ไม่ต้อง param)
/// - review → TopicDetailScreen (ต้อง fetch TopicWithProgress ก่อน)
/// - assignment → ResidentDetailScreen (ใช้ residentId)
/// - calendar → navigate ไป Checklist tab
/// - incident → IncidentChatScreen (ต้อง fetch Incident ก่อน)
/// - points → PointsHistoryScreen (ไม่ต้อง param)
/// - system → ไม่ navigate (แสดงแค่ detail)
class NotificationNavigator {
  NotificationNavigator._();

  /// Navigate ไปหน้าที่เกี่ยวข้องกับ notification
  /// แสดง loading snackbar ขณะ fetch data สำหรับ type ที่ต้องโหลดข้อมูลก่อน
  /// ถ้า fetch ไม่สำเร็จ → แสดง error snackbar
  static Future<void> navigateToTarget(
    BuildContext context,
    AppNotification notification,
  ) async {
    final referenceId = notification.referenceId;

    switch (notification.type) {
      // --- ประเภทที่ใช้แค่ ID (ไม่ต้อง fetch) ---

      case NotificationType.post:
      case NotificationType.comment:
        // PostDetailScreen รับแค่ postId แล้ว fetch เอง
        if (referenceId == null) {
          _showError(context, 'ไม่พบข้อมูลโพสต์');
          return;
        }
        _push(context, PostDetailScreen(postId: referenceId));

      case NotificationType.assignment:
        // ResidentDetailScreen รับแค่ residentId แล้ว fetch เอง
        if (referenceId == null) {
          _showError(context, 'ไม่พบข้อมูลผู้รับบริการ');
          return;
        }
        _push(context, ResidentDetailScreen(residentId: referenceId));

      // --- ประเภทที่ไม่ต้องใช้ referenceId ---

      case NotificationType.badge:
        _push(context, const BadgeCollectionScreen());

      case NotificationType.points:
        // ไปหน้า "คะแนนและอันดับ" (มี tab คะแนน/อันดับ/รางวัล)
        _push(context, const LeaderboardScreen());

      case NotificationType.calendar:
        // ไม่มี Calendar detail screen → ไปที่ Checklist tab (Tab 1)
        MainNavigationScreen.navigateToTab(context, 1);
        // Pop กลับจาก NotificationDetailScreen ไปหน้าหลัก
        Navigator.of(context).popUntil((route) => route.isFirst);

      // --- ประเภทที่ต้อง fetch data ก่อน navigate ---

      case NotificationType.task:
        if (referenceId == null) {
          _showError(context, 'ไม่พบข้อมูลงาน');
          return;
        }
        await _navigateWithLoading(
          context,
          fetchData: () => TaskService.instance.getTaskByLogId(referenceId),
          onSuccess: (task) {
            if (task == null) {
              _showError(context, 'ไม่พบข้อมูลงานนี้แล้ว');
              return;
            }
            _push(context, TaskDetailScreen(task: task));
          },
        );

      case NotificationType.review:
        if (referenceId == null) {
          _showError(context, 'ไม่พบข้อมูลบทเรียน');
          return;
        }
        await _navigateWithLoading(
          context,
          fetchData: () => _fetchTopicById(referenceId.toString()),
          onSuccess: (topic) {
            if (topic == null) {
              _showError(context, 'ไม่พบข้อมูลบทเรียนนี้แล้ว');
              return;
            }
            _push(context, TopicDetailScreen(topic: topic));
          },
        );

      case NotificationType.incident:
        if (referenceId == null) {
          _showError(context, 'ไม่พบข้อมูลเหตุการณ์');
          return;
        }
        await _navigateWithLoading(
          context,
          fetchData: () => IncidentService.instance.getIncidentById(referenceId),
          onSuccess: (incident) {
            if (incident == null) {
              _showError(context, 'ไม่พบข้อมูลเหตุการณ์นี้แล้ว');
              return;
            }
            _push(context, IncidentChatScreen(incident: incident));
          },
        );

      case NotificationType.system:
        // system type ไม่มีหน้าเป้าหมาย → ไม่ทำอะไร
        break;
    }
  }

  /// ตรวจว่า notification นี้มีหน้าเป้าหมายให้ navigate ไปไหม
  /// ใช้สำหรับแสดง/ซ่อนปุ่ม "ดูเพิ่มเติม"
  static bool hasNavigableTarget(AppNotification notification) {
    switch (notification.type) {
      // system ไม่มีหน้าเป้าหมาย
      case NotificationType.system:
        return false;

      // types ที่ไม่ต้องใช้ referenceId
      case NotificationType.badge:
      case NotificationType.points:
      case NotificationType.calendar:
        return true;

      // types ที่ต้องมี referenceId
      case NotificationType.post:
      case NotificationType.comment:
      case NotificationType.task:
      case NotificationType.review:
      case NotificationType.assignment:
      case NotificationType.incident:
        return notification.referenceId != null;
    }
  }

  /// ข้อความสำหรับปุ่ม navigate ตามประเภท notification
  /// ใช้คำพูดที่เป็นธรรมชาติ กระตุ้นให้ user อยากกด
  static String getTargetLabel(AppNotification notification) {
    switch (notification.type) {
      case NotificationType.post:
        return 'ไปอ่านโพสต์เลย';
      case NotificationType.comment:
        return 'ไปดูความคิดเห็นเลย';
      case NotificationType.task:
        return 'ไปเช็คงานกัน';
      case NotificationType.badge:
        return 'ไปดูเหรียญรางวัลเลย!';
      case NotificationType.review:
        return 'ไปทบทวนบทเรียนกัน!';
      case NotificationType.assignment:
        return 'ไปดูข้อมูลผู้รับบริการ';
      case NotificationType.calendar:
        return 'ไปดูตารางงานเลย';
      case NotificationType.incident:
        return 'ไปถอดบทเรียนกันเลย!';
      case NotificationType.points:
        return 'ไปดูรายละเอียดคะแนน';
      case NotificationType.system:
        return '';
    }
  }

  // --- Private helpers ---

  /// Push หน้าใหม่ด้วย MaterialPageRoute
  static void _push(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// แสดง error snackbar
  static void _showError(BuildContext context, String message) {
    AppToast.error(context, message);
  }

  /// Fetch data แล้ว navigate พร้อมแสดง loading snackbar
  /// ใช้สำหรับ type ที่ต้องโหลดข้อมูลก่อน (task, review, incident)
  static Future<void> _navigateWithLoading<T>(
    BuildContext context, {
    required Future<T?> Function() fetchData,
    required void Function(T?) onSuccess,
  }) async {
    // แสดง loading toast ขณะ fetch
    // AppToast.info จะแสดงผ่าน Overlay (auto-dismiss หลัง 3 วิ)
    AppToast.info(context, 'กำลังโหลด...');

    try {
      final data = await fetchData();
      onSuccess(data);
    } catch (e) {
      // แสดง error toast (Overlay ใหม่จะแทนที่ loading อัตโนมัติ)
      if (context.mounted) {
        _showError(context, 'เกิดข้อผิดพลาดในการโหลดข้อมูล');
      }
      debugPrint('NotificationNavigator: fetch error: $e');
    }
  }

  /// Fetch TopicWithProgress จาก view training_v_topics_with_progress
  /// ใช้สำหรับ notification ประเภท review
  static Future<TopicWithProgress?> _fetchTopicById(String topicId) async {
    try {
      final response = await Supabase.instance.client
          .from('training_v_topics_with_progress')
          .select()
          .eq('topic_id', topicId)
          .maybeSingle();
      if (response == null) return null;
      return TopicWithProgress.fromJson(response);
    } catch (e) {
      debugPrint('NotificationNavigator: fetchTopicById error: $e');
      return null;
    }
  }
}
