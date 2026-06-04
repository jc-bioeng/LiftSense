import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/biomech_frame_bus.dart';
import '../../../services/biomech_selectors.dart';
import '../config/biomech_colors.dart';
import '../models/ui/angle_pill_ui_model.dart';

class AngleGauges extends StatefulWidget {
  final BiomechFrameBus bus;

  const AngleGauges({super.key, required this.bus});

  @override
  State<AngleGauges> createState() => _AngleGaugesState();
}

class _AngleGaugesState extends State<AngleGauges> {
  late final MemoizedAngleSelector _hipSelector;
  late final MemoizedAngleSelector _kneeSelector;
  late final MemoizedAngleSelector _ankleSelector;
  late final MemoizedAngleSelector _trunkSelector;

  @override
  void initState() {
    super.initState();
    _hipSelector = BiomechSelectors.createHipFlexion();
    _kneeSelector = BiomechSelectors.createKneeFlexion();
    _ankleSelector = BiomechSelectors.createAnkleFlexion();
    _trunkSelector = BiomechSelectors.createTrunkFlexion();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÁNGULOS EN TIEMPO REAL',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: BiomechColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ReactiveGauge(bus: widget.bus, selector: _hipSelector),
            _ReactiveGauge(bus: widget.bus, selector: _kneeSelector),
            _ReactiveGauge(bus: widget.bus, selector: _ankleSelector),
            _ReactiveGauge(bus: widget.bus, selector: _trunkSelector),
          ],
        ),
      ],
    );
  }
}

class _ReactiveGauge extends StatefulWidget {
  final BiomechFrameBus bus;
  final MemoizedAngleSelector selector;

  const _ReactiveGauge({
    required this.bus,
    required this.selector,
  });

  @override
  State<_ReactiveGauge> createState() => _ReactiveGaugeState();
}

class _ReactiveGaugeState extends State<_ReactiveGauge> {
  late AnglePillUiModel _model;

  @override
  void initState() {
    super.initState();
    _model = widget.selector.select(widget.bus.frameNotifier.value);
    widget.bus.frameNotifier.addListener(_onFrame);
  }

  @override
  void dispose() {
    widget.bus.frameNotifier.removeListener(_onFrame);
    super.dispose();
  }

  void _onFrame() {
    final newModel = widget.selector.select(widget.bus.frameNotifier.value);
    if (!identical(newModel, _model)) {
      setState(() {
        _model = newModel;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final gaugeSize = (size.width - 40 - 24) / 4; // Screen width - margins - gaps
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: gaugeSize,
          height: gaugeSize,
          decoration: BoxDecoration(
            color: BiomechColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(gaugeSize, gaugeSize),
                painter: GaugePainter(
                  value: _model.value,
                  optimalValue: _model.optimalValue,
                  rangeRadius: _model.rangeRadius,
                  color: _model.accentColor,
                ),
              ),
              Positioned(
                bottom: gaugeSize * 0.25,
                child: Text(
                  _model.formattedValue,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BiomechColors.textPrimary,
                    shadows: [
                      Shadow(
                        color: _model.accentColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: gaugeSize,
          child: Text(
            _model.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: BiomechColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class GaugePainter extends CustomPainter {
  final double value;
  /// Centro del arco — el gauge está centrado aquí (umbral óptimo).
  final double optimalValue;
  /// Cuántos grados a cada lado del centro representa el arco completo.
  final double rangeRadius;
  final Color color;

  GaugePainter({
    required this.value,
    required this.optimalValue,
    required this.rangeRadius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // El arco empieza a la izquierda (150°) y barre 240° en total.
    // El centro del arco (120° de sweep) corresponde al optimalValue.
    const startAngle = 5 * pi / 6;   // 150° — inicio del arco
    const sweepTotal = 4 * pi / 3;   // 240° — sweep total del arco
    const centerAngle = startAngle + sweepTotal / 2; // 270° — posición central

    // Mapeo: fraction 0.0 = borde izquierdo, 0.5 = centro, 1.0 = borde derecho
    final fraction = ((value - optimalValue) / (2 * rangeRadius) + 0.5).clamp(0.0, 1.0);
    final needleAngle = startAngle + sweepTotal * fraction;

    // ---- Arco de fondo ----
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // ---- Marca central (posición óptima) ----
    final centerMarkEnd = Offset(
      center.dx + (radius + 4) * cos(centerAngle),
      center.dy + (radius + 4) * sin(centerAngle),
    );
    final centerMarkStart = Offset(
      center.dx + (radius - 8) * cos(centerAngle),
      center.dy + (radius - 8) * sin(centerAngle),
    );
    final centerMarkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(centerMarkStart, centerMarkEnd, centerMarkPaint);

    // ---- Arco de valor: desde el centro hacia la posición actual ----
    // Se dibuja como un arco centrado en el óptimo que se extiende en la
    // dirección del desvío (izquierda si menor, derecha si mayor).
    final devFraction = (value - optimalValue) / (2 * rangeRadius); // [-0.5, 0.5]
    final arcStartAngle = devFraction >= 0 ? centerAngle : needleAngle;
    final arcSweep = (devFraction * sweepTotal).abs();

    if (arcSweep > 0.01) {
      final valuePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        arcStartAngle,
        arcSweep,
        false,
        valuePaint,
      );
    }

    // ---- Aguja ----
    final needleLength = radius - 8;
    final needleEnd = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );
    final needleStart = Offset(
      center.dx + 10 * cos(needleAngle),
      center.dy + 10 * sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(needleStart, needleEnd, needlePaint);

    // Círculo en el extremo de la aguja
    canvas.drawCircle(needleEnd, 3.5, Paint()..color = color);
    canvas.drawCircle(needleEnd, 3.5, Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    // Punto central pequeño
    canvas.drawCircle(center, 2.5, Paint()..color = Colors.white.withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.optimalValue != optimalValue ||
        oldDelegate.rangeRadius != rangeRadius;
  }
}
