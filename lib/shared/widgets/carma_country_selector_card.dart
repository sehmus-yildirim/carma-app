import 'package:flutter/material.dart';

import '../plate/plate_country_config.dart';
import 'glass_card.dart';

const Color _carmaBlue = Color(0xFF139CFF);
const Color _carmaBlueLight = Color(0xFF63D5FF);
const Color _carmaBlueDark = Color(0xFF0A76FF);

class CarmaCountrySelectorCard extends StatelessWidget {
  const CarmaCountrySelectorCard({
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
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            for (var index = 0; index < plateCountryConfigs.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
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
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isSelected
                ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _carmaBlueDark,
                _carmaBlue,
                _carmaBlueLight,
              ],
            )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: _carmaBlue.withValues(alpha: 0.26),
                blurRadius: 18,
                offset: const Offset(0, 8),
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
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}