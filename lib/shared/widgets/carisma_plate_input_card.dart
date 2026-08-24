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
    this.embedded = false,
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
  final bool embedded;

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

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: fields),
        if (onUseVoiceInput != null) ...[
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            child: _VoiceInputButton(
              isLoading: isVoiceInputLoading,
              onPressed: isLocked ? null : onUseVoiceInput,
            ),
          ),
        ],
      ],
    );

    return Opacity(
      opacity: isLocked ? 0.56 : 1,
      child: embedded
          ? content
          : GlassCard(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              radius: 24,
              child: content,
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
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: CaRismaDesignTokens.controlSurface,
          border: Border.all(
            color: isEnabled
                ? CaRismaDesignTokens.blueBright.withValues(alpha: 0.30)
                : CaRismaDesignTokens.textPrimary.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CaRismaDesignTokens.bluePrimary.withValues(
                  alpha: isEnabled ? 0.20 : 0.08,
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.1,
                        color: CaRismaDesignTokens.blueBright,
                      ),
                    )
                  : Icon(
                      Icons.mic_rounded,
                      size: 23,
                      color: isEnabled
                          ? CaRismaDesignTokens.blueBright
                          : CaRismaDesignTokens.textPrimary.withValues(
                              alpha: 0.45,
                            ),
                    ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                isLoading ? 'Hört zu...' : 'Kennzeichen sprechen',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isEnabled
                      ? Colors.white
                      : CaRismaDesignTokens.textPrimary.withValues(alpha: 0.45),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.graphic_eq_rounded,
              color: isEnabled
                  ? CaRismaDesignTokens.blueBright.withValues(alpha: 0.72)
                  : CaRismaDesignTokens.textPrimary.withValues(alpha: 0.22),
              size: 25,
            ),
            const SizedBox(width: 4),
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
        Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: Theme.of(context).textSelectionTheme.copyWith(
              cursorColor: CaRismaDesignTokens.blueBright,
              selectionHandleColor: Colors.transparent,
            ),
          ),
          child: TextField(
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
              fillColor: CaRismaDesignTokens.controlSurface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 19,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: CaRismaDesignTokens.textPrimary.withValues(
                    alpha: 0.065,
                  ),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: CaRismaDesignTokens.textPrimary.withValues(
                    alpha: 0.07,
                  ),
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
        ),
      ],
    );
  }
}
