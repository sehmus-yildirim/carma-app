import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';

class CaRismaSectionTitle extends StatelessWidget {
  const CaRismaSectionTitle({
    super.key,
    required this.number,
    required this.title,
    this.optional = false,
  });

  final String number;
  final String title;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                CaRismaDesignTokens.bluePrimary,
                CaRismaDesignTokens.bluePrimary,
                CaRismaDesignTokens.bluePrimary,
              ],
            ),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: CaRismaDesignTokens.onAccent,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            optional ? '$title · optional' : title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: CaRismaDesignTokens.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}
