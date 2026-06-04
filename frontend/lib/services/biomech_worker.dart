import 'dart:isolate';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;
import '../native/liftsense_ffi.dart';
import '../domain/frame_schema.dart';
import '../domain/bio_idx.dart';

/// Mensajes que el Main Isolate envía al Worker
class BiomechWorkerRequest {
  final int id;
  final int timestampMs;
  final double vpWidth;
  final double vpHeight;
  
  const BiomechWorkerRequest(this.id, this.timestampMs, this.vpWidth, this.vpHeight);
}

/// Mensaje de inicialización
class BiomechWorkerInit {
  final String csvPath;
  final double vpWidth;
  final double vpHeight;
  const BiomechWorkerInit(this.csvPath, this.vpWidth, this.vpHeight);
}

class BiomechWorkerResponse {
  final int id;
  final int timestampMs;
  final TransferableTypedData payload;
  final int frameIndex;
  
  const BiomechWorkerResponse(this.id, this.timestampMs, this.frameIndex, this.payload);
}

/// Datos iniciales tras cargar el CSV (Series temporales + Segmentos + Dataset Plano)
class BiomechWorkerSegment {
  final int startMs;
  final int endMs;
  final int type;
  final int repId;
  const BiomechWorkerSegment(this.startMs, this.endMs, this.type, this.repId);
}

class BiomechWorkerInitialData {
  final List<Float32List> series; // [hip, knee, ankle, trunk]
  final Float32List comYSeries;
  final List<BiomechWorkerSegment> segments;
  final int durationMs;
  final Float32List flatPayload; // Dataset pre-calculado contiguo en el Isolate
  final int viewType; // 1=frontal, 2=lateral, 0=unknown

  const BiomechWorkerInitialData(
    this.series, 
    this.comYSeries, 
    this.segments, 
    this.durationMs,
    this.flatPayload,
    this.viewType,
  );
}

/// Entry point del Background Isolate
void biomechWorkerMain(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort); // Enviar el puerto de comunicación de vuelta

  receivePort.listen((message) {
    if (message is BiomechWorkerInit) {
      try {
        final frameCount = LiftsenseNative.init(message.csvPath, videoWidth: message.vpWidth, videoHeight: message.vpHeight);
        
        // 1. Extraer series completas para gráficas (eficiente, una sola vez)
        final hipSeries = LiftsenseNative.getMetricSeries(0, frameCount);
        final kneeSeries = LiftsenseNative.getMetricSeries(1, frameCount);
        final ankleSeries = LiftsenseNative.getMetricSeries(2, frameCount);
        final trunkSeries = LiftsenseNative.getMetricSeries(3, frameCount);
        
        // Extraer la serie completa de CoM Y
        final comYSeries = Float32List(frameCount);
        for (int i = 0; i < frameCount; i++) {
          final metrics = LiftsenseNative.extractRawMetrics(i);
          if (metrics.length > 5) {
            comYSeries[i] = metrics[5];
          } else {
            comYSeries[i] = 0.0;
          }
        }

        // 2. Detectar segmentos (reps/fases)
        final nativeSegs = LiftsenseNative.detectSegments(maxLen: 200);
        final segments = nativeSegs.map((s) => BiomechWorkerSegment(s.startMs, s.endMs, s.type, s.repId)).toList();

        // 3. Duración real
        final info = LiftsenseNative.getInfo();
        final duration = info.lastTimestampMs - info.firstTimestampMs;

        // 4. PARSER DE CSV Y GENERACIÓN DEL FLAT PAYLOAD CONTIGUO EN EL ISOLATE
        final file = File(message.csvPath);
        final lines = file.readAsLinesSync();
        final header = lines[0].split(',');
        final colMap = <String, int>{};
        for (int i = 0; i < header.length; i++) {
          colMap[header[i].trim()] = i;
        }

        final int parsedFrames = lines.length - 1;
        final flatPayload = Float32List(parsedFrames * BioIdx.totalFloats);

        final kpNames = [
          'nose', 'l_shoulder', 'r_shoulder', 'l_elbow', 'r_elbow',
          'l_wrist', 'r_wrist', 'l_hip', 'r_hip', 'l_knee', 'r_knee',
          'l_ankle', 'r_ankle', 'l_heel', 'r_heel', 'l_foot_index', 'r_foot_index'
        ];

        int viewTypeVal = 0; // 0=unknown, 1=frontal, 2=lateral

        for (int i = 0; i < parsedFrames; i++) {
          final row = lines[i + 1].split(',');
          if (row.length < colMap.length) continue;

          final int frameOffset = i * BioIdx.totalFloats;

          final int frame = int.tryParse(row[colMap['frame'] ?? 0]) ?? i;
          final int timeMs = int.tryParse(row[colMap['time_ms'] ?? 1]) ?? (i * 33);
          final String viewStr = (colMap.containsKey('view_type')) ? row[colMap['view_type']!].trim().toLowerCase() : 'lateral';

          if (viewTypeVal == 0) {
            if (viewStr == 'frontal') viewTypeVal = 1;
            if (viewStr == 'lateral') viewTypeVal = 2;
          }

          // A. Extraer keypoints mediante FFI (más preciso porque C++ normaliza a coordenadas)
          final nativeSkeleton = LiftsenseNative.extractRawSkeleton(timeMs, message.vpWidth, message.vpHeight);
          if (nativeSkeleton.length == FrameSchema.skeletonFloats) {
            // Saltamos el primer float de nativeSkeleton (que es el index de frame)
            flatPayload.setRange(frameOffset, frameOffset + BioIdx.skeletonFloats, nativeSkeleton, 1);
          } else {
            // Fallback manual desde el CSV si FFI falla
            for (int k = 0; k < kpNames.length; k++) {
              final name = kpNames[k];
              final xVal = double.tryParse(row[colMap['${name}_x'] ?? 0]) ?? 0.0;
              final yVal = double.tryParse(row[colMap['${name}_y'] ?? 0]) ?? 0.0;
              final cVal = double.tryParse(row[colMap['${name}_conf'] ?? 0]) ?? 0.0;
              flatPayload[frameOffset + k * 3] = xVal;
              flatPayload[frameOffset + k * 3 + 1] = yVal;
              flatPayload[frameOffset + k * 3 + 2] = cVal;
            }
          }

          // B. Extraer Métricas mediante FFI
          final nativeMetrics = LiftsenseNative.extractRawMetrics(frame);
          if (nativeMetrics.length == FrameSchema.metricsFloats) {
            flatPayload.setRange(frameOffset + BioIdx.metricsOffset, frameOffset + BioIdx.metricsOffset + BioIdx.metricsFloats, nativeMetrics);
          } else {
            // Fallback
            flatPayload[frameOffset + BioIdx.metricsOffset + BioIdx.hipFlexion] = 90.0;
            flatPayload[frameOffset + BioIdx.metricsOffset + BioIdx.kneeFlexion] = 120.0;
          }

          // C. Extraer Suelo
          final double groundY = colMap.containsKey('ground_y_px') ? (double.tryParse(row[colMap['ground_y_px']!]) ?? message.vpHeight * 0.9) : message.vpHeight * 0.9;
          final double groundConf = colMap.containsKey('ground_confidence') ? (double.tryParse(row[colMap['ground_confidence']!]) ?? 0.95) : 0.95;
          flatPayload[frameOffset + BioIdx.groundOffset + BioIdx.groundY] = groundY;
          flatPayload[frameOffset + BioIdx.groundOffset + BioIdx.groundConf] = groundConf;

          // D. Inyectar Metadatos
          flatPayload[frameOffset + BioIdx.metaOffset + BioIdx.frameIndex] = frame.toDouble();
          flatPayload[frameOffset + BioIdx.metaOffset + BioIdx.timestampMs] = timeMs.toDouble();
          flatPayload[frameOffset + BioIdx.metaOffset + BioIdx.viewType] = (viewStr == 'frontal') ? 1.0 : 2.0;
          
          // Phase and Rep de FFI si están disponibles
          flatPayload[frameOffset + BioIdx.metaOffset + BioIdx.phaseType] = nativeMetrics.length > 11 ? nativeMetrics[11] : 0.0;
          flatPayload[frameOffset + BioIdx.metaOffset + BioIdx.repId] = nativeMetrics.length > 10 ? nativeMetrics[10] : 0.0;
        }

        // ─── RESTRICCIÓN BIOMECÁNICA FRONTAL ESTRICTA ─────────────────────
        if (viewTypeVal == 1 && parsedFrames > 0) {
          double sumDist = 0.0;
          int validFrames = 0;
          for (int i = 0; i < (parsedFrames < 12 ? parsedFrames : 12); i++) {
            final int offset = i * BioIdx.totalFloats;
            final double lx = flatPayload[offset + BioIdx.lHip * 3];
            final double ly = flatPayload[offset + BioIdx.lHip * 3 + 1];
            final double rx = flatPayload[offset + BioIdx.rHip * 3];
            final double ry = flatPayload[offset + BioIdx.rHip * 3 + 1];
            final double d = math.sqrt(math.pow(lx - rx, 2) + math.pow(ly - ry, 2));
            if (d > 10.0) {
              sumDist += d;
              validFrames++;
            }
          }

          final double baseHipDist = validFrames > 0 ? (sumDist / validFrames) : 180.0;
          double currentFilteredDist = baseHipDist;
          const double emaAlpha = 0.15; // Pelvis Rigidity (EMA)

          for (int i = 0; i < parsedFrames; i++) {
            final int offset = i * BioIdx.totalFloats;
            final double lx = flatPayload[offset + BioIdx.lHip * 3];
            final double ly = flatPayload[offset + BioIdx.lHip * 3 + 1];
            final double rx = flatPayload[offset + BioIdx.rHip * 3];
            final double ry = flatPayload[offset + BioIdx.rHip * 3 + 1];
            
            final double d = math.sqrt(math.pow(lx - rx, 2) + math.pow(ly - ry, 2));
            if (d > 10.0) {
              currentFilteredDist = (emaAlpha * d) + ((1.0 - emaAlpha) * currentFilteredDist);
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
                
                flatPayload[offset + BioIdx.lHip * 3] = midX + dxL * scale;
                flatPayload[offset + BioIdx.lHip * 3 + 1] = midY + dyL * scale;
                flatPayload[offset + BioIdx.rHip * 3] = midX + dxR * scale;
                flatPayload[offset + BioIdx.rHip * 3 + 1] = midY + dyR * scale;
              }
            }
          }
        }

        sendPort.send(BiomechWorkerInitialData(
          [hipSeries, kneeSeries, ankleSeries, trunkSeries],
          comYSeries,
          segments,
          duration,
          flatPayload,
          viewTypeVal,
        ));
      } catch (e) {
        sendPort.send("ERROR: $e");
      }
    } else if (message is BiomechWorkerRequest) {
      // Dejamos la respuesta de hot-path vacía o compatible
    } else if (message == "DISPOSE") {
      LiftsenseNative.dispose();
      receivePort.close();
    }
  });
}
