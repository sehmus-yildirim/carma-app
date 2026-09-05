import 'document_profiles.dart';
import 'verification_models.dart';
import 'verification_normalization.dart';

class MrzData {
  const MrzData({
    required this.format,
    required this.issuingCountryCode,
    required this.firstNames,
    required this.lastName,
    required this.dateOfBirth,
    required this.documentExpiryDate,
  });

  final MrzFormat format;
  final String issuingCountryCode;
  final String firstNames;
  final String lastName;
  final DateTime dateOfBirth;
  final DateTime documentExpiryDate;
}

class MrzParser {
  const MrzParser({this.now});

  final DateTime? now;

  VerificationParseResult<MrzData> parse(
    List<OcrBlock> blocks, {
    required List<MrzFormat> allowedFormats,
  }) {
    final ordered = blocks.indexed.toList()
      ..sort((a, b) {
        final byTop = a.$2.bounds.top.compareTo(b.$2.bounds.top);
        return byTop == 0 ? a.$1.compareTo(b.$1) : byTop;
      });
    final lines = _normalizedLines(ordered.map((entry) => entry.$2).toList());
    VerificationParseResult<MrzData>? rejectedCandidate;
    for (final format in allowedFormats) {
      final candidate = switch (format) {
        MrzFormat.td1 => _findConsecutive(lines, count: 3, length: 30),
        MrzFormat.td2 => _findConsecutive(lines, count: 2, length: 36),
        MrzFormat.td3 => _findConsecutive(lines, count: 2, length: 44),
      };
      if (candidate == null) continue;
      final parsed = switch (format) {
        MrzFormat.td1 => _parseTd1(candidate),
        MrzFormat.td2 => _parseTd2(candidate),
        MrzFormat.td3 => _parseTd3(candidate),
      };
      if (parsed.isSuccess) return parsed;
      rejectedCandidate = parsed;
    }
    if (rejectedCandidate != null) return rejectedCandidate;
    return const VerificationParseResult.failure(
      VerificationParseFailure.missingRequiredField,
      'Die maschinenlesbare Zone wurde nicht vollständig erkannt. Bitte fotografiere die Datenseite erneut.',
    );
  }

  VerificationParseResult<MrzData> _parseTd1(List<String> lines) {
    final first = lines[0];
    final second = lines[1];
    final third = lines[2];
    return _buildResult(
      format: MrzFormat.td1,
      issuingCountry: first.substring(2, 5),
      names: third,
      birthRaw: second.substring(0, 6),
      birthCheck: second.substring(6, 7),
      expiryRaw: second.substring(8, 14),
      expiryCheck: second.substring(14, 15),
    );
  }

  VerificationParseResult<MrzData> _parseTd2(List<String> lines) {
    final first = lines[0];
    final second = lines[1];
    return _buildResult(
      format: MrzFormat.td2,
      issuingCountry: first.substring(2, 5),
      names: first.substring(5),
      birthRaw: second.substring(13, 19),
      birthCheck: second.substring(19, 20),
      expiryRaw: second.substring(21, 27),
      expiryCheck: second.substring(27, 28),
    );
  }

  VerificationParseResult<MrzData> _parseTd3(List<String> lines) {
    final first = lines[0];
    final second = lines[1];
    return _buildResult(
      format: MrzFormat.td3,
      issuingCountry: first.substring(2, 5),
      names: first.substring(5),
      birthRaw: second.substring(13, 19),
      birthCheck: second.substring(19, 20),
      expiryRaw: second.substring(21, 27),
      expiryCheck: second.substring(27, 28),
    );
  }

  VerificationParseResult<MrzData> _buildResult({
    required MrzFormat format,
    required String issuingCountry,
    required String names,
    required String birthRaw,
    required String birthCheck,
    required String expiryRaw,
    required String expiryCheck,
  }) {
    if (!mrzCheckDigitIsValid(birthRaw, birthCheck) ||
        !mrzCheckDigitIsValid(expiryRaw, expiryCheck)) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.ambiguousField,
        'Die Prüfziffern der maschinenlesbaren Zone stimmen nicht. Bitte fotografiere das Dokument erneut.',
      );
    }
    final parsedNames = _parseNames(names);
    final dateOfBirth = parseMrzDateOfBirth(birthRaw, now: now);
    final expiry = parseMrzExpiryDate(expiryRaw);
    if (parsedNames == null || dateOfBirth == null || expiry == null) {
      return const VerificationParseResult.failure(
        VerificationParseFailure.invalidDate,
        'Name, Geburts- oder Ablaufdatum konnte aus der maschinenlesbaren Zone nicht sicher gelesen werden.',
      );
    }
    return VerificationParseResult.success(
      MrzData(
        format: format,
        issuingCountryCode: issuingCountry,
        firstNames: parsedNames.firstNames,
        lastName: parsedNames.lastName,
        dateOfBirth: dateOfBirth,
        documentExpiryDate: expiry,
      ),
      fieldConfidence: const {
        VerificationField.firstNames: FieldConfidence.high,
        VerificationField.lastName: FieldConfidence.high,
        VerificationField.dateOfBirth: FieldConfidence.high,
        VerificationField.documentExpiryDate: FieldConfidence.high,
      },
    );
  }

  static ({String firstNames, String lastName})? _parseNames(String raw) {
    if (!RegExp(r'^[A-Z<]+$').hasMatch(raw)) return null;
    final parts = raw.split('<<');
    if (parts.length < 2) return null;
    final lastName = _readableMrzName(parts.first);
    final firstNames = _readableMrzName(parts.sublist(1).join('<'));
    if (lastName.length < 2 || firstNames.length < 2) return null;
    return (firstNames: firstNames, lastName: lastName);
  }

  static String _readableMrzName(String value) =>
      value.replaceAll('<', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static List<String> _normalizedLines(List<OcrBlock> blocks) {
    return blocks
        .expand((block) => block.text.split(RegExp(r'[\r\n]+')))
        .map(
          (line) => line
              .toUpperCase()
              .replaceAll('«', '<')
              .replaceAll(RegExp(r'[^A-Z0-9<]'), ''),
        )
        .where((line) => line.length >= 15)
        .toList(growable: false);
  }

  static List<String>? _findConsecutive(
    List<String> lines, {
    required int count,
    required int length,
  }) {
    for (var index = 0; index <= lines.length - count; index += 1) {
      final candidate = lines
          .skip(index)
          .take(count)
          .indexed
          .map((entry) {
            final row = entry.$1;
            final line = entry.$2;
            if (line.length == length) return line;
            if (line.length > length) return '';
            final namesRow = count == 3 ? row == 2 : row == 0;
            // ML Kit often omits repeated terminal fillers. Never reconstruct
            // name characters: a visible double filler must already end the name.
            if (namesRow) {
              final names = count == 3 ? line : line.substring(5);
              if (!line.endsWith('<<') || _parseNames(names) == null) return '';
            } else {
              // Only the four permitted fields are extracted, not optional MRZ
              // data. DOB, expiry and their check digits must be fully present.
              final requiredLength = count == 3 ? 15 : 28;
              if (line.length < requiredLength) return '';
            }
            return line.padRight(length, '<');
          })
          .toList(growable: false);
      final prefix = length == 44
          ? RegExp(r'^P[A-Z<]')
          : RegExp(r'^[IAC][A-Z<]');
      if (candidate.every((line) => line.length == length) &&
          prefix.hasMatch(candidate.first)) {
        return candidate;
      }
    }
    return null;
  }
}
