import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';

class GlassPrimaryButton extends StatelessWidget {
  const GlassPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.height = 52,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: CaRismaDesignTokens.bluePrimary,
          foregroundColor: CaRismaDesignTokens.textPrimary,
          disabledBackgroundColor: CaRismaDesignTokens.bluePrimary.withValues(
            alpha: 0.30,
          ),
          disabledForegroundColor: CaRismaDesignTokens.textPrimary.withValues(
            alpha: 0.48,
          ),
          elevation: 0,
          shadowColor: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusCard),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: CaRismaDesignTokens.textPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 10)],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

class GlassSecondaryButton extends StatelessWidget {
  const GlassSecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.height = 52,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          backgroundColor: CaRismaDesignTokens.surface2.withValues(alpha: 0.82),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusCard),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Center(child: icon ?? const SizedBox.shrink()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 26),
          ],
        ),
      ),
    );
  }
}
