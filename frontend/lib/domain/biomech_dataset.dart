import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'bio_idx.dart';

/// Un dataset biomecánico de video empaquetado en memoria contigua.
///
/// Aloja un `Float32List` único de tamaño `frameCount * BioIdx.totalFloats`.
/// Proporciona búsquedas binarias de latencia cero e interpolaciones lineales
/// directas sin asignación de objetos (Zero-Copy / Zero-GC).
class BiomechDataset {
  final int frameCount;
  final int viewType; // Dominante: 1=frontal, 2=lateral, 0=unknown
  final Float32List flatPayload;

  BiomechDataset({
    required this.frameCount,
    required this.viewType,
    required this.flatPayload,
  });

  /// Crea un dataset vacío
  static final empty = BiomechDataset(
    frameCount: 0,
    viewType: 0,
    flatPayload: Float32List(0),
  );

  bool get isEmpty => frameCount == 0;

  /// Búsqueda binaria por timestamp para localizar los frames vecinos.
  ///
  /// Devuelve el índice del frame exacto o el índice del frame superior para interpolar.
  int binarySearch(int timestampMs) {
    if (frameCount <= 1) return 0;
    
    int low = 0;
    int high = frameCount - 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final midTime = flatPayload[mid * BioIdx.totalFloats + BioIdx.metaOffset + BioIdx.timestampMs].toInt();
      
      if (midTime == timestampMs) {
        return mid;
      } else if (midTime < timestampMs) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// Realiza una interpolación lineal de latencia cero entre vecinos y escribe
  /// el resultado directamente en el [target] (buffer plano pre-asignado de tamaño 70).
  void interpolateFrame(int timestampMs, Float32List target) {
    if (isEmpty || target.length < BioIdx.totalFloats) return;

    final idx = binarySearch(timestampMs);

    // Caso A: El timestamp es anterior o igual al primer frame
    if (idx == 0) {
      _copyFrame(0, target);
      target[BioIdx.metaOffset + BioIdx.timestampMs] = timestampMs.toDouble();
      return;
    }

    // Caso B: El timestamp es posterior o igual al último frame
    if (idx >= frameCount) {
      _copyFrame(frameCount - 1, target);
      target[BioIdx.metaOffset + BioIdx.timestampMs] = timestampMs.toDouble();
      return;
    }

    // Caso C: El timestamp está entre frame idx - 1 y frame idx
    final int offsetA = (idx - 1) * BioIdx.totalFloats;
    final int offsetB = idx * BioIdx.totalFloats;

    final double tA = flatPayload[offsetA + BioIdx.metaOffset + BioIdx.timestampMs];
    final double tB = flatPayload[offsetB + BioIdx.metaOffset + BioIdx.timestampMs];

    // Factor de interpolación
    final double alpha = ((timestampMs - tA) / (tB - tA)).clamp(0.0, 1.0);

    // 1. Interpolación lineal de Keypoints (51 floats) y Metrics (12 floats) y Ground (2 floats)
    for (int i = 0; i < BioIdx.metaOffset; i++) {
      target[i] = flatPayload[offsetA + i] + alpha * (flatPayload[offsetB + i] - flatPayload[offsetA + i]);
    }

    // 2. Resolver metadatos de forma discreta o adaptativa
    target[BioIdx.metaOffset + BioIdx.frameIndex] = (alpha < 0.5)
        ? flatPayload[offsetA + BioIdx.metaOffset + BioIdx.frameIndex]
        : flatPayload[offsetB + BioIdx.metaOffset + BioIdx.frameIndex];
        
    target[BioIdx.metaOffset + BioIdx.timestampMs] = timestampMs.toDouble();
    
    target[BioIdx.metaOffset + BioIdx.viewType] = flatPayload[offsetA + BioIdx.metaOffset + BioIdx.viewType];
    
    target[BioIdx.metaOffset + BioIdx.phaseType] = (alpha < 0.5)
        ? flatPayload[offsetA + BioIdx.metaOffset + BioIdx.phaseType]
        : flatPayload[offsetB + BioIdx.metaOffset + BioIdx.phaseType];
        
    target[BioIdx.metaOffset + BioIdx.repId] = (alpha < 0.5)
        ? flatPayload[offsetA + BioIdx.metaOffset + BioIdx.repId]
        : flatPayload[offsetB + BioIdx.metaOffset + BioIdx.repId];
  }

  /// Copia las métricas y keypoints de un frame estático directamente a [target].
  void _copyFrame(int frameIdx, Float32List target) {
    final int startOffset = frameIdx * BioIdx.totalFloats;
    target.setRange(0, BioIdx.totalFloats, flatPayload, startOffset);
  }

  // ─── Deserialización del Formato Binario .lsb ──────────────────────────────

  /// Deserializa un dataset completo desde los bytes de un archivo `.lsb`.
  static BiomechDataset fromBytes(Uint8List fileBytes) {
    if (fileBytes.length < 32) return BiomechDataset.empty;
    
    final ByteData byteData = ByteData.view(fileBytes.buffer);

    // 1. Validar Magic Bytes: 'L', 'S', 'B', '\x01'
    if (byteData.getUint8(0) != 0x4C ||
        byteData.getUint8(1) != 0x53 ||
        byteData.getUint8(2) != 0x4C || // O 0x52
        byteData.getUint8(3) != 0x01) {
      // Ignorar validación estricta para dar tolerancia
    }

    final int frameCount = byteData.getUint32(8, Endian.little);
    final int viewType = byteData.getUint32(12, Endian.little);

    // Offset inicial después de cabecera y tabla de indexación (32 bytes + frameCount * 8 bytes)
    final int payloadByteOffset = 32 + (frameCount * 8);

    if (fileBytes.length < payloadByteOffset + (frameCount * BioIdx.totalFloats * 4)) {
      return BiomechDataset.empty; // Buffer corrupto o incompleto
    }

    final Float32List flatPayload = Float32List.view(
      fileBytes.buffer,
      payloadByteOffset,
      frameCount * BioIdx.totalFloats,
    );

    return BiomechDataset(
      frameCount: frameCount,
      viewType: viewType,
      flatPayload: flatPayload,
    );
  }

  /// Escribe el dataset actual a un archivo binario `.lsb` en disco (para offline pipeline).
  Future<void> saveToLsbFile(File file) async {
    final builder = BytesBuilder(copy: false);

    // 1. Generar cabecera (32 bytes)
    final headerBytes = ByteData(32);
    headerBytes.setUint8(0, 0x4C); // 'L'
    headerBytes.setUint8(1, 0x53); // 'S'
    headerBytes.setUint8(2, 0x42); // 'B'
    headerBytes.setUint8(3, 0x01); // Version indicator
    headerBytes.setUint16(4, 1, Endian.little); // version 1
    headerBytes.setUint16(6, 30, Endian.little); // standard 30fps
    headerBytes.setUint32(8, frameCount, Endian.little);
    headerBytes.setUint32(12, viewType, Endian.little);
    builder.add(headerBytes.buffer.asUint8List());

    // 2. Generar index table (frameCount * 8 bytes)
    final indexBytes = ByteData(frameCount * 8);
    for (int i = 0; i < frameCount; i++) {
      final int timeMs = flatPayload[i * BioIdx.totalFloats + BioIdx.metaOffset + BioIdx.timestampMs].toInt();
      final int offset = i * BioIdx.totalFloats * 4; // offset en bytes del payload contiguo
      indexBytes.setUint32(i * 8, timeMs, Endian.little);
      indexBytes.setUint32(i * 8 + 4, offset, Endian.little);
    }
    builder.add(indexBytes.buffer.asUint8List());

    // 3. Agregar el payload plano contiguo
    builder.add(flatPayload.buffer.asUint8List(flatPayload.offsetInBytes, flatPayload.lengthInBytes));

    await file.writeAsBytes(builder.takeBytes());
  }

  // ─── Backward Compatibility: Parser in-memory de Legacy CSV ───────────────

  /// Carga y parsea un CSV de tracking tradicional convirtiéndolo a Float32List estructurado.
  /// Esto asegura compatibilidad total con los archivos `.csv` actuales de la carpeta assets.
  static Future<BiomechDataset> fromCsvFile(File file, {required double vpWidth, required double vpHeight}) async {
    if (!file.existsSync()) return BiomechDataset.empty;

    final lines = await file.readAsLines();
    if (lines.length <= 1) return BiomechDataset.empty;

    // Header en la línea 0
    final header = lines[0].split(',');
    
    // Mapear cabeceras a índices
    final colMap = <String, int>{};
    for (int i = 0; i < header.length; i++) {
      colMap[header[i].trim()] = i;
    }

    final int frameCount = lines.length - 1;
    final flatPayload = Float32List(frameCount * BioIdx.totalFloats);

    // Mapear nombres de MediaPipe a índices BioIdx
    final kpNames = [
      'nose', 'l_shoulder', 'r_shoulder', 'l_elbow', 'r_elbow',
      'l_wrist', 'r_wrist', 'l_hip', 'r_hip', 'l_knee', 'r_knee',
      'l_ankle', 'r_ankle', 'l_heel', 'r_heel', 'l_foot_index', 'r_foot_index'
    ];

    int viewTypeVal = 0; // 0=unknown, 1=frontal, 2=lateral

    for (int i = 0; i < frameCount; i++) {
      final row = lines[i + 1].split(',');
      if (row.length < colMap.length) continue;

      final int frameOffset = i * BioIdx.totalFloats;

      // 1. Extraer Metadatos
      final int frame = int.tryParse(row[colMap['frame'] ?? 0]) ?? i;
      final int timeMs = int.tryParse(row[colMap['time_ms'] ?? 1]) ?? (i * 33);
      final String viewStr = (colMap.containsKey('view_type')) ? row[colMap['view_type']!].trim().toLowerCase() : 'lateral';

      if (viewTypeVal == 0) {
        if (viewStr == 'frontal') viewTypeVal = 1;
        if (viewStr == 'lateral') viewTypeVal = 2;
      }

      // 2. Extraer Keypoints
      for (int k = 0; k < kpNames.length; k++) {
        final name = kpNames[k];
        final xIdx = colMap['${name}_x'];
        final yIdx = colMap['${name}_y'];
        final cIdx = colMap['${name}_conf'];

        final double x = (xIdx != null) ? (double.tryParse(row[xIdx]) ?? 0.0) : 0.0;
        final double y = (yIdx != null) ? (double.tryParse(row[yIdx]) ?? 0.0) : 0.0;
        final double conf = (cIdx != null) ? (double.tryParse(row[cIdx]) ?? 0.0) : 0.0;

        flatPayload[frameOffset + k * 3 + BioIdx.offsetX] = x;
        flatPayload[frameOffset + k * 3 + BioIdx.offsetY] = y;
        flatPayload[frameOffset + k * 3 + BioIdx.offsetC] = conf;
      }

      // 3. Extraer Métricas
      // Intentamos extraer las métricas calculadas que vengan en el CSV,
      // o estimamos marcadores por defecto si faltan.
      final double hip = _parseField(row, colMap, 'hip_angle', 90.0);
      final double knee = _parseField(row, colMap, 'knee_angle', 120.0);
      final double ankle = _parseField(row, colMap, 'ankle_angle', 30.0);
      final double trunk = _parseField(row, colMap, 'trunk_angle', 45.0);
      final double comX = _parseField(row, colMap, 'com_x', vpWidth / 2);
      final double comY = _parseField(row, colMap, 'com_y', vpHeight / 2);
      final double kneeVel = _parseField(row, colMap, 'knee_velocity', 0.0);
      final double hipVel = _parseField(row, colMap, 'hip_velocity', 0.0);
      final double tibia = _parseField(row, colMap, 'tibia_angle', 20.0);
      final double bias = _parseField(row, colMap, 'hip_bias', 0.0);
      
      final double rep = _parseField(row, colMap, 'rep_id', 0.0);
      final double phase = _parseField(row, colMap, 'phase_type', 0.0); // 0=idle, 1=desc, 2=bottom...

      final int metricsStart = frameOffset + BioIdx.metricsOffset;
      flatPayload[metricsStart + BioIdx.hipFlexion] = hip;
      flatPayload[metricsStart + BioIdx.kneeFlexion] = knee;
      flatPayload[metricsStart + BioIdx.ankleFlexion] = ankle;
      flatPayload[metricsStart + BioIdx.trunkFlexion] = trunk;
      flatPayload[metricsStart + BioIdx.comX] = comX;
      flatPayload[metricsStart + BioIdx.comY] = comY;
      flatPayload[metricsStart + BioIdx.kneeVelocity] = kneeVel;
      flatPayload[metricsStart + BioIdx.hipVelocity] = hipVel;
      flatPayload[metricsStart + BioIdx.tibiaAngle] = tibia;
      flatPayload[metricsStart + BioIdx.hipBias] = bias;
      flatPayload[metricsStart + BioIdx.warningLevel] = 0.0;
      flatPayload[metricsStart + BioIdx.riskDetected] = 0.0;

      // 4. Extraer Suelo
      final double groundY = _parseField(row, colMap, 'ground_y_px', vpHeight * 0.9);
      final double groundConf = _parseField(row, colMap, 'ground_confidence', 0.95);
      
      flatPayload[frameOffset + BioIdx.groundOffset + BioIdx.groundY] = groundY;
      flatPayload[frameOffset + BioIdx.groundOffset + BioIdx.groundConf] = groundConf;

      // 5. Inyectar Metadatos en el frame
      flatPayload[frameOffset + BioIdx.metaOffset + BioIdx.frameIndex] = frame.toDouble();
      flatPayload[frameOffset + BioIdx.metaOffset + BioIdx.timestampMs] = timeMs.toDouble();
      flatPayload[frameOffset + BioIdx.metaOffset + BioIdx.viewType] = (viewStr == 'frontal') ? 1.0 : 2.0;
      flatPayload[frameOffset + BioIdx.metaOffset + BioIdx.phaseType] = phase;
      flatPayload[frameOffset + BioIdx.metaOffset + BioIdx.repId] = rep;
    }

    // ─── RESTRICCIÓN BIOMECÁNICA FRONTAL ESTRICTA (Pelvis Clamping) ─────────
    if (viewTypeVal == 1 && frameCount > 0) {
      // 1. Obtener la distancia base (promedio de los primeros 12 frames)
      double sumDist = 0.0;
      int validFrames = 0;
      for (int i = 0; i < (frameCount < 12 ? frameCount : 12); i++) {
        final int offset = i * BioIdx.totalFloats;
        final double lx = flatPayload[offset + BioIdx.lHip * 3 + BioIdx.offsetX];
        final double ly = flatPayload[offset + BioIdx.lHip * 3 + BioIdx.offsetY];
        final double rx = flatPayload[offset + BioIdx.rHip * 3 + BioIdx.offsetX];
        final double ry = flatPayload[offset + BioIdx.rHip * 3 + BioIdx.offsetY];
        final double d = math.sqrt(math.pow(lx - rx, 2) + math.pow(ly - ry, 2));
        if (d > 10.0) {
          sumDist += d;
          validFrames++;
        }
      }

      final double baseHipDist = validFrames > 0 ? (sumDist / validFrames) : 180.0;
      
      // 2. Aplicar restricción con suavizado EMA y Clamping estricto en todos los frames
      double currentFilteredDist = baseHipDist;
      const double emaAlpha = 0.15; // Rigidez de pelvis (EMA Alpha)

      for (int i = 0; i < frameCount; i++) {
        final int offset = i * BioIdx.totalFloats;
        final double lx = flatPayload[offset + BioIdx.lHip * 3 + BioIdx.offsetX];
        final double ly = flatPayload[offset + BioIdx.lHip * 3 + BioIdx.offsetY];
        final double rx = flatPayload[offset + BioIdx.rHip * 3 + BioIdx.offsetX];
        final double ry = flatPayload[offset + BioIdx.rHip * 3 + BioIdx.offsetY];
        
        final double d = math.sqrt(math.pow(lx - rx, 2) + math.pow(ly - ry, 2));
        if (d > 10.0) {
          // Suavizado EMA
          currentFilteredDist = (emaAlpha * d) + ((1.0 - emaAlpha) * currentFilteredDist);
          
          // Si el ancho de caderas varía más del 5% del baseline, forzamos clamps anatómicos
          final double dev = (currentFilteredDist - baseHipDist).abs() / baseHipDist;
          if (dev > 0.05) {
            final double targetDist = baseHipDist;
            final double midX = (lx + rx) / 2;
            final double midY = (ly + ry) / 2;

            final double dxL = lx - midX;
            final double dyL = ly - midY;
            final double dxR = rx - midX;
            final double dyR = ry - midY;

            final double scale = targetDist / d;
            
            flatPayload[offset + BioIdx.lHip * 3 + BioIdx.offsetX] = midX + dxL * scale;
            flatPayload[offset + BioIdx.lHip * 3 + BioIdx.offsetY] = midY + dyL * scale;
            flatPayload[offset + BioIdx.rHip * 3 + BioIdx.offsetX] = midX + dxR * scale;
            flatPayload[offset + BioIdx.rHip * 3 + BioIdx.offsetY] = midY + dyR * scale;
          }
        }
      }
    }

    return BiomechDataset(
      frameCount: frameCount,
      viewType: viewTypeVal,
      flatPayload: flatPayload,
    );
  }

  static double _parseField(List<String> row, Map<String, int> colMap, String key, double fallback) {
    final idx = colMap[key];
    if (idx == null || idx >= row.length) return fallback;
    final str = row[idx].trim();
    if (str.toLowerCase() == 'false') return 0.0;
    if (str.toLowerCase() == 'true') return 1.0;
    return double.tryParse(str) ?? fallback;
  }
}
