import 'package:flutter/material.dart';
import 'frontal_analysis_screen.dart';
import 'lateral_analysis_screen.dart';

/// Enrutador principal de Análisis Biomecánico.
///
/// Evalúa el [viewTag] de la sesión ('FRONTAL' o 'LATERAL') y enruta
/// dinámicamente al usuario a la pantalla optimizada para ese plano visual.
class AnalysisScreen extends StatelessWidget {
  final String? videoPath;
  final String? csvPath;
  final String exerciseName;
  final String viewTag;
  final String captureDate;
  
  const AnalysisScreen({
    super.key,
    this.videoPath,
    this.csvPath,
    this.exerciseName = 'BACK SQUAT',
    this.viewTag = 'FRONTAL',
    this.captureDate = 'Hoy, 09:41 AM',
  });

  @override
  Widget build(BuildContext context) {
    // Normalizar tag y rutar
    final String normalizedTag = viewTag.trim().toUpperCase();
    
    if (normalizedTag == 'FRONTAL' || normalizedTag == 'CARAC') {
      return FrontalAnalysisScreen(
        videoPath: videoPath,
        csvPath: csvPath,
        exerciseName: exerciseName,
        viewTag: normalizedTag,
        captureDate: captureDate,
      );
    } else {
      // Lateral y Posterior heredan análisis sagital/lateral clínico
      return LateralAnalysisScreen(
        videoPath: videoPath,
        csvPath: csvPath,
        exerciseName: exerciseName,
        viewTag: normalizedTag,
        captureDate: captureDate,
      );
    }
  }
}
