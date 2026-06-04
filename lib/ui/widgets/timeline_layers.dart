import 'package:flutter/material.dart';
import 'timeline_data.dart';

// ==========================================
// LAYER 1: STATIC BACKGROUND (Phases & Grid)
// ==========================================
class TimelineBackgroundPainter extends CustomPainter {
  final List<TimelineDataPoint> data;
  final int totalDurationMs;
  final double zoomScale;

  TimelineBackgroundPainter(this.data, this.totalDurationMs, {this.zoomScale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintDescend = Paint()..color = const Color(0xFF00B0FF).withOpacity(0.3);
    final paintBottom = Paint()..color = const Color(0xFFFFC400).withOpacity(0.4);
    final paintAscend = Paint()..color = const Color(0xFF00E676).withOpacity(0.3);

    for (int i = 0; i < data.length - 1; i++) {
      double x1 = (data[i].timeMs / totalDurationMs) * size.width * zoomScale;
      double x2 = (data[i+1].timeMs / totalDurationMs) * size.width * zoomScale;
      
      Paint? phasePaint;
      if (data[i].phase == 1) phasePaint = paintDescend;
      else if (data[i].phase == 2) phasePaint = paintBottom;
      else if (data[i].phase == 3) phasePaint = paintAscend;

      if (phasePaint != null) {
        canvas.drawRect(Rect.fromLTRB(x1, 0, x2, size.height), phasePaint);
      }
    }
    
    // Opcional: Dibujar Grid lines y Timestamps estáticos aquí.
  }

  @override
  bool shouldRepaint(covariant TimelineBackgroundPainter oldDelegate) => false; // Immutable cache
}

// ==========================================
// LAYER 2: CACHED GRAPH (Depth or Velocity)
// ==========================================
class TimelineGraphPainter extends CustomPainter {
  final List<TimelineDataPoint> data;
  final int totalDurationMs;
  final bool showDepth; // Toggle: Depth vs Velocity
  final double zoomScale;

  TimelineGraphPainter(this.data, this.totalDurationMs, this.showDepth, {this.zoomScale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final path = Path();
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;

    double maxVal = 0.0;
    for (var p in data) {
      double val = showDepth ? p.depth.abs() : p.velocity.abs();
      if (val > maxVal) maxVal = val;
    }
    if (maxVal == 0) maxVal = 1.0;

    for (int i = 0; i < data.length; i++) {
      double x = (data[i].timeMs / totalDurationMs) * size.width * zoomScale;
      double val = showDepth ? data[i].depth : data[i].velocity;
      // Normalizar Y
      double y = size.height - ((val.abs() / maxVal) * size.height * 0.8); 
      
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TimelineGraphPainter oldDelegate) => 
      oldDelegate.showDepth != showDepth || oldDelegate.zoomScale != zoomScale;
}

// ==========================================
// LAYER 3: MARKERS (Clusters & Warnings)
// ==========================================
class TimelineMarkersPainter extends CustomPainter {
  final List<TimelineCluster> clusters;
  final int totalDurationMs;
  final double zoomScale;

  TimelineMarkersPainter(this.clusters, this.totalDurationMs, {this.zoomScale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paintSevere = Paint()..color = const Color(0xFFFF1744); // Rojo
    final paintWarning = Paint()..color = const Color(0xFFFFC400); // Naranja/Ambar

    for (var cluster in clusters) {
      double x = ((cluster.startTimeMs + cluster.endTimeMs) / 2 / totalDurationMs) * size.width * zoomScale;
      Paint p = cluster.highestSeverity == AlertSeverity.CRITICAL ? paintSevere : paintWarning;
      
      canvas.drawCircle(Offset(x, size.height / 2), 4.0, p);
      
      if (cluster.eventCount > 1) {
        // Draw group indicator (e.g., text "+3")
        final tp = TextPainter(
          text: TextSpan(text: '${cluster.eventCount}', style: const TextStyle(color: Colors.white, fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width/2, size.height / 2 - 14));
      }
    }
  }

  @override
  bool shouldRepaint(covariant TimelineMarkersPainter oldDelegate) => false;
}

// ==========================================
// LAYER 4: REALTIME PLAYHEAD (Scrubber)
// ==========================================
class TimelinePlayheadPainter extends CustomPainter {
  final int currentTimeMs;
  final int totalDurationMs;
  final bool isScrubbing;
  final double zoomScale;

  TimelinePlayheadPainter(this.currentTimeMs, this.totalDurationMs, this.isScrubbing, {this.zoomScale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (totalDurationMs == 0) return;
    
    double x = (currentTimeMs / totalDurationMs) * size.width * zoomScale;
    
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.0;

    // Reduce glow during active scrubbing to save GPU
    if (!isScrubbing) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);
    }

    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    
    // Thumb / Handle
    canvas.drawRect(Rect.fromCenter(center: Offset(x, size.height / 2), width: 6, height: 16), paint);
  }

  @override
  bool shouldRepaint(covariant TimelinePlayheadPainter oldDelegate) => 
      oldDelegate.currentTimeMs != currentTimeMs || oldDelegate.isScrubbing != isScrubbing;
}
