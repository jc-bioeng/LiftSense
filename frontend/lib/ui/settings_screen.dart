import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../localization/locale_provider.dart';

class SettingsScreen extends StatelessWidget {
  final LocaleProvider localeProvider;

  const SettingsScreen({super.key, required this.localeProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CONFIGURACIÓN',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader('IDIOMA'),
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: const Color(0xFF161618),
            title: Text('Cambiar Idioma', style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
            trailing: Switch(
              value: localeProvider.locale.languageCode == 'en',
              onChanged: (bool value) {
                if (value) {
                  localeProvider.setLocale(const Locale('en'));
                } else {
                  localeProvider.setLocale(const Locale('es'));
                }
              },
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: Colors.white54,
      ),
    );
  }
}
