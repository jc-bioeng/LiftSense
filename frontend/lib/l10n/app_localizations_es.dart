// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'LIFTSENSE';

  @override
  String get initSquatRecord => 'INICIAR REGISTRO';

  @override
  String get kinematicExtraction => 'Extracción Cinemática // Plano Sagital';

  @override
  String get metaTrends => 'META-TENDENCIAS // ÚLTIMOS 7 DÍAS';

  @override
  String get avgMaxInclination => 'INC. MÁX PROMEDIO';

  @override
  String get improvement => 'MEJORA';

  @override
  String get operationalHistory => 'HISTORIAL OPERATIVO';

  @override
  String get maxTrunk => 'TRONCO MÁX';

  @override
  String get settings => 'Opciones';

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Seleccionar Idioma';

  @override
  String get spanish => 'Español';

  @override
  String get english => 'Inglés';

  @override
  String get dataOrigin => 'ORIGEN DE DATOS //';

  @override
  String get sagittalRequired =>
      'Plano Sagital Requerido p/ Extracción Analítica.';

  @override
  String get liveSensor => 'SENSOR EN VIVO';

  @override
  String get cameraRt => 'Cámara TR + MediaPipe';

  @override
  String get diskIngest => 'INGESTA DESDE DISCO';

  @override
  String get localClip => 'Clip local (.mp4)';
}
