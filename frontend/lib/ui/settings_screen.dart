import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../localization/locale_provider.dart';
import '../ui/analysis/config/biomech_colors.dart';
import '../services/local_database_service.dart';
import 'sensor_capture_screen.dart';

enum SettingsView {
  menu,
  bodyData,
  joints,
  calibration,
  language,
  advanced,
}

class SettingsScreen extends StatefulWidget {
  final LocaleProvider localeProvider;

  const SettingsScreen({super.key, required this.localeProvider});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = LocalDatabaseService.instance;
  SettingsView _currentView = SettingsView.menu;

  // ─── Perfil Antropométrico del Usuario ───────────────────────
  late double _height;
  late double _weight;
  late double _humerus;
  late double _femur;
  late double _tibia;
  late double _spine;

  // ─── Variables Avanzadas de Calibración Frontal ──────────────
  late double _hipTolerance;
  late double _shoulderTolerance;
  late double _minStability;
  late double _hipEmaAlpha;

  // ─── Variables Avanzadas de Calibración Lateral ──────────────
  late double _torsoLimitDeg;
  late double _shoulderLock;
  late double _hipLock;
  late double _pseudoZ;

  // ─── Variables Biomecánicas Generales ────────────────────────
  late double _confGuard;
  late double _oneEuroCutoff;
  late double _oneEuroBeta;
  late double _hysteresisMs;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadSettings();
  }

  void _loadSettings() {
    _height = _db.height;
    _weight = _db.weight;
    _humerus = _db.humerus;
    _femur = _db.femur;
    _tibia = _db.tibia;
    _spine = _db.spine;

    _hipTolerance = _db.hipTolerance;
    _shoulderTolerance = _db.shoulderTolerance;
    _minStability = _db.minStability;
    _hipEmaAlpha = _db.hipEmaAlpha;

    _torsoLimitDeg = _db.torsoLimitDeg;
    _shoulderLock = _db.shoulderLock;
    _hipLock = _db.hipLock;
    _pseudoZ = _db.pseudoZ;

    _confGuard = _db.confGuard;
    _oneEuroCutoff = _db.oneEuroCutoff;
    _oneEuroBeta = _db.oneEuroBeta;
    _hysteresisMs = _db.hysteresisMs;
  }

  @override
  Widget build(BuildContext context) {
    // Asegurar que siempre se mantenga el modo inmersivo
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return PopScope(
      canPop: _currentView == SettingsView.menu,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        setState(() {
          _currentView = SettingsView.menu;
        });
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (_currentView != SettingsView.menu) {
                setState(() {
                  _currentView = SettingsView.menu;
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            _getAppBarTitle(),
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _buildCurrentView(),
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentView) {
      case SettingsView.menu:
        return 'Configuración';
      case SettingsView.bodyData:
        return 'Datos corporales';
      case SettingsView.joints:
        return 'Medidas cinemáticas';
      case SettingsView.calibration:
        return 'Calibración';
      case SettingsView.language:
        return 'Idioma';
      case SettingsView.advanced:
        return 'Motor biomecánico';
    }
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case SettingsView.menu:
        return _buildMainMenu();
      case SettingsView.bodyData:
        return _buildBodyDataView();
      case SettingsView.joints:
        return _buildJointsView();
      case SettingsView.calibration:
        return _buildCalibrationView();
      case SettingsView.language:
        return _buildLanguageView();
      case SettingsView.advanced:
        return _buildAdvancedView();
    }
  }

  // ─── VISTA 1: MENU PRINCIPAL ─────────────────────────────────
  Widget _buildMainMenu() {
    final isEs = widget.localeProvider.locale.languageCode == 'es';
    return ListView(
      key: const ValueKey('main_menu_view'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildSectionLabel('PERFIL'),
        _buildMenuRow(
          title: 'Datos corporales',
          subtitle: 'Altura y peso',
          icon: Icons.accessibility_new_rounded,
          onTap: () => setState(() => _currentView = SettingsView.bodyData),
        ),
        _buildMenuRow(
          title: 'Medidas cinemáticas',
          subtitle: 'Longitud de segmentos óseos',
          icon: Icons.straighten_rounded,
          onTap: () => setState(() => _currentView = SettingsView.joints),
        ),
        _buildMenuRow(
          title: 'Calibración',
          subtitle: 'Escala de cámara y proporciones',
          icon: Icons.settings_overscan_rounded,
          onTap: () => setState(() => _currentView = SettingsView.calibration),
        ),
        const SizedBox(height: 8),
        _buildSectionLabel('PREFERENCIAS'),
        _buildMenuRow(
          title: 'Idioma',
          subtitle: isEs ? 'Español' : 'English',
          icon: Icons.language_rounded,
          onTap: () => setState(() => _currentView = SettingsView.language),
        ),
        _buildMenuRow(
          title: 'Motor biomecánico',
          subtitle: 'Variables avanzadas de análisis',
          icon: Icons.tune_rounded,
          onTap: () => setState(() => _currentView = SettingsView.advanced),
          isDestructive: false,
          showWarning: true,
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            'LiftSense Engine v2.0',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white30,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMenuRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool showWarning = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: BiomechColors.optimal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: BiomechColors.optimal, size: 18),
          ),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDestructive ? Colors.redAccent : Colors.white,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showWarning)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('ADV', style: GoogleFonts.inter(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
              Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }


  // ─── VISTA 2: DATOS CORPORALES ───────────────────────────────
  Widget _buildBodyDataView() {
    return ListView(
      key: const ValueKey('body_data_view'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              _buildSliderItem(
                'Altura Física',
                _height, 120.0, 220.0, ' cm',
                (val) {
                  setState(() => _height = val);
                  _db.height = val;
                },
                subtitle: 'Esencial para calcular la relación física cm/píxel.',
              ),
              const SizedBox(height: 10),
              _buildSliderItem(
                'Peso Corporal',
                _weight, 30.0, 180.0, ' kg',
                (val) {
                  setState(() => _weight = val);
                  _db.weight = val;
                },
                subtitle: 'Utilizado para la estimación de masa segmentaria e IA.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── VISTA 3: MEDIDAS CINEMÁTICAS ─────────────────────────────
  Widget _buildJointsView() {
    return ListView(
      key: const ValueKey('joints_view'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              _buildSliderItem(
                'Longitud de Húmero',
                _humerus, 15.0, 50.0, ' cm',
                (val) {
                  setState(() => _humerus = val);
                  _db.humerus = val;
                },
                subtitle: 'Segmento del brazo superior (hombro a codo).',
              ),
              const SizedBox(height: 10),
              _buildSliderItem(
                'Longitud de Fémur',
                _femur, 25.0, 70.0, ' cm',
                (val) {
                  setState(() => _femur = val);
                  _db.femur = val;
                },
                subtitle: 'Hueso del muslo superior (cadera a rodilla).',
              ),
              const SizedBox(height: 10),
              _buildSliderItem(
                'Longitud de Tibia',
                _tibia, 25.0, 70.0, ' cm',
                (val) {
                  setState(() => _tibia = val);
                  _db.tibia = val;
                },
                subtitle: 'Hueso de la pantorrilla (rodilla a tobillo).',
              ),
              const SizedBox(height: 10),
              _buildSliderItem(
                'Longitud de Columna',
                _spine, 25.0, 80.0, ' cm',
                (val) {
                  setState(() => _spine = val);
                  _db.spine = val;
                },
                subtitle: 'Segmento del torso (eje C7 a punto pélvico).',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── VISTA 4: CALIBRACIÓN DE ESCALA ───────────────────────────
  Widget _buildCalibrationView() {
    return ListView(
      key: const ValueKey('calibration_view'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildActionTile(
          title: 'INICIAR CALIBRACIÓN POR CÁMARA',
          desc: 'Escaneo frontal estático usando la cámara del celular. Mide articulaciones de forma anatómica real.',
          icon: Icons.videocam_rounded,
          buttonText: 'CALIBRAR EN VIVO',
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SensorCaptureScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        _buildActionTile(
          title: 'SIMULAR CALIBRACIÓN DE PRUEBA',
          desc: 'Carga una calibración biomecánica ideal parametrizada matemáticamente a partir de tu altura registrada.',
          icon: Icons.auto_mode_rounded,
          buttonText: 'SIMULAR AHORA',
          onTap: () => _simulateMockCalibration(),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String desc,
    required IconData icon,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: BiomechColors.optimal, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: BiomechColors.optimal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BiomechColors.optimal.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text(
                  buttonText,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: BiomechColors.optimal,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _simulateMockCalibration() {
    HapticFeedback.mediumImpact();

    // 1. Mostrar loading modal clínico rápido
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BiomechColors.optimal, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: BiomechColors.optimal),
              ),
              const SizedBox(height: 16),
              Text(
                'PROCESANDO PROPORCIONES...',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 2. Calcular proporciones óseas estándares basadas en la altura
    // Ratios clínicos: Fémur (25%), Tibia (23%), Columna (28%), Húmero (17%)
    final double simFemur = double.parse((_height * 0.25).toStringAsFixed(1));
    final double simTibia = double.parse((_height * 0.23).toStringAsFixed(1));
    final double simSpine = double.parse((_height * 0.28).toStringAsFixed(1));
    final double simHumerus = double.parse((_height * 0.17).toStringAsFixed(1));

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader

      // Persistir en local database
      _db.femur = simFemur;
      _db.tibia = simTibia;
      _db.spine = simSpine;
      _db.humerus = simHumerus;

      // Actualizar estado local
      setState(() {
        _femur = simFemur;
        _tibia = simTibia;
        _spine = simSpine;
        _humerus = simHumerus;
      });

      // Mostrar diálogo de éxito de calibración
      showDialog(
        context: context,
        builder: (context) => Center(
          child: Container(
            width: 310,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: BiomechColors.optimal, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'CALIBRACIÓN EXITOSA',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Firma biométrica generada matemáticamente a partir de tu altura física de $_height cm:',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white54, height: 1.4),
                ),
                const SizedBox(height: 16),
                _buildSegmentRow('HÚMERO', '$simHumerus cm'),
                _buildSegmentRow('FÉMUR', '$simFemur cm'),
                _buildSegmentRow('TIBIA', '$simTibia cm'),
                _buildSegmentRow('COLUMNA', '$simSpine cm'),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: BiomechColors.optimal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'ACEPTAR',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSegmentRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white30)),
          Text(value, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: BiomechColors.optimal)),
        ],
      ),
    );
  }

  // ─── VISTA 5: IDIOMA ──────────────────────────────────────────
  Widget _buildLanguageView() {
    final isEs = widget.localeProvider.locale.languageCode == 'es';
    return ListView(
      key: const ValueKey('language_view'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildSectionLabel('SELECCIONAR IDIOMA'),
        _buildLanguageOption(
          flag: '🇪🇸',
          label: 'Español',
          isSelected: isEs,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.localeProvider.setLocale(const Locale('es'));
            setState(() {});
          },
        ),
        const SizedBox(height: 2),
        _buildLanguageOption(
          flag: '🇺🇸',
          label: 'English',
          isSelected: !isEs,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.localeProvider.setLocale(const Locale('en'));
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildLanguageOption({
    required String flag,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: BiomechColors.optimal.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Text(flag, style: const TextStyle(fontSize: 24)),
          title: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          trailing: isSelected
              ? Icon(Icons.check_circle_rounded, color: BiomechColors.optimal, size: 20)
              : const Icon(Icons.circle_outlined, color: Colors.white24, size: 20),
        ),
      ),
    );
  }

  // ─── VISTA 6: MOTOR BIOMECÁNICO (SOLO AVANZADOS) ─────────────
  Widget _buildAdvancedView() {
    return ListView(
      key: const ValueKey('advanced_view'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildAdvancedEngineControls(),
      ],
    );
  }

  Widget _buildAdvancedEngineControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── SECCIÓN: FRONTAL ───────────────────────
          _buildCategoryHeader('VISTA FRONTAL'),
          _buildSliderItem(
            'Tolerancia Expansión Cadera', 
            _hipTolerance, 5.0, 25.0, '%', 
            (val) {
              setState(() => _hipTolerance = val);
              _db.hipTolerance = val;
            },
            subtitle: 'Evita contracciones pélvicas por profundidad Z ficticia.',
          ),
          _buildSliderItem(
            'Tolerancia Expansión Hombros', 
            _shoulderTolerance, 5.0, 25.0, '%', 
            (val) {
              setState(() => _shoulderTolerance = val);
              _db.shoulderTolerance = val;
            },
            subtitle: 'Compensa torsión torácica en plano frontal visual.',
          ),
          _buildSliderItem(
            'Estabilidad Calibración Mínima', 
            _minStability, 0.05, 0.30, ' px', 
            (val) {
              setState(() => _minStability = val);
              _db.minStability = val;
            },
            subtitle: 'Jitter articular máximo para capturar BodyProfile.',
          ),
          _buildSliderItem(
            'Rigidez de Pelvis (EMA Alpha)', 
            _hipEmaAlpha, 0.05, 0.50, '', 
            (val) {
              setState(() => _hipEmaAlpha = val);
              _db.hipEmaAlpha = val;
            },
            subtitle: 'Atenuación del efecto de oscilación/respiración.',
          ),
          const SizedBox(height: 16),

          // ─── SECCIÓN: LATERAL ───────────────────────
          _buildCategoryHeader('VISTA LATERAL'),
          _buildSliderItem(
            'Restricción de Inclinación Torso', 
            _torsoLimitDeg, 30.0, 70.0, '°', 
            (val) {
              setState(() => _torsoLimitDeg = val);
              _db.torsoLimitDeg = val;
            },
            subtitle: 'Límite de colapso sagital permitido antes de alerta.',
          ),
          _buildSliderItem(
            'Shoulder Overlap Lock', 
            _shoulderLock, 10.0, 60.0, '%', 
            (val) {
              setState(() => _shoulderLock = val);
              _db.shoulderLock = val;
            },
            subtitle: 'Histeresis al superponerse hombro cercano y lejano.',
          ),
          _buildSliderItem(
            'Hip Overlap Lock', 
            _hipLock, 10.0, 60.0, '%', 
            (val) {
              setState(() => _hipLock = val);
              _db.hipLock = val;
            },
            subtitle: 'Bloqueo estricto del eje pélvico sagital.',
          ),
          _buildSliderItem(
            'Tolerancia Pseudo-Z', 
            _pseudoZ, 0.15, 0.85, '', 
            (val) {
              setState(() => _pseudoZ = val);
              _db.pseudoZ = val;
            },
            subtitle: 'Sensibilidad a la proyección de profundidad visual.',
          ),
          const SizedBox(height: 16),

          // ─── SECCIÓN: GENERAL ───────────────────────
          _buildCategoryHeader('BIOMECÁNICA GENERAL'),
          _buildSliderItem(
            'Confidence Guard (Umbral)', 
            _confGuard, 0.25, 0.75, '', 
            (val) {
              setState(() => _confGuard = val);
              _db.confGuard = val;
            },
            subtitle: 'Puntos por debajo se consideran ocluidos.',
          ),
          _buildSliderItem(
            'OneEuro Cutoff Mínimo', 
            _oneEuroCutoff, 0.5, 3.0, ' Hz', 
            (val) {
              setState(() => _oneEuroCutoff = val);
              _db.oneEuroCutoff = val;
            },
            subtitle: 'Filtra temblores rápidos en reposo.',
          ),
          _buildSliderItem(
            'OneEuro Beta (Sensibilidad)', 
            _oneEuroBeta, 0.01, 0.20, '', 
            (val) {
              setState(() => _oneEuroBeta = val);
              _db.oneEuroBeta = val;
            },
            subtitle: 'Minimiza lag en fases de alta aceleración.',
          ),
          _buildSliderItem(
            'Deadzones e Histeresis', 
            _hysteresisMs, 50.0, 300.0, ' ms', 
            (val) {
              setState(() => _hysteresisMs = val);
              _db.hysteresisMs = val;
            },
            subtitle: 'Margen temporal para conteo y fases de repetición.',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white54,
              letterSpacing: 1.0,
            ),
          ),
          const Divider(color: Colors.white12, height: 10),
        ],
      ),
    );
  }

  Widget _buildSliderItem(
    String label, 
    double value, 
    double min, 
    double max, 
    String unit, 
    ValueChanged<double> onChanged,
    {required String subtitle}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}$unit',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: BiomechColors.optimal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: Colors.white24,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: BiomechColors.optimal,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.05),
              thumbColor: BiomechColors.optimal,
              overlayColor: BiomechColors.optimal.withValues(alpha: 0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
