import 'dart:typed_data';

/// Implementación de Double Buffering / Ring Buffer para evitar Race Conditions.
/// El Front Buffer es seguro para leer por el UI Thread (CustomPainter).
/// El Back Buffer recibe las actualizaciones asincrónicas del Isolate.
class MetricsDoubleBuffer {
  // Guardamos las métricas decodificadas o el binario. Usaremos una clase simple para la UI.
  final Map<int, Float32List> _backBuffer = {};
  Map<int, Float32List> _frontBuffer = {};

  // Mecanismo de Swap: Se invoca al final de cada frame o por un Ticker.
  void swapBuffers() {
    _frontBuffer = Map.from(_backBuffer);
    // Para limitar memoria, podríamos implementar lógica de Ring Buffer
    // borrando keys muy viejos si _backBuffer supera ej. 1000 items.
    if (_backBuffer.length > 500) {
      final sortedKeys = _backBuffer.keys.toList()..sort();
      // Eliminar los 100 más viejos
      for (int i = 0; i < 100; i++) {
        _backBuffer.remove(sortedKeys[i]);
      }
    }
  }

  /// Inserción segura (Llamada desde el listener del Isolate)
  void insertMetric(int timeMs, Float32List data) {
    _backBuffer[timeMs] = data;
  }

  /// Lectura segura con Tolerancia a Dropped Frames (Llamada por el CustomPainter)
  Float32List? getMetricsAt(int targetTimeMs) {
    if (_frontBuffer.isEmpty) return null;

    // 1. Intento Exacto O(1)
    if (_frontBuffer.containsKey(targetTimeMs)) {
      return _frontBuffer[targetTimeMs];
    }

    // 2. Manejo de Dropped Frames (Búsqueda Interpolada)
    // Encontramos el frame inferior y superior más cercanos.
    int? lowerKey;
    int? upperKey;

    for (int key in _frontBuffer.keys) {
      if (key <= targetTimeMs && (lowerKey == null || key > lowerKey)) {
        lowerKey = key;
      }
      if (key > targetTimeMs && (upperKey == null || key < upperKey)) {
        upperKey = key;
      }
    }

    if (lowerKey == null && upperKey != null) return _frontBuffer[upperKey];
    if (upperKey == null && lowerKey != null) return _frontBuffer[lowerKey];
    if (lowerKey == null && upperKey == null) return null;

    // TODO: Implementar interpolación lineal real entre lowerKey y upperKey.
    // Retornamos el más cercano como Fallback inicial.
    int diffLower = targetTimeMs - lowerKey!;
    int diffUpper = upperKey! - targetTimeMs;

    return (diffLower < diffUpper) ? _frontBuffer[lowerKey] : _frontBuffer[upperKey];
  }
}
