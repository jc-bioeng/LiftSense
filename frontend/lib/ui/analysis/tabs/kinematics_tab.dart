import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/biomechanic_charts.dart';
import '../metrics/rom_summary.dart';
import '../config/biomech_colors.dart';

class KinematicsTab extends StatelessWidget {
  final ColorScheme colors;

  const KinematicsTab({super.key, required this.colors});

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
        _buildSectionLabel('SEGUIMIENTO DE SESGO'),
        const SizedBox(height: 10),
        const KinematicBiasTracker(),
        const SizedBox(height: 32),
        _buildSectionLabel('ÁNGULOS VS TIEMPO'),
        const SizedBox(height: 10),
        const JointAngleTimeSeriesChart(),
        const SizedBox(height: 32),
        _buildSectionLabel('RESUMEN DE RANGOS (ROM)'),
        const SizedBox(height: 10),
        RomSummary(colors: colors),
      ],
    );
  }
}
