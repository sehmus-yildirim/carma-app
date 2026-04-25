import 'dart:ui';

import 'package:flutter/material.dart';

class CarmaBackground extends StatelessWidget {
  const CarmaBackground({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.3,
          colors: [
            Color(0xFF252535),
            Color(0xFF0D0D14),
            Color(0xFF050509),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -110,
            left: -90,
            child: _BlurOrb(
              size: 260,
              color: Color(0xFF404050),
              opacity: 0.55,
            ),
          ),
          const Positioned(
            bottom: -120,
            right: -90,
            child: _BlurOrb(
              size: 300,
              color: Color(0xFF1E1E2D),
              opacity: 0.70,
            ),
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.34),
          ),
          child,
        ],
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}