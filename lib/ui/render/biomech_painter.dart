import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'biomech_render_state.dart';

class BiomechPainter extends CustomPainter {
  final BiomechRenderState state;

  // Cache de brochas (Instanciadas una sola vez)
  late final Paint _bonePaint;
  late final Paint _comPaint;
  late final Paint _jointPaint;
  
  // Para el estilo "Elite Sports Science"
  late final TextPainter _textPainter;

  BiomechPainter(this.state) {
    // Glow effect sutil para el neón
    _bonePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5);

    _comPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = false; // Las líneas guía no requieren antialias pesado

    _jointPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    _textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (state.bones.isEmpty) return;

    // 1. Dibujar COM Line (Proyección al piso)
    if (state.comStart != null && state.comEnd != null) {
      _comPaint.color = state.comColor.withOpacity(0.7);
      _drawDashedLine(canvas, state.comStart!, state.comEnd!, _comPaint);
    }

    // 2. Dibujar Esqueleto (Bones)
    for (final bone in state.bones) {
      _bonePaint.color = bone.color;
      _bonePaint.strokeWidth = bone.strokeWidth;
      canvas.drawLine(bone.start, bone.end, _bonePaint);
      
      // Dibujar "Joint Node" en las intersecciones clave
      _jointPaint.color = Colors.white.withOpacity(0.8);
      canvas.drawCircle(bone.end, bone.strokeWidth * 1.2, _jointPaint);
    }

    // 3. Dibujar Etiquetas HUD (Ángulos)
    for (final label in state.labels) {
      _textPainter.text = TextSpan(
        text: label.text,
        style: TextStyle(
          color: label.color,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: 'RobotoMono', // Tipografía técnica
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 4,
              offset: const Offset(1, 1),
            )
          ],
        ),
      );
      _textPainter.layout();
      
      // Background para la etiqueta (efecto high-tech)
      final rect = Rect.fromLTWH(
        label.position.dx - 4,
        label.position.dy - 2,
        _textPainter.width + 8,
        _textPainter.height + 4,
      );
      
      final bgPaint = Paint()..color = Colors.black45;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), bgPaint);
      
      _textPainter.paint(canvas, label.position);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    
    double distance = (p2 - p1).distance;
    double dx = (p2.dx - p1.dx) / distance;
    double dy = (p2.dy - p1.dy) / distance;

    double start = 0;
    while (start < distance) {
      canvas.drawLine(
        Offset(p1.dx + dx * start, p1.dy + dy * start),
        Offset(p1.dx + dx * (start + dashWidth), p1.dy + dy * (start + dashWidth)),
        paint,
      );
      start += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant BiomechPainter oldDelegate) {
    // Solo repintar si el estado de memoria cambia (por referencia de estado o frame id)
    return oldDelegate.state != state;
  }
}
