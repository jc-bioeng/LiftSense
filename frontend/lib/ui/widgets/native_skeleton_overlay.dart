/// native_skeleton_overlay.dart — High-performance skeleton overlay using C++ FFI.
///
/// Replaces the pure-Dart SkeletonPainterView with a widget that:
///   1. Delegates all computation (CSV parsing, frame lookup, coordinate
///      mapping) to the native C++ engine via FFI
///   2. Only draws pre-transformed viewport-space points via CustomPaint
///   3. Eliminates GC pressure by reusing native buffers
///
/// The CustomPaint here is deliberately minimal — it receives viewport
/// coordinates and just draws lines/circles. All the heavy lifting
/// (binary search, coordinate transform, confidence filtering) happens
/// in C++ in < 0.1ms per frame.

import 'package:flutter/material.dart';
import '../../native/liftsense_ffi.dart';

/// Native-powered skeleton overlay widget.
///
/// Usage:
/// ```dart
/// NativeSkeletonOverlay(
///   currentPositionMs: videoPositionMs,
///   isActive: true,
/// )
/// ```
///
/// Prerequisites: [LiftsenseNative.init] must have been called before
/// this widget is inserted into the tree.
class NativeSkeletonOverlay extends StatelessWidget {
  final int currentPositionMs;
  final bool isActive;

  const NativeSkeletonOverlay({
    super.key,
    required this.currentPositionMs,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive || !LiftsenseNative.isInitialized) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Single FFI call — all computation in C++ (< 0.1ms)
        final frameData = LiftsenseNative.queryFrame(
          currentPositionMs,
          constraints.maxWidth,
          constraints.maxHeight,
        );

        if (!frameData.isValid) return const SizedBox.shrink();

        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _NativeSkeletonPainter(frameData: frameData),
        );
      },
    );
  }
}

/// Minimal CustomPainter — only draws pre-transformed points.
/// All coordinate mapping and confidence filtering already done in C++.
class _NativeSkeletonPainter extends CustomPainter {
  final NativeFrameData frameData;

  // Color palette matching the original SkeletonPainterView
  static const _colors = [
    Color(0xFF00D4AA), // Group 0: Torso — teal
    Color(0xFF4FC3F7), // Group 1: Arms — light blue
    Color(0xFFFFB627), // Group 2: Legs — amber
  ];

  _NativeSkeletonPainter({required this.frameData});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;

    // ── Layer 0: Volumetric Atmosphere (Fondo con brillo) ────
    for (final conn in frameData.connections) {
      final p1 = frameData.points[conn.fromIdx];
      final p2 = frameData.points[conn.toIdx];
      if (!p1.valid || !p2.valid) continue;

      final color = _colors[conn.group.clamp(0, 2)];
      canvas.drawLine(
        Offset(p1.x, p1.y),
        Offset(p2.x, p2.y),
        paint
          ..color = color.withValues(alpha: 0.15)
          ..strokeWidth = 12.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Layer 1: Bones (Bielas principales) ──────────────────
    paint.maskFilter = null;
    for (final conn in frameData.connections) {
      final p1 = frameData.points[conn.fromIdx];
      final p2 = frameData.points[conn.toIdx];
      if (!p1.valid || !p2.valid) continue;

      final color = _colors[conn.group.clamp(0, 2)];
      canvas.drawLine(
        Offset(p1.x, p1.y),
        Offset(p2.x, p2.y),
        paint
          ..color = color.withValues(alpha: 0.85)
          ..strokeWidth = 8.0
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Layer 2: Joints (Diferenciación Jerárquica) ──────────
    for (int i = 0; i < frameData.points.length; i++) {
      final point = frameData.points[i];
      if (!point.valid) continue;

      final Offset pos = Offset(point.x, point.y);
      
      // Determinar importancia y color de grupo
      double coreSize = 5.0;
      double glowSize = 10.0;
      double glowOpacity = 0.35;
      
      // Mapeo manual de grupos por índice (Mismo que en C++)
      // 0: Nariz/Hombros/Cadera, 1: Brazos, 2: Piernas
      int group = 0;
      if (i >= 3 && i <= 6) {
        group = 1; // Brazos
      } else if (i >= 9) {
        group = 2; // Piernas (Rodilla, Tobillo, Talón, Pie)
      }

      if (i >= 7 && i <= 12) {
        // Articulaciones de carga principal (Cadera, Rodilla, Tobillo)
        coreSize = 8.0;
        glowSize = 18.0;
        glowOpacity = 0.5;
      } else if (i == 1 || i == 2 || i >= 13) {
        // Hombros y pies (soporte secundario)
        coreSize = 6.0;
        glowSize = 12.0;
      }

      final color = _colors[group];

      // A. Glow exterior cromático
      canvas.drawCircle(
        pos, 
        glowSize, 
        paint
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: glowOpacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSize / 3),
      );

      // B. Núcleo sólido (Blanco para máxima precisión)
      canvas.drawCircle(
        pos, 
        coreSize, 
        paint
          ..maskFilter = null
          ..color = Colors.white.withValues(alpha: 0.95),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NativeSkeletonPainter old) {
    // Only repaint if the frame actually changed
    return old.frameData.frameIndex != frameData.frameIndex;
  }
}
