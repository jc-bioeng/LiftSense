import '../domain/biomech_frame_realtime.dart';
import '../ui/analysis/config/biomech_colors.dart';
import '../ui/analysis/config/biomech_thresholds.dart';
import '../ui/analysis/config/metric_indices.dart';
import '../ui/analysis/models/ui/angle_pill_ui_model.dart';

class DegreeCache {
  static final List<String> _positiveCache = List.generate(361, (i) => '$i°');
  static final List<String> _negativeCache = List.generate(361, (i) => '-$i°');

  static String getString(int degree) {
    if (degree >= 0 && degree <= 360) return _positiveCache[degree];
    if (degree < 0 && degree >= -360) return _negativeCache[-degree];
    return '$degree°'; // Fallback for very extreme values
  }
}

class MemoizedAngleSelector {
  final String label;
  final int metricIndex;
  final double optimalThreshold;
  /// Rango en grados a cada lado del óptimo que el gauge representa.
  final double rangeRadius;
  final bool lowerIsBetter;

  double _lastRoundedValue = -999;
  bool _lastWarningState = false;

  AnglePillUiModel? _cached;

  MemoizedAngleSelector({
    required this.label,
    required this.metricIndex,
    required this.optimalThreshold,
    this.rangeRadius = 60.0,
    this.lowerIsBetter = false,
  });

  AnglePillUiModel select(BiomechFrameRealtime frame) {
    if (frame.metricsBuffer.isEmpty || frame.metricsBuffer.length <= metricIndex) {
      return _cached ??= AnglePillUiModel(
        label: label,
        formattedValue: DegreeCache.getString(0),
        value: optimalThreshold, // centrado en reposo
        optimalValue: optimalThreshold,
        rangeRadius: rangeRadius,
        accentColor: BiomechColors.optimal,
        statusLabel: 'ÓPTIMO',
        visible: true,
      );
    }

    final raw = frame.metricsBuffer[metricIndex];
    // Quantization a 1 grado
    final rounded = raw.roundToDouble();
    final warning = lowerIsBetter ? (raw > optimalThreshold) : (raw < optimalThreshold);

    final unchanged = rounded == _lastRoundedValue && warning == _lastWarningState;

    if (unchanged && _cached != null) {
      return _cached!;
    }

    _lastRoundedValue = rounded;
    _lastWarningState = warning;

    _cached = AnglePillUiModel(
      label: label,
      formattedValue: DegreeCache.getString(rounded.toInt()),
      value: rounded,
      optimalValue: optimalThreshold,
      rangeRadius: rangeRadius,
      accentColor: warning ? BiomechColors.warning : BiomechColors.optimal,
      statusLabel: warning ? 'ATENCIÓN' : 'ÓPTIMO',
      visible: true,
    );

    return _cached!;
  }
}

class BiomechSelectors {
  // rangeRadius = ± grados alrededor del óptimo que el gauge representa.
  // La aguja oscilará centrada cuando el valor esté en el umbral óptimo.

  static MemoizedAngleSelector createHipFlexion() {
    return MemoizedAngleSelector(
      label: 'CADERA',
      metricIndex: MetricIndices.hipFlexion,
      optimalThreshold: BiomechThresholds.hipFlexionOptimal, // 90°
      rangeRadius: 60.0, // rango: 30° – 150°
    );
  }

  static MemoizedAngleSelector createKneeFlexion() {
    return MemoizedAngleSelector(
      label: 'RODILLA',
      metricIndex: MetricIndices.kneeFlexion,
      optimalThreshold: BiomechThresholds.kneeFlexionOptimal, // 120°
      rangeRadius: 70.0, // rango: 50° – 190°
    );
  }

  static MemoizedAngleSelector createAnkleFlexion() {
    return MemoizedAngleSelector(
      label: 'TOBILLO',
      metricIndex: MetricIndices.ankleFlexion,
      optimalThreshold: BiomechThresholds.ankleFlexionOptimal, // 30°
      rangeRadius: 25.0, // rango: 5° – 55°
    );
  }

  static MemoizedAngleSelector createTrunkFlexion() {
    return MemoizedAngleSelector(
      label: 'TRONCO',
      metricIndex: MetricIndices.trunkFlexion,
      optimalThreshold: BiomechThresholds.trunkFlexionOptimal, // 55°
      rangeRadius: 40.0, // rango: 15° – 95°
    );
  }
}
