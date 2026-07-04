import 'package:flutter/material.dart';

import '../plate/plate_country_config.dart';
import '../theme/carisma_design_tokens.dart';
import 'glass_card.dart';

class CaRismaCountrySelectorCard extends StatelessWidget {
  const CaRismaCountrySelectorCard({
    super.key,
    required this.selectedCountryCode,
    required this.onChanged,
    this.isLocked = false,
  });

  final String selectedCountryCode;
  final ValueChanged<String> onChanged;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isLocked ? 0.56 : 1,
      child: GlassCard(
        padding: const EdgeInsets.all(8),
        radius: 22,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLocked ? null : () => onChanged(config.countryCode),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0B5EF5),
                      Color(0xFF1E7BFF),
                      Color(0xFF2D6DFF),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.035),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.08),
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
                        alpha: 0.32,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 9),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                config.countryLabel,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
