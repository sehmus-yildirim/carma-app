import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class ProfileMediaUploadResult {
  const ProfileMediaUploadResult({required this.path, required this.url});

  final String path;
  final String url;
}

class ProfileMediaStorageException implements Exception {
  const ProfileMediaStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileMediaStorage {
  ProfileMediaStorage({FirebaseStorage? storage}) : _storage = storage;

  static const int _maxProfilePhotoBytes = 8 * 1024 * 1024;
  static const int _maxVerificationDocumentBytes = 12 * 1024 * 1024;

  final FirebaseStorage? _storage;

  FirebaseStorage get _bucket => _storage ?? FirebaseStorage.instance;

  Future<ProfileMediaUploadResult> uploadProfilePhoto({
    required String userId,
    required File file,
  }) async {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      throw ArgumentError('Nutzer-ID darf nicht leer sein.');
    }

    final fileSizeBytes = await file.length();

    if (fileSizeBytes <= 0) {
      throw const ProfileMediaStorageException('Profilbild ist leer.');
    }

    if (fileSizeBytes >= _maxProfilePhotoBytes) {
      throw const ProfileMediaStorageException(
        'Profilbild ist zu groß. Maximal 8 MB.',
      );
    }

    if (!await _isPng(file)) {
      throw const ProfileMediaStorageException(
        'Das Profilbild konnte nicht sicher vorbereitet werden.',
      );
    }

    final path = 'profile_photos/$trimmedUserId/profile.png';
    final reference = _bucket.ref(path);
    final metadata = SettableMetadata(
      contentType: 'image/png',
      cacheControl: 'no-cache, max-age=0, must-revalidate',
    );

    await reference.putFile(file, metadata);

    return ProfileMediaUploadResult(
      path: path,
      url: await reference.getDownloadURL(),
    );
  }

  Future<void> deleteProfilePhoto({required String userId}) async {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      throw ArgumentError('Nutzer-ID darf nicht leer sein.');
    }

    for (final fileName in const ['profile.png', 'profile.jpg']) {
      try {
        await _bucket.ref('profile_photos/$trimmedUserId/$fileName').delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') {
          rethrow;
        }
      }
    }
  }

  Future<ProfileMediaUploadResult> uploadVerificationDocument({
    required String userId,
    required String documentType,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedDocumentType = documentType.trim();

    if (trimmedUserId.isEmpty || trimmedDocumentType.isEmpty) {
      throw ArgumentError('Nutzer-ID und Dokumenttyp dürfen nicht leer sein.');
    }

    if (!const {
      'identityFront',
      'identityBack',
      'driverLicenseFront',
      'driverLicenseBack',
      'vehicleFront',
      'vehicleBack',
    }.contains(trimmedDocumentType)) {
      throw ArgumentError('Dokumenttyp ist nicht zulässig.');
    }

    final fileSizeBytes = await file.length();

    if (fileSizeBytes <= 0) {
      throw const ProfileMediaStorageException('Dokument ist leer.');
    }

    if (fileSizeBytes >= _maxVerificationDocumentBytes) {
      throw const ProfileMediaStorageException(
        'Dokument ist zu groß. Maximal 12 MB.',
      );
    }

    if (!await _isPng(file)) {
      throw const ProfileMediaStorageException(
        'Das Dokument konnte nicht sicher vorbereitet werden.',
      );
    }

    final path =
        'profile_documents/$trimmedUserId/$trimmedDocumentType/$trimmedDocumentType.png';
    final reference = _bucket.ref(path);
    final metadata = SettableMetadata(
      contentType: 'image/png',
      cacheControl: 'private, no-store, max-age=0',
      customMetadata: const {'purpose': 'profile-verification'},
    );
    final task = reference.putFile(file, metadata);
    StreamSubscription<TaskSnapshot>? progressSubscription;
    if (onProgress != null) {
      progressSubscription = task.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        onProgress(total <= 0 ? 0 : snapshot.bytesTransferred / total);
      });
    }
    try {
      await task;
      onProgress?.call(1);
    } finally {
      await progressSubscription?.cancel();
    }

    return ProfileMediaUploadResult(
      path: path,
      // Verification documents are addressed only by their private Storage
      // path. No long-lived download URL is generated or persisted.
      url: '',
    );
  }

  Future<void> deleteVerificationDocument({
    required String userId,
    required String documentType,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty ||
        !const {
          'identityFront',
          'identityBack',
          'driverLicenseFront',
          'driverLicenseBack',
          'vehicleFront',
          'vehicleBack',
        }.contains(documentType)) {
      return;
    }
    for (final extension in const ['png', 'jpg']) {
      final path =
          'profile_documents/$normalizedUserId/$documentType/$documentType.$extension';
      try {
        await _bucket.ref(path).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
  }

  Future<bool> _isPng(File file) async {
    final handle = await file.open();
    try {
      final bytes = await handle.read(8);
      const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      return bytes.length == signature.length &&
          List.generate(
            signature.length,
            (index) => bytes[index] == signature[index],
          ).every((matches) => matches);
    } finally {
      await handle.close();
    }
  }
}
