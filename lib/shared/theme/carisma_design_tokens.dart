import 'package:flutter/material.dart';

class PlaqaAdaptiveColor extends Color {
  const PlaqaAdaptiveColor({required this.dark, required this.light})
    : super(dark);

  final int dark;
  final int light;

  static Brightness _brightness = Brightness.dark;

  static void useBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  int get _activeValue => _brightness == Brightness.dark ? dark : light;

  @override
  double get a => ((_activeValue >> 24) & 0xff) / 255;

  @override
  double get r => ((_activeValue >> 16) & 0xff) / 255;

  @override
  double get g => ((_activeValue >> 8) & 0xff) / 255;

  @override
  double get b => (_activeValue & 0xff) / 255;

  @override
  int toARGB32() => _activeValue;

  @override
  int get value => _activeValue;
}

class CaRismaDesignTokens {
  const CaRismaDesignTokens._();

  static const Color background = PlaqaAdaptiveColor(
    dark: 0xFF0A0D12,
    light: 0xFFF4F7FB,
  );
  static const Color backgroundTop = PlaqaAdaptiveColor(
    dark: 0xFF0A0D12,
    light: 0xFFF8FAFC,
  );
  static const Color backgroundMid = PlaqaAdaptiveColor(
    dark: 0xFF0A0D12,
    light: 0xFFF1F5F9,
  );
  static const Color surface1 = PlaqaAdaptiveColor(
    dark: 0xFF121419,
    light: 0xFFFFFFFF,
  );
  static const Color card = PlaqaAdaptiveColor(
    dark: 0xFF121419,
    light: 0xFFFFFFFF,
  );
  static const Color surface2 = card;
  static const Color cardHighlight = card;
  static const Color controlSurface = PlaqaAdaptiveColor(
    dark: 0xFF121419,
    light: 0xFFEEF3F8,
  );
  static const Color border = PlaqaAdaptiveColor(
    dark: 0x0AFFFFFF,
    light: 0x1F344054,
  );
  static const Color textPrimary = PlaqaAdaptiveColor(
    dark: 0xFFF4F7FB,
    light: 0xFF101828,
  );
  static const Color textSecondary = PlaqaAdaptiveColor(
    dark: 0xFFAAB3C2,
    light: 0xFF475467,
  );
  static const Color textMuted = PlaqaAdaptiveColor(
    dark: 0xFF6F7A8A,
    light: 0xFF667085,
  );
  static const Color bluePrimary = Color(0xFF1A5CBA);
  static const Color blueBright = bluePrimary;
  static const Color blueDark = bluePrimary;
  static const Color onAccent = Colors.white;
  static const Color onMedia = Colors.white;
  static const Color danger = PlaqaAdaptiveColor(
    dark: 0xFFFF4D4F,
    light: 0xFFD92D20,
  );
  static const Color success = PlaqaAdaptiveColor(
    dark: 0xFF22C55E,
    light: 0xFF15803D,
  );

  static const double radiusSmall = 14;
  static const double radiusInput = 18;
  static const double radiusCard = 22;
  static const double radiusPanel = 26;
  static const double radiusNav = 34;

  /// Einheitlicher Abstand der ersten und letzten Inhalte in den Haupttabs.
  static const double mainScreenTopInset = 12;
  static const double mainScreenBottomInset = 84;

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundTop, backgroundMid, background],
    stops: [0, 0.52, 1],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bluePrimary, blueBright],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [card, card, card],
  );

  static LinearGradient surfaceGradient({double highlightAlpha = 1}) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [card, card, card],
    );
  }

  static List<BoxShadow> surfaceShadows({
    double darkAlpha = 0.45,
    double blueAlpha = 0,
    double blurRadius = 40,
    Offset offset = const Offset(0, 18),
  }) {
    return const <BoxShadow>[];
  }

  static BoxDecoration surfaceDecoration({
    double radius = radiusCard,
    double borderAlpha = 0.08,
    double darkShadowAlpha = 0.50,
    double blueShadowAlpha = 0,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: cardGradient,
      border: Border.all(color: border),
    );
  }

  /// Premium blue-glow decoration for active/CTA elements.
  static BoxDecoration glowDecoration({
    double radius = radiusCard,
    double glowAlpha = 0.38,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: blueGradient,
      border: Border.all(color: textPrimary.withValues(alpha: 0.18)),
    );
  }
}
