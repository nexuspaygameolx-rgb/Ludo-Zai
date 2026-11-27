import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Royal 3D Dark Palette
  static const darkBg = Color(0xFF0B0F1A);
  static const darkCard = Color(0xFF141B2D);
  static const darkBorder = Color(0xFF2A3550);
  static const royalGold = Color(0xFFF5B041);
  static const kutiCrimson = Color(0xFFFF3B5C);
  static const activeCyan = Color(0xFF00E5FF);

  // Daylight Marble Light Palette
  static const lightBg = Color(0xFFF7F5F0);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE2DDD2);
  static const lightGold = Color(0xFFD98A1C);
  static const deepEmerald = Color(0xFF0F766E);

  // Token Colors
  static const tokenRed = Color(0xFFFF3B5C);
  static const tokenGreen = Color(0xFF10B981);
  static const tokenYellow = Color(0xFFF59E0B);
  static const tokenBlue = Color(0xFF3B82F6);
}

class AppTheme {
  static ThemeData darkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.royalGold,
        secondary: AppColors.activeCyan,
        error: AppColors.kutiCrimson,
        surface: AppColors.darkCard,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(120, 50),
          backgroundColor: AppColors.royalGold,
          foregroundColor: AppColors.darkBg,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  static ThemeData lightTheme() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightGold,
        secondary: AppColors.deepEmerald,
        error: AppColors.kutiCrimson,
        surface: AppColors.lightCard,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(120, 50),
          backgroundColor: AppColors.lightGold,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
