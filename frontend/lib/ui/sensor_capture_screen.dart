import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../ui/analysis/config/biomech_colors.dart';
import 'video_review_screen.dart';

/// Vista de la Guía Biomecánica
enum CalibrationView {
  frontal,
  lateral,
}

/// Caracterización antropométrica real del usuario a partir del CSV de calibración
class UserBodyProfile {
  final double craniumHeight;
  final double shoulderWidth;
  final double pelvicWidth;
  final double spineLength;
  final double humerusLength;
  final double radiusLength;
  final double femurLength;
  final double tibiaLength;
  final double footLength;
  
  const UserBodyProfile({
    required this.craniumHeight,
    required this.shoulderWidth,
    required this.pelvicWidth,
    required this.spineLength,
    required this.humerusLength,
    required this.radiusLength,
    required this.femurLength,
    required this.tibiaLength,
    required this.footLength,
  });

  static const defaultProfile = UserBodyProfile(
    craniumHeight: 50.0,
    shoulderWidth: 110.0,
    pelvicWidth: 80.0,
    spineLength: 132.0,
    humerusLength: 90.0,
    radiusLength: 80.0,
    femurLength: 155.0,
    tibiaLength: 160.0,
    footLength: 30.0,
  );
}

class SensorCaptureScreen extends StatefulWidget {
  const SensorCaptureScreen({super.key});

  @override
  State<SensorCaptureScreen> createState() => _SensorCaptureScreenState();
}

class _SensorCaptureScreenState extends State<SensorCaptureScreen> 
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _timer;
  bool _isCameraInitialized = false;

  // Pulse controller for clinical HUD blinking animations
  late AnimationController _pulseController;

  // Caracterización antropométrica real cargada del CSV
  UserBodyProfile _bodyProfile = UserBodyProfile.defaultProfile;

  // ─── Estado de la Guía Biomecánica ───────────────────
  CalibrationView _currentView = CalibrationView.frontal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Initialize clinical pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _initCamera();
    _loadCalibrationBodyProfile();
  }

  Future<void> _loadCalibrationBodyProfile() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File('${docsDir.path}/carac_lstrack.csv');
      if (!await file.exists()) {
        debugPrint('[SensorCaptureScreen] carac_lstrack.csv not found in documents.');
        return;
      }
      
      final lines = await file.readAsLines();
      if (lines.length <= 1) return;
      
      final header = lines[0].split(',');
      final colMap = <String, int>{};
      for (int i = 0; i < header.length; i++) {
        colMap[header[i].trim()] = i;
      }
      
      // Tomamos la fila 1 (primer frame) para extraer las medidas reales en píxeles del usuario
      final row = lines[1].split(',');
      
      double getX(String kp) => double.tryParse(row[colMap['${kp}_x'] ?? 0]) ?? 0.0;
      double getY(String kp) => double.tryParse(row[colMap['${kp}_y'] ?? 0]) ?? 0.0;
      
      double dist(double x1, double y1, double x2, double y2) {
        return math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
      }

      final double lShX = getX('l_shoulder');
      final double lShY = getY('l_shoulder');
      final double rShX = getX('r_shoulder');
      final double rShY = getY('r_shoulder');

      final double lHpX = getX('l_hip');
      final double lHpY = getY('l_hip');
      final double rHpX = getX('r_hip');
      final double rHpY = getY('r_hip');

      final double lKnX = getX('l_knee');
      final double lKnY = getY('l_knee');

      final double lAnX = getX('l_ankle');
      final double lAnY = getY('l_ankle');

      final double lElX = getX('l_elbow');
      final double lElY = getY('l_elbow');

      final double lWrX = getX('l_wrist');
      final double lWrY = getY('l_wrist');

      final double noseX = getX('nose');
      final double noseY = getY('nose');

      // Calcular dimensiones crudas del usuario en pixeles
      final double rawShoulderWidth = dist(lShX, lShY, rShX, rShY);
      final double rawPelvicWidth = dist(lHpX, lHpY, rHpX, rHpY);
      
      final double midShX = (lShX + rShX) / 2;
      final double midShY = (lShY + rShY) / 2;
      final double midHpX = (lHpX + rHpX) / 2;
      final double midHpY = (lHpY + rHpY) / 2;
      final double rawSpineLength = dist(midShX, midShY, midHpX, midHpY);

      final double rawFemurLength = dist(lHpX, lHpY, lKnX, lKnY);
      final double rawTibiaLength = dist(lKnX, lKnY, lAnX, lAnY);
      final double rawHumerusLength = dist(lShX, lShY, lElX, lElY);
      final double rawRadiusLength = dist(lElX, lElY, lWrX, lWrY);
      final double rawCraniumHeight = dist(noseX, noseY, midShX, midShY) * 0.8;

      // Escalado paramétrico de calibración: hombros = 110.0 pixeles en pantalla
      const double targetShoulderWidth = 110.0;
      final double scale = targetShoulderWidth / (rawShoulderWidth > 0 ? rawShoulderWidth : 1.0);

      setState(() {
        _bodyProfile = UserBodyProfile(
          craniumHeight: (rawCraniumHeight * scale).clamp(35.0, 65.0),
          shoulderWidth: targetShoulderWidth,
          pelvicWidth: (rawPelvicWidth * scale).clamp(65.0, 95.0),
          spineLength: (rawSpineLength * scale).clamp(100.0, 160.0),
          humerusLength: (rawHumerusLength * scale).clamp(70.0, 110.0),
          radiusLength: (rawRadiusLength * scale).clamp(60.0, 100.0),
          femurLength: (rawFemurLength * scale).clamp(120.0, 180.0),
          tibiaLength: (rawTibiaLength * scale).clamp(120.0, 185.0),
          footLength: 30.0,
        );
      });
      debugPrint('[SensorCaptureScreen] Real user measurements loaded successfully from CSV calibration!');
    } catch (e) {
      debugPrint('[SensorCaptureScreen] Error loading body profile: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      
      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _switchView(CalibrationView view) {
    if (_isRecording) return;
    setState(() {
      _currentView = view;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pulseController.dispose();
    _controller?.dispose();
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  void _startTimer() {
    _recordDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() {
        _recordDuration++;
      });
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isRecordingVideo) {
      return;
    }
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
      _startTimer();
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      return;
    }
    try {
      final XFile videoFile = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });
      _timer?.cancel();
      HapticFeedback.heavyImpact();
      
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoReviewScreen(videoPath: videoFile.path),
        ),
      );
    } catch (e) {
      debugPrint('Error stopping record: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D4AA)),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview
          Positioned.fill(
            child: ClipRect(
              child: Transform.scale(
                scale: scale,
                child: Center(
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
          
          // 2. Silueta Guía Realista e Indicador de Plomada (Esqueleto Anatómico)
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _isRecording ? 0.0 : 1.0,
              child: CustomPaint(
                painter: CalibrationGuidePainter(
                  view: _currentView,
                  profile: _bodyProfile,
                  isRecording: _isRecording,
                ),
              ),
            ),
          ),

          // 3. Grid de Alineación Clínico
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(isRecording: _isRecording),
            ),
          ),

          // 4. Selector de Vista Clínico (Simulador en la barra superior)
          Positioned(
            top: 100,
            left: 24,
            right: 24,
            child: Center(
              child: _buildViewSelector(context),
            ),
          ),

          // 5. Elegant Single-Line Glassmorphic Crystal Status Pill (Movido a la parte superior para no tapar el esqueleto)
          Positioned(
            top: 155,
            left: 24,
            right: 24,
            child: _buildCrystalStatusPill(context),
          ),

          // 6. Encabezado Clínico de Captura
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildCameraHeader(context),
          ),

          // 7. Botón Grabador Clínico (Siempre habilitado)
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isRecording ? Colors.redAccent : const Color(0xFF00D4AA),
                        width: 3,
                      ),
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _isRecording ? 28 : 54,
                        height: _isRecording ? 28 : 54,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.redAccent : const Color(0xFF00D4AA),
                          borderRadius: BorderRadius.circular(_isRecording ? 6 : 27),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Componente: Selector de Vista Clínico ─────────────────
  Widget _buildViewSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSelectorTab('FRONTAL', CalibrationView.frontal),
          _buildSelectorTab('LATERAL', CalibrationView.lateral),
        ],
      ),
    );
  }

  Widget _buildSelectorTab(String text, CalibrationView view) {
    final bool active = _currentView == view;
    return GestureDetector(
      onTap: () => _switchView(view),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active 
              ? BiomechColors.optimal.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: active 
              ? Border.all(
                  color: BiomechColors.optimal,
                  width: 1,
                )
              : null,
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            color: active ? Colors.white : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  // ─── Componente: Encabezado Clínico de Captura ─────────────────
  Widget _buildCameraHeader(BuildContext context) {
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
                    'MODO LABORATORIO',
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
                          _currentView == CalibrationView.frontal ? 'FRONTAL' : 'LATERAL',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isRecording) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(_recordDuration),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'SENSOR ACTIVO',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Componente: Elegant Single-Line Glassmorphic Crystal Status Pill ─────
  Widget _buildCrystalStatusPill(BuildContext context) {
    final String text = _isRecording ? "RECORDING KINEMATICS..." : "SYSTEM READY";
    final Color color = _isRecording ? Colors.redAccent : const Color(0xFF00D4AA);
    final bool pulse = _isRecording;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final double pulseVal = pulse ? (0.4 + 0.6 * _pulseController.value) : 1.0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: pulseVal,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      text,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Custom Painter: Siluetas Guías Vectoriales Clínicas ───────
class CalibrationGuidePainter extends CustomPainter {
  final CalibrationView view;
  final UserBodyProfile profile;
  final bool isRecording;

  CalibrationGuidePainter({
    required this.view,
    required this.profile,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double spineY = cy - profile.spineLength;

    // Conexiones idénticas a AnalysisScreen
    const List<List<int>> connections = [
      [0,1],[0,2],[1,2], [1,3],[3,5], [2,4],[4,6],
      [1,7],[2,8],[7,8], [7,9],[9,11], [8,10],[10,12],
      [11,13],[13,15],[11,15], [12,14],[14,16],[12,16],
    ];



    List<Offset?> pts = List.filled(17, null);

    if (view == CalibrationView.frontal) {
      // Nodos Frontales (17 keypoints)
      pts[0] = Offset(cx, spineY - profile.craniumHeight + 15); // nose
      pts[1] = Offset(cx - profile.shoulderWidth / 2, spineY); // l_shoulder
      pts[2] = Offset(cx + profile.shoulderWidth / 2, spineY); // r_shoulder
      
      pts[3] = Offset(pts[1]!.dx - 15, pts[1]!.dy + profile.humerusLength); // l_elbow
      pts[4] = Offset(pts[2]!.dx + 15, pts[2]!.dy + profile.humerusLength); // r_elbow
      
      pts[5] = Offset(pts[3]!.dx - 5, pts[3]!.dy + profile.radiusLength); // l_wrist
      pts[6] = Offset(pts[4]!.dx + 5, pts[4]!.dy + profile.radiusLength); // r_wrist

      pts[7] = Offset(cx - profile.pelvicWidth / 2, cy); // l_hip
      pts[8] = Offset(cx + profile.pelvicWidth / 2, cy); // r_hip

      pts[9] = Offset(pts[7]!.dx - 5, pts[7]!.dy + profile.femurLength); // l_knee
      pts[10] = Offset(pts[8]!.dx + 5, pts[8]!.dy + profile.femurLength); // r_knee

      pts[11] = Offset(pts[9]!.dx - 5, pts[9]!.dy + profile.tibiaLength); // l_ankle
      pts[12] = Offset(pts[10]!.dx + 5, pts[10]!.dy + profile.tibiaLength); // r_ankle

      pts[13] = Offset(pts[11]!.dx, pts[11]!.dy + 5); // l_heel
      pts[14] = Offset(pts[12]!.dx, pts[12]!.dy + 5); // r_heel

      pts[15] = Offset(pts[11]!.dx - 10, pts[11]!.dy + 15); // l_foot_index
      pts[16] = Offset(pts[12]!.dx + 10, pts[12]!.dy + 15); // r_foot_index

    } else if (view == CalibrationView.lateral) {
      // Nodos Laterales (17 keypoints - Puntos izquierdos superpuestos o ignorados)
      pts[0] = Offset(cx - 20, spineY - profile.craniumHeight + 15); // nose
      pts[1] = Offset(cx, spineY); // l_shoulder
      pts[2] = Offset(cx, spineY); // r_shoulder
      
      pts[3] = Offset(cx - 15, spineY + profile.humerusLength); // l_elbow
      pts[4] = Offset(cx - 15, spineY + profile.humerusLength); // r_elbow
      
      pts[5] = Offset(pts[3]!.dx + 10, pts[3]!.dy + profile.radiusLength); // l_wrist
      pts[6] = Offset(pts[4]!.dx + 10, pts[4]!.dy + profile.radiusLength); // r_wrist

      pts[7] = Offset(cx, cy); // l_hip
      pts[8] = Offset(cx, cy); // r_hip

      pts[9] = Offset(cx + 10, cy + profile.femurLength); // l_knee
      pts[10] = Offset(cx + 10, cy + profile.femurLength); // r_knee

      pts[11] = Offset(cx, pts[9]!.dy + profile.tibiaLength); // l_ankle
      pts[12] = Offset(cx, pts[10]!.dy + profile.tibiaLength); // r_ankle

      pts[13] = Offset(pts[11]!.dx + 10, pts[11]!.dy + 10); // l_heel
      pts[14] = Offset(pts[12]!.dx + 10, pts[12]!.dy + 10); // r_heel

      pts[15] = Offset(pts[11]!.dx - 25, pts[11]!.dy + 10); // l_foot_index
      pts[16] = Offset(pts[12]!.dx - 25, pts[12]!.dy + 10); // r_foot_index
      
      // Línea de plomada referencial sutil
      final Paint plumbPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..strokeWidth = 1.0;
        
      for (double y = cy - 250; y < cy + 300; y += 15) {
        canvas.drawLine(Offset(cx, y), Offset(cx, y + 8), plumbPaint);
      }
    }

    final paint = Paint()..strokeCap = StrokeCap.round;
    final double alpha = isRecording ? 0.3 : 0.85;
    final Color clinicalGreen = const Color(0xFF00D4AA).withValues(alpha: alpha);

    // Dibujar líneas de conexión
    for (int i = 0; i < connections.length; i++) {
      final p1 = pts[connections[i][0]];
      final p2 = pts[connections[i][1]];
      if (p1 == null || p2 == null) continue;
      
      canvas.drawLine(p1, p2, paint..color = clinicalGreen..strokeWidth = 3.5);
    }

    // Dibujar articulaciones (nodos)
    final jointPaint = Paint()
      ..color = Colors.black.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    final jointBorder = Paint()
      ..color = clinicalGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final p in pts) {
      if (p != null) {
        canvas.drawCircle(p, 4.0, jointPaint);
        canvas.drawCircle(p, 4.0, jointBorder);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CalibrationGuidePainter old) =>
      old.view != view || old.profile != profile || old.isRecording != isRecording;
}

// ─── Custom Painter: Grid de Alineación de Cámara ────────────
class GridPainter extends CustomPainter {
  final bool isRecording;

  GridPainter({this.isRecording = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, 2 * size.height / 3), Offset(size.width, 2 * size.height / 3), paint);

    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(2 * size.width / 3, 0), Offset(2 * size.width / 3, size.height), paint);
    
    final centerPaint = Paint()
      ..color = isRecording 
          ? Colors.redAccent.withValues(alpha: 0.5)
          : const Color(0xFF00D4AA).withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    
    final cx = size.width / 2;
    final cy = size.height / 2;
    
    // Cruz central
    canvas.drawLine(Offset(cx - 15, cy), Offset(cx + 15, cy), centerPaint);
    canvas.drawLine(Offset(cx, cy - 15), Offset(cx, cy + 15), centerPaint);

    // Box central de alineación
    final alignRectPaint = Paint()
      ..color = isRecording 
          ? Colors.redAccent.withValues(alpha: 0.04)
          : const Color(0xFF00D4AA).withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy + 20), width: size.width * 0.4, height: size.height * 0.72),
      alignRectPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy + 20), width: size.width * 0.4, height: size.height * 0.72),
      Paint()
        ..color = isRecording ? Colors.redAccent.withValues(alpha: 0.15) : const Color(0xFF00D4AA).withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
