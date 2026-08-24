import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';

class CaRismaSecondaryButton extends StatelessWidget {
  const CaRismaSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    this.borderRadius = 18,
    this.fontSize,
    this.textAlign = TextAlign.center,
    this.isEnabled = true,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? fontSize;
  final TextAlign textAlign;
  final bool isEnabled;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final textColor = isDestructive
        ? CaRismaDesignTokens.danger
        : CaRismaDesignTokens.textPrimary;

    return Opacity(
      opacity: isEnabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: CaRismaDesignTokens.surfaceGradient(
                highlightAlpha: isDestructive ? 0.78 : 1,
              ),
              border: Border.all(
                color: isDestructive
                    ? CaRismaDesignTokens.danger.withValues(alpha: 0.28)
                    : CaRismaDesignTokens.textPrimary.withValues(alpha: 0.09),
              ),
              boxShadow: CaRismaDesignTokens.surfaceShadows(
                darkAlpha: 0.22,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: icon == null
                    ? Text(
                        label,
                        textAlign: textAlign,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w900,
                          fontSize: fontSize,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: textColor, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            textAlign: textAlign,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: fontSize,
                                ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
