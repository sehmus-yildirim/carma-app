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

class SocialPostUpload {
  const SocialPostUpload({required this.file, required this.type});

  final File file;
  final SocialPostMediaType type;
}

class SocialPostPublicIdentity {
  const SocialPostPublicIdentity({
    required this.displayName,
    required this.photoUrl,
  });

  final String displayName;
  final String photoUrl;
}

class SocialPostRepository {
  SocialPostRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  static const int maxMediaPerPost = 10;
  static const int _maxPostImageBytes = 10 * 1024 * 1024;
  static const int _maxPostVideoBytes = 80 * 1024 * 1024;
  static const int _maxPinnedPosts = 3;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Stream<SocialPostPublicIdentity> watchPublicIdentity({
    required String userId,
    required String fallbackDisplayName,
    required String fallbackPhotoUrl,
  }) {
    final normalizedUserId = userId.trim();
    final fallback = SocialPostPublicIdentity(
      displayName: fallbackDisplayName.trim().isEmpty
          ? 'plaqa Nutzer'
          : fallbackDisplayName.trim(),
      photoUrl: fallbackPhotoUrl.trim(),
    );
    if (normalizedUserId.isEmpty) return Stream.value(fallback);

    return _firestore
        .collection('public_profiles')
        .doc(normalizedUserId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) return fallback;
          final displayName = (data['displayName'] as String? ?? '').trim();
          final photoUrl = (data['photoUrl'] as String? ?? '').trim();
          return SocialPostPublicIdentity(
            displayName: displayName.isEmpty
                ? fallback.displayName
                : displayName,
            photoUrl: photoUrl,
          );
        });
  }

  Future<({String displayName, String photoUrl})> _publicIdentity({
    required String userId,
    required String fallbackDisplayName,
    required String fallbackPhotoUrl,
  }) async {
    final normalizedFallbackName = fallbackDisplayName.trim().isEmpty
        ? 'plaqa Nutzer'
        : fallbackDisplayName.trim();
    try {
      final snapshot = await _firestore
          .collection('public_profiles')
          .doc(userId)
          .get();
      final data = snapshot.data();
      if (data == null) {
        return (
          displayName: normalizedFallbackName,
          photoUrl: fallbackPhotoUrl.trim(),
        );
      }
      final publicDisplayName = (data['displayName'] as String? ?? '').trim();
      final publicPhotoUrl = (data['photoUrl'] as String? ?? '').trim();
      return (
        displayName: publicDisplayName.isEmpty
            ? normalizedFallbackName
            : publicDisplayName,
        photoUrl: publicPhotoUrl,
      );
    } catch (_) {
      return (
        displayName: normalizedFallbackName,
        photoUrl: fallbackPhotoUrl.trim(),
      );
    }
  }

  CollectionReference<Map<String, dynamic>> _postsCollection(String userId) {
    return _firestore.collection('users/$userId/social_posts');
  }

  DocumentReference<Map<String, dynamic>> _postReference(
    String userId,
    String postId,
  ) {
    return _postsCollection(userId).doc(postId);
  }

  Stream<List<SocialPost>> watchUserPosts({
    required String userId,
    required String viewerUserId,
    bool archived = false,
  }) {
    final trimmedUserId = userId.trim();
    final trimmedViewerUserId = viewerUserId.trim();
    if (trimmedUserId.isEmpty) {
      return Stream.value(const <SocialPost>[]);
    }

    Query<Map<String, dynamic>> query = _postsCollection(trimmedUserId);
    if (trimmedUserId != trimmedViewerUserId) {
      query = query
          .where('visibility', whereIn: const <String>['public', 'contacts'])
          .where('isDeleted', isEqualTo: false)
          .where('isArchived', isEqualTo: false);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .where((document) => document.data()['isDeleted'] != true)
              .map(SocialPost.fromFirestore)
              .where((post) => post.resolvedMedia.isNotEmpty)
              .where((post) => post.isArchived == archived)
              .where((post) {
                if (trimmedUserId == trimmedViewerUserId) return true;
                return post.visibilityMode != SocialPostVisibility.onlyMe;
              })
              .toList(growable: true);
          posts.sort(_comparePosts);
          return List<SocialPost>.unmodifiable(posts);
        });
  }

  Future<void> createImagePost({
    required String userId,
    required File imageFile,
    String? caption,
    String? vehicleLabel,
    String? vehicleId,
    String? locationLabel,
    SocialPostSection section = SocialPostSection.posts,
  }) {
    return createMediaPost(
      userId: userId,
      uploads: <SocialPostUpload>[
        SocialPostUpload(file: imageFile, type: SocialPostMediaType.image),
      ],
      caption: caption,
      vehicleLabel: vehicleLabel,
      vehicleId: vehicleId,
      locationLabel: locationLabel,
      section: section,
    );
  }

  Future<void> createMediaPost({
    required String userId,
    required List<SocialPostUpload> uploads,
    String? caption,
    String? vehicleLabel,
    String? vehicleId,
    String? locationLabel,
    SocialPostSection section = SocialPostSection.posts,
    SocialPostVisibility visibility = SocialPostVisibility.public,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      throw ArgumentError('Nutzer-ID darf nicht leer sein.');
    }
    if (uploads.isEmpty || uploads.length > maxMediaPerPost) {
      throw const SocialPostRepositoryException(
        'Wähle zwischen einem und zehn Medien aus.',
      );
    }

    for (final upload in uploads) {
      final size = await upload.file.length();
      final maxBytes = upload.type == SocialPostMediaType.video
          ? _maxPostVideoBytes
          : _maxPostImageBytes;
      if (size <= 0) {
        throw const SocialPostRepositoryException('Eine Datei ist leer.');
      }
      if (size > maxBytes) {
        throw SocialPostRepositoryException(
          upload.type == SocialPostMediaType.video
              ? 'Ein Video ist zu groß. Maximal 80 MB.'
              : 'Ein Bild ist zu groß. Maximal 10 MB.',
        );
      }
    }

    final postReference = _postsCollection(trimmedUserId).doc();
    final postId = postReference.id;
    final uploadedReferences = <Reference>[];
    final mediaUrls = <String>[];
    final mediaPaths = <String>[];
    final mediaTypes = <String>[];

    try {
      for (var index = 0; index < uploads.length; index++) {
        final upload = uploads[index];
        final extension = upload.type == SocialPostMediaType.video
            ? 'mp4'
            : 'jpg';
        final contentType = upload.type == SocialPostMediaType.video
            ? 'video/mp4'
            : 'image/jpeg';
        final mediaPath =
            'profile_posts/$trimmedUserId/$postId/media_$index.$extension';
        final mediaReference = _storage.ref(mediaPath);
        await mediaReference.putFile(
          upload.file,
          SettableMetadata(contentType: contentType),
        );
        uploadedReferences.add(mediaReference);
        mediaUrls.add(await mediaReference.getDownloadURL());
        mediaPaths.add(mediaPath);
        mediaTypes.add(upload.type.firestoreValue);
      }

      await postReference.set(<String, dynamic>{
        'postId': postId,
        'ownerUserId': trimmedUserId,
        'imageUrl': mediaUrls.first,
        'imagePath': mediaPaths.first,
        'mediaUrls': mediaUrls,
        'mediaPaths': mediaPaths,
        'mediaTypes': mediaTypes,
        'caption': _trimmedOrNull(caption),
        'vehicleLabel': _trimmedOrNull(vehicleLabel),
        'vehicleId': _trimmedOrNull(vehicleId),
        'locationLabel': _trimmedOrNull(locationLabel),
        'section': section.firestoreValue,
        'visibility': visibility.firestoreValue,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'isArchived': false,
        'pinnedAt': null,
      });
    } catch (_) {
      await Future.wait(
        uploadedReferences.map(
          (reference) => reference.delete().catchError((_) {}),
        ),
      );
      rethrow;
    }
  }

  Future<void> updatePost({
    required String userId,
    required SocialPost post,
    required String? caption,
    required String? locationLabel,
    required SocialPostVisibility visibility,
  }) async {
    _requireOwner(userId, post);
    await _postReference(userId.trim(), post.id).update(<String, dynamic>{
      'caption': _trimmedOrNull(caption),
      'locationLabel': _trimmedOrNull(locationLabel),
      'visibility': visibility.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setPostArchived({
    required String userId,
    required SocialPost post,
    required bool archived,
  }) async {
    _requireOwner(userId, post);
    await _postReference(userId.trim(), post.id).update(<String, dynamic>{
      'isArchived': archived,
      'pinnedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setPostPinned({
    required String userId,
    required SocialPost post,
    required bool pinned,
  }) async {
    _requireOwner(userId, post);
    if (pinned) {
      final posts = await _postsCollection(userId.trim()).get();
      final pinnedCount = posts.docs
          .where((document) => document.id != post.id)
          .where((document) => document.data()['pinnedAt'] != null)
          .length;
      if (pinnedCount >= _maxPinnedPosts) {
        throw const SocialPostRepositoryException(
          'Du kannst höchstens drei Beiträge anpinnen.',
        );
      }
    }
    await _postReference(userId.trim(), post.id).update(<String, dynamic>{
      'pinnedAt': pinned ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<int> watchLikeCount(SocialPost post) {
    return _postReference(
      post.ownerUserId,
      post.id,
    ).collection('likes').snapshots().map((snapshot) => snapshot.size);
  }

  Stream<int> watchTotalLikeCount(String ownerUserId) {
    final userId = ownerUserId.trim();
    if (userId.isEmpty) return Stream<int>.value(0);
    return _firestore
        .collectionGroup('likes')
        .where('postOwnerUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<List<SocialPostLike>> watchLikes(SocialPost post) {
    return _postReference(post.ownerUserId, post.id)
        .collection('likes')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SocialPostLike.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<bool> watchLikedBy({
    required SocialPost post,
    required String userId,
  }) {
    if (userId.trim().isEmpty) return Stream.value(false);
    return _postReference(post.ownerUserId, post.id)
        .collection('likes')
        .doc(userId.trim())
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<void> toggleLike({
    required SocialPost post,
    required String userId,
    required String displayName,
    required String photoUrl,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return;
    final identity = await _publicIdentity(
      userId: trimmedUserId,
      fallbackDisplayName: displayName,
      fallbackPhotoUrl: photoUrl,
    );
    final likeReference = _postReference(
      post.ownerUserId,
      post.id,
    ).collection('likes').doc(trimmedUserId);
    final like = await likeReference.get();
    if (like.exists) {
      await likeReference.delete();
    } else {
      await likeReference.set(<String, dynamic>{
        'userId': trimmedUserId,
        'postOwnerUserId': post.ownerUserId,
        'displayName': identity.displayName,
        'photoUrl': identity.photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<List<SocialPostComment>> watchComments(SocialPost post) {
    return _postReference(post.ownerUserId, post.id)
        .collection('comments')
        .orderBy('createdAt')
        .limit(200)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SocialPostComment.fromFirestore)
              .where((comment) => !comment.isDeleted)
              .toList(growable: false),
        );
  }

  Future<void> addComment({
    required SocialPost post,
    required String authorUserId,
    required String authorDisplayName,
    required String authorPhotoUrl,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;
    if (trimmedText.length > 500) {
      throw const SocialPostRepositoryException(
        'Ein Kommentar darf höchstens 500 Zeichen enthalten.',
      );
    }
    final normalizedAuthorUserId = authorUserId.trim();
    final identity = await _publicIdentity(
      userId: normalizedAuthorUserId,
      fallbackDisplayName: authorDisplayName,
      fallbackPhotoUrl: authorPhotoUrl,
    );
    final reference = _postReference(
      post.ownerUserId,
      post.id,
    ).collection('comments').doc();
    await reference.set(<String, dynamic>{
      'commentId': reference.id,
      'postId': post.id,
      'postOwnerUserId': post.ownerUserId,
      'authorUserId': normalizedAuthorUserId,
      'authorDisplayName': identity.displayName,
      'authorPhotoUrl': identity.photoUrl,
      'text': trimmedText,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    });
  }

  Future<void> deleteComment({
    required SocialPost post,
    required SocialPostComment comment,
  }) {
    return _postReference(
      post.ownerUserId,
      post.id,
    ).collection('comments').doc(comment.id).update(<String, dynamic>{
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reportComment({
    required SocialPost post,
    required SocialPostComment comment,
    required String reporterUserId,
  }) async {
    final trimmedUserId = reporterUserId.trim();
    if (trimmedUserId.isEmpty) return;
    await _postReference(post.ownerUserId, post.id)
        .collection('comments')
        .doc(comment.id)
        .collection('reports')
        .doc(trimmedUserId)
        .set(<String, dynamic>{
          'reporterUserId': trimmedUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Stream<Map<SocialPostCommentReaction, int>> watchCommentReactionCounts({
    required SocialPost post,
    required SocialPostComment comment,
  }) {
    return _postReference(post.ownerUserId, post.id)
        .collection('comments')
        .doc(comment.id)
        .collection('reactions')
        .snapshots()
        .map((snapshot) {
          final counts = <SocialPostCommentReaction, int>{
            for (final reaction in SocialPostCommentReaction.values)
              reaction: 0,
          };
          for (final document in snapshot.docs) {
            final reaction = SocialPostCommentReaction.fromFirestore(
              document.data()['type'],
            );
            if (reaction != null) counts[reaction] = counts[reaction]! + 1;
          }
          return counts;
        });
  }

  Stream<SocialPostCommentReaction?> watchCommentReactionForViewer({
    required SocialPost post,
    required SocialPostComment comment,
    required String viewerUserId,
  }) {
    final trimmedUserId = viewerUserId.trim();
    if (trimmedUserId.isEmpty) return Stream.value(null);
    return _postReference(post.ownerUserId, post.id)
        .collection('comments')
        .doc(comment.id)
        .collection('reactions')
        .doc(trimmedUserId)
        .snapshots()
        .map(
          (snapshot) => SocialPostCommentReaction.fromFirestore(
            snapshot.data()?['type'],
          ),
        );
  }

  Future<void> setCommentReaction({
    required SocialPost post,
    required SocialPostComment comment,
    required String userId,
    required SocialPostCommentReaction reaction,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return;
    final reference = _postReference(post.ownerUserId, post.id)
        .collection('comments')
        .doc(comment.id)
        .collection('reactions')
        .doc(trimmedUserId);
    final snapshot = await reference.get();
    if (snapshot.exists && snapshot.data()?['type'] == reaction.firestoreValue) {
      await reference.delete();
      return;
    }
    await reference.set(<String, dynamic>{
      'userId': trimmedUserId,
      'type': reaction.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePost({
    required String userId,
    required SocialPost post,
  }) async {
    _requireOwner(userId, post);
    await _postReference(userId.trim(), post.id).delete();

    final mediaPaths = post.resolvedMedia
        .map((media) => media.path.trim())
        .where((path) => path.isNotEmpty)
        .toSet();
    for (final path in mediaPaths) {
      try {
        await _storage.ref(path).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
  }

  void _requireOwner(String userId, SocialPost post) {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      throw ArgumentError('Nutzer-ID darf nicht leer sein.');
    }
    if (post.ownerUserId != trimmedUserId) {
      throw const SocialPostRepositoryException(
        'Dieser Beitrag kann nicht verwaltet werden.',
      );
    }
  }

  int _comparePosts(SocialPost left, SocialPost right) {
    if (left.isPinned != right.isPinned) return left.isPinned ? -1 : 1;
    final leftDate = left.pinnedAt ?? left.createdAt;
    final rightDate = right.pinnedAt ?? right.createdAt;
    return rightDate.compareTo(leftDate);
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
