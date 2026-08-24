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
    this.showOuterEffects = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final double? borderRadius;
  final double opacity;
  final double borderOpacity;
  final bool glow;
  final bool showOuterEffects;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = radius ?? borderRadius ?? 24;

    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        color: CaRismaDesignTokens.card,
        border: Border.all(color: CaRismaDesignTokens.border, width: 1.0),
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
        border: Border.all(color: CaRismaDesignTokens.border),
      ),
      child: child,
    );
  }
}
