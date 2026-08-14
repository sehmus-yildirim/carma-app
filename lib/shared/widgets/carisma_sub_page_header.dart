import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';
import 'carisma_blue_icon_box.dart';
import 'glass_card.dart';

class CaRismaSubPageHeader extends StatelessWidget {
  const CaRismaSubPageHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.onBack,
    this.titleFontSize,
  });

  final IconData icon;
  final String title;
  final VoidCallback onBack;
  final double? titleFontSize;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _RoundBackButton(onTap: onBack),
          const SizedBox(width: 12),
          CaRismaBlueIconBox(icon: icon, size: 46, iconSize: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: CaRismaDesignTokens.textPrimary,
                fontSize: titleFontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: CaRismaDesignTokens.surfaceGradient(),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
