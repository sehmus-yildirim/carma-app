import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_modification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const modification = ProfileVehicleModification(
    id: 'modification-1',
    ownerUserId: 'user-1',
    vehicleId: 'vehicle-1',
    title: 'Sportabgasanlage',
    category: ProfileVehicleModificationCategory.exhaust,
    manufacturer: 'Beispiel GmbH',
    product: 'Sport Line',
    description: 'Dezenter Umbau mit Eintragung.',
    workshop: 'Werkstatt Hamburg',
    costCents: 249900,
    powerChangeHp: 12,
    isRegistered: true,
    documentPaths: ['users/user-1/private/invoice.pdf'],
    visibility: ProfileVehicleVisibility.contacts,
  );

  test('private Projektion enthält interne Umbau-Daten', () {
    final data = modification.toPrivateFirestore();

    expect(data['workshop'], 'Werkstatt Hamburg');
    expect(data['costCents'], 249900);
    expect(data['documentPaths'], ['users/user-1/private/invoice.pdf']);
  });

  test('öffentliche Projektion entfernt private Umbau-Daten', () {
    final data = modification.toPublicFirestore();

    expect(data['title'], 'Sportabgasanlage');
    expect(data['visibility'], ProfileVehicleVisibility.contacts.name);
    expect(data.containsKey('workshop'), isFalse);
    expect(data.containsKey('costCents'), isFalse);
    expect(data.containsKey('documentPaths'), isFalse);
  });

  test('private und gelöschte Umbauten sind nicht öffentlich sichtbar', () {
    expect(
      modification
          .copyWith(visibility: ProfileVehicleVisibility.onlyMe)
          .isPubliclyVisible,
      isFalse,
    );
    expect(modification.copyWith(isDeleted: true).isPubliclyVisible, isFalse);
  });
}
