import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import 'profile_vehicle_encounter.dart';

class ProfileVehicleEncounterException implements Exception {
  const ProfileVehicleEncounterException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileVehicleEncounterRepository {
  ProfileVehicleEncounterRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _encounters =>
      _firestore.collection(CaRismaFirestoreCollections.vehicleEncounters);

  String encounterIdFor({
    required String firstUserId,
    required String firstVehicleId,
    required String secondUserId,
    required String secondVehicleId,
  }) {
    final endpoints = <String>[
      '${firstUserId.trim()}_${firstVehicleId.trim()}',
      '${secondUserId.trim()}_${secondVehicleId.trim()}',
    ]..sort();
    if (endpoints.any((value) => value.replaceAll('_', '').isEmpty) ||
        endpoints[0] == endpoints[1]) {
      throw ArgumentError('Die Begegnungszuordnung ist ungültig.');
    }
    return '${endpoints[0]}__${endpoints[1]}';
  }

  Stream<List<ProfileVehicleEncounter>> watchOwnerEncounters({
    required String userId,
    required String vehicleId,
  }) {
    if (userId.trim().isEmpty || vehicleId.trim().isEmpty) {
      return Stream.value(const <ProfileVehicleEncounter>[]);
    }
    return _encounters
        .where('participantUserIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final encounters = snapshot.docs
              .map(
                (document) => ProfileVehicleEncounter.fromMap(
                  id: document.id,
                  data: document.data(),
                ),
              )
              .where(
                (encounter) =>
                    encounter.status ==
                        ProfileVehicleEncounterStatus.requested ||
                    encounter.status == ProfileVehicleEncounterStatus.confirmed,
              )
              .where(
                (encounter) =>
                    (encounter.initiatorUserId == userId &&
                        encounter.initiatorVehicleId == vehicleId) ||
                    (encounter.recipientUserId == userId &&
                        encounter.recipientVehicleId == vehicleId),
              )
              .toList();
          encounters.sort(
            (left, right) => right.encounterDate.compareTo(left.encounterDate),
          );
          return encounters;
        });
  }

  Stream<List<ProfileVehicleEncounter>> watchVisibleEncounters({
    required String userId,
    required String vehicleId,
  }) {
    return _firestore
        .collection(
          CaRismaFirestorePaths.publicVehicleEncounters(userId, vehicleId),
        )
        .snapshots()
        .map((snapshot) {
          final encounters = snapshot.docs
              .map(
                (document) => ProfileVehicleEncounter.fromMap(
                  id: document.id,
                  data: document.data(),
                ),
              )
              .where((encounter) => encounter.isConfirmed)
              .toList();
          encounters.sort(
            (left, right) => right.encounterDate.compareTo(left.encounterDate),
          );
          return encounters;
        });
  }

  Future<void> createRequest(ProfileVehicleEncounter encounter) async {
    if (encounter.initiatorUserId == encounter.recipientUserId ||
        encounter.initiatorVehicleId.trim().isEmpty ||
        encounter.recipientVehicleId.trim().isEmpty) {
      throw const ProfileVehicleEncounterException(
        'Diese Begegnung kann nicht angefragt werden.',
      );
    }
    final reference = _encounters.doc(encounter.id);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) {
        final current = ProfileVehicleEncounter.fromMap(
          id: existing.id,
          data: existing.data() ?? const <String, dynamic>{},
        );
        if (current.status == ProfileVehicleEncounterStatus.requested) {
          throw const ProfileVehicleEncounterException(
            'Für diese Fahrzeuge besteht bereits eine Anfrage.',
          );
        }
        if (current.status == ProfileVehicleEncounterStatus.confirmed) {
          throw const ProfileVehicleEncounterException(
            'Diese Begegnung wurde bereits bestätigt.',
          );
        }
        throw const ProfileVehicleEncounterException(
          'Diese Begegnungsanfrage wurde bereits abgeschlossen.',
        );
      }
      transaction.set(reference, {
        ...encounter.toFirestore(),
        'status': ProfileVehicleEncounterStatus.requested.name,
        'confirmedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> accept(ProfileVehicleEncounter encounter) async {
    final confirmed = encounter.copyWith(
      status: ProfileVehicleEncounterStatus.confirmed,
      confirmedAt: DateTime.now(),
    );
    final batch = _firestore.batch();
    batch.update(_encounters.doc(encounter.id), {
      'status': ProfileVehicleEncounterStatus.confirmed.name,
      'confirmedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final publicData = <String, Object?>{
      ...confirmed.toFirestore(),
      'status': ProfileVehicleEncounterStatus.confirmed.name,
      'confirmedAt': FieldValue.serverTimestamp(),
      'createdAt': encounter.createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(encounter.createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(
      _firestore.doc(
        CaRismaFirestorePaths.publicVehicleEncounter(
          encounter.initiatorUserId,
          encounter.initiatorVehicleId,
          encounter.id,
        ),
      ),
      publicData,
    );
    batch.set(
      _firestore.doc(
        CaRismaFirestorePaths.publicVehicleEncounter(
          encounter.recipientUserId,
          encounter.recipientVehicleId,
          encounter.id,
        ),
      ),
      publicData,
    );
    await batch.commit();
  }

  Future<void> decline(ProfileVehicleEncounter encounter) {
    return _encounters.doc(encounter.id).update({
      'status': ProfileVehicleEncounterStatus.declined.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(ProfileVehicleEncounter encounter) async {
    final batch = _firestore.batch();
    batch.update(_encounters.doc(encounter.id), {
      'status': ProfileVehicleEncounterStatus.removed.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(
      _firestore.doc(
        CaRismaFirestorePaths.publicVehicleEncounter(
          encounter.initiatorUserId,
          encounter.initiatorVehicleId,
          encounter.id,
        ),
      ),
    );
    batch.delete(
      _firestore.doc(
        CaRismaFirestorePaths.publicVehicleEncounter(
          encounter.recipientUserId,
          encounter.recipientVehicleId,
          encounter.id,
        ),
      ),
    );
    await batch.commit();
  }
}
