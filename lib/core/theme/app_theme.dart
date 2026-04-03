import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0E0E0E),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFC6C6C7),
        secondary: Color(0xFF9F9DA0),
        tertiary: Color(0xFF5F9EFF),
        surface: Color(0xFF0E0E0E),
        onSurface: Color(0xFFE7E5E5),
        surfaceContainer: Color(0xFF191A1A),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: const Color(0xFFC6C6C7),
        inactiveTrackColor: const Color(0xFF131313),
        thumbColor: const Color(0xFFFCF9F8),
        overlayColor: const Color(0xFF5F9EFF).withOpacity(0.2),
      ),
    );
  }
}
