import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../render/biomech_painter.dart';
import '../render/biomech_render_state.dart';

class BiomechOverlay extends StatelessWidget {
  final VideoPlayerController videoController;
  final BiomechRenderState renderState;

  const BiomechOverlay({
    Key? key,
    required this.videoController,
    required this.renderState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. BASE LAYER: Video Player
        RepaintBoundary(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: videoController.value.size.width,
              height: videoController.value.size.height,
              child: VideoPlayer(videoController),
            ),
          ),
        ),

        // 2. MIDDLE LAYER: Biomechanical Skeleton Canvas
        RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: BiomechPainter(renderState),
          ),
        ),

        // 3. TOP LAYER: HUD & Glassmorphism (Phase Indicator)
        Positioned(
          top: 40,
          left: 20,
          child: RepaintBoundary(
            child: _buildPhaseIndicator(),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseIndicator() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: renderState.phaseColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: renderState.phaseColor.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: renderState.phaseColor,
                  boxShadow: [
                    BoxShadow(
                      color: renderState.phaseColor,
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                renderState.phaseText.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontFamily: 'RobotoMono',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
