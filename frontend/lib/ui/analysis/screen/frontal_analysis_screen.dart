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

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA FRONTAL
// Métricas válidas desde la vista frontal (plano coronal):
//   ✅ Valgo de rodilla L/R (desviación X de rodilla vs tobillo)
//   ✅ Inclinación de hombros (shoulder tilt) — eje X
//   ✅ Inclinación pélvica / cadera (hip tilt) — eje X
//   ✅ Balance lateral (bias de cadera de lado a lado)
//   ✅ Ancho de stance (distancia relativa entre pies vs hombros)
//   ✅ Simetría de movimiento bilateral (comparación L/R en el tiempo)
//   ❌ Flexión de cadera/rodilla/tobillo (ángulos sagitales — requiere vista lateral)
//   ❌ Ángulo de tronco sagital (invisible desde el frente)
//   ❌ Trayectoria de barra (solo visible en lateral)
//   ❌ CoM sagital / Hip Drive Ratio (requieren perfil lateral)
// ─────────────────────────────────────────────────────────────────────────────

class FrontalAnalysisScreen extends StatefulWidget {
  final String? videoPath;
  final String? csvPath;
  final String exerciseName;
  final String viewTag;
  final String captureDate;
  
  const FrontalAnalysisScreen({
    super.key,
    this.videoPath,
    this.csvPath,
    required this.exerciseName,
    required this.viewTag,
    required this.captureDate,
  });

  @override
  State<FrontalAnalysisScreen> createState() => _FrontalAnalysisScreenState();
}

class _FrontalAnalysisScreenState extends State<FrontalAnalysisScreen> with TickerProviderStateMixin {
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
    final csvFile = widget.csvPath ?? 'frontal_lstrack.csv';
    final videoFile = widget.videoPath ?? 'frontal_lstrack.mp4';
    
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
      debugPrint('Error init frontal video Analysis: $e');
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

                // ── Gauges coronales en tiempo real ─────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: BiomechColors.background,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: FrontalAngleGauges(bus: _bus),
                  ),
                ),

                // ── Paneles de simetría y estabilidad frontal ────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: BiomechColors.background,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ANÁLISIS FRONTAL — SIMETRÍA Y ESTABILIDAD CORONAL',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: BiomechColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        FrontalValgusPanel(bus: _bus),
                        const SizedBox(height: 16),
                        
                        FrontalSymmetryPanel(bus: _bus),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(child: FrontalBalancePanel(bus: _bus)),
                            const SizedBox(width: 12),
                            Expanded(child: FrontalStancePanel(bus: _bus)),
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
                          Tab(text: 'SIMETRÍA'),
                          Tab(text: 'RODILLA'),
                          Tab(text: 'STANCE'),
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
                  _buildSymmetryTab(),
                  _buildKneeTab(),
                  _buildStanceTab(),
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

          // ── HUD frontal: solo indica simetría e inclinaciones ──────────
          if (playback.isInitialized)
            _FrontalLiveHud(
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
                    Text('${currentSpeed}x', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: isSlow ? BiomechColors.optimal : Colors.white, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── TAB 1: Simetría bilateral en el tiempo ──────────────────────────────
  Widget _buildSymmetryTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _buildAnalysisCard(
          title: 'INCLINACIÓN LATERAL DE HOMBROS',
          value: '0.8°',
          desc: 'Alineación de hombros simétrica. No hay traslación lateral significativa.',
          icon: Icons.check_circle_rounded,
          color: BiomechColors.optimal,
        ),
        const SizedBox(height: 16),
        _buildAnalysisCard(
          title: 'INCLINACIÓN PÉLVICA (HIP TILT)',
          value: '1.2°',
          desc: 'Ligera inclinación pélvica al inicio del ascenso. Empuja con igual fuerza en ambos pies.',
          icon: Icons.info_outline,
          color: BiomechColors.warning,
        ),
        const SizedBox(height: 16),
        // Gráfica de simetría bilateral en tiempo real
        _FrontalSymmetryChart(bus: _bus),
      ],
    );
  }

  // ─── TAB 2: Valgo de rodilla bilateral ──────────────────────────────────
  Widget _buildKneeTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _buildAnalysisCard(
          title: 'VALGO RODILLA IZQUIERDA',
          value: '2.1° (ÓPTIMO)',
          desc: 'La rodilla izquierda mantiene alineación sobre el segundo metatarso durante el descenso.',
          icon: Icons.check_circle_rounded,
          color: BiomechColors.optimal,
        ),
        const SizedBox(height: 16),
        _buildAnalysisCard(
          title: 'VALGO RODILLA DERECHA',
          value: '5.8° (ATENCIÓN)',
          desc: 'Colapso en valgo leve al iniciar la fase concéntrica. Fortalecer glúteo medio.',
          icon: Icons.warning_amber_rounded,
          color: BiomechColors.warning,
        ),
        const SizedBox(height: 16),
        FrontalValgusPanel(bus: _bus),
      ],
    );
  }

  // ─── TAB 3: Stance y balance ─────────────────────────────────────────────
  Widget _buildStanceTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        FrontalBalancePanel(bus: _bus),
        const SizedBox(height: 16),
        FrontalStancePanel(bus: _bus),
        const SizedBox(height: 16),
        _buildAnalysisCard(
          title: 'ANCHO DE STANCE RELATIVO',
          value: '1.18× ancho hombros',
          desc: 'Stance moderadamente ancho — ideal para sentadilla profunda. Promueve mayor activación glútea.',
          icon: Icons.check_circle_rounded,
          color: BiomechColors.optimal,
        ),
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

// ─── Métricas frontales en tiempo real (4 indicadores coronales) ──────────
// ─── Gauges coronales (estilo idéntico a AngleGauges de lateral) ─────────
// Métricas válidas desde el plano frontal: valgo L, valgo R, hombros, pelvis
class FrontalAngleGauges extends StatefulWidget {
  final BiomechFrameBus bus;
  const FrontalAngleGauges({super.key, required this.bus});

  @override
  State<FrontalAngleGauges> createState() => _FrontalAngleGaugesState();
}

class _FrontalAngleGaugesState extends State<FrontalAngleGauges> {
  // Modelos de gauge actualizados por listener
  _CoronalGaugeModel _valgoL = _CoronalGaugeModel.zero('VALGO IZQ.', 6.0, 15.0);
  _CoronalGaugeModel _valgoR = _CoronalGaugeModel.zero('VALGO DER.', 6.0, 15.0);
  _CoronalGaugeModel _shoulder = _CoronalGaugeModel.zero('HOMBROS', 2.5, 10.0);
  _CoronalGaugeModel _pelvis = _CoronalGaugeModel.zero('PELVIS', 2.5, 10.0);

  @override
  void initState() {
    super.initState();
    widget.bus.frameNotifier.addListener(_onFrame);
  }

  @override
  void dispose() {
    widget.bus.frameNotifier.removeListener(_onFrame);
    super.dispose();
  }

  void _onFrame() {
    final frame = widget.bus.frameNotifier.value;
    if (frame.isEmpty) return;
    final buf = frame.skeletonBuffer;

    final lKneeX = buf[BioIdx.lKnee * 3];
    final lAnkleX = buf[BioIdx.lAnkle * 3];
    final rKneeX = buf[BioIdx.rKnee * 3];
    final rAnkleX = buf[BioIdx.rAnkle * 3];
    final vl = ((lKneeX - lAnkleX) * 0.08).abs().clamp(0.0, 15.0);
    final vr = ((rAnkleX - rKneeX) * 0.08).abs().clamp(0.0, 15.0);

    final sh = (math.atan2(
      buf[BioIdx.rShoulder * 3 + 1] - buf[BioIdx.lShoulder * 3 + 1],
      buf[BioIdx.rShoulder * 3] - buf[BioIdx.lShoulder * 3],
    ) * 180 / math.pi).abs().clamp(0.0, 10.0);

    final hp = (math.atan2(
      buf[BioIdx.rHip * 3 + 1] - buf[BioIdx.lHip * 3 + 1],
      buf[BioIdx.rHip * 3] - buf[BioIdx.lHip * 3],
    ) * 180 / math.pi).abs().clamp(0.0, 10.0);

    setState(() {
      _valgoL = _CoronalGaugeModel('VALGO IZQ.', vl, 6.0, 15.0);
      _valgoR = _CoronalGaugeModel('VALGO DER.', vr, 6.0, 15.0);
      _shoulder = _CoronalGaugeModel('HOMBROS', sh, 2.5, 10.0);
      _pelvis = _CoronalGaugeModel('PELVIS', hp, 2.5, 10.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gaugeSize = (MediaQuery.of(context).size.width - 40 - 24) / 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MÉTRICAS CORONALES EN TIEMPO REAL',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: BiomechColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CoronalGauge(model: _valgoL, size: gaugeSize),
            _CoronalGauge(model: _valgoR, size: gaugeSize),
            _CoronalGauge(model: _shoulder, size: gaugeSize),
            _CoronalGauge(model: _pelvis, size: gaugeSize),
          ],
        ),
      ],
    );
  }
}

// Modelo inmutable para un gauge coronal
class _CoronalGaugeModel {
  final String label;
  final double value;      // valor actual (ej. 3.2°)
  final double warnThreshold; // umbral de advertencia
  final double maxRange;   // máximo del rango
  const _CoronalGaugeModel(this.label, this.value, this.warnThreshold, this.maxRange);
  factory _CoronalGaugeModel.zero(String label, double warn, double max) =>
      _CoronalGaugeModel(label, 0.0, warn, max);
}

// Gauge circular usando el mismo GaugePainter de angle_gauges.dart
class _CoronalGauge extends StatelessWidget {
  final _CoronalGaugeModel model;
  final double size;
  const _CoronalGauge({required this.model, required this.size});

  @override
  Widget build(BuildContext context) {
    // El gauge está centrado en 0° (óptimo = 0°, rango ± maxRange)
    // Reutilizamos GaugePainter importado de angle_gauges.dart
    final isWarn = model.value > model.warnThreshold;
    final color = isWarn ? BiomechColors.warning : BiomechColors.optimal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: BiomechColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _CoronalGaugePainter(
                  value: model.value,
                  maxRange: model.maxRange,
                  warnThreshold: model.warnThreshold,
                  color: color,
                ),
              ),
              Positioned(
                bottom: size * 0.25,
                child: Text(
                  '${model.value.toStringAsFixed(1)}°',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                    shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: size,
          child: Text(
            model.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: BiomechColors.textSecondary, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }
}

// Painter circular para métricas coronales (lower-is-better: 0° = centro = óptimo)
class _CoronalGaugePainter extends CustomPainter {
  final double value;
  final double maxRange;
  final double warnThreshold;
  final Color color;

  const _CoronalGaugePainter({
    required this.value,
    required this.maxRange,
    required this.warnThreshold,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    const startAngle = 5 * math.pi / 6;   // 150°
    const sweepTotal = 4 * math.pi / 3;   // 240°
    const centerAngle = startAngle + sweepTotal / 2; // centro = 0° (óptimo)

    // fraction: 0 = sin desviación (izq del arco), 1 = desviación máxima (der)
    final fraction = (value / maxRange).clamp(0.0, 1.0);
    final needleAngle = centerAngle + (sweepTotal / 2) * fraction; // needle va del centro hacia la derecha

    // Arco de fondo
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepTotal, false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Marca zona óptima (de inicio hasta el umbral)
    final warnFrac = warnThreshold / maxRange;
    final warnSweep = (sweepTotal / 2) * warnFrac;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      centerAngle, warnSweep, false,
      Paint()
        ..color = BiomechColors.optimal.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Arco de valor actual (desde el centro)
    final valueSweep = (sweepTotal / 2) * fraction;
    if (valueSweep > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        centerAngle, valueSweep, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }

    // Marca central (0°)
    final cx = center.dx + (radius + 4) * math.cos(centerAngle);
    final cy = center.dy + (radius + 4) * math.sin(centerAngle);
    final cx2 = center.dx + (radius - 8) * math.cos(centerAngle);
    final cy2 = center.dy + (radius - 8) * math.sin(centerAngle);
    canvas.drawLine(Offset(cx2, cy2), Offset(cx, cy),
        Paint()..color = Colors.white.withValues(alpha: 0.25)..strokeWidth = 1.5..strokeCap = StrokeCap.round);

    // Aguja
    final needleLength = radius - 8;
    final needleEnd = Offset(center.dx + needleLength * math.cos(needleAngle), center.dy + needleLength * math.sin(needleAngle));
    final needleStart = Offset(center.dx + 10 * math.cos(needleAngle), center.dy + 10 * math.sin(needleAngle));
    canvas.drawLine(needleStart, needleEnd, Paint()..color = color..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    canvas.drawCircle(needleEnd, 3.5, Paint()..color = color);
    canvas.drawCircle(center, 2.5, Paint()..color = Colors.white.withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(covariant _CoronalGaugePainter old) =>
      old.value != value || old.color != color;
}



// ─── HUD frontal flotante sobre el video ─────────────────────────────────
class _FrontalLiveHud extends StatelessWidget {
  final AnalysisPlaybackController playback;
  final AnalysisScrollController scroll;
  final BiomechFrameBus bus;
  final double expandedHeight;

  const _FrontalLiveHud({
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
    final buf = frame.skeletonBuffer;
    // Solo variables del eje X (coronales)
    final lKneeX = buf[BioIdx.lKnee * 3];
    final lAnkleX = buf[BioIdx.lAnkle * 3];
    final rKneeX = buf[BioIdx.rKnee * 3];
    final rAnkleX = buf[BioIdx.rAnkle * 3];
    final valgoL = ((lKneeX - lAnkleX) * 0.08).clamp(0.0, 15.0);
    final valgoR = ((rAnkleX - rKneeX) * 0.08).clamp(0.0, 15.0);

    final lShX = buf[BioIdx.lShoulder * 3];
    final lShY = buf[BioIdx.lShoulder * 3 + 1];
    final rShX = buf[BioIdx.rShoulder * 3];
    final rShY = buf[BioIdx.rShoulder * 3 + 1];
    final shTilt = (math.atan2(rShY - lShY, rShX - lShX) * 180 / math.pi).abs().clamp(0.0, 10.0);

    final lHipX = buf[BioIdx.lHip * 3];
    final lHipY = buf[BioIdx.lHip * 3 + 1];
    final rHipX = buf[BioIdx.rHip * 3];
    final rHipY = buf[BioIdx.rHip * 3 + 1];
    final hipTilt = (math.atan2(rHipY - lHipY, rHipX - lHipX) * 180 / math.pi).abs().clamp(0.0, 10.0);

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
                _HudItem(label: 'VALGO IZQ', value: '${valgoL.toStringAsFixed(1)}°', color: valgoL > 6 ? BiomechColors.warning : BiomechColors.optimal),
                _HudDivider(),
                _HudItem(label: 'VALGO DER', value: '${valgoR.toStringAsFixed(1)}°', color: valgoR > 6 ? BiomechColors.warning : BiomechColors.optimal),
                _HudDivider(),
                _HudItem(label: 'HOMBROS', value: '${shTilt.toStringAsFixed(1)}°', color: shTilt > 2.5 ? BiomechColors.warning : Colors.white70),
                _HudDivider(),
                _HudItem(label: 'PELVIS', value: '${hipTilt.toStringAsFixed(1)}°', color: hipTilt > 2.5 ? BiomechColors.warning : Colors.white70),
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

class _HudItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _HudItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
        Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 0.8)),
      ],
    );
  }
}

// ─── Gráfica de simetría bilateral en el tiempo ───────────────────────────
// Traza el delta L-R de rodilla en cada frame (indica asimetría de movimiento)
class _FrontalSymmetryChart extends StatelessWidget {
  final BiomechFrameBus bus;
  const _FrontalSymmetryChart({required this.bus});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Float32List>>(
      valueListenable: bus.seriesNotifier,
      builder: (context, seriesList, _) {
        // Frontal view: usamos la serie de cadera (index 0) como proxy de simetría
        // Las series del CSV vienen del motor que ya conoce la vista.
        // Para frontal, el motor exporta métricas de eje coronal, no sagital.
        final hasData = seriesList.isNotEmpty;

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
                  Text('DELTA DE SIMETRÍA BILATERAL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('L vs R', style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Asimetría entre rodilla izquierda y derecha a lo largo de la repetición.',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white30, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: hasData
                    ? LineChart(_buildChart(seriesList))
                    : Center(child: Text('PROCESANDO SIMETRÍA...', style: GoogleFonts.inter(fontSize: 10, color: Colors.white24))),
              ),
            ],
          ),
        );
      },
    );
  }

  LineChartData _buildChart(List<Float32List> seriesList) {
    // Para la vista frontal, si hay dos series, son L y R
    // Calcular el delta como señal de simetría
    final a = seriesList[0];
    final b = seriesList.length > 1 ? seriesList[1] : seriesList[0];
    final len = math.min(a.length, b.length);
    final step = math.max(1, len ~/ 80);

    final deltaSpots = <FlSpot>[];
    for (int i = 0; i < len; i += step) {
      final delta = (a[i] - b[i]).abs().clamp(0.0, 20.0);
      deltaSpots.add(FlSpot(i.toDouble(), delta.toDouble()));
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
            getTitlesWidget: (val, _) => Text('${val.toInt()}', style: GoogleFonts.inter(fontSize: 8, color: Colors.white24)),
          ),
        ),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: 20,
      // Zona óptima (delta < 3) en verde
      rangeAnnotations: RangeAnnotations(
        horizontalRangeAnnotations: [
          HorizontalRangeAnnotation(y1: 0, y2: 3, color: BiomechColors.optimal.withValues(alpha: 0.06)),
        ],
      ),
      lineBarsData: [
        LineChartBarData(
          spots: deltaSpots,
          color: BiomechColors.optimal,
          barWidth: 2,
          isCurved: true,
          curveSmoothness: 0.4,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: BiomechColors.optimal.withValues(alpha: 0.06)),
        ),
      ],
    );
  }
}

// ─── PANEL 1: Valgo bilateral ──────────────────────────────────────────────
class FrontalValgusPanel extends StatelessWidget {
  final BiomechFrameBus bus;
  const FrontalValgusPanel({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: bus.frameNotifier,
      builder: (context, frame, _) {
        if (frame.isEmpty) return const SizedBox.shrink();
        final double lKneeX = frame.skeletonBuffer[BioIdx.lKnee * 3];
        final double lAnkleX = frame.skeletonBuffer[BioIdx.lAnkle * 3];
        final double rKneeX = frame.skeletonBuffer[BioIdx.rKnee * 3];
        final double rAnkleX = frame.skeletonBuffer[BioIdx.rAnkle * 3];
        final double valgoL = ((lKneeX - lAnkleX) * 0.08).clamp(-15.0, 15.0);
        final double valgoR = ((rAnkleX - rKneeX) * 0.08).clamp(-15.0, 15.0);
        final bool warnL = valgoL.abs() > 6.0;
        final bool warnR = valgoR.abs() > 6.0;

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
              Text('VALGO COLAPSO DE RODILLA (KNEE VALGUS)',
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildValgusIndicator(label: 'IZQUIERDA', value: valgoL, isWarning: warnL)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildValgusIndicator(label: 'DERECHA', value: valgoR, isWarning: warnR)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildValgusIndicator({required String label, required double value, required bool isWarning}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white38)),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('${value.abs().toStringAsFixed(1)}°',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: isWarning ? BiomechColors.warning : BiomechColors.optimal)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isWarning ? BiomechColors.warning.withValues(alpha: 0.2) : BiomechColors.optimal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(isWarning ? 'VALGO' : 'ÓPTIMO',
                  style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: isWarning ? BiomechColors.warning : BiomechColors.optimal)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (value.abs() / 15.0).clamp(0.0, 1.0),
            minHeight: 4,
            color: isWarning ? BiomechColors.warning : BiomechColors.optimal,
            backgroundColor: Colors.white10,
          ),
        ),
      ],
    );
  }
}

// ─── PANEL 2: Simetría de hombros y pelvis ────────────────────────────────
class FrontalSymmetryPanel extends StatelessWidget {
  final BiomechFrameBus bus;
  const FrontalSymmetryPanel({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: bus.frameNotifier,
      builder: (context, frame, _) {
        if (frame.isEmpty) return const SizedBox.shrink();
        final buf = frame.skeletonBuffer;
        final shAngle = (math.atan2(
          buf[BioIdx.rShoulder * 3 + 1] - buf[BioIdx.lShoulder * 3 + 1],
          buf[BioIdx.rShoulder * 3] - buf[BioIdx.lShoulder * 3],
        ) * 180 / math.pi).clamp(-10.0, 10.0);
        final hipAngle = (math.atan2(
          buf[BioIdx.rHip * 3 + 1] - buf[BioIdx.lHip * 3 + 1],
          buf[BioIdx.rHip * 3] - buf[BioIdx.lHip * 3],
        ) * 180 / math.pi).clamp(-10.0, 10.0);
        final shWarn = shAngle.abs() > 2.5;
        final hipWarn = hipAngle.abs() > 2.5;

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
              Text('INCLINACIÓN LATERAL (SHOULDER & PELVIS TILT)',
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0)),
              const SizedBox(height: 16),
              _buildTiltRow('HOMBROS', shAngle, shWarn),
              const SizedBox(height: 14),
              _buildTiltRow('PELVIS / CADERA', hipAngle, hipWarn),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTiltRow(String label, double angle, bool warn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white38)),
            Text('${angle >= 0 ? '+' : ''}${angle.toStringAsFixed(1)}°',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: warn ? BiomechColors.warning : BiomechColors.optimal)),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
            const Positioned(child: SizedBox(width: 2, height: 10, child: ColoredBox(color: Color(0x4DFFFFFF)))),
            Align(
              alignment: Alignment((angle / 10.0).clamp(-1.0, 1.0), 0.0),
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: warn ? BiomechColors.warning : BiomechColors.optimal,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: (warn ? BiomechColors.warning : BiomechColors.optimal).withValues(alpha: 0.5), blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── PANEL 3: Balance lateral ─────────────────────────────────────────────
class FrontalBalancePanel extends StatelessWidget {
  final BiomechFrameBus bus;
  const FrontalBalancePanel({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: bus.frameNotifier,
      builder: (context, frame, _) {
        if (frame.isEmpty) return const SizedBox.shrink();
        final double hipBias = frame.hipBias.clamp(-15.0, 15.0);
        final double leftPct = (50.0 - hipBias * 1.5).clamp(20.0, 80.0);
        final double rightPct = 100.0 - leftPct;

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
              Text('BALANCE LATERAL', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${leftPct.toStringAsFixed(0)}% IZQ', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: BiomechColors.optimal)),
                  Text('${rightPct.toStringAsFixed(0)}% DER', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white38)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: leftPct / 100.0,
                  minHeight: 6,
                  color: BiomechColors.optimal,
                  backgroundColor: Colors.white10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── PANEL 4: Ancho de stance ─────────────────────────────────────────────
class FrontalStancePanel extends StatelessWidget {
  final BiomechFrameBus bus;
  const FrontalStancePanel({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BiomechFrameRealtime>(
      valueListenable: bus.frameNotifier,
      builder: (context, frame, _) {
        if (frame.isEmpty) return const SizedBox.shrink();
        final buf = frame.skeletonBuffer;
        final footDist = (buf[BioIdx.rFootIndex * 3] - buf[BioIdx.lFootIndex * 3]).abs();
        final shDist = (buf[BioIdx.rShoulder * 3] - buf[BioIdx.lShoulder * 3]).abs();
        final stanceRatio = shDist > 0 ? (footDist / shDist) : 1.15;
        final isWide = stanceRatio > 1.5;
        final isNarrow = stanceRatio < 0.9;

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
              Text('ANCHO DE PARADO', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Text(stanceRatio.toStringAsFixed(2), style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(
                isWide ? 'STANCE ANCHO' : (isNarrow ? 'STANCE CERRADO' : 'STANCE ESTÁNDAR'),
                style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: (isWide || isNarrow) ? BiomechColors.warning : BiomechColors.optimal),
              ),
            ],
          ),
        );
      },
    );
  }
}
