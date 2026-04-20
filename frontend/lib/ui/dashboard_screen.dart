import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../l10n/app_localizations.dart';
import '../localization/locale_provider.dart';
import 'settings_screen.dart';
import 'analysis_screen.dart';

class SquatRecord {
  final String date;
  final String tag;
  final String maxTrunkAngle;
  final String videoPath;
  final String previewVideoPath;
  const SquatRecord(this.date, this.tag, this.maxTrunkAngle, this.videoPath, this.previewVideoPath);
}

final List<SquatRecord> _mockHistory = [
  const SquatRecord('Hoy, 09:41 AM', 'PR', '46°', 'mockup_squat.mp4', 'mockup_squat.mp4'),
  const SquatRecord('Ayer, 04:20 PM', 'WARM', '40°', 'squat_1.mp4', 'squat_1_out.mp4'),
  const SquatRecord('Mar 14, 06:15 AM', 'RAW', '43°', 'squat_2.mp4', 'squat_2_out.mp4'),
  const SquatRecord('Mar 10, 08:30 PM', 'HEAVY', '48°', 'squat_3.mp4', 'squat_3_out.mp4'),
];

class DashboardScreen extends StatefulWidget {
  final LocaleProvider localeProvider;
  const DashboardScreen({super.key, required this.localeProvider});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late ScrollController _scrollController;


  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // setState eliminado: ¡Esto detiene los re-renderizados de toda la página y salva la batería/CPU!
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
                  );
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
                    _showCaptureBottomSheet(context);
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
                _buildRecentSessions(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildRecentSessions() {
    return Column(
      children: _mockHistory.asMap().entries.map((entry) {
        return HistoryCardWidget(
          record: entry.value,
          index: entry.key,
          totalLength: _mockHistory.length,
        );
      }).toList(),
    );
  }

  void _showCaptureBottomSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C0C),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.tertiary, width: 3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.dataOrigin,
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.sagittalRequired,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 32),
              _buildBottomSheetOption(
                context,
                icon: Icons.camera_enhance_sharp,
                title: l10n.liveSensor,
                subtitle: l10n.cameraRt,
                onTap: () => _triggerAnalysisExtration(context),
              ),
              const SizedBox(height: 16),
              _buildBottomSheetOption(
                context,
                icon: Icons.snippet_folder_sharp,
                title: l10n.diskIngest,
                subtitle: l10n.localClip,
                onTap: () => _triggerAnalysisExtration(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetOption(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: Colors.white)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.primary, size: 14),
          ],
        ),
      ),
    );
  }

  void _triggerAnalysisExtration(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.pop(context); // Cerrar bottom sheet

    // Simular Pipeline Logs
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('>> EXTRACTING KINEMATICS', style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              LinearProgressIndicator(color: Theme.of(context).colorScheme.primary, backgroundColor: const Color(0xFF222222)),
              const SizedBox(height: 16),
              Text('Spine [C7_Pelvis] ... [OK]\nComputing Euler ... [WAIT]', style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // cerrar loader
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AnalysisScreen()),
      );
    });
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

class _HistoryCardWidgetState extends State<HistoryCardWidget> {
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    // Inicialización escalonada: cada tarjeta espera index * 600ms
    // Evita la contención simultánea del MediaCodec en dispositivos de gama media
    Future.delayed(Duration(milliseconds: widget.index * 600), () {
      if (mounted) _initVideo();
    });
  }

  Future<void> _initVideo() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File('${docsDir.path}/${widget.record.previewVideoPath}');
    if (!file.existsSync()) return;

    final controller = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
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
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        // SOLUCIÓN RADICAL: Eliminamos el controlador por completo antes de navegar.
        // Algunos dispositivos tienen un límite estricto de MediaCodecs (ej. 4-8)
        // y pausar no siempre libera el hardware inmediatamente.
        if (_videoController != null) {
          final oldController = _videoController;
          setState(() {
            _videoController = null;
            _videoReady = false;
          });
          await oldController!.dispose();
        }
        
        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisScreen(videoPath: widget.record.previewVideoPath),
          ),
        );
        
        // Al volver, reiniciamos el video de la tarjeta
        if (mounted) {
          _initVideo();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF222222),
            width: 1,
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
              Positioned.fill(
                child: Opacity(
                  opacity: 0.10,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
                        ),
                        child: Center(
                          child: Text(
                            '0${widget.totalLength - widget.index}',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: widget.record.tag == 'PR' ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2) : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                border: Border.all(color: widget.record.tag == 'PR' ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary),
                              ),
                              child: Text(
                                widget.record.tag,
                                style: GoogleFonts.inter(fontSize: 9, color: widget.record.tag == 'PR' ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.record.date,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.record.maxTrunkAngle,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.0,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'INCLINACIÓN',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
