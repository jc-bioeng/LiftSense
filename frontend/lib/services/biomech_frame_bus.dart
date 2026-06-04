import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../domain/biomech_frame_realtime.dart';
import '../domain/movement_segment.dart';
import '../domain/vbt_summary.dart';
import '../domain/biomech_dataset.dart';
import '../domain/bio_idx.dart';
import '../utils/vbt_calculator.dart';
import '../services/biomech_worker.dart';

/// Bus central de datos biomecánicos offline-first.
///
/// Distribuye frames biomecánicos de latencia cero pre-calculados offline
/// a todos los widgets suscritos mediante ValueNotifier.
class BiomechFrameBus {
  BiomechFrameBus._();
  static final BiomechFrameBus instance = BiomechFrameBus._();

  // ─── Dataset de Memoria Contigua (Zero GC Hotpath) ───────────
  BiomechDataset dataset = BiomechDataset.empty;
  final Float32List activeFrameBuffer = Float32List(BioIdx.totalFloats);

  // ─── Notifiers Granulares ──────────────────────────────────

  /// Frame biomecánico completo (actualizado a 60Hz localmente)
  final ValueNotifier<BiomechFrameRealtime> frameNotifier =
      ValueNotifier(BiomechFrameRealtime.empty);

  /// Progreso de reproducción normalizado (0.0 → 1.0)
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);

  /// Posición interpolada del video en ms
  final ValueNotifier<int> positionMsNotifier = ValueNotifier(0);

  /// Segmentos de fase detectados
  final ValueNotifier<List<MovementSegment>> segmentsNotifier =
      ValueNotifier([]);

  /// Series temporales para gráficas: [hip, knee, ankle, trunk]
  final ValueNotifier<List<Float32List>> seriesNotifier =
      ValueNotifier([]);

  /// Métricas de Velocity Based Training (VBT)
  final ValueNotifier<VbtSummary> vbtNotifier =
      ValueNotifier(VbtSummary.empty);

  /// Duración total del video en ms
  int totalDurationMs = 0;

  // ─── Worker Isolate (Carga Offline Inicial) ──────────────────

  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  ReceivePort? _receivePort;
  bool _isWorkerReady = false;
  bool get isWorkerReady => _isWorkerReady;

  /// Inicia el Isolate y pre-computa todo el video offline
  Future<void> startWorker(String csvPath, double vpWidth, double vpHeight) async {
    if (_workerIsolate != null) return;

    _receivePort = ReceivePort();
    _workerIsolate = await Isolate.spawn(biomechWorkerMain, _receivePort!.sendPort);

    _receivePort!.listen((message) {
      if (message is SendPort) {
        _workerSendPort = message;
        _workerSendPort!.send(BiomechWorkerInit(csvPath, vpWidth, vpHeight));
      } else if (message is BiomechWorkerInitialData) {
        _isWorkerReady = true;
        seriesNotifier.value = message.series;
        
        // Inicializar el dataset plano local contiguo
        dataset = BiomechDataset(
          frameCount: message.flatPayload.length ~/ BioIdx.totalFloats,
          viewType: message.viewType,
          flatPayload: message.flatPayload,
        );

        // Mapear segmentos
        final mappedSegments = message.segments.map((s) {
          final typeColors = {
            0: const Color(0xFF00D4AA), // Descending
            1: const Color(0xFFFFB627), // Bottom
            2: const Color(0xFF007BFF), // Ascending
            3: const Color(0xFF8B5CF6), // Lockout
          };
          final typeLabels = {
            0: 'DESCENSO', 1: 'FONDO', 2: 'ASCENSO', 3: 'LOCKOUT'
          };
          
          return MovementSegment(
            startMs: s.startMs,
            endMs: s.endMs,
            phaseType: typeLabels[s.type] ?? 'IDLE',
            repId: s.repId,
            displayColor: typeColors[s.type] ?? const Color(0xFF6B7280),
            displayLabel: typeLabels[s.type] ?? 'IDLE',
          );
        }).toList();

        segmentsNotifier.value = mappedSegments;

        // Calcular VBT
        vbtNotifier.value = VbtCalculator.calculate(
          comYSeries: message.comYSeries,
          segments: mappedSegments,
          videoHeight: vpHeight > 0 ? vpHeight : 1080,
        );

        debugPrint('[BiomechFrameBus] Pre-computation completed offline: ${dataset.frameCount} frames loaded.');
      } else if (message == "INITIALIZED") {
        _isWorkerReady = true;
      } else if (message is String && message.startsWith("ERROR:")) {
        debugPrint('[BiomechWorker] initialization error: $message');
      }
    });
  }

  /// Actualiza la posición de reproducción y renderiza localmente por búsqueda binaria
  void updatePosition(int timestampMs) {
    // Siempre actualizar posición y progreso (timeline funciona sin dataset)
    positionMsNotifier.value = timestampMs;
    if (totalDurationMs > 0) {
      progressNotifier.value = timestampMs / totalDurationMs;
    }

    // Sin dataset biomecánico: solo el scrubber/timeline funciona, no los overlays
    if (dataset.isEmpty) return;

    // 1. Realizar búsqueda binaria e interpolación lineal (latencia < 0.05ms)
    dataset.interpolateFrame(timestampMs, activeFrameBuffer);

    // 2. Localizar el segmento actual
    MovementSegment? currentSeg;
    String phaseType = 'IDLE';
    for (final seg in segmentsNotifier.value) {
      if (timestampMs >= seg.startMs && timestampMs < seg.endMs) {
        currentSeg = seg;
        phaseType = seg.phaseType;
        break;
      }
    }

    // 3. Obtener sub-vistas del Float32List (Zero-Copy)
    final skeletonBuffer = Float32List.sublistView(
      activeFrameBuffer, 
      0, 
      BioIdx.skeletonFloats * 4,
    );
    final metricsBuffer = Float32List.sublistView(
      activeFrameBuffer, 
      BioIdx.metricsOffset * 4, 
      (BioIdx.metricsOffset + BioIdx.metricsFloats) * 4,
    );

    // 4. Inyectar Frame Biomecánico completo (Zero GC Churn)
    final frame = BiomechFrameRealtime(
      timeMs: timestampMs,
      frameIndex: activeFrameBuffer[BioIdx.metaOffset + BioIdx.frameIndex].toInt(),
      currentSegment: currentSeg,
      phaseType: phaseType,
      skeletonBuffer: skeletonBuffer,
      metricsBuffer: metricsBuffer,
      sourceView: dataset.viewType == 1 ? 'FRONTAL' : 'LATERAL',
    );

    // 5. Notificar frame biomecánico
    frameNotifier.value = frame;
  }

  /// Pide un nuevo frame al Worker (Async/Non-blocking) - Conservado por compatibilidad de firma
  void requestFrame(int timestampMs, double vpWidth, double vpHeight) {
    updatePosition(timestampMs); // Derivar a la búsqueda local directa
  }

  /// Inicializa los segmentos por defecto
  void initDefaultSegments(int durationMs) {
    totalDurationMs = durationMs;
    segmentsNotifier.value = MovementSegment.defaultSquatSegments(durationMs);
  }

  void dispose() {
    if (_workerSendPort != null) {
      _workerSendPort!.send("DISPOSE");
    }
    _receivePort?.close();
    _workerIsolate?.kill();
    _workerIsolate = null;
    _workerSendPort = null;
    _isWorkerReady = false;

    dataset = BiomechDataset.empty;
    frameNotifier.value = BiomechFrameRealtime.empty;
    progressNotifier.value = 0.0;
    positionMsNotifier.value = 0;
    segmentsNotifier.value = [];
    vbtNotifier.value = VbtSummary.empty;
  }
}
