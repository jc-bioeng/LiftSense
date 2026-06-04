/// Métrica biomecánica con scoring de confianza y vista fuente.
///
/// Permite que la UI module la opacidad, el color y la prominencia
/// de cada valor basándose en qué tan confiable es la medición.
class MetricWithConfidence {
  final String jointName; // ej: 'Cadera', 'Rodilla', 'Tobillo', 'Tronco'
  final double value; // Valor angular o proxy (en grados o FLU)
  final double confidence; // 0.0 (interpolado/perdido) → 1.0 (tracking sólido)
  final String sourceView; // 'FRONTAL' | 'LATERAL'
  final String status; // 'optimal' | 'warning' | 'critical'

  const MetricWithConfidence({
    required this.jointName,
    required this.value,
    this.confidence = 1.0,
    this.sourceView = 'LATERAL',
    this.status = 'optimal',
  });

  /// Clasifica automáticamente el status según umbrales genéricos
  static String classifyAngle(String joint, double angle) {
    // Umbrales configurables por ejercicio en el futuro
    switch (joint.toLowerCase()) {
      case 'tobillo':
        return angle < 30.0 ? 'warning' : 'optimal';
      case 'tronco':
        return angle > 55.0 ? 'warning' : 'optimal';
      default:
        return 'optimal';
    }
  }
}
