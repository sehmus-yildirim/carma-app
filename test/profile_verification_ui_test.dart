import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/data/profile_repository.dart';
import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_repository.dart';
import 'package:plaqa/features/profile/data/profile_verification_repository.dart';
import 'package:plaqa/features/profile/data/profile_verification_request.dart';
import 'package:plaqa/features/profile/data/user_profile.dart';
import 'package:plaqa/features/profile/presentation/profile_verification_screen.dart';
import 'package:plaqa/shared/theme/carisma_design_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows three evidence cards with front and back sides', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      profile: UserProfile.empty(uid: 'user-1', email: 'test@plaqa.de'),
      vehicles: const [],
      request: null,
    );

    expect(find.text('Nicht begonnen'), findsOneWidget);
    expect(find.text('0 von 6 Nachweisen vollständig'), findsOneWidget);
    expect(find.text('Persönliche Daten'), findsOneWidget);
    expect(find.text('Identität bestätigen'), findsOneWidget);
    expect(find.text('Führerschein'), findsOneWidget);
    expect(find.text('Fahrzeugbezug bestätigen'), findsOneWidget);
    expect(find.text('Vorderseite'), findsNWidgets(3));
    expect(find.text('Rückseite'), findsNWidgets(3));
    expect(find.text('Fahrzeugzuordnung'), findsOneWidget);
    expect(find.text('Ablaufdatum des Ausweises'), findsOneWidget);
    expect(find.text('Ablaufdatum des Führerscheins'), findsOneWidget);
    expect(find.text('UNBEDINGT LESEN!'), findsOneWidget);
    expect(find.text('Datenschutzübersicht'), findsOneWidget);
    expect(
      find.textContaining('Nur ausdrücklich berechtigte Prüfer'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Dokumentbilder und persönliche Dokumentangaben'),
      findsOneWidget,
    );
    expect(find.text('Löschstatus'), findsNothing);
    expect(find.text('Fehlt'), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows a locked in-review state without mutable upload actions', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      profile: _completeProfile,
      vehicles: const [_vehicle],
      request: _request(
        status: ProfileVerificationStatus.pending,
        documentStatus: ProfileVerificationDocumentStatus.inReview,
      ),
    );

    expect(find.text('In Prüfung'), findsWidgets);
    expect(find.text('6 von 6 Nachweisen vollständig'), findsOneWidget);
    expect(find.text('Prüfung läuft'), findsOneWidget);
    expect(find.text('Ersetzen'), findsNothing);
    expect(find.text('Entfernen'), findsNothing);
  });

  testWidgets('shows rejection reason and a clear resubmission action', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      profile: _completeProfile,
      vehicles: const [_vehicle],
      request: _request(
        status: ProfileVerificationStatus.rejected,
        documentStatus: ProfileVerificationDocumentStatus.rejected,
        reason: 'Das Dokument ist nicht vollständig lesbar.',
      ),
    );

    expect(find.text('Abgelehnt'), findsWidgets);
    expect(
      find.text('Das Dokument ist nicht vollständig lesbar.'),
      findsWidgets,
    );
    expect(find.text('Neu einreichen'), findsNWidgets(6));
    expect(find.text('Verifizierungsproblem melden'), findsOneWidget);
  });

  testWidgets('consent and expiration input survive interaction lifecycle', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      profile: _completeProfile,
      vehicles: const [_vehicle],
      request: null,
    );

    await tester.tap(
      find.byKey(const ValueKey('verification-consent-checkbox')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    final expiration = find.byKey(
      const ValueKey('verification-expiration-identity'),
    );
    await tester.tap(expiration);
    await tester.enterText(expiration, '31122035');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final field = tester.widget<TextField>(expiration);
    expect(field.controller?.text, '31.12.2035');
    expect(find.text('Muss aktuell gültig sein'), findsNWidgets(2));
    expect(find.text('Dokumente hochladen'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired document date is marked red and is not saved', (
    tester,
  ) async {
    final repository = await _pumpScreen(
      tester,
      profile: _completeProfile,
      vehicles: const [_vehicle],
      request: null,
    );

    final expiration = find.byKey(
      const ValueKey('verification-expiration-identity'),
    );
    await tester.enterText(expiration, '01012020');
    await tester.pump();

    const message = 'Dieses Dokument ist abgelaufen.';
    expect(find.text(message), findsOneWidget);
    final field = tester.widget<TextField>(expiration);
    expect(field.decoration?.errorText, message);
    expect(
      field.decoration?.errorBorder?.borderSide.color,
      CaRismaDesignTokens.danger,
    );

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(repository.expirationSaveCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy details precede consent and highlight legal review', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      profile: _completeProfile,
      vehicles: const [_vehicle],
      request: null,
    );

    final privacyAction = find.text('Datenschutz & Berechtigung ansehen');
    final consent = find.byKey(const ValueKey('verification-consent-checkbox'));
    expect(
      tester.getTopLeft(privacyAction).dy,
      lessThan(tester.getTopLeft(consent).dy),
    );

    await tester.tap(privacyAction);
    await tester.pumpAndSettle();
    final legalText = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.textSpan?.toPlainText().contains('rechtlichen Prüfung') ==
                true,
      ),
    );
    final rootSpan = legalText.textSpan! as TextSpan;
    final highlightedSpan = rootSpan.children!
        .whereType<TextSpan>()
        .singleWhere((span) => span.text == 'rechtlichen Prüfung');
    expect(highlightedSpan.style?.color, CaRismaDesignTokens.danger);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected identity type ignores stale request snapshots', (
    tester,
  ) async {
    final repository = await _pumpScreen(
      tester,
      profile: _completeProfile,
      vehicles: const [_vehicle],
      request: _request(
        status: ProfileVerificationStatus.draft,
        documentStatus: ProfileVerificationDocumentStatus.missing,
      ),
    );

    await tester.tap(find.text('Personalausweis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reisepass').hitTestable().last);
    await tester.pumpAndSettle();
    expect(
      _selectedIdentityDocumentType(tester),
      ProfileVerificationIdentityDocumentType.passport,
    );

    repository.emit(
      _request(
        status: ProfileVerificationStatus.draft,
        documentStatus: ProfileVerificationDocumentStatus.missing,
        identityDocumentType:
            ProfileVerificationIdentityDocumentType.identityCard,
      ),
    );
    await tester.pump();
    expect(
      _selectedIdentityDocumentType(tester),
      ProfileVerificationIdentityDocumentType.passport,
    );

    repository.emit(
      _request(
        status: ProfileVerificationStatus.draft,
        documentStatus: ProfileVerificationDocumentStatus.missing,
        identityDocumentType: ProfileVerificationIdentityDocumentType.passport,
      ),
    );
    await tester.pump();
    expect(
      _selectedIdentityDocumentType(tester),
      ProfileVerificationIdentityDocumentType.passport,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected identity type stays visible when draft save fails', (
    tester,
  ) async {
    final repository = await _pumpScreen(
      tester,
      profile: _completeProfile,
      vehicles: const [_vehicle],
      request: _request(
        status: ProfileVerificationStatus.draft,
        documentStatus: ProfileVerificationDocumentStatus.missing,
      ),
    );
    repository.failIdentityTypeSave = true;

    await tester.tap(find.text('Personalausweis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aufenthaltstitel').hitTestable().last);
    await tester.pumpAndSettle();

    expect(
      _selectedIdentityDocumentType(tester),
      ProfileVerificationIdentityDocumentType.residencePermit,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('document source opens immediately while type save is pending', (
    tester,
  ) async {
    final repository = await _pumpScreen(
      tester,
      profile: _completeProfile,
      vehicles: const [_vehicle],
      request: _request(
        status: ProfileVerificationStatus.draft,
        documentStatus: ProfileVerificationDocumentStatus.missing,
      ),
    );
    repository.failIdentityTypeSave = true;

    await tester.tap(find.text('Personalausweis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reisepass').hitTestable().last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auswählen').first);
    await tester.pumpAndSettle();

    expect(find.text('Kamera'), findsOneWidget);
    expect(find.text('Galerie'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load error never returns the form to a full-screen loader', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      profile: _completeProfile,
      vehicles: const [],
      request: null,
      requestStreamFails: true,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final expiration = find.byKey(
      const ValueKey('verification-expiration-identity'),
    );
    await tester.enterText(expiration, '31122035');
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('verification-consent-checkbox')),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Dokumente hochladen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing vehicle uses an information row without a checkbox', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      profile: _completeProfile,
      vehicles: const [],
      request: null,
    );

    expect(find.text('Bitte wähle zuerst ein Fahrzeug aus.'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('request updates keep the document list at its scroll position', (
    tester,
  ) async {
    final repository = await _pumpScreen(
      tester,
      profile: _completeProfile,
      vehicles: const [_vehicle],
      request: null,
      surfaceSize: const Size(430, 850),
    );
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -1800));
    await tester.pump();
    final controller = tester.widget<ListView>(list).controller!;
    final offsetBefore = controller.offset;
    expect(offsetBefore, greaterThan(0));

    repository.emit(
      _request(
        status: ProfileVerificationStatus.draft,
        documentStatus: ProfileVerificationDocumentStatus.missing,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(controller.offset, closeTo(offsetBefore, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows submission, review and resubmission history clearly', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      profile: _completeProfile,
      vehicles: const [_vehicle],
      request: _request(
        status: ProfileVerificationStatus.rejected,
        documentStatus: ProfileVerificationDocumentStatus.rejected,
      ),
      history: [
        ProfileVerificationHistoryEntry(
          id: 'submitted',
          status: ProfileVerificationStatus.pending,
          eventType: 'submitted',
          documentGroups: const ['identity', 'driverLicense', 'vehicle'],
          createdAt: DateTime.utc(2026, 8, 10),
        ),
        ProfileVerificationHistoryEntry(
          id: 'reviewed',
          status: ProfileVerificationStatus.verified,
          eventType: 'reviewed',
          validUntil: DateTime.utc(2030, 8, 10),
          createdAt: DateTime.utc(2026, 8, 11),
        ),
        ProfileVerificationHistoryEntry(
          id: 'recheck',
          status: ProfileVerificationStatus.expired,
          eventType: 'resubmissionRequested',
          documentGroups: const ['identity'],
          createdAt: DateTime.utc(2030, 7, 11),
        ),
      ],
    );

    expect(find.text('Verifizierungsverlauf'), findsOneWidget);
    expect(find.text('Zur Prüfung eingereicht'), findsOneWidget);
    expect(find.text('Prüfung abgeschlossen'), findsOneWidget);
    expect(find.text('Erneute Prüfung angefordert'), findsOneWidget);
    expect(find.textContaining('Eingereicht am'), findsOneWidget);
    expect(find.textContaining('Geprüft am'), findsOneWidget);
    expect(find.textContaining('Angefordert am'), findsOneWidget);
    expect(find.textContaining('Gültig bis'), findsOneWidget);
  });
}

ProfileVerificationIdentityDocumentType? _selectedIdentityDocumentType(
  WidgetTester tester,
) {
  final finder = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButton<ProfileVerificationIdentityDocumentType>,
  );
  return tester
      .widget<DropdownButton<ProfileVerificationIdentityDocumentType>>(finder)
      .value;
}

Future<_FakeVerificationRepository> _pumpScreen(
  WidgetTester tester, {
  required UserProfile? profile,
  required List<ProfileVehicle> vehicles,
  required ProfileVerificationRequest? request,
  List<ProfileVerificationHistoryEntry> history = const [],
  Size surfaceSize = const Size(430, 5000),
  bool requestStreamFails = false,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final verificationRepository = _FakeVerificationRepository(
    request,
    history,
    requestStreamFails: requestStreamFails,
  );
  addTearDown(verificationRepository.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: ProfileVerificationScreen(
        userId: 'user-1',
        profileRepository: _FakeProfileRepository(profile),
        vehicleRepository: _FakeVehicleRepository(vehicles),
        verificationRepository: verificationRepository,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return verificationRepository;
}

final _completeProfile = UserProfile(
  uid: 'user-1',
  email: 'test@plaqa.de',
  firstName: 'Sehmus',
  lastName: 'Yildirim',
  displayName: 'Sehmus Y.',
  country: 'Deutschland',
  birthDate: DateTime.utc(1990, 1, 1, 12),
  personalDataLocked: true,
);

const _vehicle = ProfileVehicle(
  id: 'vehicle-1',
  ownerUserId: 'user-1',
  brand: 'BMW',
  model: 'X6',
  color: 'Schwarz',
  countryCode: 'DE',
  plateRegion: 'HH',
  plateLetters: 'SY',
  plateNumbers: '4700',
  isPrimary: true,
);

ProfileVerificationRequest _request({
  required ProfileVerificationStatus status,
  required ProfileVerificationDocumentStatus documentStatus,
  String? reason,
  ProfileVerificationIdentityDocumentType identityDocumentType =
      ProfileVerificationIdentityDocumentType.identityCard,
}) {
  return ProfileVerificationRequest(
    requestId: 'user-1',
    userId: 'user-1',
    profilePath: 'users/user-1/profiles/main',
    status: status,
    displayName: 'Sehmus Y.',
    documentStoragePaths: {
      for (final key in ProfileVerificationDocumentKeys.required)
        key: 'profile_documents/user-1/$key/$key.png',
    },
    documentStatuses: {
      for (final key in ProfileVerificationDocumentKeys.required)
        key: documentStatus,
    },
    documentRejectionReasons: reason == null
        ? const {}
        : {
            for (final key in ProfileVerificationDocumentKeys.required)
              key: reason,
          },
    vehicleId: 'vehicle-1',
    vehicleRelationship: ProfileVehicleRelationship.owner,
    authorizationConfirmed: true,
    rejectionReason: reason,
    identityDocumentType: identityDocumentType,
  );
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(this.profile);

  final UserProfile? profile;

  @override
  Stream<UserProfile?> watchProfile(String uid) => Stream.value(profile);
}

class _FakeVehicleRepository extends ProfileVehicleRepository {
  _FakeVehicleRepository(this.vehicles);

  final List<ProfileVehicle> vehicles;

  @override
  Stream<List<ProfileVehicle>> watchOwnerVehicles(String userId) {
    return Stream.value(vehicles);
  }
}

class _FakeVerificationRepository extends ProfileVerificationRepository {
  _FakeVerificationRepository(
    this.request,
    this.history, {
    this.requestStreamFails = false,
  });

  final ProfileVerificationRequest? request;
  final List<ProfileVerificationHistoryEntry> history;
  final bool requestStreamFails;
  bool failIdentityTypeSave = false;
  int expirationSaveCount = 0;
  final StreamController<ProfileVerificationRequest?> _requestController =
      StreamController<ProfileVerificationRequest?>.broadcast();

  @override
  Stream<ProfileVerificationRequest?> watchCurrentRequest(String userId) {
    if (requestStreamFails) {
      return Stream.error(
        const ProfileVerificationException(
          'Der Verifizierungsstatus konnte nicht geladen werden.',
        ),
      );
    }
    return (() async* {
      yield request;
      yield* _requestController.stream;
    })();
  }

  void emit(ProfileVerificationRequest? next) => _requestController.add(next);

  Future<void> dispose() => _requestController.close();

  @override
  Stream<List<ProfileVerificationHistoryEntry>> watchHistory(String userId) {
    return Stream.value(history);
  }

  @override
  Stream<List<ProfileVerificationNotification>> watchNotifications(
    String userId,
  ) {
    return Stream.value(const []);
  }

  @override
  Future<void> saveDraftConfirmations({
    required String userId,
    required bool authorizationConfirmed,
    required bool vehicleAssignmentConfirmed,
  }) async {}

  @override
  Future<void> saveDraftExpiration({
    required String userId,
    required String expirationKey,
    required DateTime expiresAt,
  }) async {
    expirationSaveCount += 1;
  }

  @override
  Future<void> saveDraftIdentityDocumentType({
    required String userId,
    required ProfileVerificationIdentityDocumentType identityDocumentType,
  }) async {
    if (failIdentityTypeSave) {
      throw const ProfileVerificationException(
        'Der Dokumenttyp konnte nicht gespeichert werden.',
      );
    }
  }
}
