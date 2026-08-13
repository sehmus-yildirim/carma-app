import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

enum FollowRelationshipStatus { requested, following }

enum ProfileFollowState {
  notFollowing,
  followRequested,
  following,
  followedBy,
  mutual,
  blocked,
  restricted,
}

class FollowRelationship {
  const FollowRelationship({
    required this.id,
    required this.followerUserId,
    required this.followedUserId,
    required this.followerDisplayName,
    required this.followedDisplayName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.acceptedAt,
    this.followerPhotoUrl,
    this.followedPhotoUrl,
  });

  final String id;
  final String followerUserId;
  final String followedUserId;
  final String followerDisplayName;
  final String followedDisplayName;
  final String? followerPhotoUrl;
  final String? followedPhotoUrl;
  final FollowRelationshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acceptedAt;

  factory FollowRelationship.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final statusName = data['status'] as String? ?? '';
    return FollowRelationship(
      id: document.id,
      followerUserId: data['followerUserId'] as String? ?? '',
      followedUserId: data['followedUserId'] as String? ?? '',
      followerDisplayName:
          data['followerDisplayName'] as String? ?? 'plaqa Nutzer',
      followedDisplayName:
          data['followedDisplayName'] as String? ?? 'plaqa Nutzer',
      followerPhotoUrl: data['followerPhotoUrl'] as String?,
      followedPhotoUrl: data['followedPhotoUrl'] as String?,
      status: FollowRelationshipStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => FollowRelationshipStatus.requested,
      ),
      createdAt: _dateFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateFromValue(data['updatedAt']) ?? DateTime.now(),
      acceptedAt: _dateFromValue(data['acceptedAt']),
    );
  }

  static DateTime? _dateFromValue(Object? value) {
    return value is Timestamp ? value.toDate() : null;
  }
}

class FollowSummary {
  const FollowSummary({required this.state, this.outgoing, this.incoming});

  final ProfileFollowState state;
  final FollowRelationship? outgoing;
  final FollowRelationship? incoming;
}

class FollowRepository {
  FollowRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _relationships {
    return _firestore.collection('follow_relationships');
  }

  static String relationshipIdFor(
    String followerUserId,
    String followedUserId,
  ) {
    final follower = followerUserId.trim();
    final followed = followedUserId.trim();
    if (follower.isEmpty || followed.isEmpty || follower == followed) {
      throw ArgumentError('Two different user IDs are required.');
    }
    return '${follower}_$followed';
  }

  Stream<FollowSummary> watchSummary({
    required String currentUserId,
    required String profileUserId,
  }) {
    final outgoingId = relationshipIdFor(currentUserId, profileUserId);
    final incomingId = relationshipIdFor(profileUserId, currentUserId);
    late StreamController<FollowSummary> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? outgoingSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? incomingSub;
    FollowRelationship? outgoing;
    FollowRelationship? incoming;

    void emit() {
      if (!controller.isClosed) {
        controller.add(
          FollowSummary(
            state: _stateFor(outgoing: outgoing, incoming: incoming),
            outgoing: outgoing,
            incoming: incoming,
          ),
        );
      }
    }

    controller = StreamController<FollowSummary>(
      onListen: () {
        outgoingSub = _relationships.doc(outgoingId).snapshots().listen((
          snapshot,
        ) {
          outgoing = snapshot.exists
              ? FollowRelationship.fromFirestore(snapshot)
              : null;
          emit();
        }, onError: controller.addError);
        incomingSub = _relationships.doc(incomingId).snapshots().listen((
          snapshot,
        ) {
          incoming = snapshot.exists
              ? FollowRelationship.fromFirestore(snapshot)
              : null;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await outgoingSub?.cancel();
        await incomingSub?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<List<FollowRelationship>> watchFollowers(String profileUserId) {
    return _relationships
        .where('followedUserId', isEqualTo: profileUserId.trim())
        .where('status', isEqualTo: FollowRelationshipStatus.following.name)
        .snapshots()
        .map(_relationshipsFromSnapshot);
  }

  Stream<List<FollowRelationship>> watchFollowing(String profileUserId) {
    return _relationships
        .where('followerUserId', isEqualTo: profileUserId.trim())
        .where('status', isEqualTo: FollowRelationshipStatus.following.name)
        .snapshots()
        .map(_relationshipsFromSnapshot);
  }

  Stream<List<FollowRelationship>> watchFollowRequests(String userId) {
    return _relationships
        .where('followedUserId', isEqualTo: userId.trim())
        .where('status', isEqualTo: FollowRelationshipStatus.requested.name)
        .snapshots()
        .map(_relationshipsFromSnapshot);
  }

  Future<void> follow({
    required String followerUserId,
    required String followedUserId,
    required bool targetIsPrivate,
  }) async {
    final normalizedFollowerUserId = followerUserId.trim();
    final normalizedFollowedUserId = followedUserId.trim();
    final relationshipId = relationshipIdFor(
      normalizedFollowerUserId,
      normalizedFollowedUserId,
    );
    final profileDocuments = await Future.wait([
      _firestore
          .collection('public_profiles')
          .doc(normalizedFollowerUserId)
          .get(),
      _firestore
          .collection('public_profiles')
          .doc(normalizedFollowedUserId)
          .get(),
    ]);
    final followerProfile = profileDocuments[0].data();
    final followedProfile = profileDocuments[1].data();
    if (followerProfile == null || followedProfile == null) {
      throw StateError('Public profile data is missing.');
    }
    final effectiveTargetIsPrivate =
        followedProfile['isPrivateProfile'] as bool? ?? targetIsPrivate;
    final document = _relationships.doc(relationshipId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      if (snapshot.exists) return;

      transaction.set(document, <String, Object?>{
        'relationshipId': relationshipId,
        'followerUserId': normalizedFollowerUserId,
        'followedUserId': normalizedFollowedUserId,
        'followerDisplayName':
            followerProfile['displayName'] as String? ?? 'plaqa Nutzer',
        'followedDisplayName':
            followedProfile['displayName'] as String? ?? 'plaqa Nutzer',
        'followerPhotoUrl': followerProfile['photoUrl'] as String?,
        'followedPhotoUrl': followedProfile['photoUrl'] as String?,
        'status': effectiveTargetIsPrivate
            ? FollowRelationshipStatus.requested.name
            : FollowRelationshipStatus.following.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'acceptedAt': effectiveTargetIsPrivate
            ? null
            : FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> acceptRequest(FollowRelationship request) async {
    await _relationships.doc(request.id).update(<String, Object?>{
      'status': FollowRelationshipStatus.following.name,
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> declineRequest(FollowRelationship request) {
    return _relationships.doc(request.id).delete();
  }

  Future<void> unfollow({
    required String followerUserId,
    required String followedUserId,
  }) {
    return _relationships
        .doc(relationshipIdFor(followerUserId, followedUserId))
        .delete();
  }

  Future<void> removeFollower({
    required String profileUserId,
    required String followerUserId,
  }) {
    return unfollow(
      followerUserId: followerUserId,
      followedUserId: profileUserId,
    );
  }

  List<FollowRelationship> _relationshipsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map(FollowRelationship.fromFirestore).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static ProfileFollowState _stateFor({
    required FollowRelationship? outgoing,
    required FollowRelationship? incoming,
  }) {
    final follows = outgoing?.status == FollowRelationshipStatus.following;
    final requested = outgoing?.status == FollowRelationshipStatus.requested;
    final followedBy = incoming?.status == FollowRelationshipStatus.following;

    if (follows && followedBy) return ProfileFollowState.mutual;
    if (follows) return ProfileFollowState.following;
    if (requested) return ProfileFollowState.followRequested;
    if (followedBy) return ProfileFollowState.followedBy;
    return ProfileFollowState.notFollowing;
  }
}
