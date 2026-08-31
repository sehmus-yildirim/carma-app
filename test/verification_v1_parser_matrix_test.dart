import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/verification_v1/domain/document_profiles.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_models.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_parsers.dart';

void main() {
  final dataset = _loadDataset();
  final conditions = (dataset['conditions']! as List).cast<String>();

  test('synthetic parser matrix is permanently marked non-valid', () {
    expect(dataset['notice'], contains('TEST DOCUMENT'));
    expect(dataset['notice'], contains('NOT VALID'));
    expect(conditions, hasLength(10));
  });

  test('runs 240 deterministic profile and capture-condition cases', () {
    var executed = 0;
    final passport = dataset['passport']! as Map<String, dynamic>;
    for (final countryCode in (passport['countries']! as List).cast<String>()) {
      final country = DocumentProfileRegistry.country(countryCode)!;
      for (var condition = 0; condition < conditions.length; condition += 1) {
        final result = PassportDataPageParser(
          countryCode: countryCode,
          now: DateTime(2026, 1),
        ).parse(_passportBlocks(country.icaoCode, condition));
        expect(
          result.isSuccess,
          isTrue,
          reason: '$countryCode/${conditions[condition]}: ${result.message}',
        );
        expect(result.data!.firstNames, passport['expectedFirstNames']);
        expect(result.data!.lastName, passport['expectedLastName']);
        expect(result.data!.issuingCountryCode, countryCode);
        executed += 1;
      }
    }

    for (final documentType in const [
      VerificationIdentityDocumentType.idCard,
      VerificationIdentityDocumentType.residencePermit,
    ]) {
      final profile = DocumentProfileRegistry.identityProfile(
        countryCode: 'DE',
        documentType: documentType,
      )!;
      for (var condition = 0; condition < conditions.length; condition += 1) {
        final result = ProfileDrivenIdentityDocumentParser(
          profile: profile,
          now: DateTime(2026, 1),
        ).parse(_identityBlocks(condition));
        expect(
          result.isSuccess,
          isTrue,
          reason:
              '${documentType.value}/${conditions[condition]}: ${result.message}',
        );
        expect(result.data!.firstNames, 'ERIKA MARIA');
        expect(result.data!.lastName, 'MUSTERMANN');
        executed += 1;
      }
    }

    final vehicleProfile = DocumentProfileRegistry.vehicleRegistrationProfile(
      'DE',
    )!;
    for (var condition = 0; condition < conditions.length; condition += 1) {
      final result = ProfileDrivenVehicleRegistrationParser(
        profile: vehicleProfile,
      ).parse(_vehicleBlocks(condition));
      expect(
        result.isSuccess,
        isTrue,
        reason: 'vehicle/${conditions[condition]}: ${result.message}',
      );
      expect(result.data!.plate, 'HH AB 123');
      expect(result.data!.holderNameOrCompany, 'MUSTERMANN');
      executed += 1;
    }

    expect(executed, 240);
  });

  test('ambiguous or incomplete synthetic fields are never accepted', () {
    final profile = DocumentProfileRegistry.identityProfile(
      countryCode: 'DE',
      documentType: VerificationIdentityDocumentType.idCard,
    )!;
    final ambiguous = ProfileDrivenIdentityDocumentParser(
      profile: profile,
    ).parse([..._identityBlocks(0), _block('ANDEREPERSON', 158, 22, 274, 42)]);
    final missing =
        ProfileDrivenVehicleRegistrationParser(
          profile: DocumentProfileRegistry.vehicleRegistrationProfile('DE')!,
        ).parse([
          _block('A', 12, 14, 24, 34),
          _block('HH AB 123', 90, 14, 190, 34),
        ]);
    expect(ambiguous.isSuccess, isFalse);
    expect(missing.isSuccess, isFalse);
  });
}

Map<String, dynamic> _loadDataset() =>
    jsonDecode(
          File(
            'test/fixtures/verification/golden_dataset.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

List<OcrBlock> _identityBlocks(int condition) => _transform([
  _block('Familienname', 12, 22, 138, 42),
  _block('MUSTERMANN', 158, 22, 274, 42),
  _block('Vornamen', 12, 66, 138, 86),
  _block('ERIKA MARIA', 158, 66, 282, 86),
  _block('Geburtsdatum', 12, 110, 138, 130),
  _block('01.01.1990', 158, 110, 254, 130),
  _block('Gultig bis', 12, 154, 138, 174),
  _block('31.12.2030', 158, 154, 254, 174),
], condition);

List<OcrBlock> _vehicleBlocks(int condition) => _transform([
  _block('A', 12, 14, 24, 34),
  _block('HH AB 123', 90, 14, 190, 34),
  _block('C.1.1', 12, 58, 66, 78),
  _block('MUSTERMANN', 90, 58, 210, 78),
  _block('C.1.2', 12, 102, 66, 122),
  _block('ERIKA MARIA', 90, 102, 218, 122),
], condition);

List<OcrBlock> _passportBlocks(String issuer, int condition) {
  const birth = '900101';
  const expiry = '301231';
  final first =
      ('P<$issuer'
              'MUSTERMANN<<ERIKA<MARIA')
          .padRight(44, '<');
  final second =
      'C01X00T470$issuer$birth${_mrzDigit(birth)}F$expiry${_mrzDigit(expiry)}'
          .padRight(44, '<');
  return _transform([
    _block(first, 8, 180, 448, 202),
    _block(second, 8, 206, 448, 228),
  ], condition);
}

List<OcrBlock> _transform(List<OcrBlock> blocks, int condition) {
  final dx = switch (condition) {
    1 => -6.0,
    2 => 6.0,
    3 => 9.0,
    7 => 28.0,
    _ => 0.0,
  };
  final dy = switch (condition) {
    1 => 4.0,
    2 => -4.0,
    3 => 8.0,
    8 => 12.0,
    _ => 0.0,
  };
  final scale = condition == 7 ? 0.72 : 1.0;
  return [
    for (final block in blocks)
      OcrBlock(
        text: block.text,
        bounds: OcrRect(
          left: block.bounds.left * scale + dx,
          top: block.bounds.top * scale + dy,
          right: block.bounds.right * scale + dx,
          bottom: block.bounds.bottom * scale + dy,
        ),
      ),
  ];
}

OcrBlock _block(
  String text,
  double left,
  double top,
  double right,
  double bottom,
) => OcrBlock(
  text: text,
  bounds: OcrRect(left: left, top: top, right: right, bottom: bottom),
);

String _mrzDigit(String value) {
  const weights = [7, 3, 1];
  var total = 0;
  for (var index = 0; index < value.length; index += 1) {
    final code = value.codeUnitAt(index);
    final characterValue = code >= 48 && code <= 57
        ? code - 48
        : code >= 65 && code <= 90
        ? code - 55
        : 0;
    total += characterValue * weights[index % weights.length];
  }
  return '${total % 10}';
}
