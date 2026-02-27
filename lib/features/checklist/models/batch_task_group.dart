import 'task_log.dart';

/// Model สำหรับ batch group ของ tasks ที่เหมือนกัน
/// Group key = "${task_title}|${zoneId}|${timeBlock}"
/// เช่น "พลิกตัว|3|07:00 - 09:00" = task พลิกตัวในโซน 3 ช่วง 07:00-09:00
///
/// ใช้เมื่อ batch mode เปิด — รวม task เดียวกันข้ามคนไข้ในโซนเดียวกัน
/// เพื่อให้ user ทำงานเป็นชุดๆ แทนที่จะเปิดทีละ task
class BatchTaskGroup {
  /// Key สำหรับ identify group: "${title}|${zoneId}|${timeBlock}"
  final String groupKey;

  /// ชื่อ task (เช่น "พลิกตัว", "เช็คเตียงลม")
  final String title;

  /// Zone ID ที่ task อยู่
  final int zoneId;

  /// ชื่อโซน (เช่น "โซน A")
  final String zoneName;

  /// Time block (เช่น "07:00 - 09:00")
  final String timeBlock;

  /// รายการ tasks ทั้งหมดใน group นี้ (แต่ละ task = 1 คนไข้)
  final List<TaskLog> tasks;

  /// รูปตัวอย่างจาก task template (ถ้ามี) — ใช้แสดงใน BatchTaskScreen
  final String? sampleImageUrl;

  const BatchTaskGroup({
    required this.groupKey,
    required this.title,
    required this.zoneId,
    required this.zoneName,
    required this.timeBlock,
    required this.tasks,
    this.sampleImageUrl,
  });

  /// จำนวน task ที่จัดการแล้ว (มี status ใดๆ: complete/problem/refer/postpone)
  int get handledCount => tasks.where((t) => t.status != null).length;

  /// จำนวน task ที่ complete จริง (status = 'complete' หรือ 'refer')
  int get completedCount => tasks.where((t) => t.isDone).length;

  /// จำนวน task ที่ติดปัญหา
  int get problemCount => tasks.where((t) => t.isProblem).length;

  /// จำนวน task ที่เลื่อน
  int get postponedCount => tasks.where((t) => t.isPostponed).length;

  /// จำนวน task ที่ไม่อยู่ศูนย์
  int get referredCount => tasks.where((t) => t.isReferred).length;

  /// จำนวน task ทั้งหมดใน group
  int get totalCount => tasks.length;

  /// จำนวน task ที่ยังไม่ได้ทำ (status = null)
  int get pendingCount => tasks.where((t) => t.status == null).length;

  /// เปอร์เซ็นต์ความคืบหน้า (0.0 - 1.0) — นับจาก task ที่จัดการแล้วทุกสถานะ
  double get progress =>
      totalCount > 0 ? handledCount / totalCount : 0.0;

  /// ทุก task ใน group จัดการหมดแล้วหรือยัง
  bool get isAllDone => handledCount == totalCount;

  /// ทุก task เสร็จสมบูรณ์จริงๆ (ไม่มี problem/postpone)
  bool get isAllCompleted => completedCount == totalCount;

  /// มี task ที่ไม่ใช่ complete อยู่ (problem/postpone/refer)
  bool get hasNonCompleteStatus =>
      problemCount > 0 || postponedCount > 0;

  /// มี task ที่ต้องถ่ายรูปหรือไม่ (ดูจาก task แรก เพราะ template เดียวกัน)
  bool get requireImage => tasks.isNotEmpty && tasks.first.requireImage;

  /// Task type (เช่น "การดูแลผู้ป่วย") — ดึงจาก task แรก
  String? get taskType => tasks.isNotEmpty ? tasks.first.taskType : null;

  /// สร้าง group key จาก TaskLog
  /// ใช้ title (trim แล้ว) + zoneId + timeBlock เป็น key
  /// trim เพราะ DB มี title ที่มี space ต่อท้ายไม่ consistent
  static String buildGroupKey(TaskLog task) {
    return '${(task.title ?? '').trim()}|${task.zoneId ?? 0}|${task.timeBlock ?? ''}';
  }
}
