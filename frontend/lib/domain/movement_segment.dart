import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
//  MOVEMENT SEGMENT — Reemplazo genérico de SquatPhase
//  Compatible con: Squat, Deadlift, Bench, Lunge, etc.
// ═══════════════════════════════════════════════════════════════

class MovementSegment {
  final int startMs;
  final int endMs;
  final String phaseType; // 'DESCENDING', 'BOTTOM', 'ASCENDING', 'STICKING_POINT', 'LOCKOUT', 'PULL', etc.
  final int repId;
  final double confidence;
  final Color displayColor;
  final String displayLabel; // Localizable label for UI

  const MovementSegment({
    required this.startMs,
    required this.endMs,
    required this.phaseType,
    this.repId = 0,
    this.confidence = 1.0,
    required this.displayColor,
    required this.displayLabel,
  });

  double get durationMs => (endMs - startMs).toDouble();

  /// Calculates the percentage range within a total duration
  double startPercent(int totalDurationMs) =>
      totalDurationMs > 0 ? startMs / totalDurationMs : 0.0;
  double endPercent(int totalDurationMs) =>
      totalDurationMs > 0 ? endMs / totalDurationMs : 0.0;

  /// Default squat segments (fallback when C++ hasn't processed yet)
  static List<MovementSegment> defaultSquatSegments(int totalDurationMs) {
    return [
      MovementSegment(
        startMs: 0,
        endMs: (totalDurationMs * 0.35).toInt(),
        phaseType: 'DESCENDING',
        displayColor: const Color(0xFF00D4AA),
        displayLabel: 'DESCENSO',
      ),
      MovementSegment(
        startMs: (totalDurationMs * 0.35).toInt(),
        endMs: (totalDurationMs * 0.50).toInt(),
        phaseType: 'BOTTOM',
        displayColor: const Color(0xFFFFB627),
        displayLabel: 'FONDO',
      ),
      MovementSegment(
        startMs: (totalDurationMs * 0.50).toInt(),
        endMs: (totalDurationMs * 0.85).toInt(),
        phaseType: 'ASCENDING',
        displayColor: const Color(0xFF007BFF),
        displayLabel: 'ASCENSO',
      ),
      MovementSegment(
        startMs: (totalDurationMs * 0.85).toInt(),
        endMs: totalDurationMs,
        phaseType: 'LOCKOUT',
        displayColor: const Color(0xFF8B5CF6),
        displayLabel: 'LOCKOUT',
      ),
    ];
  }
}
