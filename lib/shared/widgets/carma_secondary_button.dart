import 'package:flutter/material.dart';

class CarmaSecondaryButton extends StatelessWidget {
  const CarmaSecondaryButton({
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
    final textColor =
    isDestructive ? const Color(0xFFFF8A8A) : Colors.white;

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
              color: Colors.white.withValues(alpha: 0.10),
              border: Border.all(
                color: isDestructive
                    ? const Color(0xFFFF8A8A).withValues(alpha: 0.24)
                    : Colors.white.withValues(alpha: 0.14),
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
                    Icon(
                      icon,
                      color: textColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      textAlign: textAlign,
                      style:
                      Theme.of(context).textTheme.bodyLarge?.copyWith(
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