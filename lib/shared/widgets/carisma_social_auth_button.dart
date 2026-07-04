import 'package:flutter/material.dart';

enum CaRismaSocialAuthProvider { google, apple }

class CaRismaSocialAuthButton extends StatelessWidget {
  const CaRismaSocialAuthButton({
    super.key,
    required this.provider,
    required this.onPressed,
  });

  final CaRismaSocialAuthProvider provider;
  final VoidCallback onPressed;

  String get _label {
    return switch (provider) {
      CaRismaSocialAuthProvider.google => 'Mit Google fortfahren',
      CaRismaSocialAuthProvider.apple => 'Mit Apple fortfahren',
    };
  }

  IconData get _icon {
    return switch (provider) {
      CaRismaSocialAuthProvider.google => Icons.g_mobiledata_rounded,
      CaRismaSocialAuthProvider.apple => Icons.apple_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.92),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _icon,
                color: Colors.black.withValues(alpha: 0.86),
                size: provider == CaRismaSocialAuthProvider.google ? 30 : 24,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
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
