import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// หน้า WebView แบบ reusable - ฝังเว็บไซต์ไว้ภายในแอป
/// ใช้สำหรับเปิด Google Form, เว็บฟอร์ม หรือ URL อื่นๆ
/// มี AppBar พร้อมปุ่มกลับ, refresh, และเปิดใน browser ภายนอก
///
/// รองรับ Android/iOS (WebView ภายในแอป)
/// บน Windows/Web จะ fallback เปิด browser ภายนอกแทน
class WebViewScreen extends StatefulWidget {
  /// URL ของเว็บไซต์ที่ต้องการแสดง
  final String url;

  /// ชื่อหน้าที่แสดงบน AppBar
  final String title;

  const WebViewScreen({
    super.key,
    required this.url,
    this.title = 'แบบฟอร์ม',
  });

  /// เช็คว่า platform รองรับ WebView หรือไม่ (Android/iOS เท่านั้น)
  static bool get isWebViewSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// เปิด URL อัตโนมัติ: ถ้ารองรับ WebView → เปิดในแอป, ถ้าไม่ → เปิด browser ภายนอก
  static Future<void> openUrl(
    BuildContext context, {
    required String url,
    String title = 'แบบฟอร์ม',
  }) async {
    if (isWebViewSupported) {
      // Android/iOS → เปิด WebView ภายในแอป
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WebViewScreen(url: url, title: title),
        ),
      );
    } else {
      // Windows/Web → fallback เปิด browser ภายนอก
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  /// ค่า progress 0.0 - 1.0 (0 = เริ่มโหลด, 1 = โหลดเสร็จ)
  double _progress = 0.0;

  /// แสดง progress bar เฉพาะตอนกำลังโหลด
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // สร้าง WebViewController และตั้งค่าต่างๆ
    _controller = WebViewController()
      // เปิด JavaScript เพื่อให้ Google Form ทำงานได้
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // ตั้งค่า navigation delegate สำหรับติดตาม progress
      ..setNavigationDelegate(
        NavigationDelegate(
          // อัพเดต progress bar ขณะโหลด
          onProgress: (progress) {
            setState(() {
              _progress = progress / 100.0;
              _isLoading = progress < 100;
            });
          },
          // เมื่อเริ่มโหลดหน้าใหม่
          onPageStarted: (_) {
            setState(() {
              _isLoading = true;
            });
          },
          // เมื่อโหลดเสร็จ ซ่อน progress bar
          onPageFinished: (_) {
            setState(() {
              _isLoading = false;
            });
          },
          // จัดการ error
          onWebResourceError: (error) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      // โหลด URL ที่ส่งเข้ามา
      ..loadRequest(Uri.parse(widget.url));
  }

  /// เปิด URL ใน browser ภายนอก (Safari/Chrome)
  Future<void> _openInExternalBrowser() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        // ปุ่มกลับ
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            size: 24,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // ชื่อหน้า
        title: Text(
          widget.title,
          style: AppTypography.subtitle.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // ปุ่ม refresh - โหลดหน้าเว็บใหม่
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 20,
              color: AppColors.textPrimary,
            ),
            onPressed: () => _controller.reload(),
          ),
          // ปุ่มเปิดใน browser ภายนอก
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedShare08,
              size: 20,
              color: AppColors.textPrimary,
            ),
            onPressed: _openInExternalBrowser,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar - แสดงเฉพาะขณะกำลังโหลด
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 3,
            ),
          // WebView แสดงเว็บไซต์
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
