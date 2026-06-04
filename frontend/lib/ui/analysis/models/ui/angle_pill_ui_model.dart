import 'package:flutter/material.dart';

class AnglePillUiModel {
  final String label;
  final String formattedValue;
  final double value;
  /// Centro del arco del gauge (umbral óptimo de la articulación).
  final double optimalValue;
  /// Cuántos grados se representan a cada lado del centro.
  final double rangeRadius;
  final Color accentColor;
  final String statusLabel;
  final bool visible;

  const AnglePillUiModel({
    required this.label,
    required this.formattedValue,
    required this.value,
    required this.optimalValue,
    required this.rangeRadius,
    required this.accentColor,
    required this.statusLabel,
    this.visible = true,
  });
}
