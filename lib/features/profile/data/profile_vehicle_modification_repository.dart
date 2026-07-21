import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import 'profile_vehicle_modification.dart';
import 'profile_vehicle_timeline_entry.dart';

class ProfileVehicleModificationRepository {
  ProfileVehicleModificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _privateCollection(
    String userId,
    String vehicleId,
  ) {
    return _firestore.collection(
      CaRismaFirestorePaths.userVehicleModifications(userId, vehicleId),
    );
  }

  CollectionReference<Map<String, dynamic>> _publicCollection(
    String userId,
    String vehicleId,
  ) {
    return _firestore.collection(
      CaRismaFirestorePaths.publicVehicleModifications(userId, vehicleId),
    );
  }

  DocumentReference<Map<String, dynamic>> _privateDocument(
    String userId,
    String vehicleId,
    String modificationId,
  ) {
    return _firestore.doc(
      CaRismaFirestorePaths.userVehicleModification(
        userId,
        vehicleId,
        modificationId,
      ),
    );
  }

  DocumentReference<Map<String, dynamic>> _publicDocument(
    String userId,
    String vehicleId,
    String modificationId,
  ) {
    return _firestore.doc(
      CaRismaFirestorePaths.publicVehicleModification(
        userId,
        vehicleId,
        modificationId,
      ),
    );
  }

  String createModificationId({
    required String userId,
    required String vehicleId,
  }) {
    return _privateCollection(userId, vehicleId).doc().id;
  }

  Stream<List<ProfileVehicleModification>> watchOwnerModifications({
    required String userId,
    required String vehicleId,
  }) {
    return _privateCollection(
      userId,
      vehicleId,
    ).snapshots().map(_modificationsFromSnapshot);
  }

  Stream<List<ProfileVehicleModification>> watchVisibleModifications({
    required String userId,
    required String vehicleId,
  }) {
    return _publicCollection(
      userId,
      vehicleId,
    ).snapshots().map(_modificationsFromSnapshot);
  }

  Future<void> saveModification(ProfileVehicleModification modification) async {
    final userId = modification.ownerUserId.trim();
    final vehicleId = modification.vehicleId.trim();
    final modificationId = modification.id.trim();
    if (userId.isEmpty || vehicleId.isEmpty || modificationId.isEmpty) {
      throw ArgumentError('Die Umbau-Zuordnung ist unvollständig.');
    }
    if (modification.title.trim().isEmpty) {
      throw ArgumentError('Bitte gib einen Titel für den Umbau ein.');
    }
    if (modification.costCents != null && modification.costCents! < 0) {
      throw ArgumentError('Die Kosten dürfen nicht negativ sein.');
    }

    final privateReference = _privateDocument(
      userId,
      vehicleId,
      modificationId,
    );
    final publicReference = _publicDocument(userId, vehicleId, modificationId);
    final vehicleSnapshot = await _firestore
        .doc(CaRismaFirestorePaths.userVehicle(userId, vehicleId))
        .get();
    if (!vehicleSnapshot.exists) {
      throw StateError('Das zugehörige Fahrzeug wurde nicht gefunden.');
    }
    final vehicleData = vehicleSnapshot.data() ?? <String, dynamic>{};
    final vehicleCanBePublic =
        vehicleData['visibility'] == 'contacts' &&
        vehicleData['status'] != 'archived';
    final existing = await privateReference.get();
    final createdAt = existing.data()?['createdAt'];
    final batch = _firestore.batch();
    batch.set(privateReference, {
      ...modification.toPrivateFirestore(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (modification.isPubliclyVisible && vehicleCanBePublic) {
      batch.set(publicReference, {
        ...modification.toPublicFirestore(),
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      batch.delete(publicReference);
    }
    if (!existing.exists) {
      final timelineEntry = ProfileVehicleTimelineEntry(
        id: 'modification_$modificationId',
        ownerUserId: userId,
        vehicleId: vehicleId,
        type: ProfileVehicleTimelineType.modificationAdded,
        title: modification.title.trim(),
        description: modification.description,
        eventDate: modification.modifiedAt ?? DateTime.now(),
        linkedModificationId: modificationId,
        isAutomaticallyCreated: true,
        visibility: modification.visibility,
      );
      batch.set(
        _firestore.doc(
          CaRismaFirestorePaths.userVehicleTimelineEntry(
            userId,
            vehicleId,
            timelineEntry.id,
          ),
        ),
        {
          ...timelineEntry.toPrivateFirestore(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      final publicTimelineReference = _firestore.doc(
        CaRismaFirestorePaths.publicVehicleTimelineEntry(
          userId,
          vehicleId,
          timelineEntry.id,
        ),
      );
      if (timelineEntry.isPubliclyVisible && vehicleCanBePublic) {
        batch.set(publicTimelineReference, {
          ...timelineEntry.toPublicFirestore(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        batch.delete(publicTimelineReference);
      }
    }
    await batch.commit();
  }

  Future<void> deleteModification(
    ProfileVehicleModification modification,
  ) async {
    final batch = _firestore.batch();
    batch.update(
      _privateDocument(
        modification.ownerUserId,
        modification.vehicleId,
        modification.id,
      ),
      {'isDeleted': true, 'updatedAt': FieldValue.serverTimestamp()},
    );
    batch.delete(
      _publicDocument(
        modification.ownerUserId,
        modification.vehicleId,
        modification.id,
      ),
    );
    await batch.commit();
  }

  List<ProfileVehicleModification> _modificationsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final modifications = snapshot.docs
        .map(
          (document) => ProfileVehicleModification.fromMap(
            id: document.id,
            data: document.data(),
          ),
        )
        .where((modification) => !modification.isDeleted)
        .toList();
    modifications.sort((left, right) {
      final leftDate =
          left.modifiedAt ??
          left.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          right.modifiedAt ??
          right.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });
    return modifications;
  }
}
