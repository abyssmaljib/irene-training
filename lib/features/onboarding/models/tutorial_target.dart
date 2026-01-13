import 'package:flutter/material.dart';

/// Model สำหรับ Tutorial Step
/// แต่ละ step จะ highlight widget ที่มี GlobalKey และแสดง tooltip อธิบาย
///
/// ใช้กับ tutorial_coach_mark package
class TutorialTarget {
  /// Unique identifier สำหรับ step นี้
  /// ใช้สำหรับ tracking และ debugging
  final String id;

  /// หัวข้อของ step (แสดงเป็น title ใน tooltip)
  final String title;

  /// คำอธิบายรายละเอียดของ feature/widget นี้
  final String description;

  /// Tab index ที่ต้อง navigate ไปก่อนแสดง step นี้
  /// null = ไม่ต้อง navigate (อยู่ tab เดิม)
  /// 0 = Home, 1 = Checklist, 2 = Residents, 3 = Board, 4 = Settings
  final int? navigateToTab;

  /// GlobalKey ของ widget ที่ต้องการ highlight
  /// จะถูก assign ตอน runtime จาก TutorialKeys
  final GlobalKey? key;

  /// รูปร่างของ highlight
  /// - circle: วงกลม (เหมาะกับ icon, button กลม)
  /// - rectangle: สี่เหลี่ยม (เหมาะกับ card, list item)
  final TutorialShape shape;

  /// ตำแหน่งของ tooltip content
  /// - top: แสดงด้านบนของ highlight
  /// - bottom: แสดงด้านล่างของ highlight
  final ContentPosition contentPosition;

  const TutorialTarget({
    required this.id,
    required this.title,
    required this.description,
    this.navigateToTab,
    this.key,
    this.shape = TutorialShape.rectangle,
    this.contentPosition = ContentPosition.bottom,
  });

  /// สร้าง copy พร้อม GlobalKey ที่กำหนด
  /// ใช้ตอน runtime เมื่อ assign key จาก TutorialKeys
  TutorialTarget copyWithKey(GlobalKey key) {
    return TutorialTarget(
      id: id,
      title: title,
      description: description,
      navigateToTab: navigateToTab,
      key: key,
      shape: shape,
      contentPosition: contentPosition,
    );
  }
}

/// รูปร่างของ highlight area
enum TutorialShape {
  /// วงกลม - เหมาะกับ icon, FAB, avatar
  circle,

  /// สี่เหลี่ยมมุมโค้ง - เหมาะกับ card, button, input field
  rectangle,
}

/// ตำแหน่งของ tooltip content
enum ContentPosition {
  /// แสดงด้านบนของ highlight
  top,

  /// แสดงด้านล่างของ highlight
  bottom,
}

/// Class สำหรับเก็บ GlobalKeys ทั้งหมดที่ใช้ใน Tutorial
/// Singleton pattern เพื่อให้ทุก widget เข้าถึง keys เดียวกัน
class TutorialKeys {
  // Singleton instance
  static final TutorialKeys _instance = TutorialKeys._internal();
  factory TutorialKeys() => _instance;
  TutorialKeys._internal();

  // ===== Navigation Bar Keys =====
  /// Tab หน้าหลัก (Home)
  final GlobalKey homeTabKey = GlobalKey(debugLabel: 'homeTab');

  /// Tab Checklist
  final GlobalKey checklistTabKey = GlobalKey(debugLabel: 'checklistTab');

  /// Tab Residents (คนไข้)
  final GlobalKey residentsTabKey = GlobalKey(debugLabel: 'residentsTab');

  /// Tab Board (กระดานข่าว)
  final GlobalKey boardTabKey = GlobalKey(debugLabel: 'boardTab');

  /// Tab Settings
  final GlobalKey settingsTabKey = GlobalKey(debugLabel: 'settingsTab');

  // ===== Home Screen Keys =====
  /// ปุ่มลงเวลาเข้า-ออกงาน
  final GlobalKey clockInButtonKey = GlobalKey(debugLabel: 'clockInButton');

  /// Dropdown เลือกโซน
  final GlobalKey zoneSelectorKey = GlobalKey(debugLabel: 'zoneSelector');

  /// Card สรุปประจำเดือน
  final GlobalKey monthlySummaryKey = GlobalKey(debugLabel: 'monthlySummary');

  // ===== Checklist Screen Keys =====
  /// รายการ task แรก
  final GlobalKey taskItemKey = GlobalKey(debugLabel: 'taskItem');

  /// Filter tabs (เวร เช้า/บ่าย/ดึก)
  final GlobalKey shiftFilterKey = GlobalKey(debugLabel: 'shiftFilter');

  // ===== Residents Screen Keys =====
  /// Card คนไข้แรก
  final GlobalKey residentCardKey = GlobalKey(debugLabel: 'residentCard');

  /// Search bar
  final GlobalKey searchBarKey = GlobalKey(debugLabel: 'searchBar');

  // ===== Board Screen Keys =====
  /// Post แรก
  final GlobalKey postCardKey = GlobalKey(debugLabel: 'postCard');

  /// Filter tabs (ทั้งหมด/ยังไม่อ่าน)
  final GlobalKey boardFilterKey = GlobalKey(debugLabel: 'boardFilter');

  // ===== Settings Screen Keys =====
  /// Profile section
  final GlobalKey profileSectionKey = GlobalKey(debugLabel: 'profileSection');

  /// Logout button
  final GlobalKey logoutButtonKey = GlobalKey(debugLabel: 'logoutButton');
}
