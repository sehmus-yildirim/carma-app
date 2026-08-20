import 'dart:async';

import 'follow_repository.dart';
import 'social_post.dart';
import 'social_post_repository.dart';

class SocialFeedRepository {
  SocialFeedRepository({
    FollowRepository? followRepository,
    SocialPostRepository? postRepository,
  }) : _followRepository = followRepository ?? FollowRepository(),
       _postRepository = postRepository ?? SocialPostRepository();

  static const int maxFeedPosts = 80;

  final FollowRepository _followRepository;
  final SocialPostRepository _postRepository;

  Stream<List<SocialPost>> watchFollowingPosts({required String userId}) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream<List<SocialPost>>.value(const <SocialPost>[]);
    }

    late final StreamController<List<SocialPost>> controller;
    StreamSubscription<List<FollowRelationship>>? relationshipsSubscription;
    final postSubscriptions = <String, StreamSubscription<List<SocialPost>>>{};
    final postsByOwner = <String, List<SocialPost>>{};
    final subscriptionVersionByOwner = <String, int>{};
    var nextSubscriptionVersion = 0;

    void emit() {
      if (controller.isClosed) return;
      controller.add(
        mergeFollowingFeedPosts(postsByOwner, limit: maxFeedPosts),
      );
    }

    Future<void> removeOwner(String ownerUserId) async {
      subscriptionVersionByOwner.remove(ownerUserId);
      postsByOwner.remove(ownerUserId);
      await postSubscriptions.remove(ownerUserId)?.cancel();
    }

    Future<void> updateFollowing(List<FollowRelationship> relationships) async {
      final followedUserIds = relationships
          .where(
            (relationship) =>
                relationship.status == FollowRelationshipStatus.following,
          )
          .map((relationship) => relationship.followedUserId.trim())
          .where(
            (followedUserId) =>
                followedUserId.isNotEmpty && followedUserId != normalizedUserId,
          )
          .toSet();

      final removedUserIds = postSubscriptions.keys
          .where((ownerUserId) => !followedUserIds.contains(ownerUserId))
          .toList(growable: false);
      for (final ownerUserId in removedUserIds) {
        await removeOwner(ownerUserId);
      }

      for (final ownerUserId in followedUserIds) {
        if (postSubscriptions.containsKey(ownerUserId)) continue;
        postsByOwner[ownerUserId] = const <SocialPost>[];
        final subscriptionVersion = ++nextSubscriptionVersion;
        subscriptionVersionByOwner[ownerUserId] = subscriptionVersion;
        postSubscriptions[ownerUserId] = _postRepository
            .watchUserPosts(userId: ownerUserId, viewerUserId: normalizedUserId)
            .listen(
              (posts) {
                if (subscriptionVersionByOwner[ownerUserId] !=
                    subscriptionVersion) {
                  return;
                }
                postsByOwner[ownerUserId] = posts;
                emit();
              },
              onError: (_) {
                if (subscriptionVersionByOwner[ownerUserId] !=
                    subscriptionVersion) {
                  return;
                }
                postsByOwner[ownerUserId] = const <SocialPost>[];
                emit();
              },
            );
      }
      emit();
    }

    controller = StreamController<List<SocialPost>>(
      onListen: () {
        relationshipsSubscription = _followRepository
            .watchFollowing(normalizedUserId)
            .listen((relationships) {
              unawaited(updateFollowing(relationships));
            }, onError: controller.addError);
      },
      onCancel: () async {
        await relationshipsSubscription?.cancel();
        final subscriptions = postSubscriptions.values.toList(growable: false);
        postSubscriptions.clear();
        postsByOwner.clear();
        subscriptionVersionByOwner.clear();
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }
}

List<SocialPost> mergeFollowingFeedPosts(
  Map<String, List<SocialPost>> postsByOwner, {
  int limit = SocialFeedRepository.maxFeedPosts,
}) {
  final postsById = <String, SocialPost>{};
  for (final entry in postsByOwner.entries) {
    for (final post in entry.value) {
      if (post.ownerUserId.trim() != entry.key.trim() ||
          post.section != SocialPostSection.posts ||
          post.isArchived ||
          post.visibilityMode == SocialPostVisibility.onlyMe ||
          post.resolvedMedia.isEmpty) {
        continue;
      }
      postsById['${post.ownerUserId}/${post.id}'] = post;
    }
  }

  final posts = postsById.values.toList(growable: false)
    ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  return List<SocialPost>.unmodifiable(posts.take(limit));
}
