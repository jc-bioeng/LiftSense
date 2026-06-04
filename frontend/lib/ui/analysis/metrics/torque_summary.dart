import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../domain/biomech_frame_realtime.dart';
import '../../../services/biomech_frame_bus.dart';
import '../config/biomech_colors.dart';

class TorqueSummary extends StatelessWidget {
  final ColorScheme colors;

  const TorqueSummary({super.key, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: BiomechFrameBus.instance.frameNotifier,
      builder: (context, frame, child) {
        // Si el frame no está inicializado, usamos valores predeterminados (mockup)
        final bool isMock = frame.isEmpty || frame.metricsBuffer.isEmpty;

        double hipTorqueVal = 142.0;
        double kneeTorqueVal = 118.0;
        double ankleTorqueVal = 76.0;
        double lumbarTorqueVal = 95.0;

        if (!isMock) {
          // Extraer ángulos reales
          final hipAngle = frame.hipAngle;
          final kneeAngle = frame.kneeAngle;
          final ankleAngle = frame.ankleAngle;
          final trunkAngle = frame.trunkAngle;

          // Cadera Extensor Torque: aumenta con flexión de cadera (180 - hipAngle)
          final hipFlexion = (180.0 - hipAngle).clamp(0.0, 110.0);
          hipTorqueVal = 35.0 + 165.0 * pow(hipFlexion / 110.0, 1.8);

          // Rodilla Extensor Torque: aumenta con flexión de rodilla (180 - kneeAngle)
          final kneeFlexion = (180.0 - kneeAngle).clamp(0.0, 130.0);
          kneeTorqueVal = 30.0 + 130.0 * pow(kneeFlexion / 130.0, 1.5);

          // Tobillo Plantarflexion Torque: aumenta con flexión/dorsiflexión (110 - ankleAngle)
          final ankleFlexion = (110.0 - ankleAngle).clamp(0.0, 45.0);
          ankleTorqueVal = 15.0 + 75.0 * pow(ankleFlexion / 45.0, 1.2);

          // Lumbar Extensor Torque: aumenta con inclinación del tronco (trunkAngle)
          final trunkLean = trunkAngle.clamp(0.0, 60.0);
          lumbarTorqueVal = 25.0 + 115.0 * pow(trunkLean / 60.0, 1.4);
        }

        // Límites máximos sugeridos para normalizar el porcentaje (pct)
        final double hipMax = 220.0;
        final double kneeMax = 180.0;
        final double ankleMax = 100.0;
        final double lumbarMax = 160.0;

        final torqueData = [
          {
            'name': 'Cadera Ext.',
            'value': '${hipTorqueVal.toStringAsFixed(0)} N·m',
            'pct': hipTorqueVal / hipMax,
          },
          {
            'name': 'Rodilla Ext.',
            'value': '${kneeTorqueVal.toStringAsFixed(0)} N·m',
            'pct': kneeTorqueVal / kneeMax,
          },
          {
            'name': 'Tobillo P.F.',
            'value': '${ankleTorqueVal.toStringAsFixed(0)} N·m',
            'pct': ankleTorqueVal / ankleMax,
          },
          {
            'name': 'Lumbar Ext.',
            'value': '${lumbarTorqueVal.toStringAsFixed(0)} N·m',
            'pct': lumbarTorqueVal / lumbarMax,
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
            children: torqueData.asMap().entries.map((entry) {
              final d = entry.value;
              return Column(
                children: [
                  if (entry.key > 0) const SizedBox(height: 20),
                  Row(
                    children: [
                      SizedBox(
                        width: 85,
                        child: Text(
                          (d['name'] as String).toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: BiomechColors.textSecondary),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (d['pct'] as double).clamp(0.0, 1.0),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 65,
                        child: Text(
                          d['value'] as String,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: BiomechColors.textPrimary),
                        ),
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
