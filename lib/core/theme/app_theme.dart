import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.primaryBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryAccent,
        secondary: AppColors.lightAccent,
        surface: AppColors.secondarySurface,
        error: AppColors.error,
        onPrimary: AppColors.primaryText,
        onSecondary: AppColors.primaryText,
        onSurface: AppColors.primaryText,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 32),
          headlineLarge: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 24),
          headlineMedium: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600, fontSize: 20),
          titleLarge: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600, fontSize: 18),
          titleMedium: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w500, fontSize: 16),
          bodyLarge: TextStyle(color: AppColors.primaryText, fontSize: 16),
          bodyMedium: TextStyle(color: AppColors.secondaryText, fontSize: 14),
          bodySmall: TextStyle(color: AppColors.tertiaryText, fontSize: 12),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryText),
        titleTextStyle: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.secondarySurface,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondarySurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryAccent,
          foregroundColor: AppColors.primaryText,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AppColors.cardSurface),
        dataRowColor: WidgetStateProperty.all(AppColors.secondarySurface),
        dividerThickness: 1,
        horizontalMargin: 24,
        columnSpacing: 32,
      ),
    );
  }
}
