import 'document_profiles.dart';
import 'mrz_parser.dart';
import 'verification_confidence.dart';
import 'verification_models.dart';
import 'verification_normalization.dart';

abstract interface class IdentityDocumentParser {
  VerificationParseResult<IdentityDocumentData> parse(List<OcrBlock> blocks);
}

abstract interface class VehicleRegistrationParser {
  VerificationParseResult<VehicleRegistrationData> parse(List<OcrBlock> blocks);
}

class GermanIdCardFrontParser implements IdentityDocumentParser {
  const GermanIdCardFrontParser();

  @override
  VerificationParseResult<IdentityDocumentData> parse(List<OcrBlock> blocks) {
    final profile = DocumentProfileRegistry.identityProfile(
      countryCode: 'DE',
      documentType: VerificationIdentityDocumentType.idCard,
    )!;
    return ProfileDrivenIdentityDocumentParser(profile: profile).parse(blocks);
  }
}

class GermanResidencePermitFrontParser implements IdentityDocumentParser {
  const GermanResidencePermitFrontParser();

  @override
  VerificationParseResult<IdentityDocumentData> parse(List<OcrBlock> blocks) {
    final profile = DocumentProfileRegistry.identityProfile(
      countryCode: 'DE',
      documentType: VerificationIdentityDocumentType.residencePermit,
    )!;
    return ProfileDrivenIdentityDocumentParser(profile: profile).parse(blocks);
  }
}

class PassportDataPageParser implements IdentityDocumentParser {
  const PassportDataPageParser({this.now, this.countryCode = 'DE'});

  final DateTime? now;
  final String countryCode;

  @override
  VerificationParseResult<IdentityDocumentData> parse(List<OcrBlock> blocks) {
    final profile = DocumentProfileRegistry.identityProfile(
      countryCode: countryCode,
      documentType: VerificationIdentityDocumentType.passport,
    );
    if (profile == null) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.unsupportedDocument,
        'Dieser Reisepass ist für die automatische Prüfung noch nicht freigegeben.',
      );
    }
    return ProfileDrivenIdentityDocumentParser(
      profile: profile,
      now: now,
    ).parse(blocks);
  }
}

class GermanVehicleRegistrationFrontParser
    implements VehicleRegistrationParser {
  const GermanVehicleRegistrationFrontParser();

  @override
  VerificationParseResult<VehicleRegistrationData> parse(
    List<OcrBlock> blocks,
  ) {
    final profile = DocumentProfileRegistry.vehicleRegistrationProfile('DE')!;
    return ProfileDrivenVehicleRegistrationParser(
      profile: profile,
    ).parse(blocks);
  }
}

class ProfileDrivenIdentityDocumentParser implements IdentityDocumentParser {
  const ProfileDrivenIdentityDocumentParser({required this.profile, this.now});

  final DocumentProfile profile;
  final DateTime? now;

  @override
  VerificationParseResult<IdentityDocumentData> parse(List<OcrBlock> blocks) {
    if (!profile.parserAvailable || profile.identityDocumentType == null) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.unsupportedDocument,
        'Dieser Dokumenttyp ist noch nicht zuverlässig unterstützt.',
      );
    }
    final mrzConfiguration = profile.mrzConfiguration;
    final hasMrz = blocks.any(
      (block) => block.text
          .split(RegExp(r'[\r\n]+'))
          .any(
            (line) =>
                line.contains('<') &&
                RegExp(
                  r'^[IACP][A-Z<][A-Z<]{3}[A-Z0-9<]{20}',
                ).hasMatch(line.replaceAll(' ', '').toUpperCase()),
          ),
    );
    if (mrzConfiguration?.required == true ||
        (mrzConfiguration != null && hasMrz)) {
      final mrz = MrzParser(
        now: now,
      ).parse(blocks, allowedFormats: mrzConfiguration!.formats);
      if (!mrz.isSuccess) {
        return VerificationParseResult.failure(mrz.failure, mrz.message);
      }
      final data = mrz.data!;
      final country = DocumentProfileRegistry.country(profile.countryCode)!;
      final issuingCode = data.issuingCountryCode.replaceAll('<', '');
      if (issuingCode != country.icaoCode &&
          !(profile.countryCode == 'DE' && issuingCode == 'D')) {
        return const VerificationParseResult.failure(
          VerificationParseFailure.ambiguousField,
          'Das Ausstellungsland im Dokument stimmt nicht mit der Auswahl überein.',
        );
      }
      return VerificationParseResult.success(
        IdentityDocumentData(
          firstNames: data.firstNames,
          lastName: data.lastName,
          dateOfBirth: data.dateOfBirth,
          expiresAt: data.documentExpiryDate,
          documentType: profile.identityDocumentType!,
          issuingCountryCode: profile.countryCode,
          documentProfileVersion: profile.documentVersion,
          parserVersion: '${profile.parserVersion}_mrz',
        ),
        fieldConfidence: mrz.fieldConfidence,
      );
    }
    return _LabelledIdentityParser(profile: profile, now: now).parse(blocks);
  }
}

class ProfileDrivenVehicleRegistrationParser
    implements VehicleRegistrationParser {
  const ProfileDrivenVehicleRegistrationParser({required this.profile});

  final DocumentProfile profile;

  @override
  VerificationParseResult<VehicleRegistrationData> parse(
    List<OcrBlock> blocks,
  ) {
    if (!profile.parserAvailable ||
        profile.documentKind != VerificationDocumentKind.vehicleRegistration) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.unsupportedDocument,
        'Dieses Fahrzeugdokument ist noch nicht zuverlässig unterstützt.',
      );
    }
    final layout = _OcrLayout(blocks, profile);
    final plate = layout.valueForLabels(
      profile.aliasesFor(VerificationField.plateNumber),
      exactLabel: true,
      accepts: _isGermanPlate,
    );
    final holderName = layout.valueForLabels(
      profile.aliasesFor(VerificationField.holderLastNameOrCompany),
      accepts: _isHolderName,
    );
    final holderFirstNames = layout.valueForLabels(
      profile.aliasesFor(VerificationField.holderFirstNames),
      accepts: _isPersonName,
    );
    final normalizedPlate = plate
        ?.toUpperCase()
        .replaceAll(RegExp(r'[^A-ZÄÖÜ0-9\- ]'), '')
        .trim();
    if (normalizedPlate == null || normalizedPlate.length < 3) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.missingRequiredField,
        'Das Kennzeichen wurde nicht sicher erkannt. Bitte fotografiere das Fahrzeugdokument erneut.',
      );
    }
    if (holderName == null || holderName.trim().length < 2) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.missingRequiredField,
        'Der Haltername wurde nicht sicher erkannt. Bitte fotografiere das Fahrzeugdokument erneut.',
      );
    }
    return VerificationParseResult.success(
      VehicleRegistrationData(
        plate: normalizedPlate,
        holderNameOrCompany: holderName.trim(),
        holderFirstNames: holderFirstNames?.trim().isEmpty == true
            ? null
            : holderFirstNames?.trim(),
        registrationCountryCode: profile.countryCode,
        documentProfileVersion: profile.documentVersion,
        parserVersion: profile.parserVersion,
      ),
      fieldConfidence: {
        VerificationField.plateNumber: FieldConfidence.high,
        VerificationField.holderLastNameOrCompany: FieldConfidence.high,
        if (holderFirstNames?.trim().isNotEmpty == true)
          VerificationField.holderFirstNames: FieldConfidence.high,
      },
    );
  }
}

class _LabelledIdentityParser implements IdentityDocumentParser {
  const _LabelledIdentityParser({required this.profile, this.now});

  final DocumentProfile profile;
  final DateTime? now;

  @override
  VerificationParseResult<IdentityDocumentData> parse(List<OcrBlock> blocks) {
    final layout = _OcrLayout(blocks, profile);
    final residenceNames =
        profile.identityDocumentType ==
            VerificationIdentityDocumentType.residencePermit
        ? _residenceNames(blocks)
        : null;
    if (residenceNames?.ambiguous == true) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.ambiguousField,
        'Vor- und Nachname im gemeinsamen Namensfeld sind nicht eindeutig getrennt. Bitte wähle die Rückseite des Aufenthaltstitels mit den drei Codezeilen.',
      );
    }
    final firstNames =
        residenceNames?.firstNames ??
        layout.valueForLabels(
          profile.aliasesFor(VerificationField.firstNames),
          accepts: _isPersonName,
        );
    final rawLastName =
        residenceNames?.lastName ??
        layout.valueForLabels(
          profile.aliasesFor(VerificationField.lastName),
          accepts: (value) => _isPersonName(_cleanIdentitySurname(value)),
        );
    final lastName = rawLastName == null
        ? null
        : _cleanIdentitySurname(rawLastName);
    final birthValue = layout.valueForLabels(
      profile.aliasesFor(VerificationField.dateOfBirth),
      accepts: (value) => parseDocumentDate(value) != null,
    );
    final expiryValue = layout.valueForLabels(
      profile.aliasesFor(VerificationField.documentExpiryDate),
      accepts: (value) => parseDocumentDate(value) != null,
    );
    final dateOfBirth = birthValue == null
        ? null
        : parseDocumentDate(birthValue);
    final expiresAt = expiryValue == null
        ? null
        : parseDocumentDate(expiryValue);
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
    final today = now ?? DateTime.now();
    if (!dateOfBirth.isBefore(today) || ageOn(dateOfBirth, today) > 120) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.invalidDate,
        'Das Geburtsdatum ist nicht plausibel.',
      );
    }
    final confidenceEngine = VerificationConfidenceEngine();
    final confidence = <VerificationField, FieldConfidence>{};
    for (final field in const {
      VerificationField.firstNames,
      VerificationField.lastName,
      VerificationField.dateOfBirth,
      VerificationField.documentExpiryDate,
    }) {
      confidence[field] = confidenceEngine
          .assess(
            field: field,
            signals: const {
              ConfidenceSignal.anchorFound,
              ConfidenceSignal.formatValid,
              ConfidenceSignal.uniqueCandidate,
            },
            thresholds: profile.confidenceThresholds,
          )
          .level;
    }
    if (!confidenceEngine.permitsAutomaticAcceptance(
      confidence,
      requiredFields: const {
        VerificationField.firstNames,
        VerificationField.lastName,
        VerificationField.dateOfBirth,
        VerificationField.documentExpiryDate,
      },
    )) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.ambiguousField,
        'Wir konnten die Angaben nicht eindeutig erkennen. Bitte fotografiere das Dokument erneut.',
      );
    }
    return VerificationParseResult.success(
      IdentityDocumentData(
        firstNames: firstNames.trim(),
        lastName: lastName.trim(),
        dateOfBirth: dateOfBirth,
        expiresAt: expiresAt,
        documentType: profile.identityDocumentType!,
        issuingCountryCode: profile.countryCode,
        documentProfileVersion: profile.documentVersion,
        parserVersion: profile.parserVersion,
      ),
      fieldConfidence: confidence,
    );
  }
}

({String? firstNames, String? lastName, bool ambiguous})? _residenceNames(
  List<OcrBlock> blocks,
) {
  final anchors = blocks.where((block) {
    final text = block.text.toUpperCase();
    return RegExp(r'(^|[^A-Z])(NAMEN?|SURNAMES)($|[^A-Z])').hasMatch(text) &&
        (text.contains('VORNAME') || text.contains('FORENAMES'));
  }).toList();
  if (anchors.isEmpty) return null;
  const rejected = (firstNames: null, lastName: null, ambiguous: true);
  if (anchors.length != 1) return rejected;
  final anchor = anchors.single;
  final candidates =
      blocks
          .where(
            (block) =>
                block.bounds.top >= anchor.bounds.bottom &&
                block.bounds.top - anchor.bounds.bottom <=
                    anchor.bounds.height * 4 &&
                (block.bounds.left - anchor.bounds.left).abs() <=
                    anchor.bounds.width &&
                RegExp(
                  r"^[\p{L}\p{M}\s,.'’\-]+$",
                  unicode: true,
                ).hasMatch(block.text) &&
                !RegExp(
                  r'GEBURT|STAATS|GESCHLECHT|NATIONALITY|SEX|BIRTH',
                  caseSensitive: false,
                ).hasMatch(block.text),
          )
          .toList()
        ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
  String? surname;
  String? given;
  if (candidates.length == 2 &&
      candidates[1].bounds.top >= candidates[0].bounds.bottom) {
    surname = candidates[0].text.trim();
    given = candidates[1].text.trim();
  } else if (candidates.length == 1) {
    final value = candidates.single.text.trim();
    final parts = value.split(',');
    if (parts.length == 2) {
      surname = parts[0].trim();
      given = parts[1].trim();
    } else {
      // The eAT specimen prints the surname in capitals and given names in
      // mixed case. An all-capitals OCR line cannot be split unambiguously.
      final match = RegExp(
        r'^([\p{Lu}\p{M}\s\-]+)\s+([\p{Lu}][\p{Ll}\p{M}].*)$',
        unicode: true,
      ).firstMatch(value);
      surname = match?.group(1)?.trim();
      given = match?.group(2)?.trim();
    }
  }
  if (surname == null ||
      given == null ||
      !_isPersonName(surname) ||
      !_isPersonName(given)) {
    return rejected;
  }
  return (firstNames: given, lastName: surname, ambiguous: false);
}

class _OcrLayout {
  _OcrLayout(List<OcrBlock> source, DocumentProfile profile)
    : blocks = source.where((block) => block.text.trim().isNotEmpty).toList(),
      knownLabels = profile.anchors.expand((anchor) => anchor.aliases).toList();

  final List<OcrBlock> blocks;
  final List<String> knownLabels;

  String? valueForLabels(
    List<String> labels, {
    bool exactLabel = false,
    required bool Function(String) accepts,
  }) {
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
          if (inline != null && accepts(inline) && !_isKnownLabel(inline)) {
            blockInlineValues.add((
              value: inline,
              labelLength: _normalizeLabel(label).length,
            ));
          }
        }
        if (_isLabel(block.text, label, exactLabel: exactLabel)) {
          if (!matches.any((match) => identical(match.block, block))) {
            matches.add(_LabelMatch(block));
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
        if (labelBlocks.contains(candidate) ||
            _isKnownLabel(candidate.text) ||
            !accepts(_cleanValue(candidate.text))) {
          continue;
        }
        // Never borrow the next field's value when this field is unreadable.
        final crossesField = blocks.any(
          (other) =>
              !labelBlocks.contains(other) &&
              _isKnownLabel(other.text) &&
              other.bounds.top > match.block.bounds.bottom &&
              other.bounds.top <= candidate.bounds.top &&
              (other.bounds.left - match.block.bounds.left).abs() <
                  match.block.bounds.width,
        );
        if (crossesField) continue;
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

  bool _isKnownLabel(String value) => knownLabels.any(
    (label) =>
        _isLabel(value, label, exactLabel: true) ||
        _inlineValue(value, label, exactLabel: false) != null,
  );

  static double _candidateScore(OcrBlock label, OcrBlock candidate) {
    final verticalDistance = (candidate.bounds.centerY - label.bounds.centerY)
        .abs();
    final sameLine =
        verticalDistance <=
        0.5 *
            (label.bounds.height > candidate.bounds.height
                ? label.bounds.height
                : candidate.bounds.height);
    if (sameLine && candidate.bounds.left >= label.bounds.right - 4) {
      return candidate.bounds.left - label.bounds.right + verticalDistance;
    }
    final below = candidate.bounds.top >= label.bounds.bottom - 3;
    final horizontalDistance = (candidate.bounds.left - label.bounds.left)
        .abs();
    if (below &&
        candidate.bounds.top - label.bounds.bottom <= label.bounds.height * 6 &&
        horizontalDistance <= label.bounds.width * 1.8 + 30) {
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
    // EU registration codes can be joined to their value by ML Kit. Match
    // the complete code token, never a word merely beginning with "A".
    final code = label.replaceAll(RegExp(r'[\s.]'), '').toUpperCase();
    if (code == 'A' || RegExp(r'^C1[12]$').hasMatch(code)) {
      final pattern = code == 'A'
          ? r'^\s*\(?A\)?(?=\s|:|$)\s*:?\s*'
          : '^\\s*\\(?C\\s*\\.?\\s*1\\s*\\.?\\s*${code[2]}\\)?(?=\\s|:|\$)\\s*:?\\s*';
      final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
      if (match == null) return null;
      final value = _cleanValue(text.substring(match.end));
      return value.isEmpty ? null : value;
    }
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
    final code = expected.replaceAll(' ', '');
    if (code == 'a' || RegExp(r'^c1[12]$').hasMatch(code)) {
      return text.replaceAll(' ', '') == code;
    }
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

bool _isPersonName(String value) =>
    value.trim().length >= 2 &&
    RegExp(
      r"^[\p{L}\p{M}][\p{L}\p{M}\s.'’\-]*$",
      unicode: true,
    ).hasMatch(value.trim());

bool _isHolderName(String value) =>
    value.trim().length >= 2 &&
    RegExp(r'\p{L}', unicode: true).hasMatch(value) &&
    !RegExp(r'^C\s*\.?\s*\d', caseSensitive: false).hasMatch(value);

bool _isGermanPlate(String value) => RegExp(
  r'^[A-ZÄÖÜ]{1,3}[\s\-]+[A-Z]{1,2}\s*\d{1,4}[EH]?$',
  caseSensitive: false,
).hasMatch(value.trim());

class _LabelMatch {
  const _LabelMatch(this.block);

  final OcrBlock block;
}

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
