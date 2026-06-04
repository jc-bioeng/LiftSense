import 'dart:typed_data';
import 'movement_segment.dart';
import 'bio_idx.dart';

/// Frame biomecánico en tiempo real optimizado (Flat Memory Layout).
///
/// Aloja buffers planos deFloat32 directos y getters de alta velocidad.
class BiomechFrameRealtime {
  final int timeMs;
  final int frameIndex;

  // Phase & Rep
  final MovementSegment? currentSegment;
  final String phaseType; 
  final int repId;

  // Flat Buffers (Zero GC Churn)
  /// Puntos del esqueleto: 17 puntos * 3 valores (x, y, confidence). Total: 51 floats.
  final Float32List skeletonBuffer;
  
  /// Métricas: [hip, knee, ankle, trunk, comX, comY, kneeVel, hipVel, tibia, bias, warn, risk]
  final Float32List metricsBuffer;

  // Risk & Warnings
  final int warningLevel; // 0=NONE, 1=LOW, 2=MEDIUM, 3=HIGH, 4=CRITICAL
  final bool isRiskDetected;

  // Source & Confidence
  final String sourceView; // 'FRONTAL' | 'LATERAL'
  final double overallConfidence;

  const BiomechFrameRealtime({
    required this.timeMs,
    required this.frameIndex,
    this.currentSegment,
    this.phaseType = 'IDLE',
    this.repId = 0,
    required this.skeletonBuffer,
    required this.metricsBuffer,
    this.warningLevel = 0,
    this.isRiskDetected = false,
    this.sourceView = 'LATERAL',
    this.overallConfidence = 1.0,
  });

  static final empty = BiomechFrameRealtime(
    timeMs: 0,
    frameIndex: -1,
    skeletonBuffer: Float32List(0),
    metricsBuffer: Float32List(0),
  );

  bool get isEmpty => frameIndex < 0;

  // ─── Getters de Métricas con Mapeo Biomecánico Estático ───────────
  double get hipAngle => metricsBuffer.isNotEmpty ? metricsBuffer[BioIdx.hipFlexion] : 0.0;
  double get kneeAngle => metricsBuffer.length > 1 ? metricsBuffer[BioIdx.kneeFlexion] : 0.0;
  double get ankleAngle => metricsBuffer.length > 2 ? metricsBuffer[BioIdx.ankleFlexion] : 0.0;
  double get trunkAngle => metricsBuffer.length > 3 ? metricsBuffer[BioIdx.trunkFlexion] : 0.0;
  
  double get comX => metricsBuffer.length > 4 ? metricsBuffer[BioIdx.comX] : 0.0;
  
  // comY es la métrica de profundidad (index 5)
  double get depth => metricsBuffer.length > 5 ? metricsBuffer[BioIdx.comY] : 0.0; 
  
  // kneeVelocity es index 6
  double get verticalVelocity => metricsBuffer.length > 6 ? metricsBuffer[BioIdx.kneeVelocity] : 0.0; 
  
  double get tibiaAngle => metricsBuffer.length > 8 ? metricsBuffer[BioIdx.tibiaAngle] : 0.0;
  double get hipBias => metricsBuffer.length > 9 ? metricsBuffer[BioIdx.hipBias] : 0.0;
}
