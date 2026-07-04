import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../plate/plate_country_config.dart';
import '../plate/plate_input_formatters.dart';
import '../theme/carisma_design_tokens.dart';
import 'glass_card.dart';

class CaRismaPlateInputCard extends StatelessWidget {
  const CaRismaPlateInputCard({
    super.key,
    required this.countryCode,
    required this.regionController,
    required this.lettersController,
    required this.numbersController,
    required this.regionFocusNode,
    required this.lettersFocusNode,
    required this.numbersFocusNode,
    required this.onRegionChanged,
    required this.onLettersChanged,
    required this.onNumbersChanged,
    this.isLocked = false,
    this.onUseVoiceInput,
    this.isVoiceInputLoading = false,
  });

  final String countryCode;

  final TextEditingController regionController;
  final TextEditingController lettersController;
  final TextEditingController numbersController;

  final FocusNode regionFocusNode;
  final FocusNode lettersFocusNode;
  final FocusNode numbersFocusNode;

  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onLettersChanged;
  final ValueChanged<String> onNumbersChanged;

  final bool isLocked;
  final VoidCallback? onUseVoiceInput;
  final bool isVoiceInputLoading;

  PlateCountryConfig get _config {
    return plateConfigForCountry(countryCode);
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      Expanded(
        child: _PlateInputField(
          label: _config.regionLabel,
          controller: regionController,
          focusNode: regionFocusNode,
          textInputAction: TextInputAction.next,
          maxLength: _config.regionMaxLength,
          inputFormatters: const [LettersOnlyFormatter()],
          enabled: !isLocked,
          onChanged: onRegionChanged,
        ),
      ),
    ];

    if (countryCode == 'AT') {
      fields.addAll([
        const SizedBox(width: 10),
        Expanded(
          child: _PlateInputField(
            label: 'Zahlen',
            controller: numbersController,
            focusNode: numbersFocusNode,
            textInputAction: TextInputAction.next,
            maxLength: _config.numbersMaxLength,
            inputFormatters: const [NumbersOnlyFormatter()],
            enabled: !isLocked,
            onChanged: onNumbersChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlateInputField(
            label: 'Buchstaben',
            controller: lettersController,
            focusNode: lettersFocusNode,
            textInputAction: TextInputAction.done,
            maxLength: _config.lettersMaxLength,
            inputFormatters: const [LettersOnlyFormatter()],
            enabled: !isLocked,
            onChanged: onLettersChanged,
          ),
        ),
      ]);
    } else if (countryCode == 'CH') {
      fields.addAll([
        const SizedBox(width: 10),
        Expanded(
          child: _PlateInputField(
            label: 'Zahlen',
            controller: numbersController,
            focusNode: numbersFocusNode,
            textInputAction: TextInputAction.done,
            maxLength: _config.numbersMaxLength,
            inputFormatters: const [NumbersOnlyFormatter()],
            enabled: !isLocked,
            onChanged: onNumbersChanged,
          ),
        ),
      ]);
    } else {
      fields.addAll([
        const SizedBox(width: 10),
        Expanded(
          child: _PlateInputField(
            label: 'Buchstaben',
            controller: lettersController,
            focusNode: lettersFocusNode,
            textInputAction: TextInputAction.next,
            maxLength: _config.lettersMaxLength,
            inputFormatters: const [LettersOnlyFormatter()],
            enabled: !isLocked,
            onChanged: onLettersChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlateInputField(
            label: 'Zahlen',
            controller: numbersController,
            focusNode: numbersFocusNode,
            textInputAction: TextInputAction.done,
            maxLength: _config.numbersMaxLength,
            inputFormatters: const [GermanNumberWithOptionalEFormatter()],
            enabled: !isLocked,
            onChanged: onNumbersChanged,
          ),
        ),
      ]);
    }

    return Opacity(
      opacity: isLocked ? 0.56 : 1,
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: fields),
            if (onUseVoiceInput != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _VoiceInputButton(
                  isLoading: isVoiceInputLoading,
                  onPressed: isLocked ? null : onUseVoiceInput,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VoiceInputButton extends StatelessWidget {
  const _VoiceInputButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return InkWell(
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: CaRismaDesignTokens.bluePrimary.withValues(
            alpha: isEnabled ? 0.18 : 0.08,
          ),
          border: Border.all(
            color: isEnabled
                ? CaRismaDesignTokens.blueBright.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.1,
                  color: CaRismaDesignTokens.blueBright,
                ),
              )
            else
              Icon(
                Icons.mic_rounded,
                size: 18,
                color: isEnabled
                    ? CaRismaDesignTokens.blueBright
                    : Colors.white.withValues(alpha: 0.45),
              ),
            const SizedBox(width: 8),
            Text(
              isLoading ? 'H\\u00f6rt zu...' : 'Kennzeichen sprechen',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isEnabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlateInputField extends StatelessWidget {
  const _PlateInputField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.textInputAction,
    required this.maxLength,
    required this.inputFormatters,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputAction textInputAction;
  final int maxLength;
  final List<TextInputFormatter> inputFormatters;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.94),
              fontWeight: FontWeight.w900,
              fontSize: 14.5,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          maxLength: maxLength,
          keyboardType: TextInputType.text,
          textInputAction: textInputAction,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: CaRismaDesignTokens.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 23,
            letterSpacing: 0.8,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: CaRismaDesignTokens.surface1.withValues(alpha: 0.92),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 19,
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.065),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: CaRismaDesignTokens.blueBright.withValues(alpha: 0.92),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
