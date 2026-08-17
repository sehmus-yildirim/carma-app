import 'package:flutter/material.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';

class ProfileSectionAddButton extends StatelessWidget {
  const ProfileSectionAddButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CaRismaDesignTokens.controlSurface,
            border: Border.all(
              color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.82),
            ),
          ),
          child: const Icon(
            Icons.add_rounded,
            size: 17,
            color: CaRismaDesignTokens.blueBright,
          ),
        ),
      ),
    );
  }
}
