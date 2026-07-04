import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';
import 'glass_card.dart';

class CaRismaMessageCard extends StatelessWidget {
  const CaRismaMessageCard({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CaRismaDesignTokens.cardHighlight.withValues(alpha: 0.72),
                  CaRismaDesignTokens.surface2.withValues(alpha: 0.94),
                  CaRismaDesignTokens.surface1,
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: CaRismaDesignTokens.textSecondary.withValues(
                  alpha: 0.86,
                ),
                letterSpacing: 0,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
