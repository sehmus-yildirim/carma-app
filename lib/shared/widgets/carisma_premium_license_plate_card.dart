import 'package:flutter/material.dart';

import '../plate/dach_plate_presentation.dart';
import '../theme/carisma_design_tokens.dart';
import 'carisma_license_plate_preview.dart';
import 'carisma_plate_input_card.dart';
import 'glass_card.dart';

class CaRismaPremiumLicensePlateCard extends StatelessWidget {
  const CaRismaPremiumLicensePlateCard({
    super.key,
    required this.countryCode,
    required this.regionPresentation,
    required this.regionController,
    required this.lettersController,
    required this.numbersController,
    required this.regionFocusNode,
    required this.lettersFocusNode,
    required this.numbersFocusNode,
    required this.onRegionChanged,
    required this.onLettersChanged,
    required this.onNumbersChanged,
    required this.isSubmitEnabled,
    required this.isSubmitting,
    required this.onSubmit,
    this.showSubmit = true,
    this.showOuterEffects = true,
  });

  final String countryCode;
  final RegistrationRegionPresentationData regionPresentation;
  final TextEditingController regionController;
  final TextEditingController lettersController;
  final TextEditingController numbersController;
  final FocusNode regionFocusNode;
  final FocusNode lettersFocusNode;
  final FocusNode numbersFocusNode;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onLettersChanged;
  final ValueChanged<String> onNumbersChanged;
  final bool isSubmitEnabled;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final bool showSubmit;
  final bool showOuterEffects;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      radius: 24,
      glow: showOuterEffects,
      showOuterEffects: showOuterEffects,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CaRismaLicensePlatePreview(
            countryCode: countryCode,
            region: regionController.text,
            letters: lettersController.text,
            numbers: numbersController.text,
            regionPresentation: regionPresentation,
          ),
          const SizedBox(height: 14),
          CaRismaPlateInputCard(
            countryCode: countryCode,
            regionController: regionController,
            lettersController: lettersController,
            numbersController: numbersController,
            regionFocusNode: regionFocusNode,
            lettersFocusNode: lettersFocusNode,
            numbersFocusNode: numbersFocusNode,
            onRegionChanged: onRegionChanged,
            onLettersChanged: onLettersChanged,
            onNumbersChanged: onNumbersChanged,
            embedded: true,
          ),
          if (showSubmit) ...[
            const SizedBox(height: 13),
            _PremiumSubmitButton(
              isEnabled: isSubmitEnabled,
              isLoading: isSubmitting,
              onPressed: onSubmit,
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumSubmitButton extends StatefulWidget {
  const _PremiumSubmitButton({
    required this.isEnabled,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  State<_PremiumSubmitButton> createState() => _PremiumSubmitButtonState();
}

class _PremiumSubmitButtonState extends State<_PremiumSubmitButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final canTap = widget.isEnabled && !widget.isLoading;

    return Opacity(
      opacity: widget.isEnabled ? 1 : 0.45,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _isPressed ? 0.98 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canTap ? widget.onPressed : null,
            onHighlightChanged: (value) {
              if (_isPressed != value) {
                setState(() => _isPressed = value);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: CaRismaDesignTokens.controlSurface,
                border: Border.all(
                  color: canTap
                      ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.12),
                  width: canTap ? 1.4 : 1,
                ),
                boxShadow: canTap
                    ? [
                        BoxShadow(
                          color: CaRismaDesignTokens.bluePrimary.withValues(
                            alpha: 0.16,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    if (widget.isLoading)
                      const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: CaRismaDesignTokens.bluePrimary,
                        ),
                      )
                    else
                      const Icon(
                        Icons.search_rounded,
                        color: CaRismaDesignTokens.bluePrimary,
                        size: 27,
                      ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        widget.isLoading
                            ? 'Prüfung läuft...'
                            : 'Anfrage prüfen',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: CaRismaDesignTokens.bluePrimary,
                      size: 25,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
