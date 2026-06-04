import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';
import '../../utils/metrics_buffer.dart';
import 'biomech_render_state.dart';

/// Define cómo mapear el Float32List crudo a un BiomechRenderState amigable.
typedef StateMapper = BiomechRenderState Function(int timeMs, dynamic rawData);

class ActiveTickerSync {
  final VideoPlayerController videoController;
  final MetricsDoubleBuffer buffer;
  final StateMapper mapper;
  
  Ticker? _ticker;
  BiomechRenderState currentState = BiomechRenderState.empty;
  
  // Callback opcional si la UI quiere forzar un setState (aunque lo ideal es ValueNotifier)
  final void Function(BiomechRenderState) onStateUpdated;

  ActiveTickerSync({
    required this.videoController,
    required this.buffer,
    required this.mapper,
    required this.onStateUpdated,
  });

  void start(TickerProvider vsync) {
    _ticker?.dispose();
    _ticker = vsync.createTicker(_onTick);
    _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    if (!videoController.value.isPlaying && !videoController.value.isBuffering) {
      // Si el video está pausado, solo actualizamos si hay scrub (arrastre manual).
      // Aquí podríamos optimizar retornando, pero asumiendo scrubbing activo, lo mantenemos.
    }

    // 1. Reloj Monotónico: Obtenemos el tiempo exacto del motor de video
    final currentVideoTimeMs = videoController.value.position.inMilliseconds;

    // 2. Consulta de O(1) o Interpolada al Double Buffer
    final rawData = buffer.getMetricsAt(currentVideoTimeMs);

    // 3. Mapeo a Render State precalculado
    if (rawData != null) {
      final newState = mapper(currentVideoTimeMs, rawData);
      if (newState != currentState) {
        currentState = newState;
        onStateUpdated(currentState);
      }
    }
  }

  void stop() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }
}
