import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';

const String _transparentLogoAsset =
    'assets/images/carisma_logo_transparent.png';

class CaRismaAuthBrandHeader extends StatelessWidget {
  const CaRismaAuthBrandHeader({super.key, this.logoHeight = 132});

  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: logoHeight,
      child: Transform.scale(
        scale: 1.15,
        child: Image.asset(
          _transparentLogoAsset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: SizedBox.square(
                dimension: 104,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CaRismaDesignTokens.controlSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(
                    Icons.directions_car_filled_rounded,
                    color: CaRismaDesignTokens.bluePrimary,
                    size: 50,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CaRismaAuthBackButton extends StatelessWidget {
  const CaRismaAuthBackButton({
    super.key,
    required this.onTap,
    this.icon = Icons.arrow_back_rounded,
    this.semanticLabel = 'Zurück',
  });

  final VoidCallback onTap;
  final IconData icon;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(icon, color: CaRismaDesignTokens.textPrimary),
          ),
        ),
      ),
    );
  }
}
