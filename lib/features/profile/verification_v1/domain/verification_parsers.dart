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
      'Given names',
      'Given name',
    ]);
    final lastName = layout.valueForLabels(const [
      'Familienname',
      'Surname',
      'Name',
    ]);
    final birthValue = layout.valueForLabels(const [
      'Geburtsdatum',
      'Geburtstag',
      'Date of birth',
    ]);
    final expiryValue = layout.valueForLabels(const [
      'Gültig bis',
      'Date of expiry',
      'Date of expiration',
      'Expiry',
    ]);
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
    if (dateOfBirth == null || expiresAt == null) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.invalidDate,
        'Geburts- oder Ablaufdatum konnte nicht eindeutig erkannt werden.',
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
    for (final block in blocks) {
      for (final label in labels) {
        final inline = _inlineValue(block.text, label, exactLabel: exactLabel);
        if (inline != null) return inline;
        if (_isLabel(block.text, label, exactLabel: exactLabel)) {
          matches.add(_LabelMatch(block, label));
        }
      }
    }
    if (matches.length != 1) return null;
    final label = matches.single.block;
    final candidates =
        blocks
            .where((candidate) => candidate != label)
            .map(
              (candidate) =>
                  (block: candidate, score: _candidateScore(label, candidate)),
            )
            .where((candidate) => candidate.score < 100000)
            .toList()
          ..sort((left, right) => left.score.compareTo(right.score));
    if (candidates.isEmpty) return null;
    if (candidates.length > 1 &&
        (candidates[1].score - candidates.first.score).abs() < 2) {
      return null;
    }
    return _cleanValue(candidates.first.block.text);
  }

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
    final index = text.toLowerCase().indexOf(label.toLowerCase());
    if (index < 0) return null;
    final value = text
        .substring(index + label.length)
        .replaceFirst(RegExp(r'^\s*[:\-]?\s*'), '');
    return value.trim().isEmpty ? null : _cleanValue(value);
  }

  static bool _isLabel(String raw, String label, {required bool exactLabel}) {
    final text = _normalizeLabel(raw);
    final expected = _normalizeLabel(label);
    return exactLabel ? text == expected : text == expected;
  }

  static String _normalizeLabel(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(':', '')
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
