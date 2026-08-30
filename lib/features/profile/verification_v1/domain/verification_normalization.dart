final RegExp _whitespace = RegExp(r'\s+');
final RegExp _plateSeparators = RegExp(r'[\s\-]+');
final RegExp _datePattern = RegExp(
  r'(?<!\d)(\d{1,4})\s*(?:[.\-/]|\s+)\s*(\d{1,2})\s*(?:[.\-/]|\s+)\s*(\d{1,4})(?!\d)',
);
final RegExp _compactDatePattern = RegExp(r'(?<!\d)(\d{8})(?!\d)');

String normalizePersonName(String raw) {
  var value = _composeRelevantUnicode(raw.trim().toLowerCase());
  value = value
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('’', "'")
      .replaceAll('`', "'")
      .replaceAll('´', "'")
      .replaceAll(RegExp(r'\s*[-]\s*'), '-')
      .replaceAll(RegExp(r"\s*'\s*"), "'")
      .replaceAll(_whitespace, ' ');
  return value.trim();
}

String normalizePlate(String raw, {String countryCode = 'DE'}) {
  final country = countryCode.trim().toUpperCase();
  final plate = raw
      .trim()
      .toUpperCase()
      .replaceAll(_plateSeparators, '')
      .replaceAll(RegExp(r'[^A-ZÄÖÜ0-9]'), '');
  return country.isEmpty ? plate : '${country}_$plate';
}

bool conservativeLastNameMatch(String left, String right) =>
    normalizePersonName(left) == normalizePersonName(right);

bool conservativeFirstNamesMatch(String left, String right) {
  final leftTokens = _nameTokens(left);
  final rightTokens = _nameTokens(right);
  if (leftTokens.isEmpty || rightTokens.isEmpty) return false;
  if (leftTokens.first != rightTokens.first) return false;
  return _isOrderedSubset(leftTokens, rightTokens) ||
      _isOrderedSubset(rightTokens, leftTokens);
}

DateTime? parseDocumentDate(String raw) {
  final normalized = raw
      .replaceAll(RegExp(r'[oO]'), '0')
      .replaceAll(RegExp(r'[iIlL|]'), '1')
      .replaceAll(RegExp(r'[·•,;:_]'), '.');
  for (final match in _datePattern.allMatches(normalized)) {
    final first = int.tryParse(match.group(1)!);
    final second = int.tryParse(match.group(2)!);
    final third = int.tryParse(match.group(3)!);
    if (first == null || second == null || third == null) continue;
    final yearFirst = match.group(1)!.length == 4;
    final year = yearFirst ? first : _expandFourDigitYear(third);
    final month = second;
    final day = yearFirst ? third : first;
    final parsed = _validDate(year, month, day);
    if (parsed != null) return parsed;
  }
  for (final match in _compactDatePattern.allMatches(normalized)) {
    final value = match.group(1)!;
    final yearFirst = int.tryParse(value.substring(0, 4));
    if (yearFirst != null && yearFirst >= 1900 && yearFirst <= 2199) {
      final parsed = _validDate(
        yearFirst,
        int.parse(value.substring(4, 6)),
        int.parse(value.substring(6, 8)),
      );
      if (parsed != null) return parsed;
    }
    final parsed = _validDate(
      int.parse(value.substring(4, 8)),
      int.parse(value.substring(2, 4)),
      int.parse(value.substring(0, 2)),
    );
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime? parseMrzDateOfBirth(String raw, {DateTime? now}) {
  if (!RegExp(r'^\d{6}$').hasMatch(raw)) return null;
  final today = now ?? DateTime.now();
  final yearPart = int.parse(raw.substring(0, 2));
  final month = int.parse(raw.substring(2, 4));
  final day = int.parse(raw.substring(4, 6));
  final candidates =
      <DateTime?>[
        _validDate(1900 + yearPart, month, day),
        _validDate(2000 + yearPart, month, day),
      ].whereType<DateTime>().where((date) {
        final age = ageOn(date, today);
        return age >= 16 && age <= 120;
      }).toList();
  if (candidates.length != 1) return null;
  return candidates.single;
}

DateTime? parseMrzExpiryDate(String raw) {
  if (!RegExp(r'^\d{6}$').hasMatch(raw)) return null;
  return _validDate(
    2000 + int.parse(raw.substring(0, 2)),
    int.parse(raw.substring(2, 4)),
    int.parse(raw.substring(4, 6)),
  );
}

int ageOn(DateTime birthDate, DateTime date) {
  var age = date.year - birthDate.year;
  if (date.month < birthDate.month ||
      (date.month == birthDate.month && date.day < birthDate.day)) {
    age -= 1;
  }
  return age;
}

bool mrzCheckDigitIsValid(String value, String digit) {
  if (!RegExp(r'^\d$').hasMatch(digit)) return false;
  const weights = <int>[7, 3, 1];
  var total = 0;
  for (var index = 0; index < value.length; index += 1) {
    total += _mrzValue(value[index]) * weights[index % weights.length];
  }
  return total % 10 == int.parse(digit);
}

List<String> _nameTokens(String raw) => normalizePersonName(
  raw,
).split(' ').where((token) => token.isNotEmpty).toList(growable: false);

bool _isOrderedSubset(List<String> shorter, List<String> longer) {
  if (shorter.length > longer.length) return false;
  var cursor = 0;
  for (final token in longer) {
    if (cursor < shorter.length && token == shorter[cursor]) cursor += 1;
  }
  return cursor == shorter.length;
}

int _expandFourDigitYear(int value) => value < 100 ? 2000 + value : value;

DateTime? _validDate(int year, int month, int day) {
  if (year < 1900 || year > 2199 || month < 1 || month > 12 || day < 1) {
    return null;
  }
  final candidate = DateTime(year, month, day);
  if (candidate.year != year ||
      candidate.month != month ||
      candidate.day != day) {
    return null;
  }
  return candidate;
}

int _mrzValue(String character) {
  final code = character.codeUnitAt(0);
  if (code >= 48 && code <= 57) return code - 48;
  if (code >= 65 && code <= 90) return code - 55;
  return 0;
}

String _composeRelevantUnicode(String value) {
  const replacements = <String, String>{
    'a\u0308': 'ä',
    'o\u0308': 'ö',
    'u\u0308': 'ü',
    'a\u0301': 'á',
    'e\u0301': 'é',
    'i\u0307': 'i',
    'i\u0301': 'í',
    'o\u0301': 'ó',
    'u\u0301': 'ú',
    'c\u0327': 'ç',
    'g\u0306': 'ğ',
    's\u0327': 'ş',
  };
  var normalized = value;
  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized;
}
