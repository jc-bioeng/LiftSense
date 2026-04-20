import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'widgets/biomechanic_charts.dart';

// ─── Mock Data Models ───────────────────────────────────────
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
  final String status; // 'optimal', 'warning', 'critical'
  const JointAngleSnapshot(this.joint, this.angle, this.status);
}

// ─── Main Screen ────────────────────────────────────────────
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

  // Mock movement phases (percentage of video duration)
  static const List<SquatPhase> _phases = [
    SquatPhase('DESCENSO', 0.0, 0.35, Color(0xFF00D4AA)),
    SquatPhase('FONDO', 0.35, 0.50, Color(0xFFFFB627)),
    SquatPhase('ASCENSO', 0.50, 0.85, Color(0xFF007BFF)),
    SquatPhase('LOCKOUT', 0.85, 1.0, Color(0xFF8B5CF6)),
  ];

  // Mock joint angle data at current frame
  static const List<JointAngleSnapshot> _currentAngles = [
    JointAngleSnapshot('Cadera', 92.3, 'optimal'),
    JointAngleSnapshot('Rodilla', 118.7, 'optimal'),
    JointAngleSnapshot('Tobillo', 28.4, 'warning'),
    JointAngleSnapshot('Tronco', 42.1, 'optimal'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initVideo();
  }

  Future<void> _initVideo() async {
    // Delay estratégico para permitir que los decodificadores del Dashboard 
    // se liberen por completo en el hardware.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    try {
      final videoFile = widget.videoPath ?? 'mockup_squat.mp4';
      final docsDir = await getApplicationDocumentsDirectory();
      
      // Si el path ya es absoluto no lo concatenamos
      final File file = (videoFile.contains('/') || videoFile.contains('\\')) 
          ? File(videoFile) 
          : File('${docsDir.path}/$videoFile');

      _videoController = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      
      await _videoController!.initialize();
      
      if (mounted) {
        setState(() {});
        _videoController!.addListener(_onVideoProgress);
        _videoController!.setVolume(0);
        _videoController!.setLooping(true);
        _videoController!.play();
        _isPlaying = true;
      }
    } catch (e) {
      debugPrint("AnalysisScreen: Error al inicializar video -> $e");
      // Opcional: mostrar un estado de error en la UI
    }
  }

  void _onVideoProgress() {
    if (!mounted || _videoController == null) return;
    final pos = _videoController!.value.position;
    final dur = _videoController!.value.duration;
    if (dur.inMilliseconds > 0) {
      final newProgress = pos.inMilliseconds / dur.inMilliseconds;
      if ((newProgress - _playbackProgress).abs() > 0.005) {
        setState(() => _playbackProgress = newProgress);
      }
    }
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    if (_videoController == null) return;
    setState(() {
      if (_isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  void _seekToPhase(int index) {
    HapticFeedback.selectionClick();
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    final dur = _videoController!.value.duration;
    final seekMs = (dur.inMilliseconds * _phases[index].startPercent).toInt();
    _videoController!.seekTo(Duration(milliseconds: seekMs));
    setState(() => _selectedPhaseIndex = index);
  }

  void _seekToPosition(double percent) {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    final dur = _videoController!.value.duration;
    final seekMs = (dur.inMilliseconds * percent).toInt();
    _videoController!.seekTo(Duration(milliseconds: seekMs));
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD — CustomScrollView con SliverPersistentHeader
  //  El video se contrae de 62% → 220px al hacer scroll.
  //  Todo el bloque (video+fases+stats+tabs) queda PINNED.
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final screenHeight = MediaQuery.of(context).size.height;

    final videoExpanded = screenHeight * 0.62;
    const videoCollapsed = 220.0;
    const phaseHeight = 56.0;
    const statsHeight = 60.0;
    const tabBarHeight = 46.0;
    const controlsHeight = phaseHeight + statsHeight + tabBarHeight;

    final maxHeaderExtent = videoExpanded + controlsHeight;
    final minHeaderExtent = videoCollapsed + controlsHeight;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ─── Collapsing Video Header (pinned) ────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _VideoHeaderDelegate(
              maxExtent: maxHeaderExtent,
              minExtent: minHeaderExtent,
              videoExpanded: videoExpanded,
              videoCollapsed: videoCollapsed,
              statusBarHeight: statusBarHeight,
              builder: (double videoH, double shrinkRatio) {
                return Container(
                  color: const Color(0xFF0A0A0C),
                  child: Column(
                    children: [
                      // ─── Video (se contrae) ──────────────
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showOverlay = !_showOverlay),
                          child: Container(
                            width: double.infinity,
                            color: Colors.black,
                            child: Stack(
                              children: [
                                // Video player
                                if (_videoController != null && _videoController!.value.isInitialized)
                                  Positioned.fill(
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      clipBehavior: Clip.hardEdge,
                                      child: SizedBox(
                                        width: _videoController!.value.size.width,
                                        height: _videoController!.value.size.height,
                                        child: VideoPlayer(_videoController!),
                                      ),
                                    ),
                                  )
                                else
                                  // Skeleton loading
                                  Positioned.fill(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0xFF111113), Color(0xFF0A0A0C)],
                                        ),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 28, height: 28,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: const Color(0xFF00D4AA).withValues(alpha: 0.6),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text('Preparando análisis...', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white30)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                // Top gradient (status bar protection)
                                Positioned(
                                  top: 0, left: 0, right: 0,
                                  height: statusBarHeight + 50,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                        colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                                      ),
                                    ),
                                  ),
                                ),

                                // Bottom gradient (blend con fondo)
                                Positioned(
                                  bottom: 0, left: 0, right: 0, height: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                        colors: [const Color(0xFF0A0A0C), Colors.transparent],
                                      ),
                                    ),
                                  ),
                                ),

                                // Play/Pause overlay
                                if (_showOverlay && _videoController != null && _videoController!.value.isInitialized)
                                  Positioned.fill(
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: _togglePlayPause,
                                        child: Container(
                                          width: 54 - (shrinkRatio * 10),
                                          height: 54 - (shrinkRatio * 10),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                          ),
                                          child: Icon(
                                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                            color: Colors.white, size: 28 - (shrinkRatio * 4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // Back button
                                Positioned(
                                  top: statusBarHeight + 4, left: 12,
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                        child: Container(
                                          width: 36, height: 36,
                                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // REC badge
                                Positioned(
                                  top: statusBarHeight + 4, right: 12,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(width: 5, height: 5, decoration: BoxDecoration(color: colors.tertiary, shape: BoxShape.circle)),
                                            const SizedBox(width: 5),
                                            Text('REC 00:04.2', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ─── Phase Timeline (pinned) ──────────
                      SizedBox(height: phaseHeight, child: _buildPhaseTimeline(colors)),

                      // ─── Quick Stats (pinned) ─────────────
                      SizedBox(height: statsHeight, child: _buildQuickStats(colors)),

                      // ─── Tab Bar (pinned) ─────────────────
                      SizedBox(
                        height: tabBarHeight,
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: colors.primary,
                          indicatorWeight: 3,
                          indicatorSize: TabBarIndicatorSize.label,
                          labelColor: colors.primary,
                          unselectedLabelColor: Colors.white38,
                          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.0),
                          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: 1.0),
                          tabs: const [Tab(text: "CINEMÁTICA"), Tab(text: "CARGAS"), Tab(text: "VELOCIDAD")],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ─── Tab Content (scrolleable debajo del header) ──
          SliverFillRemaining(
            hasScrollBody: true,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildKinematicsTab(colors),
                _buildLoadsTab(colors),
                _buildVelocityTab(colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Phase Timeline Widget ──────────────────────────────────
  Widget _buildPhaseTimeline(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              final box = context.findRenderObject() as RenderBox;
              final percent = (details.localPosition.dx / (box.size.width - 40)).clamp(0.0, 1.0);
              _seekToPosition(percent);
            },
            child: SizedBox(
              height: 20,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Row(
                    children: _phases.asMap().entries.map((entry) {
                      final i = entry.key;
                      final phase = entry.value;
                      final width = phase.endPercent - phase.startPercent;
                      return Expanded(
                        flex: (width * 100).toInt(),
                        child: GestureDetector(
                          onTap: () => _seekToPhase(i),
                          child: Container(
                            height: 5,
                            margin: EdgeInsets.only(right: i < _phases.length - 1 ? 2 : 0),
                            decoration: BoxDecoration(
                              color: phase.color.withValues(alpha: _selectedPhaseIndex == i ? 0.9 : 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  Positioned(
                    left: _playbackProgress * (MediaQuery.of(context).size.width - 40) - 5,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: _phases.asMap().entries.map((entry) {
              final i = entry.key;
              final phase = entry.value;
              final width = phase.endPercent - phase.startPercent;
              final isActive = _playbackProgress >= phase.startPercent && _playbackProgress < phase.endPercent;
              return Expanded(
                flex: (width * 100).toInt(),
                child: GestureDetector(
                  onTap: () => _seekToPhase(i),
                  child: Text(phase.label, textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 8, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, letterSpacing: 0.5, color: isActive ? phase.color : Colors.white30),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Quick Stats Row ──────────────────────────────────────
  Widget _buildQuickStats(ColorScheme colors) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: _currentAngles.map((angle) {
          Color statusColor;
          switch (angle.status) {
            case 'warning': statusColor = const Color(0xFFFFB627); break;
            case 'critical': statusColor = colors.tertiary; break;
            default: statusColor = colors.primary;
          }
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: statusColor.withValues(alpha: 0.5), width: 2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  angle.joint.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white30,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${angle.angle.toStringAsFixed(1)}°',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Tab: Cinemática ──────────────────────────────────────
  Widget _buildKinematicsTab(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        _buildSectionLabel('CLASIFICACIÓN DE SESGO CINEMÁTICO'),
        const SizedBox(height: 10),
        const KinematicBiasTracker(),
        const SizedBox(height: 20),
        _buildSectionLabel('ÁNGULOS ARTICULARES VS TIEMPO'),
        const SizedBox(height: 10),
        const JointAngleTimeSeriesChart(),
        const SizedBox(height: 20),
        _buildSectionLabel('RANGO DE MOVIMIENTO'),
        const SizedBox(height: 10),
        _buildRomTable(colors),
        const SizedBox(height: 20),
        _buildSectionLabel('NOTA CLÍNICA'),
        const SizedBox(height: 10),
        const RectusFemorisAlertCard(),
      ],
    );
  }

  // ─── Tab: Cargas ──────────────────────────────────────────
  Widget _buildLoadsTab(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        _buildSectionLabel('CARGAS ARTICULARES ESTIMADAS'),
        const SizedBox(height: 10),
        const JointLoadsChart(),
        const SizedBox(height: 20),
        _buildSectionLabel('TORSIÓN NETA POR ARTICULACIÓN'),
        const SizedBox(height: 10),
        _buildTorqueBar('CADERA EXT.', 142, 180, colors.primary),
        const SizedBox(height: 8),
        _buildTorqueBar('RODILLA EXT.', 118, 180, const Color(0xFF007BFF)),
        const SizedBox(height: 8),
        _buildTorqueBar('TOBILLO PF.', 45, 180, const Color(0xFFFFB627)),
        const SizedBox(height: 8),
        _buildTorqueBar('LUMBAR EXT.', 165, 200, const Color(0xFF8B5CF6)),
        const SizedBox(height: 20),
        _buildSectionLabel('ALERTA ESTRUCTURAL'),
        const SizedBox(height: 10),
        const ButtWinkAlertCard(),
      ],
    );
  }

  // ─── Tab: Velocidad ───────────────────────────────────────
  Widget _buildVelocityTab(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        _buildSectionLabel('PERFIL VBT — VELOCITY BASED TRAINING'),
        const SizedBox(height: 10),
        const VelocityTrainingChart(),
        const SizedBox(height: 20),
        _buildSectionLabel('MÉTRICAS CLAVE'),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildVbtMetricCard('V. MEDIA', '0.68 m/s', colors.primary),
            const SizedBox(width: 8),
            _buildVbtMetricCard('V. PICO', '0.92 m/s', const Color(0xFF007BFF)),
            const SizedBox(width: 8),
            _buildVbtMetricCard('DROP-OFF', '-28%', colors.tertiary),
          ],
        ),
      ],
    );
  }

  // ─── Shared Helpers ───────────────────────────────────────
  Widget _buildSectionLabel(String text) {
    return Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.white30));
  }

  Widget _buildRomTable(ColorScheme colors) {
    final romData = [
      {'joint': 'Cadera', 'rom': '87.3°', 'ref': '90–120°', 'ok': false},
      {'joint': 'Rodilla', 'rom': '118.7°', 'ref': '110–140°', 'ok': true},
      {'joint': 'Tobillo', 'rom': '28.4°', 'ref': '30–40°', 'ok': false},
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(14),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(child: Text('ARTICULACIÓN', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white24, letterSpacing: 0.5))),
                SizedBox(width: 80, child: Text('ROM', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white24, letterSpacing: 0.5))),
                SizedBox(width: 80, child: Text('REF.', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white24, letterSpacing: 0.5))),
                const SizedBox(width: 24),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          ...romData.map((d) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text(d['joint'] as String, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white))),
                SizedBox(width: 80, child: Text(d['rom'] as String, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                SizedBox(width: 80, child: Text(d['ref'] as String, style: GoogleFonts.inter(fontSize: 11, color: Colors.white38))),
                SizedBox(width: 24, child: Icon((d['ok'] as bool) ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded, color: (d['ok'] as bool) ? colors.primary : const Color(0xFFFFB627), size: 16)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTorqueBar(String label, double value, double max, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF141416), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white54)),
              Text('${value.toInt()} N·m', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: (value / max).clamp(0.0, 1.0), backgroundColor: Colors.white.withValues(alpha: 0.05), color: color, minHeight: 6),
          ),
        ],
      ),
    );
  }

  Widget _buildVbtMetricCard(String label, String value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(14),
          border: Border(top: BorderSide(color: accent.withValues(alpha: 0.4), width: 1.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.white38, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  VIDEO HEADER DELEGATE
//  Contrae el video de expandido (62% pantalla) → colapsado
//  (220px) y mantiene todo el bloque PINNED en el tope.
// ═══════════════════════════════════════════════════════════════
class _VideoHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  final double maxExtent;
  @override
  final double minExtent;
  final double videoExpanded;
  final double videoCollapsed;
  final double statusBarHeight;
  final Widget Function(double videoHeight, double shrinkRatio) builder;

  const _VideoHeaderDelegate({
    required this.maxExtent,
    required this.minExtent,
    required this.videoExpanded,
    required this.videoCollapsed,
    required this.statusBarHeight,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final maxShrink = maxExtent - minExtent;
    final shrinkRatio = (shrinkOffset / maxShrink).clamp(0.0, 1.0);
    final videoH = videoExpanded - (shrinkRatio * (videoExpanded - videoCollapsed));
    return builder(videoH, shrinkRatio);
  }

  @override
  bool shouldRebuild(covariant _VideoHeaderDelegate oldDelegate) =>
      maxExtent != oldDelegate.maxExtent || minExtent != oldDelegate.minExtent;
}
