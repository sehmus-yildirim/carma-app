import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';

class CaRismaSectionTitle extends StatelessWidget {
  const CaRismaSectionTitle({
    super.key,
    required this.number,
    required this.title,
    this.optional = false,
    this.outlinedNumber = false,
  });

  final String number;
  final String title;
  final bool optional;
  final bool outlinedNumber;

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
            color: outlinedNumber ? CaRismaDesignTokens.controlSurface : null,
            gradient: outlinedNumber
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
            border: outlinedNumber
                ? Border.all(
                    color: CaRismaDesignTokens.bluePrimary.withValues(
                      alpha: 0.88,
                    ),
                    width: 1.4,
                  )
                : null,
          ),
          child: Text(
            number,
            style: TextStyle(
              color: outlinedNumber
                  ? CaRismaDesignTokens.bluePrimary
                  : CaRismaDesignTokens.onAccent,
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
