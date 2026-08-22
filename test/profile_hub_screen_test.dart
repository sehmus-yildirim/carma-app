import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/chats/data/chat_story_repository.dart';
import 'package:plaqa/features/chats/presentation/chats_screen.dart';
import 'package:plaqa/features/profile/presentation/profile_hub_screen.dart';

void main() {
  testWidgets('switches between home and profile by tap and swipe', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileHubView(
            homePage: Center(child: Text('Startseiteninhalt')),
            profilePage: Center(child: Text('Profilinhalt')),
          ),
        ),
      ),
    );

    expect(find.text('Startseiteninhalt').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Startseite'), findsOneWidget);
    expect(find.byTooltip('Profil'), findsOneWidget);

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Profilinhalt').hitTestable(), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('profile-hub-pages')),
      const Offset(320, 0),
      900,
    );
    await tester.pumpAndSettle();
    expect(find.text('Startseiteninhalt').hitTestable(), findsOneWidget);
  });

  testWidgets(
    'keeps the profile switcher directly above the bottom navigation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            extendBody: true,
            body: const ProfileHubView(
              homePage: Center(child: Text('Startseiteninhalt')),
              profilePage: Center(child: Text('Profilinhalt')),
            ),
            bottomNavigationBar: const SizedBox(
              key: ValueKey('test-bottom-navigation'),
              height: 80,
            ),
          ),
        ),
      );

      final switcherBottom = tester
          .getBottomLeft(find.byTooltip('Startseite'))
          .dy;
      final navigationTop = tester
          .getTopLeft(find.byKey(const ValueKey('test-bottom-navigation')))
          .dy;

      expect(navigationTop - switcherBottom, closeTo(4, 0.1));

      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Profilinhalt').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('home story strip opens the current users story', (tester) async {
    var opened = false;
    final story = ChatStoryRecord(
      id: 'story-1',
      ownerUserId: 'user-1',
      ownerDisplayName: 'Mila K.',
      imageUrl: 'https://example.test/story.jpg',
      imagePath: 'chat_stories/user-1/story.jpg',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileStoryStrip(
            stories: [story],
            currentUserId: 'user-1',
            currentUserPhotoUrl: '',
            currentUserDisplayName: 'Mila K.',
            isAddingOwnStory: false,
            onAddOwnStory: () {},
            onOpenStory: (_, _) => opened = true,
          ),
        ),
      ),
    );

    expect(find.text('Deine Story'), findsOneWidget);
    await tester.tap(find.text('Deine Story'));
    expect(opened, isTrue);
  });

  testWidgets(
    'story strip uses profile fallbacks and distinguishes new and viewed stories',
    (tester) async {
      final now = DateTime.now();
      final newStory = ChatStoryRecord(
        id: 'story-new',
        ownerUserId: 'user-new',
        ownerDisplayName: 'Mila Kaya',
        ownerPhotoUrl: '',
        viewerUserIds: const ['viewer'],
        imageUrl: 'https://example.test/story-medium-new.jpg',
        imagePath: 'chat_stories/user-new/story-new.jpg',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );
      final viewedStory = ChatStoryRecord(
        id: 'story-viewed',
        ownerUserId: 'user-viewed',
        ownerDisplayName: 'Emre Aydin',
        ownerPhotoUrl: '',
        viewerUserIds: const ['viewer'],
        imageUrl: 'https://example.test/story-medium-viewed.jpg',
        imagePath: 'chat_stories/user-viewed/story-viewed.jpg',
        viewedAtBy: {'viewer': now},
        createdAt: now.subtract(const Duration(minutes: 1)),
        expiresAt: now.add(const Duration(hours: 24)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileStoryStrip(
              stories: [newStory, viewedStory],
              currentUserId: 'viewer',
              currentUserPhotoUrl: '',
              currentUserDisplayName: 'Viewer User',
              isAddingOwnStory: false,
              onAddOwnStory: () {},
              onOpenStory: (_, _) {},
            ),
          ),
        ),
      );

      expect(find.text('MK'), findsOneWidget);
      expect(find.text('EA'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Neue Story von Mila Kaya')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Gesehene Story von Emre Aydin')),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    },
  );
}
