import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'widgets/biomechanic_charts.dart';
import 'widgets/native_skeleton_overlay.dart';
import '../native/liftsense_ffi.dart';

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
  final String? csvPath;
  final String exerciseName;
  final String viewTag;
  final String captureDate;
  const AnalysisScreen({
    super.key,
    this.videoPath,
    this.csvPath,
    this.exerciseName = 'BACK SQUAT',
    this.viewTag = 'FRONTAL',
    this.captureDate = 'Hoy, 09:41 AM',
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  late TabController _tabController;
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  int _currentPositionMs = 0;
  bool _hasError = false;

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

  String? _resolvedCsvPath;
  bool _nativeEngineReady = false;
  late ScrollController _scrollController;
  double _scrollProgress = 0.0; // 0.0 = Video Focus, 1.0 = Data Focus

  // ── High-Frequency Sync (Phase 2 Interpolation) ──────
  late Ticker _syncTicker;
  Duration _lastVideoUpdate = Duration.zero;
  DateTime _lastUpdateWallClock = DateTime.now();
  int _interpolatedPositionMs = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Ticker to drive 60Hz skeleton updates
    _syncTicker = createTicker(_onTick);
    _syncTicker.start();

    // Resolve CSV path and init native engine immediately
    _resolvePaths();

    // Ocultar barra de navegación de Android para maximizar el área de análisis
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Calculamos el rango de scroll basado en la altura real del video
    final size = MediaQuery.of(context).size;
    final videoAspectRatio = (_videoController != null && _videoController!.value.isInitialized)
        ? _videoController!.value.aspectRatio
        : 16 / 9;
    final expandedHeight = size.width / videoAspectRatio;
    final collapsedHeight = size.height * 0.38; // Regresado al 38%

    final maxScroll = expandedHeight - collapsedHeight;
    if (maxScroll <= 0) return;

    final progress = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
    if (progress != _scrollProgress) {
      setState(() => _scrollProgress = progress);
    }
  }

  double get screenHeight => MediaQuery.of(context).size.height;
  double get screenWidth => MediaQuery.of(context).size.width;

  // Compensación de latencia del reproductor (Lead Time)
  static const int _lagCompensationMs = 45;

  void _onTick(Duration elapsed) {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }

    final currentVideoPos = _videoController!.value.position;
    final durationMs = _videoController!.value.duration.inMilliseconds;

    // Sincronización crítica para el INICIO y el LOOP
    // Si el video está en 0 o ha saltado hacia atrás, reseteamos el reloj de interpolación inmediatamente
    if (currentVideoPos == Duration.zero || currentVideoPos < _lastVideoUpdate) {
      _lastVideoUpdate = currentVideoPos;
      _lastUpdateWallClock = DateTime.now();
    }

    // Calcular interpolación: coarse_pos + (time_now - time_last_update)
    final now = DateTime.now();
    final delta = now.difference(_lastUpdateWallClock).inMilliseconds;
    
    // La interpolación solo avanza si el video está realmente reproduciéndose
    final interpolationOffset = _isPlaying ? delta.clamp(0, 200) : 0;
    
    // Aplicamos la compensación proactiva (+45ms) para anular el lag del listener
    int newPos = _lastVideoUpdate.inMilliseconds + interpolationOffset + _lagCompensationMs;
    
    // Evitar que el esqueleto se pase del final del video
    if (durationMs > 0 && newPos >= durationMs) {
      newPos = durationMs;
    }

    if (newPos != _interpolatedPositionMs) {
      setState(() {
        _interpolatedPositionMs = newPos;
        _playbackProgress = durationMs > 0 ? newPos / durationMs : 0.0;
      });
    }
  }


  Future<void> _resolvePaths() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final csvFile = widget.csvPath ?? 'lateral_lstrack.csv';
    
    final List<String> csvCandidates = [
      '${docsDir.path}/$csvFile',
      '/storage/emulated/0/LiftSense/$csvFile',
    ];

    for (final path in csvCandidates) {
      if (await File(path).exists()) {
        _resolvedCsvPath = path;
        break;
      }
    }

    if (_resolvedCsvPath == null) {
      debugPrint('[NativeEngine] CSV NOT FOUND in candidates: $csvCandidates');
    }

    await _initVideo();
  }

  Future<void> _initVideo() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final videoFile = widget.videoPath ?? 'frontal.mp4';
    
    final List<String> videoCandidates = [
      '${docsDir.path}/$videoFile',
      '/storage/emulated/0/LiftSense/$videoFile',
    ];

    File? foundFile;
    for (final path in videoCandidates) {
      final f = File(path);
      if (await f.exists()) {
        foundFile = f;
        break;
      }
    }

    if (foundFile == null) {
      debugPrint('Video file not found in candidates: $videoCandidates');
      setState(() => _hasError = true);
      return;
    }

    try {
      _videoController = VideoPlayerController.file(
        foundFile,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await _videoController!.initialize();
      
      // ── Initialize native C++ engine with TRACKER space size (1080x1920) ──
      // This allows C++ to scale the 1080px-based CSV points to any viewport size.
      if (_resolvedCsvPath != null) {
        try {
          if (LiftsenseNative.isInitialized) LiftsenseNative.dispose();
          final frameCount = LiftsenseNative.init(
            _resolvedCsvPath!, 
            videoWidth: 1080.0, 
            videoHeight: 1920.0,
          );
          debugPrint('[NativeEngine] Loaded $frameCount frames for 1080x1920 tracker space.');
          if (mounted) setState(() => _nativeEngineReady = true);
        } catch (e) {
          debugPrint('[NativeEngine] Init failed: $e');
        }
      }

      if (mounted) {
        setState(() {
          _hasError = false;
          _lastVideoUpdate = Duration.zero;
          _lastUpdateWallClock = DateTime.now();
          _interpolatedPositionMs = 0;
          
          _videoController!.addListener(_onVideoProgress);
          _videoController!.play();
          _isPlaying = true;
          _videoController!.setLooping(true);
        });
      }
    } catch (e) {
      debugPrint('Error init video Analysis: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onVideoProgress() {
    if (!mounted || _videoController == null || !_videoController!.value.isInitialized) return;
    final pos = _videoController!.value.position;
    final dur = _videoController!.value.duration;
    
    if (pos.inMilliseconds != _currentPositionMs) {
      // Si detectamos un salto hacia atrás (loop), reseteamos todo
      final bool isLoop = pos.inMilliseconds < _currentPositionMs;
      
      setState(() {
        _lastVideoUpdate = pos;
        _lastUpdateWallClock = DateTime.now();
        _currentPositionMs = pos.inMilliseconds;
        _interpolatedPositionMs = pos.inMilliseconds;
        _playbackProgress = dur.inMilliseconds > 0 
            ? pos.inMilliseconds / dur.inMilliseconds 
            : 0.0;
      });
    }
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    if (_videoController == null) return;
    setState(() {
      if (_isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  void dispose() {
    _syncTicker.dispose();
    _scrollController.dispose();
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
    _tabController.dispose();
    // Release native engine resources
    if (_nativeEngineReady) {
      LiftsenseNative.dispose();
      _nativeEngineReady = false;
    }
    // Restaurar barra de navegación al salir de la pantalla de análisis
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    // Calculamos la altura expandida basada en el aspect ratio real del video
    final videoAspectRatio = (_videoController != null && _videoController!.value.isInitialized)
        ? _videoController!.value.aspectRatio
        : 16 / 9;
    final expandedHeight = size.width / videoAspectRatio;

    // Reserved space for the skeleton at the top (38% for better balance)
    final collapsedHeight = size.height * 0.38; 

    return Scaffold(
      backgroundColor: const Color(0xFF161618), // Tono ligeramente más claro para el modo laboratorio
      body: Stack(
        children: [
          // ── Layer 0: Main Scrolling Experience ──
          NestedScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(), // Elimina el brillo verde de Android
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // 1. Dynamic Header (Video Only Layer)
                SliverAppBar(
                  expandedHeight: expandedHeight,
                  collapsedHeight: collapsedHeight,
                  pinned: true,
                  backgroundColor: const Color(0xFF161618), // Opaco con el mismo color del fondo para ocultar el scroll
                  surfaceTintColor: Colors.transparent, // Desactiva el tinte verde de Material 3
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(color: Colors.transparent),
                  ),
                ),

                // 2. Persistent Timeline Header (Pinned below the stage)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SolidStickyTimelineDelegate(
                    height: 124, 
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Handle central (Pill shape)
                          Container(
                            width: 44,
                            height: 5,
                            margin: const EdgeInsets.only(top: 10, bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          _buildPhaseTimeline(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Data Section (Pills)
                SliverToBoxAdapter(
                  child: Container(
                    color: const Color(0xFF101012), // Fondo oscuro unificado con la línea de tiempo
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildJointAnglePills(colors),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Sticky Tab Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SolidStickyTabBarDelegate(
                    PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: colors.primary,
                        labelColor: colors.primary,
                        unselectedLabelColor: Colors.white38,
                        indicatorWeight: 3,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'CINEMÁTICA'),
                          Tab(text: 'CARGAS'),
                          Tab(text: 'VELOCIDAD'),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: Container(
              color: const Color(0xFF101012), // Fondo oscuro unificado para todas las pestañas
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildKinematicsTab(colors),
                  _buildLoadsTab(colors),
                  _buildVelocityTab(colors),
                ],
              ),
            ),
          ),

          // ── Layer 1: Persistent Biomechanical Stage (Video + Skeleton) ──
          if (_videoController != null && _videoController!.value.isInitialized)
            _buildBiomechanicalStage(size, expandedHeight, collapsedHeight),

          // ── Layer 2: Floating Header with Identity ──
          _buildFloatingHeader(context),
          
          // Play/Pause Overlay (Only when in video mode)
          if (!_isPlaying && _scrollProgress < 0.3)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBiomechanicalStage(Size size, double expandedHeight, double collapsedHeight) {
    // Aplicamos un factor de 1.5x para que la transición (encogimiento) ocurra más rápido
    final p = (_scrollProgress * 1.5).clamp(0.0, 1.0);
    final t = 1.0 - p; // t=1 expanded, t=0 collapsed
    
    // Geometry sync: Both video and skeleton live in this 1080x1920 box
    final double videoWidth = _videoController?.value.size.width ?? 1080;
    final double videoHeight = _videoController?.value.size.height ?? 1920;
    
    // PiP transition logic
    final double scale = 1.0 - (0.65 * p); // Escalar al 35%
    
    // Al colapsar (p=1), queremos que el centro del video escalado quede en el centro 
    // del espacio DISPONIBLE debajo del header.
    final double topPadding = MediaQuery.of(context).padding.top;
    final double headerHeight = topPadding + 64; // Estimación del alto del header
    
    // Centro del espacio entre el header y el final de collapsedHeight
    final double targetCenterY = (headerHeight + collapsedHeight) / 2;
    final double targetY = targetCenterY - (expandedHeight / 2);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: expandedHeight + 2, // Overlap de seguridad para evitar la línea de 1px
      child: ClipRect(
        child: IgnorePointer(
          ignoring: p > 0.5,
          child: Transform.translate(
            offset: Offset(0, targetY * p),
            child: Container(
              width: size.width,
              height: expandedHeight + 2,
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform.scale(
                  scale: scale,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: videoWidth,
                      height: videoHeight,
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: Stack(
                          children: [
                            // 1. Video Layer (Fades out)
                            Opacity(
                              opacity: t,
                              child: GestureDetector(
                                onTap: _togglePlayPause,
                                child: VideoPlayer(_videoController!),
                              ),
                            ),
                            // 2. Skeleton Layer (Always visible, perfectly synced)
                            if (_nativeEngineReady)
                              NativeSkeletonOverlay(
                                currentPositionMs: _interpolatedPositionMs,
                                isActive: true,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final blurSigma = 20.0 * _scrollProgress;
    final bgOpacity = 0.75 * _scrollProgress;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurSigma.clamp(0.01, 25.0),
            sigmaY: blurSigma.clamp(0.01, 25.0),
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(12, topPadding + 8, 20, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: bgOpacity),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15 * _scrollProgress),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 14),
                // LIFTSENSE brand mark
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      fontSize: 16,
                    ),
                    children: [
                      TextSpan(
                        text: 'LIFT',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                      const TextSpan(
                        text: 'SENSE',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Exercise info (right-aligned)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.exerciseName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            widget.viewTag,
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.captureDate,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Timeline ───────────────────────────────────────────
  Widget _buildPhaseTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LÍNEA DE TIEMPO',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Colors.white54,
              ),
            ),
            Text(
              '${(_playbackProgress * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Barra de progreso
        Container(
          height: 32,
          clipBehavior: Clip.antiAlias, // Recorta las fases internas a la forma pill
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: const Border(
              top: BorderSide(color: Color(0x0DFFFFFF), width: 1),
            ),
          ),
          child: Stack(
            children: [
              // Fondos de Fases
              Row(
                children: _phases.asMap().entries.map((entry) {
                  final p = entry.value;
                  final isLast = entry.key == _phases.length - 1;
                  return Expanded(
                    flex: ((p.endPercent - p.startPercent) * 1000).toInt(),
                    child: GestureDetector(
                      onTap: () => _seekToPhase(p.startPercent),
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.color.withValues(alpha: 0.15),
                          border: isLast ? null : const Border(
                            right: BorderSide(color: Colors.black26, width: 1.0),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            p.label,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: p.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Indicador actual
              Positioned.fill(
                child: LayoutBuilder(builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned(
                        left: constraints.maxWidth * _playbackProgress - 2,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 6)
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _seekToPhase(double percent) {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    final dur = _videoController!.value.duration;
    _videoController!.seekTo(Duration(milliseconds: (dur.inMilliseconds * percent).toInt()));
  }

  // ─── Pills ──────────────────────────────────────────────
  Widget _buildJointAnglePills(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÁNGULOS EN TIEMPO REAL',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _currentAngles.asMap().entries.map((entry) {
            final a = entry.value;
            final isLast = entry.key == _currentAngles.length - 1;
            final isOk = a.status == 'optimal';
            final color = isOk ? const Color(0xFF00D4AA) : const Color(0xFFFFB627);
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: isLast ? 0 : 8),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(14),
                  border: Border(
                    top: BorderSide(color: color, width: 2.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      a.joint.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white54,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${a.angle.toStringAsFixed(0)}°',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOk ? 'ÓPTIMO' : 'ATENCIÓN',
                        style: GoogleFonts.inter(
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Tab Contents ───────────────────────────────────────
  Widget _buildKinematicsTab(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100), // Padding inferior generoso
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
        _buildRomSummary(colors),
      ],
    );
  }

  Widget _buildLoadsTab(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        _buildSectionLabel('CARGAS ARTICULARES'),
        const SizedBox(height: 10),
        const JointLoadsChart(),
        const SizedBox(height: 32),
        _buildSectionLabel('TORQUE MÁXIMO POR ARTICULACIÓN'),
        const SizedBox(height: 10),
        _buildTorqueSummary(colors),
      ],
    );
  }

  Widget _buildVelocityTab(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        _buildSectionLabel('PERFIL VBT MPV'),
        const SizedBox(height: 10),
        const VelocityTrainingChart(),
        const SizedBox(height: 32),
        _buildSectionLabel('MÉTRICAS DE RENDIMIENTO'),
        const SizedBox(height: 10),
        _buildVbtMetrics(colors),
      ],
    );
  }

  Widget _buildSectionLabel(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: Colors.white54,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
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
                          fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      d['rom'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5),
                    ),
                  ),
                  Text(d['ref'] as String,
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white30)),
                  const SizedBox(width: 12),
                  Icon(
                    isOk ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: isOk ? const Color(0xFF00D4AA) : const Color(0xFFFFB627),
                    size: 20,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
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
                          fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white54),
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
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
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
          _vbtCard('V. MEDIA', '0.68 m/s', const Color(0xFF00D4AA)),
          const SizedBox(width: 12),
          _vbtCard('V. PICO', '0.92 m/s', const Color(0xFF007BFF)),
          const SizedBox(width: 12),
          _vbtCard('DROP-OFF', '-28%', const Color(0xFFFFB627)),
        ],
      );

  Widget _vbtCard(String label, String value, Color accent) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
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
                      color: Colors.white54,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5)),
            ],
          ),
        ),
      );
}

// ─── Sticky Tab Bar Delegate ──────────────────────────────
class _SolidStickyTimelineDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _SolidStickyTimelineDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Stack(
        children: [
          Positioned.fill(
            top: -2, // Aumentado para sellar con el esqueleto de arriba
            bottom: -2,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xD9101012),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SolidStickyTimelineDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class _SolidStickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final PreferredSizeWidget child;

  _SolidStickyTabBarDelegate(this.child);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: Stack(
        children: [
          // Capa de Glass con overlap en ambos sentidos para evitar costuras
          Positioned.fill(
            top: -1,
            bottom: -1, 
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF101012).withValues(alpha: 0.85),
                  border: const Border(
                    bottom: BorderSide(
                      color: Color(0x0DFFFFFF),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Las pestañas reales
          child,
        ],
      ),
    );
  }

  @override
  double get maxExtent => child.preferredSize.height;

  @override
  double get minExtent => child.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SolidStickyTabBarDelegate oldDelegate) =>
      oldDelegate.child != child;
}
