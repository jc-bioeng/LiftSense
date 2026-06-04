import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Gestor centralizado para la resolución de rutas de archivos y
/// restauración de assets de prueba (mockups).
class AppAssetsManager {
  static final AppAssetsManager instance = AppAssetsManager._();
  AppAssetsManager._();

  // Lista de assets a restaurar (los nombres coinciden 1:1 con lo que espera la app)
  final List<String> _videosToRestore = [
    'frontal_lstrack.mp4',
    'lateral_lstrack.mp4',
    'posterior_lstrack.mp4',
    'carac_lstrack.mp4',
  ];

  final List<String> _csvsToRestore = [
    'frontal_lstrack.csv',
    'lateral_lstrack.csv',
    'posterior_lstrack.csv',
    'carac_lstrack.csv',
  ];

  /// Restaura los archivos desde assets a la carpeta de documentos si no existen.
  Future<void> restoreAssetsIfMissing() async {
    final docsDir = await getApplicationDocumentsDirectory();

    // Copiar videos con pausa para no bloquear
    for (final fileName in _videosToRestore) {
      final assetPath = 'assets/videos/$fileName';
      final file = File('${docsDir.path}/$fileName');
      
      if (!await file.exists()) {
        try {
          final data = await rootBundle.load(assetPath);
          final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await file.writeAsBytes(bytes);
          debugPrint('AppAssetsManager: Restaurado video $fileName');
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('AppAssetsManager: Error restaurando video $assetPath: $e');
        }
      }
    }

    // Copiar CSVs
    for (final fileName in _csvsToRestore) {
      final assetPath = 'assets/csv/$fileName';
      final file = File('${docsDir.path}/$fileName');
      
      if (!await file.exists()) {
        try {
          final data = await rootBundle.load(assetPath);
          final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await file.writeAsBytes(bytes);
          debugPrint('AppAssetsManager: Restaurado CSV $fileName');
        } catch (e) {
          debugPrint('AppAssetsManager: Error restaurando CSV $assetPath: $e');
        }
      }
    }
  }

  /// Resuelve la ruta completa de un archivo buscando en Documents y luego en Storage externo.
  Future<String?> resolveFilePath(String fileName) async {
    // Si ya es una ruta absoluta y el archivo existe, retornarla directamente
    if (fileName.contains('/') || fileName.contains('\\')) {
      final file = File(fileName);
      if (await file.exists()) {
        return fileName;
      }
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final paths = [
      '${docsDir.path}/$fileName',
      '/storage/emulated/0/LiftSense/$fileName',
    ];

    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        return path;
      }
    }
    return null;
  }
}
