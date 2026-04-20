import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

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
    // Mock data: trunk incl. 42.1° vs tibia incl. 28.4° → diff +13.7° → HIP BIAS
    const trunkAngle = 42.1;
    const tibiaAngle = 28.4;
    const diff = trunkAngle - tibiaAngle; // +13.7° → hip dominant

    String biasLabel;
    String biasDesc;
    Color biasColor;
    if (diff > 10) {
      biasLabel = 'SESGO DE CADERA';
      biasDesc = 'Tu tronco se inclina ${diff.toStringAsFixed(1)}° más que la tibia.\nLa cadena posterior (glúteos) absorbe la mayor carga.';
      biasColor = colors.primary;
    } else if (diff < -10) {
      biasLabel = 'SESGO DE RODILLA';
      biasDesc = 'La tibia avanza ${(-diff).toStringAsFixed(1)}° más que el tronco.\nEl cuádriceps soporta la mayor demanda articular.';
      biasColor = const Color(0xFF007BFF);
    } else {
      biasLabel = 'NEUTRAL';
      biasDesc = 'Diferencia de ${diff.toStringAsFixed(1)}°. Distribución equilibrada\nentre extensores de cadera y rodilla (ratio ≈ 1.0).';
      biasColor = const Color(0xFFFFB627);
    }

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
                  flex: 65,
                  child: Container(height: 8, color: colors.primary),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: 35,
                  child: Container(height: 8, color: const Color(0xFF007BFF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Glúteo · Isquio  65%', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: colors.primary)),
              Text('Cuádriceps  35%', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF007BFF))),
            ],
          ),
        ],
      ),
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

    // Mock kinematic data: angle vs % of squat cycle
    final hipData = [
      const FlSpot(0, 5), const FlSpot(10, 20), const FlSpot(20, 42),
      const FlSpot(30, 65), const FlSpot(40, 82), const FlSpot(50, 92),  // max depth
      const FlSpot(60, 80), const FlSpot(70, 55), const FlSpot(80, 30),
      const FlSpot(90, 12), const FlSpot(100, 5),
    ];
    final kneeData = [
      const FlSpot(0, 8), const FlSpot(10, 28), const FlSpot(20, 55),
      const FlSpot(30, 78), const FlSpot(40, 100), const FlSpot(50, 119),
      const FlSpot(60, 105), const FlSpot(70, 72), const FlSpot(80, 40),
      const FlSpot(90, 18), const FlSpot(100, 8),
    ];
    final ankleData = [
      const FlSpot(0, 2), const FlSpot(10, 6), const FlSpot(20, 12),
      const FlSpot(30, 18), const FlSpot(40, 24), const FlSpot(50, 28),
      const FlSpot(60, 25), const FlSpot(70, 18), const FlSpot(80, 10),
      const FlSpot(90, 5), const FlSpot(100, 2),
    ];

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
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
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 30,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        String label;
                        switch (value.toInt()) {
                          case 0: label = 'INICIO'; break;
                          case 50: label = 'FONDO'; break;
                          case 100: label = 'FIN'; break;
                          default: label = '${value.toInt()}%';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(label, style: GoogleFonts.inter(fontSize: 8, color: Colors.white30, fontWeight: FontWeight.w500)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 30,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}°',
                        style: GoogleFonts.inter(fontSize: 9, color: Colors.white30),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: 100,
                minY: 0, maxY: 130,
                lineBarsData: [
                  _buildLine(hipData, colors.primary),
                  _buildLine(kneeData, const Color(0xFF007BFF)),
                  _buildLine(ankleData, const Color(0xFFFFB627)),
                ],
                // Phase annotation: bottom marker
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    VerticalLine(
                      x: 50,
                      color: Colors.white.withValues(alpha: 0.15),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                      label: VerticalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: GoogleFonts.inter(fontSize: 8, color: Colors.white30),
                        labelResolver: (_) => 'Máx. Flexión',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

    // Mock clinical loads (N/kg body weight) from research
    // ACL Shear ~450N, PCL Shear ~800N, Patellofemoral ~4200N, Lumbar Axial ~7200N
    // Normalized to max for chart
    final loads = [
      {'label': 'LCA\nCizalla', 'value': 450.0, 'max': 2000.0, 'color': colors.primary, 'unit': '450 N'},
      {'label': 'LCP\nCizalla', 'value': 800.0, 'max': 4000.0, 'color': const Color(0xFF007BFF), 'unit': '800 N'},
      {'label': 'Rótula\nCompresión', 'value': 4200.0, 'max': 5000.0, 'color': colors.tertiary, 'unit': '4.2 kN'},
      {'label': 'Lumbar\nAxial', 'value': 7200.0, 'max': 8000.0, 'color': const Color(0xFF8B5CF6), 'unit': '7.2 kN'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning header if any load approaches tissue limit
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.tertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.monitor_heart_outlined, color: colors.tertiary, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Compresión rotuliana en zona de atención (84% del umbral)',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: colors.tertiary),
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
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white54),
                      ),
                      Row(
                        children: [
                          Text(
                            d['unit'] as String,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isHigh ? color : Colors.white),
                          ),
                          if (isHigh) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.warning_amber_rounded, size: 12, color: color),
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
                      style: GoogleFonts.inter(fontSize: 8, color: Colors.white24),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
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

    // Mock VBT data: MPV per rep (m/s)
    // Rep 1 = 0.82, progresando hasta fatiga en Rep 8
    final mpvData = [
      const FlSpot(1, 0.82), const FlSpot(2, 0.78), const FlSpot(3, 0.74),
      const FlSpot(4, 0.70), const FlSpot(5, 0.65), const FlSpot(6, 0.61),
      const FlSpot(7, 0.57), const FlSpot(8, 0.52),
    ];

    // Velocity loss threshold at 30% = 0.82 * 0.70 = 0.574
    const lossThreshold = 0.574;
    // Rep where it crosses = Rep 7 (0.57 ≈ threshold)
    const dropOffPct = 36.6; // (0.82 - 0.52) / 0.82 * 100

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
                  Text('8', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
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
                  '⚡ -$dropOffPct% DROP-OFF',
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
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('R${value.toInt()}', style: GoogleFonts.inter(fontSize: 9, color: Colors.white30)),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: 0.1,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toStringAsFixed(1)}',
                        style: GoogleFonts.inter(fontSize: 9, color: Colors.white30),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 1, maxX: 8,
                minY: 0.4, maxY: 0.95,
                lineBarsData: [
                  LineChartBarData(
                    spots: mpvData,
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

          // Recommendation
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
                    'Cortar serie en Rep 7. Fatiga neuromuscular excede el umbral de resistencia segura.',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: colors.tertiary, height: 1.4),
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
