import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'widgets/biomechanic_charts.dart';
import 'widgets/skeleton_painter.dart';

// ─── Mock Data Models ────────────────────────────────────────
class SquatPhase {
  final String label;
  final double startPercent;
  final double endPercent;
  final Color color;
  const SquatPhase(this.label, this.startPercent, this.endPercent, this.color);
}

class JointAngleSnapshot {
  final String joint;
  final double angle;
  final String status;
  const JointAngleSnapshot(this.joint, this.angle, this.status);
}

// ─── Main Screen ─────────────────────────────────────────────
class AnalysisScreen extends StatefulWidget {
  final String? videoPath;
  const AnalysisScreen({super.key, this.videoPath});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  late TabController _tabController;
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  int _selectedPhaseIndex = -1;
  bool _showOverlay = true;
  bool _hasError = false;
  // Controladores y estado
  late ScrollController _scrollController;
  late DraggableScrollableController _sheetController;
  late ValueNotifier<double> _sheetExtent;
  bool _isAutoPaused = false;

  static const List<SquatPhase> _phases = [
    SquatPhase('DESCENSO', 0.0, 0.35, Color(0xFF00D4AA)),
    SquatPhase('FONDO', 0.35, 0.50, Color(0xFFFFB627)),
    SquatPhase('ASCENSO', 0.50, 0.85, Color(0xFF007BFF)),
    SquatPhase('LOCKOUT', 0.85, 1.0, Color(0xFF8B5CF6)),
  ];

  static const List<JointAngleSnapshot> _currentAngles = [
    JointAngleSnapshot('Cadera', 92.3, 'optimal'),
    JointAngleSnapshot('Rodilla', 118.7, 'optimal'),
    JointAngleSnapshot('Tobillo', 28.4, 'warning'),
    JointAngleSnapshot('Tronco', 42.1, 'optimal'),
  ];

  // El video ocupa casi toda la pantalla cuando expandido.
  // Alturas calculadas dinámicamente en base al tamaño de pantalla.
  static const double _collapsedBar = 68.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _sheetController = DraggableScrollableController();
    _sheetExtent = ValueNotifier<double>(0.25); // Inicia minimizado
    
    _sheetController.addListener(() {
      _sheetExtent.value = _sheetController.size;
      _onSheetChanged();
    });

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _initVideo();
  }

  void _onSheetChanged() {
    if (!mounted) return;
    final extent = _sheetController.size;
    
    // Auto-pause video when expanded to Maximized state (above 0.8)
    if (extent >= 0.8) {
      if (!_isAutoPaused && _isPlaying && _videoController != null) {
        _videoController!.pause();
        setState(() {
          _isAutoPaused = true;
          _isPlaying = false;
        });
      }
    } else {
      if (_isAutoPaused && !_isPlaying && _videoController != null) {
        _videoController!.play();
        setState(() {
          _isAutoPaused = false;
          _isPlaying = true;
        });
      }
    }
  }

  Future<void> _initVideo() async {
    final videoFile = widget.videoPath ?? 'mockup_squat.mp4';
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File('${docsDir.path}/$videoFile');
    
    _videoController = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() {
          _hasError = false;
        });
        _videoController!.addListener(_onVideoProgress);
        _videoController!.play();
        _isPlaying = true;
      }
    } catch (e) {
      debugPrint('Error init video Analysis: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _onVideoProgress() {
    if (!mounted || _videoController == null) return;
    final pos = _videoController!.value.position;
    final dur = _videoController!.value.duration;
    if (dur.inMilliseconds > 0) {
      final np = pos.inMilliseconds / dur.inMilliseconds;
      if ((np - _playbackProgress).abs() > 0.005) {
        setState(() => _playbackProgress = np);
      }
    }
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    if (_videoController == null) return;
    setState(() {
      if (_isPlaying) {
        // Primer toque mientras corre: mostrar overlay con botón de pausa
        if (!_showOverlay) {
          _showOverlay = true;
          // Auto-ocultar el overlay después de 2.5s
          Future.delayed(const Duration(milliseconds: 2500), () {
            if (mounted && _isPlaying) setState(() => _showOverlay = false);
          });
          return; // no pausar aún, solo mostrar el botón
        }
        // Segundo toque (overlay visible): pausar de verdad
        _videoController!.pause();
        _isPlaying = false;
        _showOverlay = true; // mantener visible mientras pausado
      } else {
        // Estaba pausado: reanudar
        _videoController!.play();
        _isPlaying = true;
        _showOverlay = false; // ocultar botón inmediatamente al correr
      }
    });
  }

  void _seekToPhase(int index) {
    HapticFeedback.selectionClick();
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    final dur = _videoController!.value.duration;
    _videoController!.seekTo(
      Duration(milliseconds: (dur.inMilliseconds * _phases[index].startPercent).toInt()),
    );
    setState(() => _selectedPhaseIndex = index);
  }

  void _seekToPosition(double percent) {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    final dur = _videoController!.value.duration;
    _videoController!.seekTo(
      Duration(milliseconds: (dur.inMilliseconds * percent).toInt()),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _sheetController.dispose();
    _sheetExtent.dispose();
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusBarH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ══ UNIFIED BACKGROUND LAYER (Video & Skeleton) ════
          _AnalysisHeroBackground(
            extent: _sheetExtent,
            videoController: _videoController,
            isPlaying: _isPlaying,
            showOverlay: _showOverlay,
            hasError: _hasError,
            onTogglePlayPause: _togglePlayPause,
            colors: colors,
            statusBarHeight: statusBarH,
          ),

          // ══ FRONT LAYER (Dynamic Bottom Sheet) ══════════
          DraggableScrollableSheet(
            key: const GlobalObjectKey('analysis_sheet'),
            controller: _sheetController,
            initialChildSize: 0.14,
            minChildSize: 0.14,
            maxChildSize: 0.98,
            snap: true,
            snapSizes: const [0.14, 0.45, 0.98],
            builder: (context, scrollController) {
              return ValueListenableBuilder<double>(
                valueListenable: _sheetExtent,
                builder: (context, extent, child) {
                  // Estado lógico basado en la extensión
                  // State 1: < 0.25 (Pills)
                  // State 2: 0.25 - 0.8 (Expansion)
                  // State 3: > 0.8 (Solid Matte)
                  
                  final isMaximized = extent > 0.8;
                  final tMaterial = ((extent - 0.75) / 0.15).clamp(0.0, 1.0);
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: isMaximized 
                        ? const Color(0xFF0A0A0C) 
                        : const Color(0xFF0A0A0C).withValues(alpha: lerpDouble(0.65, 1.0, tMaterial)!),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: isMaximized ? 0 : 20,
                          sigmaY: isMaximized ? 0 : 20,
                        ),
                        child: CustomScrollView(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          slivers: [
                            if (isMaximized)
                              SliverToBoxAdapter(
                                child: SizedBox(height: statusBarH + 10),
                              ),

                            // ── HANDLE INDICATOR ──────────
                            SliverToBoxAdapter(
                              child: Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),

                            // ── PHASE BAR ───────────────
                            SliverToBoxAdapter(
                              child: _buildPhaseTimeline(
                                context: context,
                                playbackProgress: _playbackProgress,
                                phases: _phases,
                                selectedPhaseIndex: _selectedPhaseIndex,
                                onSeekToPhase: _seekToPhase,
                                onSeekToPosition: _seekToPosition,
                              ),
                            ),

                            const SliverToBoxAdapter(child: SizedBox(height: 12)),

                            // ── JOINT ANGLES (PILLS -> CARDS) ──
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _JointAnglesHeaderDelegate(
                                angles: _currentAngles,
                                colors: colors,
                                extent: extent,
                              ),
                            ),

                            const SliverToBoxAdapter(child: SizedBox(height: 20)),

                            // ── TABS (Only visible in Max) ──
                            if (isMaximized) ...[
                              SliverPersistentHeader(
                                pinned: true,
                                delegate: _SimpleStickyTabBarDelegate(
                                  colors: colors,
                                  child: TabBar(
                                    controller: _tabController,
                                    indicatorColor: colors.primary,
                                    labelColor: colors.primary,
                                    unselectedLabelColor: Colors.white24,
                                    indicatorWeight: 3,
                                    tabs: const [
                                      Tab(text: 'CINEMÁTICA'),
                                      Tab(text: 'CARGAS'),
                                      Tab(text: 'VELOCIDAD'),
                                    ],
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: _buildTabContent(colors),
                                ),
                              ),
                            ] else ...[
                               // Preview content when slightly expanded
                               SliverToBoxAdapter(
                                 child: Opacity(
                                   opacity: ((extent - 0.25) / 0.3).clamp(0.0, 1.0),
                                   child: _buildKinematicsTab(colors),
                                 ),
                               )
                            ],
                            
                            const SliverToBoxAdapter(child: SizedBox(height: 100)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // ══ PERSISTENT BACK BUTTON ═══════════════════════
          Positioned(
            top: statusBarH + 10,
            left: 16,
            child: _buildBackButton(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ColorScheme colors) {
    switch (_tabController.index) {
      case 0: return _buildKinematicsTab(colors);
      case 1: return _buildLoadsTab(colors);
      case 2: return _buildVelocityTab(colors);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildKinematicsTab(ColorScheme colors) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          key: const ValueKey('kinematics'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('SEGUIMIENTO DE SESGO'),
            const SizedBox(height: 10),
            const KinematicBiasTracker(),
            const SizedBox(height: 24),
            _buildSectionLabel('ÁNGULOS VS TIEMPO'),
            const SizedBox(height: 10),
            const JointAngleTimeSeriesChart(),
            const SizedBox(height: 24),
            _buildSectionLabel('RESUMEN DE RANGOS (ROM)'),
            const SizedBox(height: 10),
            _buildRomSummary(colors),
          ],
        ),
      );

  Widget _buildLoadsTab(ColorScheme colors) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          key: const ValueKey('loads'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('CARGAS ARTICULARES'),
            const SizedBox(height: 10),
            const JointLoadsChart(),
            const SizedBox(height: 24),
            _buildSectionLabel('TORQUE MÁXIMO POR ARTICULACIÓN'),
            const SizedBox(height: 10),
            _buildTorqueSummary(colors),
          ],
        ),
      );

  Widget _buildVelocityTab(ColorScheme colors) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          key: const ValueKey('velocity'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('PERFIL VBT MPV'),
            const SizedBox(height: 10),
            const VelocityTrainingChart(),
            const SizedBox(height: 24),
            _buildSectionLabel('MÉTRICAS DE RENDIMIENTO'),
            const SizedBox(height: 10),
            _buildVbtMetrics(colors),
          ],
        ),
      );


  Widget _buildSectionLabel(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: Colors.white38,
        ),
      );

  Widget _buildRomSummary(ColorScheme colors) {
    final romData = [
      {'joint': 'Cadera', 'rom': '92.3°', 'ref': '90°–120°', 'ok': true},
      {'joint': 'Rodilla', 'rom': '118.7°', 'ref': '110°–140°', 'ok': true},
      {'joint': 'Tobillo', 'rom': '28.4°', 'ref': '30°–45°', 'ok': false},
      {'joint': 'Tronco', 'rom': '42.1°', 'ref': '35°–55°', 'ok': true},
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(14),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
      ),
      child: Column(
        children: romData.asMap().entries.map((entry) {
          final d = entry.value;
          final isOk = d['ok'] as bool;
          return Column(
            children: [
              if (entry.key > 0)
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 20),
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      (d['joint'] as String).toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white54),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      d['rom'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5),
                    ),
                  ),
                  Text(d['ref'] as String,
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.white30)),
                  const SizedBox(width: 8),
                  Icon(
                    isOk ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: isOk ? colors.primary : const Color(0xFFFFB627),
                    size: 16,
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTorqueSummary(ColorScheme colors) {
    final torqueData = [
      {'name': 'Cadera Ext.', 'value': '142 N·m', 'pct': 0.85},
      {'name': 'Rodilla Ext.', 'value': '118 N·m', 'pct': 0.70},
      {'name': 'Tobillo P.F.', 'value': '76 N·m', 'pct': 0.45},
      {'name': 'Lumbar Ext.', 'value': '95 N·m', 'pct': 0.57},
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(14),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
      ),
      child: Column(
        children: torqueData.asMap().entries.map((entry) {
          final d = entry.value;
          return Column(
            children: [
              if (entry.key > 0) const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(
                    width: 85,
                    child: Text(
                      (d['name'] as String).toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white54),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: d['pct'] as double,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        color: colors.primary.withValues(alpha: 0.7),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: Text(
                      d['value'] as String,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVbtMetrics(ColorScheme colors) => Row(
        children: [
          _vbtCard('V. MEDIA', '0.68 m/s', colors.primary),
          const SizedBox(width: 10),
          _vbtCard('V. PICO', '0.92 m/s', const Color(0xFF007BFF)),
          const SizedBox(width: 10),
          _vbtCard('DROP-OFF', '-28%', colors.tertiary),
        ],
      );

  Widget _vbtCard(String label, String value, Color accent) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(14),
            border: Border(top: BorderSide(color: accent.withValues(alpha: 0.4), width: 1.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white38,
                      letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5)),
            ],
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  STICKY TAB BAR DELEGATE
//  Permite que el TabBar se quede pegado al tope bajo el header
// ═══════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════
//  SIMPLE STICKY TAB BAR DELEGATE
// ═══════════════════════════════════════════════════════════════
class _SimpleStickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final ColorScheme colors;

  _SimpleStickyTabBarDelegate({required this.child, required this.colors});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0A0A0C),
      child: child,
    );
  }

  @override
  double get maxExtent => 50;
  @override
  double get minExtent => 50;
  @override
  bool shouldRebuild(_SimpleStickyTabBarDelegate oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════
//  JOINT ANGLES HEADER DELEGATE
//  Interpolates from pills (collapsed) to cards (expanded)
// ═══════════════════════════════════════════════════════════════
class _JointAnglesHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<JointAngleSnapshot> angles;
  final ColorScheme colors;
  final double extent; // DraggableScrollableSheet size

  _JointAnglesHeaderDelegate({
    required this.angles,
    required this.colors,
    required this.extent,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Definimos el progreso interno basado en el extent
    // 0.14 - 0.25 -> Pills
    // 0.25 - 0.45 -> Transición
    // > 0.45 -> Full Cards
    final t = ((extent - 0.14) / 0.31).clamp(0.0, 1.0);
    
    final boxH = lerpDouble(44.0, 105.0, Curves.easeInOutCubic.transform(t))!;
    final detailOpacity = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
    final pillOpacity = (1.0 - t * 2).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: boxH,
      child: Row(
        children: angles.map((a) {
          final color = _statusColor(a.status);
          final isOk = a.status == 'optimal';

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                height: boxH,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ──── PILL (Minimizado) ────────────
                    if (pillOpacity > 0)
                      Opacity(
                        opacity: pillOpacity,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _abbr(a.joint),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${a.angle.toStringAsFixed(0)}°',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ──── CARD (Expandido) ─────────────
                    if (detailOpacity > 0)
                      Opacity(
                        opacity: detailOpacity,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                a.joint.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white38,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${a.angle.toStringAsFixed(1)}°',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 5, height: 5,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isOk ? 'Óptimo' : 'Cuidado',
                                    style: GoogleFonts.inter(fontSize: 8, color: color, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _statusColor(String status) {
    if (status == 'warning') return const Color(0xFFFFB627);
    if (status == 'critical') return colors.tertiary;
    return colors.primary;
  }

  String _abbr(String name) {
    switch (name.toLowerCase()) {
      case 'cadera': return 'CAD';
      case 'rodilla': return 'ROD';
      case 'tobillo': return 'TOB';
      default: return 'TRO';
    }
  }

  @override
  double get maxExtent => lerpDouble(44.0, 105.0, Curves.easeInOutCubic.transform(((extent - 0.14) / 0.31).clamp(0.0, 1.0)))!;
  @override
  double get minExtent => maxExtent;
  @override
  bool shouldRebuild(_JointAnglesHeaderDelegate oldDelegate) => oldDelegate.extent != extent;
}


// ═══════════════════════════════════════════════════════════════
//  UNIFIED HERO BACKGROUND
//  Manages both Video and Skeleton states in a single object
// ═══════════════════════════════════════════════════════════════
class _AnalysisHeroBackground extends StatelessWidget {
  final ValueNotifier<double> extent;
  final VideoPlayerController? videoController;
  final bool isPlaying;
  final bool showOverlay;
  final bool hasError;
  final VoidCallback onTogglePlayPause;
  final ColorScheme colors;
  final double statusBarHeight;

  const _AnalysisHeroBackground({
    required this.extent,
    required this.videoController,
    required this.isPlaying,
    required this.showOverlay,
    required this.hasError,
    required this.onTogglePlayPause,
    required this.colors,
    required this.statusBarHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: extent,
      builder: (context, currentExtent, _) {
        final skeletonOpacity = ((currentExtent - 0.75) / 0.20).clamp(0.0, 1.0);
        final videoOpacity = (1.0 - (currentExtent - 0.8) / 0.15).clamp(0.0, 1.0);
        final isMaximized = currentExtent > 0.85;

        return Stack(
          fit: StackFit.expand,
          children: [
            // ── VIDEO LAYER ──────────────────────────────────
            if (videoOpacity > 0)
              Opacity(
                opacity: videoOpacity,
                child: _buildVideoView(),
              ),

            // ── SKELETON LAYER ───────────────────────────────
            if (skeletonOpacity > 0)
              Opacity(
                opacity: skeletonOpacity,
                child: Container(
                  color: const Color(0xFF0A0A0C),
                  child: Center(
                    child: SkeletonMockupView(isActive: isMaximized),
                  ),
                ),
              ),

            // ── OVERLAYS (Buttons, Gradients) ────────────────
            if (videoOpacity > 0.5) ...[
              _buildTopGradient(),
              _buildPlayButton(context, currentExtent),
              _buildBadge(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildVideoView() {
    if (hasError) return _buildErrorState();
    if (videoController == null || !videoController!.value.isInitialized) {
      return _buildLoadingState();
    }
    return GestureDetector(
      onTap: onTogglePlayPause,
      child: Container(
        color: Colors.black,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: videoController!.value.size.width,
            height: videoController!.value.size.height,
            child: VideoPlayer(videoController!),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context, double currentExtent) {
    final canShow = (showOverlay || !isPlaying) && !hasError && currentExtent < 0.8;
    if (!canShow) return const SizedBox.shrink();

    return Center(
      child: GestureDetector(
        onTap: onTogglePlayPause,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: isPlaying ? 64 : 72,
              height: isPlaying ? 64 : 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isPlaying ? 0.10 : 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: isPlaying ? 28 : 36,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopGradient() {
    return Positioned(
      top: 0, left: 0, right: 0,
      height: statusBarHeight + 100,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Positioned(
      top: statusBarHeight + 12,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_rounded, color: colors.primary, size: 14),
                const SizedBox(width: 6),
                Text('ANALIZANDO MOVIMIENTO',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: const Color(0xFF0A0A0C),
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: const Color(0xFF0A0A0C),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: colors.tertiary, size: 32),
            const SizedBox(height: 12),
            Text('Error al cargar video', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED UI HELPERS
// ═══════════════════════════════════════════════════════════════

Widget _buildPhaseTimeline({
  required BuildContext context,
  required double playbackProgress,
  required List<SquatPhase> phases,
  required int selectedPhaseIndex,
  required ValueChanged<int> onSeekToPhase,
  required ValueChanged<double> onSeekToPosition,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: [
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            final pct = (details.localPosition.dx / (screenWidth - 40)).clamp(0.0, 1.0);
            onSeekToPosition(pct);
          },
          child: SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Row(
                  children: phases.asMap().entries.map((entry) {
                    final i = entry.key;
                    final phase = entry.value;
                    final w = phase.endPercent - phase.startPercent;
                    return Expanded(
                      flex: (w * 100).toInt(),
                      child: GestureDetector(
                        onTap: () => onSeekToPhase(i),
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(right: i < phases.length - 1 ? 2 : 0),
                          decoration: BoxDecoration(
                            color: phase.color.withValues(alpha: selectedPhaseIndex == i ? 1.0 : 0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                Positioned(
                  left: (playbackProgress * (screenWidth - 40) - 6).clamp(0, screenWidth - 52),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: Colors.white54, blurRadius: 8, spreadRadius: 1),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: phases.asMap().entries.map((entry) {
            final phase = entry.value;
            final w = phase.endPercent - phase.startPercent;
            final isActive = playbackProgress >= phase.startPercent && playbackProgress < phase.endPercent;
            return Expanded(
              flex: (w * 100).toInt(),
              child: GestureDetector(
                onTap: () => onSeekToPhase(entry.key),
                child: Text(
                  phase.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.5,
                    color: isActive ? phase.color : Colors.white30,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

