import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'social_post.dart';

class SocialPostRepositoryException implements Exception {
  const SocialPostRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SocialPostRepository {
  SocialPostRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  static const int _maxPostImageBytes = 10 * 1024 * 1024;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _postsCollection(String userId) {
    return _firestore.collection('users/$userId/social_posts');
  }

  Stream<List<SocialPost>> watchUserPosts({
    required String userId,
    required String viewerUserId,
  }) {
    final trimmedUserId = userId.trim();
    final trimmedViewerUserId = viewerUserId.trim();
    if (trimmedUserId.isEmpty) {
      return Stream.value(const <SocialPost>[]);
    }

    Query<Map<String, dynamic>> query = _postsCollection(trimmedUserId);
    if (trimmedUserId != trimmedViewerUserId) {
      query = query
          .where('visibility', isEqualTo: 'public')
          .where('isDeleted', isEqualTo: false);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((document) => document.data()['isDeleted'] != true)
              .map(SocialPost.fromFirestore)
              .where((post) => post.imageUrl.trim().isNotEmpty)
              .toList(growable: false),
        );
  }

  Future<void> createImagePost({
    required String userId,
    required File imageFile,
    String? caption,
    String? vehicleLabel,
    String? locationLabel,
    SocialPostSection section = SocialPostSection.posts,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      throw ArgumentError('Nutzer-ID darf nicht leer sein.');
    }

    final fileSizeBytes = await imageFile.length();
    if (fileSizeBytes <= 0) {
      throw const SocialPostRepositoryException('Bild ist leer.');
    }
    if (fileSizeBytes >= _maxPostImageBytes) {
      throw const SocialPostRepositoryException(
        'Bild ist zu groß. Maximal 10 MB.',
      );
    }

    final postReference = _postsCollection(trimmedUserId).doc();
    final postId = postReference.id;
    final imagePath = 'profile_posts/$trimmedUserId/$postId/image.jpg';
    final imageReference = _storage.ref(imagePath);

    await imageReference.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final imageUrl = await imageReference.getDownloadURL();
    final postData = <String, dynamic>{
      'postId': postId,
      'ownerUserId': trimmedUserId,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'caption': _trimmedOrNull(caption),
      'vehicleLabel': _trimmedOrNull(vehicleLabel),
      'locationLabel': _trimmedOrNull(locationLabel),
      'section': section.firestoreValue,
      'visibility': 'public',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    };

    await postReference.set(postData);
  }

  Future<void> deletePost({
    required String userId,
    required SocialPost post,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      throw ArgumentError('Nutzer-ID darf nicht leer sein.');
    }
    if (post.ownerUserId != trimmedUserId) {
      throw const SocialPostRepositoryException(
        'Dieser Beitrag kann nicht gelöscht werden.',
      );
    }

    await _postsCollection(trimmedUserId).doc(post.id).delete();

    final imagePath = post.imagePath.trim();
    if (imagePath.isEmpty) return;

    try {
      await _storage.ref(imagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
