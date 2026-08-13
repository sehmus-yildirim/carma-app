import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseVehicle = ProfileVehicle(
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

  test('formatiert Fahrzeug und Kennzeichen stabil', () {
    expect(baseVehicle.displayName, 'BMW X6');
    expect(baseVehicle.displayPlate, 'HH-SY 4700');
    expect(baseVehicle.hasRequiredData, isTrue);
  });

  test('verbirgt Kennzeichenteile in öffentlicher Projektion', () {
    final publicData = baseVehicle.toPublicFirestore();

    expect(publicData['countryCode'], 'DE');
    expect(publicData['plateRegion'], isNull);
    expect(publicData['plateLetters'], isNull);
    expect(publicData['plateNumbers'], isNull);
  });

  test('kopiert keine privaten Fahrzeugkennungen ins öffentliche Profil', () {
    final vehicle = ProfileVehicle(
      id: baseVehicle.id,
      ownerUserId: baseVehicle.ownerUserId,
      brand: baseVehicle.brand,
      model: baseVehicle.model,
      color: baseVehicle.color,
      countryCode: baseVehicle.countryCode,
      plateRegion: baseVehicle.plateRegion,
      plateLetters: baseVehicle.plateLetters,
      plateNumbers: baseVehicle.plateNumbers,
      equipment: const ['Panorama', 'Sitzheizung'],
      hsn: '0005',
      tsn: 'ABC',
      vin: 'WBA12345678901234',
    );

    final privateData = vehicle.toPrivateFirestore();
    final publicData = vehicle.toPublicFirestore();

    expect(privateData['hsn'], '0005');
    expect(privateData['tsn'], 'ABC');
    expect(privateData['vin'], 'WBA12345678901234');
    expect(publicData.containsKey('hsn'), isFalse);
    expect(publicData.containsKey('tsn'), isFalse);
    expect(publicData.containsKey('vin'), isFalse);
    expect(publicData['equipment'], ['Panorama', 'Sitzheizung']);
  });

  test('archivierte Fahrzeuge sind nicht öffentlich sichtbar', () {
    final archived = baseVehicle.copyWith(
      status: ProfileVehicleStatus.archived,
    );

    expect(archived.isArchived, isTrue);
    expect(archived.isPubliclyVisible, isFalse);
  });

  test('übernimmt bestehendes Profil als primäres Legacy-Fahrzeug', () {
    const profile = UserProfile(
      uid: 'user-1',
      email: 'test@example.com',
      firstName: 'Sehmus',
      lastName: 'Yildirim',
      displayName: 'Sehmus Y.',
      country: 'Deutschland',
      countryCode: 'DE',
      plateRegion: 'HH',
      plateLetters: 'SY',
      plateNumbers: '4700',
      vehicleBrand: 'BMW',
      vehicleModel: 'X6',
      vehicleColor: 'Schwarz',
      showVehicleOnPublicProfile: true,
      showPlateOnPublicProfile: true,
    );

    final vehicle = ProfileVehicle.fromLegacyProfile(profile);

    expect(vehicle.id, 'legacy_primary');
    expect(vehicle.isPrimary, isTrue);
    expect(vehicle.visibility, ProfileVehicleVisibility.contacts);
    expect(vehicle.showPlate, isTrue);
  });
}
