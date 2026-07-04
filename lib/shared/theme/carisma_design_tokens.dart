import 'package:flutter/material.dart';

class CaRismaDesignTokens {
  const CaRismaDesignTokens._();

  static const Color background = Color(0xFF090A0C);
  static const Color backgroundTop = Color(0xFF0F1014);
  static const Color backgroundMid = Color(0xFF0C0D10);
  static const Color surface1 = Color(0xFF101115);
  static const Color surface2 = Color(0xFF14161C);
  static const Color card = Color(0xFF121419);
  static const Color cardHighlight = Color(0xFF181A22);
  static const Color border = Color(0x0AFFFFFF);
  static const Color textPrimary = Color(0xFFF4F7FB);
  static const Color textSecondary = Color(0xFFAAB3C2);
  static const Color textMuted = Color(0xFF6F7A8A);
  static const Color bluePrimary = Color(0xFF1E7BFF);
  static const Color blueBright = Color(0xFF28A8FF);
  static const Color blueDark = Color(0xFF063264);
  static const Color danger = Color(0xFFFF4D4F);
  static const Color success = Color(0xFF22C55E);

  static const double radiusSmall = 14;
  static const double radiusInput = 18;
  static const double radiusCard = 22;
  static const double radiusPanel = 26;
  static const double radiusNav = 34;

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundMid, background],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bluePrimary, blueBright],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardHighlight, card, surface2],
  );

  static LinearGradient surfaceGradient({double highlightAlpha = 1}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        cardHighlight.withValues(alpha: highlightAlpha),
        card,
        surface1,
      ],
    );
  }

  static List<BoxShadow> surfaceShadows({
    double darkAlpha = 0.45,
    double blueAlpha = 0,
    double blurRadius = 40,
    Offset offset = const Offset(0, 18),
  }) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: darkAlpha),
        blurRadius: blurRadius,
        offset: offset,
      ),
      if (blueAlpha > 0)
        BoxShadow(
          color: bluePrimary.withValues(alpha: blueAlpha),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.04),
        blurRadius: 14,
        offset: const Offset(0, -1),
      ),
    ];
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
      border: Border.all(color: Colors.white.withValues(alpha: borderAlpha)),
      boxShadow: surfaceShadows(
        darkAlpha: darkShadowAlpha,
        blueAlpha: blueShadowAlpha,
      ),
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
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      boxShadow: [
        BoxShadow(
          color: bluePrimary.withValues(alpha: glowAlpha),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.30),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
