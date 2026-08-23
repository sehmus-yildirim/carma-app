import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/models/carisma_models.dart';
import '../../../shared/config/carisma_app_config.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../chats/data/chat_story_repository.dart';
import '../../chats/presentation/chats_screen.dart';
import '../data/profile_repository.dart';
import '../data/social_feed_repository.dart';
import '../data/social_post.dart';
import '../data/social_post_repository.dart';
import '../data/user_profile.dart' as profile_data;
import 'social_profile_screen.dart';
import 'widgets/profile_post_details_sheet.dart';

const String _debugHomeContentPrefix = 'plaqa-debug-home-';
const String _debugVehicleImage = 'asset://assets/images/debug_bmw_x6_m50d.png';

bool _isDebugHomeContent(String id) {
  return id.startsWith(_debugHomeContentPrefix);
}

List<SocialPost> _debugHomeFeedPosts(String currentUserId) {
  final now = DateTime.now();
  return <SocialPost>[
    SocialPost(
      id: '${_debugHomeContentPrefix}own-post',
      ownerUserId: currentUserId,
      imageUrl: _debugVehicleImage,
      imagePath: '',
      createdAt: now.subtract(const Duration(minutes: 18)),
      section: SocialPostSection.posts,
      visibility: SocialPostVisibility.public.firestoreValue,
      caption: 'Eine neue Aufnahme von meinem BMW X6 M50d.',
      vehicleLabel: 'BMW X6 M50d',
      locationLabel: 'Hamburg',
    ),
    SocialPost(
      id: '${_debugHomeContentPrefix}community-post',
      ownerUserId: '${_debugHomeContentPrefix}community-user',
      imageUrl: _debugVehicleImage,
      imagePath: '',
      createdAt: now.subtract(const Duration(hours: 2, minutes: 8)),
      section: SocialPostSection.posts,
      visibility: SocialPostVisibility.public.firestoreValue,
      caption: 'Abendrunde mit der Community.',
      vehicleLabel: 'BMW X6 M50d',
      locationLabel: 'Berlin',
    ),
  ];
}

class ProfileHomeFeedScreen extends StatefulWidget {
  const ProfileHomeFeedScreen({super.key, required this.userState});

  final AppUserState userState;

  @override
  State<ProfileHomeFeedScreen> createState() => _ProfileHomeFeedScreenState();
}

class _ProfileHomeFeedScreenState extends State<ProfileHomeFeedScreen>
    with AutomaticKeepAliveClientMixin {
  final ProfileRepository _profileRepository = ProfileRepository();
  final SocialPostRepository _postRepository = SocialPostRepository();
  final SocialFeedRepository _feedRepository = SocialFeedRepository();
  final ChatStoryRepository _storyRepository = ChatStoryRepository();

  late final String _currentUserId;
  late final Stream<profile_data.UserProfile?> _profileStream;
  late final Stream<List<SocialPost>> _feedStream;
  late final Stream<List<ChatStoryRecord>> _visibleStoriesStream;
  late final Stream<List<ChatStoryRecord>> _ownerStoriesStream;
  bool _isCreatingStory = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentUserId =
        FirebaseAuth.instance.currentUser?.uid ?? widget.userState.userId;
    _profileStream = _profileRepository.watchProfile(_currentUserId);
    _feedStream = _feedRepository.watchFollowingPosts(userId: _currentUserId);
    _visibleStoriesStream = _storyRepository.watchVisibleStories(
      userId: _currentUserId,
    );
    _ownerStoriesStream = _storyRepository.watchOwnerStories(
      ownerUserId: _currentUserId,
    );
  }

  Future<void> _createStory() async {
    if (_isCreatingStory) return;
    setState(() => _isCreatingStory = true);
    try {
      final story = await showProfileStoryComposer(
        context: context,
        currentUserId: _currentUserId,
      );
      if (!mounted || story == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Story wurde hinzugefügt.')));
    } on ProfileStoryCreationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story konnte nicht gespeichert werden.')),
      );
    } finally {
      if (mounted) setState(() => _isCreatingStory = false);
    }
  }

  Future<void> _openStory(
    ChatStoryRecord story,
    List<ChatStoryRecord> stories,
  ) {
    return showProfileStoryViewer(
      context: context,
      currentUserId: _currentUserId,
      story: story,
      stories: stories,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CaRismaBackground(
      child: SafeArea(
        bottom: false,
        child: StreamBuilder<profile_data.UserProfile?>(
          stream: _profileStream,
          builder: (context, profileSnapshot) {
            final profile = CaRismaAppConfig.storeScreenshotMode
                ? null
                : profileSnapshot.data;
            final displayName = CaRismaAppConfig.storeScreenshotMode
                ? CaRismaAppConfig.storeDemoDisplayName
                : _profileDisplayName(profile);
            final profilePhotoUrl = CaRismaAppConfig.storeScreenshotMode
                ? ''
                : profile?.photoUrl?.trim() ?? '';
            return CustomScrollView(
              key: const PageStorageKey<String>('profile-home-feed-scroll'),
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    CaRismaDesignTokens.mainScreenTopInset + 12,
                    14,
                    10,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _HomeStoriesSection(
                      currentUserId: _currentUserId,
                      currentUserDisplayName: displayName,
                      currentUserPhotoUrl: profilePhotoUrl,
                      visibleStoriesStream: _visibleStoriesStream,
                      ownerStoriesStream: _ownerStoriesStream,
                      isCreatingStory: _isCreatingStory,
                      onCreateStory: _createStory,
                      onOpenStory: _openStory,
                    ),
                  ),
                ),
                StreamBuilder<List<SocialPost>>(
                  stream: _feedStream,
                  builder: (context, feedSnapshot) {
                    if (feedSnapshot.hasError && !kDebugMode) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _HomeFeedMessage(
                          icon: Icons.cloud_off_rounded,
                          title: 'Beiträge konnten nicht geladen werden',
                          description:
                              'Prüfe deine Verbindung und versuche es erneut.',
                        ),
                      );
                    }
                    if (feedSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !feedSnapshot.hasData &&
                        !kDebugMode) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: SizedBox.square(
                            dimension: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        ),
                      );
                    }
                    final storedPosts = CaRismaAppConfig.storeScreenshotMode
                        ? const <SocialPost>[]
                        : feedSnapshot.data ?? const <SocialPost>[];
                    final posts = CaRismaAppConfig.storeScreenshotMode
                        ? _debugHomeFeedPosts(_currentUserId)
                        : kDebugMode
                        ? <SocialPost>[
                            ..._debugHomeFeedPosts(_currentUserId),
                            ...storedPosts,
                          ]
                        : storedPosts;
                    if (posts.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _HomeFeedMessage(
                          icon: Icons.dynamic_feed_outlined,
                          title: 'Noch keine neuen Beiträge',
                          description:
                              'Neue Beiträge von Profilen, denen du folgst, erscheinen hier.',
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        0,
                        14,
                        MediaQuery.paddingOf(context).bottom + 154,
                      ),
                      sliver: SliverList.separated(
                        itemCount: posts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => ProfileHomePostCard(
                          key: ValueKey(
                            'home-feed-${posts[index].ownerUserId}-${posts[index].id}',
                          ),
                          post: posts[index],
                          repository: _postRepository,
                          viewerUserId: _currentUserId,
                          viewerDisplayName: displayName,
                          viewerPhotoUrl: profilePhotoUrl,
                          identityOverride: _debugIdentityForPost(
                            posts[index],
                            currentUserId: _currentUserId,
                            currentUserDisplayName: displayName,
                            currentUserPhotoUrl: profilePhotoUrl,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

SocialPostPublicIdentity? _debugIdentityForPost(
  SocialPost post, {
  required String currentUserId,
  required String currentUserDisplayName,
  required String currentUserPhotoUrl,
}) {
  if (!kDebugMode || !_isDebugHomeContent(post.id)) return null;
  if (post.ownerUserId == currentUserId) {
    return SocialPostPublicIdentity(
      displayName: currentUserDisplayName,
      photoUrl: currentUserPhotoUrl,
    );
  }
  return const SocialPostPublicIdentity(
    displayName: CaRismaAppConfig.storeDemoShortName,
    photoUrl: '',
  );
}

List<ChatStoryRecord> _debugHomeStories({
  required String currentUserId,
  required String currentUserDisplayName,
  required String currentUserPhotoUrl,
}) {
  final now = DateTime.now();
  return <ChatStoryRecord>[
    ChatStoryRecord(
      id: '${_debugHomeContentPrefix}own-story',
      ownerUserId: currentUserId,
      ownerDisplayName: currentUserDisplayName,
      ownerPhotoUrl: currentUserPhotoUrl,
      viewerUserIds: <String>[currentUserId],
      imageUrl: _debugVehicleImage,
      imagePath: '',
      text: 'Meine Beispiel-Story',
      createdAt: now.subtract(const Duration(minutes: 12)),
      expiresAt: now.add(const Duration(hours: 23, minutes: 48)),
    ),
    ChatStoryRecord(
      id: '${_debugHomeContentPrefix}community-story',
      ownerUserId: '${_debugHomeContentPrefix}community-user',
      ownerDisplayName: CaRismaAppConfig.storeDemoShortName,
      ownerPhotoUrl: '',
      viewerUserIds: <String>[currentUserId],
      imageUrl: _debugVehicleImage,
      imagePath: '',
      text: 'Community-Ausfahrt',
      createdAt: now.subtract(const Duration(minutes: 42)),
      expiresAt: now.add(const Duration(hours: 23, minutes: 18)),
    ),
  ];
}

class _HomeStoriesSection extends StatelessWidget {
  const _HomeStoriesSection({
    required this.currentUserId,
    required this.currentUserDisplayName,
    required this.currentUserPhotoUrl,
    required this.visibleStoriesStream,
    required this.ownerStoriesStream,
    required this.isCreatingStory,
    required this.onCreateStory,
    required this.onOpenStory,
  });

  final String currentUserId;
  final String currentUserDisplayName;
  final String currentUserPhotoUrl;
  final Stream<List<ChatStoryRecord>> visibleStoriesStream;
  final Stream<List<ChatStoryRecord>> ownerStoriesStream;
  final bool isCreatingStory;
  final VoidCallback onCreateStory;
  final void Function(ChatStoryRecord, List<ChatStoryRecord>) onOpenStory;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatStoryRecord>>(
      stream: visibleStoriesStream,
      builder: (context, visibleSnapshot) {
        return StreamBuilder<List<ChatStoryRecord>>(
          stream: ownerStoriesStream,
          builder: (context, ownerSnapshot) {
            final storiesById = <String, ChatStoryRecord>{};
            if (!CaRismaAppConfig.storeScreenshotMode) {
              for (final story in <ChatStoryRecord>[
                ...?visibleSnapshot.data,
                ...?ownerSnapshot.data,
              ]) {
                if (!story.isExpired && story.hasRenderableMedia) {
                  storiesById[story.id] = story;
                }
              }
            }
            if (kDebugMode) {
              for (final story in _debugHomeStories(
                currentUserId: currentUserId,
                currentUserDisplayName: currentUserDisplayName,
                currentUserPhotoUrl: currentUserPhotoUrl,
              )) {
                storiesById.putIfAbsent(story.id, () => story);
              }
            }
            return ProfileStoryStrip(
              stories: storiesById.values.toList(growable: false),
              currentUserId: currentUserId,
              currentUserPhotoUrl: currentUserPhotoUrl,
              currentUserDisplayName: currentUserDisplayName,
              isAddingOwnStory: isCreatingStory,
              onAddOwnStory: onCreateStory,
              onOpenStory: onOpenStory,
            );
          },
        );
      },
    );
  }
}

class ProfileHomePostCard extends StatefulWidget {
  const ProfileHomePostCard({
    super.key,
    required this.post,
    required this.repository,
    required this.viewerUserId,
    required this.viewerDisplayName,
    required this.viewerPhotoUrl,
    this.identityOverride,
  });

  final SocialPost post;
  final SocialPostRepository repository;
  final String viewerUserId;
  final String viewerDisplayName;
  final String viewerPhotoUrl;
  final SocialPostPublicIdentity? identityOverride;

  @override
  State<ProfileHomePostCard> createState() => _ProfileHomePostCardState();
}

class _ProfileHomePostCardState extends State<ProfileHomePostCard> {
  int _mediaIndex = 0;
  bool _isLikeBusy = false;
  bool _debugLiked = false;

  Future<void> _toggleLike() async {
    if (_isLikeBusy) return;
    if (_isDebugPost) {
      setState(() => _debugLiked = !_debugLiked);
      return;
    }
    setState(() => _isLikeBusy = true);
    try {
      await widget.repository.toggleLike(
        post: widget.post,
        userId: widget.viewerUserId,
        displayName: widget.viewerDisplayName,
        photoUrl: widget.viewerPhotoUrl,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gefällt mir konnte nicht aktualisiert werden.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLikeBusy = false);
    }
  }

  bool get _isDebugPost {
    return kDebugMode && _isDebugHomeContent(widget.post.id);
  }

  Future<void> _sharePost() async {
    final link =
        'https://plaqa.de/profile/${widget.post.ownerUserId}/post/${widget.post.id}';
    try {
      await SharePlus.instance.share(
        ShareParams(text: 'Beitrag auf plaqa ansehen: $link'),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beitrag konnte gerade nicht geteilt werden.'),
        ),
      );
    }
  }

  Future<void> _openDetails(
    SocialPostPublicIdentity identity, {
    ProfilePostEngagementView? engagement,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfilePostDetailsSheet(
        post: widget.post,
        repository: widget.repository,
        viewerUserId: widget.viewerUserId,
        viewerDisplayName: widget.viewerDisplayName,
        viewerPhotoUrl: widget.viewerPhotoUrl,
        ownerDisplayName: identity.displayName,
        ownerPhotoUrl: identity.photoUrl,
        isOwner: false,
        isDemo: _isDebugPost,
        initialEngagement: engagement,
        engagementOnly: engagement != null,
        demoMediaBuilder: (_, media) => _FeedMediaItem(media: media),
        onEdit: () {},
        onTogglePin: () {},
        onArchive: () {},
        onDelete: () {},
        onShare: _sharePost,
      ),
    );
  }

  void _openOwnerProfile() {
    if (_isDebugPost && widget.post.ownerUserId != widget.viewerUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dieses Beispielprofil ist nur in der Vorschau aktiv.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      buildSocialProfileRoute(
        profileUserId: widget.post.ownerUserId,
        readOnly: widget.post.ownerUserId != widget.viewerUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return StreamBuilder<SocialPostPublicIdentity>(
      stream: widget.identityOverride == null
          ? widget.repository.watchPublicIdentity(
              userId: post.ownerUserId,
              fallbackDisplayName: 'plaqa Nutzer',
              fallbackPhotoUrl: '',
            )
          : Stream<SocialPostPublicIdentity>.value(widget.identityOverride!),
      builder: (context, identitySnapshot) {
        final identity =
            identitySnapshot.data ??
            const SocialPostPublicIdentity(
              displayName: 'plaqa Nutzer',
              photoUrl: '',
            );
        return GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FeedPostHeader(
                identity: identity,
                createdAt: post.createdAt,
                onTap: _openOwnerProfile,
              ),
              _FeedPostMedia(
                post: post,
                currentIndex: _mediaIndex,
                onIndexChanged: (index) => setState(() => _mediaIndex = index),
                onTap: null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StreamBuilder<bool>(
                          stream: _isDebugPost
                              ? Stream<bool>.value(_debugLiked)
                              : widget.repository.watchLikedBy(
                                  post: post,
                                  userId: widget.viewerUserId,
                                ),
                          initialData: _debugLiked,
                          builder: (context, likedSnapshot) {
                            final isLiked = likedSnapshot.data ?? false;
                            return _FeedActionButton(
                              tooltip: isLiked
                                  ? 'Gefällt mir entfernen'
                                  : 'Gefällt mir',
                              icon: isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isLiked
                                  ? CaRismaDesignTokens.blueBright
                                  : Colors.white,
                              onTap: _isLikeBusy ? null : _toggleLike,
                            );
                          },
                        ),
                        StreamBuilder<int>(
                          stream: _isDebugPost
                              ? Stream<int>.value(_debugLiked ? 6 : 5)
                              : widget.repository.watchLikeCount(post),
                          initialData: _isDebugPost ? (_debugLiked ? 6 : 5) : 0,
                          builder: (context, snapshot) => _FeedCountButton(
                            label: '${snapshot.data ?? 0}',
                            tooltip: 'Gefällt mir Angaben',
                            onTap: () => _openDetails(
                              identity,
                              engagement: ProfilePostEngagementView.likes,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FeedActionButton(
                          tooltip: 'Kommentare',
                          icon: Icons.chat_bubble_outline_rounded,
                          onTap: () => _openDetails(
                            identity,
                            engagement: ProfilePostEngagementView.comments,
                          ),
                        ),
                        StreamBuilder<List<SocialPostComment>>(
                          stream: _isDebugPost
                              ? Stream<List<SocialPostComment>>.value(
                                  const <SocialPostComment>[],
                                )
                              : widget.repository.watchComments(post),
                          initialData: const <SocialPostComment>[],
                          builder: (context, snapshot) => _FeedCountButton(
                            label: _isDebugPost
                                ? '5'
                                : '${snapshot.data?.length ?? 0}',
                            tooltip: 'Kommentare',
                            onTap: () => _openDetails(
                              identity,
                              engagement: ProfilePostEngagementView.comments,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if ((post.locationLabel ?? '').trim().isNotEmpty)
                          Flexible(
                            child: _FeedLocation(label: post.locationLabel!),
                          ),
                        _FeedActionButton(
                          tooltip: 'Beitrag teilen',
                          icon: Icons.send_outlined,
                          onTap: _sharePost,
                        ),
                      ],
                    ),
                    if ((post.caption ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${identity.displayName}  ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(text: post.caption!.trim()),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CaRismaDesignTokens.textSecondary,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeedPostHeader extends StatelessWidget {
  const _FeedPostHeader({
    required this.identity,
    required this.createdAt,
    required this.onTap,
  });

  final SocialPostPublicIdentity identity;
  final DateTime createdAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _FeedAvatar(
                photoUrl: identity.photoUrl,
                displayName: identity.displayName,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      identity.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _relativePostTime(createdAt),
                      style: const TextStyle(
                        color: CaRismaDesignTokens.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedPostMedia extends StatelessWidget {
  const _FeedPostMedia({
    required this.post,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.onTap,
  });

  final SocialPost post;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final media = post.resolvedMedia;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: media.length,
            onPageChanged: onIndexChanged,
            itemBuilder: (context, index) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: _FeedMediaItem(media: media[index]),
            ),
          ),
          if (media.length > 1)
            Positioned(
              top: 10,
              right: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.64),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Text(
                    '${currentIndex + 1}/${media.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedMediaItem extends StatelessWidget {
  const _FeedMediaItem({required this.media});

  final SocialPostMedia media;

  @override
  Widget build(BuildContext context) {
    if (media.isVideo) {
      return const ColoredBox(
        color: CaRismaDesignTokens.surface2,
        child: Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 56,
          ),
        ),
      );
    }
    if (media.url.startsWith('asset://')) {
      return Image.asset(
        media.url.substring('asset://'.length),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: CaRismaDesignTokens.surface2,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: CaRismaDesignTokens.textMuted,
              size: 38,
            ),
          ),
        ),
      );
    }
    return Image.network(
      media.url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const ColoredBox(
          color: CaRismaDesignTokens.surface2,
          child: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => const ColoredBox(
        color: CaRismaDesignTokens.surface2,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: CaRismaDesignTokens.textMuted,
            size: 38,
          ),
        ),
      ),
    );
  }
}

class _FeedAvatar extends StatelessWidget {
  const _FeedAvatar({required this.photoUrl, required this.displayName});

  final String photoUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty
        ? 'P'
        : displayName.trim().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 20,
      backgroundColor: CaRismaDesignTokens.controlSurface,
      backgroundImage: photoUrl.trim().isEmpty
          ? null
          : NetworkImage(photoUrl.trim()),
      child: photoUrl.trim().isEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class _FeedActionButton extends StatelessWidget {
  const _FeedActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: Icon(icon, color: color, size: 23),
    );
  }
}

class _FeedCountButton extends StatelessWidget {
  const _FeedCountButton({
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedLocation extends StatelessWidget {
  const _FeedLocation({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 16,
            color: CaRismaDesignTokens.textMuted,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CaRismaDesignTokens.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeFeedMessage extends StatelessWidget {
  const _HomeFeedMessage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 160),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CaRismaDesignTokens.textMuted, size: 34),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CaRismaDesignTokens.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _profileDisplayName(profile_data.UserProfile? profile) {
  final displayName = profile?.displayName.trim() ?? '';
  if (displayName.isNotEmpty) return displayName;
  final firstName = profile?.firstName.trim() ?? '';
  final lastName = profile?.lastName.trim() ?? '';
  if (firstName.isEmpty && lastName.isEmpty) return 'plaqa Nutzer';
  final lastInitial = lastName.isEmpty ? '' : '${lastName.substring(0, 1)}.';
  return <String>[
    firstName,
    lastInitial,
  ].where((part) => part.isNotEmpty).join(' ');
}

String _relativePostTime(DateTime createdAt) {
  final difference = DateTime.now().difference(createdAt);
  if (difference.isNegative || difference.inMinutes < 1) return 'Gerade eben';
  if (difference.inMinutes < 60) return 'Vor ${difference.inMinutes} Min.';
  if (difference.inHours < 24) return 'Vor ${difference.inHours} Std.';
  if (difference.inDays < 7) return 'Vor ${difference.inDays} Tagen';
  return '${createdAt.day.toString().padLeft(2, '0')}.'
      '${createdAt.month.toString().padLeft(2, '0')}.'
      '${createdAt.year}';
}
