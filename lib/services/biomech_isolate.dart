import 'dart:isolate';
import 'dart:typed_data';
import 'biomech_service.dart';

/// Protocolo de comunicación (Binario Compacto):
/// Request (Main -> Isolate): Float32List
///  [0] = COMMAND (0 = INIT, 1 = PROCESS, 2 = DISPOSE)
///  [1] = ViewType (0 = Frontal, 1 = Lateral)
///  [2] = frameIndex
///  [3] = timeMs
///  [4...135] = Landmarks 0..32 (x, y, z, conf) -> Array of Structs layout
///  [136...142] = COM/Anclas (comX, comY, midHipX, midHipY, midFootX, heelX, footIndexX)

/// Response (Isolate -> Main): Float32List
///  [0] = EVENT_TYPE (1 = METRICS_UPDATE, 2 = PHASE_CHANGED)
///  [1] = timeMs
///  [2] = phase
///  [3] = warningLevel
///  [4] = isRiskDetected (0.0 o 1.0)
///  [5] = verticalVelocity
///  [6...14] = Angles (leftKnee, rightKnee, trunkFlexion, etc.)

class BiomechIsolate {
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  bool _isReady = false;

  Stream<Float32List> get outputStream => _receivePort.cast<Float32List>();

  Future<void> initialize() async {
    await Isolate.spawn(_isolateEntryPoint, _receivePort.sendPort);
    // Esperar el primer mensaje con el SendPort del Isolate
    _sendPort = await _receivePort.first as SendPort;
    _isReady = true;
  }

  void initEngine(int viewType) {
    if (!_isReady) return;
    final cmd = Float32List(2);
    cmd[0] = 0.0; // INIT
    cmd[1] = viewType.toDouble();
    _sendPort!.send(cmd); // Fast copy for small lists
  }

  /// Envía un frame binario usando TransferableTypedData para O(1) transfer.
  void processFrame(Float32List payload) {
    if (!_isReady) return;
    // Transferir la memoria directamente evita la penalidad del copiado profundo (deep copy)
    _sendPort!.send(payload); 
  }

  void dispose() {
    if (!_isReady) return;
    final cmd = Float32List(1);
    cmd[0] = 2.0; // DISPOSE
    _sendPort!.send(cmd);
    _receivePort.close();
  }

  // ==================================================================
  // ISOLATE ENTRY POINT (Ejecutado en background thread)
  // ==================================================================
  static void _isolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    final service = BiomechNativeService();
    int previousPhase = 0; // IDLE

    receivePort.listen((message) {
      if (message is Float32List) {
        final command = message[0].toInt();

        if (command == 0) { // INIT
          service.initEngine(message[1].toInt());
        } 
        else if (command == 1) { // PROCESS
          if (service.sharedFramePtr == null) return;

          // 1. Decodificar Binario -> Sobreescribir Shared Memory (Zero-copy approach)
          final nativeFrame = service.sharedFramePtr!.ref;
          nativeFrame.frameIndex = message[2].toInt();
          nativeFrame.timeMs = message[3].toInt();

          // Array of Structs memory layout
          int offset = 4;
          for (int i = 0; i < 33; i++) {
            nativeFrame.landmarks[i].x = message[offset++];
            nativeFrame.landmarks[i].y = message[offset++];
            nativeFrame.landmarks[i].z = message[offset++];
            nativeFrame.landmarks[i].conf = message[offset++];
          }

          nativeFrame.comX = message[offset++];
          nativeFrame.comY = message[offset++];
          nativeFrame.midHipX = message[offset++];
          nativeFrame.midHipY = message[offset++];
          nativeFrame.midFootX = message[offset++];
          nativeFrame.heelX = message[offset++];
          nativeFrame.footIndexX = message[offset++];

          // 2. Invocar C++
          final metrics = service.processSharedFrame();

          // 3. Emitir Evento Prioritario (Ej: Phase Changed)
          if (metrics.phase != previousPhase) {
            final event = Float32List(3);
            event[0] = 2.0; // PHASE_CHANGED
            event[1] = nativeFrame.timeMs.toDouble();
            event[2] = metrics.phase.toDouble();
            mainSendPort.send(event);
            previousPhase = metrics.phase;
          }

          // 4. Codificar Respuesta Binaria
          final response = Float32List(15);
          response[0] = 1.0; // METRICS_UPDATE
          response[1] = nativeFrame.timeMs.toDouble();
          response[2] = metrics.phase.toDouble();
          response[3] = metrics.warningLevel.toDouble();
          response[4] = metrics.isRiskDetected ? 1.0 : 0.0;
          response[5] = metrics.verticalVelocity;
          
          final angles = metrics.angles;
          response[6] = angles.leftKnee;
          response[7] = angles.rightKnee;
          response[8] = angles.leftHip;
          response[9] = angles.rightHip;
          response[10] = angles.trunkFlexion;
          response[11] = angles.tibiaAngle;
          response[12] = angles.valgusAngle;
          response[13] = angles.comProjection;
          response[14] = angles.hipKneeRatio;

          mainSendPort.send(response);
        }
        else if (command == 2) { // DISPOSE
          service.dispose();
          receivePort.close();
        }
      }
    });
  }
}
