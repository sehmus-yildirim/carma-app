import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:plaqa/features/profile/verification_v1/data/document_services.dart';
import 'package:plaqa/features/profile/verification_v1/data/local_image_quality_service.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_models.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_normalization.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_parsers.dart';

void main() {
  group('verification models and normalization', () {
    test(
      'serializes only the permitted identity fields as date-only values',
      () {
        final data = IdentityDocumentData(
          firstNames: '  Aylin  ',
          lastName: ' Yilmaz ',
          dateOfBirth: DateTime(1995, 2, 3, 18),
          expiresAt: DateTime(2031, 9, 7, 8),
          documentType: VerificationIdentityDocumentType.idCard,
          parserVersion: 'test-v1',
        );

        expect(data.toSubmissionJson(), {
          'firstNames': 'Aylin',
          'lastName': 'Yilmaz',
          'dateOfBirth': '1995-02-03',
          'expiresAt': '2031-09-07',
          'documentType': 'id_card',
          'parserVersion': 'test-v1',
        });
      },
    );

    test('serializes only the permitted vehicle-registration fields', () {
      const data = VehicleRegistrationData(
        plate: ' HH AB 123 ',
        holderNameOrCompany: ' Beispiel GmbH ',
        holderFirstNames: null,
        parserVersion: 'vehicle-test-v1',
      );

      expect(data.toSubmissionJson(), {
        'plate': 'HH AB 123',
        'holderNameOrCompany': 'Beispiel GmbH',
        'holderFirstNames': null,
        'parserVersion': 'vehicle-test-v1',
      });
    });

    test('normalizes German and Turkish OCR variants conservatively', () {
      expect(normalizePersonName('  Müller - Öztürk  '), 'mueller-oeztuerk');
      expect(conservativeLastNameMatch('Groß', 'GROSS'), isTrue);
      expect(conservativeLastNameMatch('Yılmaz', 'YILMAZ'), isTrue);
      expect(conservativeLastNameMatch("O'Connor", "O’Connor"), isTrue);
      expect(
        conservativeLastNameMatch('Meyer-Schulz', 'Meyer Schulz'),
        isFalse,
      );
      expect(conservativeFirstNamesMatch('Ali Can', 'Ali'), isTrue);
      expect(conservativeFirstNamesMatch('Ali Can', 'Ali Mehmet'), isFalse);
      expect(conservativeFirstNamesMatch('Ali', 'Mehmet Ali'), isFalse);
    });

    test('normalizes plates without guessing lookalike characters', () {
      expect(normalizePlate(' hh - ab 123 '), 'DE_HHAB123');
      expect(normalizePlate('HH-OI 10'), isNot(normalizePlate('HH-01 10')));
    });

    test('parses common dates and handles leap-year age boundaries', () {
      expect(parseDocumentDate('03.02.1995'), DateTime(1995, 2, 3));
      expect(parseDocumentDate('2031-09-07'), DateTime(2031, 9, 7));
      expect(parseDocumentDate('31.02.2030'), isNull);
      expect(ageOn(DateTime(2008, 2, 29), DateTime(2026, 2, 28)), 17);
      expect(ageOn(DateTime(2008, 2, 29), DateTime(2026, 3)), 18);
    });

    test('validates MRZ check digits', () {
      expect(mrzCheckDigitIsValid('900101', _mrzDigit('900101')), isTrue);
      expect(mrzCheckDigitIsValid('900101', '9'), isFalse);
    });

    test('enforces every verification-session state transition', () {
      expect(
        VerificationSessionState.created.canTransitionTo(
          VerificationSessionState.requiresDeclaration,
        ),
        isTrue,
      );
      expect(
        VerificationSessionState.requiresDeclaration.canTransitionTo(
          VerificationSessionState.completed,
        ),
        isTrue,
      );
      for (final terminal in const [
        VerificationSessionState.completed,
        VerificationSessionState.expired,
        VerificationSessionState.failed,
      ]) {
        expect(
          terminal.canTransitionTo(VerificationSessionState.created),
          isFalse,
        );
      }
      expect(
        VerificationSessionState.completed.canTransitionTo(
          VerificationSessionState.completed,
        ),
        isTrue,
      );
    });

    test('derives effective expiry from a date instead of a stale boolean', () {
      VerificationV1Record record(DateTime expiry) => VerificationV1Record(
        status: VerificationV1Status.verified,
        assuranceLevel: 'document_data_match',
        verificationMethod: 'on_device_ocr_front_v1',
        documentExpiresAt: expiry,
      );

      final today = DateTime(2026, 8, 30, 23, 59);
      expect(
        VerificationV1Policy.effectiveIdentityStatus(
          record(DateTime(2026, 8, 29)),
          serverToday: today,
        ),
        VerificationV1Status.expired,
      );
      expect(
        VerificationV1Policy.effectiveIdentityStatus(
          record(DateTime(2026, 8, 30)),
          serverToday: today,
        ),
        VerificationV1Status.verified,
      );
      expect(
        VerificationV1Policy.effectiveIdentityStatus(
          record(DateTime(2026, 8, 31)),
          serverToday: today,
        ),
        VerificationV1Status.verified,
      );
    });

    test('keeps the four vehicle relations separate and deterministic', () {
      expect(VerificationVehicleRelation.values.map((value) => value.value), [
        'registered_holder',
        'leasing_vehicle',
        'company_vehicle',
        'authorized_by_holder',
      ]);
      expect(
        VerificationVehicleRelation.values
            .where((value) => value.requiresDeclaration)
            .length,
        3,
      );
    });
  });

  group('document parsers', () {
    test('parses a German identity-card front from spatial OCR blocks', () {
      final result = const GermanIdCardFrontParser().parse([
        _block('Familienname', 10, 10, 130, 30),
        _block('Muster', 150, 10, 250, 30),
        _block('Vornamen', 10, 50, 130, 70),
        _block('Erika Maria', 150, 50, 270, 70),
        _block('Geburtsdatum', 10, 90, 130, 110),
        _block('01.01.1990', 150, 90, 250, 110),
        _block('Gültig bis', 10, 130, 130, 150),
        _block('31.12.2030', 150, 130, 250, 150),
      ]);

      expect(result.isSuccess, isTrue);
      expect(result.data!.firstNames, 'Erika Maria');
      expect(result.data!.lastName, 'Muster');
      expect(result.data!.expiresAt, DateTime(2030, 12, 31));
    });

    test('parses a German residence-permit front', () {
      final result = const GermanResidencePermitFrontParser().parse([
        _block('Familienname', 10, 10, 130, 30),
        _block('Yilmaz', 150, 10, 250, 30),
        _block('Vornamen', 10, 50, 130, 70),
        _block('Aylin', 150, 50, 250, 70),
        _block('Geburtsdatum', 10, 90, 130, 110),
        _block('03.02.1995', 150, 90, 250, 110),
        _block('Gültig bis', 10, 130, 130, 150),
        _block('07.09.2031', 150, 130, 250, 150),
      ]);

      expect(result.isSuccess, isTrue);
      expect(
        result.data!.documentType,
        VerificationIdentityDocumentType.residencePermit,
      );
    });

    test('parses a passport MRZ and rejects an invalid check digit', () {
      final first = 'P<DEUMUSTERMANN<<ERIKA<MARIA'.padRight(44, '<');
      final birth = '900101';
      final expiry = '301231';
      final second =
          'C01X00T470DEU$birth${_mrzDigit(birth)}F$expiry${_mrzDigit(expiry)}'
              .padRight(44, '<');
      final parser = PassportDataPageParser(now: DateTime(2026, 1));

      final parsed = parser.parse([_block('$first\n$second', 0, 0, 440, 40)]);
      expect(parsed.isSuccess, isTrue);
      expect(parsed.data!.lastName, 'MUSTERMANN');
      expect(parsed.data!.firstNames, 'ERIKA MARIA');

      final invalid = second.replaceRange(
        19,
        20,
        second[19] == '9' ? '8' : '9',
      );
      final rejected = parser.parse([
        _block('$first\n$invalid', 0, 0, 440, 40),
      ]);
      expect(rejected.isSuccess, isFalse);
      expect(rejected.failure, VerificationParseFailure.ambiguousField);
    });

    test('parses vehicle fields and permits an empty C.1.2 for a company', () {
      final result = const GermanVehicleRegistrationFrontParser().parse([
        _block('A', 10, 10, 25, 30),
        _block('HH AB 123', 50, 10, 160, 30),
        _block('C.1.1', 10, 50, 60, 70),
        _block('Beispiel GmbH', 90, 50, 230, 70),
      ]);

      expect(result.isSuccess, isTrue);
      expect(result.data!.plate, 'HH AB 123');
      expect(result.data!.holderNameOrCompany, 'Beispiel GmbH');
      expect(result.data!.holderFirstNames, isNull);
    });

    test('does not guess between equally plausible OCR values', () {
      final result = const GermanVehicleRegistrationFrontParser().parse([
        _block('A', 10, 10, 25, 30),
        _block('HH AB 123', 50, 10, 160, 30),
        _block('HH CD 456', 50, 10, 160, 30),
        _block('C.1.1', 10, 50, 60, 70),
        _block('Muster', 90, 50, 160, 70),
      ]);

      expect(result.isSuccess, isFalse);
      expect(result.failure, VerificationParseFailure.missingRequiredField);
    });

    test('rejects a vehicle document with missing holder data', () {
      final result = const GermanVehicleRegistrationFrontParser().parse([
        _block('A', 10, 10, 25, 30),
        _block('HH AB 123', 50, 10, 160, 30),
      ]);

      expect(result.isSuccess, isFalse);
      expect(result.failure, VerificationParseFailure.missingRequiredField);
    });
  });

  group('local image lifecycle', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('plaqa_verify_test_');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('detects dark, overexposed and low-resolution photos', () async {
      final service = LocalImageQualityService(
        minimumLongEdge: 100,
        minimumShortEdge: 80,
      );
      final dark = await _writeSolid(root, 'dark.png', 120, 90, 0);
      final bright = await _writeSolid(root, 'bright.png', 120, 90, 255);
      final small = await _writeSolid(root, 'small.png', 20, 20, 128);
      final blurry = await _writeSolid(root, 'blurry.png', 120, 90, 128);

      expect(
        (await service.inspect(dark.path)).failures,
        contains(ImageQualityFailure.tooDark),
      );
      expect(
        (await service.inspect(bright.path)).failures,
        contains(ImageQualityFailure.overexposed),
      );
      expect(
        (await service.inspect(small.path)).failures,
        contains(ImageQualityFailure.tooSmall),
      );
      expect(
        (await service.inspect(blurry.path)).failures,
        contains(ImageQualityFailure.blurry),
      );
    });

    test(
      'adopts captures and removes source plus managed temporary files',
      () async {
        final managedRoot = Directory('${root.path}/managed');
        final source = await _writeSolid(root, 'source.png', 20, 20, 120);
        final service = LocalVerificationTemporaryFileService(
          root: managedRoot,
        );

        final adopted = await service.adopt(source.path);
        expect(await File(adopted).exists(), isTrue);
        expect(await source.exists(), isFalse);

        await service.delete(adopted);
        expect(await File(adopted).exists(), isFalse);

        final orphan = File('${managedRoot.path}/orphan.jpg');
        await orphan.create(recursive: true);
        await service.cleanupOrphans();
        expect(await orphan.exists(), isFalse);
      },
    );

    test('removes a temporary camera source when adoption fails', () async {
      final managedRoot = Directory('${root.path}/managed-failure');
      final source = File('${root.path}/broken-camera-source.jpg');
      await source.writeAsBytes([1, 2, 3], flush: true);
      final service = LocalVerificationTemporaryFileService(root: managedRoot);

      await expectLater(
        service.adopt(source.path),
        throwsA(anyOf(isA<FormatException>(), isA<RangeError>())),
      );

      expect(await source.exists(), isFalse);
    });
  });
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

Future<File> _writeSolid(
  Directory directory,
  String name,
  int width,
  int height,
  int value,
) async {
  final bitmap = image.Image(width: width, height: height);
  image.fill(bitmap, color: image.ColorRgb8(value, value, value));
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(image.encodePng(bitmap), flush: true);
  return file;
}
