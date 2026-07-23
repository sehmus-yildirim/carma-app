import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';

enum CaRismaSocialAuthProvider { google, apple }

class CaRismaSocialAuthButton extends StatelessWidget {
  const CaRismaSocialAuthButton({
    super.key,
    required this.provider,
    this.onPressed,
    this.isEnabled = true,
  });

  final CaRismaSocialAuthProvider provider;
  final VoidCallback? onPressed;
  final bool isEnabled;

  String get _label {
    return switch (provider) {
      CaRismaSocialAuthProvider.google => 'Mit Google fortfahren',
      CaRismaSocialAuthProvider.apple => 'Mit Apple fortfahren',
    };
  }

  Widget get _providerIcon {
    return switch (provider) {
      CaRismaSocialAuthProvider.google => Image.asset(
        'assets/images/google_g_logo.png',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      ),
      CaRismaSocialAuthProvider.apple => const Icon(
        Icons.apple_rounded,
        color: CaRismaDesignTokens.textPrimary,
        size: 27,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final canTap = isEnabled && onPressed != null;

    return _CaRismaAuthButtonSurface(
      label: _label,
      leading: _providerIcon,
      enabled: canTap,
      borderColor: canTap
          ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.72)
          : Colors.white.withValues(alpha: 0.10),
      onPressed: onPressed,
    );
  }
}

class CaRismaAuthNavigationButton extends StatelessWidget {
  const CaRismaAuthNavigationButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isEnabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return _CaRismaAuthButtonSurface(
      label: label,
      leading: Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 26),
      enabled: isEnabled,
      borderColor: Colors.white.withValues(alpha: 0.10),
      onPressed: onPressed,
    );
  }
}

class _CaRismaAuthButtonSurface extends StatelessWidget {
  const _CaRismaAuthButtonSurface({
    required this.label,
    required this.leading,
    required this.enabled,
    required this.borderColor,
    required this.onPressed,
  });

  final String label;
  final Widget leading;
  final bool enabled;
  final Color borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.46,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: CaRismaDesignTokens.controlSurface,
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 18,
                    child: SizedBox.square(
                      dimension: 28,
                      child: Center(child: leading),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 52),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: CaRismaDesignTokens.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CaRismaAuthDivider extends StatelessWidget {
  const CaRismaAuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'oder',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.54),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}
