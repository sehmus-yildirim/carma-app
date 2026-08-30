import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_repository.dart';

void main() {
  group('ProfileVehicleRepository commands', () {
    late _RecordingVehicleGateway gateway;
    late ProfileVehicleRepository repository;

    setUp(() {
      gateway = _RecordingVehicleGateway();
      repository = ProfileVehicleRepository(commandGateway: gateway);
    });

    test('sends a normalized complete vehicle payload', () async {
      await repository.saveVehicle(_vehicle());

      expect(gateway.calls, hasLength(1));
      final call = gateway.calls.single;
      expect(call.command, 'saveProfileVehicle');
      final expectedPayload = <String, dynamic>{
        'vehicleId': 'vehicle-1',
        'brand': 'BMW',
        'model': 'X6',
        'series': 'G06',
        'color': 'Schwarz',
        'countryCode': 'DE',
        'plateRegion': 'HH',
        'plateLetters': 'SY',
        'plateNumbers': '4700',
        'isPrimary': true,
        'status': 'active',
        'useRelationship': 'leasingCompany',
        'vehicleType': 'passengerCar',
        'plateType': 'seasonal',
        'seasonStartMonth': 4,
        'seasonEndMonth': 10,
        'showOnPublicProfile': true,
        'discoverableByPlate': true,
        'selectableInStories': false,
        'allowContactRequests': true,
        'plateDisplayMode': 'shortened',
        'year': 2024,
        'bodyStyle': 'SUV',
        'hsn': '0005',
        'tsn': 'ABC',
        'vin': 'WBA12345678901234',
        'mileage': 12000,
      };
      for (final entry in expectedPayload.entries) {
        expect(call.payload[entry.key], entry.value, reason: entry.key);
      }
    });

    test('uses stable commands for primary and deactivate actions', () async {
      await repository.setPrimaryVehicle(
        userId: 'user-1',
        vehicleId: ' vehicle-1 ',
      );
      await repository.archiveVehicle(
        userId: 'user-1',
        vehicleId: ' vehicle-1 ',
      );

      expect(gateway.calls, [
        const _GatewayCall(
          command: 'setPrimaryProfileVehicle',
          payload: {'vehicleId': 'vehicle-1'},
        ),
        const _GatewayCall(
          command: 'deactivateProfileVehicle',
          payload: {'vehicleId': 'vehicle-1'},
        ),
      ]);
    });

    test('rejects incomplete vehicles before calling the server', () async {
      final invalid = _vehicle().copyWith(plateNumbers: '');

      await expectLater(
        repository.saveVehicle(invalid),
        throwsA(
          isA<ProfileVehicleException>()
              .having((error) => error.code, 'code', 'invalid-argument')
              .having(
                (error) => error.message,
                'message',
                'Die Fahrzeugdaten sind nicht vollständig.',
              ),
        ),
      );
      expect(gateway.calls, isEmpty);
    });

    test('rejects a negative mileage before calling the server', () async {
      final invalid = _vehicle().copyWith(mileage: -1);

      await expectLater(
        repository.saveVehicle(invalid),
        throwsA(
          isA<ProfileVehicleException>().having(
            (error) => error.message,
            'message',
            'Der Kilometerstand darf nicht negativ sein.',
          ),
        ),
      );
      expect(gateway.calls, isEmpty);
    });

    test('maps transport failures to a stable German error', () async {
      gateway.error = StateError('network down');

      await expectLater(
        repository.saveVehicle(_vehicle()),
        throwsA(
          isA<ProfileVehicleException>()
              .having((error) => error.code, 'code', 'unavailable')
              .having(
                (error) => error.message,
                'message',
                'Die Fahrzeugdaten konnten gerade nicht gespeichert werden. Bitte versuche es erneut.',
              ),
        ),
      );
    });
  });

  test('uses the protected public label for shortened plates', () {
    final vehicle = ProfileVehicle.fromMap(
      id: 'public-vehicle',
      data: const {
        'ownerUserId': 'user-1',
        'brand': 'BMW',
        'model': 'X6',
        'color': 'Schwarz',
        'countryCode': 'DE',
        'plateDisplayMode': 'shortened',
        'plateDisplayLabel': 'HH S •••',
      },
    );

    expect(vehicle.publicDisplayPlate, 'HH S •••');
    expect(vehicle.plateRegion, isEmpty);
    expect(vehicle.plateLetters, isEmpty);
  });
}

ProfileVehicle _vehicle() {
  return const ProfileVehicle(
    id: ' vehicle-1 ',
    ownerUserId: 'user-1',
    brand: ' BMW ',
    model: ' X6 ',
    series: ' G06 ',
    color: ' Schwarz ',
    countryCode: 'de',
    plateRegion: 'hh',
    plateLetters: 'sy',
    plateNumbers: '4700',
    isPrimary: true,
    status: ProfileVehicleStatus.active,
    useRelationship: ProfileVehicleUseRelationship.leasingCompany,
    vehicleType: ProfileVehicleType.passengerCar,
    plateType: ProfilePlateType.seasonal,
    seasonStartMonth: 4,
    seasonEndMonth: 10,
    showOnPublicProfile: true,
    discoverableByPlate: true,
    selectableInStories: false,
    allowContactRequests: true,
    plateDisplayMode: ProfilePlateDisplayMode.shortened,
    year: 2024,
    bodyStyle: ' SUV ',
    hsn: ' 0005 ',
    tsn: ' abc ',
    vin: ' wba12345678901234 ',
    mileage: 12000,
  );
}

class _RecordingVehicleGateway implements ProfileVehicleCommandGateway {
  final List<_GatewayCall> calls = [];
  Object? error;

  @override
  Future<Map<String, dynamic>> call(
    String command,
    Map<String, Object?> payload,
  ) async {
    calls.add(_GatewayCall(command: command, payload: payload));
    final currentError = error;
    if (currentError != null) throw currentError;
    return const {'ok': true};
  }
}

class _GatewayCall {
  const _GatewayCall({required this.command, required this.payload});

  final String command;
  final Map<String, Object?> payload;

  @override
  bool operator ==(Object other) {
    return other is _GatewayCall &&
        other.command == command &&
        _mapsEqual(other.payload, payload);
  }

  @override
  int get hashCode =>
      Object.hash(command, Object.hashAllUnordered(payload.entries));
}

bool _mapsEqual(Map<String, Object?> left, Map<String, Object?> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
