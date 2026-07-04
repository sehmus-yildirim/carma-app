import 'package:flutter/material.dart';

import '../theme/carisma_design_tokens.dart';

class CaRismaBackground extends StatelessWidget {
  const CaRismaBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: CaRismaDesignTokens.screenGradient,
      ),
      child: child,
    );
  }
}
