import 'package:carisma/features/plate_search/data/plate_contact_reason.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlateContactReason', () {
    const vehicle = 'BMW X6';

    test('builds the four configured messages', () {
      expect(
        PlateContactReason.vehicleQuestion.messageFor(vehicleName: vehicle),
        'Hallo, ich habe eine Frage zu deinem BMW X6 und würde mich gerne kurz mit dir darüber austauschen.',
      );
      expect(
        PlateContactReason.compliment.messageFor(vehicleName: vehicle),
        'Hallo, dein BMW X6 ist mir positiv aufgefallen. Wirklich ein sehr schönes Auto.',
      );
      expect(
        PlateContactReason.meetAndDrive.messageFor(vehicleName: vehicle),
        'Hallo, ich wollte fragen, ob du Interesse an einem Fahrzeugtreffen oder einer gemeinsamen Ausfahrt hast.',
      );
      expect(
        PlateContactReason.getToKnow.messageFor(vehicleName: vehicle),
        'Hallo, du bist mir mit deinem BMW X6 aufgefallen und ich würde dich gerne kennenlernen.',
      );
    });

    test('uses a safe fallback when vehicle data is missing', () {
      expect(
        PlateContactReason.compliment.messageFor(vehicleName: ''),
        contains('dein Fahrzeug'),
      );
    });
  });
}
