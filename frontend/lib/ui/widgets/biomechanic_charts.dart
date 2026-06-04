import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/biomech_frame_bus.dart';
import '../../domain/biomech_frame_realtime.dart';
import '../../domain/vbt_summary.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS — Mantiene coherencia con dashboard identity
// ═══════════════════════════════════════════════════════════════
const _surfaceColor = Color(0xFF141416);
const _borderHighlight = 0.05; // alpha for top border "illumination"

BoxDecoration _panelDecoration({Color? topBorderColor}) => BoxDecoration(
  color: _surfaceColor,
  borderRadius: BorderRadius.circular(14),
  border: Border(
    top: BorderSide(
      color: topBorderColor ?? Colors.white.withValues(alpha: _borderHighlight),
      width: 1,
    ),
  ),
);



TextStyle _label() => GoogleFonts.inter(
  fontSize: 10,
  fontWeight: FontWeight.w500,
  color: Colors.white38,
);

TextStyle _body() => GoogleFonts.inter(
  fontSize: 12,
  color: Colors.white70,
  height: 1.5,
);

// ═══════════════════════════════════════════════════════════════
//  1. KINEMATIC BIAS TRACKER
//     Basado en: Ángulo Tronco-Tibia como predictor de demanda
//     muscular (hip bias vs knee bias vs neutral)
// ═══════════════════════════════════════════════════════════════
class KinematicBiasTracker extends StatelessWidget {
  const KinematicBiasTracker({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bus = BiomechFrameBus.instance;

    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: bus.frameNotifier,
      builder: (context, frame, _) {
        final trunkAngle = frame.trunkAngle;
        final tibiaAngle = frame.tibiaAngle;
        final diff = frame.hipBias;

        String biasLabel;
        String biasDesc;
        Color biasColor;
        
        if (diff > 8) {
          biasLabel = 'SESGO DE CADERA';
          biasDesc = 'Tu tronco se inclina ${diff.toStringAsFixed(1)}° más que la tibia.\nLa cadena posterior (glúteos) absorbe la mayor carga.';
          biasColor = colors.primary;
        } else if (diff < -8) {
          biasLabel = 'SESGO DE RODILLA';
          biasDesc = 'La tibia avanza ${(-diff).toStringAsFixed(1)}° más que el tronco.\nEl cuádriceps soporta la mayor demanda articular.';
          biasColor = const Color(0xFF007BFF);
        } else {
          biasLabel = 'NEUTRAL';
          biasDesc = 'Diferencia de ${diff.toStringAsFixed(1)}°. Distribución equilibrada\nentre extensores de cadera y rodilla (ratio ≈ 1.0).';
          biasColor = const Color(0xFFFFB627);
        }

        // Heurística de contribución muscular
        final double glutePct = (50 + diff * 1.8).clamp(20, 80);
        final double quadPct = 100 - glutePct;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _panelDecoration(topBorderColor: biasColor.withValues(alpha: 0.3)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with bias classification
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: biasColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(biasLabel, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: biasColor)),
                      const SizedBox(height: 2),
                      Text('Clasificación dinámica automática', style: _label()),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Angle comparison row
              Row(
                children: [
                  _buildAngleChip('TRONCO', trunkAngle, colors.primary),
                  const SizedBox(width: 10),
                  _buildAngleChip('TIBIA', tibiaAngle, const Color(0xFF007BFF)),
                  const SizedBox(width: 10),
                  _buildAngleChip('ΔDIF', diff, biasColor),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              Text(biasDesc, style: _body()),

              const SizedBox(height: 12),

              // Muscle contribution bar
              Text('CONTRIBUCIÓN ESTIMADA', style: _label()),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Expanded(
                      flex: glutePct.toInt(),
                      child: Container(height: 8, color: colors.primary),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: quadPct.toInt(),
                      child: Container(height: 8, color: const Color(0xFF007BFF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Glúteo · Isquio  ${glutePct.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: colors.primary)),
                  Text('Cuádriceps  ${quadPct.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF007BFF))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAngleChip(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7), letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text('${value.toStringAsFixed(1)}°', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  2. JOINT ANGLE TIME-SERIES CHART  
//     Cinemática articular a lo largo del ciclo del squat
//     (Hip, Knee, Ankle, Trunk vs % del movimiento)
// ═══════════════════════════════════════════════════════════════
class JointAngleTimeSeriesChart extends StatelessWidget {
  const JointAngleTimeSeriesChart({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bus = BiomechFrameBus.instance;

    return ValueListenableBuilder<List<Float32List>>(
      valueListenable: bus.seriesNotifier,
      builder: (context, series, _) {
        if (series.isEmpty || series[0].isEmpty) {
          return Container(
            height: 240,
            decoration: _panelDecoration(),
            child: const Center(
              child: Text(
                'Cargando cinemática...',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          );
        }

        final hipData = _mapToSpots(series[0]);
        final kneeData = _mapToSpots(series[1]);
        final ankleData = _mapToSpots(series[2]);

        return Container(
          height: 240,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          decoration: _panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _legendDot('Cadera', colors.primary),
                  const SizedBox(width: 16),
                  _legendDot('Rodilla', const Color(0xFF007BFF)),
                  const SizedBox(width: 16),
                  _legendDot('Tobillo', const Color(0xFFFFB627)),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LineChart(
                  LineChartData(
                    lineTouchData: const LineTouchData(enabled: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 45,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withValues(alpha: 0.05),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 25,
                          getTitlesWidget: (value, meta) {
                            if (value % 25 != 0) return const SizedBox();
                            return Text('${value.toInt()}%', style: _label());
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      _buildLine(hipData, colors.primary),
                      _buildLine(kneeData, const Color(0xFF007BFF)),
                      _buildLine(ankleData, const Color(0xFFFFB627)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<FlSpot> _mapToSpots(Float32List data) {
    if (data.isEmpty) return [];
    final step = (data.length / 50).clamp(1, 100).toInt();
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i += step) {
      final percent = (i / (data.length - 1)) * 100;
      spots.add(FlSpot(percent, data[i]));
    }
    return spots;
  }

  LineChartBarData _buildLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.06),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white54)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  3. JOINT LOADS CHART (Bar)
//     Fuerzas de cizallamiento y compresión articular estimadas
//     Datos basados en la investigación del usuario
// ═══════════════════════════════════════════════════════════════
class JointLoadsChart extends StatelessWidget {
  const JointLoadsChart({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: BiomechFrameBus.instance.frameNotifier,
      builder: (context, frame, child) {
        final bool isMock = frame.isEmpty || frame.metricsBuffer.isEmpty;

        double aclValue = 450.0;
        double pclValue = 800.0;
        double patellaValue = 4200.0;
        double lumbarValue = 7200.0;

        if (!isMock) {
          final kneeAngle = frame.kneeAngle;
          final trunkAngle = frame.trunkAngle;

          final kneeFlexion = (180.0 - kneeAngle).clamp(0.0, 130.0);
          final trunkLean = trunkAngle.clamp(0.0, 60.0);

          // LCA Cizalla: peaks at 15°-45° flexion, drops in deep flexion
          if (kneeFlexion <= 45.0) {
            aclValue = 100.0 + 350.0 * sin((kneeFlexion / 45.0) * (pi / 2.0));
          } else {
            aclValue = 100.0 + 350.0 * cos(((kneeFlexion - 45.0) / 75.0) * (pi / 2.0));
          }

          // LCP Cizalla: increases with deep flexion
          pclValue = 100.0 + 700.0 * (kneeFlexion / 120.0);

          // Rótula Compresión: increases with knee flexion
          patellaValue = 200.0 + 4000.0 * pow(kneeFlexion / 110.0, 1.5);

          // Lumbar Axial: increases with trunk lean
          lumbarValue = 1200.0 + 6000.0 * pow(trunkLean / 50.0, 1.3);
        }

        final aclMax = 2000.0;
        final pclMax = 4000.0;
        final patellaMax = 5000.0;
        final lumbarMax = 8000.0;

        final aclPct = aclValue / aclMax;
        final pclPct = pclValue / pclMax;
        final patellaPct = patellaValue / patellaMax;
        final lumbarPct = lumbarValue / lumbarMax;

        // Determinar advertencia
        String warningMsg = 'Cargas articulares en rangos óptimos y tolerables.';
        Color warningColor = const Color(0xFF00D4AA); // Teal / Safe
        IconData warningIcon = Icons.check_circle_outline_rounded;

        if (patellaPct > 0.8) {
          warningMsg = 'Compresión rotuliana en zona de atención (${(patellaPct * 100).toStringAsFixed(0)}% del umbral)';
          warningColor = colors.tertiary;
          warningIcon = Icons.warning_amber_rounded;
        } else if (lumbarPct > 0.8) {
          warningMsg = 'Carga axial lumbar elevada (${(lumbarPct * 100).toStringAsFixed(0)}% del umbral). Evita redondear la espalda.';
          warningColor = colors.tertiary;
          warningIcon = Icons.warning_amber_rounded;
        } else if (aclPct > 0.8) {
          warningMsg = 'Fuerza de cizalla del LCA elevada. Reduce la velocidad de descenso.';
          warningColor = colors.tertiary;
          warningIcon = Icons.warning_amber_rounded;
        } else if (pclPct > 0.8) {
          warningMsg = 'Fuerza de cizalla del LCP elevada.';
          warningColor = colors.tertiary;
          warningIcon = Icons.warning_amber_rounded;
        } else if (patellaPct > 0.6 || lumbarPct > 0.6) {
          warningMsg = 'Demanda articular moderada. Carga y reclutamiento óptimos.';
          warningColor = const Color(0xFFFFB627); // Amber
          warningIcon = Icons.info_outline_rounded;
        }

        final loads = [
          {
            'label': 'LCA\nCizalla',
            'value': aclValue,
            'max': aclMax,
            'color': colors.primary,
            'unit': '${aclValue.toStringAsFixed(0)} N',
          },
          {
            'label': 'LCP\nCizalla',
            'value': pclValue,
            'max': pclMax,
            'color': const Color(0xFF007BFF),
            'unit': '${pclValue.toStringAsFixed(0)} N',
          },
          {
            'label': 'Rótula\nCompresión',
            'value': patellaValue,
            'max': patellaMax,
            'color': colors.tertiary,
            'unit': '${(patellaValue / 1000).toStringAsFixed(1)} kN',
          },
          {
            'label': 'Lumbar\nAxial',
            'value': lumbarValue,
            'max': lumbarMax,
            'color': const Color(0xFF8B5CF6),
            'unit': '${(lumbarValue / 1000).toStringAsFixed(1)} kN',
          },
        ];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic warning header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(warningIcon, color: warningColor, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warningMsg,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: warningColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Load bars
              ...loads.map((d) {
                final pct = (d['value'] as double) / (d['max'] as double);
                final color = d['color'] as Color;
                final isHigh = pct > 0.8;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            (d['label'] as String).replaceAll('\n', ' '),
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white54),
                          ),
                          Row(
                            children: [
                              Text(
                                d['unit'] as String,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isHigh ? color : Colors.white),
                              ),
                              if (isHigh) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.warning_amber_rounded,
                                    size: 12, color: color),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: pct.clamp(0.0, 1.0),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          // Tissue limit marker
                          Positioned(
                            left: null,
                            right: 0,
                            child: Container(
                              width: 1.5,
                              height: 8,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Límite tejido: ${(d['max'] as double).toInt()} N',
                          style: GoogleFonts.inter(
                              fontSize: 8, color: Colors.white24),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  4. BUTT WINK ALERT CARD
//     Basado en: Detección algorítmica de inversión lumbar
//     (ASIS/PSIS tracking + pérdida de lordosis)
// ═══════════════════════════════════════════════════════════════
class ButtWinkAlertCard extends StatelessWidget {
  const ButtWinkAlertCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.tertiary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.tertiary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.report_problem_rounded, color: colors.tertiary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INVERSIÓN LUMBAR DETECTADA', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: colors.tertiary)),
                    Text('Frame #127 — Fase excéntrica profunda', style: GoogleFonts.inter(fontSize: 10, color: Colors.white38)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Key metrics row
          Row(
            children: [
              _buildAlertMetric('LORDOSIS', '-8.3°', 'Inversión detectada', colors.tertiary),
              const SizedBox(width: 10),
              _buildAlertMetric('HJ_PFA', '96.2°', 'Límite de cadera', const Color(0xFFFFB627)),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'La pelvis ha rotado posteriormente, forzando la columna lumbar (L4-L5) a perder su curvatura natural. Bajo compresión axial de ~7.2 kN, las estructuras pasivas (disco intervertebral, lig. longitudinal posterior) absorben la carga.',
            style: _body(),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: const Color(0xFFFFB627), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recomendación: Limitar profundidad 5° antes del frame actual, o ampliar stance a 1.5× ancho biacromial.',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white60, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertMetric(String label, String value, String desc, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.5)),
            Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(desc, style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  5. RECTUS FEMORIS ALERT (Lombard Paradox)
//     Basado en: Insuficiencia activa del recto femoral
//     biarticular durante el squat
// ═══════════════════════════════════════════════════════════════
class RectusFemorisAlertCard extends StatelessWidget {
  const RectusFemorisAlertCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB627).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB627).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB627).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline_rounded, color: Color(0xFFFFB627), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PARADOJA DE LOMBARD', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFFFB627))),
                    Text('Músculo biarticular en conflicto', style: GoogleFonts.inter(fontSize: 10, color: Colors.white38)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'El Recto Femoral experimenta insuficiencia activa (acortado en cadera, estirado en rodilla). Su longitud neta es casi constante durante todo el squat, limitando severamente su activación máxima.',
            style: _body(),
          ),
          const SizedBox(height: 10),
          Text(
            'El trabajo extenso de rodilla recae sobre Vasto Lateral y Vasto Medial. Isquiosurales actúan como estabilizadores de cizallamiento (co-contracción anti-LCA), no como productores de potencia.',
            style: _body(),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: colors.primary, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nota clínica: Incrementar profundidad no aumenta activación del Recto Femoral. Para hipertrofiarlo, trabajar extensión de rodilla aislada.',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white60, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  6. VELOCITY TRAINING CHART (VBT)
//     Basado en: MCV, PCV, MPV y velocity loss thresholds
//     del paper del usuario
// ═══════════════════════════════════════════════════════════════
class VelocityTrainingChart extends StatelessWidget {
  const VelocityTrainingChart({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ValueListenableBuilder<VbtSummary>(
      valueListenable: BiomechFrameBus.instance.vbtNotifier,
      builder: (context, vbt, child) {
        final bool isMock = vbt.isEmpty;

        // Fallback data if empty
        final List<double> meanVelocities = isMock
            ? [0.82, 0.78, 0.74, 0.70, 0.65, 0.61, 0.57, 0.52]
            : vbt.repMeanVelocities;

        final double firstMean = meanVelocities.first;

        // Umbral de pérdida de velocidad al -30% basado en la primera repetición
        final double lossThreshold = firstMean * 0.70;
        final double dropOffPctVal = isMock
            ? 36.6
            : vbt.velocityLossPercent.abs();

        // Crear FlSpots
        final mpvSpots = <FlSpot>[];
        for (int i = 0; i < meanVelocities.length; i++) {
          mpvSpots.add(FlSpot((i + 1).toDouble(), meanVelocities[i]));
        }

        // Determinar si hay alguna repetición que cruza el umbral
        int cutRepIndex = -1;
        for (int i = 0; i < meanVelocities.length; i++) {
          if (meanVelocities[i] <= lossThreshold) {
            cutRepIndex = i + 1;
            break;
          }
        }

        String recommendationMsg = 'Mantén la velocidad de ejecución. Fatiga controlada y segura.';
        if (cutRepIndex != -1) {
          recommendationMsg = 'Recomendación: Cortar serie en Rep $cutRepIndex. La fatiga excede el umbral del -30%.';
        } else if (dropOffPctVal > 20.0) {
          recommendationMsg = 'Recomendación: Considera terminar la serie. Pérdida de velocidad moderada (${dropOffPctVal.toStringAsFixed(0)}%).';
        }

        // Dinamizar límites de la gráfica
        final double minX = 1;
        final double maxX = meanVelocities.length.toDouble().clamp(4.0, 15.0);
        
        final double minVal = meanVelocities.reduce(min);
        final double maxVal = meanVelocities.reduce(max);
        
        final double minY = (minVal - 0.1).clamp(0.1, 1.5);
        final double maxY = (maxVal + 0.1).clamp(0.8, 2.5);

        return Container(
          height: 340,
          padding: const EdgeInsets.all(20),
          decoration: _panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rep counter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('${meanVelocities.length}', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(width: 6),
                      Text('REPS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1.0)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.tertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚡ -${dropOffPctVal.toStringAsFixed(1)}% DROP-OFF',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: colors.tertiary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 0.1,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withValues(alpha: 0.05),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (value < 1 || value > meanVelocities.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('R${value.toInt()}', style: GoogleFonts.inter(fontSize: 9, color: Colors.white30)),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          interval: 0.1,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(1),
                            style: GoogleFonts.inter(fontSize: 9, color: Colors.white30),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: minX, maxX: maxX,
                    minY: minY, maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: mpvSpots,
                        isCurved: true,
                        curveSmoothness: 0.25,
                        color: colors.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            final isBelow = spot.y <= lossThreshold;
                            return FlDotCirclePainter(
                              radius: 4,
                              color: isBelow ? colors.tertiary : colors.primary,
                              strokeWidth: 2,
                              strokeColor: const Color(0xFF141416),
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: colors.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: lossThreshold,
                          color: colors.tertiary.withValues(alpha: 0.5),
                          strokeWidth: 1.5,
                          dashArray: [6, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: colors.tertiary),
                            labelResolver: (_) => 'UMBRAL -30%',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Dynamic Recommendation
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_off_outlined, color: colors.tertiary, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recommendationMsg,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: colors.tertiary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
