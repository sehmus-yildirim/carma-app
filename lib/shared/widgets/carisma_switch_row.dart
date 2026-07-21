import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';
import 'carisma_blue_icon_box.dart';

class CaRismaSwitchRow extends StatelessWidget {
  const CaRismaSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: CaRismaDesignTokens.controlSurface,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: CaRismaDesignTokens.surfaceShadows(
            darkAlpha: 0.20,
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ),
        child: Row(
          children: [
            CaRismaBlueIconBox(icon: icon, size: 44, iconSize: 22),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: CaRismaDesignTokens.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CaRismaDesignTokens.textSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeThumbColor: Colors.white,
              activeTrackColor: CaRismaDesignTokens.bluePrimary,
              inactiveThumbColor: Colors.white.withValues(alpha: 0.76),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
