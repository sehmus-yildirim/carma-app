import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:integration_test/integration_test.dart';
import 'package:plaqa/features/profile/data/profile_repository.dart';
import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_repository.dart';
import 'package:plaqa/features/profile/data/user_profile.dart';
import 'package:plaqa/features/profile/presentation/profile_verification_screen.dart';
import 'package:plaqa/features/profile/verification_v1/data/document_services.dart';
import 'package:plaqa/features/profile/verification_v1/data/verification_v1_repository.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_models.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_parsers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'ML Kit extracts the marked synthetic identity fixture on Android',
    (_) async {
      final directory = await Directory.systemTemp.createTemp(
        'plaqa_ocr_fixture_',
      );
      final file = File('${directory.path}/identity_test_not_valid.png');
      final bitmap = image.Image(width: 1600, height: 1000);
      image.fill(bitmap, color: image.ColorRgb8(244, 244, 240));
      image.drawString(
        bitmap,
        'PLAQA TEST DOCUMENT - SAMPLE - NOT VALID',
        font: image.arial24,
        x: 60,
        y: 50,
        color: image.ColorRgb8(0, 0, 0),
      );
      for (final line in const [
        (text: 'FAMILIENNAME: MUSTERMANN', y: 220),
        (text: 'VORNAMEN: ERIKA MARIA', y: 380),
        (text: 'GEBURTSDATUM: 01.01.1990', y: 540),
        (text: 'GULTIG BIS: 31.12.2030', y: 700),
      ]) {
        image.drawString(
          bitmap,
          line.text,
          font: image.arial48,
          x: 80,
          y: line.y,
          color: image.ColorRgb8(0, 0, 0),
        );
      }
      await file.writeAsBytes(image.encodePng(bitmap), flush: true);
      final recognizer = MlKitDocumentOcrService();
      try {
        final blocks = await recognizer.recognize(file.path);
        final parsed = const GermanIdCardFrontParser().parse(blocks);
        expect(parsed.isSuccess, isTrue, reason: parsed.message);
        expect(parsed.data!.firstNames, 'ERIKA MARIA');
        expect(parsed.data!.lastName, 'MUSTERMANN');
        expect(parsed.data!.dateOfBirth, DateTime(1990, 1, 1));
        expect(parsed.data!.expiresAt, DateTime(2030, 12, 31));
      } finally {
        await recognizer.close();
        await directory.delete(recursive: true);
      }
    },
    skip: !Platform.isAndroid,
  );

  testWidgets('registered holder completes the full synthetic flow', (
    tester,
  ) async {
    final gateway = _IntegrationGateway();
    await _pump(tester, gateway);
    await _prepareDocuments(tester);
    await _acceptPrivacy(tester);

    await _tap(tester, find.text('Abgleichen'));
    await tester.pumpAndSettle();

    expect(find.text('Fahrzeug verifiziert'), findsOneWidget);
    expect(gateway.submissions, 1);
    expect(gateway.finalizations, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blurry identity photo requires a retake before success', (
    tester,
  ) async {
    final gateway = _IntegrationGateway();
    await _pump(
      tester,
      gateway,
      qualityService: _QualityService(blurryFirstInspection: true),
    );

    await _tap(tester, find.text('Vorderseite fotografieren'));
    expect(
      find.text(
        'Das Foto ist unscharf. Bitte halte das Smartphone ruhig und fotografiere erneut.',
      ),
      findsOneWidget,
    );
    expect(find.text('Weiter zum Fahrzeug'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Weiter zum Fahrzeug'),
          )
          .onPressed,
      isNull,
    );

    await _prepareDocuments(tester);
    await _acceptPrivacy(tester);
    await _tap(tester, find.text('Abgleichen'));
    expect(find.text('Fahrzeug verifiziert'), findsOneWidget);
  });

  testWidgets('unknown identity document is rejected without submission', (
    tester,
  ) async {
    final gateway = _IntegrationGateway();
    await _pump(
      tester,
      gateway,
      ocrService: _OcrService(
        identityBlocks: [
          _block('PLAQA TEST DOCUMENT - SAMPLE - NOT VALID', 10, 10, 430, 40),
          _block('UNBEKANNTES DOKUMENT', 10, 60, 280, 90),
        ],
      ),
    );

    await _tap(tester, find.text('Vorderseite fotografieren'));

    expect(
      find.text('Vorname konnte nicht eindeutig erkannt werden.'),
      findsOneWidget,
    );
    expect(gateway.submissions, 0);
  });

  testWidgets('invalid passport MRZ never reaches automatic verification', (
    tester,
  ) async {
    final gateway = _IntegrationGateway();
    const birth = '900101';
    const expiry = '301231';
    final validBirthDigit = _mrzDigit(birth);
    final invalidBirthDigit = validBirthDigit == '9' ? '8' : '9';
    final first = 'P<DEUMUSTERMANN<<ERIKA<MARIA'.padRight(44, '<');
    final second =
        'C01X00T470DEU$birth$invalidBirthDigit'
                'F$expiry${_mrzDigit(expiry)}'
            .padRight(44, '<');
    await _pump(
      tester,
      gateway,
      ocrService: _OcrService(
        identityBlocks: [
          _block(first, 8, 180, 448, 202),
          _block(second, 8, 206, 448, 228),
        ],
      ),
    );
    await _tap(tester, find.text('Personalausweis'));
    await _tap(tester, find.text('Reisepass').last);
    await _tap(tester, find.text('Datenseite fotografieren'));

    expect(
      find.text(
        'Die Prüfziffern der maschinenlesbaren Zone stimmen nicht. Bitte fotografiere das Dokument erneut.',
      ),
      findsOneWidget,
    );
    expect(gateway.submissions, 0);
  });

  for (final scenario in const [
    (
      name: 'expired identity document',
      message:
          'Der Identitätsnachweis ist abgelaufen. Bitte verwende ein gültiges Dokument.',
      birthDate: '01.01.1990',
      expiresAt: '31.12.2020',
      lastName: 'Muster',
      plate: 'HH AB 123',
    ),
    (
      name: 'minimum age not met',
      message: 'Für Plaqa musst du mindestens 16 Jahre alt sein.',
      birthDate: '01.01.2015',
      expiresAt: '31.12.2030',
      lastName: 'Muster',
      plate: 'HH AB 123',
    ),
    (
      name: 'holder name mismatch',
      message:
          'Der Name im Identitätsnachweis stimmt nicht mit dem Fahrzeugschein überein.',
      birthDate: '01.01.1990',
      expiresAt: '31.12.2030',
      lastName: 'Anders',
      plate: 'HH AB 123',
    ),
    (
      name: 'vehicle plate mismatch',
      message:
          'Das Kennzeichen im Fahrzeugschein stimmt nicht mit dem ausgewählten Fahrzeug überein.',
      birthDate: '01.01.1990',
      expiresAt: '31.12.2030',
      lastName: 'Muster',
      plate: 'HH CD 999',
    ),
  ]) {
    testWidgets('holder flow rejects ${scenario.name}', (tester) async {
      final gateway = _IntegrationGateway(
        submissionErrors: [VerificationV1Exception(scenario.message)],
      );
      await _pump(
        tester,
        gateway,
        ocrService: _OcrService(
          birthDate: scenario.birthDate,
          expiresAt: scenario.expiresAt,
          identityLastName: scenario.lastName,
          plate: scenario.plate,
        ),
      );
      await _prepareDocuments(tester);
      await _acceptPrivacy(tester);
      await _tap(tester, find.text('Abgleichen'));

      expect(find.text(scenario.message), findsOneWidget);
      expect(find.text('Fahrzeug verifiziert'), findsNothing);
      expect(gateway.submissions, 1);
    });
  }

  for (final relation in VerificationVehicleRelation.values.where(
    (value) => value.requiresDeclaration,
  )) {
    testWidgets('${relation.value} requires and finalizes a declaration', (
      tester,
    ) async {
      final gateway = _IntegrationGateway();
      await _pump(
        tester,
        gateway,
        ocrService: _OcrService(
          companyHolder: relation == VerificationVehicleRelation.companyCar,
        ),
      );
      await _scanIdentity(tester);
      await _tap(
        tester,
        find.byKey(ValueKey('verification-relation-${relation.value}')),
      );
      await _scanVehicle(tester);
      await _acceptPrivacy(tester);
      await _tap(tester, find.text('Zum Abgleich'));

      expect(find.text('Eigenerklärung'), findsWidgets);
      await _tap(tester, find.textContaining('Ich habe die Eigenerklärung'));
      await tester.ensureVisible(
        find.byKey(const ValueKey('verification-signature-pad')),
      );
      await tester.pumpAndSettle();
      await tester.timedDrag(
        find.byKey(const ValueKey('verification-signature-pad')),
        const Offset(250, 90),
        const Duration(milliseconds: 500),
      );
      await tester.pump();
      await _tap(tester, find.text('Verbindlich bestätigen'));

      expect(find.text('Fahrzeug verifiziert'), findsOneWidget);
      expect(gateway.finalizations, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('camera permission denial is recoverable and contains no crash', (
    tester,
  ) async {
    final gateway = _IntegrationGateway();
    await _pump(
      tester,
      gateway,
      captureService: _CaptureService(
        error: const VerificationV1Exception(
          'Der Kamerazugriff wurde verweigert.',
        ),
      ),
    );

    await _tap(tester, find.text('Vorderseite fotografieren'));
    expect(find.text('Der Kamerazugriff wurde verweigert.'), findsOneWidget);
    expect(find.text('Vorderseite fotografieren'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network loss before submit allows a safe retry', (tester) async {
    final gateway = _IntegrationGateway(
      submissionErrors: [
        const VerificationV1Exception(
          'Die Verbindung wurde unterbrochen. Bitte versuche es erneut.',
          code: 'unavailable',
        ),
      ],
    );
    await _pump(tester, gateway);
    await _prepareDocuments(tester);
    await _acceptPrivacy(tester);

    final submit = find.text('Abgleichen');
    await _tap(tester, submit);
    expect(gateway.sessions, 1);
    expect(gateway.submissions, 1);

    await _tap(tester, submit);
    expect(find.text('Fahrzeug verifiziert'), findsOneWidget);
    expect(gateway.sessions, 1);
    expect(gateway.submissions, 2);
  });

  testWidgets('rapid duplicate submit is ignored while request is active', (
    tester,
  ) async {
    final gateway = _IntegrationGateway(
      submissionDelay: const Duration(milliseconds: 120),
    );
    await _pump(tester, gateway);
    await _prepareDocuments(tester);
    await _acceptPrivacy(tester);

    final submit = find.text('Abgleichen');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Fahrzeug verifiziert'), findsOneWidget);
    expect(gateway.sessions, 1);
    expect(gateway.submissions, 1);
  });

  testWidgets('expired session is discarded and recreated on retry', (
    tester,
  ) async {
    final gateway = _IntegrationGateway(
      submissionErrors: [
        const VerificationV1Exception(
          'Die Session ist abgelaufen. Bitte starte die Verifizierung erneut.',
          code: 'deadline-exceeded',
          reason: 'session-expired',
        ),
      ],
    );
    await _pump(tester, gateway);
    await _prepareDocuments(tester);
    await _acceptPrivacy(tester);

    await _tap(tester, find.text('Abgleichen'));
    expect(find.textContaining('Session ist abgelaufen'), findsOneWidget);
    await _tap(tester, find.text('Abgleichen'));

    expect(find.text('Fahrzeug verifiziert'), findsOneWidget);
    expect(gateway.sessions, 2);
    expect(gateway.submissions, 2);
  });

  testWidgets('logout disposes the flow and cleans temporary files', (
    tester,
  ) async {
    final temporaryFiles = _TemporaryFileService();
    await _pump(
      tester,
      _IntegrationGateway(),
      temporaryFileService: temporaryFiles,
    );
    await _tap(tester, find.text('Vorderseite fotografieren'));
    expect(temporaryFiles.deletedPaths, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(temporaryFiles.cleanupCalls, greaterThanOrEqualTo(2));
  });

  test('plate change uses the authoritative invalidation command', () async {
    final gateway = _IntegrationGateway();
    final repository = VerificationV1Repository(gateway: gateway);

    await repository.revokeVehicle(
      vehicleId: 'vehicle-1',
      reason: 'vehicle_plate_changed',
    );

    expect(gateway.revocations, 1);
    expect(gateway.lastRevocationReason, 'vehicle_plate_changed');
  });
}

Future<void> _prepareDocuments(WidgetTester tester) async {
  await _scanIdentity(tester);
  await _scanVehicle(tester);
}

Future<void> _scanIdentity(WidgetTester tester) async {
  await _tap(tester, find.text('Vorderseite fotografieren'));
  await _tap(tester, find.text('Weiter zum Fahrzeug'));
}

Future<void> _scanVehicle(WidgetTester tester) async {
  await _tap(tester, find.text('Fahrzeugschein fotografieren'));
}

Future<void> _acceptPrivacy(WidgetTester tester) async {
  await _tap(tester, find.text('Datenschutz & Berechtigung ansehen'));
  await _tap(tester, find.text('Information verstanden'));
  await _tap(tester, find.text('Ich habe die aktuelle Information gelesen.'));
}

Future<void> _pump(
  WidgetTester tester,
  _IntegrationGateway gateway, {
  DocumentCaptureService? captureService,
  DocumentOcrService? ocrService,
  ImageQualityService? qualityService,
  _TemporaryFileService? temporaryFileService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProfileVerificationScreen(
        userId: 'synthetic-user',
        profileRepository: _ProfileRepository(),
        vehicleRepository: _VehicleRepository(),
        verificationV1Repository: VerificationV1Repository(gateway: gateway),
        captureService: captureService ?? _CaptureService(),
        ocrService: ocrService ?? _OcrService(),
        imageQualityService: qualityService ?? _QualityService(),
        temporaryFileService: temporaryFileService ?? _TemporaryFileService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _ProfileRepository extends ProfileRepository {
  @override
  Stream<UserProfile?> watchProfile(String uid) => Stream.value(
    UserProfile(
      uid: uid,
      email: 'synthetic@example.test',
      firstName: 'Erika',
      lastName: 'Muster',
      displayName: 'Erika M.',
      country: 'Deutschland',
      birthDate: DateTime(1990),
    ),
  );
}

class _VehicleRepository extends ProfileVehicleRepository {
  @override
  Stream<List<ProfileVehicle>> watchOwnerVehicles(String userId) =>
      Stream.value(const [
        ProfileVehicle(
          id: 'vehicle-1',
          ownerUserId: 'synthetic-user',
          brand: 'BMW',
          model: 'X6',
          color: 'Schwarz',
          countryCode: 'DE',
          plateRegion: 'HH',
          plateLetters: 'AB',
          plateNumbers: '123',
          isPrimary: true,
        ),
      ]);
}

class _CaptureService implements DocumentCaptureService {
  _CaptureService({this.error});

  final VerificationV1Exception? error;

  @override
  Future<CapturedVerificationDocument?> capture(
    VerificationDocumentKind kind,
  ) async {
    if (error != null) throw error!;
    return CapturedVerificationDocument(
      path: 'synthetic-${kind.name}.jpg',
      kind: kind,
      deleteSourceAfterAdoption: false,
    );
  }
}

class _OcrService implements DocumentOcrService {
  _OcrService({
    this.birthDate = '01.01.1990',
    this.expiresAt = '31.12.2030',
    this.identityLastName = 'Muster',
    this.plate = 'HH AB 123',
    this.companyHolder = false,
    this.identityBlocks,
  });

  final String birthDate;
  final String expiresAt;
  final String identityLastName;
  final String plate;
  final bool companyHolder;
  final List<OcrBlock>? identityBlocks;

  @override
  Future<void> close() async {}

  @override
  Future<List<OcrBlock>> recognize(String imagePath) async =>
      imagePath.contains('vehicleRegistration')
      ? [
          _block('A', 10, 10, 25, 30),
          _block(plate, 50, 10, 160, 30),
          _block('C.1.1', 10, 50, 60, 70),
          _block(companyHolder ? 'Beispiel GmbH' : 'Muster', 90, 50, 210, 70),
          if (!companyHolder) ...[
            _block('C.1.2', 10, 90, 60, 110),
            _block('Erika Maria', 90, 90, 190, 110),
          ],
        ]
      : identityBlocks ??
            [
              _block('Familienname', 10, 10, 130, 30),
              _block(identityLastName, 150, 10, 250, 30),
              _block('Vornamen', 10, 50, 130, 70),
              _block('Erika Maria', 150, 50, 270, 70),
              _block('Geburtsdatum', 10, 90, 130, 110),
              _block(birthDate, 150, 90, 250, 110),
              _block('Gültig bis', 10, 130, 130, 150),
              _block(expiresAt, 150, 130, 250, 150),
            ];
}

class _QualityService implements ImageQualityService {
  _QualityService({this.blurryFirstInspection = false});

  final bool blurryFirstInspection;
  int inspections = 0;

  @override
  Future<ImageQualityResult> inspect(String imagePath) async {
    inspections += 1;
    if (blurryFirstInspection && inspections == 1) {
      return const ImageQualityResult(
        width: 1600,
        height: 1000,
        averageLuminance: 120,
        contrast: 18,
        sharpness: 1,
        failures: [ImageQualityFailure.blurry],
      );
    }
    return const ImageQualityResult(
      width: 1600,
      height: 1000,
      averageLuminance: 120,
      contrast: 42,
      sharpness: 8,
    );
  }
}

class _TemporaryFileService implements VerificationTemporaryFileService {
  int cleanupCalls = 0;
  final List<String> deletedPaths = [];

  @override
  Future<String> adopt(String sourcePath) async => sourcePath;

  @override
  Future<void> cleanupOrphans() async {
    cleanupCalls += 1;
  }

  @override
  Future<void> delete(String path) async {
    deletedPaths.add(path);
  }
}

class _IntegrationGateway implements VerificationV1Gateway {
  _IntegrationGateway({
    List<VerificationV1Exception> submissionErrors = const [],
    this.submissionDelay = Duration.zero,
  }) : submissionErrors = [...submissionErrors];

  final List<VerificationV1Exception> submissionErrors;
  final Duration submissionDelay;
  String relation = VerificationVehicleRelation.registeredHolder.value;
  int sessions = 0;
  int submissions = 0;
  int finalizations = 0;
  int revocations = 0;
  String? lastRevocationReason;

  @override
  Future<Map<String, dynamic>> call(
    String command,
    Map<String, Object?> payload,
  ) async {
    if (command == 'createVerificationSessionV1') {
      sessions += 1;
      relation = payload['relation']!.toString();
      return {
        'sessionId': 'session-1',
        'nonce': List.filled(40, 'n').join(),
        'expiresAt': '2030-08-30T12:15:00.000Z',
        'state': 'created',
      };
    }
    if (command == 'submitVerificationDataV1') {
      submissions += 1;
      if (submissionDelay > Duration.zero) {
        await Future<void>.delayed(submissionDelay);
      }
      if (submissionErrors.isNotEmpty) throw submissionErrors.removeAt(0);
      return {
        'status': relation == VerificationVehicleRelation.registeredHolder.value
            ? 'verified'
            : 'requires_declaration',
        'holderMatch':
            relation == VerificationVehicleRelation.registeredHolder.value,
      };
    }
    if (command == 'finalizeVehicleDeclarationV1') {
      finalizations += 1;
      return {
        'status': 'verified',
        'holderMatch': false,
        'declarationId': 'declaration-1',
      };
    }
    if (command == 'revokeOrInvalidateVerificationV1') {
      revocations += 1;
      lastRevocationReason = payload['reason']?.toString();
      return {'status': 'revoked'};
    }
    return const {};
  }
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
