import 'package:flutter/material.dart';

import '../plate/dach_plate_presentation.dart';
import '../plate/plate_country_config.dart';
import '../theme/carisma_design_tokens.dart';
import 'glass_card.dart';

class CaRismaCountrySelectorCard extends StatelessWidget {
  const CaRismaCountrySelectorCard({
    super.key,
    required this.selectedCountryCode,
    required this.onChanged,
    this.isLocked = false,
    this.showOuterEffects = true,
  });

  final String selectedCountryCode;
  final ValueChanged<String> onChanged;
  final bool isLocked;
  final bool showOuterEffects;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isLocked ? 0.56 : 1,
      child: GlassCard(
        padding: const EdgeInsets.all(8),
        radius: 24,
        showOuterEffects: showOuterEffects,
        child: Row(
          children: [
            for (
              var index = 0;
              index < plateCountryConfigs.length;
              index++
            ) ...[
              if (index > 0) const SizedBox(width: 6),
              Expanded(
                child: _CountryButton(
                  config: plateCountryConfigs[index],
                  selectedCountryCode: selectedCountryCode,
                  isLocked: isLocked,
                  onChanged: onChanged,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountryButton extends StatelessWidget {
  const _CountryButton({
    required this.config,
    required this.selectedCountryCode,
    required this.isLocked,
    required this.onChanged,
  });

  final PlateCountryConfig config;
  final String selectedCountryCode;
  final bool isLocked;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedCountryCode == config.countryCode;
    final presentation = countryPresentationFor(config.countryCode);

    return Semantics(
      button: true,
      selected: isSelected,
      label: config.countryLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isLocked ? null : () => onChanged(config.countryCode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: CaRismaDesignTokens.card,
            border: Border.all(
              color: isSelected
                  ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.34),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: CaRismaDesignTokens.bluePrimary.withValues(
                        alpha: 0.18,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image.asset(
                      presentation.flagAsset,
                      width: config.countryCode == 'CH' ? 20 : 26,
                      height: 18,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 26, height: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    config.countryLabel,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
