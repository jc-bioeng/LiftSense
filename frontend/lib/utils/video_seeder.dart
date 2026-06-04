import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class VideoSeeder {
  static Future<void> seedVideos() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File('${docsDir.path}/mockup_squat.mp4');
      
      if (!await file.exists()) {
        try {
          final byteData = await rootBundle.load('assets/videos/mockup_squat.mp4');
          await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
          debugPrint('Video mockup_squat.mp4 sembrado exitosamente.');
        } catch (e) {
          try {
             // Fallback if it's directly in assets/
             final byteData = await rootBundle.load('assets/mockup_squat.mp4');
             await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
          } catch (e2) {
             debugPrint('Error al cargar mockup_squat.mp4 desde assets: $e2');
          }
        }
      }

      // Sembrar CSVs
      final csvs = ['lateral_lstrack.csv', 'frontal_lstrack.csv'];
      for (final csvName in csvs) {
        final csvFile = File('${docsDir.path}/$csvName');
        if (!await csvFile.exists()) {
          try {
            final byteData = await rootBundle.load('assets/csv/$csvName');
            await csvFile.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
            debugPrint('CSV $csvName sembrado exitosamente.');
          } catch (e) {
            debugPrint('Error al cargar $csvName desde assets: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error general en VideoSeeder: $e');
    }
  }
  
  static void debugPrint(String message) {
    // ignore: avoid_print
    print(message);
  }
}
