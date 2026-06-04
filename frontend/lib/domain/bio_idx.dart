/// Constantes de Índices Biomecánicos Fijos en el Buffer Plano.
///
/// Evita el uso de Maps dinámicos y strings en el hot-path del renderizador.
/// La topología consta de 17 puntos clave (MediaPipe Pose 2D estructurada).
abstract class BioIdx {
  // ─── Keypoints (Cada punto ocupa 3 floats consecutivos: X, Y, Confidence) ────
  static const int nose = 0;
  static const int lShoulder = 1;
  static const int rShoulder = 2;
  static const int lElbow = 3;
  static const int rElbow = 4;
  static const int lWrist = 5;
  static const int rWrist = 6;
  static const int lHip = 7;
  static const int rHip = 8;
  static const int lKnee = 9;
  static const int rKnee = 10;
  static const int lAnkle = 11;
  static const int rAnkle = 12;
  static const int lHeel = 13;
  static const int rHeel = 14;
  static const int lFootIndex = 15;
  static const int rFootIndex = 16;

  // Offsets de acceso para cada punto clave
  static const int offsetX = 0;
  static const int offsetY = 1;
  static const int offsetC = 2;

  // Cantidad total de floats ocupados por los keypoints: 17 * 3 = 51 floats.
  static const int skeletonFloats = 51;

  // ─── Metrics Buffer (Offset 51 en el buffer de 70 floats del Frame) ─────────
  static const int metricsOffset = 51;

  static const int hipFlexion = 0;
  static const int kneeFlexion = 1;
  static const int ankleFlexion = 2;
  static const int trunkFlexion = 3;
  static const int comX = 4;
  static const int comY = 5;
  static const int kneeVelocity = 6;
  static const int hipVelocity = 7;
  static const int tibiaAngle = 8;
  static const int hipBias = 9;
  static const int warningLevel = 10;
  static const int riskDetected = 11;

  // Cantidad total de floats de métricas: 12.
  static const int metricsFloats = 12;

  // ─── Ground Buffer (Offset 63 en el buffer del Frame) ─────────────────────────
  static const int groundOffset = 63; // 51 keypoints + 12 metrics = index 63

  static const int groundY = 0;
  static const int groundConf = 1;

  // Cantidad total de floats de suelo: 2.
  static const int groundFloats = 2;

  // ─── Meta Buffer (Offset 65 en el buffer del Frame) ───────────────────────────
  static const int metaOffset = 65;

  static const int frameIndex = 0;
  static const int timestampMs = 1;
  static const int viewType = 2;
  static const int phaseType = 3;
  static const int repId = 4;

  // Cantidad total de floats de metadatos: 5.
  static const int metaFloats = 5;

  // Tamaño total de floats por frame: 51 + 12 + 2 + 5 = 70 floats.
  static const int totalFloats = 70;
}
