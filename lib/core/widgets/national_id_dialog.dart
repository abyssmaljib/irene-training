import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'buttons.dart';

/// Dialog ขอเลขบัตรประชาชนจาก user ที่ยังไม่เคยกรอก
///
/// Features:
/// - แสดงรูปแมวไหว้ (graceful_cat.webp) พร้อมข้อความน่ารัก
/// - กด dismiss ได้ (barrierDismissible: true) แต่จะขึ้นอีกทุกครั้งที่เปิดแอปใหม่
/// - Validate เลขบัตร 13 หลัก ก่อนบันทึก
/// - บันทึกลง user_info.national_ID_staff โดยตรง
class NationalIdDialog extends StatefulWidget {
  const NationalIdDialog({super.key});

  /// แสดง dialog ขอเลขบัตรประชาชน
  /// Returns true ถ้าบันทึกสำเร็จ, false ถ้า dismiss
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true, // กด dismiss ได้
      builder: (context) => const NationalIdDialog(),
    );
    return result ?? false;
  }

  /// เช็คว่า user มี national_id หรือยัง
  /// Returns true ถ้ายังไม่มี (ต้องแสดง dialog)
  static Future<bool> needsNationalId() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await Supabase.instance.client
          .from('user_info')
          .select('national_ID_staff')
          .eq('id', userId)
          .maybeSingle();

      // ยังไม่มี national_id ถ้า null หรือ empty string
      final nationalId = response?['national_ID_staff'] as String?;
      return nationalId == null || nationalId.trim().isEmpty;
    } catch (e) {
      debugPrint('NationalIdDialog: Error checking national_id: $e');
      // ถ้า error ไม่บังคับ (fail-safe)
      return false;
    }
  }

  /// บันทึก national_id ลง database
  static Future<void> _saveNationalId(String nationalId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await Supabase.instance.client.from('user_info').update({
      'national_ID_staff': nationalId.trim(),
    }).eq('id', userId);
  }

  @override
  State<NationalIdDialog> createState() => _NationalIdDialogState();
}

class _NationalIdDialogState extends State<NationalIdDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  // สถานะ
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // Auto focus ช่อง input หลัง dialog เปิด
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Validate เลขบัตรประชาชน 13 หลัก
  /// ใช้ algorithm ตรวจสอบ checksum ตาม กรมการปกครอง
  bool _isValidNationalId(String id) {
    // ต้องเป็นตัวเลข 13 หลักเท่านั้น
    if (id.length != 13 || !RegExp(r'^\d{13}$').hasMatch(id)) {
      return false;
    }

    // ตรวจ checksum: คูณหลักที่ 1-12 ด้วย 13-2 ตามลำดับ
    // แล้วเอา 11 - (ผลรวม mod 11) ต้องเท่ากับหลักที่ 13
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += int.parse(id[i]) * (13 - i);
    }
    final checkDigit = (11 - (sum % 11)) % 10;
    return checkDigit == int.parse(id[12]);
  }

  /// บันทึกเลขบัตรประชาชน
  Future<void> _handleSave() async {
    final value = _controller.text.trim();

    // Validate
    if (value.isEmpty) {
      setState(() => _errorText = 'กรุณากรอกเลขบัตรประชาชน');
      return;
    }

    if (!_isValidNationalId(value)) {
      setState(() => _errorText = 'เลขบัตรประชาชนไม่ถูกต้อง (ต้องเป็น 13 หลัก)');
      return;
    }

    // Clear error แล้วบันทึก
    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    try {
      await NationalIdDialog._saveNationalId(value);

      if (mounted) {
        Navigator.pop(context, true); // return true = บันทึกสำเร็จ
      }
    } catch (e) {
      debugPrint('NationalIdDialog: Error saving: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = 'บันทึกไม่สำเร็จ กรุณาลองใหม่';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeRadius, // 24px ตาม design system
      ),
      backgroundColor: AppColors.surface,
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: AppSpacing.lg),

              // รูปแมวไหว้
              Image.asset(
                'assets/images/graceful_cat.webp',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),

              SizedBox(height: AppSpacing.sm),

              // Title — ข้อความน่ารัก
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'ได้โปรดขอเลขบัตรประชาชนหน่อยงับ 🙏',
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: AppSpacing.xs),

              // Description
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'เราต้องการเลขบัตรประชาชนเพื่อใช้ในระบบ\nกรุณากรอกให้ถูกต้อง 13 หลักนะงับ',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: AppSpacing.md),

              // Input field — เลขบัตรประชาชน
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label
                    Text(
                      'เลขบัตรประชาชน',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: AppSpacing.xs),

                    // TextField
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      maxLength: 13,
                      // รับเฉพาะตัวเลข
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        hintText: 'X-XXXX-XXXXX-XX-X',
                        hintStyle: AppTypography.body.copyWith(
                          color: AppColors.secondaryText.withValues(alpha: 0.5),
                        ),
                        // แสดง error text ใต้ input
                        errorText: _errorText,
                        errorMaxLines: 2,
                        // Counter text (13 หลัก) — ซ่อนไว้เพราะ maxLength แสดงอยู่แล้ว
                        counterText: '',
                        // Prefix icon
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 8),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedIdentityCard,
                            color: AppColors.secondaryText,
                            size: 20,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        // Border styling
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.inputBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.inputBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.error,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.error,
                            width: 2,
                          ),
                        ),
                      ),
                      style: AppTypography.body.copyWith(
                        // ใช้ letterSpacing เพื่อให้เลขอ่านง่ายขึ้น
                        letterSpacing: 2.0,
                      ),
                      // เคลียร์ error เมื่อ user พิมพ์ใหม่
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
                      // กด Enter = บันทึก
                      onSubmitted: (_) => _handleSave(),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.md),

              // ปุ่มบันทึก
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: PrimaryButton(
                  text: _isSaving ? 'กำลังบันทึก...' : 'บันทึก',
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  onPressed: _isSaving ? null : _handleSave,
                  width: double.infinity,
                ),
              ),

              SizedBox(height: AppSpacing.sm),

              // ปุ่ม dismiss — "ไว้ทีหลัง"
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                child: Text(
                  'ไว้ทีหลังนะ',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),

              SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
