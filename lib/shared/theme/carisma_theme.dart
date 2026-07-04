import 'package:flutter/material.dart';

import 'carisma_design_tokens.dart';

class CaRismaTheme {
  const CaRismaTheme._();

  static const Color background = CaRismaDesignTokens.background;
  static const Color surface = CaRismaDesignTokens.surface1;
  static const Color glassFill = CaRismaDesignTokens.card;
  static const Color glassBorder = CaRismaDesignTokens.border;
  static const Color textPrimary = CaRismaDesignTokens.textPrimary;
  static const Color textSecondary = CaRismaDesignTokens.textSecondary;
  static const Color textMuted = CaRismaDesignTokens.textMuted;
  static const Color error = CaRismaDesignTokens.danger;
  static const Color success = CaRismaDesignTokens.success;

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.white,
      brightness: Brightness.dark,
      primary: CaRismaDesignTokens.bluePrimary,
      secondary: CaRismaDesignTokens.blueBright,
      surface: surface,
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: CaRismaDesignTokens.card,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusCard),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: CaRismaDesignTokens.surface1.withValues(alpha: 0.78),
        indicatorColor: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.24),
        height: 74,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);

          return TextStyle(
            color: isSelected
                ? CaRismaDesignTokens.textPrimary
                : CaRismaDesignTokens.textMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: isSelected
                ? CaRismaDesignTokens.textPrimary
                : CaRismaDesignTokens.textMuted,
            size: isSelected ? 27 : 25,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CaRismaDesignTokens.bluePrimary,
          foregroundColor: CaRismaDesignTokens.textPrimary,
          disabledBackgroundColor: CaRismaDesignTokens.bluePrimary.withValues(
            alpha: 0.24,
          ),
          disabledForegroundColor: CaRismaDesignTokens.textPrimary.withValues(
            alpha: 0.45,
          ),
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusCard),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CaRismaDesignTokens.textPrimary,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          backgroundColor: CaRismaDesignTokens.surface2.withValues(alpha: 0.72),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusCard),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CaRismaDesignTokens.surface1.withValues(alpha: 0.92),
        labelStyle: TextStyle(
          color: CaRismaDesignTokens.textSecondary.withValues(alpha: 0.86),
        ),
        hintStyle: TextStyle(
          color: CaRismaDesignTokens.textMuted.withValues(alpha: 0.92),
        ),
        prefixIconColor: CaRismaDesignTokens.textSecondary,
        suffixIconColor: CaRismaDesignTokens.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusInput),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusInput),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusInput),
          borderSide: const BorderSide(
            color: CaRismaDesignTokens.blueBright,
            width: 1.4,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusInput),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: CaRismaDesignTokens.textSecondary,
        textColor: CaRismaDesignTokens.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.10),
        thickness: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.all(CaRismaDesignTokens.background),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return CaRismaDesignTokens.blueBright;
          }

          return Colors.transparent;
        }),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CaRismaDesignTokens.cardHighlight,
        contentTextStyle: const TextStyle(
          color: CaRismaDesignTokens.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 12,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CaRismaDesignTokens.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        elevation: 24,
        titleTextStyle: const TextStyle(
          color: CaRismaDesignTokens.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
        contentTextStyle: TextStyle(
          color: CaRismaDesignTokens.textSecondary.withValues(alpha: 0.90),
          fontWeight: FontWeight.w600,
          height: 1.4,
          fontSize: 14.5,
        ),
      ),
    );
  }
}
