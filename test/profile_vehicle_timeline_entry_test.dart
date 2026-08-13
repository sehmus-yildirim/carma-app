import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_timeline_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final entry = ProfileVehicleTimelineEntry(
    id: 'entry-1',
    ownerUserId: 'user-1',
    vehicleId: 'vehicle-1',
    type: ProfileVehicleTimelineType.maintenance,
    title: 'Ölwechsel',
    description: 'Wartung bei 80.000 km',
    eventDate: DateTime(2026, 7, 12),
    mediaUrls: const ['https://example.com/service.jpg'],
    visibility: ProfileVehicleVisibility.contacts,
  );

  test('freigegebener Timeline-Eintrag ist öffentlich sichtbar', () {
    expect(entry.isPubliclyVisible, isTrue);
    expect(
      entry
          .copyWith(visibility: ProfileVehicleVisibility.onlyMe)
          .isPubliclyVisible,
      isFalse,
    );
    expect(entry.copyWith(isDeleted: true).isPubliclyVisible, isFalse);
  });

  test('öffentliche Projektion behält typisierte Ereignisdaten', () {
    final data = entry.toPublicFirestore();

    expect(data['type'], 'maintenance');
    expect(data['title'], 'Ölwechsel');
    expect(data['visibility'], 'contacts');
    expect(data['isDeleted'], isFalse);
  });

  test('automatische Einträge werden stabil rekonstruiert', () {
    final restored = ProfileVehicleTimelineEntry.fromMap(
      id: 'vehicle_created',
      data: {
        ...entry.toPrivateFirestore(),
        'type': 'vehicleCreated',
        'isAutomaticallyCreated': true,
      },
    );

    expect(restored.type, ProfileVehicleTimelineType.vehicleCreated);
    expect(restored.isAutomaticallyCreated, isTrue);
  });
}
