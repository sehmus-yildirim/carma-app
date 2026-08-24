import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';

class CaRismaPageHeader extends StatelessWidget {
  const CaRismaPageHeader({
    super.key,
    required this.icon,
    required this.title,
    this.iconSize = 28,
    this.onAction,
    this.actionIcon = Icons.person_outline_rounded,
  });

  final IconData icon;
  final String title;
  final double iconSize;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: CaRismaDesignTokens.surface2,
            border: Border.all(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.04),
            ),
          ),
          child: Icon(
            icon,
            color: CaRismaDesignTokens.bluePrimary,
            size: iconSize,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: CaRismaDesignTokens.textPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.0,
              fontSize: 32,
            ),
          ),
        ),
        if (onAction != null) ...[
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: CaRismaDesignTokens.surface2,
                  border: Border.all(
                    color: CaRismaDesignTokens.textPrimary.withValues(
                      alpha: 0.05,
                    ),
                  ),
                ),
                child: Icon(
                  actionIcon,
                  color: CaRismaDesignTokens.textSecondary,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
