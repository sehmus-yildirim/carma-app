import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_repository.dart';
import 'package:plaqa/features/settings/presentation/profile_verification_settings_screen.dart';
import 'package:plaqa/shared/models/carisma_models.dart';

void main() {
  testWidgets('shows a clear empty vehicle state', (tester) async {
    final repository = _FakeVehicleRepository(const []);
    await tester.pumpWidget(_app(repository));
    await tester.pump();

    expect(find.text('Fahrzeuge & Kennzeichen'), findsOneWidget);
    expect(find.text('Fahrzeug hinzufügen'), findsOneWidget);
    expect(
      find.textContaining('Noch kein Fahrzeug hinterlegt'),
      findsOneWidget,
    );
  });

  testWidgets('shows primary, verification and visibility states', (
    tester,
  ) async {
    final repository = _FakeVehicleRepository([
      _vehicle(
        isPrimary: true,
        verificationStatus: ProfileVehicleVerificationStatus.inReview,
      ),
    ]);
    await tester.pumpWidget(_app(repository));
    await tester.pump();

    expect(find.text('BMW X6'), findsOneWidget);
    expect(find.text('HH-CR 2026'), findsOneWidget);
    expect(find.textContaining('In Prüfung'), findsOneWidget);
    expect(find.text('Öffentlich sichtbar'), findsOneWidget);
    expect(find.text('Hauptfahrzeug'), findsOneWidget);
  });

  testWidgets('explains soft-delete effects before removing a vehicle', (
    tester,
  ) async {
    final repository = _FakeVehicleRepository([_vehicle(isPrimary: false)]);
    await tester.pumpWidget(_app(repository));
    await tester.pump();

    await tester.tap(find.byTooltip('Fahrzeug verwalten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fahrzeug entfernen'));
    await tester.pumpAndSettle();

    expect(find.text('Fahrzeug entfernen?'), findsOneWidget);
    expect(find.textContaining('neuen Storys und Anfragen'), findsOneWidget);
    expect(
      find.textContaining('Bestehende Chats bleiben erhalten'),
      findsOneWidget,
    );
  });
}

Widget _app(ProfileVehicleRepository repository) {
  return MaterialApp(
    home: ProfileVerificationSettingsScreen(
      userState: AppUserState.localRegistered(userId: 'user-a'),
      area: ProfileSettingsArea.vehicles,
      vehicleRepository: repository,
    ),
  );
}

ProfileVehicle _vehicle({
  required bool isPrimary,
  ProfileVehicleVerificationStatus verificationStatus =
      ProfileVehicleVerificationStatus.evidenceMissing,
}) {
  return ProfileVehicle(
    id: 'vehicle-a',
    ownerUserId: 'user-a',
    brand: 'BMW',
    model: 'X6',
    color: 'Schwarz',
    countryCode: 'DE',
    plateRegion: 'HH',
    plateLetters: 'CR',
    plateNumbers: '2026',
    isPrimary: isPrimary,
    verificationStatus: verificationStatus,
    showOnPublicProfile: true,
    visibility: ProfileVehicleVisibility.contacts,
  );
}

class _FakeVehicleRepository extends ProfileVehicleRepository {
  _FakeVehicleRepository(this.vehicles);

  final List<ProfileVehicle> vehicles;

  @override
  Stream<List<ProfileVehicle>> watchOwnerVehicles(String userId) {
    return Stream.value(vehicles);
  }

  @override
  Future<void> archiveVehicle({
    required String userId,
    required String vehicleId,
  }) async {}
}
