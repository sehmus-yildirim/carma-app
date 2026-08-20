import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/data/follow_repository.dart';
import 'package:plaqa/features/profile/data/social_feed_repository.dart';
import 'package:plaqa/features/profile/data/social_post.dart';
import 'package:plaqa/features/profile/data/social_post_repository.dart';

void main() {
  test(
    'merges visible followed posts chronologically and filters invalid data',
    () {
      final older = _post(
        id: 'older',
        ownerUserId: 'owner-a',
        createdAt: DateTime(2026, 8, 19, 12),
      );
      final newer = _post(
        id: 'newer',
        ownerUserId: 'owner-b',
        createdAt: DateTime(2026, 8, 20, 12),
      );
      final result = mergeFollowingFeedPosts({
        'owner-a': [
          older,
          _post(
            id: 'private',
            ownerUserId: 'owner-a',
            visibility: SocialPostVisibility.onlyMe,
          ),
          _post(
            id: 'vehicle',
            ownerUserId: 'owner-a',
            section: SocialPostSection.vehicle,
          ),
        ],
        'owner-b': [
          newer,
          _post(id: 'archived', ownerUserId: 'owner-b', isArchived: true),
          _post(id: 'wrong-owner', ownerUserId: 'owner-c'),
        ],
      });

      expect(result.map((post) => post.id), ['newer', 'older']);
    },
  );

  test('limits the merged feed after sorting', () {
    final result = mergeFollowingFeedPosts({
      'owner-a': [
        _post(
          id: 'first',
          ownerUserId: 'owner-a',
          createdAt: DateTime(2026, 8, 18),
        ),
        _post(
          id: 'second',
          ownerUserId: 'owner-a',
          createdAt: DateTime(2026, 8, 19),
        ),
      ],
    }, limit: 1);

    expect(result.single.id, 'second');
  });

  test('updates the feed when followed users post or are unfollowed', () async {
    final followRepository = _FakeFollowRepository();
    final postRepository = _FakeSocialPostRepository();
    final repository = SocialFeedRepository(
      followRepository: followRepository,
      postRepository: postRepository,
    );
    final emissions = <List<SocialPost>>[];
    final subscription = repository
        .watchFollowingPosts(userId: 'viewer')
        .listen(emissions.add);
    addTearDown(() async {
      await subscription.cancel();
      await followRepository.close();
      await postRepository.close();
    });

    followRepository.add(<FollowRelationship>[
      FollowRelationship(
        id: 'viewer_owner-a',
        followerUserId: 'viewer',
        followedUserId: 'owner-a',
        followerDisplayName: 'Viewer',
        followedDisplayName: 'Owner A',
        status: FollowRelationshipStatus.following,
        createdAt: DateTime(2026, 8, 20),
        updatedAt: DateTime(2026, 8, 20),
        acceptedAt: DateTime(2026, 8, 20),
      ),
    ]);
    await _waitUntil(() => postRepository.hasListenerFor('owner-a'));

    postRepository.add('owner-a', <SocialPost>[
      _post(id: 'live-post', ownerUserId: 'owner-a'),
    ]);
    await _waitUntil(
      () =>
          emissions.any((posts) => posts.any((post) => post.id == 'live-post')),
    );

    followRepository.add(const <FollowRelationship>[]);
    await _waitUntil(() => emissions.isNotEmpty && emissions.last.isEmpty);
    expect(postRepository.hasListenerFor('owner-a'), isFalse);
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out while waiting for the feed stream.');
}

class _FakeFollowRepository implements FollowRepository {
  final StreamController<List<FollowRelationship>> _controller =
      StreamController<List<FollowRelationship>>.broadcast();

  void add(List<FollowRelationship> relationships) {
    _controller.add(relationships);
  }

  Future<void> close() => _controller.close();

  @override
  Stream<List<FollowRelationship>> watchFollowing(String profileUserId) {
    return _controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSocialPostRepository implements SocialPostRepository {
  final Map<String, StreamController<List<SocialPost>>> _controllers =
      <String, StreamController<List<SocialPost>>>{};

  bool hasListenerFor(String userId) {
    return _controllers[userId]?.hasListener ?? false;
  }

  void add(String userId, List<SocialPost> posts) {
    _controllers[userId]?.add(posts);
  }

  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }

  @override
  Stream<List<SocialPost>> watchUserPosts({
    required String userId,
    required String viewerUserId,
    bool archived = false,
  }) {
    return _controllers
        .putIfAbsent(
          userId,
          () => StreamController<List<SocialPost>>.broadcast(),
        )
        .stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SocialPost _post({
  required String id,
  required String ownerUserId,
  DateTime? createdAt,
  SocialPostSection section = SocialPostSection.posts,
  SocialPostVisibility visibility = SocialPostVisibility.public,
  bool isArchived = false,
}) {
  return SocialPost(
    id: id,
    ownerUserId: ownerUserId,
    imageUrl: 'https://example.test/$id.jpg',
    imagePath: 'social_posts/$ownerUserId/$id.jpg',
    createdAt: createdAt ?? DateTime(2026, 8, 20),
    section: section,
    visibility: visibility.firestoreValue,
    isArchived: isArchived,
  );
}
