import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'carisma_design_tokens.dart';

class CaRismaTheme {
  const CaRismaTheme._();

  static ThemeData darkTheme() => _build(const _PlaqaPalette.dark());

  static ThemeData lightTheme() => _build(const _PlaqaPalette.light());

  static ThemeData _build(_PlaqaPalette palette) {
    final isDark = palette.brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: CaRismaDesignTokens.bluePrimary,
          brightness: palette.brightness,
        ).copyWith(
          primary: CaRismaDesignTokens.bluePrimary,
          onPrimary: Colors.white,
          secondary: const Color(0xFFFF7A18),
          onSecondary: const Color(0xFF101828),
          surface: palette.card,
          onSurface: palette.textPrimary,
          outline: palette.border,
          outlineVariant: palette.border,
          error: palette.danger,
          onError: Colors.white,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
    );
    final textTheme = base.textTheme.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusCard),
          side: BorderSide(color: palette.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.14),
        height: 74,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? palette.textPrimary : palette.textMuted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? CaRismaDesignTokens.bluePrimary
                : palette.textMuted,
            size: selected ? 27 : 25,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CaRismaDesignTokens.bluePrimary,
          foregroundColor: Colors.white,
          overlayColor: Colors.transparent,
          disabledBackgroundColor: CaRismaDesignTokens.bluePrimary.withValues(
            alpha: 0.22,
          ),
          disabledForegroundColor: palette.textMuted,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusCard),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          overlayColor: Colors.transparent,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: palette.border),
          backgroundColor: palette.controlSurface,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusCard),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CaRismaDesignTokens.bluePrimary,
          overlayColor: Colors.transparent,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          overlayColor: Colors.transparent,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(palette.textPrimary),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        splashColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.controlSurface,
        labelStyle: TextStyle(color: palette.textSecondary),
        hintStyle: TextStyle(color: palette.textMuted),
        prefixIconColor: palette.textSecondary,
        suffixIconColor: palette.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: _inputBorder(palette.border),
        enabledBorder: _inputBorder(palette.border),
        focusedBorder: _inputBorder(
          CaRismaDesignTokens.bluePrimary,
          width: 1.4,
        ),
        disabledBorder: _inputBorder(palette.border.withValues(alpha: 0.55)),
        errorBorder: _inputBorder(palette.danger),
        focusedErrorBorder: _inputBorder(palette.danger, width: 1.4),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        textColor: palette.textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
      checkboxTheme: CheckboxThemeData(
        checkColor: const WidgetStatePropertyAll(Colors.white),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? CaRismaDesignTokens.bluePrimary
              : Colors.transparent;
        }),
        side: BorderSide(color: palette.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? CaRismaDesignTokens.bluePrimary
              : palette.textSecondary;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : palette.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? CaRismaDesignTokens.bluePrimary
              : palette.controlSurface;
        }),
        trackOutlineColor: WidgetStatePropertyAll(palette.border),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.14)
                : palette.controlSurface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? CaRismaDesignTokens.bluePrimary
                : palette.textSecondary;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.card,
        contentTextStyle: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.border),
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: palette.border),
        ),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
        contentTextStyle: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w600,
          height: 1.4,
          fontSize: 14.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        modalBackgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: palette.border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: TextStyle(color: palette.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: palette.textPrimary),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: palette.controlSurface,
          enabledBorder: _inputBorder(palette.border),
          focusedBorder: _inputBorder(CaRismaDesignTokens.bluePrimary),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.card),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusInput),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _PlaqaPalette {
  const _PlaqaPalette({
    required this.brightness,
    required this.background,
    required this.card,
    required this.controlSurface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.danger,
  });

  const _PlaqaPalette.dark()
    : this(
        brightness: Brightness.dark,
        background: const Color(0xFF0A0D12),
        card: const Color(0xFF121419),
        controlSurface: const Color(0xFF121419),
        border: const Color(0x1AFFFFFF),
        textPrimary: const Color(0xFFF4F7FB),
        textSecondary: const Color(0xFFAAB3C2),
        textMuted: const Color(0xFF6F7A8A),
        danger: const Color(0xFFFF4D4F),
      );

  const _PlaqaPalette.light()
    : this(
        brightness: Brightness.light,
        background: const Color(0xFFF4F7FB),
        card: const Color(0xFFFFFFFF),
        controlSurface: const Color(0xFFEEF3F8),
        border: const Color(0x26344054),
        textPrimary: const Color(0xFF101828),
        textSecondary: const Color(0xFF475467),
        textMuted: const Color(0xFF667085),
        danger: const Color(0xFFD92D20),
      );

  final Brightness brightness;
  final Color background;
  final Color card;
  final Color controlSurface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color danger;
}
