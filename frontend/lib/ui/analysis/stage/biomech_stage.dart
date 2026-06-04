import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../coordinator/analysis_playback_controller.dart';
import '../coordinator/analysis_scroll_controller.dart';
import '../../widgets/native_skeleton_overlay.dart';

class BiomechStage extends StatelessWidget {
  final AnalysisPlaybackController playback;
  final AnalysisScrollController scroll;
  final bool nativeEngineReady;
  final double expandedHeight;
  final double collapsedHeight;

  const BiomechStage({
    super.key,
    required this.playback,
    required this.scroll,
    required this.nativeEngineReady,
    required this.expandedHeight,
    required this.collapsedHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (!playback.isInitialized) return const SizedBox.shrink();

    return ValueListenableBuilder<double>(
      valueListenable: scroll.scrollProgress,
      builder: (context, progress, child) {
        final p = (progress * 1.5).clamp(0.0, 1.0);

        final videoWidth = playback.videoController?.value.size.width ?? 1080;
        final videoHeight = playback.videoController?.value.size.height ?? 1920;

        final scale = 1.0 - (0.65 * p);

        final topPadding = MediaQuery.of(context).padding.top;
        final headerHeight = topPadding + 64;

        final targetCenterY = (headerHeight + collapsedHeight) / 2;
        final targetY = targetCenterY - (expandedHeight / 2);

        final size = MediaQuery.of(context).size;

        return ClipRect(
          child: IgnorePointer(
            ignoring: false,
            child: Transform.translate(
              offset: Offset(0, targetY * p),
              child: SizedBox(
                width: size.width,
                height: expandedHeight,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.scale(
                    scale: scale,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: videoWidth,
                        height: videoHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(
                              child: GestureDetector(
                                onTap: playback.togglePlayPause,
                                child: VideoPlayer(playback.videoController!),
                              ),
                            ),
                            if (nativeEngineReady)
                              // Conectar positionMs dinámicamente al overlay de esqueleto
                              ValueListenableBuilder<int>(
                                valueListenable: playback.positionMs,
                                builder: (context, posMs, _) {
                                  return RepaintBoundary(
                                    child: NativeSkeletonOverlay(
                                      currentPositionMs: posMs,
                                      isActive: true,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
