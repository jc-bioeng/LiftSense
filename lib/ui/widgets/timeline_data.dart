import 'package:flutter/material.dart';

enum AlertSeverity { INFO, WARNING, SEVERE, CRITICAL }

class BiomechEvent {
  final int timeMs;
  final String type; // 'STICKING_POINT', 'VALGUS', 'BUTT_WINK'
  final AlertSeverity severity;

  const BiomechEvent(this.timeMs, this.type, this.severity);
}

class TimelineDataPoint {
  final int timeMs;
  final double depth;
  final double velocity;
  final int phase; // 0: IDLE, 1: DESCENDING, 2: BOTTOM, 3: ASCENDING
  final bool isCriticalNode; // Protected from decimation

  const TimelineDataPoint({
    required this.timeMs,
    required this.depth,
    required this.velocity,
    required this.phase,
    this.isCriticalNode = false,
  });
}

class TimelineCluster {
  final int startTimeMs;
  final int endTimeMs;
  final AlertSeverity highestSeverity;
  final int eventCount;

  const TimelineCluster(
    this.startTimeMs,
    this.endTimeMs,
    this.highestSeverity,
    this.eventCount,
  );
}

class TimelineDataProcessor {
  /// Biomechanically-aware Decimation
  /// Reduce los puntos a dibujar, pero protege nodos biomecánicos críticos.
  static List<TimelineDataPoint> optimizePoints(
    List<TimelineDataPoint> raw,
    double tolerance,
  ) {
    if (raw.length <= 2) return raw;

    // 1. Identificar Nodos Críticos (Max/Min de profundidad, cambios de fase, sticking points)
    List<TimelineDataPoint> protected = [];
    int lastPhase = -1;

    for (int i = 0; i < raw.length; i++) {
      bool isCritical = raw[i].isCriticalNode;
      // Proteger transiciones de fase
      if (raw[i].phase != lastPhase) {
        isCritical = true;
        lastPhase = raw[i].phase;
      }

      // Proteger máximos locales de profundidad (Bottom)
      if (i > 0 && i < raw.length - 1) {
        if ((raw[i].depth > raw[i - 1].depth &&
                raw[i].depth > raw[i + 1].depth) ||
            (raw[i].velocity == 0 &&
                raw[i - 1].velocity < 0 &&
                raw[i + 1].velocity > 0)) {
          isCritical = true;
        }
      }

      if (isCritical || i == 0 || i == raw.length - 1) {
        protected.add(
          TimelineDataPoint(
            timeMs: raw[i].timeMs,
            depth: raw[i].depth,
            velocity: raw[i].velocity,
            phase: raw[i].phase,
            isCriticalNode: true,
          ),
        );
      } else {
        protected.add(raw[i]);
      }
    }

    // 2. Douglas-Peucker parcial (sólo entre nodos protegidos)
    return _adaptiveDecimation(protected, tolerance);
  }

  static List<TimelineDataPoint> _adaptiveDecimation(
    List<TimelineDataPoint> points,
    double epsilon,
  ) {
    // Si todos son críticos, no decimamos
    if (points.length <= 2) return points;

    // Implementación simplificada de Douglas-Peucker preservando 'isCriticalNode'
    // En una implementación real se particiona el array iterativamente por distancia ortogonal.
    // Aquí hacemos un salto heurístico para simular la reducción protegiendo críticos.
    List<TimelineDataPoint> result = [];
    result.add(points.first);

    for (int i = 1; i < points.length - 1; i++) {
      if (points[i].isCriticalNode) {
        result.add(points[i]);
      } else {
        // Drop lógico si la diferencia geométrica es menor al epsilon (simplificación)
        double dy = (points[i].depth - points[i - 1].depth).abs();
        if (dy > epsilon) {
          result.add(points[i]);
        }
      }
    }
    result.add(points.last);
    return result;
  }

  /// Clusterea eventos cercanos para evitar solapamiento visual
  static List<TimelineCluster> clusterEvents(
    List<BiomechEvent> events,
    int msTolerance,
  ) {
    if (events.isEmpty) return [];

    List<TimelineCluster> clusters = [];
    events.sort((a, b) => a.timeMs.compareTo(b.timeMs));

    int currentStart = events[0].timeMs;
    int currentEnd = events[0].timeMs;
    int count = 1;
    AlertSeverity maxSev = events[0].severity;

    for (int i = 1; i < events.length; i++) {
      if (events[i].timeMs - currentEnd <= msTolerance) {
        currentEnd = events[i].timeMs;
        count++;
        if (events[i].severity.index > maxSev.index) {
          maxSev = events[i].severity;
        }
      } else {
        clusters.add(TimelineCluster(currentStart, currentEnd, maxSev, count));
        currentStart = events[i].timeMs;
        currentEnd = events[i].timeMs;
        count = 1;
        maxSev = events[i].severity;
      }
    }
    clusters.add(TimelineCluster(currentStart, currentEnd, maxSev, count));

    return clusters;
  }
}
