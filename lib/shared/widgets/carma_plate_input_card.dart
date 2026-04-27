import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../plate/plate_country_config.dart';
import '../plate/plate_input_formatters.dart';
import 'glass_card.dart';

const Color _carmaBlueLight = Color(0xFF63D5FF);

class CarmaPlateInputCard extends StatelessWidget {
  const CarmaPlateInputCard({
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
          inputFormatters: const [
            LettersOnlyFormatter(),
          ],
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
            inputFormatters: const [
              NumbersOnlyFormatter(),
            ],
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
            inputFormatters: const [
              LettersOnlyFormatter(),
            ],
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
            inputFormatters: const [
              NumbersOnlyFormatter(),
            ],
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
            inputFormatters: const [
              LettersOnlyFormatter(),
            ],
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
            inputFormatters: const [
              GermanNumberWithOptionalEFormatter(),
            ],
            enabled: !isLocked,
            onChanged: onNumbersChanged,
          ),
        ),
      ]);
    }

    return Opacity(
      opacity: isLocked ? 0.56 : 1,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: fields,
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
              color: Colors.white.withValues(alpha: 0.96),
              fontWeight: FontWeight.w900,
              fontSize: 15.5,
              letterSpacing: -0.1,
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
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 23,
            letterSpacing: 0.8,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.10),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 18,
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: _carmaBlueLight.withValues(alpha: 0.90),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}