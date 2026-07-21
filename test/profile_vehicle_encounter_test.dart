import 'package:carisma/features/profile/data/profile_vehicle_encounter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final encounter = ProfileVehicleEncounter(
    id: 'user-a_vehicle-a__user-b_vehicle-b',
    initiatorUserId: 'user-a',
    recipientUserId: 'user-b',
    initiatorVehicleId: 'vehicle-a',
    recipientVehicleId: 'vehicle-b',
    initiatorVehicleLabel: 'BMW X6',
    recipientVehicleLabel: 'Mercedes GLE',
    participantUserIds: const ['user-a', 'user-b'],
    type: ProfileVehicleEncounterType.meet,
    status: ProfileVehicleEncounterStatus.requested,
    encounterDate: DateTime(2026, 7, 12),
  );

  test('Anfrage unterscheidet Eingang und Ausgang korrekt', () {
    expect(encounter.isOutgoingFor('user-a'), isTrue);
    expect(encounter.isIncomingFor('user-b'), isTrue);
    expect(encounter.isIncomingFor('user-a'), isFalse);
  });

  test('Gegenfahrzeug wird aus Sicht des Nutzers bestimmt', () {
    expect(encounter.otherVehicleLabel('user-a'), 'Mercedes GLE');
    expect(encounter.otherVehicleLabel('user-b'), 'BMW X6');
  });

  test('Bestätigung wird typisiert gespeichert und geladen', () {
    final confirmed = encounter.copyWith(
      status: ProfileVehicleEncounterStatus.confirmed,
      confirmedAt: DateTime(2026, 7, 13),
    );
    final restored = ProfileVehicleEncounter.fromMap(
      id: confirmed.id,
      data: confirmed.toFirestore(),
    );

    expect(restored.isConfirmed, isTrue);
    expect(restored.type, ProfileVehicleEncounterType.meet);
    expect(restored.participantUserIds, containsAll(['user-a', 'user-b']));
  });
}
