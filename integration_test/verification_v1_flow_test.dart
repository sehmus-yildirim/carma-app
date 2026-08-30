import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:plaqa/features/profile/data/profile_repository.dart';
import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_repository.dart';
import 'package:plaqa/features/profile/data/user_profile.dart';
import 'package:plaqa/features/profile/presentation/profile_verification_screen.dart';
import 'package:plaqa/features/profile/verification_v1/data/document_services.dart';
import 'package:plaqa/features/profile/verification_v1/data/verification_v1_repository.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Weiter zum Fahrzeug'),
          )
          .onPressed,
      isNull,
    );

    await _prepareDocuments(tester);
    await _acceptPrivacy(tester);
    await _tap(tester, find.text('Abgleichen'));
    expect(find.text('Fahrzeug verifiziert'), findsOneWidget);
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
          companyHolder: relation == VerificationVehicleRelation.companyVehicle,
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
  });

  final String birthDate;
  final String expiresAt;
  final String identityLastName;
  final String plate;
  final bool companyHolder;

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
      : [
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
