import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final bool isNetwork;
  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    required this.isNetwork,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;

  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();

    if (widget.isNetwork) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..initialize().then((_) {
          setState(() {});
          _controller.play();
        });
    } else {
      _controller = VideoPlayerController.file(File(widget.videoUrl))
        ..initialize().then((_) {
          setState(() {});
          _controller.play();
        });
    }

    _controller.setLooping(true);
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Player'),
      ),
      body: RotatedBox(
        quarterTurns: _isFullScreen ? 1 : 0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!_isFullScreen) const Spacer(),
            Expanded(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : Container(),
            ),
            SizedBox(
              height: 8,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: Colors.blueGrey,
                  bufferedColor: Colors.grey.shade400,
                  backgroundColor: Colors.grey,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.all(0),
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "${_controller.value.position.inHours}:${_controller.value.position.inMinutes.remainder(60)}:${(_controller.value.position.inSeconds.remainder(60))} / ${_controller.value.duration.inHours}:${_controller.value.duration.inMinutes.remainder(60)}:${(_controller.value.duration.inSeconds.remainder(60))}",
                  style: const TextStyle(fontSize: 12),
                ),
                const Spacer(),
                CupertinoButton(
                  padding: const EdgeInsets.all(0),
                  child: const Icon(Icons.fullscreen),
                  onPressed: () {
                    setState(() {
                      _isFullScreen = !_isFullScreen;
                    });
                  },
                ),
              ],
            ),
            if (!_isFullScreen) const Spacer(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}

class VideoPlayerThumbNail extends StatelessWidget {
  final VoidCallback onTap;

  const VideoPlayerThumbNail({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        width: double.infinity,
        color: Colors.black38,
        child: Icon(
          Icons.play_circle_filled,
          size: 60,
          color: Colors.grey.shade200,
        ),
      ),
    );
  }
}
