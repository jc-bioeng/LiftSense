import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../domain/vbt_summary.dart';
import '../../../services/biomech_frame_bus.dart';
import '../config/biomech_colors.dart';

class VbtMetrics extends StatelessWidget {
  final ColorScheme colors;

  const VbtMetrics({super.key, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VbtSummary>(
      valueListenable: BiomechFrameBus.instance.vbtNotifier,
      builder: (context, vbt, child) {
        final double meanVelocityVal = vbt.isEmpty ? 0.68 : vbt.meanVelocity;
        final double peakVelocityVal = vbt.isEmpty ? 0.92 : vbt.peakVelocity;
        final double dropOffVal = vbt.isEmpty ? -28.0 : vbt.velocityLossPercent;

        // Drop-off warning color: warning if fatiga exceeds -30%, amber if between -15% and -30%, optimal otherwise
        final Color dropOffColor = dropOffVal <= -30.0
            ? BiomechColors.warning
            : (dropOffVal <= -15.0 ? const Color(0xFFFFB627) : BiomechColors.optimal);

        return Row(
          children: [
            _vbtCard('V. MEDIA', '${meanVelocityVal.toStringAsFixed(2)} m/s', BiomechColors.optimal),
            const SizedBox(width: 12),
            _vbtCard('V. PICO', '${peakVelocityVal.toStringAsFixed(2)} m/s', const Color(0xFF007BFF)),
            const SizedBox(width: 12),
            _vbtCard(
              'DROP-OFF',
              '${dropOffVal.toStringAsFixed(0)}%',
              dropOffColor,
            ),
          ],
        );
      },
    );
  }

  Widget _vbtCard(String label, String value, Color accent) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: BiomechColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border(top: BorderSide(color: accent, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: BiomechColors.textSecondary,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: BiomechColors.textPrimary,
                      letterSpacing: -0.5)),
            ],
          ),
        ),
      );
}
