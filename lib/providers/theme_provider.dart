import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum PrayerPeriod { fajr, morning, asr, maghrib, isha }

class ThemeProvider with ChangeNotifier {
  PrayerPeriod _currentPeriod = PrayerPeriod.isha; // Default to night
  bool _isDebugOverride = false;

  PrayerPeriod get currentPeriod => _currentPeriod;

  void debugCycleTheme() {
    _isDebugOverride = true;
    int nextIndex = (_currentPeriod.index + 1) % PrayerPeriod.values.length;
    _currentPeriod = PrayerPeriod.values[nextIndex];
    notifyListeners();
  }

  // Period updates based on the current time and prayer times
  void updatePeriod(DateTime now, Map<String, DateTime> prayerTimes) {
    if (_isDebugOverride) return;
    if (prayerTimes.isEmpty) return;

    final fajr = prayerTimes['Fajr'];
    final sunrise = prayerTimes['Sunrise'];
    final asr = prayerTimes['Asr'];
    final maghrib = prayerTimes['Maghrib'];
    final isha = prayerTimes['Isha'];
    
    if (fajr == null || sunrise == null || asr == null || maghrib == null || isha == null) {
      return;
    }

    PrayerPeriod newPeriod;
    
    if (now.isAfter(isha) || now.isBefore(fajr)) {
      newPeriod = PrayerPeriod.isha;
    } else if (now.isAfter(fajr) && now.isBefore(sunrise)) {
      newPeriod = PrayerPeriod.fajr;
    } else if (now.isAfter(sunrise) && now.isBefore(asr)) {
      newPeriod = PrayerPeriod.morning;
    } else if (now.isAfter(asr) && now.isBefore(maghrib)) {
      newPeriod = PrayerPeriod.asr;
    } else {
      newPeriod = PrayerPeriod.maghrib;
    }

    if (newPeriod != _currentPeriod) {
      _currentPeriod = newPeriod;
      notifyListeners();
    }
  }

  ThemeData get themeData {
    switch (_currentPeriod) {
      case PrayerPeriod.fajr:
        return _buildTheme(
          background: const Color(0xFF1A1B3A),
          surface: const Color(0xFF242650),
          accent: const Color(0xFFE8B4BC),
          primaryText: const Color(0xFFF2F0F5),
          secondaryText: const Color(0xFFA8A4C0),
        );
      case PrayerPeriod.morning:
        return _buildTheme(
          background: const Color(0xFFE8F4F8),
          surface: const Color(0xFFFFFFFF),
          accent: const Color(0xFFD4A24C),
          primaryText: const Color(0xFF1A1B3A),
          secondaryText: const Color(0xFF5B6470),
        );
      case PrayerPeriod.asr:
        return _buildTheme(
          background: const Color(0xFFF5E6D3),
          surface: const Color(0xFFFBF3E8),
          accent: const Color(0xFFC56B3F),
          primaryText: const Color(0xFF3A2A1E),
          secondaryText: const Color(0xFF8A7565),
        );
      case PrayerPeriod.maghrib:
        return _buildTheme(
          background: const Color(0xFF2A1F3D), // Used base purple for background fallback
          surface: const Color(0xCC2A1F3D),
          accent: const Color(0xFFFF9466),
          primaryText: const Color(0xFFFFFFFF),
          secondaryText: const Color(0xFFD9C4CE),
        );
      case PrayerPeriod.isha:
      default:
        return _buildTheme(
          background: const Color(0xFF12121A),
          surface: const Color(0xFF1C1C26),
          accent: const Color(0xFF5FAFA0),
          primaryText: const Color(0xFFE8E8ED),
          secondaryText: const Color(0xFF75757F),
        );
    }
  }

  ThemeData _buildTheme({
    required Color background,
    required Color surface,
    required Color accent,
    required Color primaryText,
    required Color secondaryText,
  }) {
    final baseTheme = ThemeData(
      brightness: ThemeData.estimateBrightnessForColor(background),
      colorScheme: ColorScheme(
        brightness: ThemeData.estimateBrightnessForColor(background),
        primary: accent,
        onPrimary: background,
        secondary: accent,
        onSecondary: background,
        error: const Color(0xFFE05C5C),
        onError: Colors.white,
        surface: background,
        onSurface: primaryText,
        onSurfaceVariant: secondaryText,
        primaryContainer: surface,
        onPrimaryContainer: primaryText,
        secondaryContainer: const Color(0xFF5FAF6F), // Success / Completed color from scheme
      ),
      scaffoldBackgroundColor: background,
      cardColor: surface,
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.amiriTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.amiri(color: primaryText, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.amiri(color: primaryText, fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.amiri(color: primaryText, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.amiri(color: primaryText, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.amiri(color: primaryText, fontWeight: FontWeight.bold),
        headlineSmall: GoogleFonts.amiri(color: primaryText, fontWeight: FontWeight.bold),
      ).apply(
        bodyColor: primaryText,
        displayColor: primaryText,
      ),
    );
  }
}
