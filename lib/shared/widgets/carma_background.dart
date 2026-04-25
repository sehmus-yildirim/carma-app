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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF12151E),
            Color(0xFF07090F),
            Color(0xFF020309),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -120,
            right: -80,
            child: _GlowOrb(
              size: 300,
              color: Color(0xFF6B8CFF),
              opacity: 0.16,
            ),
          ),
          const Positioned(
            top: 170,
            left: -120,
            child: _GlowOrb(
              size: 260,
              color: Color(0xFFB7D9FF),
              opacity: 0.08,
            ),
          ),
          const Positioned(
            bottom: -130,
            right: -120,
            child: _GlowOrb(
              size: 320,
              color: Color(0xFFFFFFFF),
              opacity: 0.06,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.12),
                  Colors.black.withValues(alpha: 0.44),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
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
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: opacity),
              blurRadius: 120,
              spreadRadius: 42,
            ),
          ],
        ),
      ),
    );
  }
}