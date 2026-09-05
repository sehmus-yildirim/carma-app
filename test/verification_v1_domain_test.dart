import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:plaqa/features/profile/verification_v1/data/document_services.dart';
import 'package:plaqa/features/profile/verification_v1/data/local_image_quality_service.dart';
import 'package:plaqa/features/profile/verification_v1/domain/document_profiles.dart';
import 'package:plaqa/features/profile/verification_v1/domain/mrz_parser.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_confidence.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_models.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_normalization.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_parsers.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_state_machine.dart';

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
          'issuingCountryCode': 'DE',
          'documentProfileVersion': 'test-v1',
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
        'registrationCountryCode': 'DE',
        'documentProfileVersion': 'vehicle-test-v1',
      });
    });

    test('normalizes German and Turkish OCR variants conservatively', () {
      expect(normalizePersonName('  Müller - Öztürk  '), 'mueller-oeztuerk');
      expect(conservativeLastNameMatch('Groß', 'GROSS'), isTrue);
      expect(conservativeLastNameMatch('Yılmaz', 'YILMAZ'), isTrue);
      expect(conservativeFirstNamesMatch('Şehmuş', 'SEHMUS'), isTrue);
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
      expect(parseDocumentDate('O3 . O2 . 1995'), DateTime(1995, 2, 3));
      expect(parseDocumentDate('31 12 2030'), DateTime(2030, 12, 31));
      expect(parseDocumentDate('03021995'), DateTime(1995, 2, 3));
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
        verificationMethod: 'on_device_document_ocr_v1',
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

    test('keeps the five vehicle relations separate and deterministic', () {
      expect(VerificationVehicleRelation.values.map((value) => value.value), [
        'registered_holder',
        'leasing',
        'company_car',
        'authorized_private_vehicle',
        'other_authorized',
      ]);
      expect(
        VerificationVehicleRelation.values
            .where((value) => value.requiresDeclaration)
            .length,
        4,
      );
    });

    test(
      'registers every V1 country without claiming production validation',
      () {
        expect(DocumentProfileRegistry.countries, hasLength(21));
        expect(
          DocumentProfileRegistry.countries.map((country) => country.code),
          containsAll(<String>['DE', 'TR', 'UA', 'SY', 'XK', 'CH']),
        );
        expect(
          DocumentProfileRegistry.profiles.where(
            (profile) => profile.productionValidated,
          ),
          isEmpty,
        );
        for (final country in DocumentProfileRegistry.countries) {
          expect(
            DocumentProfileRegistry.identityTypesFor(country.code),
            contains(VerificationIdentityDocumentType.passport),
          );
        }
        expect(
          DocumentProfileRegistry.vehicleRegistrationProfile('TR'),
          isNull,
        );
      },
    );

    test('derives deterministic confidence from documented signals', () {
      const engine = VerificationConfidenceEngine();
      final high = engine.assess(
        field: VerificationField.lastName,
        signals: const {
          ConfidenceSignal.anchorFound,
          ConfidenceSignal.formatValid,
          ConfidenceSignal.uniqueCandidate,
        },
        thresholds: const DocumentConfidenceThresholds(),
      );
      final conflicted = engine.assess(
        field: VerificationField.lastName,
        signals: const {
          ConfidenceSignal.anchorFound,
          ConfidenceSignal.formatValid,
          ConfidenceSignal.uniqueCandidate,
          ConfidenceSignal.conflict,
        },
        thresholds: const DocumentConfidenceThresholds(),
      );
      expect(high.level, FieldConfidence.high);
      expect(conflicted.level, FieldConfidence.low);
    });

    test('enforces the explicit end-to-end flow state machine', () {
      final machine = VerificationStateMachine();
      for (final state in const [
        VerificationFlowState.capturingIdentity,
        VerificationFlowState.processingIdentity,
        VerificationFlowState.identityDataChecked,
        VerificationFlowState.capturingVehicle,
        VerificationFlowState.processingVehicle,
        VerificationFlowState.awaitingDeclaration,
        VerificationFlowState.declarationSigning,
        VerificationFlowState.verified,
      ]) {
        machine.transitionTo(state);
      }
      expect(machine.state, VerificationFlowState.verified);
      expect(
        () => machine.transitionTo(VerificationFlowState.notStarted),
        throwsStateError,
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

    test(
      'parses multilingual identity labels emitted as separate OCR lines',
      () {
        final result = const GermanIdCardFrontParser().parse([
          _block('NAME', 10, 10, 130, 28),
          _block('Surname / Nom', 10, 30, 150, 48),
          _block('YILDIRIM', 10, 50, 150, 70),
          _block('VORNAMEN', 10, 82, 130, 100),
          _block('Given names / Prénoms', 10, 102, 190, 120),
          _block('SEHMUS', 10, 122, 150, 142),
          _block('TAG DER GEBURT', 10, 154, 150, 172),
          _block('Date of birth', 10, 174, 150, 192),
          _block('01.01.1990', 10, 194, 130, 214),
          _block('GÜLTIG BIS', 10, 226, 130, 244),
          _block("Date d'expiration", 10, 246, 170, 264),
          _block('31.12.2030', 10, 266, 130, 286),
        ]);

        expect(
          result.isSuccess,
          isTrue,
          reason: '${result.failure}: ${result.message}',
        );
        expect(result.data!.firstNames, 'SEHMUS');
        expect(result.data!.lastName, 'YILDIRIM');
        expect(result.data!.dateOfBirth, DateTime(1990, 1, 1));
        expect(result.data!.expiresAt, DateTime(2030, 12, 31));
      },
    );

    test('strips the official surname marker and its observed OCR error', () {
      for (final surname in const ['[a] YILDIRIM', 'tal YILDIRIM']) {
        final result = const GermanIdCardFrontParser().parse([
          _block('NAME / SURNAME / NOM', 10, 10, 230, 30),
          _block(surname, 10, 34, 150, 54),
          _block('VORNAMEN / GIVEN NAMES / PRENOMS', 10, 68, 320, 88),
          _block('SEHMUS', 10, 92, 150, 112),
          _block('GEBURTSDATUM', 10, 126, 150, 146),
          _block('01.01.1990', 10, 150, 150, 170),
          _block('GÜLTIG BIS', 10, 184, 150, 204),
          _block('31.12.2030', 10, 208, 150, 228),
        ]);

        expect(
          result.isSuccess,
          isTrue,
          reason: '$surname: ${result.failure}: ${result.message}',
        );
        expect(result.data!.lastName, 'YILDIRIM');
      }
    });

    test('parses real-world combined labels with missing OCR punctuation', () {
      final result = const GermanIdCardFrontParser().parse([
        _block('NAME SURNAME NOM', 10, 10, 210, 30),
        _block('YILDIRIM', 10, 34, 150, 54),
        _block('VORNAME(N) GIVEN NAME(S) PRENOM(S)', 10, 68, 330, 88),
        _block('SEHMUS', 10, 92, 150, 112),
        _block(
          'GEBURTSDATUM DATE OF BIRTH DATE DE NAISSANCE',
          10,
          126,
          410,
          146,
        ),
        _block('01.01.1990', 10, 150, 150, 170),
        _block('GULTIG BIS: 31.12.2030', 10, 184, 390, 204),
      ]);

      expect(
        result.isSuccess,
        isTrue,
        reason: '${result.failure}: ${result.message}',
      );
      expect(result.data!.firstNames, 'SEHMUS');
      expect(result.data!.lastName, 'YILDIRIM');
      expect(result.data!.dateOfBirth, DateTime(1990, 1, 1));
      expect(result.data!.expiresAt, DateTime(2030, 12, 31));
    });

    test('parses labels and values merged into single OCR lines', () {
      final result = const GermanIdCardFrontParser().parse([
        _block('NAME / SURNAME / NOM: YILDIRIM', 10, 10, 330, 30),
        _block('VORNAMEN GIVEN NAMES PRENOMS: SEHMUS', 10, 44, 370, 64),
        _block(
          'GEBURTSDATUM DATE OF BIRTH DATE DE NAISSANCE: 01.01.1990',
          10,
          78,
          520,
          98,
        ),
        _block(
          'GÜLTIG BIS DATE OF EXPIRY DATE D EXPIRATION: 31.12.2030',
          10,
          112,
          500,
          132,
        ),
      ]);

      expect(result.isSuccess, isTrue);
      expect(result.data!.firstNames, 'SEHMUS');
      expect(result.data!.lastName, 'YILDIRIM');
      expect(result.data!.dateOfBirth, DateTime(1990, 1, 1));
      expect(result.data!.expiresAt, DateTime(2030, 12, 31));
    });

    test('rejects unlabeled dates instead of guessing their meaning', () {
      final result = const GermanIdCardFrontParser().parse([
        _block('NAME / SURNAME / NOM', 10, 10, 230, 30),
        _block('YILDIRIM', 10, 34, 150, 54),
        _block('VORNAMEN / GIVEN NAMES / PRENOMS', 10, 68, 320, 88),
        _block('SEHMUS', 10, 92, 150, 112),
        _block('O1 . O1 . 199O', 10, 150, 150, 170),
        _block('31 12 2030', 10, 208, 150, 228),
      ]);

      expect(result.isSuccess, isFalse);
      expect(result.failure, VerificationParseFailure.invalidDate);
    });

    test('parses and validates TD1, TD2 and TD3 MRZ structures', () {
      final parser = MrzParser(now: DateTime(2026, 1));
      final birth = '900101';
      final expiry = '301231';
      final td1 = parser.parse(
        [
          _block('I<DEU${'D23145890'.padRight(25, '<')}', 0, 0, 300, 20),
          _block(
            '$birth${_mrzDigit(birth)}F$expiry${_mrzDigit(expiry)}DEU'.padRight(
              30,
              '<',
            ),
            0,
            22,
            300,
            42,
          ),
          _block('MUSTERMANN<<ERIKA<MARIA'.padRight(30, '<'), 0, 44, 300, 64),
        ],
        allowedFormats: const [MrzFormat.td1],
      );
      final td2 = parser.parse(
        [
          _block(
            'I<DEUMUSTERMANN<<ERIKA<MARIA'.padRight(36, '<'),
            0,
            0,
            360,
            20,
          ),
          _block(
            'D231458907DEU$birth${_mrzDigit(birth)}F$expiry${_mrzDigit(expiry)}'
                .padRight(36, '<'),
            0,
            22,
            360,
            42,
          ),
        ],
        allowedFormats: const [MrzFormat.td2],
      );
      final td3 = PassportDataPageParser(now: DateTime(2026, 1)).parse([
        _block('P<DEUMUSTERMANN<<ERIKA<MARIA'.padRight(44, '<'), 0, 0, 440, 20),
        _block(
          'C01X00T470DEU$birth${_mrzDigit(birth)}F$expiry${_mrzDigit(expiry)}'
              .padRight(44, '<'),
          0,
          22,
          440,
          42,
        ),
      ]);
      expect(td1.isSuccess, isTrue, reason: td1.message);
      expect(td2.isSuccess, isTrue, reason: td2.message);
      expect(td3.isSuccess, isTrue, reason: td3.message);
    });

    test('still rejects equally plausible conflicting name values', () {
      final result = const GermanIdCardFrontParser().parse([
        _block('NAME', 10, 10, 130, 30),
        _block('YILDIRIM', 150, 10, 250, 30),
        _block('MUSTERMANN', 150, 10, 260, 30),
        _block('VORNAMEN', 10, 50, 130, 70),
        _block('SEHMUS', 150, 50, 250, 70),
        _block('GEBURTSDATUM', 10, 90, 130, 110),
        _block('01.01.1990', 150, 90, 250, 110),
        _block('GÜLTIG BIS', 10, 130, 130, 150),
        _block('31.12.2030', 150, 130, 250, 150),
      ]);

      expect(result.isSuccess, isFalse);
      expect(result.failure, VerificationParseFailure.missingRequiredField);
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
      'reports framing hints without vetoing OCR from image edges alone',
      () async {
        final service = LocalImageQualityService(
          minimumLongEdge: 100,
          minimumShortEdge: 80,
          minimumSharpness: 0.1,
        );
        final good = await _writeDocumentPolygon(root, 'good-frame.png', [
          image.Point(45, 45),
          image.Point(355, 45),
          image.Point(355, 255),
          image.Point(45, 255),
        ]);
        final small = await _writeDocumentPolygon(root, 'small-frame.png', [
          image.Point(150, 110),
          image.Point(250, 110),
          image.Point(250, 190),
          image.Point(150, 190),
        ]);
        final cropped = await _writeDocumentPolygon(root, 'cropped-frame.png', [
          image.Point(0, 45),
          image.Point(355, 45),
          image.Point(355, 255),
          image.Point(0, 255),
        ]);
        final rotated = await _writeDocumentPolygon(root, 'rotated-frame.png', [
          image.Point(80, 20),
          image.Point(360, 120),
          image.Point(320, 280),
          image.Point(40, 180),
        ]);
        final perspective =
            await _writeDocumentPolygon(root, 'perspective-frame.png', [
              image.Point(100, 45),
              image.Point(300, 45),
              image.Point(370, 260),
              image.Point(30, 260),
            ]);

        expect((await service.inspect(good.path)).failures, isEmpty);
        expect(
          (await service.inspect(small.path)).framingHints,
          contains(ImageQualityFailure.documentTooSmall),
        );
        expect(
          (await service.inspect(cropped.path)).framingHints,
          contains(ImageQualityFailure.documentCropped),
        );
        expect(
          (await service.inspect(rotated.path)).framingHints,
          contains(ImageQualityFailure.documentRotated),
        );
        expect(
          (await service.inspect(perspective.path)).framingHints,
          contains(ImageQualityFailure.perspectiveDistortion),
        );
        expect((await service.inspect(cropped.path)).isAcceptable, isTrue);
      },
    );

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

    test('accepts bounded verification source images', () {
      expect(
        () => validateVerificationSourceImage(
          byteLength: verificationDocumentMaxSourceBytes,
          width: verificationDocumentMaxDimension,
          height: verificationDocumentMaxDimension,
        ),
        returnsNormally,
      );
    });

    test(
      'capture cleanup removes temporary copies but preserves original files',
      () async {
        final cached = await _writeSolid(root, 'picker-copy.png', 20, 20, 120);
        await LocalVerificationTemporaryFileService.discardCaptureSource(
          cached.path,
        );
        expect(await cached.exists(), isFalse);

        final originalRoot = await Directory(
          '${Directory.current.path}/build',
        ).createTemp('verification-original-');
        try {
          final original = await _writeSolid(
            originalRoot,
            'original.png',
            20,
            20,
            120,
          );
          await LocalVerificationTemporaryFileService.discardCaptureSource(
            original.path,
          );
          expect(await original.exists(), isTrue);
        } finally {
          await originalRoot.delete(recursive: true);
        }
      },
    );

    test('rejects oversized verification source images', () {
      expect(
        () => validateVerificationSourceImage(
          byteLength: verificationDocumentMaxSourceBytes + 1,
          width: 1200,
          height: 800,
        ),
        throwsFormatException,
      );
      expect(
        () => validateVerificationSourceImage(
          byteLength: 1024,
          width: verificationDocumentMaxDimension,
          height: verificationDocumentMaxDimension + 1,
        ),
        throwsFormatException,
      );
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

Future<File> _writeDocumentPolygon(
  Directory directory,
  String name,
  List<image.Point> points,
) async {
  final bitmap = image.Image(width: 400, height: 300);
  image.fill(bitmap, color: image.ColorRgb8(24, 24, 28));
  image.fillPolygon(
    bitmap,
    vertices: points,
    color: image.ColorRgb8(224, 224, 220),
  );
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(image.encodePng(bitmap), flush: true);
  return file;
}
