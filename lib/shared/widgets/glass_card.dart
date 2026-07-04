import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.radius,
    this.borderRadius,
    this.opacity = 0.12,
    this.borderOpacity = 0.24,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final double? borderRadius;
  final double opacity;
  final double borderOpacity;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = radius ?? borderRadius ?? 24;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        color: CaRismaDesignTokens.card,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 16,
            offset: const Offset(5, 5),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(-5, -5),
          ),
          if (glow)
            BoxShadow(
              color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.radius = 18,
    this.opacity = 0.08,
    this.borderOpacity = 0.18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: CaRismaDesignTokens.surface2,
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.60),
            blurRadius: 12,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: child,
    );
  }
}
