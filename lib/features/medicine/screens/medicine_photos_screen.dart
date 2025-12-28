import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/toggle_switch.dart';
import '../models/meal_photo_group.dart';
import '../services/camera_service.dart';
import '../services/medicine_service.dart';
import '../widgets/day_picker.dart';
import '../widgets/meal_section_card.dart';
import 'medicine_list_screen.dart';

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

  DateTime _selectedDate = DateTime.now();
  bool _showFoiled = true; // true = แผง (2C), false = เม็ดยา (3C)
  bool _showOverlay = true; // แสดง overlay จำนวนเม็ดยา
  List<MealPhotoGroup> _mealGroups = [];
  bool _isLoading = true;
  int? _expandedIndex; // index ของมื้อที่ expand อยู่ (null = ไม่มีมื้อไหน expand)

  @override
  void initState() {
    super.initState();
    _loadMealGroups();
  }

  /// โหลดข้อมูลยาแบ่งตามมื้อ
  /// [forceRefresh] = true จะบังคับ fetch ใหม่จาก API (ใช้ตอน pull-to-refresh)
  Future<void> _loadMealGroups({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final groups = await _medicineService.getMedicinePhotosByMeal(
        widget.residentId,
        _selectedDate,
        forceRefresh: forceRefresh,
      );
      // หา index แรกที่มียา สำหรับ expand เริ่มต้น
      int? firstWithMedicines;
      for (int i = 0; i < groups.length; i++) {
        if (groups[i].hasMedicines) {
          firstWithMedicines = i;
          break;
        }
      }

      setState(() {
        _mealGroups = groups;
        _isLoading = false;
        _expandedIndex = firstWithMedicines;
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
                onPressed: () => Navigator.pop(context),
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
                // Shortcut to medicine list
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MedicineListScreen(
                          residentId: widget.residentId,
                          residentName: widget.residentName,
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    Iconsax.clipboard_text,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'รายการยา',
                ),
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
                SizedBox(width: 8),
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
          onExpandChanged: () => _onMealExpanded(index),
          onTakePhoto: _onTakePhoto,
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

  /// ถ่ายรูปยา
  Future<void> _onTakePhoto(String mealKey, String photoType) async {
    // แสดง loading indicator
    _showLoadingDialog();

    try {
      final url = await _cameraService.captureAndUpload(
        residentId: widget.residentId,
        mealKey: mealKey,
        photoType: photoType,
        date: _selectedDate,
      );

      // ปิด loading dialog
      if (mounted) Navigator.pop(context);

      if (url != null) {
        // รีโหลดข้อมูลเพื่อแสดงรูปใหม่
        await _loadMealGroups(forceRefresh: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('บันทึกรูปเรียบร้อยแล้ว'),
              backgroundColor: AppColors.tagPassedText,
            ),
          );
        }
      }
    } catch (e) {
      // ปิด loading dialog
      if (mounted) Navigator.pop(context);

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

  void _showLoadingDialog() {
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
                'กำลังบันทึกรูป...',
                style: AppTypography.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
