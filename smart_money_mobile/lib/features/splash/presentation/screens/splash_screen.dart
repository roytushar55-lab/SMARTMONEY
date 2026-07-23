import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/routes/route_names.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _videoController;

  Timer? _fallbackTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.asset(
      'assets/videos/smartmoney_splash.mp4',
    );

    try {
      await _videoController.initialize();
      await _videoController.setVolume(0);
      await _videoController.setLooping(false);

      _videoController.addListener(_videoListener);

      if (!mounted) return;

      setState(() {});
      await _videoController.play();

      // Safety fallback if completion is not detected.
      _fallbackTimer = Timer(const Duration(milliseconds: 4200), _openLogin);
    } catch (_) {
      _fallbackTimer = Timer(const Duration(milliseconds: 800), _openLogin);
    }
  }

  void _videoListener() {
    if (!_videoController.value.isInitialized) return;

    final position = _videoController.value.position;
    final duration = _videoController.value.duration;

    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 100)) {
      _openLogin();
    }
  }

  void _openLogin() {
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;
    _fallbackTimer?.cancel();

    Navigator.pushReplacementNamed(context, RouteNames.login);
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _videoController.removeListener(_videoListener);
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _videoController.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
          child: Center(
            child: isReady
                ? AspectRatio(
                    aspectRatio: _videoController.value.aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: VideoPlayer(_videoController),
                    ),
                  )
                : const CircularProgressIndicator(color: Color(0xFF6334D8)),
          ),
        ),
      ),
    );
  }
}
