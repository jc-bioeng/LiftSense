import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:shimmer/shimmer.dart';
import '../l10n/app_localizations.dart';
import '../localization/locale_provider.dart';
import '../main.dart'; // Para routeObserver
import 'settings_screen.dart';
import 'analysis/screen/analysis_screen.dart';
import '../services/app_assets_manager.dart';
import '../services/local_database_service.dart';
import 'sensor_capture_screen.dart';

class SquatRecord {
  final String date;
  final String tag;
  final String maxTrunkAngle;
  final String videoPath;
  final String previewVideoPath;
  final String csvPath;
  const SquatRecord(this.date, this.tag, this.maxTrunkAngle, this.videoPath, this.previewVideoPath, this.csvPath);
}

final List<SquatRecord> _mockHistory = [
  const SquatRecord('Hoy, 09:41 AM', 'FRONTAL', '46°', 'frontal_lstrack.mp4', 'frontal_lstrack.mp4', 'frontal_lstrack.csv'),
  const SquatRecord('Ayer, 04:20 PM', 'LATERAL', '40°', 'lateral_lstrack.mp4', 'lateral_lstrack.mp4', 'lateral_lstrack.csv'),
  const SquatRecord('Mar 14, 06:15 AM', 'POSTERIOR', '43°', 'posterior_lstrack.mp4', 'posterior_lstrack.mp4', 'posterior_lstrack.csv'),
];

class DashboardScreen extends StatefulWidget {
  final LocaleProvider localeProvider;
  const DashboardScreen({super.key, required this.localeProvider});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late ScrollController _scrollController;
  List<SquatRecord> _sessions = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    AppAssetsManager.instance.restoreAssetsIfMissing();
    _loadSessions();
  }

  void _loadSessions() {
    final saved = LocalDatabaseService.instance.savedRecords;
    final converted = saved
        .where((item) {
          final tag = (item['tag'] ?? '').toString().toUpperCase();
          return tag != 'CARAC' && tag != 'CALIBRADO' && tag != 'CALIBRACIÓN';
        })
        .map((item) {
          return SquatRecord(
            item['date'] ?? '',
            item['tag'] ?? 'CALCULADO',
            item['maxTrunkAngle'] ?? '40°',
            item['videoPath'] ?? '',
            item['previewVideoPath'] ?? '',
            item['csvPath'] ?? '',
          );
        }).toList();

    setState(() {
      _sessions = [...converted, ..._mockHistory];
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent, // El color es manejado por el Container interno
            expandedHeight: 120, // Altura ampliada para Large Title
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Cálculo paramétrico super eficiente aislado del rest del widget tree
                final top = constraints.biggest.height;
                final expandDelta = 120.0 + MediaQuery.of(context).padding.top;
                final collapseDelta = kToolbarHeight + MediaQuery.of(context).padding.top;
                
                // Calcular opacidad sin triggear un Rebuild de Android/iOS global
                final percentage = ((expandDelta - top) / (expandDelta - collapseDelta)).clamp(0.0, 1.0);

                return ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 25 * percentage, // Blur reactivo hardware-accelerated
                      sigmaY: 25 * percentage,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E).withValues(alpha: 0.75 * percentage), // Acrílico
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15 * percentage), // Infinity Edge dinámico
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        expandedTitleScale: 1.4,
                        title: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                              fontSize: 24, // Forzando tamaño estándar
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
                      ),
                    ),
                  ),
                );
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_sharp, color: Colors.white70), // Neutralizado para evitar fatiga visual
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(localeProvider: widget.localeProvider),
                    ),
                  ).then((_) => _loadSessions());
                },
              )
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   SizedBox(height: MediaQuery.of(context).padding.top + 16),
                // Main Action Card
                GestureDetector(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SensorCaptureScreen(),
                      ),
                    ).then((_) => _loadSessions());
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181A), // Superficie elevada sobre fondo 0A0A0C
                      borderRadius: BorderRadius.circular(24),
                      border: Border(
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1), // Efecto Bisel 3D
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4), // Sombra más contenida para no invadir el margin inferior
                        )
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 28), // Restaurado a cámara de vídeo
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "MODO LABORATORIO",
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.initSquatRecord,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // TU PROGRESO Component
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'TU PROGRESO',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '// ÚLTIMOS 7 DÍAS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                        color: Colors.white30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416), // Un paso sobre el fondo
                    borderRadius: BorderRadius.circular(16),
                    border: Border(
                      top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1), // Iluminación superior
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INCLINACIÓN DE TRONCO PROM.',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '40.5°',
                            style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rango óptimo: 35°–45°  ✓',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary, // Fondo sólido = contraste máximo
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.trending_down_rounded, color: const Color(0xFF0A0A0C), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '-2.3°',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0A0A0C), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'SESIONES RECIENTES',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  padding: EdgeInsets.zero, // CRÍTICO: Elimina el espacio fantasma de los ListViews en Flutter
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final record = _sessions[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnalysisScreen(
                              videoPath: record.videoPath,
                              csvPath: record.csvPath,
                              exerciseName: 'BACK SQUAT',
                              viewTag: record.tag,
                              captureDate: record.date,
                            ),
                          ),
                        ).then((_) => _loadSessions());
                      },
                      child: _buildHistoryCard(context, index, record),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildHistoryCard(BuildContext context, int index, SquatRecord record) {
    return HistoryCardWidget(
      index: index,
      record: record,
      totalLength: _sessions.length,
    );
  }

}

class HistoryCardWidget extends StatefulWidget {
  final int index;
  final SquatRecord record;
  final int totalLength;

  const HistoryCardWidget({
    super.key,
    required this.index,
    required this.record,
    required this.totalLength,
  });

  @override
  State<HistoryCardWidget> createState() => _HistoryCardWidgetState();
}

class _HistoryCardWidgetState extends State<HistoryCardWidget> with RouteAware {
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void initState() {
    super.initState();
    // Staggered initialization: wait (index + 1) * 500ms to avoid overloading
    Future.delayed(Duration(milliseconds: (widget.index + 1) * 500), () {
      if (mounted) _initVideo();
    });
  }

  @override
  void didPushNext() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    if (mounted) setState(() => _videoReady = false);
  }

  @override
  void didPopNext() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _initVideo();
    });
  }

  Future<void> _initVideo() async {
    if (_videoController != null) return;
    
    final path = await AppAssetsManager.instance.resolveFilePath(widget.record.previewVideoPath);
    if (path == null) {
      debugPrint('Video path not found for: ${widget.record.previewVideoPath}');
      return;
    }
    final file = File(path);
    if (!file.existsSync()) return;

    final controller = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.setVolume(0);
      controller.setLooping(true);
      controller.play();
      setState(() {
        _videoController = controller;
        _videoReady = true;
      });
    } catch (e) {
      debugPrint('Error init video Dashboard: $e');
      controller.dispose();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('history_card_${widget.index}'),
      onVisibilityChanged: (info) {
        if (!mounted || _videoController == null) return;
        if (info.visibleFraction == 0) {
          _videoController?.pause();
        } else {
          _videoController?.play();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.8,
          ),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF141416),
              const Color(0xFF1C1C1E).withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Video de fondo con opacidad baja
            if (_videoReady && _videoController != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.15,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                ),
              )
            else
              // Shimmer effect while video is loading
              Positioned.fill(
                child: Shimmer.fromColors(
                  baseColor: const Color(0xFF1A1A1A),
                  highlightColor: const Color(0xFF2A2A2A),
                  period: const Duration(milliseconds: 1500),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Glassmorphic index badge
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 0.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '0${widget.totalLength - widget.index}',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'BACK SQUAT',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: widget.record.tag == 'PR' || widget.record.tag == 'POSTERIOR'
                                    ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15)
                                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: widget.record.tag == 'PR' || widget.record.tag == 'POSTERIOR'
                                      ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.4)
                                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                widget.record.tag,
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  color: widget.record.tag == 'PR' || widget.record.tag == 'POSTERIOR'
                                      ? Theme.of(context).colorScheme.tertiary
                                      : Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.record.date,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.record.maxTrunkAngle,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'INCLINACIÓN',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
