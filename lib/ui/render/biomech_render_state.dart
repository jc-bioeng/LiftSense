import 'package:flutter/material.dart';

/// Define las conexiones anatómicas del esqueleto
class SkeletonConnection {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  const SkeletonConnection({
    required this.start,
    required this.end,
    required this.color,
    this.strokeWidth = 3.0,
  });
}

/// Define textos flotantes (ej. ángulos o velocidades)
class HUDLabel {
  final Offset position;
  final String text;
  final Color color;

  const HUDLabel({
    required this.position,
    required this.text,
    required this.color,
  });
}

/// Estado precomputado: El CustomPainter solo consumirá esto, cero matemática.
class BiomechRenderState {
  final List<SkeletonConnection> bones;
  final List<HUDLabel> labels;
  
  // COM Projection (Dashed line)
  final Offset? comStart;
  final Offset? comEnd;
  final Color comColor;

  final int phase; // 0=IDLE, 1=DESC, 2=BOTTOM, 3=ASC, 4=STICKING
  final String phaseText;
  final Color phaseColor;

  const BiomechRenderState({
    this.bones = const [],
    this.labels = const [],
    this.comStart,
    this.comEnd,
    this.comColor = Colors.cyanAccent,
    this.phase = 0,
    this.phaseText = 'IDLE',
    this.phaseColor = Colors.white,
  });

  static const BiomechRenderState empty = BiomechRenderState();
}
