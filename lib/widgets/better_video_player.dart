import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class BetterVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const BetterVideoPlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  State<BetterVideoPlayer> createState() => _BetterVideoPlayerState();
}

class _BetterVideoPlayerState extends State<BetterVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (kIsWeb || !Platform.isWindows) {
      try {
        _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
        await _videoPlayerController!.initialize();

        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: false,
          looping: false,
          showControls: true,
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text(
                '無法播放影片: $errorMessage',
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
          placeholder: Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );

        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
          });
        }
        print('影片播放器初始化錯誤: $e');
      }
    } else {
      setState(() {
        _error = '目前 Windows 平台不支援影片播放功能';
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            if (kIsWeb || !Platform.isWindows) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重試'),
                onPressed: _initializePlayer,
              ),
            ],
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return AspectRatio(
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }
} 