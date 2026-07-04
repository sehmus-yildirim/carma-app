import 'package:carisma/features/chats/data/chat_repository.dart';
import 'package:carisma/features/chats/data/chat_story_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatRecord visibility', () {
    test(
      'keeps archived and deleted chats out of the active list per user',
      () {
        final now = DateTime(2026, 6, 9, 12);
        final archivedChat = ChatRecord(
          id: 'chat-1',
          participants: const ['user-a', 'user-b'],
          status: ChatStatus.active,
          createdAt: now,
          updatedAt: now,
          archivedBy: const {'user-a': true},
        );
        final deletedChat = ChatRecord(
          id: 'chat-2',
          participants: const ['user-a', 'user-b'],
          status: ChatStatus.active,
          createdAt: now,
          updatedAt: now,
          deletedBy: const {'user-a': true},
        );

        expect(archivedChat.isVisibleInActiveListFor('user-a'), isFalse);
        expect(archivedChat.isVisibleInArchivedListFor('user-a'), isTrue);
        expect(archivedChat.isVisibleInActiveListFor('user-b'), isTrue);
        expect(deletedChat.isVisibleInActiveListFor('user-a'), isFalse);
        expect(deletedChat.isVisibleInActiveListFor('user-b'), isTrue);
      },
    );

    test('only shows blocked chats for the user who blocked them', () {
      final now = DateTime(2026, 6, 9, 12);
      final chat = ChatRecord(
        id: 'chat-1',
        participants: const ['user-a', 'user-b'],
        status: ChatStatus.blocked,
        createdAt: now,
        updatedAt: now,
        blockedBy: 'user-a',
      );

      expect(chat.isVisibleInBlockedListFor('user-a'), isTrue);
      expect(chat.isVisibleInBlockedListFor('user-b'), isFalse);
    });

    test('keeps deleted and blocked chats out of story-capable views', () {
      final now = DateTime(2026, 6, 9, 12);
      final archivedChat = ChatRecord(
        id: 'chat-1',
        participants: const ['user-a', 'user-b'],
        status: ChatStatus.archived,
        createdAt: now,
        updatedAt: now,
        archivedBy: const {'user-a': true},
      );
      final deletedChat = ChatRecord(
        id: 'chat-2',
        participants: const ['user-a', 'user-b'],
        status: ChatStatus.archived,
        createdAt: now,
        updatedAt: now,
        archivedBy: const {'user-a': true},
        deletedBy: const {'user-a': true},
      );
      final blockedChat = ChatRecord(
        id: 'chat-3',
        participants: const ['user-a', 'user-b'],
        status: ChatStatus.blocked,
        createdAt: now,
        updatedAt: now,
        blockedBy: 'user-a',
      );

      expect(archivedChat.isVisibleInArchivedListFor('user-a'), isTrue);
      expect(deletedChat.isVisibleInArchivedListFor('user-a'), isFalse);
      expect(blockedChat.isVisibleInActiveListFor('user-a'), isFalse);
      expect(blockedChat.isVisibleInArchivedListFor('user-a'), isFalse);
    });

    test('calculates unread state from last message and read timestamps', () {
      final lastMessageAt = DateTime(2026, 6, 9, 12);
      final chat = ChatRecord(
        id: 'chat-1',
        participants: const ['user-a', 'user-b'],
        status: ChatStatus.active,
        createdAt: lastMessageAt,
        updatedAt: lastMessageAt,
        lastMessageAt: lastMessageAt,
        lastReadAtBy: {
          'user-a': lastMessageAt.subtract(const Duration(minutes: 1)),
          'user-b': lastMessageAt.add(const Duration(minutes: 1)),
        },
      );

      expect(chat.hasUnreadFor('user-a'), isTrue);
      expect(chat.hasUnreadFor('user-b'), isFalse);
    });
  });

  group('ChatStoryRecord media state', () {
    test('detects expired stories and renderable image media', () {
      final now = DateTime.now();
      final story = ChatStoryRecord(
        id: 'user-a',
        ownerUserId: 'user-a',
        ownerDisplayName: 'CaRisma Nutzer',
        viewerUserIds: const ['user-a', 'user-b'],
        imageUrl: 'https://example.test/story.jpg',
        imagePath: 'chat_stories/user-a/202606091200.jpg',
        createdAt: now.subtract(const Duration(hours: 25)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );

      expect(story.isExpired, isTrue);
      expect(story.isVideo, isFalse);
      expect(story.hasRenderableMedia, isTrue);
    });

    test('requires a video url for video stories to render', () {
      final now = DateTime.now();
      final missingVideo = ChatStoryRecord(
        id: 'user-a',
        ownerUserId: 'user-a',
        ownerDisplayName: 'CaRisma Nutzer',
        viewerUserIds: const ['user-a', 'user-b'],
        imageUrl: '',
        imagePath: '',
        mediaType: 'video',
        videoPath: 'chat_stories/user-a/202606091200.mp4',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );
      final video = ChatStoryRecord(
        id: 'user-a',
        ownerUserId: 'user-a',
        ownerDisplayName: 'CaRisma Nutzer',
        viewerUserIds: const ['user-a', 'user-b'],
        imageUrl: '',
        imagePath: '',
        mediaType: 'video',
        videoUrl: 'https://example.test/story.mp4',
        videoPath: 'chat_stories/user-a/202606091200.mp4',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );

      expect(missingVideo.hasRenderableMedia, isFalse);
      expect(video.isVideo, isTrue);
      expect(video.hasRenderableMedia, isTrue);
    });
  });
}
