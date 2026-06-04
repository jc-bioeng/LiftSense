import 'package:flutter/material.dart';
import 'analysis_playback_controller.dart';
import '../../../services/biomech_frame_bus.dart';

/// Motor de sincronización Biomecánica 100% guiado por el Video (Video-Timestamp Driven).
///
/// Elimina por completo la sincronización pesada basada en Tickers y Ticks de Flutter.
/// Se suscribe directamente al controlador de video nativo y realiza búsquedas
/// binarias instantáneas sobre los datos ya pre-calculados.
class AnalysisSyncEngine {
  final AnalysisPlaybackController playback;
  final BiomechFrameBus bus;
  
  bool _isListening = false;
  int _lastDispatchedPos = -1;

  AnalysisSyncEngine({
    required TickerProvider vsync, // Conservado por compatibilidad de firma
    required this.playback,
    required this.bus,
  });

  /// Inicia la escucha activa de la posición del reproductor de video
  void start() {
    if (_isListening) return;
    
    final controller = playback.videoController;
    if (controller != null) {
      controller.addListener(_onVideoPositionChanged);
      _isListening = true;
      
      // Dispatch inicial
      _onVideoPositionChanged();
    }
  }

  /// Detiene la escucha
  void stop() {
    if (!_isListening) return;
    
    final controller = playback.videoController;
    if (controller != null) {
      controller.removeListener(_onVideoPositionChanged);
      _isListening = false;
    }
  }

  void dispose() {
    stop();
  }

  void reset() {
    _lastDispatchedPos = -1;
  }

  /// Callback de alta frecuencia gatillado por el Media Player de Android/iOS
  void _onVideoPositionChanged() {
    final controller = playback.videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final int currentPosMs = controller.value.position.inMilliseconds;
    final int durationMs = controller.value.duration.inMilliseconds;

    // Guard: evitar duplicación de despachos innecesarios para el mismo milisegundo
    if (currentPosMs == _lastDispatchedPos) return;
    _lastDispatchedPos = currentPosMs;

    // Forzar clamping seguro dentro de la duración del video
    int targetPos = currentPosMs;
    if (durationMs > 0 && targetPos > durationMs) {
      targetPos = durationMs;
    }

    // Gatillar la búsqueda binaria e interpolación lineal local e inmediata
    bus.updatePosition(targetPos);
  }
}
