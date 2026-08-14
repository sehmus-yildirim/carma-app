import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/data/profile_repository.dart';
import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_repository.dart';
import 'package:plaqa/features/profile/data/profile_verification_repository.dart';
import 'package:plaqa/features/profile/data/profile_verification_request.dart';
import 'package:plaqa/features/profile/data/user_profile.dart';
import 'package:plaqa/features/profile/presentation/profile_verification_screen.dart';

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
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required UserProfile? profile,
  required List<ProfileVehicle> vehicles,
  required ProfileVerificationRequest? request,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 5000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: ProfileVerificationScreen(
        userId: 'user-1',
        profileRepository: _FakeProfileRepository(profile),
        vehicleRepository: _FakeVehicleRepository(vehicles),
        verificationRepository: _FakeVerificationRepository(request),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
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
  _FakeVerificationRepository(this.request);

  final ProfileVerificationRequest? request;

  @override
  Stream<ProfileVerificationRequest?> watchCurrentRequest(String userId) {
    return Stream.value(request);
  }

  @override
  Stream<List<ProfileVerificationHistoryEntry>> watchHistory(String userId) {
    return Stream.value(const []);
  }

  @override
  Stream<List<ProfileVerificationNotification>> watchNotifications(
    String userId,
  ) {
    return Stream.value(const []);
  }
}
