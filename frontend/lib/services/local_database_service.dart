import 'dart:io';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio centralizado de persistencia local mediante Hive.
/// Almacena el perfil antropométrico y las calibraciones avanzadas del motor.
class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();

  Box? _box;

  /// Inicializa la base de datos local y abre la caja de configuraciones.
  Future<void> init() async {
    if (_box != null) return;
    _box = await Hive.openBox('biomech_settings');
  }

  // ─── Perfil Antropométrico del Usuario ───────────────────────

  double get height => _box?.get('height', defaultValue: 175.0) ?? 175.0;
  set height(double val) => _box?.put('height', val);

  double get weight => _box?.get('weight', defaultValue: 75.0) ?? 75.0;
  set weight(double val) => _box?.put('weight', val);

  // Longitudes de articulaciones ajustables manualmente (en cm)
  double get humerus => _box?.get('humerus', defaultValue: 30.0) ?? 30.0;
  set humerus(double val) => _box?.put('humerus', val);

  double get femur => _box?.get('femur', defaultValue: 45.0) ?? 45.0;
  set femur(double val) => _box?.put('femur', val);

  double get tibia => _box?.get('tibia', defaultValue: 43.0) ?? 43.0;
  set tibia(double val) => _box?.put('tibia', val);

  double get spine => _box?.get('spine', defaultValue: 48.0) ?? 48.0;
  set spine(double val) => _box?.put('spine', val);

  // ─── Configuración Avanzada: Vista Frontal ───────────────────

  double get hipTolerance => _box?.get('hipTolerance', defaultValue: 10.0) ?? 10.0;
  set hipTolerance(double val) => _box?.put('hipTolerance', val);

  double get shoulderTolerance => _box?.get('shoulderTolerance', defaultValue: 12.0) ?? 12.0;
  set shoulderTolerance(double val) => _box?.put('shoulderTolerance', val);

  double get minStability => _box?.get('minStability', defaultValue: 0.10) ?? 0.10;
  set minStability(double val) => _box?.put('minStability', val);

  double get hipEmaAlpha => _box?.get('hipEmaAlpha', defaultValue: 0.15) ?? 0.15;
  set hipEmaAlpha(double val) => _box?.put('hipEmaAlpha', val);

  // ─── Configuración Avanzada: Vista Lateral ───────────────────

  double get torsoLimitDeg => _box?.get('torsoLimitDeg', defaultValue: 55.0) ?? 55.0;
  set torsoLimitDeg(double val) => _box?.put('torsoLimitDeg', val);

  double get shoulderLock => _box?.get('shoulderLock', defaultValue: 25.0) ?? 25.0;
  set shoulderLock(double val) => _box?.put('shoulderLock', val);

  double get hipLock => _box?.get('hipLock', defaultValue: 30.0) ?? 30.0;
  set hipLock(double val) => _box?.put('hipLock', val);

  double get pseudoZ => _box?.get('pseudoZ', defaultValue: 0.45) ?? 0.45;
  set pseudoZ(double val) => _box?.put('pseudoZ', val);

  // ─── Configuración Avanzada: Biomecánica General ──────────────

  double get confGuard => _box?.get('confGuard', defaultValue: 0.45) ?? 0.45;
  set confGuard(double val) => _box?.put('confGuard', val);

  double get oneEuroCutoff => _box?.get('oneEuroCutoff', defaultValue: 1.0) ?? 1.0;
  set oneEuroCutoff(double val) => _box?.put('oneEuroCutoff', val);

  double get oneEuroBeta => _box?.get('oneEuroBeta', defaultValue: 0.05) ?? 0.05;
  set oneEuroBeta(double val) => _box?.put('oneEuroBeta', val);

  double get hysteresisMs => _box?.get('hysteresisMs', defaultValue: 150.0) ?? 150.0;
  set hysteresisMs(double val) => _box?.put('hysteresisMs', val);

  // ─── Historial de Grabaciones del Usuario ────────────────────

  List<Map<String, dynamic>> get savedRecords {
    final raw = _box?.get('saved_records');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (raw as List).map((item) => Map<String, dynamic>.from(item as Map)),
    );
  }

  Future<void> saveRecord({
    required String date,
    required String tag,
    required String maxTrunkAngle,
    required String videoPath,
    required String csvPath,
  }) async {
    final record = {
      'date': date,
      'tag': tag,
      'maxTrunkAngle': maxTrunkAngle,
      'videoPath': videoPath,
      'previewVideoPath': videoPath, // Usamos la misma ruta para preview
      'csvPath': csvPath,
    };
    final list = savedRecords;
    list.insert(0, record); // Más reciente primero
    await _box?.put('saved_records', list);
  }

  // ─── Exportación a JSON para la librería de Python ───────────

  /// Genera y escribe el archivo `user_profile.json` en el directorio de documentos
  /// para que la librería de Python lo consuma directamente durante el post-procesamiento.
  Future<String> writeUserProfileJson() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File('${docsDir.path}/user_profile.json');

    const double cmPerPx = 0.115; // Escala por defecto compatible con MediaPipe

    final profile = {
      'segments_cm': {
        'torso': spine,
        'femur_l': femur,
        'femur_r': femur,
        'tibia_l': tibia,
        'tibia_r': tibia,
        'shoulder_width': humerus * 1.25, // Estimado de ancho de hombros
        'hip_width': femur * 0.52 // Estimado de ancho de cadera
      },
      'segments_px': {
        'torso': spine / cmPerPx,
        'femur_l': femur / cmPerPx,
        'femur_r': femur / cmPerPx,
        'tibia_l': tibia / cmPerPx,
        'tibia_r': tibia / cmPerPx,
        'shoulder_width': (humerus * 1.25) / cmPerPx,
        'hip_width': (femur * 0.52) / cmPerPx
      },
      'cm_per_pixel': cmPerPx
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(profile);
    await file.writeAsString(jsonString);
    return file.path;
  }
}
