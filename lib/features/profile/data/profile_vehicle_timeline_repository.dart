import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import 'profile_vehicle.dart';
import 'profile_vehicle_timeline_entry.dart';

class ProfileVehicleTimelineRepository {
  ProfileVehicleTimelineRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _privateCollection(
    String userId,
    String vehicleId,
  ) => _firestore.collection(
    CaRismaFirestorePaths.userVehicleTimeline(userId, vehicleId),
  );

  CollectionReference<Map<String, dynamic>> _publicCollection(
    String userId,
    String vehicleId,
  ) => _firestore.collection(
    CaRismaFirestorePaths.publicVehicleTimeline(userId, vehicleId),
  );

  String createEntryId({required String userId, required String vehicleId}) {
    return _privateCollection(userId, vehicleId).doc().id;
  }

  Stream<List<ProfileVehicleTimelineEntry>> watchOwnerEntries({
    required String userId,
    required String vehicleId,
  }) => _privateCollection(
    userId,
    vehicleId,
  ).snapshots().map(_entriesFromSnapshot);

  Stream<List<ProfileVehicleTimelineEntry>> watchVisibleEntries({
    required String userId,
    required String vehicleId,
  }) => _publicCollection(
    userId,
    vehicleId,
  ).snapshots().map(_entriesFromSnapshot);

  Future<void> saveEntry(ProfileVehicleTimelineEntry entry) async {
    final userId = entry.ownerUserId.trim();
    final vehicleId = entry.vehicleId.trim();
    final entryId = entry.id.trim();
    if (userId.isEmpty || vehicleId.isEmpty || entryId.isEmpty) {
      throw ArgumentError('Die Timeline-Zuordnung ist unvollständig.');
    }
    if (entry.title.trim().isEmpty) {
      throw ArgumentError('Bitte gib einen Titel für das Ereignis ein.');
    }

    final privateReference = _privateCollection(userId, vehicleId).doc(entryId);
    final publicReference = _publicCollection(userId, vehicleId).doc(entryId);
    final vehicleSnapshot = await _firestore
        .doc(CaRismaFirestorePaths.userVehicle(userId, vehicleId))
        .get();
    if (!vehicleSnapshot.exists) {
      throw StateError('Das zugehörige Fahrzeug wurde nicht gefunden.');
    }
    final vehicleData = vehicleSnapshot.data() ?? <String, dynamic>{};
    final vehicleCanBePublic =
        vehicleData['visibility'] == ProfileVehicleVisibility.contacts.name &&
        vehicleData['status'] != ProfileVehicleStatus.archived.name;
    final existing = await privateReference.get();
    final createdAt = existing.data()?['createdAt'];
    final batch = _firestore.batch();
    batch.set(privateReference, {
      ...entry.toPrivateFirestore(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (entry.isPubliclyVisible && vehicleCanBePublic) {
      batch.set(publicReference, {
        ...entry.toPublicFirestore(),
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      batch.delete(publicReference);
    }
    await batch.commit();
  }

  Future<void> ensureAutomaticEntry({
    required String userId,
    required String vehicleId,
    required String entryId,
    required ProfileVehicleTimelineType type,
    required String title,
    required DateTime eventDate,
    String? description,
    String? linkedModificationId,
    ProfileVehicleVisibility visibility = ProfileVehicleVisibility.contacts,
  }) async {
    final reference = _privateCollection(userId, vehicleId).doc(entryId);
    final existing = await reference.get();
    if (existing.exists) return;
    await saveEntry(
      ProfileVehicleTimelineEntry(
        id: entryId,
        ownerUserId: userId,
        vehicleId: vehicleId,
        type: type,
        title: title,
        description: description,
        eventDate: eventDate,
        linkedModificationId: linkedModificationId,
        isAutomaticallyCreated: true,
        visibility: visibility,
      ),
    );
  }

  Future<void> deleteEntry(ProfileVehicleTimelineEntry entry) async {
    if (entry.isAutomaticallyCreated) {
      throw StateError(
        'Automatische Timeline-Einträge können nicht gelöscht werden.',
      );
    }
    final batch = _firestore.batch();
    batch.update(
      _privateCollection(entry.ownerUserId, entry.vehicleId).doc(entry.id),
      {'isDeleted': true, 'updatedAt': FieldValue.serverTimestamp()},
    );
    batch.delete(
      _publicCollection(entry.ownerUserId, entry.vehicleId).doc(entry.id),
    );
    await batch.commit();
  }

  List<ProfileVehicleTimelineEntry> _entriesFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final entries = snapshot.docs
        .map(
          (document) => ProfileVehicleTimelineEntry.fromMap(
            id: document.id,
            data: document.data(),
          ),
        )
        .where((entry) => !entry.isDeleted)
        .toList();
    entries.sort((left, right) => right.eventDate.compareTo(left.eventDate));
    return entries;
  }
}
