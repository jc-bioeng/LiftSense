import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'ui/dashboard_screen.dart';
import 'localization/locale_provider.dart';
import 'utils/video_seeder.dart';
import 'services/local_database_service.dart';

// Definición global del provider y el observer para simplicidad en este nivel del proyecto
final LocaleProvider localeProvider = LocaleProvider();
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LocalDatabaseService.instance.init();
  
  // Sembrar videos en la primera versión para persistencia local
  await VideoSeeder.seedVideos();
  
  runApp(const LiftSenseApp());
}

class LiftSenseApp extends StatelessWidget {
  const LiftSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'LiftSense',
          debugShowCheckedModeBanner: false,
          locale: localeProvider.locale,
          navigatorObservers: [routeObserver],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('es'),
          ],
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0A0A0C), // Negro suave: no fatiga la vista
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D4AA),   // Teal clínico con vitalidad orgánica
              secondary: Color(0xFF007BFF),
              tertiary: Color(0xFFFF2A4D),  // Solo para alertas críticas
              surface: Color(0xFF141416),
            ),
            textTheme: GoogleFonts.interTextTheme(
              ThemeData.dark().textTheme,
            ).apply(bodyColor: Colors.white70, displayColor: Colors.white),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0A0A0C),
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF00D4AA)),
            ),
            useMaterial3: true,
          ),
          home: DashboardScreen(localeProvider: localeProvider),
        );
      },
    );
  }
}
