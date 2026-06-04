import 'dart:math';
import 'dart:typed_data';
import '../domain/movement_segment.dart';
import '../domain/vbt_summary.dart';

class VbtCalculator {
  /// Calcula el perfil VBT a partir de la trayectoria Y del CoM y los segmentos de movimiento detectados.
  static VbtSummary calculate({
    required Float32List comYSeries,
    required List<MovementSegment> segments,
    required double videoHeight,
  }) {
    // 1. Filtrar segmentos de fase concéntrica ('ASCENSO' / 'ASCENDING')
    final concentricSegments = segments
        .where((s) => s.phaseType == 'ASCENSO' || s.phaseType == 'ASCENDING')
        .toList();
        
    if (concentricSegments.isEmpty || comYSeries.isEmpty) {
      return VbtSummary.empty;
    }

    // Ordenar por repetición
    concentricSegments.sort((a, b) => a.repId.compareTo(b.repId));

    final repMeanVelocities = <double>[];
    final repPeakVelocities = <double>[];

    // Constante física de conversión: píxeles a metros
    // Estimamos que una carrera vertical típica de squat de ~0.6m representa el 25% de la altura del video.
    // Esto se ajusta al alto del viewport del video.
    final double metersPerPixel = 0.6 / (videoHeight * 0.25).clamp(200.0, 600.0);

    for (final seg in concentricSegments) {
      // Suponemos intervalos fijos de frame de ~33.3ms
      final startIdx = (seg.startMs / 33.33).round().clamp(0, comYSeries.length - 1);
      final endIdx = (seg.endMs / 33.33).round().clamp(0, comYSeries.length - 1);

      if (startIdx >= endIdx) continue;

      final velocities = <double>[];
      for (int i = startIdx + 1; i <= endIdx; i++) {
        // En coordenadas de pantalla, Y aumenta hacia abajo.
        // Un movimiento hacia arriba (con concéntrico) significa que Y disminuye.
        // Por ende, dy = comY[i-1] - comY[i] es positivo para ascenso.
        final double dy = comYSeries[i - 1] - comYSeries[i];
        const double dt = 0.03333; // 33.33ms en segundos (30 FPS)
        
        final double instantVel = (dy * metersPerPixel) / dt;
        velocities.add(instantVel);
      }

      if (velocities.isEmpty) continue;

      // MPV (Mean Propulsive Velocity): promedio de las velocidades concéntricas propulsivas (> 0.1 m/s)
      final positiveVelocities = velocities.where((v) => v > 0.1).toList();
      final double meanVel = positiveVelocities.isEmpty
          ? velocities.reduce((a, b) => a + b) / velocities.length
          : positiveVelocities.reduce((a, b) => a + b) / positiveVelocities.length;

      final double peakVel = velocities.reduce(max);

      // Limitar a valores físicamente realistas
      repMeanVelocities.add(meanVel.clamp(0.2, 1.8));
      repPeakVelocities.add(peakVel.clamp(0.3, 2.5));
    }

    if (repMeanVelocities.isEmpty) {
      return VbtSummary.empty;
    }

    final double overallMean = repMeanVelocities.reduce((a, b) => a + b) / repMeanVelocities.length;
    final double overallPeak = repPeakVelocities.reduce(max);

    // Drop-off de velocidad: decaimiento entre la primera y la última repetición (fatiga del set)
    final double firstMean = repMeanVelocities.first;
    final double lastMean = repMeanVelocities.last;
    final double dropOff = firstMean > 0 ? ((firstMean - lastMean) / firstMean) * -100.0 : 0.0;

    return VbtSummary(
      repMeanVelocities: repMeanVelocities,
      repPeakVelocities: repPeakVelocities,
      meanVelocity: overallMean,
      peakVelocity: overallPeak,
      velocityLossPercent: dropOff,
      repCount: repMeanVelocities.length,
    );
  }
}
