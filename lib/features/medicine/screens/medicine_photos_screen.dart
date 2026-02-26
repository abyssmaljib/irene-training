// =============================================================================
// CRASH FIX LOG - หน้ารูปตัวอย่างยา
// =============================================================================
//
// ปัญหา: User report ว่าแอป crash ตอน scroll หน้ารูปตัวอย่างยา และตอนกดถ่ายรูป
//        โดยเฉพาะบน iOS เมื่อมียาหลายตัว (20-30 ตัว)
//
// สาเหตุที่พบ:
// 1. [meal_section_card.dart] addRepaintBoundaries: false
//    - ทำให้ทุก item ใน GridView ถูก repaint พร้อมกันตอน scroll
//    - ทำให้ memory spike และ crash บน iOS
//
// 2. [meal_section_card.dart] _LogPhotoNetworkImage ใช้ Image.network โดยตรง
//    - ไม่มี disk caching ต้องโหลดซ้ำทุกครั้ง
//    - ใช้ memory มากเกินไป
//
// 3. [medicine_photo_item.dart] รูปโหลดพร้อมกันหมดตอน scroll
//    - ทำให้ network request พุ่งขึ้นพร้อมกัน
//    - memory spike จากการ decode รูปพร้อมกัน
//
// การแก้ไข (28-29 ม.ค. 2026):
// 1. ลบ addRepaintBoundaries: false ออกจาก GridView.builder
// 2. เปลี่ยน Image.network เป็น CachedNetworkImage ใน _LogPhotoNetworkImage
// 3. จำกัด memCacheWidth ที่ 200-400px เพื่อลด memory usage
//
// การแก้ไข (2 ก.พ. 2026):
// 4. Clear image cache ก่อนเปิดกล้อง (ใน _onTakePhoto):
//    - ปัญหา: เปิดกล้อง + รูปยาเยอะ → memory spike → crash บน iOS
//    - แก้ไข: เรียก PaintingBinding.instance.imageCache.clear() ก่อนถ่ายรูป
//    - ผล: ปล่อย memory ให้กล้องใช้งานได้ ลด crash
//
// 5. เปลี่ยนจาก Preload-All เป็น Lazy Loading (iOS Best Practice):
//    - ปัญหาเดิม: preload รูปทั้งหมด 80-360+ รูป → รอนาน 30 วิ - 2 นาที
//    - แก้ไข: ใช้ Lazy Loading - โหลดรูปเฉพาะมื้อที่เปิด + มื้อถัดไป
//    - ผล: เข้าหน้าได้ทันที ไม่ต้องรอโหลด
//
// การแก้ไข (6 ก.พ. 2026):
// 6. Unmount content เมื่อ collapse สนิท (meal_section_card.dart):
//    - ปัญหา: Align(heightFactor:0) แค่ซ่อน ไม่ได้ unmount CachedNetworkImage
//    - decoded images ยังค้างใน memory แม้ section จะปิดแล้ว
//    - แก้ไข: เพิ่ม condition !_controller.isDismissed + AnimationStatusListener
//    - ผล: เมื่อ collapse เสร็จ → widgets unmount → decoded images ถูกปล่อยจริง
//
// 7. Collapse section + aggressive cache cleanup ก่อนเปิดกล้อง:
//    - ปัญหา: clear cache อย่างเดียวไม่พอ เพราะ live widgets ยังถือ reference
//    - แก้ไข: Collapse ก่อน → รอ unmount → clear cache → set cache limit = 0
//    - ผล: memory ว่างจริงก่อนเปิดกล้อง → ไม่ crash
//
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/services/image_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/toggle_switch.dart';
import '../../../core/widgets/success_popup.dart';
import '../../../core/services/user_service.dart';
import '../../checklist/models/system_role.dart';
import '../models/meal_photo_group.dart';
import '../services/camera_service.dart';
import '../services/medicine_service.dart';
import '../services/med_error_log_service.dart';
import '../../points/services/points_service.dart';
import '../widgets/day_picker.dart';
import '../widgets/meal_section_card.dart';
import 'medicine_list_screen.dart';
import 'photo_preview_screen.dart';

/// หน้ารูปตัวอย่างยา
class MedicinePhotosScreen extends StatefulWidget {
  final int residentId;
  final String residentName;

  const MedicinePhotosScreen({
    super.key,
    required this.residentId,
    required this.residentName,
  });

  @override
  State<MedicinePhotosScreen> createState() => _MedicinePhotosScreenState();
}

class _MedicinePhotosScreenState extends State<MedicinePhotosScreen> {
  final _medicineService = MedicineService.instance;
  final _cameraService = CameraService.instance;
  final _medErrorLogService = MedErrorLogService();

  DateTime _selectedDate = DateTime.now();
  bool _showFoiled = true; // true = แผง (2C), false = เม็ดยา (3C)
  bool _showOverlay = true; // แสดง overlay จำนวนเม็ดยา
  List<MealPhotoGroup> _mealGroups = [];
  bool _isLoading = true;
  int? _expandedIndex; // index ของมื้อที่ expand อยู่ (null = ไม่มีมื้อไหน expand)
  SystemRole? _systemRole; // system role ของ user ปัจจุบัน (สำหรับตรวจสิทธิ์ QC)
  bool _hasDataChanged = false; // track ว่ามีการเปลี่ยนแปลงข้อมูลยาหรือไม่

  @override
  void initState() {
    super.initState();
    _loadMealGroups();
    _loadUserRole();
  }

  /// โหลด system role ของ user ปัจจุบัน (สำหรับตรวจสิทธิ์ QC)
  Future<void> _loadUserRole() async {
    final systemRole = await UserService().getSystemRole();
    if (mounted) {
      setState(() => _systemRole = systemRole);
    }
  }

  /// โหลดข้อมูลยาแบ่งตามมื้อ
  /// [forceRefresh] = true จะบังคับ fetch ใหม่จาก API (ใช้ตอน pull-to-refresh)
  /// [preserveExpanded] = true จะเก็บสถานะ expanded ไว้ (ใช้หลังถ่ายรูป)
  Future<void> _loadMealGroups({
    bool forceRefresh = false,
    bool preserveExpanded = false,
  }) async {
    final previousExpandedIndex = _expandedIndex;

    setState(() => _isLoading = true);
    try {
      final groups = await _medicineService.getMedicinePhotosByMeal(
        widget.residentId,
        _selectedDate,
        forceRefresh: forceRefresh,
      );

      // กำหนด expanded index
      int? newExpandedIndex;
      if (preserveExpanded && previousExpandedIndex != null) {
        // เก็บ index เดิมไว้ (ถ้ายังอยู่ในช่วง)
        if (previousExpandedIndex < groups.length) {
          newExpandedIndex = previousExpandedIndex;
        }
      } else {
        // หา index แรกที่มียา สำหรับ expand เริ่มต้น
        for (int i = 0; i < groups.length; i++) {
          if (groups[i].hasMedicines) {
            newExpandedIndex = i;
            break;
          }
        }
      }

      setState(() {
        _mealGroups = groups;
        _isLoading = false;
        _expandedIndex = newExpandedIndex;
      });

      // Lazy Loading: preload รูปเฉพาะมื้อที่ expand อยู่ + มื้อถัดไป (background)
      if (newExpandedIndex != null) {
        _preloadMealImages(newExpandedIndex);
      }
    } catch (e) {
      debugPrint('Error loading meal groups: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onDateChanged(DateTime date) {
    setState(() => _selectedDate = date);
    _loadMealGroups();
  }

  void _onPhotoTypeChanged(int index) {
    setState(() => _showFoiled = index == 0);
  }

  /// Preload รูปเฉพาะมื้อที่ระบุ + มื้อถัดไป (ไม่ block UI)
  /// ใช้ Lazy Loading แบบ iOS best practice:
  /// - ไม่โหลดทุกรูปตอนเข้าหน้า (เหมือนเดิม)
  /// - โหลดเฉพาะมื้อที่เปิด + preload มื้อถัดไปล่วงหน้า
  /// - รูปโหลด background ไม่ block การทำงาน
  Future<void> _preloadMealImages(int mealIndex) async {
    // เก็บ indices ที่จะ preload: มื้อปัจจุบัน + มื้อถัดไป (ถ้ามี)
    final indicesToPreload = <int>[mealIndex];
    if (mealIndex + 1 < _mealGroups.length) {
      indicesToPreload.add(mealIndex + 1);
    }

    for (final index in indicesToPreload) {
      if (!mounted) return;

      final group = _mealGroups[index];
      final urls = <String>[];

      // รวบรวม URLs จากมื้อนี้
      // รูปตัวอย่างยา (2C และ 3C)
      for (final medicine in group.medicines) {
        if (medicine.photo2C?.isNotEmpty == true) urls.add(medicine.photo2C!);
        if (medicine.photo3C?.isNotEmpty == true) urls.add(medicine.photo3C!);
      }

      // รูปถ่ายจัดยา/เสิร์ฟยาจาก med_logs
      if (group.medLog?.picture2CUrl?.isNotEmpty == true) {
        urls.add(group.medLog!.picture2CUrl!);
      }
      if (group.medLog?.picture3CUrl?.isNotEmpty == true) {
        urls.add(group.medLog!.picture3CUrl!);
      }

      // Preload แบบ background (ไม่ block UI)
      // ใช้ Supabase Image Transformation เพื่อโหลดรูปขนาดเล็ก (200px)
      // ลดจาก ~1.5MB → ~50KB ช่วยแก้ปัญหา crash บน iOS
      for (final url in urls.toSet()) {
        if (!mounted) return;
        try {
          // Transform URL ให้โหลดรูปขนาดเล็กจาก server
          final thumbnailUrl = ImageService.getThumbnailUrl(url);
          await precacheImage(
            CachedNetworkImageProvider(thumbnailUrl, maxWidth: 200),
            context,
          );
        } catch (_) {
          // Ignore errors - CachedNetworkImage มี placeholder/error widget อยู่แล้ว
        }
      }
    }
  }

  /// Toggle button สำหรับสลับไปหน้ารายการยา (styled like checklist view toggle)
  Widget _buildViewToggle() {
    return Material(
      color: AppColors.accent1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MedicineListScreen(
                residentId: widget.residentId,
                residentName: widget.residentName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedClipboard,
            color: AppColors.primary,
            size: AppIconSize.lg,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // ใช้ IreneSecondaryAppBar แทน SliverAppBar เพื่อ consistency ทั้งแอป
      // หน้านี้มี titleWidget แบบ custom (2 บรรทัด) และมี actions
      appBar: IreneSecondaryAppBar(
        onBack: () => Navigator.pop(context, _hasDataChanged),
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'คุณ${widget.residentName}',
              style: AppTypography.title,
            ),
            Text(
              'รูปตัวอย่างยา',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          // Toggle overlay button
          IconButton(
            onPressed: () {
              setState(() => _showOverlay = !_showOverlay);
            },
            icon: HugeIcon(
              icon: _showOverlay ? HugeIcons.strokeRoundedView : HugeIcons.strokeRoundedViewOff,
              color: _showOverlay ? AppColors.primary : AppColors.textSecondary,
            ),
            tooltip: _showOverlay ? 'ซ่อนจำนวนเม็ดยา' : 'แสดงจำนวนเม็ดยา',
          ),
          // Toggle to medicine list (styled like checklist view toggle)
          _buildViewToggle(),
          SizedBox(width: AppSpacing.md),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadMealGroups(forceRefresh: true),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day Picker และ Photo Type Toggle (ย้ายมาอยู่ใน body แทน FlexibleSpaceBar)
              Container(
                color: AppColors.secondaryBackground,
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day Picker
                    DayPicker(
                      selectedDate: _selectedDate,
                      onDateChanged: _onDateChanged,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    // Photo Type Toggle
                    SegmentedControl(
                      options: const ['จัดยา (แผง)', 'เสิร์ฟยา (เม็ด)'],
                      selectedIndex: _showFoiled ? 0 : 1,
                      onChanged: _onPhotoTypeChanged,
                    ),
                  ],
                ),
              ),
              // Content
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // แสดง loading ตอนโหลดข้อมูล
    if (_isLoading) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              AppSpacing.verticalGapMd,
              Text(
                'กำลังโหลดข้อมูล...',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // นับยาที่มีในวันนี้
    final totalMedicines = _mealGroups.fold<int>(
      0,
      (sum, group) => sum + group.medicineCount,
    );

    if (totalMedicines == 0) {
      // ใช้ SizedBox เพื่อให้ pull-to-refresh ทำงานได้
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                size: AppIconSize.display,
                color: AppColors.textSecondary,
              ),
              AppSpacing.verticalGapMd,
              Text(
                'ไม่มียาในวันนี้',
                style: AppTypography.title.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ใช้ Column แทน ListView.builder เพราะอยู่ใน SingleChildScrollView แล้ว
    return Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: List.generate(_mealGroups.length, (index) {
          final group = _mealGroups[index];
          return MealSectionCard(
            key: ValueKey('meal_${group.mealKey}'),
            mealGroup: group,
            showFoiled: _showFoiled,
            showOverlay: _showOverlay,
            isExpanded: _expandedIndex == index,
            systemRole: _systemRole,
            onExpandChanged: () => _onMealExpanded(index),
            onTakePhoto: _onTakePhoto,
            onDeletePhoto: _onDeletePhoto,
            onQCPhoto: _onQCPhoto,
          );
        }),
      ),
    );
  }

  /// เมื่อกดขยายมื้อใด มื้ออื่นจะปิดลง (accordion behavior)
  /// และ preload รูปมื้อนี้ + มื้อถัดไป แบบ background (Lazy Loading)
  void _onMealExpanded(int index) {
    // ถ้ากดมื้อเดิมที่ expand อยู่ = ปิด
    if (_expandedIndex == index) {
      setState(() => _expandedIndex = null);
      return;
    }

    // เปิดมื้อใหม่ (มื้อเดิมจะปิดอัตโนมัติ)
    setState(() => _expandedIndex = index);

    // Preload รูปมื้อนี้ + มื้อถัดไป (background, ไม่ block UI)
    _preloadMealImages(index);
  }

  /// ถ่ายรูปยา พร้อมหน้า preview ให้หมุนรูปได้
  Future<void> _onTakePhoto(String mealKey, String photoType) async {
    try {
      // === Phase 1: ปล่อย memory ก่อนเปิดกล้อง ===
      // ปัญหาเดิม: clear image cache อย่างเดียวไม่พอ เพราะ CachedNetworkImage widgets
      // ยังคง mount อยู่ใน widget tree (แม้ collapse แล้วก็ยังถือ decoded images)
      //
      // แก้ไข: Collapse section → AnimationStatusListener trigger setState
      // → content ถูก unmount → decoded images ถูกปล่อยจริง → memory ว่าง
      final previousExpandedIndex = _expandedIndex;
      setState(() => _expandedIndex = null);

      // รอ animation collapse เสร็จ (200ms) + StatusListener setState + rebuild
      // เพื่อให้ CachedNetworkImage widgets ถูก unmount จริง
      await Future.delayed(const Duration(milliseconds: 300));

      // Clear image cache หลัง widgets ถูก unmount แล้ว
      // ตอนนี้ไม่มี live references → decoded images ถูกปล่อยจาก memory จริง
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // ลด cache limit ชั่วคราวเป็น 0 เพื่อป้องกันไม่ให้ cache รูปใหม่ระหว่างเปิดกล้อง
      // กล้อง iOS ใช้ memory สูงมาก ต้องให้ memory ว่างมากที่สุด
      final savedMaxSize = PaintingBinding.instance.imageCache.maximumSize;
      final savedMaxBytes = PaintingBinding.instance.imageCache.maximumSizeBytes;
      PaintingBinding.instance.imageCache.maximumSize = 0;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 0;
      debugPrint('MedicinePhotosScreen: Collapsed sections + cleared caches before camera');

      // === Phase 2: ถ่ายรูป ===
      final file = await _cameraService.takePhoto();

      // คืนค่า cache limits ทันทีหลังกล้องปิด
      PaintingBinding.instance.imageCache.maximumSize = savedMaxSize;
      PaintingBinding.instance.imageCache.maximumSizeBytes = savedMaxBytes;

      if (file == null) {
        // User ยกเลิก → คืน expanded state เดิม
        if (mounted) setState(() => _expandedIndex = previousExpandedIndex);
        return;
      }

      if (!mounted) return;

      // === Phase 3: แสดง preview ===
      final mealLabel = _getMealLabel(mealKey);
      final confirmedFile = await PhotoPreviewScreen.show(
        context: context,
        imageFile: file,
        photoType: photoType,
        mealLabel: mealLabel,
      );

      if (confirmedFile == null) {
        // User ยกเลิก/ถ่ายใหม่ → คืน expanded state เดิม
        if (mounted) setState(() => _expandedIndex = previousExpandedIndex);
        return;
      }

      if (!mounted) return;

      // คืน expandedIndex ก่อน upload เพื่อให้ preserveExpanded ทำงานถูกต้อง
      _expandedIndex = previousExpandedIndex;

      // === Phase 4: Upload ===
      _showLoadingDialog();

      final url = await _cameraService.uploadPhoto(
        file: confirmedFile,
        residentId: widget.residentId,
        mealKey: mealKey,
        photoType: photoType,
        date: _selectedDate,
      );

      if (url == null) {
        if (mounted) Navigator.pop(context);
        throw Exception('Upload failed');
      }

      // อัพเดต med_log
      await _cameraService.updateMedLog(
        residentId: widget.residentId,
        mealKey: mealKey,
        date: _selectedDate,
        photoUrl: url,
        photoType: photoType,
      );

      // บันทึก points สำหรับถ่ายรูปยา (ได้เฉพาะครั้งแรกต่อรูป)
      final userId = UserService().effectiveUserId;
      if (userId != null) {
        await PointsService().recordMedicinePhotoTaken(
          userId: userId,
          residentId: widget.residentId,
          date: _selectedDate,
          mealKey: mealKey,
          photoType: photoType,
        );
      }

      // ปิด loading dialog
      if (mounted) Navigator.pop(context);

      // รีโหลดข้อมูลเพื่อแสดงรูปใหม่ (เก็บสถานะ expand ไว้)
      await _loadMealGroups(forceRefresh: true, preserveExpanded: true);

      // Mark ว่ามีการเปลี่ยนแปลงข้อมูล
      _hasDataChanged = true;

      if (mounted) {
        await SuccessPopup.show(context, emoji: '📷', message: 'บันทึกรูปเรียบร้อย');
      }
    } catch (e) {
      // ปิด loading dialog ถ้ายังเปิดอยู่
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        AppSnackbar.error(context, 'เกิดข้อผิดพลาด: $e');
      }
    }
  }

  /// แปลง mealKey เป็น label สำหรับแสดงใน preview
  String _getMealLabel(String mealKey) {
    if (mealKey.contains('morning') || mealKey.contains('เช้า')) {
      if (mealKey.contains('before') || mealKey.contains('ก่อน')) {
        return 'ก่อนอาหารเช้า';
      }
      return 'หลังอาหารเช้า';
    } else if (mealKey.contains('noon') || mealKey.contains('กลางวัน')) {
      if (mealKey.contains('before') || mealKey.contains('ก่อน')) {
        return 'ก่อนอาหารกลางวัน';
      }
      return 'หลังอาหารกลางวัน';
    } else if (mealKey.contains('evening') || mealKey.contains('เย็น')) {
      if (mealKey.contains('before') || mealKey.contains('ก่อน')) {
        return 'ก่อนอาหารเย็น';
      }
      return 'หลังอาหารเย็น';
    }
    return 'ก่อนนอน';
  }

  /// QC รูปยา (สำหรับ admin/superAdmin)
  Future<void> _onQCPhoto(String mealKey, String photoType, String status) async {
    final is2C = photoType == '2C';

    // ถ้าเป็น __reset__ ให้ลบ record แทน
    if (status == '__reset__') {
      _showLoadingDialog(message: 'กำลังยกเลิก...');

      try {
        final success = await _medErrorLogService.deleteErrorLog(
          residentId: widget.residentId,
          date: _selectedDate,
          meal: mealKey,
          is2CPicture: is2C,
        );

        if (mounted) Navigator.pop(context);

        if (success) {
          await _loadMealGroups(forceRefresh: true, preserveExpanded: true);

          // Mark ว่ามีการเปลี่ยนแปลงข้อมูล
          _hasDataChanged = true;

          if (mounted) {
            await SuccessPopup.show(context, emoji: '↩️', message: 'ยกเลิกการตรวจแล้ว');
          }
        } else {
          throw Exception('Delete failed');
        }
      } catch (e) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (mounted) {
          AppSnackbar.error(context, 'เกิดข้อผิดพลาด: $e');
        }
      }
      return;
    }

    // บันทึกผลการตรวจปกติ
    _showLoadingDialog(message: 'กำลังบันทึก...');

    try {
      final success = await _medErrorLogService.saveErrorLog(
        residentId: widget.residentId,
        date: _selectedDate,
        meal: mealKey,
        is2CPicture: is2C,
        replyNurseMark: status,
      );

      // ปิด loading dialog
      if (mounted) Navigator.pop(context);

      if (success) {
        // รีโหลดข้อมูลเพื่อแสดงสถานะใหม่ (เก็บสถานะ expand ไว้)
        await _loadMealGroups(forceRefresh: true, preserveExpanded: true);

        // Mark ว่ามีการเปลี่ยนแปลงข้อมูล
        _hasDataChanged = true;

        if (mounted) {
          await SuccessPopup.show(context, emoji: '✅', message: 'บันทึกผลตรวจแล้ว');
        }
      } else {
        throw Exception('Save failed');
      }
    } catch (e) {
      // ปิด loading dialog ถ้ายังเปิดอยู่
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        AppSnackbar.error(context, 'เกิดข้อผิดพลาด: $e');
      }
    }
  }

  /// ลบรูปยา
  Future<void> _onDeletePhoto(String mealKey, String photoType) async {
    _showLoadingDialog(message: 'กำลังลบรูป...');

    try {
      final success = await _cameraService.deletePhoto(
        residentId: widget.residentId,
        mealKey: mealKey,
        date: _selectedDate,
        photoType: photoType,
      );

      // ปิด loading dialog
      if (mounted) Navigator.pop(context);

      if (success) {
        // รีโหลดข้อมูลเพื่อแสดงสถานะใหม่ (เก็บสถานะ expand ไว้)
        await _loadMealGroups(forceRefresh: true, preserveExpanded: true);

        // Mark ว่ามีการเปลี่ยนแปลงข้อมูล
        _hasDataChanged = true;

        if (mounted) {
          await SuccessPopup.show(context, emoji: '🗑️', message: 'ลบรูปเรียบร้อย');
        }
      } else {
        throw Exception('Delete failed');
      }
    } catch (e) {
      // ปิด loading dialog ถ้ายังเปิดอยู่
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        AppSnackbar.error(context, 'เกิดข้อผิดพลาด: $e');
      }
    }
  }

  void _showLoadingDialog({String message = 'กำลังบันทึกรูป...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadius.mediumRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                message,
                style: AppTypography.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
