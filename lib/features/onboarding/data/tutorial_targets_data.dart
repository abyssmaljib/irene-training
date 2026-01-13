import '../models/tutorial_target.dart';

/// Static data สำหรับ Tutorial Steps
/// กำหนดลำดับและเนื้อหาของแต่ละ step ใน tutorial
///
/// Flow:
/// 1. Home Tab → Clock-in → Zone Selector
/// 2. Checklist Tab → Task List
/// 3. Residents Tab → Resident Card
/// 4. Board Tab → Post Card
/// 5. Settings Tab → Profile
class TutorialTargetsData {
  /// List ของ tutorial steps ทั้งหมด
  /// เรียงตามลำดับที่ต้องการแสดง
  static List<TutorialTarget> getTargets(TutorialKeys keys) {
    return [
      // ===== Step 1: Home Tab =====
      TutorialTarget(
        id: 'home_tab',
        title: 'หน้าหลัก',
        description:
            'นี่คือหน้าหลักของคุณ\nดูสถานะการทำงาน สรุปประจำเดือน และกิจกรรมต่างๆ',
        navigateToTab: 0, // Navigate ไป Home tab ก่อน (ถ้ายังไม่อยู่)
        shape: TutorialShape.circle,
        contentPosition: ContentPosition.bottom,
      ).copyWithKey(keys.homeTabKey),

      // ===== Step 2: Clock-in Button =====
      TutorialTarget(
        id: 'clock_in',
        title: 'ลงเวลาเข้า-ออกงาน',
        description:
            'กดที่นี่เพื่อลงเวลาเข้างาน\nเมื่อเลิกงานก็กดอีกครั้งเพื่อลงเวลาออก',
        navigateToTab: null, // อยู่ Home อยู่แล้ว
        shape: TutorialShape.rectangle,
        contentPosition: ContentPosition.bottom,
      ).copyWithKey(keys.clockInButtonKey),

      // ===== Step 3: Zone Selector =====
      TutorialTarget(
        id: 'zone_selector',
        title: 'เลือกโซน',
        description: 'เลือกโซนที่คุณดูแลวันนี้\nระบบจะแสดงคนไข้และงานของโซนนั้น',
        navigateToTab: null,
        shape: TutorialShape.rectangle,
        contentPosition: ContentPosition.bottom,
      ).copyWithKey(keys.zoneSelectorKey),

      // ===== Step 4: Checklist Tab =====
      TutorialTarget(
        id: 'checklist_tab',
        title: 'เช็คลิสต์',
        description: 'กดที่นี่เพื่อดูรายการงานประจำวัน\nติ๊กเสร็จเมื่อทำงานเสร็จแล้ว',
        navigateToTab: 1, // Navigate ไป Checklist tab
        shape: TutorialShape.circle,
        contentPosition: ContentPosition.top,
      ).copyWithKey(keys.checklistTabKey),

      // ===== Step 5: Task Item =====
      TutorialTarget(
        id: 'task_item',
        title: 'รายการงาน',
        description:
            'นี่คือรายการงานของคุณ\nกดเพื่อดูรายละเอียด บันทึกปัญหา หรือแนบรูปภาพ',
        navigateToTab: null, // อยู่ Checklist อยู่แล้ว
        shape: TutorialShape.rectangle,
        contentPosition: ContentPosition.bottom,
      ).copyWithKey(keys.taskItemKey),

      // ===== Step 6: Residents Tab =====
      TutorialTarget(
        id: 'residents_tab',
        title: 'คนไข้',
        description: 'กดที่นี่เพื่อดูข้อมูลคนไข้\nดูประวัติ ยา และการดูแลพิเศษ',
        navigateToTab: 2, // Navigate ไป Residents tab
        shape: TutorialShape.circle,
        contentPosition: ContentPosition.top,
      ).copyWithKey(keys.residentsTabKey),

      // ===== Step 7: Resident Card =====
      TutorialTarget(
        id: 'resident_card',
        title: 'ข้อมูลคนไข้',
        description:
            'กดที่การ์ดเพื่อดูรายละเอียดคนไข้\nดูประวัติการดูแล ยา และข้อควรระวัง',
        navigateToTab: null,
        shape: TutorialShape.rectangle,
        contentPosition: ContentPosition.bottom,
      ).copyWithKey(keys.residentCardKey),

      // ===== Step 8: Board Tab =====
      TutorialTarget(
        id: 'board_tab',
        title: 'กระดานข่าว',
        description: 'กดที่นี่เพื่อดูประกาศและข่าวสาร\nอ่านโพสต์สำคัญจากทีม',
        navigateToTab: 3, // Navigate ไป Board tab
        shape: TutorialShape.circle,
        contentPosition: ContentPosition.top,
      ).copyWithKey(keys.boardTabKey),

      // ===== Step 9: Post Card =====
      TutorialTarget(
        id: 'post_card',
        title: 'โพสต์',
        description: 'กดที่โพสต์เพื่ออ่านรายละเอียด\nดูรูปภาพ วิดีโอ และความคิดเห็น',
        navigateToTab: null,
        shape: TutorialShape.rectangle,
        contentPosition: ContentPosition.bottom,
      ).copyWithKey(keys.postCardKey),

      // ===== Step 10: Settings Tab =====
      TutorialTarget(
        id: 'settings_tab',
        title: 'โปรไฟล์และตั้งค่า',
        description:
            'กดที่นี่เพื่อจัดการบัญชี\nดู badges ที่สะสม และออกจากระบบ\n\nเสร็จสิ้น! คุณพร้อมใช้งานแล้ว',
        navigateToTab: 4, // Navigate ไป Settings tab
        shape: TutorialShape.circle,
        contentPosition: ContentPosition.top,
      ).copyWithKey(keys.settingsTabKey),
    ];
  }

  /// ดึงเฉพาะ steps สำหรับ Home screen (สำหรับ quick tour)
  static List<TutorialTarget> getHomeOnlyTargets(TutorialKeys keys) {
    return [
      TutorialTarget(
        id: 'clock_in',
        title: 'ลงเวลาเข้า-ออกงาน',
        description:
            'กดที่นี่เพื่อลงเวลาเข้างาน\nเมื่อเลิกงานก็กดอีกครั้งเพื่อลงเวลาออก',
        shape: TutorialShape.rectangle,
        contentPosition: ContentPosition.bottom,
      ).copyWithKey(keys.clockInButtonKey),
      TutorialTarget(
        id: 'zone_selector',
        title: 'เลือกโซน',
        description: 'เลือกโซนที่คุณดูแลวันนี้\nระบบจะแสดงคนไข้และงานของโซนนั้น',
        shape: TutorialShape.rectangle,
        contentPosition: ContentPosition.bottom,
      ).copyWithKey(keys.zoneSelectorKey),
    ];
  }
}
