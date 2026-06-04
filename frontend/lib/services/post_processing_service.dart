import 'dart:io';
import 'package:flutter/foundation.dart';
import 'local_database_service.dart';

class PostProcessingResult {
  final bool success;
  final String videoPath;
  final String csvPath;
  final String viewTag;
  final String maxTrunkAngle;
  final String? error;

  const PostProcessingResult({
    required this.success,
    required this.videoPath,
    required this.csvPath,
    required this.viewTag,
    required this.maxTrunkAngle,
    this.error,
  });
}

/// Servicio encargado de ejecutar el pos-procesamiento real mediante la librería de Python.
class PostProcessingService {
  PostProcessingService._();
  static final PostProcessingService instance = PostProcessingService._();

  /// Ejecuta `pose_tracker.py` para procesar el video capturado por la cámara.
  Future<PostProcessingResult> processVideo(String inputVideoPath) async {
    try {
      debugPrint('[PostProcessing] Starting real post-processing for video: $inputVideoPath');

      // 1. Escribir el perfil de usuario actual a JSON
      final profileJsonPath = await LocalDatabaseService.instance.writeUserProfileJson();
      debugPrint('[PostProcessing] Wrote temporary user profile to: $profileJsonPath');

      // 2. Determinar la ruta raíz del proyecto
      String rootPath = 'c:\\flutter_projects\\LiftSense';
      if (Directory.current.path.contains('frontend')) {
        rootPath = Directory.current.parent.path;
      } else if (Directory.current.path.contains('LiftSense')) {
        rootPath = Directory.current.path;
      }

      final pythonExePath = '$rootPath\\.venv\\Scripts\\python.exe';
      final scriptPath = '$rootPath\\python_research\\pose_tracker.py';

      // Verificar que los ejecutables y scripts existan
      final pythonFile = File(pythonExePath);
      final scriptFile = File(scriptPath);

      if (!await pythonFile.exists()) {
        throw Exception('No se encontró el intérprete de Python en la ruta: $pythonExePath');
      }
      if (!await scriptFile.exists()) {
        throw Exception('No se encontró el script de procesamiento en la ruta: $scriptPath');
      }

      // 3. Obtener rutas de salida deseadas
      final fileDir = File(inputVideoPath).parent.path;
      final fileBase = inputVideoPath.split(Platform.pathSeparator).last;
      final dotIndex = fileBase.lastIndexOf('.');
      final baseName = dotIndex != -1 ? fileBase.substring(0, dotIndex) : fileBase;

      final expectedOutVid = '$fileDir\\${baseName}_lstrack.mp4';
      final expectedOutCsv = '$fileDir\\${baseName}_lstrack.csv';

      debugPrint('[PostProcessing] Running command: $pythonExePath pose_tracker.py $inputVideoPath --mode analyze --height ${LocalDatabaseService.instance.height} --profile $profileJsonPath');

      // 4. Ejecutar el script de Python con el directorio de trabajo en python_research
      final result = await Process.run(
        pythonExePath,
        [
          'pose_tracker.py',
          inputVideoPath,
          '--mode',
          'analyze',
          '--height',
          LocalDatabaseService.instance.height.toString(),
          '--profile',
          profileJsonPath,
        ],
        workingDirectory: '$rootPath\\python_research',
      );

      debugPrint('[PostProcessing] Python exit code: ${result.exitCode}');
      if (result.stdout != null && result.stdout.toString().isNotEmpty) {
        debugPrint('[PostProcessing] Python STDOUT: ${result.stdout}');
      }
      if (result.stderr != null && result.stderr.toString().isNotEmpty) {
        debugPrint('[PostProcessing] Python STDERR: ${result.stderr}');
      }

      if (result.exitCode != 0) {
        throw Exception('El motor de Python falló con código ${result.exitCode}. Error: ${result.stderr}');
      }

      // Verificar que los archivos de salida realmente existan
      final outVidFile = File(expectedOutVid);
      final outCsvFile = File(expectedOutCsv);

      if (await outVidFile.exists() && await outCsvFile.exists()) {
        debugPrint('[PostProcessing] SUCCESS! Outputs generated:');
        debugPrint('  Video: $expectedOutVid');
        debugPrint('  CSV: $expectedOutCsv');

        // Procesar el CSV en caliente para extraer el view_type detectado y el trunk_angle máximo
        String detectedView = 'CALCULADO';
        double maxTrunk = 0.0;
        try {
          final lines = await outCsvFile.readAsLines();
          if (lines.length > 1) {
            final header = lines[0].split(',');
            
            // 1. Detectar vista
            final viewIdx = header.indexOf('view_type');
            if (viewIdx != -1) {
              final row = lines[1].split(',');
              if (viewIdx < row.length) {
                final viewStr = row[viewIdx].trim().toUpperCase();
                if (viewStr == 'FRONTAL' || viewStr == 'LATERAL' || viewStr == 'POSTERIOR') {
                  detectedView = viewStr;
                }
              }
            }
            
            // 2. Buscar inclinación máxima del tronco
            final trunkIdx = header.indexOf('trunk_angle_deg');
            if (trunkIdx != -1) {
              for (int i = 1; i < lines.length; i++) {
                final row = lines[i].split(',');
                if (trunkIdx < row.length) {
                  final val = double.tryParse(row[trunkIdx]) ?? 0.0;
                  if (val > maxTrunk) {
                    maxTrunk = val;
                  }
                }
              }
            }
          }
        } catch (csvErr) {
          debugPrint('[PostProcessing] Error parsing generated CSV: $csvErr');
        }

        final maxTrunkAngleStr = '${maxTrunk.toStringAsFixed(0)}°';
        debugPrint('[PostProcessing] Parsed - View: $detectedView, Max Trunk Angle: $maxTrunkAngleStr');
        
        return PostProcessingResult(
          success: true,
          videoPath: expectedOutVid,
          csvPath: expectedOutCsv,
          viewTag: detectedView,
          maxTrunkAngle: maxTrunkAngleStr,
        );
      } else {
        throw Exception('El script finalizó pero no se encontraron los archivos de salida generados en $fileDir.');
      }
    } catch (e) {
      debugPrint('[PostProcessing] Error: $e');
      return PostProcessingResult(
        success: false,
        videoPath: '',
        csvPath: '',
        viewTag: 'ERROR',
        maxTrunkAngle: '0°',
        error: e.toString(),
      );
    }
  }
}
