import 'package:flutter/services.dart';

class LettersOnlyFormatter extends TextInputFormatter {
  const LettersOnlyFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final normalized =
    newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-ZÄÖÜ]'), '');

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}

class NumbersOnlyFormatter extends TextInputFormatter {
  const NumbersOnlyFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final normalized = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}

class GermanNumberWithOptionalEFormatter extends TextInputFormatter {
  const GermanNumberWithOptionalEFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final upper = newValue.text.toUpperCase();
    final buffer = StringBuffer();

    var digitCount = 0;
    var hasE = false;

    for (var i = 0; i < upper.length; i++) {
      final char = upper[i];

      if (RegExp(r'[0-9]').hasMatch(char)) {
        if (!hasE && digitCount < 4) {
          buffer.write(char);
          digitCount++;
        }
        continue;
      }

      if (char == 'E' && !hasE && digitCount > 0 && i == upper.length - 1) {
        buffer.write(char);
        hasE = true;
      }
    }

    final normalized = buffer.toString();

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}