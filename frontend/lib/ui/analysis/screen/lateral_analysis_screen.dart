import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../services/biomech_frame_bus.dart';
import '../../../services/app_assets_manager.dart';
import '../../../domain/biomech_frame_realtime.dart';
import '../../../domain/bio_idx.dart';
import '../config/biomech_colors.dart';
import '../coordinator/analysis_playback_controller.dart';
import '../coordinator/analysis_scroll_controller.dart';
import '../coordinator/analysis_sync_engine.dart';
import '../stage/biomech_stage.dart';
import '../stage/floating_header.dart';
import '../timeline/phase_timeline.dart';
import '../timeline/sticky_timeline_delegate.dart';
import '../tabs/sticky_tab_delegate.dart';
import '../metrics/rom_summary.dart';
import '../metrics/angle_gauges.dart';


// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA LATERAL
// Métricas válidas desde la vista lateral (plano sagital):
//   ✅ Ángulo de tronco (trunk angle)         ✅ Flexión de cadera
//   ✅ Flexión de rodilla                     ✅ Ángulo de tibia/espinilla
//   ✅ Cohesión tibia-tronco                  ✅ Trayectoria de barra
//   ✅ Proyección del Centro de Masa (CoM)    ✅ Hip Drive Ratio
//   ✅ Gráficas temporales de ángulos sagitales
//   ❌ Valgo de rodilla (plano frontal, invisible desde lateral)
//   ❌ Simetría bilateral (requiere vista frontal)
// ─────────────────────────────────────────────────────────────────────────────

class LateralAnalysisScreen extends StatefulWidget {
  final String? videoPath;
  final String? csvPath;
  final String exerciseName;
  final String viewTag;
  final String captureDate;
  
  const LateralAnalysisScreen({
    super.key,
    this.videoPath,
    this.csvPath,
    required this.exerciseName,
    required this.viewTag,
    required this.captureDate,
  });

  @override
  State<LateralAnalysisScreen> createState() => _LateralAnalysisScreenState();
}

class _LateralAnalysisScreenState extends State<LateralAnalysisScreen> with TickerProviderStateMixin {
  late final AnalysisPlaybackController playback;
  late final AnalysisScrollController scroll;
  late final AnalysisSyncEngine syncEngine;
  late final TabController tabController;
  
  final _bus = BiomechFrameBus.instance;
  bool _nativeEngineReady = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    playback = AnalysisPlaybackController();
    scroll = AnalysisScrollController();
    scroll.init();
    
    syncEngine = AnalysisSyncEngine(
      vsync: this,
      playback: playback,
      bus: _bus,
    );
    
    _resolvePathsAndInit();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _resolvePathsAndInit() async {
    final csvFile = widget.csvPath ?? 'lateral_lstrack.csv';
    final videoFile = widget.videoPath ?? 'lateral_lstrack.mp4';
    
    final resolvedCsvPath = await AppAssetsManager.instance.resolveFilePath(csvFile);
    final resolvedVideoPath = await AppAssetsManager.instance.resolveFilePath(videoFile);

    if (resolvedVideoPath == null) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    final foundVideoFile = File(resolvedVideoPath);

    try {
      await playback.initFromFile(foundVideoFile);
      
      if (resolvedCsvPath != null) {
        final vpSize = playback.videoController!.value.size;
        await _bus.startWorker(
          resolvedCsvPath,
          vpSize.width > 0 ? vpSize.width : 1080.0,
          vpSize.height > 0 ? vpSize.height : 1920.0,
        );
        if (mounted) setState(() => _nativeEngineReady = true);
      }

      if (mounted) {
        final durationMs = playback.videoController!.value.duration.inMilliseconds;
        _bus.initDefaultSegments(durationMs);
        
        playback.play();
        syncEngine.start();
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error init lateral video Analysis: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    syncEngine.dispose();
    scroll.dispose();
    playback.dispose();
    tabController.dispose();
    _bus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Error cargando video o CSV', style: TextStyle(color: Colors.white54))));
    
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    final videoAspectRatio = playback.isInitialized
        ? playback.videoController!.value.aspectRatio
        : 16 / 9;
    final expandedHeight = size.width / videoAspectRatio;
    final appBarExpandedHeight = expandedHeight - 24;
    final collapsedHeight = (size.height * 0.38).clamp(kToolbarHeight + 40, appBarExpandedHeight - 40);

    scroll.updateMaxScroll(appBarExpandedHeight - collapsedHeight);

    return Scaffold(
      backgroundColor: BiomechColors.screenBackground,
      body: Stack(
        children: [
          NestedScrollView(
            controller: scroll.scrollController,
            physics: const ClampingScrollPhysics(),

            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: appBarExpandedHeight,
                  collapsedHeight: collapsedHeight,
                  pinned: true,
                  backgroundColor: BiomechColors.screenBackground,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: const FlexibleSpaceBar(
                    background: SizedBox.shrink(),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: SolidStickyTimelineDelegate(
                    height: 160,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 5,
                            margin: const EdgeInsets.only(top: 12, bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          RepaintBoundary(
                            child: PhaseTimeline(bus: _bus, playback: playback),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Ángulos sagitales en tiempo real (gauges válidos para lateral) ──
                SliverToBoxAdapter(
                  child: Container(
                    color: BiomechColors.background,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: AngleGauges(bus: _bus),
                  ),
                ),

                // ── Paneles de métricas sagitales ───────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: BiomechColors.background,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MÉTRICAS SAGITALES CLÍNICAS (VISTA LATERAL)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: BiomechColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TrunkMechanicsPanel(bus: _bus),
                        const SizedBox(height: 16),
                        
                        BarPathPanel(bus: _bus),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(child: COMPanel(bus: _bus)),
                            const SizedBox(width: 12),
                            Expanded(child: HipDrivePanel(bus: _bus)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPersistentHeader(
                  pinned: true,
                  delegate: SolidStickyTabBarDelegate(
                    PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: TabBar(
                        controller: tabController,
                        indicatorColor: colors.primary,
                        labelColor: colors.primary,
                        unselectedLabelColor: Colors.white38,
                        indicatorWeight: 3,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'CINEMÁTICA'),
                          Tab(text: 'PALANCAS'),
                          Tab(text: 'RANGOS (ROM)'),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: Container(
              color: BiomechColors.background,
              child: TabBarView(
                controller: tabController,
                children: [
                  _buildKinematicsTab(),
                  _buildLeversTab(),
                  _buildRomTab(colors),
                ],
              ),
            ),
          ),
          
          if (playback.isInitialized)
            BiomechStage(
              playback: playback,
              scroll: scroll,
              nativeEngineReady: _nativeEngineReady,
              expandedHeight: appBarExpandedHeight,
              collapsedHeight: collapsedHeight,
            ),

          // ── HUD de ángulos sagitales flotante sobre el video ───────────────
          if (playback.isInitialized)
            _LateralLiveHud(
              playback: playback,
              scroll: scroll,
              bus: _bus,
              expandedHeight: appBarExpandedHeight,
            ),
            
          FloatingHeader(
            scroll: scroll,
            exerciseName: widget.exerciseName,
            viewTag: widget.viewTag,
            captureDate: widget.captureDate,
          ),

          if (playback.isInitialized)
            ValueListenableBuilder<double>(
              valueListenable: scroll.scrollProgress,
              builder: (context, progress, _) {
                final double opacity = (1.0 - progress * 4.0).clamp(0.0, 1.0);
                if (opacity <= 0.0) return const SizedBox.shrink();
                final double videoAspectRatio = playback.videoController?.value.aspectRatio ?? (1080 / 1920);
                final double expandedHeightVal = MediaQuery.of(context).size.width / videoAspectRatio;
                final double topOffset = (expandedHeightVal - 110) + (progress * 30);
                return Positioned(
                  top: topOffset,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: opacity,
                      child: _buildSpeedSelector(context),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedSelector(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: playback.speed,
      builder: (context, currentSpeed, _) {
        final isSlow = currentSpeed < 1.0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: GestureDetector(
              onTap: () {
                double nextSpeed = 1.0;
                if (currentSpeed == 1.0) {
                  nextSpeed = 0.5;
                } else if (currentSpeed == 0.5) {
                  nextSpeed = 0.25;
                } else if (currentSpeed == 0.25) {
                  nextSpeed = 0.1;
                }
                playback.setSpeed(nextSpeed);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSlow ? BiomechColors.optimal.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed_rounded, size: 15, color: isSlow ? BiomechColors.optimal : Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      '${currentSpeed}x',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: isSlow ? BiomechColors.optimal : Colors.white, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── TAB 1: Cinemática sagital con gráfica de ángulos reales ────────────
  Widget _buildKinematicsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _buildAnalysisCard(
          title: 'FLEXIÓN DE RODILLA MÁXIMA',
          value: '124.5°',
          desc: 'Profundidad excelente. La rodilla alcanza flexión completa, rompiendo el paralelo de forma limpia.',
          icon: Icons.check_circle_rounded,
          color: BiomechColors.optimal,
        ),
        const SizedBox(height: 16),
        _buildAnalysisCard(
          title: 'INCLINACIÓN MÁXIMA DEL TRONCO',
          value: '42.1°',
          desc: 'Control lumbar correcto. El tronco mantiene ángulo sagital seguro, reduciendo la carga de cizalla.',
          icon: Icons.check_circle_rounded,
          color: BiomechColors.optimal,
        ),
        const SizedBox(height: 16),
        // Gráfica real de ángulos sagitales (cadera, rodilla, tronco)
        _LateralAnglesChart(bus: _bus),
      ],
    );
  }

  // ─── TAB 2: Palancas mecánicas (barra vs punto de apoyo) ────────────────
  Widget _buildLeversTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _buildAnalysisCard(
          title: 'DISTANCIA BARRA A MEDIO-PIE',
          value: '2.8 cm (ÓPTIMO)',
          desc: 'La proyección de la barra se mantiene sobre el centro de presión del pie, garantizando eficiencia de palancas.',
          icon: Icons.check_circle_rounded,
          color: BiomechColors.optimal,
        ),
        const SizedBox(height: 16),
        BarPathPanel(bus: _bus),
        const SizedBox(height: 16),
        _TrunkAngleChart(bus: _bus),
      ],
    );
  }

  // ─── TAB 3: Rangos de movimiento (ROM) ──────────────────────────────────
  Widget _buildRomTab(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        RomSummary(colors: colors),
      ],
    );
  }

  Widget _buildAnalysisCard({
    required String title,
    required String value,
    required String desc,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BiomechColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.5))),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Text(desc, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70, height: 1.4)),
        ],
      ),
    );
  }
}

// ─── HUD Lateral: ángulos sagitales reales sobre el video ─────────────────
class _LateralLiveHud extends StatelessWidget {
  final AnalysisPlaybackController playback;
  final AnalysisScrollController scroll;
  final BiomechFrameBus bus;
  final double expandedHeight;

  const _LateralLiveHud({
    required this.playback,
    required this.scroll,
    required this.bus,
    required this.expandedHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: scroll.scrollProgress,
      builder: (context, progress, _) {
        final opacity = (1.0 - progress * 3.0).clamp(0.0, 1.0);
        if (opacity <= 0.0) return const SizedBox.shrink();

        return Positioned(
          top: expandedHeight - 76.0,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: opacity,
            child: ValueListenableBuilder<BiomechFrameRealtime>(
              valueListenable: bus.frameNotifier,
              builder: (context, frame, _) {
                if (frame.isEmpty) return const SizedBox.shrink();
                return _buildHud(frame);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHud(BiomechFrameRealtime frame) {
    // Solo ángulos válidos desde vista lateral (sagital)
    final trunk = frame.trunkAngle;
    final hip = frame.hipAngle;
    final knee = frame.kneeAngle;
    final tibia = frame.tibiaAngle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _HudAngle(label: 'TRONCO', value: trunk, color: const Color(0xFFFBBF24)),
                _HudDivider(),
                _HudAngle(label: 'CADERA', value: hip, color: BiomechColors.optimal),
                _HudDivider(),
                _HudAngle(label: 'RODILLA', value: knee, color: const Color(0xFF60A5FA)),
                _HudDivider(),
                _HudAngle(label: 'TIBIA', value: tibia, color: const Color(0xFFA78BFA)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HudDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.1));
}

class _HudAngle extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _HudAngle({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${value.toStringAsFixed(0)}°', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
        Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 0.8)),
      ],
    );
  }
}

// ─── Gráfica de ángulos sagitales en el tiempo ─────────────────────────────
class _LateralAnglesChart extends StatelessWidget {
  final BiomechFrameBus bus;
  const _LateralAnglesChart({required this.bus});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Float32List>>(
      valueListenable: bus.seriesNotifier,
      builder: (context, seriesList, _) {
        final hasData = seriesList.length >= 4;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BiomechColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ÁNGULOS SAGITALES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0)),
                  Row(
                    children: [
                      _LegendDot(color: BiomechColors.optimal, label: 'Cadera'),
                      const SizedBox(width: 8),
                      _LegendDot(color: const Color(0xFF60A5FA), label: 'Rodilla'),
                      const SizedBox(width: 8),
                      _LegendDot(color: const Color(0xFFFBBF24), label: 'Tronco'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 150,
                child: hasData
                    ? LineChart(_buildChart(seriesList))
                    : Center(child: Text('PROCESANDO...', style: GoogleFonts.inter(fontSize: 10, color: Colors.white24))),
              ),
            ],
          ),
        );
      },
    );
  }

  LineChartData _buildChart(List<Float32List> seriesList) {
    final hip = seriesList[0];
    final knee = seriesList[1];
    final trunk = seriesList[3];

    final int step = math.max(1, hip.length ~/ 80);

    List<FlSpot> hipSpots = [], kneeSpots = [], trunkSpots = [];
    for (int i = 0; i < hip.length; i += step) {
      hipSpots.add(FlSpot(i.toDouble(), hip[i].clamp(0, 180).toDouble()));
    }
    for (int i = 0; i < knee.length; i += step) {
      kneeSpots.add(FlSpot(i.toDouble(), knee[i].clamp(0, 180).toDouble()));
    }
    for (int i = 0; i < trunk.length; i += step) {
      trunkSpots.add(FlSpot(i.toDouble(), trunk[i].clamp(0, 90).toDouble()));
    }

    return LineChartData(
      backgroundColor: Colors.transparent,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withValues(alpha: 0.04), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (val, _) => Text('${val.toInt()}°', style: GoogleFonts.inter(fontSize: 8, color: Colors.white24)),
          ),
        ),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: 185,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1E1E20),
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
            '${s.y.toStringAsFixed(0)}°',
            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: s.bar.color ?? Colors.white),
          )).toList(),
        ),
      ),
      lineBarsData: [
        _line(hipSpots, BiomechColors.optimal),
        _line(kneeSpots, const Color(0xFF60A5FA)),
        _line(trunkSpots, const Color(0xFFFBBF24)),
      ],
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots,
    color: color,
    barWidth: 1.5,
    isCurved: true,
    curveSmoothness: 0.3,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.04)),
  );
}

// ─── Gráfica de ángulo de tronco (única variable de palanca) ──────────────
class _TrunkAngleChart extends StatelessWidget {
  final BiomechFrameBus bus;
  const _TrunkAngleChart({required this.bus});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: bus.frameNotifier,
      builder: (context, frame, _) {
        if (frame.isEmpty) return const SizedBox.shrink();
        final trunk = frame.trunkAngle;
        final isOptimal = trunk < 50.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BiomechColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INCLINACIÓN ACTUAL', style: GoogleFonts.inter(fontSize: 9, color: Colors.white38, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text('${trunk.toStringAsFixed(1)}°', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: isOptimal ? BiomechColors.optimal : BiomechColors.warning)),
                    Text(isOptimal ? 'TRONCO ERGUIDO' : 'EXCESO DE INCLINACIÓN', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: isOptimal ? BiomechColors.optimal : BiomechColors.warning)),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(painter: _TrunkGaugePainter(angle: trunk)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrunkGaugePainter extends CustomPainter {
  final double angle;
  const _TrunkGaugePainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;
    final fraction = (angle / 90.0).clamp(0.0, 1.0);
    final color = angle < 50 ? BiomechColors.optimal : BiomechColors.warning;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false,
      Paint()..color = Colors.white.withValues(alpha: 0.07)..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle * fraction, false,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrunkGaugePainter old) => old.angle != angle;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
      ],
    );
  }
}

// ─── WIDGET 1: TrunkMechanicsPanel ────────────────────────────────────────
class TrunkMechanicsPanel extends StatelessWidget {
  final BiomechFrameBus bus;
  const TrunkMechanicsPanel({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: bus.frameNotifier,
      builder: (context, frame, _) {
        if (frame.isEmpty) return const SizedBox.shrink();
        final double trunk = frame.trunkAngle;
        final double shin = frame.tibiaAngle;
        final double diff = (trunk - shin).abs();
        final double cohesion = (100.0 - diff * 1.5).clamp(0.0, 100.0);
        final bool isGood = cohesion > 80.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BiomechColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MECÁNICA DE TRONCO Y ESPINILLA (SAGITTAL COHESION)',
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ÁNGULO TRONCO', style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
                    Text('${trunk.toStringAsFixed(0)}°', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Text('COHESIÓN TIBIA-TRONCO', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white38)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isGood ? BiomechColors.optimal.withValues(alpha: 0.2) : BiomechColors.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${cohesion.toStringAsFixed(0)}%',
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: isGood ? BiomechColors.optimal : BiomechColors.warning)),
                    ),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('ÁNGULO TIBIA', style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
                    Text('${shin.toStringAsFixed(0)}°', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── WIDGET 2: BarPathPanel ────────────────────────────────────────────────
class BarPathPanel extends StatelessWidget {
  final BiomechFrameBus bus;
  const BarPathPanel({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: bus.frameNotifier,
      builder: (context, frame, _) {
        if (frame.isEmpty) return const SizedBox.shrink();
        final double barMidfoot = frame.hipBias.clamp(-8.0, 8.0);
        final bool isWarning = barMidfoot.abs() > 4.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BiomechColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DESVIACIÓN TRAYECTORIA DE BARRA A MEDIO-PIE',
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${barMidfoot.abs().toStringAsFixed(1)} cm',
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: isWarning ? BiomechColors.warning : BiomechColors.optimal)),
                  Text(isWarning ? '⚠ DERIVA DELANTERA' : 'TRAYECTORIA ESTABLE',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: isWarning ? BiomechColors.warning : BiomechColors.optimal)),
                ],
              ),
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
                  const Positioned(child: SizedBox(width: 2, height: 10, child: ColoredBox(color: Color(0x4DFFFFFF)))),
                  Align(
                    alignment: Alignment((barMidfoot / 8.0).clamp(-1.0, 1.0), 0.0),
                    child: Container(width: 12, height: 12, decoration: BoxDecoration(color: isWarning ? BiomechColors.warning : BiomechColors.optimal, shape: BoxShape.circle)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── WIDGET 3: COMPanel ───────────────────────────────────────────────────
class COMPanel extends StatelessWidget {
  final BiomechFrameBus bus;
  const COMPanel({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: bus.frameNotifier,
      builder: (context, frame, _) {
        if (frame.isEmpty) return const SizedBox.shrink();
        final double comX = frame.comX;
        final double lAnkleX = frame.skeletonBuffer[BioIdx.lAnkle * 3];
        final double comDrift = ((comX - lAnkleX) * 0.1).clamp(-10.0, 10.0);
        final bool isBalanced = comDrift.abs() < 4.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BiomechColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PROYECCIÓN CoM', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Text('${comDrift.abs().toStringAsFixed(1)} mm',
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: isBalanced ? BiomechColors.optimal : BiomechColors.warning)),
              Text(isBalanced ? 'CENTRO APOYO' : 'DESCOMPENSADO',
                  style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: isBalanced ? BiomechColors.optimal : BiomechColors.warning)),
            ],
          ),
        );
      },
    );
  }
}

// ─── WIDGET 4: HipDrivePanel ──────────────────────────────────────────────
class HipDrivePanel extends StatelessWidget {
  final BiomechFrameBus bus;
  const HipDrivePanel({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: bus.frameNotifier,
      builder: (context, frame, _) {
        if (frame.isEmpty) return const SizedBox.shrink();
        final double hip = frame.hipAngle;
        final double knee = frame.kneeAngle;
        final double driveRatio = knee > 0 ? (hip / knee) : 1.0;
        final bool isHinge = driveRatio > 1.15;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BiomechColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HIP DRIVE RATIO', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Text(driveRatio.toStringAsFixed(2), style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(isHinge ? 'DOMINANCIA CADERA' : 'EMPUJE BALANCEADO',
                  style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold,
                      color: isHinge ? const Color(0xFF8B5CF6) : BiomechColors.optimal)),
            ],
          ),
        );
      },
    );
  }
}
