import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/data/social_post.dart';
import 'package:plaqa/features/profile/data/social_post_repository.dart';
import 'package:plaqa/features/profile/presentation/widgets/profile_post_details_sheet.dart';

void main() {
  testWidgets('comment replies keep useful width on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final post = SocialPost(
      id: 'debug-home-feed-layout',
      ownerUserId: 'owner',
      imageUrl: 'https://example.test/post.jpg',
      imagePath: 'social_posts/owner/post.jpg',
      createdAt: DateTime(2026, 8, 20),
      section: SocialPostSection.posts,
      visibility: 'public',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePostDetailsSheet(
            post: post,
            repository: _FakeSocialPostRepository(),
            viewerUserId: 'viewer',
            viewerDisplayName: 'Viewer User',
            viewerPhotoUrl: '',
            ownerDisplayName: 'Owner User',
            ownerPhotoUrl: '',
            isOwner: false,
            isDemo: true,
            demoMediaBuilder: (_, _) => const ColoredBox(color: Colors.black),
            onEdit: () {},
            onTogglePin: () {},
            onArchive: () {},
            onDelete: () {},
            onShare: () {},
            initialEngagement: ProfilePostEngagementView.comments,
            engagementOnly: true,
          ),
        ),
      ),
    );
    await tester.pump();

    final reply = find.text('Finde ich auch, besonders mit den Felgen.');
    expect(reply, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(reply);
    final lineTops = paragraph
        .getBoxesForSelection(
          const TextSelection(
            baseOffset: 0,
            extentOffset: 'Finde ich auch, besonders mit den Felgen.'.length,
          ),
        )
        .map((box) => box.top.round())
        .toSet();
    expect(lineTops.length, lessThanOrEqualTo(3));
    expect(
      tester.getTopRight(find.byTooltip('Antwortoptionen').first).dx,
      greaterThan(300),
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeSocialPostRepository implements SocialPostRepository {
  @override
  Stream<SocialPostPublicIdentity> watchPublicIdentity({
    required String userId,
    required String fallbackDisplayName,
    required String fallbackPhotoUrl,
  }) {
    return Stream<SocialPostPublicIdentity>.value(
      SocialPostPublicIdentity(
        displayName: fallbackDisplayName,
        photoUrl: fallbackPhotoUrl,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
