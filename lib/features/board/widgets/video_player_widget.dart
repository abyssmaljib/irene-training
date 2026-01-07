import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Widget สำหรับเล่นวิดีโอจาก URL
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool showControls;
  final double? aspectRatio;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.showControls = true,
    this.aspectRatio,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitializing = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeControllers();
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    setState(() {
      _isInitializing = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(widget.videoUrl);
      _videoController = VideoPlayerController.networkUrl(uri);

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: widget.autoPlay,
        looping: false,
        showControls: widget.showControls,
        aspectRatio: widget.aspectRatio ?? _videoController!.value.aspectRatio,
        placeholder: Container(
          color: AppColors.background,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget(errorMessage);
        },
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('VideoPlayerWidget initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedVideoOff,
              size: AppIconSize.xxxl,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'ไม่สามารถเล่นวิดีโอได้',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _initializeVideo,
              icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: AppIconSize.md),
              label: Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
              const SizedBox(height: 12),
              Text(
                'กำลังโหลดวิดีโอ...',
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError || _chewieController == null) {
      return _buildErrorWidget(_errorMessage ?? 'Unknown error');
    }

    return Chewie(controller: _chewieController!);
  }
}

/// Widget สำหรับแสดง video thumbnail ที่กดแล้วเปิด video player
class VideoThumbnailPlayer extends StatefulWidget {
  final String videoUrl;
  final double? height;
  final double? width;
  final BoxFit fit;

  const VideoThumbnailPlayer({
    super.key,
    required this.videoUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoThumbnailPlayer> createState() => _VideoThumbnailPlayerState();
}

class _VideoThumbnailPlayerState extends State<VideoThumbnailPlayer> {
  bool _showPlayer = false;

  @override
  Widget build(BuildContext context) {
    if (_showPlayer) {
      return SizedBox(
        height: widget.height,
        width: widget.width,
        child: VideoPlayerWidget(
          videoUrl: widget.videoUrl,
          autoPlay: true,
          showControls: true,
        ),
      );
    }

    // แสดง placeholder พร้อมปุ่มเล่น
    return GestureDetector(
      onTap: () {
        setState(() {
          _showPlayer = true;
        });
      },
      child: Container(
        height: widget.height,
        width: widget.width,
        color: AppColors.background,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video icon background
            HugeIcon(
              icon: HugeIcons.strokeRoundedVideo01,
              size: AppIconSize.display,
              color: AppColors.secondaryText.withValues(alpha: 0.3),
            ),

            // Play button overlay
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedPlay,
                size: AppIconSize.xxl,
                color: Colors.white,
              ),
            ),

            // Label
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'แตะเพื่อเล่นวิดีโอ',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full screen video player dialog
class FullScreenVideoPlayer extends StatelessWidget {
  final String videoUrl;

  const FullScreenVideoPlayer({
    super.key,
    required this.videoUrl,
  });

  static void show(BuildContext context, String videoUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPlayer(videoUrl: videoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: VideoPlayerWidget(
          videoUrl: videoUrl,
          autoPlay: true,
          showControls: true,
        ),
      ),
    );
  }
}
