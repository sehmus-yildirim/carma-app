import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/data/profile_repository.dart';
import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_repository.dart';
import 'package:plaqa/features/profile/data/user_profile.dart';
import 'package:plaqa/features/profile/presentation/profile_verification_screen.dart';
import 'package:plaqa/features/profile/verification_v1/data/document_services.dart';
import 'package:plaqa/features/profile/verification_v1/data/verification_v1_repository.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_models.dart';

void main() {
  testWidgets('replaces the legacy double-upload UI', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Identität & Fahrzeug'), findsOneWidget);
    expect(find.textContaining('Rückseite'), findsNothing);
    expect(find.text('Auswählen'), findsNothing);
    expect(
      find.textContaining('Ablaufdatum des Identitätsnachweises'),
      findsNothing,
    );
    expect(find.text('Personalausweis'), findsOneWidget);
    expect(find.text('Vorderseite fotografieren'), findsOneWidget);
  });

  testWidgets('opens the configured camera flow without a gallery chooser', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Vorderseite fotografieren'));
    await tester.pumpAndSettle();

    expect(find.text('Erika Maria'), findsOneWidget);
    expect(find.text('Galerie'), findsNothing);
  });

  testWidgets('shows OCR identity values read-only and advances', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Vorderseite fotografieren'));
    await tester.pumpAndSettle();

    expect(find.text('Erika Maria'), findsOneWidget);
    expect(find.text('Muster'), findsOneWidget);
    expect(find.text('01.01.1990'), findsOneWidget);
    expect(find.text('31.12.2030'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Erika Maria'), findsNothing);

    await tester.tap(find.text('Weiter zum Fahrzeug'));
    await tester.pumpAndSettle();
    expect(find.text('Fahrzeugbezug bestätigen'), findsOneWidget);
  });

  testWidgets('updates the camera CTA for every document type', (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Personalausweis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reisepass').last);
    await tester.pumpAndSettle();
    expect(find.text('Datenseite fotografieren'), findsOneWidget);

    await tester.tap(find.text('Reisepass'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aufenthaltstitel').last);
    await tester.pumpAndSettle();
    expect(find.text('Vorderseite fotografieren'), findsOneWidget);
  });

  testWidgets('requires an existing vehicle before a registration scan', (
    tester,
  ) async {
    await _pumpScreen(tester, vehicleRepository: _EmptyVehicleRepository());
    await tester.tap(find.text('Vorderseite fotografieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weiter zum Fahrzeug'));
    await tester.pumpAndSettle();

    expect(
      find.text('Lege zuerst ein Fahrzeug in deinem Profil an.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Fahrzeugschein fotografieren'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('offers exactly five separate vehicle relations', (tester) async {
    await _reachVehicleStep(tester);

    for (final relation in VerificationVehicleRelation.values) {
      expect(find.text(relation.label), findsOneWidget);
    }
    expect(find.text('Leasing- oder Firmenfahrzeug'), findsNothing);
  });

  testWidgets('requires privacy information before server submit', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _reachVehicleStep(tester, gateway: gateway);
    await tester.tap(find.text('Fahrzeugschein fotografieren'));
    await tester.pumpAndSettle();

    expect(find.text('HH AB 123'), findsOneWidget);
    final submit = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Abgleichen'),
    );
    expect(submit.onPressed, isNull);

    await _acceptPrivacy(tester);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Abgleichen'),
          )
          .onPressed,
      isNotNull,
    );
    expect(gateway.calls, isEmpty);
  });

  testWidgets('registered holder completes without declaration', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _prepareAndSubmit(tester, gateway: gateway);

    expect(find.text('Fahrzeug verifiziert'), findsOneWidget);
    expect(find.text('Eigenerklärung'), findsNothing);
    expect(gateway.calls.map((call) => call.command), [
      'createVerificationSessionV1',
      'submitVerificationDataV1',
    ]);
  });

  for (final error in const [
    'Der Name im Identitätsnachweis stimmt nicht mit deinem Profil überein.',
    'Das Kennzeichen im Fahrzeugschein stimmt nicht mit dem ausgewählten Fahrzeug überein.',
  ]) {
    testWidgets('shows the safe server validation error: $error', (
      tester,
    ) async {
      final gateway = _FakeGateway(submitError: VerificationV1Exception(error));
      await _prepareAndSubmit(tester, gateway: gateway);

      expect(find.text(error), findsOneWidget);
      expect(find.text('Fahrzeug verifiziert'), findsNothing);
      expect(find.text('Neu fotografieren'), findsWidgets);
    });
  }

  testWidgets('shows a loading state and prevents a second submit', (
    tester,
  ) async {
    final gateway = _FakeGateway(submitDelay: const Duration(milliseconds: 80));
    await _reachVehicleStep(tester, gateway: gateway);
    await tester.tap(find.text('Fahrzeugschein fotografieren'));
    await tester.pumpAndSettle();
    await _acceptPrivacy(tester);

    await tester.tap(find.text('Abgleichen'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Abgleichen'),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpAndSettle();
    expect(find.text('Fahrzeug verifiziert'), findsOneWidget);
  });

  testWidgets('non-holder requires declaration, checkbox and signature', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _reachVehicleStep(tester, gateway: gateway);
    await tester.tap(
      find.byKey(const ValueKey('verification-relation-leasing')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Zum Abgleich'), findsOneWidget);
    await tester.tap(find.text('Fahrzeugschein fotografieren'));
    await tester.pumpAndSettle();
    expect(find.text('Zum Abgleich'), findsOneWidget);
    await _acceptPrivacy(tester);
    expect(
      find.text('Zum Abgleich'),
      findsOneWidget,
      reason: 'the non-holder relation must survive privacy confirmation',
    );
    await tester.tap(find.text('Zum Abgleich'));
    await tester.pumpAndSettle();

    expect(find.text('Eigenerklärung'), findsWidgets);
    final finalizeFinder = find.widgetWithText(
      OutlinedButton,
      'Verbindlich bestätigen',
    );
    expect(tester.widget<OutlinedButton>(finalizeFinder).onPressed, isNull);

    await tester.tap(find.textContaining('Ich habe die Eigenerklärung'));
    await tester.pump();
    final signature = find.byKey(const ValueKey('verification-signature-pad'));
    await tester.timedDrag(
      signature,
      const Offset(260, 90),
      const Duration(milliseconds: 700),
    );
    await tester.pump();

    expect(tester.widget<OutlinedButton>(finalizeFinder).onPressed, isNotNull);
    await tester.tap(finalizeFinder);
    await tester.pumpAndSettle();
    expect(find.text('Fahrzeug verifiziert'), findsOneWidget);
    expect(find.textContaining('privat gespeichert'), findsOneWidget);
  });

  testWidgets('shows safe scan errors and supports retry', (tester) async {
    await _pumpScreen(
      tester,
      captureService: _FakeCaptureService(
        error: const VerificationV1Exception(
          'Der Kamerazugriff wurde verweigert.',
        ),
      ),
    );

    await tester.tap(find.text('Vorderseite fotografieren'));
    await tester.pumpAndSettle();
    expect(find.text('Der Kamerazugriff wurde verweigert.'), findsOneWidget);
    expect(find.text('Vorderseite fotografieren'), findsOneWidget);
  });

  testWidgets('uses a camera-managed capture without adopting it twice', (
    tester,
  ) async {
    final temporaryFiles = _FakeTemporaryFileService();
    await _pumpScreen(
      tester,
      captureService: _FakeCaptureService(managed: true),
      temporaryFileService: temporaryFiles,
    );

    await tester.tap(find.text('Vorderseite fotografieren'));
    await tester.pumpAndSettle();

    expect(temporaryFiles.adoptedPaths, isEmpty);
    expect(temporaryFiles.deletedPaths, contains('synthetic-identityCard.jpg'));
    expect(find.text('Erika Maria'), findsOneWidget);
  });

  testWidgets('does not overflow on a small display with large text', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      surfaceSize: const Size(320, 640),
      textScaler: const TextScaler.linear(1.7),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Identität & Fahrzeug'), findsOneWidget);
  });

  testWidgets('exposes the flow and camera action to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpScreen(tester);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Schritt 1 von 4: Identität',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Vorderseite fotografieren',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}

Future<void> _prepareAndSubmit(
  WidgetTester tester, {
  required _FakeGateway gateway,
}) async {
  await _reachVehicleStep(tester, gateway: gateway);
  await tester.tap(find.text('Fahrzeugschein fotografieren'));
  await tester.pumpAndSettle();
  await _acceptPrivacy(tester);
  await tester.tap(find.text('Abgleichen'));
  await tester.pumpAndSettle();
}

Future<void> _reachVehicleStep(
  WidgetTester tester, {
  _FakeGateway? gateway,
}) async {
  await _pumpScreen(tester, gateway: gateway);
  await tester.tap(find.text('Vorderseite fotografieren'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Weiter zum Fahrzeug'));
  await tester.pumpAndSettle();
}

Future<void> _acceptPrivacy(WidgetTester tester) async {
  await tester.tap(find.text('Datenschutz & Berechtigung ansehen'));
  await tester.pumpAndSettle();
  expect(
    find.textContaining('keine amtliche Echtheitsprüfung'),
    findsOneWidget,
  );
  await tester.tap(find.text('Information verstanden'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ich habe die aktuelle Information gelesen.'));
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  _FakeGateway? gateway,
  DocumentCaptureService? captureService,
  VerificationTemporaryFileService? temporaryFileService,
  ProfileVehicleRepository? vehicleRepository,
  Size surfaceSize = const Size(430, 5000),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final effectiveGateway = gateway ?? _FakeGateway();
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: ProfileVerificationScreen(
        userId: 'user-1',
        profileRepository: _FakeProfileRepository(),
        vehicleRepository: vehicleRepository ?? _FakeVehicleRepository(),
        verificationV1Repository: VerificationV1Repository(
          gateway: effectiveGateway,
        ),
        captureService: captureService ?? _FakeCaptureService(),
        ocrService: _FakeOcrService(),
        imageQualityService: const _FakeQualityService(),
        temporaryFileService:
            temporaryFileService ?? _FakeTemporaryFileService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeProfileRepository extends ProfileRepository {
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

class _FakeVehicleRepository extends ProfileVehicleRepository {
  @override
  Stream<List<ProfileVehicle>> watchOwnerVehicles(String userId) =>
      Stream.value([
        const ProfileVehicle(
          id: 'vehicle-1',
          ownerUserId: 'user-1',
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

class _EmptyVehicleRepository extends ProfileVehicleRepository {
  @override
  Stream<List<ProfileVehicle>> watchOwnerVehicles(String userId) =>
      Stream.value(const []);
}

class _FakeCaptureService implements DocumentCaptureService {
  _FakeCaptureService({this.error, this.managed = false});

  final Object? error;
  final bool managed;

  @override
  Future<CapturedVerificationDocument?> capture(
    VerificationDocumentKind kind,
  ) async {
    if (error != null) throw error!;
    return CapturedVerificationDocument(
      path: 'synthetic-${kind.name}.jpg',
      kind: kind,
      deleteSourceAfterAdoption: false,
      isManagedTemporaryFile: managed,
    );
  }
}

class _FakeOcrService implements DocumentOcrService {
  @override
  Future<void> close() async {}

  @override
  Future<List<OcrBlock>> recognize(String imagePath) async {
    if (imagePath.contains('vehicleRegistration')) {
      return [
        _block('A', 10, 10, 25, 30),
        _block('HH AB 123', 50, 10, 160, 30),
        _block('C.1.1', 10, 50, 60, 70),
        _block('Muster', 90, 50, 160, 70),
        _block('C.1.2', 10, 90, 60, 110),
        _block('Erika Maria', 90, 90, 190, 110),
      ];
    }
    return [
      _block('Familienname', 10, 10, 130, 30),
      _block('Muster', 150, 10, 250, 30),
      _block('Vornamen', 10, 50, 130, 70),
      _block('Erika Maria', 150, 50, 270, 70),
      _block('Geburtsdatum', 10, 90, 130, 110),
      _block('01.01.1990', 150, 90, 250, 110),
      _block('Gültig bis', 10, 130, 130, 150),
      _block('31.12.2030', 150, 130, 250, 150),
    ];
  }
}

class _FakeQualityService implements ImageQualityService {
  const _FakeQualityService();

  @override
  Future<ImageQualityResult> inspect(String imagePath) async =>
      const ImageQualityResult(
        width: 1600,
        height: 1000,
        averageLuminance: 120,
        contrast: 42,
        sharpness: 8,
      );
}

class _FakeTemporaryFileService implements VerificationTemporaryFileService {
  final List<String> adoptedPaths = [];
  final List<String> deletedPaths = [];

  @override
  Future<String> adopt(String sourcePath) async {
    adoptedPaths.add(sourcePath);
    return sourcePath;
  }

  @override
  Future<void> cleanupOrphans() async {}

  @override
  Future<void> delete(String path) async => deletedPaths.add(path);
}

class _GatewayCall {
  const _GatewayCall(this.command, this.payload);

  final String command;
  final Map<String, Object?> payload;
}

class _FakeGateway implements VerificationV1Gateway {
  _FakeGateway({this.submitError, this.submitDelay = Duration.zero});

  final List<_GatewayCall> calls = [];
  final VerificationV1Exception? submitError;
  final Duration submitDelay;
  String relation = 'registered_holder';

  @override
  Future<Map<String, dynamic>> call(
    String command,
    Map<String, Object?> payload,
  ) async {
    calls.add(_GatewayCall(command, payload));
    if (command == 'createVerificationSessionV1') {
      relation = payload['relation']!.toString();
      return {
        'sessionId': 'session-1',
        'nonce': List.filled(40, 'n').join(),
        'expiresAt': '2026-08-30T12:15:00.000Z',
        'state': 'created',
      };
    }
    if (command == 'submitVerificationDataV1') {
      if (submitDelay > Duration.zero) await Future<void>.delayed(submitDelay);
      if (submitError != null) throw submitError!;
      return {
        'status': relation == 'registered_holder'
            ? 'verified'
            : 'requires_declaration',
        'holderMatch': relation == 'registered_holder',
      };
    }
    if (command == 'finalizeVehicleDeclarationV1') {
      return {
        'status': 'verified',
        'holderMatch': false,
        'declarationId': 'declaration-1',
      };
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
