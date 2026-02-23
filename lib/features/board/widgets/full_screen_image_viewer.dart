import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';

/// เปิดหน้าดูรูปเต็มจอพร้อม zoom และ swipe ดูรูปอื่น
///
/// [urls] - รายการ URL รูปทั้งหมด
/// [initialIndex] - index ของรูปที่ต้องการเปิดก่อน
void showFullScreenImage(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FullScreenImageViewer(
        imageUrls: urls,
        initialIndex: initialIndex,
      ),
    ),
  );
}

/// หน้าดูรูปเต็มจอ พร้อม zoom (InteractiveViewer) และ swipe (PageView)
/// ใช้ร่วมกันได้ทุกหน้าที่ต้องการขยายรูป
class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: IreneSecondaryAppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.imageUrls.length > 1
            ? '${_currentIndex + 1} / ${widget.imageUrls.length}'
            : null,
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.imageUrls[index],
                fit: BoxFit.cover,
                progressIndicatorBuilder: (context, url, progress) => Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress.progress,
                        color: AppColors.primary,
                        strokeWidth: 3,
                        backgroundColor: Colors.white24,
                      ),
                      if (progress.progress != null)
                        Text(
                          '${(progress.progress! * 100).toInt()}%',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                errorWidget: (context, url, error) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedImage01,
                      size: AppIconSize.xxxl,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'ไม่สามารถโหลดรูปได้',
                      style:
                          AppTypography.body.copyWith(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
