import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../domain/biomech_frame_realtime.dart';
import '../../domain/bio_idx.dart';
import '../../services/biomech_frame_bus.dart';

/// Skeleton overlay reactivo que se suscribe al BiomechFrameBus y renderiza a 60Hz.
class NativeSkeletonOverlay extends StatefulWidget {
  final int currentPositionMs;
  final bool isActive;

  const NativeSkeletonOverlay({
    super.key,
    required this.currentPositionMs,
    this.isActive = true,
  });

  @override
  State<NativeSkeletonOverlay> createState() => _NativeSkeletonOverlayState();
}

class _NativeSkeletonOverlayState extends State<NativeSkeletonOverlay> {
  Float32List? _fixedFloorPoints;

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: BiomechFrameBus.instance.frameNotifier,
      builder: (context, frame, _) {
        if (frame.isEmpty || frame.skeletonBuffer.isEmpty) {
          return const SizedBox.shrink();
        }

        // Calibrar el suelo dinámicamente si no está hecho
        if (_fixedFloorPoints == null) {
          final buf = frame.skeletonBuffer;
          final lHeelC = buf[BioIdx.lHeel * 3 + BioIdx.offsetC];
          final rHeelC = buf[BioIdx.rHeel * 3 + BioIdx.offsetC];
          final lFootC = buf[BioIdx.lFootIndex * 3 + BioIdx.offsetC];
          final rFootC = buf[BioIdx.rFootIndex * 3 + BioIdx.offsetC];

          if (lHeelC >= 0 && rHeelC >= 0 && lFootC >= 0 && rFootC >= 0) {
            final lHeelX = buf[BioIdx.lHeel * 3 + BioIdx.offsetX];
            final lHeelY = buf[BioIdx.lHeel * 3 + BioIdx.offsetY];
            final rHeelX = buf[BioIdx.rHeel * 3 + BioIdx.offsetX];
            final rHeelY = buf[BioIdx.rHeel * 3 + BioIdx.offsetY];
            final lFootX = buf[BioIdx.lFootIndex * 3 + BioIdx.offsetX];
            final lFootY = buf[BioIdx.lFootIndex * 3 + BioIdx.offsetY];
            final rFootX = buf[BioIdx.rFootIndex * 3 + BioIdx.offsetX];
            final rFootY = buf[BioIdx.rFootIndex * 3 + BioIdx.offsetY];

            final cx = (lHeelX + rHeelX + lFootX + rFootX) / 4;
            final cy = (lHeelY + rHeelY + lFootY + rFootY) / 4;

            final scale = 2.0;

            _fixedFloorPoints = Float32List(8);
            _fixedFloorPoints![0] = cx + (lHeelX - cx) * scale;
            _fixedFloorPoints![1] = cy + (lHeelY - cy) * scale;
            _fixedFloorPoints![2] = cx + (rHeelX - cx) * scale;
            _fixedFloorPoints![3] = cy + (rHeelY - cy) * scale;
            _fixedFloorPoints![4] = cx + (rFootX - cx) * scale;
            _fixedFloorPoints![5] = cy + (rFootY - cy) * scale;
            _fixedFloorPoints![6] = cx + (lFootX - cx) * scale;
            _fixedFloorPoints![7] = cy + (lFootY - cy) * scale;
          }
        }

        return SizedBox.expand(
          child: CustomPaint(
            painter: _FlatSkeletonPainter(
              frame.skeletonBuffer, 
              frame.frameIndex,
              fixedFloorPoints: _fixedFloorPoints,
            ),
          ),
        );
      },
    );
  }
}

// ─── Topología Estática del Esqueleto (17-point MediaPipe) ──────────────────
// Formato: [fromIdx, toIdx, group]  group: 0=Torso, 1=Brazos, 2=Piernas
const List<int> _kEdges = [
  BioIdx.lShoulder,  BioIdx.rShoulder,  0,
  BioIdx.lShoulder,  BioIdx.lHip,       0,
  BioIdx.rShoulder,  BioIdx.rHip,       0,
  BioIdx.lHip,       BioIdx.rHip,       0,
  
  BioIdx.lShoulder,  BioIdx.lElbow,     1,
  BioIdx.lElbow,     BioIdx.lWrist,     1,
  BioIdx.rShoulder,  BioIdx.rElbow,     1,
  BioIdx.rElbow,     BioIdx.rWrist,     1,
  
  BioIdx.lHip,       BioIdx.lKnee,      2,
  BioIdx.lKnee,      BioIdx.lAnkle,     2,
  BioIdx.lAnkle,     BioIdx.lHeel,      2,
  BioIdx.lHeel,      BioIdx.lFootIndex, 2,
  BioIdx.lAnkle,     BioIdx.lFootIndex, 2,
  
  BioIdx.rHip,       BioIdx.rKnee,      2,
  BioIdx.rKnee,      BioIdx.rAnkle,     2,
  BioIdx.rAnkle,     BioIdx.rHeel,      2,
  BioIdx.rHeel,      BioIdx.rFootIndex, 2,
  BioIdx.rAnkle,     BioIdx.rFootIndex, 2,
];

const _kColors = [
  Color(0xFF00D4AA), // Torso
  Color(0xFF00D4AA), // Brazos
  Color(0xFF00D4AA), // Piernas
];

class _FlatSkeletonPainter extends CustomPainter {
  final Float32List buf; // 51 floats contiguos sin offset de frameIndex
  final int frameIndex;
  final Float32List? fixedFloorPoints;

  static final Paint _bonePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 8.0;

  static final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 12.0
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

  static final Paint _jointPaint = Paint()
    ..style = PaintingStyle.fill;

  static final Paint _glowJointPaint = Paint()
    ..style = PaintingStyle.fill;

  const _FlatSkeletonPainter(this.buf, this.frameIndex, {this.fixedFloorPoints});

  @override
  void paint(Canvas canvas, Size size) {
    // ── Layer -1: Plataforma del Suelo ──────────────────
    if (fixedFloorPoints != null) {
      final p1x = fixedFloorPoints![0];
      final p1y = fixedFloorPoints![1];
      final p2x = fixedFloorPoints![2];
      final p2y = fixedFloorPoints![3];
      final p3x = fixedFloorPoints![4];
      final p3y = fixedFloorPoints![5];
      final p4x = fixedFloorPoints![6];
      final p4y = fixedFloorPoints![7];

      final path = Path()
        ..moveTo(p1x, p1y)
        ..lineTo(p2x, p2y)
        ..lineTo(p3x, p3y)
        ..lineTo(p4x, p4y)
        ..close();

      canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.03)..style = PaintingStyle.fill);
      canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 1.0);

      // Líneas cruzadas de la plataforma
      canvas.drawLine(Offset((p1x + p2x) / 2, (p1y + p2y) / 2), Offset((p4x + p3x) / 2, (p4y + p3y) / 2), Paint()..color = Colors.white.withValues(alpha: 0.15)..strokeWidth = 1.0);
      canvas.drawLine(Offset((p1x + p4x) / 2, (p1y + p4y) / 2), Offset((p2x + p3x) / 2, (p2y + p3y) / 2), Paint()..color = Colors.white.withValues(alpha: 0.15)..strokeWidth = 1.0);
    }

    // ── Layer 0: Resplandor del Hueso (Bone Glow) ───────────
    for (int e = 0; e < _kEdges.length; e += 3) {
      final fromIdx = _kEdges[e];
      final toIdx = _kEdges[e + 1];
      final group = _kEdges[e + 2];

      final fx = buf[fromIdx * 3 + BioIdx.offsetX];
      final fy = buf[fromIdx * 3 + BioIdx.offsetY];
      final fc = buf[fromIdx * 3 + BioIdx.offsetC];
      final tx = buf[toIdx * 3 + BioIdx.offsetX];
      final ty = buf[toIdx * 3 + BioIdx.offsetY];
      final tc = buf[toIdx * 3 + BioIdx.offsetC];

      if (fc < 0 || tc < 0) continue;

      final color = _kColors[group.clamp(0, 2)];
      canvas.drawLine(
        Offset(fx, fy),
        Offset(tx, ty),
        _glowPaint..color = color.withValues(alpha: 0.15),
      );
    }

    // ── Layer 1: Huesos Sólidos ────────────────────────────
    for (int e = 0; e < _kEdges.length; e += 3) {
      final fromIdx = _kEdges[e];
      final toIdx = _kEdges[e + 1];
      final group = _kEdges[e + 2];

      final fx = buf[fromIdx * 3 + BioIdx.offsetX];
      final fy = buf[fromIdx * 3 + BioIdx.offsetY];
      final fc = buf[fromIdx * 3 + BioIdx.offsetC];
      final tx = buf[toIdx * 3 + BioIdx.offsetX];
      final ty = buf[toIdx * 3 + BioIdx.offsetY];
      final tc = buf[toIdx * 3 + BioIdx.offsetC];

      if (fc < 0 || tc < 0) continue;

      final color = _kColors[group.clamp(0, 2)];
      canvas.drawLine(
        Offset(fx, fy),
        Offset(tx, ty),
        _bonePaint..color = color.withValues(alpha: 0.85),
      );
    }

    // ── Layer 2: Articulaciones (Joints) ───────────────────
    for (int i = 0; i < 17; i++) {
      if (i == BioIdx.nose) continue; // Nariz excluida del pintado clínico
      
      final x = buf[i * 3 + BioIdx.offsetX];
      final y = buf[i * 3 + BioIdx.offsetY];
      final c = buf[i * 3 + BioIdx.offsetC];
      if (c < 0) continue;

      final int group = (i >= 3 && i <= 6) ? 1 : (i >= 7 ? 2 : 0);
      final color = _kColors[group];

      final double coreSize = (i == BioIdx.lShoulder || i == BioIdx.rShoulder || i == BioIdx.lHip || i == BioIdx.rHip)
          ? 9.0
          : ((i == BioIdx.lKnee || i == BioIdx.rKnee || i == BioIdx.lAnkle || i == BioIdx.rAnkle)
              ? 7.0
              : 5.0);
      final double glowSize = coreSize * 2.25;

      canvas.drawCircle(
        Offset(x, y),
        glowSize,
        _glowJointPaint
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSize / 3),
      );

      canvas.drawCircle(
        Offset(x, y),
        coreSize,
        _jointPaint
          ..color = Colors.white.withValues(alpha: 0.95)
          ..maskFilter = null,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlatSkeletonPainter old) =>
      old.frameIndex != frameIndex;
}
