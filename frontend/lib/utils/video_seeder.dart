import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class VideoSeeder {
  static const List<String> videos = [
    'mockup_squat.mp4',
    'squat_1.mp4',
    'squat_1_out.mp4',
    'squat_2.mp4',
    'squat_2_out.mp4',
    'squat_3.mp4',
    'squat_3_out.mp4',
  ];

  static Future<void> seedVideos() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final targetPath = docsDir.path;

      for (String fileName in videos) {
        final file = File('$targetPath/$fileName');
        if (!await file.exists()) {
          print('Seeding $fileName ...');
          final data = await rootBundle.load('assets/videos/$fileName');
          final bytes = data.buffer.asUint8List();
          await file.writeAsBytes(bytes, flush: true);
        }
      }
      print('Seeding completed successfully to $targetPath.');
    } catch (e) {
      print('Error seeding videos: $e');
    }
  }
}
