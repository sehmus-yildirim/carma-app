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
  ProfileMediaStorage({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  static const int _maxProfilePhotoBytes = 8 * 1024 * 1024;
  static const int _maxVerificationDocumentBytes = 12 * 1024 * 1024;

  final FirebaseStorage _storage;

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

    final path = 'profile_photos/$trimmedUserId/profile.jpg';
    final reference = _storage.ref(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');

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

    try {
      await _storage.ref('profile_photos/$trimmedUserId/profile.jpg').delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  Future<ProfileMediaUploadResult> uploadVerificationDocument({
    required String userId,
    required String documentType,
    required File file,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedDocumentType = documentType.trim();

    if (trimmedUserId.isEmpty || trimmedDocumentType.isEmpty) {
      throw ArgumentError('Nutzer-ID und Dokumenttyp dürfen nicht leer sein.');
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmedDocumentType)) {
      throw ArgumentError('Dokumenttyp enthält ungültige Zeichen.');
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

    final path =
        'profile_documents/$trimmedUserId/$trimmedDocumentType/$trimmedDocumentType.jpg';
    final reference = _storage.ref(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    await reference.putFile(file, metadata);

    return ProfileMediaUploadResult(
      path: path,
      url: await reference.getDownloadURL(),
    );
  }
}
