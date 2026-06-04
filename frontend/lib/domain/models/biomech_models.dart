import 'package:flutter/foundation.dart';

/// Define the reliability of a specific biomechanical calculation.
/// Final score is a weighted multiplication: View * Visibility * Temporal * Occlusion
class BiomechConfidence {
  final double score; // 0.0 to 1.0
  final String? unavailabilityReason; // Explains why score is too low (e.g., 'Occlusion', 'Frontal View')

  const BiomechConfidence({
    required this.score,
    this.unavailabilityReason,
  });

  bool get isReliable => score > 0.7;
  bool get isWarning => score > 0.3 && score <= 0.7;
  bool get isHidden => score <= 0.3;

  static const optimal = BiomechConfidence(score: 1.0);
}

/// A generic segment of movement (replaces SquatPhase)
class MovementSegment {
  final int startMs;
  final int endMs;
  final String phaseType; // e.g., 'DESCEND', 'BOTTOM', 'ASCEND'
  final int repId;
  final BiomechConfidence confidence;

  const MovementSegment({
    required this.startMs,
    required this.endMs,
    required this.phaseType,
    required this.repId,
    required this.confidence,
  });
}

/// The single, immutable state emitted at 60 FPS for rendering.
@immutable
class BiomechFrameRealtime {
  final int frameId; // Monotonically increasing for debugging/sync
  final int timestampMs;
  final String currentPhase;
  final int repId;
  final String sourceView; // 'FRONTAL' or 'LATERAL'

  // Pre-calculated geometric angles
  final Map<String, double> jointAngles;
  // Deep biomechanical proxies (Torque, COM, Velocity)
  final Map<String, double> metrics;
  // Specific confidence logic per metric based on View and Occlusion
  final Map<String, BiomechConfidence> confidences;

  const BiomechFrameRealtime({
    required this.frameId,
    required this.timestampMs,
    required this.currentPhase,
    required this.repId,
    required this.sourceView,
    required this.jointAngles,
    required this.metrics,
    required this.confidences,
  });

  static const empty = BiomechFrameRealtime(
    frameId: 0,
    timestampMs: 0,
    currentPhase: 'IDLE',
    repId: 0,
    sourceView: 'UNKNOWN',
    jointAngles: {},
    metrics: {},
    confidences: {},
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiomechFrameRealtime &&
          runtimeType == other.runtimeType &&
          frameId == other.frameId;

  @override
  int get hashCode => frameId.hashCode;
}
