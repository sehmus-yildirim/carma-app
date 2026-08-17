import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import 'profile_vehicle.dart';
import 'user_profile.dart';

class ProfileVehicleException implements Exception {
  const ProfileVehicleException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

abstract interface class ProfileVehicleCommandGateway {
  Future<Map<String, dynamic>> call(
    String command,
    Map<String, Object?> payload,
  );
}

class FirebaseProfileVehicleCommandGateway
    implements ProfileVehicleCommandGateway {
  FirebaseProfileVehicleCommandGateway({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, dynamic>> call(
    String command,
    Map<String, Object?> payload,
  ) async {
    final result = await _functions.httpsCallable(command).call(payload);
    final data = result.data;
    return data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
  }
}

class ProfileVehicleRepository {
  ProfileVehicleRepository({
    FirebaseFirestore? firestore,
    ProfileVehicleCommandGateway? commandGateway,
  }) : _firestore = firestore,
       _commandGateway = commandGateway;

  final FirebaseFirestore? _firestore;
  final ProfileVehicleCommandGateway? _commandGateway;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;
  ProfileVehicleCommandGateway get _commands =>
      _commandGateway ?? FirebaseProfileVehicleCommandGateway();

  CollectionReference<Map<String, dynamic>> _privateVehicles(String userId) {
    return _database.collection(CaRismaFirestorePaths.userVehicles(userId));
  }

  CollectionReference<Map<String, dynamic>> _publicVehicles(String userId) {
    return _database.collection(
      CaRismaFirestorePaths.publicProfileVehicles(userId),
    );
  }

  DocumentReference<Map<String, dynamic>> _privateVehicle(
    String userId,
    String vehicleId,
  ) {
    return _database.doc(CaRismaFirestorePaths.userVehicle(userId, vehicleId));
  }

  String createVehicleId(String userId) {
    return _privateVehicles(userId).doc().id;
  }

  Stream<List<ProfileVehicle>> watchOwnerVehicles(String userId) {
    return _privateVehicles(userId).snapshots().map(_vehiclesFromSnapshot);
  }

  Stream<List<ProfileVehicle>> watchVisibleVehicles(String userId) {
    return _publicVehicles(userId).snapshots().map(_vehiclesFromSnapshot);
  }

  Future<ProfileVehicle?> getOwnerVehicle({
    required String userId,
    required String vehicleId,
  }) async {
    final snapshot = await _privateVehicle(userId, vehicleId).get();
    if (!snapshot.exists) return null;
    return ProfileVehicle.fromMap(id: snapshot.id, data: snapshot.data() ?? {});
  }

  Future<void> ensureLegacyPrimaryVehicle(UserProfile profile) async {
    if (profile.uid.trim().isEmpty) return;

    final existing = await _privateVehicles(profile.uid).limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final legacyVehicle = ProfileVehicle.fromLegacyProfile(profile);
    if (!legacyVehicle.hasRequiredData) return;
    await saveVehicle(legacyVehicle);
  }

  Future<void> saveVehicle(ProfileVehicle vehicle) async {
    final userId = vehicle.ownerUserId.trim();
    final vehicleId = vehicle.id.trim();
    if (userId.isEmpty || vehicleId.isEmpty || !vehicle.hasRequiredData) {
      throw const ProfileVehicleException(
        'Die Fahrzeugdaten sind nicht vollständig.',
        code: 'invalid-argument',
      );
    }
    if (vehicle.mileage != null && vehicle.mileage! < 0) {
      throw const ProfileVehicleException(
        'Der Kilometerstand darf nicht negativ sein.',
        code: 'invalid-argument',
      );
    }

    await _runCommand('saveProfileVehicle', vehicleCommandPayload(vehicle));
  }

  Future<void> setPrimaryVehicle({
    required String userId,
    required String vehicleId,
  }) async {
    await _runCommand('setPrimaryProfileVehicle', {
      'vehicleId': vehicleId.trim(),
    });
  }

  Future<void> archiveVehicle({
    required String userId,
    required String vehicleId,
  }) async {
    await _runCommand('deactivateProfileVehicle', {
      'vehicleId': vehicleId.trim(),
    });
  }

  Future<Map<String, dynamic>> _runCommand(
    String command,
    Map<String, Object?> payload,
  ) async {
    try {
      return await _commands.call(command, payload);
    } on FirebaseFunctionsException catch (error) {
      throw ProfileVehicleException(
        _messageForFunctionsError(error),
        code: error.code,
      );
    } on ProfileVehicleException {
      rethrow;
    } catch (_) {
      throw const ProfileVehicleException(
        'Die Fahrzeugdaten konnten gerade nicht gespeichert werden. Bitte versuche es erneut.',
        code: 'unavailable',
      );
    }
  }

  List<ProfileVehicle> _vehiclesFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final vehicles = snapshot.docs
        .map(
          (document) =>
              ProfileVehicle.fromMap(id: document.id, data: document.data()),
        )
        .toList();
    vehicles.sort((left, right) {
      if (left.isPrimary != right.isPrimary) return left.isPrimary ? -1 : 1;
      final leftUpdated =
          left.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightUpdated =
          right.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightUpdated.compareTo(leftUpdated);
    });
    return vehicles;
  }

  static Map<String, Object?> vehicleCommandPayload(ProfileVehicle vehicle) {
    return <String, Object?>{
      'vehicleId': vehicle.id.trim(),
      'brand': vehicle.brand.trim(),
      'model': vehicle.model.trim(),
      'series': _trimmedOrNull(vehicle.series),
      'color': vehicle.color.trim(),
      'countryCode': vehicle.countryCode.trim().toUpperCase(),
      'plateRegion': vehicle.plateRegion.trim().toUpperCase(),
      'plateLetters': vehicle.plateLetters.trim().toUpperCase(),
      'plateNumbers': vehicle.plateNumbers.trim().toUpperCase(),
      'isPrimary': vehicle.isPrimary,
      'status': vehicle.status.name,
      'useRelationship': vehicle.useRelationship.name,
      'vehicleType': vehicle.vehicleType.name,
      'plateType': vehicle.plateType.name,
      'seasonStartMonth': vehicle.seasonStartMonth,
      'seasonEndMonth': vehicle.seasonEndMonth,
      'showOnPublicProfile': vehicle.showOnPublicProfile,
      'discoverableByPlate': vehicle.discoverableByPlate,
      'selectableInStories': vehicle.selectableInStories,
      'allowContactRequests': vehicle.allowContactRequests,
      'plateDisplayMode': vehicle.plateDisplayMode.name,
      'year': vehicle.year,
      'firstRegistration': vehicle.firstRegistration?.millisecondsSinceEpoch,
      'bodyStyle': _trimmedOrNull(vehicle.bodyStyle),
      'engineDescription': _trimmedOrNull(vehicle.engineDescription),
      'displacementCcm': vehicle.displacementCcm,
      'horsepower': vehicle.horsepower,
      'kilowatts': vehicle.kilowatts,
      'fuelType': _trimmedOrNull(vehicle.fuelType),
      'transmission': _trimmedOrNull(vehicle.transmission),
      'drivetrain': _trimmedOrNull(vehicle.drivetrain),
      'equipment': vehicle.equipment,
      'ownedSince': vehicle.ownedSince?.millisecondsSinceEpoch,
      'mileage': vehicle.mileage,
      'profileHighlights': vehicle.profileHighlights
          .map((value) => value.name)
          .toList(growable: false),
    };
  }

  static String _messageForFunctionsError(FirebaseFunctionsException error) {
    final serverMessage = error.message?.trim();
    if (serverMessage != null &&
        serverMessage.isNotEmpty &&
        !serverMessage.toLowerCase().contains('firebase')) {
      return serverMessage;
    }
    return switch (error.code) {
      'already-exists' =>
        'Dieses Kennzeichen ist bereits einem aktiven Fahrzeug zugeordnet.',
      'failed-precondition' =>
        'Das Fahrzeug kann in seinem aktuellen Zustand nicht geändert werden.',
      'permission-denied' => 'Du darfst dieses Fahrzeug nicht ändern.',
      'unauthenticated' => 'Bitte melde dich neu an.',
      'not-found' => 'Das Fahrzeug wurde nicht gefunden.',
      'invalid-argument' => 'Bitte prüfe die Fahrzeug- und Kennzeichendaten.',
      _ =>
        'Die Fahrzeugdaten konnten gerade nicht gespeichert werden. Bitte versuche es erneut.',
    };
  }

  static String? _trimmedOrNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
