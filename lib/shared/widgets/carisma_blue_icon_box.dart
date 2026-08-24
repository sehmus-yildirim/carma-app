import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';

class CaRismaBlueIconBox extends StatelessWidget {
  const CaRismaBlueIconBox({
    super.key,
    required this.icon,
    this.size = 46,
    this.iconSize = 23,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        color: CaRismaDesignTokens.surface2,
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.05),
          width: 1.0,
        ),
      ),
      child: Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: iconSize),
    );
  }
}
