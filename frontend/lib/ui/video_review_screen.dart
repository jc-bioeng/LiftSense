import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../services/post_processing_service.dart';
import '../services/local_database_service.dart';
import 'analysis/config/biomech_colors.dart';
import 'analysis/screen/analysis_screen.dart';
import 'package:intl/intl.dart';

class VideoReviewScreen extends StatefulWidget {
  final String videoPath;
  const VideoReviewScreen({super.key, required this.videoPath});

  @override
  State<VideoReviewScreen> createState() => _VideoReviewScreenState();
}

class _VideoReviewScreenState extends State<VideoReviewScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    try {
      await _controller.initialize();
      _controller.setLooping(true);
      _controller.play();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error init review video: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _triggerAnalysisExtraction(BuildContext context) {
    HapticFeedback.selectionClick();

    // Mostrar diálogo de carga clínica real con indicador activo
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          width: 310,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: BiomechColors.optimal),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'PROCESANDO BIOMECÁNICA',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
              const SizedBox(height: 16),
              Text(
                'Ejecutando motor de inferencia MediaPipe...\nFiltrando One-Euro y analizando ángulos en Python...',
                style: GoogleFonts.inter(fontSize: 9, color: Colors.white54, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Invocar el procesamiento real asíncrono
    PostProcessingService.instance.processVideo(widget.videoPath).then((result) {
      if (!mounted) return;
      navigator.pop(); // Cerrar el diálogo de carga

      if (result.success) {
        // 1. Formatear la fecha actual hermosamente en español
        final now = DateTime.now();
        final DateFormat formatter = DateFormat("dd MMM, hh:mm a");
        final formattedDate = formatter.format(now);

        // 2. Persistir en la base de datos local Hive
        LocalDatabaseService.instance.saveRecord(
          date: formattedDate,
          tag: result.viewTag,
          maxTrunkAngle: result.maxTrunkAngle,
          videoPath: result.videoPath,
          csvPath: result.csvPath,
        );

        // 3. Enrutamiento con archivos calculados reales
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => AnalysisScreen(
              videoPath: result.videoPath,
              csvPath: result.csvPath,
              exerciseName: 'BACK SQUAT',
              viewTag: result.viewTag,
              captureDate: formattedDate,
            ),
          ),
        );
      } else {
        // Notificar fallo y enrutar a assets simulados como fallback
        debugPrint('[VideoReviewScreen] Post-processing failed: ${result.error}');
        
        scaffoldMessenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF2A4D),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            content: Text(
              'Error en motor de Python. Usando simulación de laboratorio.\nDetalle: ${result.error}',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
            ),
          ),
        );

        // Fallback a archivos demo
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AnalysisScreen(
              videoPath: 'frontal_lstrack.mp4',
              csvPath: 'frontal_lstrack.csv',
              exerciseName: 'BACK SQUAT',
              viewTag: 'FRONTAL',
              captureDate: 'Simulación (Fallback)',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Color(0xFF00D4AA))),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildReviewHeader(context),
          ),

          if (_isInitialized)
            Positioned(
              bottom: 100,
              left: 24,
              right: 24,
              child: _buildTimeline(),
            ),

          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: _buildActionButtons(context),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
        child: Container(
          padding: EdgeInsets.fromLTRB(12, topPadding + 8, 20, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withValues(alpha: 0.6),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                  Navigator.pop(context);
                },
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'REVISIÓN DE CAPTURA',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
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
                      'POST-PROCESAMIENTO',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header y tiempo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.movie_filter_rounded, color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'SCRUBBER (60FPS)',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, VideoPlayerValue value, child) {
                  return Text(
                    '${(value.position.inMilliseconds / 1000).toStringAsFixed(2)}s / ${(value.duration.inMilliseconds / 1000).toStringAsFixed(2)}s',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Slider
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, VideoPlayerValue value, child) {
              final position = value.position.inMilliseconds.toDouble();
              final duration = value.duration.inMilliseconds.toDouble();
              return SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: Colors.white10,
                  thumbColor: Colors.white,
                  overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: position.clamp(0.0, duration > 0 ? duration : 1.0),
                  min: 0.0,
                  max: duration > 0 ? duration : 1.0,
                  onChanged: (val) {
                    _controller.seekTo(Duration(milliseconds: val.toInt()));
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          
          // Controles Playback
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlBtn(Icons.skip_previous_rounded, () {
                final pos = _controller.value.position.inMilliseconds;
                _controller.seekTo(Duration(milliseconds: (pos - 17).clamp(0, _controller.value.duration.inMilliseconds)));
              }),
              const SizedBox(width: 24),
              ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, VideoPlayerValue value, child) {
                  final isPlaying = value.isPlaying;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      isPlaying ? _controller.pause() : _controller.play();
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 24),
              _buildControlBtn(Icons.skip_next_rounded, () {
                final pos = _controller.value.position.inMilliseconds;
                _controller.seekTo(Duration(milliseconds: (pos + 17).clamp(0, _controller.value.duration.inMilliseconds)));
              }),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _controller.pause(); // Auto-pause when stepping
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'DESCARTAR',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _triggerAnalysisExtraction(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.analytics_rounded, color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'ANALIZAR',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
