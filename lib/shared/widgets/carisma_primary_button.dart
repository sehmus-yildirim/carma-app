import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';

class CaRismaPrimaryButton extends StatelessWidget {
  const CaRismaPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isEnabled = true,
    this.isLoading = false,
    this.loadingLabel,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 21),
    this.borderRadius = 26,
    this.iconSize = 27,
    this.fontSize = 19,
    this.showShadow = true,
    this.surfaceOutlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isEnabled;
  final bool isLoading;
  final String? loadingLabel;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double iconSize;
  final double fontSize;
  final bool showShadow;
  final bool surfaceOutlined;

  @override
  Widget build(BuildContext context) {
    final canTap = isEnabled && !isLoading;
    final effectiveLabel = isLoading ? (loadingLabel ?? label) : label;
    final effectiveIcon = isLoading ? Icons.hourglass_top_rounded : icon;

    return Opacity(
      opacity: isEnabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canTap ? onPressed : null,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: surfaceOutlined
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        CaRismaDesignTokens.bluePrimary,
                        CaRismaDesignTokens.bluePrimary,
                        CaRismaDesignTokens.bluePrimary,
                      ],
                    ),
              color: surfaceOutlined
                  ? CaRismaDesignTokens.controlSurface
                  : null,
              border: Border.all(
                color: surfaceOutlined
                    ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.16),
                width: surfaceOutlined ? 1.4 : 1,
              ),
              boxShadow: showShadow
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.38),
                        blurRadius: 20,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: CaRismaDesignTokens.bluePrimary.withValues(
                          alpha: surfaceOutlined ? 0.15 : 0.36,
                        ),
                        blurRadius: surfaceOutlined ? 18 : 30,
                        offset: Offset(0, surfaceOutlined ? 6 : 10),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  effectiveIcon,
                  color: surfaceOutlined
                      ? CaRismaDesignTokens.bluePrimary
                      : Colors.white,
                  size: iconSize,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    effectiveLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: fontSize,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
