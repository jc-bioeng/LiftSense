import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/biomechanic_charts.dart';
import '../metrics/vbt_metrics.dart';
import '../config/biomech_colors.dart';

class VelocityTab extends StatelessWidget {
  final ColorScheme colors;

  const VelocityTab({super.key, required this.colors});

  Widget _buildSectionLabel(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: BiomechColors.textSecondary,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        _buildSectionLabel('PERFIL VBT MPV'),
        const SizedBox(height: 10),
        const VelocityTrainingChart(),
        const SizedBox(height: 32),
        _buildSectionLabel('MÉTRICAS DE RENDIMIENTO'),
        const SizedBox(height: 10),
        VbtMetrics(colors: colors),
      ],
    );
  }
}
