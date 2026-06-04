import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/biomech_frame_bus.dart';
import '../config/biomech_colors.dart';

class RomSummary extends StatelessWidget {
  final ColorScheme colors;

  const RomSummary({super.key, required this.colors});

  double _calculateRom(Float32List series) {
    if (series.isEmpty) return 0.0;
    double minVal = series[0];
    double maxVal = series[0];
    for (int i = 1; i < series.length; i++) {
      final val = series[i];
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }
    return maxVal - minVal;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Float32List>>(
      valueListenable: BiomechFrameBus.instance.seriesNotifier,
      builder: (context, seriesList, child) {
        // Fallback or dynamic values
        final double hipRom = seriesList.isNotEmpty ? _calculateRom(seriesList[0]) : 92.3;
        final double kneeRom = seriesList.length > 1 ? _calculateRom(seriesList[1]) : 118.7;
        final double ankleRom = seriesList.length > 2 ? _calculateRom(seriesList[2]) : 28.4;
        final double trunkRom = seriesList.length > 3 ? _calculateRom(seriesList[3]) : 42.1;

        // Check against reference ranges
        // Hip: 90°–120°
        final isHipOk = hipRom >= 90.0 && hipRom <= 120.0;
        // Knee: 110°–140°
        final isKneeOk = kneeRom >= 110.0 && kneeRom <= 140.0;
        // Ankle: 30°–45°
        final isAnkleOk = ankleRom >= 30.0 && ankleRom <= 45.0;
        // Trunk: 35°–55°
        final isTrunkOk = trunkRom >= 35.0 && trunkRom <= 55.0;

        final romData = [
          {
            'joint': 'Cadera',
            'rom': '${hipRom.toStringAsFixed(1)}°',
            'ref': '90°–120°',
            'ok': isHipOk,
          },
          {
            'joint': 'Rodilla',
            'rom': '${kneeRom.toStringAsFixed(1)}°',
            'ref': '110°–140°',
            'ok': isKneeOk,
          },
          {
            'joint': 'Tobillo',
            'rom': '${ankleRom.toStringAsFixed(1)}°',
            'ref': '30°–45°',
            'ok': isAnkleOk,
          },
          {
            'joint': 'Tronco',
            'rom': '${trunkRom.toStringAsFixed(1)}°',
            'ref': '35°–55°',
            'ok': isTrunkOk,
          },
        ];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: BiomechColors.card,
            borderRadius: BorderRadius.circular(16),
            border: const Border(
              top: BorderSide(color: Color(0x0DFFFFFF), width: 1),
            ),
          ),
          child: Column(
            children: romData.asMap().entries.map((entry) {
              final d = entry.value;
              final isOk = d['ok'] as bool;
              return Column(
                children: [
                  if (entry.key > 0)
                    const Divider(color: Colors.white10, height: 30),
                  Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          (d['joint'] as String).toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: BiomechColors.textSecondary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          d['rom'] as String,
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: BiomechColors.textPrimary,
                              letterSpacing: -0.5),
                        ),
                      ),
                      Text(d['ref'] as String,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.white30)),
                      const SizedBox(width: 12),
                      Icon(
                        isOk ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: isOk ? BiomechColors.optimal : BiomechColors.warning,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
