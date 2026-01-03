import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/toggle_switch.dart';
import '../../../core/services/user_service.dart';
import '../../checklist/models/system_role.dart';
import '../models/meal_photo_group.dart';
import '../services/camera_service.dart';
import '../services/medicine_service.dart';
import '../services/med_error_log_service.dart';
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
          child: Icon(
            Iconsax.clipboard_text,
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // App Bar
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              backgroundColor: AppColors.secondaryBackground,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.pop(context, _hasDataChanged),
                icon: Icon(
                  Iconsax.arrow_left,
                  color: AppColors.primaryText,
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.residentName,
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
              centerTitle: false,
              actions: [
                // Toggle overlay button
                IconButton(
                  onPressed: () {
                    setState(() => _showOverlay = !_showOverlay);
                  },
                  icon: Icon(
                    _showOverlay ? Iconsax.eye : Iconsax.eye_slash,
                    color: _showOverlay ? AppColors.primary : AppColors.textSecondary,
                  ),
                  tooltip: _showOverlay ? 'ซ่อนจำนวนเม็ดยา' : 'แสดงจำนวนเม็ดยา',
                ),
                // Toggle to medicine list (styled like checklist view toggle)
                _buildViewToggle(),
                SizedBox(width: AppSpacing.md), // Padding เท่ากับหน้า post/task
              ],
              expandedHeight: 270,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppColors.secondaryBackground,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        top: kToolbarHeight + 8,
                      ),
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
                  ),
                ),
              ),
            ),
          ];
        },
        body: RefreshIndicator(
          onRefresh: () => _loadMealGroups(forceRefresh: true),
          color: AppColors.primary,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
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
      );
    }

    // นับยาที่มีในวันนี้
    final totalMedicines = _mealGroups.fold<int>(
      0,
      (sum, group) => sum + group.medicineCount,
    );

    if (totalMedicines == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.image,
              size: 64,
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
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.md),
      itemCount: _mealGroups.length,
      itemBuilder: (context, index) {
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
      },
    );
  }

  /// เมื่อกดขยายมื้อใด มื้ออื่นจะปิดลง (accordion behavior)
  void _onMealExpanded(int index) {
    setState(() {
      // ถ้ากดมื้อเดิมที่ expand อยู่ = ปิด
      // ถ้ากดมื้อใหม่ = เปิดมื้อใหม่ (มื้อเดิมจะปิดอัตโนมัติ)
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else {
        _expandedIndex = index;
      }
    });
  }

  /// ถ่ายรูปยา พร้อมหน้า preview ให้หมุนรูปได้
  Future<void> _onTakePhoto(String mealKey, String photoType) async {
    try {
      // 1. ถ่ายรูป
      final file = await _cameraService.takePhoto();
      if (file == null) return; // user ยกเลิก

      if (!mounted) return;

      // 2. แสดงหน้า preview ให้ user ดูและหมุนรูป
      final mealLabel = _getMealLabel(mealKey);
      final confirmedFile = await PhotoPreviewScreen.show(
        context: context,
        imageFile: file,
        photoType: photoType,
        mealLabel: mealLabel,
      );

      if (confirmedFile == null) return; // user ยกเลิก/ถ่ายใหม่

      if (!mounted) return;

      // 3. แสดง loading และ upload
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

      // 4. อัพเดต med_log
      await _cameraService.updateMedLog(
        residentId: widget.residentId,
        mealKey: mealKey,
        date: _selectedDate,
        photoUrl: url,
        photoType: photoType,
      );

      // ปิด loading dialog
      if (mounted) Navigator.pop(context);

      // รีโหลดข้อมูลเพื่อแสดงรูปใหม่ (เก็บสถานะ expand ไว้)
      await _loadMealGroups(forceRefresh: true, preserveExpanded: true);

      // Mark ว่ามีการเปลี่ยนแปลงข้อมูล
      _hasDataChanged = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกรูปเรียบร้อยแล้ว'),
            backgroundColor: AppColors.tagPassedText,
          ),
        );
      }
    } catch (e) {
      // ปิด loading dialog ถ้ายังเปิดอยู่
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppColors.tagFailedText,
          ),
        );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('ยกเลิกการตรวจเรียบร้อยแล้ว'),
                backgroundColor: AppColors.primary,
              ),
            );
          }
        } else {
          throw Exception('Delete failed');
        }
      } catch (e) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: AppColors.tagFailedText,
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('บันทึกผลตรวจ "$status" เรียบร้อยแล้ว'),
              backgroundColor: AppColors.tagPassedText,
            ),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppColors.tagFailedText,
          ),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ลบรูปเรียบร้อยแล้ว'),
              backgroundColor: AppColors.tagPassedText,
            ),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppColors.tagFailedText,
          ),
        );
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
