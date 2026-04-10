import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../checklist/models/assessment_models.dart';
import '../../checklist/services/assessment_service.dart';
import '../../checklist/widgets/assessment_inline_section.dart';

// ============================================
// PostAssessmentSection — "📋 ประเมินสุขภาพ"
// ============================================
// Section แยกสำหรับแนบผลประเมินสุขภาพ (1-5 rating) ใน post
// แสดงเมื่อเลือก resident แล้ว ทั้ง create + edit
// Reuse AssessmentInlineSection widget โดยตรง
//
// Layout:
// ── 📋 ประเมินสุขภาพ ─────────── ▼ ──
//  [อารมณ์: 1-5 scale]
//  [การนอนหลับ: 1-5 scale]

class PostAssessmentSection extends StatefulWidget {
  /// Nursing home ID — ใช้ดึง subjects ทั้งหมดที่ nursing home นี้มี
  final int nursinghomeId;

  /// หัวข้อประเมินที่โหลดมาแล้ว (จาก parent state)
  /// ถ้า empty จะ fetch จาก DB ใน initState
  final List<AssessmentSubject> subjects;

  /// ผลประเมินเดิม (สำหรับ edit mode — ยังไม่รองรับ restore)
  final List<AssessmentRating> initialRatings;

  /// Callback เมื่อโหลด subjects สำเร็จ (ให้ parent เก็บ state)
  final ValueChanged<List<AssessmentSubject>> onSubjectsLoaded;

  /// Callback เมื่อ ratings เปลี่ยน
  final ValueChanged<List<AssessmentRating>> onRatingsChanged;

  /// เปิด expanded ตั้งแต่แรก (จาก FAB shortcut)
  final bool initiallyExpanded;

  /// Single mode: ซ่อน header แสดง content ตรงๆ เลย (จาก shortcut)
  final bool singleMode;

  /// แสดงเฉพาะ subject นี้ตัวเดียว (จาก FAB shortcut เลือกหัวข้อ)
  final int? subjectId;

  const PostAssessmentSection({
    super.key,
    required this.nursinghomeId,
    required this.subjects,
    this.initialRatings = const [],
    required this.onSubjectsLoaded,
    required this.onRatingsChanged,
    this.initiallyExpanded = false,
    this.singleMode = false,
    this.subjectId,
  });

  @override
  State<PostAssessmentSection> createState() => _PostAssessmentSectionState();
}

class _PostAssessmentSectionState extends State<PostAssessmentSection> {
  late bool _isExpanded;
  bool _isLoading = false;

  /// จำนวน rating ที่กรอกแล้ว
  int _ratedCount = 0;

  /// ตรวจว่ามี subject ให้แสดงหรือยัง
  bool get _hasSubjects => widget.subjects.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // ตั้งค่า expanded จาก initiallyExpanded หรือ initialRatings
    _isExpanded = widget.initiallyExpanded || widget.initialRatings.isNotEmpty;
    _ratedCount = widget.initialRatings.length;

    // ถ้ายังไม่มี subjects → fetch จาก DB (guard: nursinghomeId ต้อง > 0)
    if (widget.subjects.isEmpty && widget.nursinghomeId > 0) {
      _loadSubjects();
    }
  }

  @override
  void didUpdateWidget(PostAssessmentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ถ้า nursinghomeId เปลี่ยนจาก 0 → ค่าจริง → โหลด subjects
    if (oldWidget.nursinghomeId == 0 &&
        widget.nursinghomeId > 0 &&
        widget.subjects.isEmpty &&
        !_isLoading) {
      _loadSubjects();
    }
  }

  /// ดึง assessment subjects ทั้งหมดของ nursing home
  Future<void> _loadSubjects() async {
    setState(() => _isLoading = true);
    try {
      final subjects = await AssessmentService.instance
          .getAllSubjectsForNursingHome(widget.nursinghomeId);
      if (mounted) {
        widget.onSubjectsLoaded(subjects);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ถ้ายังรอ nursinghomeId อยู่ → แสดง loading (ไม่ซ่อน)
    // ถ้าโหลด subjects แล้วไม่มี → ซ่อน
    if (!_isLoading && !_hasSubjects && widget.nursinghomeId > 0) {
      return const SizedBox.shrink();
    }

    // === Single mode: แสดง content ตรงๆ ไม่มี header ===
    if (widget.singleMode) {
      return _buildExpandedContent();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        if (_isExpanded) _buildExpandedContent(),
      ],
    );
  }

  // ============================================
  // Header — tap เพื่อ expand/collapse
  // ============================================
  Widget _buildHeader() {
    final hasRatings = _ratedCount > 0;

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasRatings ? AppColors.primary : AppColors.alternate,
            width: hasRatings ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: hasRatings
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Icon
            HugeIcon(
              icon: HugeIcons.strokeRoundedStethoscope02,
              size: AppIconSize.lg,
              color: hasRatings ? AppColors.primary : AppColors.secondaryText,
            ),
            const SizedBox(width: 8),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ประเมินสุขภาพ',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color:
                          hasRatings ? AppColors.primary : AppColors.primaryText,
                    ),
                  ),
                  Text(
                    _isLoading
                        ? 'กำลังโหลดหัวข้อ...'
                        : 'อารมณ์, การนอน, อื่นๆ',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            // Badge count
            if (_ratedCount > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.fullRadius,
                ),
                child: Text(
                  '$_ratedCount',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            // Loading indicator
            if (_isLoading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 4),
            ],
            // Arrow
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                size: AppIconSize.md,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // Expanded Content — reuse AssessmentInlineSection
  // ============================================
  Widget _buildExpandedContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasSubjects) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'ไม่มีหัวข้อประเมินสำหรับศูนย์นี้',
          style: AppTypography.caption
              .copyWith(color: AppColors.secondaryText),
        ),
      );
    }

    // Filter เฉพาะ subject ที่เลือก (ถ้ามี subjectId จาก shortcut)
    final displaySubjects = widget.subjectId != null
        ? widget.subjects.where((s) => s.subjectId == widget.subjectId).toList()
        : widget.subjects;

    if (displaySubjects.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AssessmentInlineSection(
        // Key เปลี่ยนเมื่อ initialRatings มาใหม่ → recreate widget ให้ pre-fill ถูก
        key: ValueKey('assessment_${widget.initialRatings.length}'),
        subjects: displaySubjects,
        initialRatings: widget.initialRatings,
        onChanged: (ratings) {
          setState(() => _ratedCount = ratings.length);
          widget.onRatingsChanged(ratings);
        },
        onCompletionChanged: (_) {
          // ใน post ไม่บังคับกรอกครบ — callback นี้ไม่ใช้
        },
      ),
    );
  }
}
