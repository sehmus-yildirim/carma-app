import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import '../../../shared/firebase/secure_upload_reservation_service.dart';
import 'profile_vehicle.dart';
import 'profile_vehicle_gallery_media.dart';

class ProfileVehicleGalleryException implements Exception {
  const ProfileVehicleGalleryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileVehicleGalleryRepository {
  ProfileVehicleGalleryRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    SecureUploadReservationService? uploadReservations,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _uploadReservations =
           uploadReservations ?? SecureUploadReservationService();

  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const int _maxVideoBytes = 80 * 1024 * 1024;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final SecureUploadReservationService _uploadReservations;

  CollectionReference<Map<String, dynamic>> _privateCollection(
    String userId,
    String vehicleId,
  ) => _firestore.collection(
    CaRismaFirestorePaths.userVehicleGallery(userId, vehicleId),
  );

  CollectionReference<Map<String, dynamic>> _publicCollection(
    String userId,
    String vehicleId,
  ) => _firestore.collection(
    CaRismaFirestorePaths.publicVehicleGallery(userId, vehicleId),
  );

  Stream<List<ProfileVehicleGalleryMedia>> watchOwnerMedia({
    required String userId,
    required String vehicleId,
  }) =>
      _privateCollection(userId, vehicleId).snapshots().map(_mediaFromSnapshot);

  Stream<List<ProfileVehicleGalleryMedia>> watchVisibleMedia({
    required String userId,
    required String vehicleId,
  }) =>
      _publicCollection(userId, vehicleId).snapshots().map(_mediaFromSnapshot);

  Future<void> uploadImage({
    required String userId,
    required ProfileVehicle vehicle,
    required File imageFile,
    required ProfileVehicleGalleryCategory category,
    String? caption,
  }) {
    return _uploadMedia(
      userId: userId,
      vehicle: vehicle,
      mediaFile: imageFile,
      mediaType: ProfileVehicleGalleryMediaType.image,
      contentType: 'image/jpeg',
      maxBytes: _maxImageBytes,
      category: category,
      caption: caption,
    );
  }

  Future<void> uploadVideo({
    required String userId,
    required ProfileVehicle vehicle,
    required File videoFile,
    required ProfileVehicleGalleryCategory category,
    String? caption,
  }) {
    return _uploadMedia(
      userId: userId,
      vehicle: vehicle,
      mediaFile: videoFile,
      mediaType: ProfileVehicleGalleryMediaType.video,
      contentType: 'video/mp4',
      maxBytes: _maxVideoBytes,
      category: category,
      caption: caption,
    );
  }

  Future<void> _uploadMedia({
    required String userId,
    required ProfileVehicle vehicle,
    required File mediaFile,
    required ProfileVehicleGalleryMediaType mediaType,
    required String contentType,
    required int maxBytes,
    required ProfileVehicleGalleryCategory category,
    String? caption,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty || vehicle.id.trim().isEmpty) {
      throw const ProfileVehicleGalleryException(
        'Die Fahrzeugzuordnung ist unvollständig.',
      );
    }
    final size = await mediaFile.length();
    if (size <= 0) {
      throw const ProfileVehicleGalleryException('Die Mediendatei ist leer.');
    }
    if (size >= maxBytes) {
      throw ProfileVehicleGalleryException(
        mediaType == ProfileVehicleGalleryMediaType.video
            ? 'Das Video ist zu groß. Maximal 80 MB.'
            : 'Das Bild ist zu groß. Maximal 10 MB.',
      );
    }

    final privateCollection = _privateCollection(trimmedUserId, vehicle.id);
    final mediaReference = privateCollection.doc();
    final mediaId = mediaReference.id;
    final mediaPath = 'vehicle_gallery/$trimmedUserId/${vehicle.id}/$mediaId';
    final storageReference = _storage.ref(mediaPath);
    final reservationId = await _uploadReservations.reserve(
      storagePath: mediaPath,
      contentType: contentType,
      sizeBytes: size,
    );

    await storageReference.putFile(
      mediaFile,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {'uploadReservationId': reservationId},
      ),
    );
    final mediaUrl = await storageReference.getDownloadURL();

    try {
      final existing = await privateCollection.get();
      final hasCategoryMedia = existing.docs.any((document) {
        final existingMedia = ProfileVehicleGalleryMedia.fromMap(
          id: document.id,
          data: document.data(),
        );
        return !existingMedia.isDeleted && existingMedia.category == category;
      });
      final media = ProfileVehicleGalleryMedia(
        id: mediaId,
        ownerUserId: trimmedUserId,
        vehicleId: vehicle.id,
        mediaUrl: mediaUrl,
        mediaPath: mediaPath,
        mediaType: mediaType,
        category: category,
        caption: caption,
        isMain: !hasCategoryMedia,
        visibility: vehicle.isPubliclyVisible
            ? ProfileVehicleVisibility.contacts
            : ProfileVehicleVisibility.onlyMe,
      );
      final batch = _firestore.batch();
      batch.set(mediaReference, {
        ...media.toPrivateFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (media.isPubliclyVisible) {
        batch.set(_publicCollection(trimmedUserId, vehicle.id).doc(mediaId), {
          ...media.toPublicFirestore(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {
      await _deleteStorageObject(mediaPath);
      rethrow;
    }
  }

  Future<void> setMainMedia(ProfileVehicleGalleryMedia selected) async {
    final snapshot = await _privateCollection(
      selected.ownerUserId,
      selected.vehicleId,
    ).get();
    final batch = _firestore.batch();
    for (final document in snapshot.docs) {
      final media = ProfileVehicleGalleryMedia.fromMap(
        id: document.id,
        data: document.data(),
      );
      if (media.isDeleted || media.category != selected.category) continue;
      final isMain = media.id == selected.id;
      batch.update(document.reference, {
        'isMain': isMain,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final publicReference = _publicCollection(
        selected.ownerUserId,
        selected.vehicleId,
      ).doc(media.id);
      if (media.isPubliclyVisible) {
        batch.set(publicReference, {
          ...media.copyWith(isMain: isMain).toPublicFirestore(),
          'createdAt': media.createdAt == null
              ? FieldValue.serverTimestamp()
              : Timestamp.fromDate(media.createdAt!),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        batch.delete(publicReference);
      }
    }
    await batch.commit();
  }

  Future<void> deleteMedia(ProfileVehicleGalleryMedia media) async {
    final batch = _firestore.batch();
    batch.update(
      _privateCollection(media.ownerUserId, media.vehicleId).doc(media.id),
      {
        'isDeleted': true,
        'isMain': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    batch.delete(
      _publicCollection(media.ownerUserId, media.vehicleId).doc(media.id),
    );
    await batch.commit();
    await _deleteStorageObject(media.mediaPath);
  }

  List<ProfileVehicleGalleryMedia> _mediaFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final media = snapshot.docs
        .map(
          (document) => ProfileVehicleGalleryMedia.fromMap(
            id: document.id,
            data: document.data(),
          ),
        )
        .where((item) => !item.isDeleted && item.mediaUrl.trim().isNotEmpty)
        .toList();
    media.sort((a, b) {
      if (a.isMain != b.isMain) return a.isMain ? -1 : 1;
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return media;
  }

  Future<void> _deleteStorageObject(String path) async {
    if (path.trim().isEmpty) return;
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}
