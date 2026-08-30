import 'verification_models.dart';
import 'verification_normalization.dart';

abstract interface class IdentityDocumentParser {
  VerificationParseResult<IdentityDocumentData> parse(List<OcrBlock> blocks);
}

abstract interface class VehicleRegistrationParser {
  VerificationParseResult<VehicleRegistrationData> parse(List<OcrBlock> blocks);
}

class GermanIdCardFrontParser extends _LabelledIdentityParser {
  const GermanIdCardFrontParser()
    : super(
        documentType: VerificationIdentityDocumentType.idCard,
        parserVersion: 'de_id_front_v1.0.0',
      );
}

class GermanResidencePermitFrontParser extends _LabelledIdentityParser {
  const GermanResidencePermitFrontParser()
    : super(
        documentType: VerificationIdentityDocumentType.residencePermit,
        parserVersion: 'de_residence_front_v1.0.0',
      );
}

class PassportDataPageParser implements IdentityDocumentParser {
  const PassportDataPageParser({this.now});

  final DateTime? now;

  @override
  VerificationParseResult<IdentityDocumentData> parse(List<OcrBlock> blocks) {
    final hasMrz = blocks.any(
      (block) => block.text
          .split(RegExp(r'[\r\n]+'))
          .any((line) => line.trimLeft().toUpperCase().startsWith('P<')),
    );
    final visual = const _LabelledIdentityParser(
      documentType: VerificationIdentityDocumentType.passport,
      parserVersion: 'passport_data_page_v1.0.0',
    ).parse(blocks);
    final mrz = _parseMrz(blocks);
    if (visual.isSuccess && mrz.isSuccess) {
      final visualData = visual.data!;
      final mrzData = mrz.data!;
      if (!conservativeLastNameMatch(visualData.lastName, mrzData.lastName) ||
          !conservativeFirstNamesMatch(
            visualData.firstNames,
            mrzData.firstNames,
          ) ||
          !_sameDay(visualData.dateOfBirth, mrzData.dateOfBirth) ||
          !_sameDay(visualData.expiresAt, mrzData.expiresAt)) {
        return const VerificationParseResult.failure(
          VerificationParseFailure.conflictingMrz,
          'Die sichtbaren Angaben und die maschinenlesbare Zone widersprechen sich. Bitte fotografiere die Datenseite erneut.',
        );
      }
      return mrz;
    }
    if (mrz.isSuccess) return mrz;
    if (hasMrz) return mrz;
    return visual;
  }

  VerificationParseResult<IdentityDocumentData> _parseMrz(
    List<OcrBlock> blocks,
  ) {
    final lines = blocks
        .expand((block) => block.text.split(RegExp(r'[\r\n]+')))
        .map((line) => line.toUpperCase().replaceAll(RegExp(r'\s+'), ''))
        .where((line) => line.length >= 40)
        .toList(growable: false);
    String? firstLine;
    String? secondLine;
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      if (line.startsWith('P<') && line.length >= 44) {
        firstLine = line.substring(0, 44);
        if (index + 1 < lines.length && lines[index + 1].length >= 44) {
          secondLine = lines[index + 1].substring(0, 44);
        }
        break;
      }
    }
    if (firstLine == null || secondLine == null) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.missingRequiredField,
        'Die Datenseite wurde nicht vollständig erkannt. Bitte positioniere sie vollständig im Rahmen.',
      );
    }
    final names = firstLine.substring(5).split('<<');
    if (names.length < 2) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.ambiguousField,
        'Vor- und Nachname konnten nicht eindeutig erkannt werden.',
      );
    }
    final lastName = names.first.replaceAll('<', ' ').trim();
    final firstNames = names.sublist(1).join(' ').replaceAll('<', ' ').trim();
    final dateOfBirthRaw = secondLine.substring(13, 19);
    final dateOfBirthCheck = secondLine.substring(19, 20);
    final expiresAtRaw = secondLine.substring(21, 27);
    final expiresAtCheck = secondLine.substring(27, 28);
    if (!mrzCheckDigitIsValid(dateOfBirthRaw, dateOfBirthCheck) ||
        !mrzCheckDigitIsValid(expiresAtRaw, expiresAtCheck)) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.ambiguousField,
        'Die maschinenlesbare Zone ist nicht eindeutig. Bitte fotografiere die Datenseite erneut.',
      );
    }
    final dateOfBirth = parseMrzDateOfBirth(dateOfBirthRaw, now: now);
    final expiresAt = parseMrzExpiryDate(expiresAtRaw);
    if (lastName.isEmpty ||
        firstNames.isEmpty ||
        dateOfBirth == null ||
        expiresAt == null) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.invalidDate,
        'Geburts- oder Ablaufdatum konnte nicht eindeutig erkannt werden.',
      );
    }
    return VerificationParseResult.success(
      IdentityDocumentData(
        firstNames: firstNames,
        lastName: lastName,
        dateOfBirth: dateOfBirth,
        expiresAt: expiresAt,
        documentType: VerificationIdentityDocumentType.passport,
        parserVersion: 'passport_mrz_v1.0.0',
      ),
    );
  }
}

class GermanVehicleRegistrationFrontParser
    implements VehicleRegistrationParser {
  const GermanVehicleRegistrationFrontParser();

  @override
  VerificationParseResult<VehicleRegistrationData> parse(
    List<OcrBlock> blocks,
  ) {
    final layout = _OcrLayout(blocks);
    final plate = layout.valueForLabels(const ['A'], exactLabel: true);
    final holderName = layout.valueForLabels(const ['C.1.1', 'C 1.1']);
    final holderFirstNames = layout.valueForLabels(const ['C.1.2', 'C 1.2']);
    final normalizedPlate = plate
        ?.toUpperCase()
        .replaceAll(RegExp(r'[^A-ZÄÖÜ0-9\- ]'), '')
        .trim();
    if (normalizedPlate == null || normalizedPlate.length < 3) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.missingRequiredField,
        'Das Kennzeichen in Feld A wurde nicht erkannt. Bitte fotografiere den Fahrzeugschein erneut.',
      );
    }
    if (holderName == null || holderName.trim().length < 2) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.missingRequiredField,
        'Das Halterfeld C.1.1 wurde nicht erkannt. Bitte fotografiere den Fahrzeugschein erneut.',
      );
    }
    return VerificationParseResult.success(
      VehicleRegistrationData(
        plate: normalizedPlate,
        holderNameOrCompany: holderName.trim(),
        holderFirstNames: holderFirstNames?.trim().isEmpty == true
            ? null
            : holderFirstNames?.trim(),
        parserVersion: 'de_vehicle_registration_front_v1.0.0',
      ),
    );
  }
}

class _LabelledIdentityParser implements IdentityDocumentParser {
  const _LabelledIdentityParser({
    required this.documentType,
    required this.parserVersion,
  });

  final VerificationIdentityDocumentType documentType;
  final String parserVersion;

  @override
  VerificationParseResult<IdentityDocumentData> parse(List<OcrBlock> blocks) {
    final layout = _OcrLayout(blocks);
    final firstNames = layout.valueForLabels(const [
      'Vornamen',
      'Vorname',
      'Vorname(n)',
      'Given names',
      'Given name',
      'Forenames',
      'Forename',
      'Prénoms',
      'Prenoms',
      'Given names/Prénoms',
      'Given names/Prenoms',
      'Vornamen/Given names/Prénoms',
      'Vornamen/Given names/Prenoms',
      'Vornamen/Given name(s)/Prénom(s)',
      'Vornamen/Given name(s)/Prenom(s)',
      'Vorname(n)/Given name(s)/Prénom(s)',
      'Vorname(n)/Given name(s)/Prenom(s)',
    ]);
    final rawLastName = layout.valueForLabels(const [
      'Familienname',
      'Surname',
      'Nom',
      'Name',
      'Surname/Nom',
      'Name/Surname/Nom',
      'Familienname/Surname/Nom',
    ]);
    final lastName = rawLastName == null
        ? null
        : _cleanIdentitySurname(rawLastName);
    final birthValue = layout.valueForLabels(const [
      'Geburtsdatum',
      'Geburtstag',
      'Tag der Geburt',
      'Date of birth',
      'Date de naissance',
      'Date of birth/Date de naissance',
      'Geburtsdatum/Date of birth/Date de naissance',
      'Tag der Geburt/Date of birth/Date de naissance',
    ]);
    final expiryValue = layout.valueForLabels(const [
      'Gültig bis',
      'Gueltig bis',
      'Gultig bis',
      'Date of expiry',
      'Date of expiration',
      "Date d'expiration",
      'Date d expiration',
      "Date of expiry/Date d'expiration",
      'Date of expiry/Date d expiration',
      "Gültig bis/Date of expiry/Date d'expiration",
      'Gültig bis/Date of expiry/Date d expiration',
      "Gueltig bis/Date of expiry/Date d'expiration",
      'Gueltig bis/Date of expiry/Date d expiration',
      "Gultig bis/Date of expiry/Date d'expiration",
      'Gultig bis/Date of expiry/Date d expiration',
      'Expiry',
    ]);
    var dateOfBirth = birthValue == null ? null : parseDocumentDate(birthValue);
    var expiresAt = expiryValue == null ? null : parseDocumentDate(expiryValue);
    final recognizedDates = <DateTime>[];
    for (final block in blocks) {
      final parsed = parseDocumentDate(block.text);
      if (parsed != null &&
          !recognizedDates.any((date) => _sameDay(date, parsed))) {
        recognizedDates.add(parsed);
      }
    }
    final today = DateTime.now();
    if (dateOfBirth == null) {
      final candidates = recognizedDates
          .where((date) {
            final age = ageOn(date, today);
            return age >= 16 && age <= 120;
          })
          .toList(growable: false);
      if (candidates.length == 1) dateOfBirth = candidates.single;
    }
    if (expiresAt == null) {
      final candidates = recognizedDates
          .where((date) {
            if (dateOfBirth case final birthDate?
                when _sameDay(date, birthDate)) {
              return false;
            }
            return date.year >= today.year - 1 && date.year <= today.year + 20;
          })
          .toList(growable: false);
      if (candidates.length == 1) expiresAt = candidates.single;
    }
    if (firstNames == null || firstNames.trim().length < 2) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.missingRequiredField,
        'Vorname konnte nicht eindeutig erkannt werden.',
      );
    }
    if (lastName == null || lastName.trim().length < 2) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.missingRequiredField,
        'Nachname konnte nicht eindeutig erkannt werden.',
      );
    }
    if (dateOfBirth == null && expiresAt == null) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.invalidDate,
        'Geburts- oder Ablaufdatum konnte nicht eindeutig erkannt werden.',
      );
    }
    if (dateOfBirth == null) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.invalidDate,
        'Das Geburtsdatum konnte nicht eindeutig erkannt werden.',
      );
    }
    if (expiresAt == null) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.invalidDate,
        'Das Ablaufdatum konnte nicht eindeutig erkannt werden.',
      );
    }
    return VerificationParseResult.success(
      IdentityDocumentData(
        firstNames: firstNames.trim(),
        lastName: lastName.trim(),
        dateOfBirth: dateOfBirth,
        expiresAt: expiresAt,
        documentType: documentType,
        parserVersion: parserVersion,
      ),
    );
  }
}

class _OcrLayout {
  _OcrLayout(List<OcrBlock> source)
    : blocks = source.where((block) => block.text.trim().isNotEmpty).toList();

  final List<OcrBlock> blocks;

  String? valueForLabels(List<String> labels, {bool exactLabel = false}) {
    final matches = <_LabelMatch>[];
    final inlineValues = <String>[];
    for (final block in blocks) {
      final normalizedBlock = _normalizeLabel(block.text);
      final isExactKnownLabel = labels.any(
        (label) => normalizedBlock == _normalizeLabel(label),
      );
      final blockInlineValues = <({String value, int labelLength})>[];
      for (final label in labels) {
        if (!isExactKnownLabel) {
          final inline = _inlineValue(
            block.text,
            label,
            exactLabel: exactLabel,
          );
          if (inline != null) {
            blockInlineValues.add((
              value: inline,
              labelLength: _normalizeLabel(label).length,
            ));
          }
        }
        if (_isLabel(block.text, label, exactLabel: exactLabel)) {
          if (!matches.any((match) => identical(match.block, block))) {
            matches.add(_LabelMatch(block, label));
          }
        }
      }
      if (blockInlineValues.isNotEmpty) {
        final longestLabel = blockInlineValues
            .map((candidate) => candidate.labelLength)
            .reduce((left, right) => left > right ? left : right);
        inlineValues.addAll(
          blockInlineValues
              .where((candidate) => candidate.labelLength == longestLabel)
              .map((candidate) => candidate.value),
        );
      }
    }
    final distinctInlineValues = _distinctValues(inlineValues);
    if (distinctInlineValues.length == 1) return distinctInlineValues.single;
    if (distinctInlineValues.length > 1 || matches.isEmpty) return null;

    final labelBlocks = matches.map((match) => match.block).toSet();
    final candidates = <({OcrBlock block, double score})>[];
    for (final match in matches) {
      for (final candidate in blocks) {
        if (labelBlocks.contains(candidate)) continue;
        final score = _candidateScore(match.block, candidate);
        if (score < 100000) candidates.add((block: candidate, score: score));
      }
    }
    candidates.sort((left, right) => left.score.compareTo(right.score));
    if (candidates.isEmpty) return null;
    final bestValue = _cleanValue(candidates.first.block.text);
    for (final candidate in candidates.skip(1)) {
      if ((candidate.score - candidates.first.score).abs() >= 2) break;
      if (_normalizeValue(_cleanValue(candidate.block.text)) !=
          _normalizeValue(bestValue)) {
        return null;
      }
    }
    return bestValue;
  }

  static List<String> _distinctValues(Iterable<String> values) {
    final distinct = <String, String>{};
    for (final value in values) {
      distinct.putIfAbsent(_normalizeValue(value), () => value);
    }
    return distinct.values.toList(growable: false);
  }

  static String _normalizeValue(String value) =>
      _cleanValue(value).toLowerCase();

  static double _candidateScore(OcrBlock label, OcrBlock candidate) {
    final verticalDistance = (candidate.bounds.centerY - label.bounds.centerY)
        .abs();
    final sameLine =
        verticalDistance <=
        (label.bounds.height > candidate.bounds.height
            ? label.bounds.height
            : candidate.bounds.height);
    if (sameLine && candidate.bounds.left >= label.bounds.right - 4) {
      return candidate.bounds.left - label.bounds.right + verticalDistance;
    }
    final below = candidate.bounds.top >= label.bounds.bottom - 3;
    final horizontalDistance = (candidate.bounds.left - label.bounds.left)
        .abs();
    if (below && horizontalDistance <= label.bounds.width * 1.8 + 30) {
      return 100 +
          (candidate.bounds.top - label.bounds.bottom) * 2 +
          horizontalDistance;
    }
    return 100000;
  }

  static String? _inlineValue(
    String raw,
    String label, {
    required bool exactLabel,
  }) {
    final text = raw.trim();
    final normalizedText = _normalizeLabel(text);
    final normalizedLabel = _normalizeLabel(label);
    if (exactLabel && normalizedText != normalizedLabel) return null;
    if (!normalizedText.startsWith(normalizedLabel)) return null;
    if (normalizedText == normalizedLabel) return null;
    final labelParts = label
        .trim()
        .split(RegExp(r'[\s/|]+'))
        .where((part) => part.isNotEmpty)
        .map(RegExp.escape)
        .toList(growable: false);
    if (labelParts.isEmpty) return null;
    final prefix = RegExp(
      '^\\s*${labelParts.join(r'[\s/|:;,.()\-]*')}',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    if (prefix == null) return null;
    final valueStart = prefix.end;
    if (valueStart < text.length &&
        RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text[valueStart])) {
      return null;
    }
    final remainder = text.substring(valueStart);
    if (RegExp(r'^\s*[/|]').hasMatch(remainder)) return null;
    final value = remainder.replaceFirst(RegExp(r'^\s*[:\-]?\s*'), '');
    return value.trim().isEmpty ? null : _cleanValue(value);
  }

  static bool _isLabel(String raw, String label, {required bool exactLabel}) {
    final text = _normalizeLabel(raw);
    final expected = _normalizeLabel(label);
    if (text == expected) return true;
    if (exactLabel) return false;
    final textWords = text
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    final expectedWords = expected
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (expectedWords.isEmpty || textWords.length < expectedWords.length) {
      return false;
    }
    for (
      var start = 0;
      start <= textWords.length - expectedWords.length;
      start += 1
    ) {
      var matches = true;
      for (var offset = 0; offset < expectedWords.length; offset += 1) {
        if (textWords[start + offset] != expectedWords[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }

  static String _normalizeLabel(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(':', '')
      .replaceAll(RegExp(r'\s*[/|]\s*'), ' ')
      .replaceAll(RegExp(r'[().,;]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  static String _cleanValue(String value) => value
      .replaceAll(RegExp(r'^[\s:;\-]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _LabelMatch {
  const _LabelMatch(this.block, this.label);

  final OcrBlock block;
  final String label;
}

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _cleanIdentitySurname(String value) {
  var cleaned = value.trim();

  // German ID cards prefix the family name with a printed field marker such
  // as "[a]". ML Kit can occasionally read that small marker as "tal".
  cleaned = cleaned.replaceFirst(RegExp(r'^\s*[\[({]\s*[aA]\s*[\])}]\s*'), '');
  cleaned = cleaned.replaceFirst(
    RegExp(r'^tal\s+(?=[A-ZÄÖÜŞÇĞİ]{2})', unicode: true),
    '',
  );

  return cleaned.trim();
}
