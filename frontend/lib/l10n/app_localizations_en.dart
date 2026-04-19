// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LIFTSENSE';

  @override
  String get initSquatRecord => 'INIT SQUAT RECORD';

  @override
  String get kinematicExtraction => 'Kinematic Extraction // Sagittal Plane';

  @override
  String get metaTrends => 'META-TRENDS // LAST 7 DAYS';

  @override
  String get avgMaxInclination => 'AVG MAX INCLINATION';

  @override
  String get improvement => 'IMPROVEMENT';

  @override
  String get operationalHistory => 'OPERATIONAL HISTORY';

  @override
  String get maxTrunk => 'MAX TRUNK';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get spanish => 'Spanish';

  @override
  String get english => 'English';

  @override
  String get dataOrigin => 'DATA SOURCE //';

  @override
  String get sagittalRequired =>
      'Sagittal Plane Required for Analytical Extraction.';

  @override
  String get liveSensor => 'LIVE SENSOR';

  @override
  String get cameraRt => 'RT Camera + MediaPipe';

  @override
  String get diskIngest => 'DISK INGEST';

  @override
  String get localClip => 'Local clip (.mp4)';
}
