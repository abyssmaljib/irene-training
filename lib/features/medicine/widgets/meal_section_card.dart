import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../checklist/models/system_role.dart';
import '../models/med_log.dart';
import '../models/med_error_log.dart';
import '../models/meal_photo_group.dart';
import 'medicine_photo_item.dart';

/// Card สำหรับแสดงยาในแต่ละมื้อ (Expandable)
/// ใช้ isExpanded + onExpandChanged สำหรับ controlled accordion behavior
class MealSectionCard extends StatefulWidget {
  final MealPhotoGroup mealGroup;
  final bool showFoiled; // true = แผง (2C), false = เม็ดยา (3C)
  final bool showOverlay; // แสดง overlay จำนวนเม็ดยา
  final bool isExpanded; // controlled from parent
  final SystemRole? systemRole; // system role ของ user ปัจจุบัน (สำหรับตรวจสิทธิ์ QC)
  final VoidCallback? onExpandChanged; // callback when tapped
  final Future<void> Function(String mealKey, String photoType)? onTakePhoto; // callback สำหรับถ่ายรูป
  final Future<void> Function(String mealKey, String photoType)? onDeletePhoto; // callback สำหรับลบรูป
  final Future<void> Function(String mealKey, String photoType, String status)? onQCPhoto; // callback สำหรับ QC

  const MealSectionCard({
    super.key,
    required this.mealGroup,
    this.showFoiled = true,
    this.showOverlay = true,
    this.isExpanded = false,
    this.systemRole,
    this.onExpandChanged,
    this.onTakePhoto,
    this.onDeletePhoto,
    this.onQCPhoto,
  });

  @override
  State<MealSectionCard> createState() => _MealSectionCardState();
}

class _MealSectionCardState extends State<MealSectionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _heightFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Set initial animation value based on isExpanded
    if (widget.isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(MealSectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate when isExpanded changes from parent
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Notify parent to handle accordion behavior
    widget.onExpandChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.mealGroup;
    final hasMedicines = group.hasMedicines;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.smallRadius,
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        children: [
          // Header - always visible
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasMedicines ? _handleTap : null,
              borderRadius: AppRadius.smallRadius,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // Meal icon
                    _buildMealIcon(group.mealKey),
                    AppSpacing.horizontalGapSm,

                    // Label + Before/After badge
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            _getMealTimeLabel(group.mealKey),
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: hasMedicines
                                  ? AppColors.primaryText
                                  : AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(width: 6),
                          _buildBeforeAfterBadge(group.mealKey),
                        ],
                      ),
                    ),

                    // Medicine count badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasMedicines
                            ? AppColors.accent1
                            : AppColors.background,
                        borderRadius: AppRadius.fullRadius,
                      ),
                      child: Text(
                        '${group.medicineCount}',
                        style: AppTypography.caption.copyWith(
                          color: hasMedicines
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    SizedBox(width: 8),

                    // Status icon
                    _buildStatusIcon(group.status),

                    // Nurse mark badges (2C และ 3C)
                    if (group.nurseMark2C != NurseMarkStatus.none ||
                        group.nurseMark3C != NurseMarkStatus.none) ...[
                      SizedBox(width: 6),
                      _buildNurseMarkBadges(group.nurseMark2C, group.nurseMark3C),
                    ],

                    // Expand arrow
                    if (hasMedicines) ...[
                      SizedBox(width: 8),
                      RotationTransition(
                        turns: _iconTurns,
                        child: Icon(
                          Iconsax.arrow_down_1,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Expandable content
          if (hasMedicines)
            ClipRect(
              child: AnimatedBuilder(
                animation: _heightFactor,
                builder: (context, child) {
                  return Align(
                    heightFactor: _heightFactor.value,
                    alignment: Alignment.topCenter,
                    child: child,
                  );
                },
                child: _buildContent(),
              ),
            ),
        ],
      ),
    );
  }

  /// แปลง mealKey เป็นชื่อมื้อ (ไม่รวม ก่อน/หลัง)
  String _getMealTimeLabel(String mealKey) {
    if (mealKey.contains('morning') || mealKey.contains('เช้า')) {
      return 'เช้า';
    } else if (mealKey.contains('noon') || mealKey.contains('กลางวัน')) {
      return 'กลางวัน';
    } else if (mealKey.contains('evening') || mealKey.contains('เย็น')) {
      return 'เย็น';
    } else {
      return 'ก่อนนอน';
    }
  }

  /// สี Pastel สำหรับแต่ละมื้อ
  /// เช้า - เหลือง, กลางวัน - ส้ม, เย็น - น้ำเงิน, ก่อนนอน - ม่วง
  static const _mealColors = {
    'morning': Color(0xFFF59E0B), // Amber/Yellow
    'noon': Color(0xFFF97316), // Orange
    'evening': Color(0xFF3B82F6), // Blue
    'bedtime': Color(0xFF8B5CF6), // Purple
  };

  /// สี Pastel Background สำหรับแต่ละมื้อ
  static const _mealBgColors = {
    'morning': Color(0xFFFEF3C7), // Amber-100
    'noon': Color(0xFFFFEDD5), // Orange-100
    'evening': Color(0xFFDBEAFE), // Blue-100
    'bedtime': Color(0xFFEDE9FE), // Purple-100
  };

  /// สีสำหรับ ก่อน/หลัง อาหาร
  /// ก่อน - โทนฟ้า, หลัง - โทนแดง
  static const _beforeColor = Color(0xFF0EA5E9); // Sky-500
  static const _afterColor = Color(0xFFEF4444); // Red-500
  static const _beforeBgColor = Color(0xFFE0F2FE); // Sky-100
  static const _afterBgColor = Color(0xFFFEE2E2); // Red-100

  Widget _buildMealIcon(String mealKey) {
    IconData icon;
    Color iconColor;
    Color bgColor;

    // ตรวจสอบว่าเป็น "ก่อน" หรือ "หลัง"
    final isBefore = mealKey.contains('before') ||
        (mealKey.contains('ก่อน') && !mealKey.contains('ก่อนนอน'));

    // กำหนด icon และสีตามมื้อ (แยกละเอียดตามรูป)
    if (mealKey.contains('morning') || mealKey.contains('เช้า')) {
      // เช้า - สีส้ม
      iconColor = _mealColors['morning']!;
      bgColor = _mealBgColors['morning']!;
      // ก่อนเช้า = sunrise, หลังเช้า = sun
      icon = isBefore ? Iconsax.sun_1 : Iconsax.sun;
    } else if (mealKey.contains('noon') || mealKey.contains('กลางวัน')) {
      // กลางวัน - สีส้ม
      iconColor = _mealColors['noon']!;
      bgColor = _mealBgColors['noon']!;
      // ก่อนกลางวัน = sun_fog (พระอาทิตย์แรง), หลังกลางวัน = sun
      icon = isBefore ? Iconsax.sun_fog : Iconsax.sun;
    } else if (mealKey.contains('evening') || mealKey.contains('เย็น')) {
      // เย็น - สีน้ำเงิน
      iconColor = _mealColors['evening']!;
      bgColor = _mealBgColors['evening']!;
      // ก่อนเย็น = sun_1 (sunset), หลังเย็น = cloud
      icon = isBefore ? Iconsax.sun_1 : Iconsax.cloud;
    } else {
      // ก่อนนอน - สีม่วง + moon
      icon = Iconsax.moon;
      iconColor = _mealColors['bedtime']!;
      bgColor = _mealBgColors['bedtime']!;
    }

    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.smallRadius,
      ),
      child: Icon(icon, size: 16, color: iconColor),
    );
  }

  /// Badge แสดง ก่อน/หลัง อาหาร
  Widget _buildBeforeAfterBadge(String mealKey) {
    final isBedtime =
        mealKey.contains('bedtime') || mealKey == 'ก่อนนอน';

    // ก่อนนอนไม่ต้องแสดง badge
    if (isBedtime) return SizedBox.shrink();

    // ตรวจสอบว่าเป็น "ก่อน" หรือ "หลัง" อาหาร
    final isBefore = mealKey.contains('before') ||
        (mealKey.contains('ก่อน') && !mealKey.contains('ก่อนนอน'));

    final color = isBefore ? _beforeColor : _afterColor;
    final bgColor = isBefore ? _beforeBgColor : _afterBgColor;
    final label = isBefore ? 'ก่อน' : 'หลัง';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.fullRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildStatusIcon(MealPhotoStatus status) {
    switch (status) {
      case MealPhotoStatus.completed:
        return Icon(
          Iconsax.tick_circle,
          size: 20,
          color: AppColors.tagPassedText,
        );
      case MealPhotoStatus.arranged:
        return Icon(
          Iconsax.clock,
          size: 20,
          color: AppColors.tagPendingText,
        );
      case MealPhotoStatus.pending:
        return Icon(
          Iconsax.minus_cirlce,
          size: 20,
          color: AppColors.textSecondary,
        );
      case MealPhotoStatus.noMedicine:
        return Icon(
          Iconsax.minus,
          size: 20,
          color: AppColors.inputBorder,
        );
    }
  }

  /// สร้าง badge แสดงสถานะการตรวจสอบจากหัวหน้าเวร
  /// แสดงเป็น pill badge: "2C ✓" และ "3C ✓"
  Widget _buildNurseMarkBadges(NurseMarkStatus mark2C, NurseMarkStatus mark3C) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge 2C
        if (mark2C != NurseMarkStatus.none)
          _buildSingleNurseMarkBadge(mark2C, is2C: true),
        // Badge 3C
        if (mark3C != NurseMarkStatus.none) ...[
          if (mark2C != NurseMarkStatus.none) const SizedBox(width: 4),
          _buildSingleNurseMarkBadge(mark3C, is2C: false),
        ],
      ],
    );
  }

  /// สร้าง badge เดี่ยวสำหรับ nurse mark - แบบ pill badge
  Widget _buildSingleNurseMarkBadge(NurseMarkStatus status, {required bool is2C}) {
    // กำหนดสีและ icon ตาม status
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case NurseMarkStatus.correct:
        // เขียว - รูปตรง
        bgColor = const Color(0xFFDCFCE7); // green-100
        textColor = const Color(0xFF166534); // green-800
        icon = Icons.check_circle;
        break;
      case NurseMarkStatus.incorrect:
        // แดง - รูปไม่ตรง
        bgColor = const Color(0xFFFEE2E2); // red-100
        textColor = const Color(0xFFDC2626); // red-600
        icon = Icons.cancel;
        break;
      case NurseMarkStatus.noPhoto:
        // เทา - ไม่มีรูป
        bgColor = const Color(0xFFF3F4F6); // gray-100
        textColor = const Color(0xFF6B7280); // gray-500
        icon = Icons.image_not_supported;
        break;
      case NurseMarkStatus.swapped:
        // เหลือง - ตำแหน่งสลับ
        bgColor = const Color(0xFFFEF3C7); // amber-100
        textColor = const Color(0xFFD97706); // amber-600
        icon = Icons.swap_horiz;
        break;
      case NurseMarkStatus.none:
        return const SizedBox.shrink();
    }

    final label = is2C ? 'จัด' : 'เสิร์ฟ';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            icon,
            size: 12,
            color: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final medicines = widget.mealGroup.medicines;
    final medLog = widget.mealGroup.medLog;
    final logPhotoUrl = widget.showFoiled
        ? medLog?.picture2CUrl
        : medLog?.picture3CUrl;
    final hasLogPhoto = logPhotoUrl != null && logPhotoUrl.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grid รูปตัวอย่างยา - แสดงเต็มความกว้าง
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.xs,
              mainAxisSpacing: AppSpacing.xs,
              childAspectRatio: 1.0,
            ),
            itemCount: medicines.length,
            itemBuilder: (context, index) {
              return MedicinePhotoItem(
                medicine: medicines[index],
                showFoiled: widget.showFoiled,
                showOverlay: widget.showOverlay,
              );
            },
          ),

          SizedBox(height: AppSpacing.sm),

          // รูปจัดยา/ให้ยา (2C/3C) หรือปุ่มถ่ายรูป - อยู่ด้านล่าง
          hasLogPhoto
              ? _buildLogPhoto(logPhotoUrl, medLog!)
              : _buildCameraButton(),
        ],
      ),
    );
  }

  /// ปุ่มถ่ายรูป - แบบยาวเต็มความกว้าง
  Widget _buildCameraButton() {
    final photoType = widget.showFoiled ? '2C' : '3C';
    final label = widget.showFoiled ? 'ถ่ายรูปจัดยา' : 'ถ่ายรูปเสิร์ฟยา';
    final color = widget.showFoiled
        ? const Color(0xFF0EA5E9)
        : const Color(0xFF10B981);

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: AppRadius.smallRadius,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTakePhoto != null
              ? () => widget.onTakePhoto!(widget.mealGroup.mealKey, photoType)
              : null,
          borderRadius: AppRadius.smallRadius,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Iconsax.camera,
                    size: 24,
                    color: color,
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTypography.body.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'กดเพื่อถ่ายรูป',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ตรวจสอบว่าสามารถลบรูปได้หรือไม่
  /// สิทธิ์ตาม role:
  /// - พนักงานทั่วไป: ลบรูปที่ตัวเองถ่าย ไม่เกิน 6 ชม.
  /// - admin: ลบรูปของทุกคน ไม่เกิน 6 ชม.
  /// - superAdmin: ลบรูปของทุกคน ตอนไหนก็ได้
  bool _canDeletePhoto({
    required DateTime? timestamp,
    required String? photographerUserId,
  }) {
    if (timestamp == null) return false;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final role = widget.systemRole;

    // owner/manager: ลบได้ทุกรูป ไม่จำกัดเวลา
    if (role != null && role.isAtLeastManager) return true;

    // ตรวจสอบเวลา: ต้องถ่ายไม่เกิน 6 ชม. (สำหรับ shift_leader และ user ทั่วไป)
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inHours >= 6) return false;

    // หัวหน้าเวรขึ้นไป: ลบรูปของทุกคนได้ (ภายใน 6 ชม.)
    if (role != null && role.canQC) return true;

    // พนักงานทั่วไป: ต้องเป็นคนถ่ายรูปเอง
    if (photographerUserId == null) return false;
    return currentUserId == photographerUserId;
  }

  /// แสดงรูปจัดยา/ให้ยา จาก med_logs พร้อมชื่อผู้ถ่ายและเวลา
  Widget _buildLogPhoto(String photoUrl, MedLog medLog) {
    // ดึงชื่อผู้ถ่ายและเวลาตาม mode (2C หรือ 3C)
    final photographer = widget.showFoiled
        ? medLog.userNickname2c
        : medLog.userNickname3c;
    final timestamp = widget.showFoiled
        ? medLog.createdAt
        : medLog.timestamp3C ?? medLog.createdAt;
    final photographerUserId = widget.showFoiled
        ? medLog.userId2c
        : medLog.userId3c;

    // ตรวจสอบว่าสามารถลบรูปได้หรือไม่ (ภายใน 6 ชม. + เป็นคนถ่ายเอง)
    final canDelete = _canDeletePhoto(
      timestamp: timestamp,
      photographerUserId: photographerUserId,
    );

    final borderColor = widget.showFoiled
        ? const Color(0xFF0EA5E9)
        : const Color(0xFF10B981);

    return GestureDetector(
      onTap: () => _showLogPhotoFullScreen(photoUrl),
      child: Hero(
        tag: 'log_photo_${widget.mealGroup.mealKey}_$photoUrl',
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.smallRadius,
            border: Border.all(color: borderColor, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 4 / 3, // รูปยาวขึ้น ดูชัดขึ้น
            child: Stack(
              fit: StackFit.expand,
              children: [
                // รูปจัดยา/ให้ยา - ใช้ Image.network ที่จะโหลดจนกว่าจะเสร็จ
                // ใช้ BoxFit.contain เพื่อรักษาสัดส่วนรูปยา (ไม่บิดเบี้ยว)
                Container(
                  color: Colors.black,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      final progress = loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null;
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                            if (progress != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.image,
                              size: 32,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'โหลดรูปไม่สำเร็จ',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // ปุ่มลบรูป (มุมขวาบน) - แสดงเฉพาะรูปที่ถ่ายไม่เกิน 6 ชม.
                if (widget.onDeletePhoto != null && canDelete)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _showDeleteConfirmDialog(),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Iconsax.trash,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                // ปุ่ม QC (มุมซ้ายบน) - แสดงเฉพาะหัวหน้าเวรขึ้นไป
                if (widget.systemRole != null && widget.systemRole!.canQC && widget.onQCPhoto != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _QCButton(
                      onTap: _showQCDialog,
                      currentStatus: widget.showFoiled
                          ? widget.mealGroup.nurseMark2C
                          : widget.mealGroup.nurseMark3C,
                      reviewerName: widget.showFoiled
                          ? widget.mealGroup.reviewer2CName
                          : widget.mealGroup.reviewer3CName,
                    ),
                  ),

                // Badge 2C/3C + ข้อมูลผู้ถ่าย
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        // Badge จัดโดย/เสิร์ฟโดย
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: borderColor,
                            borderRadius: AppRadius.fullRadius,
                          ),
                          child: Text(
                            widget.showFoiled ? 'จัดโดย' : 'เสิร์ฟโดย',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // ข้อมูลผู้ถ่ายและเวลา
                        Expanded(
                          child: Text(
                            _formatPhotoInfo(photographer, timestamp),
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // กดเพื่อดูรูปขยาย
                        Icon(
                          Iconsax.maximize_4,
                          size: 16,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Format ข้อมูลผู้ถ่ายและเวลา เช่น "โซฟิยา - 27/12 22:28"
  String _formatPhotoInfo(String? photographer, DateTime? timestamp) {
    final parts = <String>[];

    if (photographer != null && photographer.isNotEmpty) {
      parts.add(photographer);
    }

    if (timestamp != null) {
      final day = timestamp.day.toString().padLeft(2, '0');
      final month = timestamp.month.toString().padLeft(2, '0');
      final hour = timestamp.hour.toString().padLeft(2, '0');
      final minute = timestamp.minute.toString().padLeft(2, '0');
      parts.add('$day/$month $hour:$minute');
    }

    return parts.join(' - ');
  }

  /// แสดง dialog เลือกสถานะ QC
  Future<void> _showQCDialog() async {
    final photoType = widget.showFoiled ? '2C' : '3C';
    final typeLabel = widget.showFoiled ? 'จัดยา' : 'เสิร์ฟยา';

    // ดึงสถานะปัจจุบัน
    final currentMark = widget.showFoiled
        ? widget.mealGroup.nurseMark2C
        : widget.mealGroup.nurseMark3C;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _QCBottomSheet(
        photoType: photoType,
        typeLabel: typeLabel,
        currentStatus: currentMark,
      ),
    );

    if (result != null && widget.onQCPhoto != null) {
      await widget.onQCPhoto!(widget.mealGroup.mealKey, photoType, result);
    }
  }

  /// แสดง dialog ยืนยันการลบรูป
  Future<void> _showDeleteConfirmDialog() async {
    final photoType = widget.showFoiled ? '2C' : '3C';
    final typeLabel = widget.showFoiled ? 'จัดยา' : 'เสิร์ฟยา';

    final shouldDelete = await ConfirmDialog.show(
      context,
      type: ConfirmDialogType.delete,
      title: 'ลบรูป$typeLabel',
      message: 'ต้องการลบรูป$typeLabel ($photoType) ของมื้อนี้หรือไม่?\n\nการลบจะไม่สามารถกู้คืนได้',
      confirmText: 'ลบรูป',
    );

    if (shouldDelete) {
      widget.onDeletePhoto?.call(
        widget.mealGroup.mealKey,
        photoType,
      );
    }
  }

  void _showLogPhotoFullScreen(String photoUrl) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _FullScreenPhotoView(
              photoUrl: photoUrl,
              heroTag: 'log_photo_${widget.mealGroup.mealKey}_$photoUrl',
              title: widget.showFoiled ? 'จัดยา (แผง)' : 'เสิร์ฟยา (เม็ด)',
            ),
          );
        },
      ),
    );
  }
}

/// ปุ่ม QC พร้อม pulse animation เพื่อดึงดูดความสนใจ
/// แสดงสถานะการตรวจสอบปัจจุบันหากมี พร้อมชื่อผู้ตรวจสอบ
class _QCButton extends StatefulWidget {
  final VoidCallback onTap;
  final NurseMarkStatus currentStatus;
  final String? reviewerName; // ชื่อผู้ตรวจสอบ (format: "ชื่อจริง (ชื่อเล่น)")

  const _QCButton({
    required this.onTap,
    required this.currentStatus,
    this.reviewerName,
  });

  @override
  State<_QCButton> createState() => _QCButtonState();
}

class _QCButtonState extends State<_QCButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // เริ่ม animation เฉพาะเมื่อยังไม่ได้ตรวจสอบ
    if (widget.currentStatus == NurseMarkStatus.none) {
      _controller.repeat(reverse: true);
    }

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_QCButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // เริ่ม/หยุด animation เมื่อ status เปลี่ยน
    if (widget.currentStatus != oldWidget.currentStatus) {
      if (widget.currentStatus == NurseMarkStatus.none) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// ข้อมูลสีและ icon ตาม status
  ({Color color, Color bgColor, IconData icon, String label}) _getStatusStyle() {
    switch (widget.currentStatus) {
      case NurseMarkStatus.correct:
        return (
          color: const Color(0xFF166534), // green-800
          bgColor: const Color(0xFFDCFCE7), // green-100
          icon: Icons.check_circle,
          label: 'รูปตรง',
        );
      case NurseMarkStatus.incorrect:
        return (
          color: const Color(0xFFDC2626), // red-600
          bgColor: const Color(0xFFFEE2E2), // red-100
          icon: Icons.cancel,
          label: 'รูปไม่ตรง',
        );
      case NurseMarkStatus.noPhoto:
        return (
          color: const Color(0xFF6B7280), // gray-500
          bgColor: const Color(0xFFF3F4F6), // gray-100
          icon: Icons.image_not_supported,
          label: 'ไม่มีรูป',
        );
      case NurseMarkStatus.swapped:
        return (
          color: const Color(0xFFD97706), // amber-600
          bgColor: const Color(0xFFFEF3C7), // amber-100
          icon: Icons.swap_horiz,
          label: 'ตำแหน่งสลับ',
        );
      case NurseMarkStatus.none:
        return (
          color: Colors.white,
          bgColor: Colors.transparent,
          icon: Icons.touch_app,
          label: 'ตรวจสอบ',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasStatus = widget.currentStatus != NurseMarkStatus.none;
    final style = _getStatusStyle();

    // ถ้ามี status แล้ว แสดงแบบ solid badge (ไม่มี animation)
    if (hasStatus) {
      // สร้าง label: ถ้ามีชื่อผู้ตรวจ แสดง "ตรวจโดย ชื่อ" ไม่งั้นแสดง status label
      final displayLabel = widget.reviewerName != null && widget.reviewerName!.isNotEmpty
          ? 'ตรวจโดย ${widget.reviewerName}'
          : style.label;

      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: style.bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: style.color.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                style.icon,
                size: 14,
                color: style.color,
              ),
              SizedBox(width: 4),
              Text(
                displayLabel,
                style: AppTypography.caption.copyWith(
                  color: style.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ยังไม่ได้ตรวจสอบ - แสดงแบบ gradient + animation
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF59E0B), // amber-500
                const Color(0xFFF97316), // orange-500
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app,
                size: 16,
                color: Colors.white,
              ),
              SizedBox(width: 6),
              Text(
                'ตรวจสอบ',
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet สำหรับเลือกสถานะ QC
class _QCBottomSheet extends StatelessWidget {
  final String photoType;
  final String typeLabel;
  final NurseMarkStatus currentStatus;

  const _QCBottomSheet({
    required this.photoType,
    required this.typeLabel,
    required this.currentStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.sm),

              // Title
              Text(
                'ตรวจสอบรูป$typeLabel ($photoType)',
                style: AppTypography.heading3,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.md),

              // Options - 2x2 grid
              Row(
                children: [
                  Expanded(
                    child: _buildOption(
                      context,
                      status: 'รูปตรง',
                      icon: Icons.check_circle,
                      color: const Color(0xFF22C55E), // green-500
                      bgColor: const Color(0xFFDCFCE7), // green-100
                      isSelected: currentStatus == NurseMarkStatus.correct,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildOption(
                      context,
                      status: 'รูปไม่ตรง',
                      icon: Icons.cancel,
                      color: const Color(0xFFEF4444), // red-500
                      bgColor: const Color(0xFFFEE2E2), // red-100
                      isSelected: currentStatus == NurseMarkStatus.incorrect,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _buildOption(
                      context,
                      status: 'ไม่มีรูป',
                      icon: Icons.image_not_supported,
                      color: const Color(0xFF6B7280), // gray-500
                      bgColor: const Color(0xFFF3F4F6), // gray-100
                      isSelected: currentStatus == NurseMarkStatus.noPhoto,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildOption(
                      context,
                      status: 'ตำแหน่งสลับ',
                      icon: Icons.swap_horiz,
                      color: const Color(0xFFD97706), // amber-600
                      bgColor: const Color(0xFFFEF3C7), // amber-100
                      isSelected: currentStatus == NurseMarkStatus.swapped,
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.md),

              // Reset button - แสดงเฉพาะเมื่อมี status อยู่แล้ว
              if (currentStatus != NurseMarkStatus.none) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, '__reset__'),
                    borderRadius: AppRadius.smallRadius,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: AppRadius.smallRadius,
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 18,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ยกเลิกการตรวจ',
                            style: AppTypography.button.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
              ],

              // Cancel button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: AppRadius.smallRadius,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'ปิด',
                        style: AppTypography.button.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String status,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, status),
        borderRadius: AppRadius.smallRadius,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : bgColor,
            borderRadius: AppRadius.smallRadius,
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: color,
              ),
              SizedBox(height: 4),
              Text(
                status,
                style: AppTypography.body.copyWith(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              if (isSelected) ...[
                SizedBox(height: 2),
                Text(
                  '(เลือกอยู่)',
                  style: AppTypography.caption.copyWith(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Full screen photo viewer with Hero animation
class _FullScreenPhotoView extends StatelessWidget {
  final String photoUrl;
  final String heroTag;
  final String title;

  const _FullScreenPhotoView({
    required this.photoUrl,
    required this.heroTag,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background - tap to close
            Container(color: Colors.transparent),

            // Image with Hero - ใช้ Image.network ที่จะโหลดจนกว่าจะเสร็จ
            Center(
              child: Hero(
                tag: heroTag,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      final progress = loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null;
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                            if (progress != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Iconsax.image,
                        size: 64,
                        color: Colors.white54,
                      );
                    },
                  ),
                ),
              ),
            ),

            // Close button & Title
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppTypography.title.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Iconsax.close_circle,
                      color: Colors.white,
                      size: 28,
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
}
