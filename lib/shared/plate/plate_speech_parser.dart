import 'german_plate_region_codes.dart';
import 'plate_country_config.dart';

class PlateSpeechParseResult {
  const PlateSpeechParseResult({
    required this.region,
    required this.letters,
    required this.numbers,
  });

  final String region;
  final String letters;
  final String numbers;

  bool get hasAnyValue {
    return region.isNotEmpty || letters.isNotEmpty || numbers.isNotEmpty;
  }
}

PlateSpeechParseResult parseSpokenPlateInput({
  required String countryCode,
  required String transcript,
  required String currentRegion,
  required String currentLetters,
  required String currentNumbers,
}) {
  final config = plateConfigForCountry(countryCode);
  final normalized = _normalizeSpokenInput(transcript);

  if (normalized.isEmpty) {
    return PlateSpeechParseResult(
      region: currentRegion.trim().toUpperCase(),
      letters: currentLetters.trim().toUpperCase(),
      numbers: currentNumbers.trim().toUpperCase(),
    );
  }

  final alphaTokens = RegExp('[A-Z\\u00c4\\u00d6\\u00dc]+')
      .allMatches(normalized)
      .map((match) => match.group(0) ?? '')
      .where((value) => value.isNotEmpty)
      .map(_normalizeAlphaToken)
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  final digitTokens = RegExp(r'\d+')
      .allMatches(normalized)
      .map((match) => match.group(0) ?? '')
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  var region = currentRegion.trim().toUpperCase();
  var letters = currentLetters.trim().toUpperCase();
  var numbers = currentNumbers.trim().toUpperCase();

  if (countryCode == 'CH') {
    if (region.isEmpty && alphaTokens.isNotEmpty) {
      region = _fitRegionToken(alphaTokens.first, config.regionMaxLength);
    }

    if (digitTokens.isNotEmpty) {
      final mergedDigits = digitTokens.join('');
      numbers = mergedDigits.substring(
        0,
        mergedDigits.length.clamp(0, config.numbersMaxLength),
      );
    }

    return PlateSpeechParseResult(
      region: region,
      letters: '',
      numbers: numbers,
    );
  }

  if (countryCode == 'AT') {
    final firstAlpha = alphaTokens.isNotEmpty ? alphaTokens.first : '';
    final lastAlpha = alphaTokens.length > 1 ? alphaTokens.last : '';
    final mergedDigits = digitTokens.join('');

    if (region.isEmpty && firstAlpha.isNotEmpty) {
      region = _fitRegionToken(firstAlpha, config.regionMaxLength);
    }

    if (mergedDigits.isNotEmpty) {
      numbers = mergedDigits.substring(
        0,
        mergedDigits.length.clamp(0, config.numbersMaxLength),
      );
    }

    if (letters.isEmpty) {
      final candidate = lastAlpha.isNotEmpty && lastAlpha != firstAlpha
          ? lastAlpha
          : (alphaTokens.length == 1 &&
                    firstAlpha.length > config.regionMaxLength
                ? firstAlpha.substring(config.regionMaxLength)
                : '');
      if (candidate.isNotEmpty) {
        letters = _fitLettersToken(candidate, config.lettersMaxLength);
      }
    }

    return PlateSpeechParseResult(
      region: region,
      letters: letters,
      numbers: numbers,
    );
  }

  if (alphaTokens.isNotEmpty) {
    if (region.isEmpty) {
      final splitAlpha = _splitGermanAlphaTokens(alphaTokens, config);
      region = splitAlpha.region;

      if (letters.isEmpty) {
        final candidate = splitAlpha.letters.isNotEmpty
            ? splitAlpha.letters
            : (alphaTokens.length > 1 ? alphaTokens[1] : '');
        if (candidate.isNotEmpty) {
          letters = _fitLettersToken(candidate, config.lettersMaxLength);
        }
      }
    } else if (letters.isEmpty) {
      letters = _fitLettersToken(alphaTokens.join(), config.lettersMaxLength);
    }
  }

  if (digitTokens.isNotEmpty) {
    final mergedDigits = digitTokens.join('');
    numbers = mergedDigits.substring(
      0,
      mergedDigits.length.clamp(0, config.numbersMaxLength),
    );
  }

  return PlateSpeechParseResult(
    region: region,
    letters: letters,
    numbers: numbers,
  );
}

({String region, String letters}) _splitGermanAlphaTokens(
  List<String> tokens,
  PlateCountryConfig config,
) {
  final normalizedTokens = tokens
      .map((token) => token.trim().toUpperCase())
      .where((token) => token.isNotEmpty)
      .toList(growable: false);

  if (normalizedTokens.isEmpty) {
    return (region: '', letters: '');
  }

  if (normalizedTokens.length > 1) {
    final firstToken = normalizedTokens.first;
    final remainingTokens = normalizedTokens.skip(1).join();

    if (normalizedTokens.length >= 3 &&
        const {'AE', 'OE', 'UE'}.contains(normalizedTokens[1])) {
      final umlautRegionKey = '$firstToken${normalizedTokens[1]}';
      final umlautRegion = germanPlateRegionCodesBySpeechKey[umlautRegionKey];
      if (umlautRegion != null) {
        return (
          region: umlautRegion,
          letters: _fitLettersToken(
            normalizedTokens.skip(2).join(),
            config.lettersMaxLength,
          ),
        );
      }
    }

    if (firstToken.length > 1) {
      return (
        region: _fitRegionToken(
          _resolveGermanRegionToken(firstToken),
          config.regionMaxLength,
        ),
        letters: _fitLettersToken(remainingTokens, config.lettersMaxLength),
      );
    }

    if (normalizedTokens.length >= 2 &&
        normalizedTokens[0].length == 1 &&
        normalizedTokens[1].length == 1) {
      final knownSplit = _splitKnownGermanRegion(
        normalizedTokens.join(),
        config,
      );
      if (knownSplit != null) {
        return knownSplit;
      }
    }

    final allSingleLetters = normalizedTokens.every(
      (token) => token.length == 1,
    );

    if (allSingleLetters) {
      return _splitGermanSingleLetterRun(normalizedTokens, config);
    }

    if (remainingTokens.isNotEmpty &&
        normalizedTokens.skip(1).any((token) => token.length > 1)) {
      return (
        region: _fitRegionToken(firstToken, config.regionMaxLength),
        letters: _fitLettersToken(remainingTokens, config.lettersMaxLength),
      );
    }

    return _splitGermanCombinedAlphaToken(normalizedTokens.join(), config);
  }

  return _splitGermanCombinedAlphaToken(normalizedTokens.first, config);
}

({String region, String letters}) _splitGermanSingleLetterRun(
  List<String> tokens,
  PlateCountryConfig config,
) {
  final combined = tokens.join();

  if (combined.isEmpty) {
    return (region: '', letters: '');
  }

  final knownSplit = _splitKnownGermanRegion(combined, config);
  if (knownSplit != null) {
    return knownSplit;
  }

  if (combined.length == 3) {
    return (region: combined.substring(0, 1), letters: combined.substring(1));
  }

  if (combined.length == 4) {
    final regionLength = tokens[0] == tokens[1] ? 2 : 3;

    return (
      region: combined.substring(0, regionLength),
      letters: combined.substring(regionLength),
    );
  }

  final regionLength = (combined.length - config.lettersMaxLength)
      .clamp(1, config.regionMaxLength)
      .toInt();

  return (
    region: combined.substring(0, regionLength),
    letters: combined.substring(regionLength),
  );
}

({String region, String letters}) _splitGermanCombinedAlphaToken(
  String token,
  PlateCountryConfig config,
) {
  final normalized = token.trim().toUpperCase();

  if (normalized.isEmpty) {
    return (region: '', letters: '');
  }

  final knownSplit = _splitKnownGermanRegion(normalized, config);
  if (knownSplit != null) {
    return knownSplit;
  }

  final knownRegion = germanPlateRegionCodesBySpeechKey[normalized];
  if (knownRegion != null) {
    return (region: knownRegion, letters: '');
  }

  if (normalized.length <= config.regionMaxLength) {
    if (normalized.length == 3) {
      return (
        region: normalized.substring(0, 1),
        letters: normalized.substring(1),
      );
    }

    return (region: normalized, letters: '');
  }

  if (normalized.length == 4 && config.lettersMaxLength >= 2) {
    return (
      region: normalized.substring(0, 2),
      letters: normalized.substring(2),
    );
  }

  final regionLength = (normalized.length - config.lettersMaxLength)
      .clamp(1, config.regionMaxLength)
      .toInt();

  return (
    region: normalized.substring(0, regionLength),
    letters: normalized.substring(regionLength),
  );
}

({String region, String letters})? _splitKnownGermanRegion(
  String token,
  PlateCountryConfig config,
) {
  final normalized = token.trim().toUpperCase();
  final maxPrefixLength = (normalized.length - 1)
      .clamp(1, config.regionMaxLength + 1)
      .toInt();

  for (var prefixLength = maxPrefixLength; prefixLength >= 1; prefixLength--) {
    final lettersLength = normalized.length - prefixLength;
    if (lettersLength < 1 || lettersLength > config.lettersMaxLength) {
      continue;
    }

    final regionKey = normalized.substring(0, prefixLength);
    final region = germanPlateRegionCodesBySpeechKey[regionKey];
    if (region == null) {
      continue;
    }

    return (region: region, letters: normalized.substring(prefixLength));
  }

  return null;
}

String _resolveGermanRegionToken(String token) {
  final normalized = token.trim().toUpperCase();
  return germanPlateRegionCodesBySpeechKey[normalized] ?? normalized;
}

String _normalizeSpokenInput(String value) {
  var normalized = value.trim().toUpperCase();

  const replacements = <String, String>{
    '\u00c4': 'AE',
    '\u00d6': 'OE',
    '\u00dc': 'UE',
    '\u00df': 'SS',
    'MINUS': ' ',
    '-': ' ',
    '/': ' ',
    ',': ' ',
    '.': ' ',
  };

  replacements.forEach((from, to) {
    normalized = normalized.replaceAll(from, to);
  });

  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

  return normalized.trim();
}

String _normalizeAlphaToken(String token) {
  final normalized = token.trim().toUpperCase();

  if (normalized.isEmpty) {
    return '';
  }

  const directWordMap = <String, String>{
    'A': 'A',
    'AH': 'A',
    'B': 'B',
    'BE': 'B',
    'C': 'C',
    'CE': 'C',
    'D': 'D',
    'DE': 'D',
    'E': 'E',
    'F': 'F',
    'EF': 'F',
    'G': 'G',
    'GE': 'G',
    'H': 'H',
    'HA': 'H',
    'I': 'I',
    'J': 'J',
    'K': 'K',
    'KA': 'K',
    'L': 'L',
    'EL': 'L',
    'M': 'M',
    'EM': 'M',
    'N': 'N',
    'EN': 'N',
    'O': 'O',
    'P': 'P',
    'PE': 'P',
    'Q': 'Q',
    'KU': 'Q',
    'R': 'R',
    'ER': 'R',
    'S': 'S',
    'ES': 'S',
    'T': 'T',
    'TE': 'T',
    'U': 'U',
    'V': 'V',
    'W': 'W',
    'WE': 'W',
    'X': 'X',
    'IX': 'X',
    'Y': 'Y',
    '\u00dcPSILON': 'Y',
    'Z': 'Z',
    'ZET': 'Z',
  };

  if (directWordMap.containsKey(normalized)) {
    return directWordMap[normalized]!;
  }

  if (RegExp(r'^([A-Z]{2})\1$').hasMatch(normalized)) {
    final syllable = normalized.substring(0, 2);
    final firstLetter = _normalizeAlphaToken(syllable);
    if (firstLetter.length == 1) {
      return '$firstLetter$firstLetter';
    }
  }

  if (normalized.length == 3 && normalized.startsWith('E')) {
    return normalized.substring(1);
  }

  return normalized;
}

String _fitRegionToken(String token, int maxLength) {
  if (token.length <= maxLength) {
    return token;
  }

  if (token.length == maxLength + 1 && token.startsWith('E')) {
    return token.substring(1);
  }

  return token.substring(0, maxLength);
}

String _fitLettersToken(String token, int maxLength) {
  if (token.length <= maxLength) {
    return token;
  }

  if (token.length == maxLength + 1 && token.startsWith('E')) {
    return token.substring(1);
  }

  return token.substring(0, maxLength);
}
