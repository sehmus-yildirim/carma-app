import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import 'plate_repository.dart';
import 'profile_vehicle.dart';
import 'profile_vehicle_timeline_entry.dart';
import 'user_profile.dart';

class ProfileVehicleRepository {
  ProfileVehicleRepository({
    FirebaseFirestore? firestore,
    PlateRepository? plateRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _plateRepository =
           plateRepository ??
           PlateRepository(firestore: firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final PlateRepository _plateRepository;

  CollectionReference<Map<String, dynamic>> _privateVehicles(String userId) {
    return _firestore.collection(CaRismaFirestorePaths.userVehicles(userId));
  }

  CollectionReference<Map<String, dynamic>> _publicVehicles(String userId) {
    return _firestore.collection(
      CaRismaFirestorePaths.publicProfileVehicles(userId),
    );
  }

  DocumentReference<Map<String, dynamic>> _privateVehicle(
    String userId,
    String vehicleId,
  ) {
    return _firestore.doc(CaRismaFirestorePaths.userVehicle(userId, vehicleId));
  }

  DocumentReference<Map<String, dynamic>> _publicVehicle(
    String userId,
    String vehicleId,
  ) {
    return _firestore.doc(
      CaRismaFirestorePaths.publicProfileVehicle(userId, vehicleId),
    );
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
      throw ArgumentError('Die Fahrzeugdaten sind nicht vollständig.');
    }
    if (vehicle.mileage != null && vehicle.mileage! < 0) {
      throw ArgumentError('Der Kilometerstand darf nicht negativ sein.');
    }

    final profileReference = _firestore.doc(
      CaRismaFirestorePaths.userProfile(userId),
    );
    final publicProfileReference = _firestore.doc(
      CaRismaFirestorePaths.publicProfile(userId),
    );
    final vehicleReference = _privateVehicle(userId, vehicleId);
    final publicVehicleReference = _publicVehicle(userId, vehicleId);
    final createdTimelineReference = _firestore.doc(
      CaRismaFirestorePaths.userVehicleTimelineEntry(
        userId,
        vehicleId,
        'vehicle_created',
      ),
    );
    final publicCreatedTimelineReference = _firestore.doc(
      CaRismaFirestorePaths.publicVehicleTimelineEntry(
        userId,
        vehicleId,
        'vehicle_created',
      ),
    );

    late ProfileVehicle savedVehicle;
    UserProfile? previousProfile;

    await _firestore.runTransaction((transaction) async {
      final profileSnapshot = await transaction.get(profileReference);
      if (!profileSnapshot.exists) {
        throw StateError('Das Profil muss vor dem Fahrzeug angelegt werden.');
      }

      previousProfile = UserProfile.fromFirestore(profileSnapshot);
      final profileData = profileSnapshot.data() ?? <String, dynamic>{};
      final currentPrimaryId =
          (profileData['primaryVehicleId'] as String?)?.trim() ?? '';
      final shouldBePrimary =
          vehicle.isPrimary ||
          currentPrimaryId.isEmpty ||
          currentPrimaryId == vehicleId;
      savedVehicle = vehicle.copyWith(isPrimary: shouldBePrimary);

      final currentVehicleSnapshot = await transaction.get(vehicleReference);
      final isNewVehicle = !currentVehicleSnapshot.exists;
      DocumentSnapshot<Map<String, dynamic>>? oldPrimarySnapshot;
      DocumentSnapshot<Map<String, dynamic>>? oldPublicPrimarySnapshot;
      if (shouldBePrimary &&
          currentPrimaryId.isNotEmpty &&
          currentPrimaryId != vehicleId) {
        oldPrimarySnapshot = await transaction.get(
          _privateVehicle(userId, currentPrimaryId),
        );
        oldPublicPrimarySnapshot = await transaction.get(
          _publicVehicle(userId, currentPrimaryId),
        );
      }

      final createdAtValue = currentVehicleSnapshot.exists
          ? (currentVehicleSnapshot.data()?['createdAt'] ??
                FieldValue.serverTimestamp())
          : FieldValue.serverTimestamp();
      final privateData = <String, Object?>{
        ...savedVehicle.toPrivateFirestore(),
        'createdAt': createdAtValue,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(vehicleReference, privateData, SetOptions(merge: true));

      if (savedVehicle.isPubliclyVisible) {
        transaction.set(publicVehicleReference, {
          ...savedVehicle.toPublicFirestore(),
          'createdAt': createdAtValue,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        transaction.delete(publicVehicleReference);
      }

      if (isNewVehicle) {
        final timelineEntry = ProfileVehicleTimelineEntry(
          id: 'vehicle_created',
          ownerUserId: userId,
          vehicleId: vehicleId,
          type: ProfileVehicleTimelineType.vehicleCreated,
          title: 'Fahrzeug hinzugefügt',
          description: savedVehicle.displayName,
          eventDate: DateTime.now(),
          isAutomaticallyCreated: true,
          visibility: savedVehicle.visibility,
        );
        transaction.set(createdTimelineReference, {
          ...timelineEntry.toPrivateFirestore(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (timelineEntry.isPubliclyVisible) {
          transaction.set(publicCreatedTimelineReference, {
            ...timelineEntry.toPublicFirestore(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (oldPrimarySnapshot?.exists == true) {
        transaction.update(oldPrimarySnapshot!.reference, {
          'isPrimary': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (oldPublicPrimarySnapshot?.exists == true) {
        transaction.update(oldPublicPrimarySnapshot!.reference, {
          'isPrimary': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (shouldBePrimary) {
        final showVehicle =
            profileData['showVehicleOnPublicProfile'] as bool? ?? false;
        final showPlate =
            profileData['showPlateOnPublicProfile'] as bool? ?? false;
        transaction.set(profileReference, {
          'primaryVehicleId': vehicleId,
          'vehicleBrand': savedVehicle.brand.trim(),
          'vehicleModel': savedVehicle.model.trim(),
          'vehicleColor': savedVehicle.color.trim(),
          'countryCode': savedVehicle.countryCode.trim().toUpperCase(),
          'plateRegion': savedVehicle.plateRegion.trim().toUpperCase(),
          'plateLetters': savedVehicle.plateLetters.trim().toUpperCase(),
          'plateNumbers': savedVehicle.plateNumbers.trim().toUpperCase(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(publicProfileReference, {
          'primaryVehicleId': vehicleId,
          'vehicleBrand': showVehicle ? savedVehicle.brand.trim() : null,
          'vehicleModel': showVehicle ? savedVehicle.model.trim() : null,
          'countryCode': showPlate
              ? savedVehicle.countryCode.trim().toUpperCase()
              : null,
          'plateRegion': showPlate
              ? savedVehicle.plateRegion.trim().toUpperCase()
              : null,
          'plateLetters': showPlate
              ? savedVehicle.plateLetters.trim().toUpperCase()
              : null,
          'plateNumbers': showPlate
              ? savedVehicle.plateNumbers.trim().toUpperCase()
              : null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });

    if (!savedVehicle.isPrimary || previousProfile == null) return;

    final updatedProfile = previousProfile!.copyWith(
      primaryVehicleId: savedVehicle.id,
      countryCode: savedVehicle.countryCode,
      plateRegion: savedVehicle.plateRegion,
      plateLetters: savedVehicle.plateLetters,
      plateNumbers: savedVehicle.plateNumbers,
      vehicleBrand: savedVehicle.brand,
      vehicleModel: savedVehicle.model,
      vehicleColor: savedVehicle.color,
    );
    final previous = previousProfile!;
    final plateKeyChanged =
        _plateKeyFor(previous) != _plateKeyFor(updatedProfile);
    final searchableVehicleChanged =
        previous.primaryVehicleId?.trim() !=
            updatedProfile.primaryVehicleId?.trim() ||
        previous.vehicleBrand?.trim() != updatedProfile.vehicleBrand?.trim() ||
        previous.vehicleModel?.trim() != updatedProfile.vehicleModel?.trim() ||
        previous.vehicleColor?.trim() != updatedProfile.vehicleColor?.trim();
    if (!plateKeyChanged && !searchableVehicleChanged) return;

    if (plateKeyChanged) {
      await _plateRepository.deactivatePlateForProfile(previous);
    }
    await _plateRepository.registerPlateForProfile(updatedProfile);
  }

  Future<void> setPrimaryVehicle({
    required String userId,
    required String vehicleId,
  }) async {
    final vehicle = await getOwnerVehicle(userId: userId, vehicleId: vehicleId);
    if (vehicle == null || vehicle.isArchived) {
      throw StateError('Das Fahrzeug ist nicht verfügbar.');
    }
    await saveVehicle(vehicle.copyWith(isPrimary: true));
  }

  Future<void> archiveVehicle({
    required String userId,
    required String vehicleId,
  }) async {
    final vehicle = await getOwnerVehicle(userId: userId, vehicleId: vehicleId);
    if (vehicle == null) return;
    if (vehicle.isPrimary) {
      throw StateError(
        'Wähle zuerst ein anderes Fahrzeug als Hauptfahrzeug aus.',
      );
    }
    await saveVehicle(
      vehicle.copyWith(
        status: ProfileVehicleStatus.archived,
        visibility: ProfileVehicleVisibility.onlyMe,
      ),
    );
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

  String _plateKeyFor(UserProfile profile) {
    return [
      profile.countryCode ?? profile.country,
      profile.plateRegion,
      profile.plateLetters,
      profile.plateNumbers,
    ].whereType<String>().map((part) => part.trim().toUpperCase()).join();
  }
}
