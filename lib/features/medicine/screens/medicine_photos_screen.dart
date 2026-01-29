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
// 3. เพิ่ม preload system (โหลดทุกรูปทีเดียวตอนเข้าหน้า):
//    - เข้าหน้า → โหลดรูปทุกมื้อพร้อมกัน แสดง Nyan Cat + progress bar
//    - โหลดทีละ batch (3 รูป) เพื่อป้องกัน memory spike
//    - โหลดเสร็จแล้วค่อยให้ทำงาน → ไม่มีสะดุดระหว่างทำงาน
// 4. จำกัด memCacheWidth ที่ 200-400px เพื่อลด memory usage
// 5. Round-based retry mechanism (ดีกว่า per-image retry):
//    - รอบ 1: โหลดทุกรูป → บางรูปอาจ fail
//    - รอบ 2-5: retry เฉพาะรูปที่ fail ในรอบก่อน
//    - ไม่ต้องรอรูปที่โหลดช้า/fail นาน → progress เร็วขึ้น
//    - ใช้ exponential backoff ระหว่างรอบ (500ms, 1000ms, ...)
// 6. เพิ่ม loading animation ที่น่ารัก:
//    - ข้อความตลกๆ 25 ข้อความ สลับทุก 3 วินาที
//    - Typewriter effect พิมพ์ทีละตัวอักษร (50ms/ตัว)
//    - ทำให้รอโหลดไม่น่าเบื่อ
//
// =============================================================================

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/toggle_switch.dart';
import '../../../core/widgets/success_popup.dart';
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

  // State สำหรับ preload รูปภาพ (โหลดทั้งหมดทีเดียวตอนเข้าหน้า)
  // เพื่อให้ทำงานได้ลื่นไหล ไม่มีสะดุดระหว่างทำงาน
  bool _isPrecaching = false; // กำลัง preload รูปอยู่หรือไม่
  int _precacheProgress = 0; // จำนวนรูปที่โหลดเสร็จแล้ว
  int _precacheTotal = 0; // จำนวนรูปทั้งหมด
  bool _allImagesPrecached = false; // โหลดรูปทั้งหมดเสร็จแล้วหรือยัง

  // ข้อความน่ารักๆ สลับไปมาระหว่างโหลด (แสดงคู่กับ Nyan Cat)
  static const _loadingMessages = [
    'กำลังเตรียมรูปยา รอแป๊บนะ...',
    'แมวกำลังวิ่งเก็บรูปอยู่...',
    'อดทนอีกนิด ใกล้เสร็จแล้ว...',
    'นับเม็ดยา นับๆๆ...',
    'รูปเยอะจัง รอหน่อยนะ...',
    'เหมียววิ่งเร็วที่สุดแล้วนะ...',
    'กำลังจัดยาใส่ถาด...',
    'เดี๋ยวเสร็จแล้วจะบอก...',
    'ยังอยู่นะ อย่าไปไหน...',
    'โหลดไปได้ครึ่งทางแล้ว...',
    'แมวขยันมากเลยวันนี้...',
    'รูปสวยๆ กำลังมา...',
    'เตรียมตัวทำงานได้เลย...',
    'แป๊บเดียวเอง รอได้รอได้...',
    'ถ้าช้าไป โทษเน็ตนะ...',
    'เหมียวไม่หนีไปไหนแน่นอน...',
    'โหลดเสร็จแล้วลุยกันเลย...',
    'ยาครบถ้วน พร้อมเสิร์ฟ...',
    'แมวส่งยาถึงที่แล้ว...',
    'เกือบเสร็จแล้ว สู้ๆ...',
    'แมวแวะดื่มกาแฟระหว่างทาง...',
    'รอก่อนนะ เดี๋ยวไปเอารูปมาให้...',
    'กำลังเรียงรูปให้อย่างสวยงาม...',
    'ไปต้มมาม่ารอ ได้นะ...',
    'อย่าเพิ่งหลับ แมวกำลังโหลดให้...',
  ];
  int _loadingMessageIndex = 0; // index ข้อความปัจจุบัน
  Timer? _messageTimer; // Timer สำหรับสลับข้อความทุก 3 วินาที

  // Typewriter effect - พิมพ์ทีละตัวอักษร
  String _displayedText = ''; // ข้อความที่แสดงอยู่ (พิมพ์ไปทีละตัว)
  Timer? _typewriterTimer; // Timer สำหรับพิมพ์ทีละตัวอักษร

  @override
  void initState() {
    super.initState();
    _loadMealGroups();
    _loadUserRole();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  /// เริ่ม typewriter effect - พิมพ์ข้อความทีละตัวอักษร
  void _startTypewriter() {
    _typewriterTimer?.cancel();
    _displayedText = '';
    final targetText = _loadingMessages[_loadingMessageIndex];
    int charIndex = 0;

    // พิมพ์ทีละตัวอักษรทุก 50ms
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (charIndex < targetText.length) {
        setState(() {
          _displayedText = targetText.substring(0, charIndex + 1);
        });
        charIndex++;
      } else {
        timer.cancel(); // พิมพ์เสร็จแล้ว หยุด timer
      }
    });
  }

  /// เริ่ม Timer สลับข้อความโหลดทุก 3 วินาที (เพิ่มเวลาให้พิมพ์เสร็จ)
  void _startMessageTimer() {
    _messageTimer?.cancel();
    _loadingMessageIndex = 0;
    _startTypewriter(); // เริ่มพิมพ์ข้อความแรก

    _messageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _loadingMessageIndex = (_loadingMessageIndex + 1) % _loadingMessages.length;
        });
        _startTypewriter(); // เริ่มพิมพ์ข้อความใหม่
      }
    });
  }

  /// หยุด Timer สลับข้อความ
  void _stopMessageTimer() {
    _messageTimer?.cancel();
    _typewriterTimer?.cancel();
    _messageTimer = null;
    _typewriterTimer = null;
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

      // Reset precache state เมื่อเปลี่ยนวันหรือ forceRefresh
      if (forceRefresh || !preserveExpanded) {
        _allImagesPrecached = false;
      }

      setState(() {
        _mealGroups = groups;
        _isLoading = false;
        _expandedIndex = newExpandedIndex;
      });

      // Preload รูปทั้งหมดทีเดียว เพื่อให้ทำงานได้ลื่นไหล
      if (!_allImagesPrecached) {
        await _precacheAllImages();
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

  /// Preload รูปยาทั้งหมดจากทุกมื้อเข้า cache ทีเดียว
  /// โหลดทีละ batch เพื่อป้องกัน memory spike บน iOS
  /// เรียกตอนเข้าหน้าครั้งแรก เพื่อให้ทำงานได้ลื่นไหลไม่สะดุด
  Future<void> _precacheAllImages() async {
    // ถ้าโหลดไปแล้ว ไม่ต้องโหลดซ้ำ
    if (_allImagesPrecached) return;

    // รวบรวม URL รูปทั้งหมดจากทุกมื้อ
    final List<String> imageUrls = [];

    for (final group in _mealGroups) {
      // รูปตัวอย่างยา (2C และ 3C) จาก medicine_summary
      for (final medicine in group.medicines) {
        if (medicine.photo2C != null && medicine.photo2C!.isNotEmpty) {
          imageUrls.add(medicine.photo2C!);
        }
        if (medicine.photo3C != null && medicine.photo3C!.isNotEmpty) {
          imageUrls.add(medicine.photo3C!);
        }
      }

      // รูปถ่ายจัดยา/เสิร์ฟยาจาก med_logs
      final log = group.medLog;
      if (log != null) {
        if (log.picture2CUrl != null && log.picture2CUrl!.isNotEmpty) {
          imageUrls.add(log.picture2CUrl!);
        }
        if (log.picture3CUrl != null && log.picture3CUrl!.isNotEmpty) {
          imageUrls.add(log.picture3CUrl!);
        }
      }
    }

    // ไม่มีรูปให้ preload - mark as done แล้ว return
    if (imageUrls.isEmpty) {
      _allImagesPrecached = true;
      return;
    }

    // ลบ duplicates
    final uniqueUrls = imageUrls.toSet().toList();
    final totalImages = uniqueUrls.length;

    setState(() {
      _isPrecaching = true;
      _precacheProgress = 0;
      _precacheTotal = totalImages;
    });

    // เริ่ม Timer สลับข้อความน่ารักๆ ระหว่างโหลด
    _startMessageTimer();

    // ========== Round-based retry ==========
    // แทนที่จะ retry แต่ละรูปหลายครั้งก่อนไปรูปถัดไป
    // เราจะโหลดทุกรูปก่อน แล้วค่อย retry รูปที่ fail
    // ทำให้ไม่ต้องรอรูปที่โหลดช้า/fail นาน
    //
    // รอบ 1: โหลดทุกรูป → สำเร็จ 7/10
    // รอบ 2: retry รูปที่ fail → สำเร็จเพิ่ม 2/3
    // รอบ 3: retry รูปที่ยัง fail → สำเร็จเพิ่ม 1/1
    // =========================================

    const maxRounds = 5; // จำนวนรอบ retry สูงสุด
    const batchSize = 3; // โหลดพร้อมกันทีละ 3 รูป

    List<String> pendingUrls = List.from(uniqueUrls);
    final Set<String> successUrls = {};

    for (int round = 1; round <= maxRounds && pendingUrls.isNotEmpty; round++) {
      if (!mounted) return;

      debugPrint('Precache round $round: ${pendingUrls.length} images pending');

      final List<String> failedInThisRound = [];

      // โหลดทีละ batch
      for (var i = 0; i < pendingUrls.length; i += batchSize) {
        if (!mounted) return;

        final end = (i + batchSize < pendingUrls.length)
            ? i + batchSize
            : pendingUrls.length;
        final batch = pendingUrls.sublist(i, end);

        // โหลด batch นี้พร้อมกัน และเก็บผลลัพธ์
        final results = await Future.wait(
          batch.map((url) => _precacheSingleImage(url)),
          eagerError: false,
        );

        // ตรวจสอบผลลัพธ์แต่ละรูป
        for (int j = 0; j < batch.length; j++) {
          if (results[j]) {
            successUrls.add(batch[j]);
          } else {
            failedInThisRound.add(batch[j]);
          }
        }

        if (!mounted) return;

        // อัพเดต progress (นับเฉพาะรูปที่สำเร็จ)
        setState(() {
          _precacheProgress = successUrls.length;
        });
      }

      // เตรียม pending list สำหรับรอบถัดไป
      pendingUrls = failedInThisRound;

      // ถ้าโหลดหมดแล้ว หยุดเลย
      if (pendingUrls.isEmpty) {
        debugPrint('Precache completed in round $round: all $totalImages images loaded');
        break;
      }

      // รอสักครู่ก่อน retry รอบถัดไป (exponential backoff)
      if (round < maxRounds && pendingUrls.isNotEmpty) {
        await Future.delayed(Duration(milliseconds: 500 * round));
      }
    }

    // Log ผลลัพธ์สุดท้าย
    if (pendingUrls.isNotEmpty) {
      debugPrint('Precache finished: ${successUrls.length}/$totalImages images loaded, ${pendingUrls.length} failed');
    }

    // เสร็จสิ้นการ preload ทั้งหมด
    if (mounted) {
      _stopMessageTimer(); // หยุด Timer สลับข้อความ
      _allImagesPrecached = true;
      setState(() => _isPrecaching = false);
    }
  }

  /// Preload รูปเดียวเข้า cache (ไม่มี retry - retry อยู่ใน _precacheAllImages)
  /// Return true ถ้าโหลดสำเร็จ, false ถ้า fail
  Future<bool> _precacheSingleImage(String url) async {
    // ตรวจสอบ mounted ก่อนใช้ context
    if (!mounted) return false;

    try {
      await precacheImage(
        CachedNetworkImageProvider(
          url,
          maxWidth: 200, // จำกัดขนาดใน memory (ตรงกับ memCacheWidth ใน widget)
        ),
        context,
      );
      return true; // โหลดสำเร็จ
    } catch (e) {
      debugPrint('Precache failed: $url - $e');
      return false; // โหลดไม่สำเร็จ
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

    // แสดง loading ตอน preload รูป พร้อม Nyan Cat 🐱
    if (_isPrecaching && _precacheTotal > 0) {
      final progress = _precacheProgress / _precacheTotal;
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Nyan Cat animation 🌈
              SizedBox(
                width: 120,
                height: 120,
                child: Lottie.asset(
                  'assets/animations/The Nyan Cat.json',
                  fit: BoxFit.contain,
                ),
              ),
              AppSpacing.verticalGapSm,
              // Progress bar แนวนอน
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.fullRadius,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.inputBorder,
                        color: AppColors.primary,
                        minHeight: 8,
                      ),
                    ),
                    AppSpacing.verticalGapSm,
                    // ข้อความน่ารักๆ พิมพ์ทีละตัวอักษร (typewriter effect)
                    Text(
                      _displayedText,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.verticalGapXs,
                    // แสดง progress
                    Text(
                      '$_precacheProgress / $_precacheTotal รูป (${(progress * 100).toInt()}%)',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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
  /// ถ้ามื้อนั้นยังไม่ได้ preload จะโหลดรูปก่อนแล้วค่อยแสดง
  /// เมื่อกดขยายมื้อใด มื้ออื่นจะปิดลง (accordion behavior)
  /// ไม่ต้อง preload เพราะโหลดรูปทั้งหมดตั้งแต่เข้าหน้าแล้ว
  void _onMealExpanded(int index) {
    // ถ้ากดมื้อเดิมที่ expand อยู่ = ปิด
    if (_expandedIndex == index) {
      setState(() => _expandedIndex = null);
      return;
    }

    // เปิดมื้อใหม่ (มื้อเดิมจะปิดอัตโนมัติ)
    setState(() => _expandedIndex = index);
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
        await SuccessPopup.show(context, emoji: '📷', message: 'บันทึกรูปเรียบร้อย');
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
