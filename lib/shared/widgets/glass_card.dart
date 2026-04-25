import 'package:flutter/material.dart';

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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
          if (glow)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.08),
              blurRadius: 38,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(effectiveRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: opacity + 0.08),
                Colors.white.withValues(alpha: opacity),
                Colors.white.withValues(alpha: opacity * 0.55),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 1.2,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.34),
                ),
              ),
              Positioned(
                top: 1,
                left: 1,
                bottom: 1,
                child: Container(
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              Padding(
                padding: padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: opacity + 0.05),
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: opacity * 0.65),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: borderOpacity),
        ),
      ),
      child: child,
    );
  }
}