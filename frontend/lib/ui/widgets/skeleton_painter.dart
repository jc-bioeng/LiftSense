import 'dart:math';
import 'package:flutter/material.dart';

class SkeletonMockupView extends StatefulWidget {
  final bool isActive;
  const SkeletonMockupView({super.key, required this.isActive});

  @override
  State<SkeletonMockupView> createState() => _SkeletonMockupViewState();
}

class _SkeletonMockupViewState extends State<SkeletonMockupView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: SkeletonPainter(
            progress: _controller.value,
            color: const Color(0xFF00D4AA),
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class SkeletonPainter extends CustomPainter {
  final double progress;
  final Color color;

  SkeletonPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Simulate Squat Movement
    // progress 0.0 -> Descent -> 0.5 (Bottom) -> 1.0 (Ascent / Lockout)
    final t = (progress < 0.5) ? progress * 2 : (1.0 - (progress - 0.5) * 2);
    final curve = Curves.easeInOutCubic.transform(t);

    final centerX = size.width / 2;
    final topY = size.height * 0.25;
    
    // Joint offsets relative to center
    // Shoulders
    final shoulderY = topY + (curve * 40);
    final shoulderL = Offset(centerX - 40, shoulderY);
    final shoulderR = Offset(centerX + 40, shoulderY);
    
    // Hips
    final hipY = shoulderY + 80 + (curve * 100);
    final hipL = Offset(centerX - 35, hipY);
    final hipR = Offset(centerX + 35, hipY);
    
    // Knees (move out and down)
    final kneeY = hipY + 100 - (curve * 40);
    final kneeXOffset = 40 + (curve * 30);
    final kneeL = Offset(centerX - kneeXOffset, kneeY);
    final kneeR = Offset(centerX + kneeXOffset, kneeY);
    
    // Ankles (stay fixed mostly)
    final ankleY = size.height * 0.85;
    final ankleL = Offset(centerX - 45, ankleY);
    final ankleR = Offset(centerX + 45, ankleY);

    // Spine/Torso
    final head = Offset(centerX, shoulderY - 30);

    void drawBone(Offset a, Offset b) {
      canvas.drawLine(a, b, glowPaint);
      canvas.drawLine(a, b, paint);
    }

    void drawJoint(Offset p, String? label, String? value, Color txtColor) {
      canvas.drawCircle(p, 4, dotPaint);
      if (label != null) {
        final tp = TextPainter(
          text: TextSpan(
            children: [
              TextSpan(text: label, style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
              if (value != null)
                TextSpan(text: '\n$value', style: TextStyle(color: txtColor, fontSize: 10, fontWeight: FontWeight.w900)),
            ],
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout();
        tp.paint(canvas, p + const Offset(10, -10));
      }
    }

    // Draw Skeleton
    // Upper body
    drawBone(head, Offset(centerX, shoulderY));
    drawBone(shoulderL, shoulderR);
    drawBone(shoulderL, hipL);
    drawBone(shoulderR, hipR);
    drawBone(hipL, hipR);
    
    // Legs
    drawBone(hipL, kneeL);
    drawBone(kneeL, ankleL);
    drawBone(hipR, kneeR);
    drawBone(kneeR, ankleR);

    // Joints with dynamic data
    drawJoint(head, null, null, Colors.white);
    drawJoint(shoulderL, null, null, Colors.white);
    drawJoint(shoulderR, null, null, Colors.white);
    
    // Biomechanical Data Points (Simulated but visual)
    final hipAngle = (90 + curve * 30).toStringAsFixed(1) + '°';
    final kneeAngle = (120 - curve * 40).toStringAsFixed(1) + '°';
    final ankleAngle = (30 + curve * 10).toStringAsFixed(1) + '°';

    drawJoint(hipL, 'CAD', hipAngle, color);
    drawJoint(hipR, null, null, color);
    drawJoint(kneeL, 'ROD', kneeAngle, color);
    drawJoint(kneeR, null, null, color);
    drawJoint(ankleL, 'TOB', ankleAngle, const Color(0xFFFFB627));
    drawJoint(ankleR, null, null, Colors.white);
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) => 
      oldDelegate.progress != progress || oldDelegate.color != color;
}
