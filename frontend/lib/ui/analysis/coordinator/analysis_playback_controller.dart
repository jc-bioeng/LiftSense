import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class AnalysisPlaybackController {
  VideoPlayerController? videoController;
  final ValueNotifier<bool> isPlaying = ValueNotifier(false);
  final ValueNotifier<int> positionMs = ValueNotifier(0);
  final ValueNotifier<double> progress = ValueNotifier(0.0);
  final ValueNotifier<double> speed = ValueNotifier(1.0);
  
  bool get isInitialized => videoController?.value.isInitialized ?? false;

  Future<void> initFromFile(File file) async {
    videoController = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    await videoController!.initialize();
    videoController!.addListener(_onVideoProgress);
    await videoController!.setLooping(true);
  }

  void _onVideoProgress() {
    if (!isInitialized) return;
    final pos = videoController!.value.position;
    final dur = videoController!.value.duration;
    
    // Solo notificamos si cambia el milisegundo para no saturar
    if (pos.inMilliseconds != positionMs.value) {
      positionMs.value = pos.inMilliseconds;
      progress.value = dur.inMilliseconds > 0 
          ? pos.inMilliseconds / dur.inMilliseconds 
          : 0.0;
    }
  }

  void play() {
    videoController?.play();
    isPlaying.value = true;
    // Asegurar que la velocidad se mantenga al reanudar
    videoController?.setPlaybackSpeed(speed.value);
  }

  void pause() {
    videoController?.pause();
    isPlaying.value = false;
  }

  void togglePlayPause() {
    HapticFeedback.lightImpact();
    if (isPlaying.value) {
      pause();
    } else {
      play();
    }
  }

  void setSpeed(double newSpeed) {
    HapticFeedback.mediumImpact();
    speed.value = newSpeed;
    if (isInitialized) {
      videoController?.setPlaybackSpeed(newSpeed);
    }
  }

  void seekTo(Duration position) {
    videoController?.seekTo(position);
  }

  void dispose() {
    videoController?.removeListener(_onVideoProgress);
    videoController?.dispose();
    isPlaying.dispose();
    positionMs.dispose();
    progress.dispose();
    speed.dispose();
  }
}

