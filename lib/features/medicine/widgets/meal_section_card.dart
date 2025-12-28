import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
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
  final VoidCallback? onExpandChanged; // callback when tapped
  final Future<void> Function(String mealKey, String photoType)? onTakePhoto; // callback สำหรับถ่ายรูป
  final Future<void> Function(String mealKey, String photoType)? onDeletePhoto; // callback สำหรับลบรูป

  const MealSectionCard({
    super.key,
    required this.mealGroup,
    this.showFoiled = true,
    this.showOverlay = true,
    this.isExpanded = false,
    this.onExpandChanged,
    this.onTakePhoto,
    this.onDeletePhoto,
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

    // กำหนดสีตามมื้อ
    if (mealKey.contains('morning') || mealKey.contains('เช้า')) {
      icon = Iconsax.sun_1;
      iconColor = _mealColors['morning']!;
      bgColor = _mealBgColors['morning']!;
    } else if (mealKey.contains('noon') || mealKey.contains('กลางวัน')) {
      icon = Iconsax.sun;
      iconColor = _mealColors['noon']!;
      bgColor = _mealBgColors['noon']!;
    } else if (mealKey.contains('evening') || mealKey.contains('เย็น')) {
      icon = Iconsax.moon;
      iconColor = _mealColors['evening']!;
      bgColor = _mealBgColors['evening']!;
    } else {
      // ก่อนนอน
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
          Iconsax.tick_circle5,
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

  /// แสดงรูปจัดยา/ให้ยา จาก med_logs พร้อมชื่อผู้ถ่ายและเวลา
  Widget _buildLogPhoto(String photoUrl, MedLog medLog) {
    // ดึงชื่อผู้ถ่ายและเวลาตาม mode (2C หรือ 3C)
    final photographer = widget.showFoiled
        ? medLog.userNickname2c
        : medLog.userNickname3c;
    final timestamp = widget.showFoiled
        ? medLog.createdAt
        : medLog.timestamp3C ?? medLog.createdAt;

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

                // ปุ่มลบรูป (มุมขวาบน)
                if (widget.onDeletePhoto != null)
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
                        // Badge 2C/3C
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: borderColor,
                            borderRadius: AppRadius.fullRadius,
                          ),
                          child: Text(
                            widget.showFoiled ? '2C' : '3C',
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

  /// แสดง dialog ยืนยันการลบรูป
  void _showDeleteConfirmDialog() {
    final photoType = widget.showFoiled ? '2C' : '3C';
    final typeLabel = widget.showFoiled ? 'จัดยา' : 'เสิร์ฟยา';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mediumRadius,
        ),
        title: Row(
          children: [
            Icon(Iconsax.trash, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text(
              'ลบรูป$typeLabel',
              style: AppTypography.title,
            ),
          ],
        ),
        content: Text(
          'ต้องการลบรูป$typeLabel ($photoType) ของมื้อนี้หรือไม่?\n\nการลบจะไม่สามารถกู้คืนได้',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'ยกเลิก',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDeletePhoto?.call(
                widget.mealGroup.mealKey,
                photoType,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('ลบรูป'),
          ),
        ],
      ),
    );
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
