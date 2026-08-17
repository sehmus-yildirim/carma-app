import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/data/social_post.dart';
import 'package:plaqa/features/profile/data/social_post_repository.dart';

void main() {
  group('SocialPost', () {
    test('keeps legacy image posts readable as one media item', () {
      final post = SocialPost(
        id: 'post-1',
        ownerUserId: 'owner-1',
        imageUrl: 'https://example.com/image.jpg',
        imagePath: 'profile_posts/owner-1/post-1/image.jpg',
        createdAt: DateTime(2026, 8, 16),
        section: SocialPostSection.posts,
        visibility: 'public',
      );

      expect(post.resolvedMedia, hasLength(1));
      expect(post.resolvedMedia.single.type, SocialPostMediaType.image);
      expect(post.visibilityMode, SocialPostVisibility.public);
    });

    test('preserves ordered image and video gallery media', () {
      final post = SocialPost(
        id: 'post-2',
        ownerUserId: 'owner-1',
        imageUrl: 'https://example.com/image.jpg',
        imagePath: 'profile_posts/owner-1/post-2/media_0.jpg',
        createdAt: DateTime(2026, 8, 16),
        section: SocialPostSection.posts,
        visibility: 'contacts',
        media: const <SocialPostMedia>[
          SocialPostMedia(
            url: 'https://example.com/image.jpg',
            path: 'profile_posts/owner-1/post-2/media_0.jpg',
            type: SocialPostMediaType.image,
          ),
          SocialPostMedia(
            url: 'https://example.com/video.mp4',
            path: 'profile_posts/owner-1/post-2/media_1.mp4',
            type: SocialPostMediaType.video,
          ),
        ],
      );

      expect(post.resolvedMedia, hasLength(2));
      expect(post.resolvedMedia.last.isVideo, isTrue);
      expect(post.visibilityMode, SocialPostVisibility.contacts);
    });

    test('copyWith supports archive, visibility and clearing a pin', () {
      final post = SocialPost(
        id: 'post-3',
        ownerUserId: 'owner-1',
        imageUrl: 'https://example.com/image.jpg',
        imagePath: 'profile_posts/owner-1/post-3/media_0.jpg',
        createdAt: DateTime(2026, 8, 16),
        section: SocialPostSection.posts,
        visibility: 'public',
        pinnedAt: DateTime(2026, 8, 16, 12),
      );

      final updated = post.copyWith(
        visibility: 'onlyMe',
        isArchived: true,
        clearPinnedAt: true,
      );

      expect(updated.visibilityMode, SocialPostVisibility.onlyMe);
      expect(updated.isArchived, isTrue);
      expect(updated.isPinned, isFalse);
    });

    test('repository limits a gallery to ten media items', () {
      expect(SocialPostRepository.maxMediaPerPost, 10);
    });

    test('supports all comment reaction types', () {
      expect(
        SocialPostCommentReaction.fromFirestore('like'),
        SocialPostCommentReaction.like,
      );
      expect(
        SocialPostCommentReaction.fromFirestore('dislike'),
        SocialPostCommentReaction.dislike,
      );
      expect(
        SocialPostCommentReaction.fromFirestore('heart'),
        SocialPostCommentReaction.heart,
      );
      expect(SocialPostCommentReaction.fromFirestore('unknown'), isNull);
    });
  });
}
