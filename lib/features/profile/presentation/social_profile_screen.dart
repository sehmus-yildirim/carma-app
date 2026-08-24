import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/models/carisma_models.dart';
import '../../../shared/config/carisma_app_config.dart';
import '../../../shared/plate/dach_plate_presentation.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_license_plate_preview.dart';
import '../../../shared/widgets/carisma_secondary_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../chats/data/chat_story_repository.dart';
import '../../chats/data/chat_repository.dart';
import '../../chats/presentation/chats_screen.dart';
import '../data/follow_repository.dart';
import '../data/profile_media_storage.dart';
import '../data/profile_repository.dart';
import '../data/profile_vehicle.dart';
import '../data/profile_vehicle_gallery_media.dart';
import '../data/profile_vehicle_gallery_repository.dart';
import '../data/profile_vehicle_hero_service.dart';
import '../data/profile_vehicle_modification.dart';
import '../data/profile_vehicle_modification_repository.dart';
import '../data/profile_vehicle_repository.dart';
import '../data/profile_vehicle_timeline_entry.dart';
import '../data/profile_vehicle_timeline_repository.dart';
import '../data/social_post.dart';
import '../data/social_post_repository.dart';
import '../data/user_profile.dart' as profile_data;
import 'widgets/profile_vehicle_details_sheet.dart';
import 'widgets/profile_vehicle_editor_sheet.dart';
import 'widgets/profile_vehicle_modification_sheet.dart';
import 'widgets/profile_vehicle_panel.dart';
import 'widgets/profile_vehicle_timeline_sheet.dart';
import 'widgets/profile_photo_crop_screen.dart';
import 'widgets/profile_post_details_sheet.dart';
import 'widgets/profile_post_gallery_screen.dart';

const String _debugProfileContentPrefix = 'plaqa-debug-';

final List<SocialPost> _debugSocialPosts = <SocialPost>[
  SocialPost(
    id: '${_debugProfileContentPrefix}post-1',
    ownerUserId: _debugProfileContentPrefix,
    imageUrl: 'debug://bmw-x6-front',
    imagePath: '',
    createdAt: DateTime(2026, 8, 16, 18, 30),
    section: SocialPostSection.posts,
    visibility: 'private',
    caption: 'Schwarzer BMW X6 M50d, Baujahr 2015.',
    vehicleLabel: 'BMW X6 M50d',
    locationLabel: 'Hamburg',
  ),
  SocialPost(
    id: '${_debugProfileContentPrefix}post-4',
    ownerUserId: _debugProfileContentPrefix,
    imageUrl: 'debug://bmw-x6-interior',
    imagePath: '',
    createdAt: DateTime(2026, 8, 13, 14, 20),
    section: SocialPostSection.posts,
    visibility: 'private',
    caption: 'Innenraum des X6 M50d in Schwarz.',
    vehicleLabel: 'BMW X6 M50d',
    locationLabel: 'Hamburg',
  ),
  SocialPost(
    id: '${_debugProfileContentPrefix}post-5',
    ownerUserId: _debugProfileContentPrefix,
    imageUrl: 'debug://bmw-x6-night',
    imagePath: '',
    createdAt: DateTime(2026, 8, 12, 22, 5),
    section: SocialPostSection.posts,
    visibility: 'private',
    caption: 'Nachtaufnahme mit dem BMW X6 M50d.',
    vehicleLabel: 'BMW X6 M50d',
    locationLabel: 'Hamburg',
  ),
  SocialPost(
    id: '${_debugProfileContentPrefix}post-2',
    ownerUserId: _debugProfileContentPrefix,
    imageUrl: 'debug://bmw-x6-road',
    imagePath: '',
    createdAt: DateTime(2026, 8, 15, 20, 10),
    section: SocialPostSection.posts,
    visibility: 'private',
    caption: 'Abendfahrt mit dem X6 durch Hamburg.',
    vehicleLabel: 'BMW X6 M50d',
    locationLabel: 'Hamburg',
  ),
  SocialPost(
    id: '${_debugProfileContentPrefix}post-3',
    ownerUserId: _debugProfileContentPrefix,
    imageUrl: 'debug://bmw-x6-detail',
    imagePath: '',
    createdAt: DateTime(2026, 8, 14, 16, 45),
    section: SocialPostSection.posts,
    visibility: 'private',
    caption: 'Detailaufnahme vor dem nächsten Treffen.',
    vehicleLabel: 'BMW X6 M50d',
    locationLabel: 'Hamburg',
  ),
];

const List<ProfileVehicleGalleryMedia> _debugVehicleGallery =
    <ProfileVehicleGalleryMedia>[
      ProfileVehicleGalleryMedia(
        id: '${_debugProfileContentPrefix}gallery-front',
        ownerUserId: _debugProfileContentPrefix,
        vehicleId: debugProfileVehicleId,
        mediaUrl: 'asset://assets/images/debug_bmw_x6_m50d.png',
        mediaPath: '',
        caption: 'Frontansicht des BMW X6 M50d.',
        isMain: true,
        visibility: ProfileVehicleVisibility.contacts,
      ),
      ProfileVehicleGalleryMedia(
        id: '${_debugProfileContentPrefix}gallery-side',
        ownerUserId: _debugProfileContentPrefix,
        vehicleId: debugProfileVehicleId,
        mediaUrl: 'asset://assets/images/debug_bmw_x6_m50d.png',
        mediaPath: '',
        category: ProfileVehicleGalleryCategory.interior,
        caption: 'Innenraum und schwarze Lederausstattung.',
        visibility: ProfileVehicleVisibility.contacts,
      ),
      ProfileVehicleGalleryMedia(
        id: '${_debugProfileContentPrefix}gallery-wheels',
        ownerUserId: _debugProfileContentPrefix,
        vehicleId: debugProfileVehicleId,
        mediaUrl: 'asset://assets/images/debug_bmw_x6_m50d.png',
        mediaPath: '',
        category: ProfileVehicleGalleryCategory.modifications,
        caption: 'Felgen und Fahrwerk im Detail.',
        visibility: ProfileVehicleVisibility.contacts,
      ),
      ProfileVehicleGalleryMedia(
        id: '${_debugProfileContentPrefix}gallery-night',
        ownerUserId: _debugProfileContentPrefix,
        vehicleId: debugProfileVehicleId,
        mediaUrl: 'asset://assets/images/debug_bmw_x6_m50d.png',
        mediaPath: '',
        category: ProfileVehicleGalleryCategory.exterior,
        caption: 'Abendaufnahme in Hamburg.',
        visibility: ProfileVehicleVisibility.contacts,
      ),
    ];

final List<ProfileVehicleModification> _debugVehicleModifications =
    <ProfileVehicleModification>[
      ProfileVehicleModification(
        id: '${_debugProfileContentPrefix}mod-wheels',
        ownerUserId: _debugProfileContentPrefix,
        vehicleId: debugProfileVehicleId,
        title: '22-Zoll M-Felgen',
        category: ProfileVehicleModificationCategory.wheels,
        manufacturer: 'BMW M',
        product: 'Doppelspeiche',
        modifiedAt: DateTime(2024, 4, 12),
        isRegistered: true,
        visibility: ProfileVehicleVisibility.contacts,
      ),
      ProfileVehicleModification(
        id: '${_debugProfileContentPrefix}mod-software',
        ownerUserId: _debugProfileContentPrefix,
        vehicleId: debugProfileVehicleId,
        title: 'Softwareoptimierung',
        category: ProfileVehicleModificationCategory.software,
        manufacturer: 'M Performance',
        powerChangeHp: 32,
        modifiedAt: DateTime(2025, 3, 8),
        isRegistered: true,
        visibility: ProfileVehicleVisibility.contacts,
      ),
      ProfileVehicleModification(
        id: '${_debugProfileContentPrefix}mod-suspension',
        ownerUserId: _debugProfileContentPrefix,
        vehicleId: debugProfileVehicleId,
        title: 'Sportfahrwerk',
        category: ProfileVehicleModificationCategory.suspension,
        manufacturer: 'KW',
        product: 'Street Comfort',
        modifiedAt: DateTime(2025, 6, 21),
        visibility: ProfileVehicleVisibility.contacts,
      ),
    ];

final List<ProfileVehicleTimelineEntry> _debugVehicleTimeline =
    <ProfileVehicleTimelineEntry>[
      ProfileVehicleTimelineEntry(
        id: '${_debugProfileContentPrefix}timeline-acquired',
        ownerUserId: _debugProfileContentPrefix,
        vehicleId: debugProfileVehicleId,
        type: ProfileVehicleTimelineType.vehicleAcquired,
        title: 'Fahrzeug übernommen',
        description: 'Der BMW X6 M50d zieht ins Profil ein.',
        eventDate: DateTime(2023, 5, 1),
        visibility: ProfileVehicleVisibility.contacts,
      ),
      ProfileVehicleTimelineEntry(
        id: '${_debugProfileContentPrefix}timeline-wheels',
        ownerUserId: _debugProfileContentPrefix,
        vehicleId: debugProfileVehicleId,
        type: ProfileVehicleTimelineType.wheelsInstalled,
        title: 'Neue Felgen montiert',
        description: '22-Zoll M-Felgen für die Sommersaison.',
        eventDate: DateTime(2024, 4, 12),
        visibility: ProfileVehicleVisibility.contacts,
      ),
      ProfileVehicleTimelineEntry(
        id: '${_debugProfileContentPrefix}timeline-service',
        ownerUserId: _debugProfileContentPrefix,
        vehicleId: debugProfileVehicleId,
        type: ProfileVehicleTimelineType.maintenance,
        title: 'Große Wartung',
        description: 'Öl, Filter und Bremsen geprüft.',
        eventDate: DateTime(2025, 2, 18),
        visibility: ProfileVehicleVisibility.contacts,
      ),
      ProfileVehicleTimelineEntry(
        id: '${_debugProfileContentPrefix}timeline-trip',
        ownerUserId: _debugProfileContentPrefix,
        vehicleId: debugProfileVehicleId,
        type: ProfileVehicleTimelineType.trip,
        title: 'Ausfahrt an die Ostsee',
        description: 'Wochenendtour ab Hamburg.',
        eventDate: DateTime(2026, 7, 19),
        visibility: ProfileVehicleVisibility.contacts,
      ),
    ];

bool _isDebugProfileContent(String id) =>
    id.startsWith(_debugProfileContentPrefix);

Route<void> buildSocialProfileRoute({
  required String profileUserId,
  bool readOnly = false,
}) {
  return MaterialPageRoute<void>(
    builder: (_) => SocialProfileScreen(
      profileUserId: profileUserId,
      isOwnProfile: false,
      readOnly: readOnly,
    ),
  );
}

class SocialProfileScreen extends StatefulWidget {
  const SocialProfileScreen({
    super.key,
    this.userState,
    this.profileUserId,
    this.isOwnProfile = true,
    this.readOnly = false,
    this.bottomContentInset = 0,
  });

  final AppUserState? userState;
  final String? profileUserId;
  final bool isOwnProfile;
  final bool readOnly;
  final double bottomContentInset;

  @override
  State<SocialProfileScreen> createState() => _SocialProfileScreenState();
}

class _SocialProfileScreenState extends State<SocialProfileScreen> {
  final ProfileRepository _profileRepository = ProfileRepository();
  final ProfileMediaStorage _profileMediaStorage = ProfileMediaStorage();
  final SocialPostRepository _socialPostRepository = SocialPostRepository();
  final ChatStoryRepository _storyRepository = ChatStoryRepository();
  final ChatRepository _chatRepository = FirestoreChatRepository();
  final FollowRepository _followRepository = FollowRepository();
  final ProfileVehicleRepository _profileVehicleRepository =
      ProfileVehicleRepository();
  final ProfileVehicleGalleryRepository _profileVehicleGalleryRepository =
      ProfileVehicleGalleryRepository();
  final ProfileVehicleHeroService _profileVehicleHeroService =
      ProfileVehicleHeroService();
  final ProfileVehicleModificationRepository
  _profileVehicleModificationRepository =
      ProfileVehicleModificationRepository();
  final ProfileVehicleTimelineRepository _profileVehicleTimelineRepository =
      ProfileVehicleTimelineRepository();
  final ImagePicker _imagePicker = ImagePicker();
  late final Stream<int> _followerCountStream;
  late final Stream<int> _followingCountStream;
  late final Stream<List<ProfileVehicle>> _vehiclesStream;
  Stream<FollowSummary>? _followSummaryStream;
  int _selectedTab = 0;
  bool _isFollowActionBusy = false;
  bool _isCreatingStory = false;
  bool _legacyVehicleSyncScheduled = false;
  bool _isPreviewingOwnProfile = false;
  final Set<String> _busyHeroVehicleIds = <String>{};
  final Set<String> _autoHeroRequestedVehicleIds = <String>{};

  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? widget.userState?.userId ?? '';

  String get _userId {
    final targetUserId = widget.profileUserId?.trim() ?? '';
    return targetUserId.isNotEmpty ? targetUserId : _currentUserId;
  }

  bool get _isOwnProfile => widget.isOwnProfile && _userId == _currentUserId;
  bool get _canManageOwnProfile => _isOwnProfile && !_isPreviewingOwnProfile;

  @override
  void initState() {
    super.initState();
    final profileUserId = _userId;
    final currentUserId = _currentUserId;
    _followerCountStream = profileUserId.isEmpty
        ? Stream<int>.value(0)
        : _followRepository
              .watchFollowers(profileUserId)
              .map((relationships) => relationships.length);
    _followingCountStream = profileUserId.isEmpty
        ? Stream<int>.value(0)
        : _followRepository
              .watchFollowing(profileUserId)
              .map((relationships) => relationships.length);
    _vehiclesStream = profileUserId.isEmpty
        ? Stream<List<ProfileVehicle>>.value(const <ProfileVehicle>[])
        : _isOwnProfile
        ? _profileVehicleRepository.watchOwnerVehicles(profileUserId)
        : _profileVehicleRepository.watchVisibleVehicles(profileUserId);
    if (!widget.readOnly &&
        !_isOwnProfile &&
        currentUserId.isNotEmpty &&
        profileUserId.isNotEmpty) {
      _followSummaryStream = _followRepository.watchSummary(
        currentUserId: currentUserId,
        profileUserId: profileUserId,
      );
    }
    if (!_isOwnProfile &&
        profileUserId.isNotEmpty &&
        currentUserId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _profileRepository.recordProfileView(profileUserId).catchError((_) {});
      });
    }
  }

  Future<void> _handleFollowAction(
    profile_data.UserProfile? profile,
    FollowSummary summary,
  ) async {
    if (_isFollowActionBusy || _isOwnProfile) return;
    if (widget.readOnly) return;
    final currentUserId = _currentUserId;
    final profileUserId = _userId;
    if (currentUserId.isEmpty || profileUserId.isEmpty) return;

    setState(() => _isFollowActionBusy = true);
    try {
      switch (summary.state) {
        case ProfileFollowState.notFollowing:
        case ProfileFollowState.followedBy:
          await _followRepository.follow(
            followerUserId: currentUserId,
            followedUserId: profileUserId,
            targetIsPrivate: profile?.isPrivateProfile ?? true,
          );
          break;
        case ProfileFollowState.followRequested:
        case ProfileFollowState.following:
        case ProfileFollowState.mutual:
          await _followRepository.unfollow(
            followerUserId: currentUserId,
            followedUserId: profileUserId,
          );
          break;
        case ProfileFollowState.blocked:
        case ProfileFollowState.restricted:
          break;
      }
    } catch (error) {
      debugPrint('Vehicle hero request could not start: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Der Follow-Status konnte nicht geändert werden.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isFollowActionBusy = false);
    }
  }

  bool _canViewFollowList(
    profile_data.UserProfile? profile,
    FollowSummary summary, {
    required bool followers,
  }) {
    if (widget.readOnly) return false;
    if (_isOwnProfile) return true;
    final visibility = followers
        ? profile?.followersVisibility ?? 'onlyMe'
        : profile?.followingVisibility ?? 'onlyMe';
    if (visibility == 'contacts') return true;
    if (visibility == 'followers') {
      return summary.state == ProfileFollowState.following ||
          summary.state == ProfileFollowState.mutual;
    }
    return false;
  }

  Future<void> _showFollowList(
    profile_data.UserProfile? profile,
    FollowSummary summary, {
    required bool followers,
  }) async {
    if (!_canViewFollowList(profile, summary, followers: followers)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            followers
                ? 'Die Follower-Liste ist nicht sichtbar.'
                : 'Die Gefolgt-Liste ist nicht sichtbar.',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FollowListSheet(
        title: followers ? 'Follower' : 'Gefolgt',
        relationships: followers
            ? _followRepository.watchFollowers(_userId)
            : _followRepository.watchFollowing(_userId),
        showFollower: followers,
        canManage: _isOwnProfile,
        onRemove: (relationship) async {
          if (followers) {
            await _followRepository.removeFollower(
              profileUserId: _userId,
              followerUserId: relationship.followerUserId,
            );
          } else {
            await _followRepository.unfollow(
              followerUserId: _userId,
              followedUserId: relationship.followedUserId,
            );
          }
        },
      ),
    );
  }

  Future<void> _showFollowRequests() async {
    if (!_isOwnProfile) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      useSafeArea: true,

      builder: (context) => _FollowRequestsSheet(
        requests: _followRepository.watchFollowRequests(_userId),
        onAccept: _followRepository.acceptRequest,
        onDecline: _followRepository.declineRequest,
      ),
    );
  }

  Future<void> _openExistingChat(profile_data.UserProfile? profile) async {
    final currentUserId = _currentUserId.trim();
    final profileUserId = _userId.trim();
    if (currentUserId.isEmpty || profileUserId.isEmpty || _isOwnProfile) return;

    try {
      final chats = await _chatRepository.loadChats(userId: currentUserId);
      ChatRecord? matchingChat;
      for (final chat in chats) {
        if (chat.participants.contains(profileUserId) &&
            !chat.isDeletedFor(currentUserId)) {
          matchingChat = chat;
          break;
        }
      }
      if (!mounted) return;
      if (matchingChat == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ein Chat ist erst nach einer angenommenen Kontaktanfrage verfügbar.',
            ),
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        buildChatConversationRoute(
          chatId: matchingChat.id,
          displayName: matchingChat.displayNameFor(currentUserId),
          profilePhotoUrl: matchingChat.profilePhotoUrlFor(currentUserId),
          vehicleModel: matchingChat.vehicleModelLabel,
          vehicleColor: matchingChat.vehicleColorLabel,
          displayPlate: matchingChat.displayPlate,
          profileUserId: profileUserId,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Der Chat konnte gerade nicht geöffnet werden.'),
        ),
      );
    }
  }

  Widget _buildProfileHero(
    profile_data.UserProfile? profile,
    int postCount, {
    required ProfileVehicle? primaryVehicle,
    required bool compact,
  }) {
    final storyStream = CaRismaAppConfig.storeScreenshotMode
        ? Stream<List<ChatStoryRecord>>.value(const <ChatStoryRecord>[])
        : _currentUserId.trim().isEmpty
        ? Stream<List<ChatStoryRecord>>.value(const <ChatStoryRecord>[])
        : _isOwnProfile
        ? _storyRepository.watchOwnerStories(ownerUserId: _userId)
        : _storyRepository.watchVisibleStories(userId: _currentUserId);

    return StreamBuilder<List<ChatStoryRecord>>(
      stream: storyStream,
      builder: (context, storySnapshot) {
        final profileStories =
            (storySnapshot.data ?? const <ChatStoryRecord>[])
                .where(
                  (story) =>
                      story.ownerUserId.trim() == _userId.trim() &&
                      !story.isExpired &&
                      story.hasRenderableMedia,
                )
                .toList(growable: false)
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final activeStory = profileStories.isEmpty ? null : profileStories.last;

        return StreamBuilder<FollowSummary>(
          stream: _followSummaryStream,
          initialData: const FollowSummary(
            state: ProfileFollowState.notFollowing,
          ),
          builder: (context, followSnapshot) {
            final summary =
                followSnapshot.data ??
                const FollowSummary(state: ProfileFollowState.notFollowing);
            final canViewFollowers = _canViewFollowList(
              profile,
              summary,
              followers: true,
            );
            final canViewFollowing = _canViewFollowList(
              profile,
              summary,
              followers: false,
            );

            return StreamBuilder<int>(
              stream: canViewFollowers ? _followerCountStream : null,
              initialData: canViewFollowers ? 0 : null,
              builder: (context, followerSnapshot) {
                return StreamBuilder<int>(
                  stream: canViewFollowing ? _followingCountStream : null,
                  initialData: canViewFollowing ? 0 : null,
                  builder: (context, followingSnapshot) {
                    return Column(
                      children: [
                        _ProfileHeroCard(
                          profile: profile,
                          primaryVehicle: primaryVehicle,
                          compact: compact,
                          postCount: postCount,
                          followerCount: CaRismaAppConfig.storeScreenshotMode
                              ? 128
                              : followerSnapshot.hasError
                              ? null
                              : followerSnapshot.data,
                          followingCount: CaRismaAppConfig.storeScreenshotMode
                              ? 84
                              : followingSnapshot.hasError
                              ? null
                              : followingSnapshot.data,
                          followState: summary.state,
                          isFollowActionBusy: _isFollowActionBusy,
                          isCreatingStory: _isCreatingStory,
                          isOwnProfile: _canManageOwnProfile,
                          isReadOnly:
                              widget.readOnly || _isPreviewingOwnProfile,
                          showPreviewToggle: _isOwnProfile,
                          isPreviewing: _isPreviewingOwnProfile,
                          onPreviewToggle: () => setState(
                            () => _isPreviewingOwnProfile =
                                !_isPreviewingOwnProfile,
                          ),
                          activeStory: activeStory,
                          onEditProfile: _canManageOwnProfile
                              ? () => _showEditPublicProfileSheet(profile)
                              : null,
                          onAvatarTap: activeStory != null
                              ? () => _openProfileStory(
                                  activeStory,
                                  profileStories,
                                )
                              : _canManageOwnProfile
                              ? () => _showProfileIdentityActions(profile)
                              : null,
                          onAvatarLongPress: _canManageOwnProfile
                              ? () => _showProfileIdentityActions(profile)
                              : null,
                          onAddStory: _canManageOwnProfile
                              ? () => _showProfileCreateActions(profile)
                              : null,
                          onFollow: () => _handleFollowAction(profile, summary),
                          onMessage: () => _openExistingChat(profile),
                          onFollowersTap: canViewFollowers
                              ? () => _showFollowList(
                                  profile,
                                  summary,
                                  followers: true,
                                )
                              : null,
                          onFollowingTap: canViewFollowing
                              ? () => _showFollowList(
                                  profile,
                                  summary,
                                  followers: false,
                                )
                              : null,
                        ),
                        if (_canManageOwnProfile)
                          StreamBuilder<List<FollowRelationship>>(
                            stream: _followRepository.watchFollowRequests(
                              _userId,
                            ),
                            builder: (context, snapshot) {
                              final requestCount = snapshot.data?.length ?? 0;
                              if (requestCount == 0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _FollowRequestsBanner(
                                  count: requestCount,
                                  onTap: _showFollowRequests,
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CaRismaBackground(
      child: SafeArea(
        bottom: false,
        child: StreamBuilder<profile_data.UserProfile?>(
          stream: _isOwnProfile
              ? _profileRepository.watchProfile(_userId)
              : _profileRepository.watchPublicProfile(_userId),
          builder: (context, snapshot) {
            final profile = CaRismaAppConfig.storeScreenshotMode
                ? null
                : snapshot.data;
            _scheduleLegacyVehicleSync(profile);
            return StreamBuilder<List<ProfileVehicle>>(
              stream: _vehiclesStream,
              builder: (context, vehicleSnapshot) {
                final vehicles =
                    vehicleSnapshot.data ?? const <ProfileVehicle>[];
                final resolvedVehicles = _resolvedProfileVehicles(vehicles);
                final primaryVehicle = _primaryVehicleFrom(resolvedVehicles);
                _schedulePrimaryHeroGeneration(primaryVehicle);
                return StreamBuilder<List<SocialPost>>(
                  stream: _socialPostRepository.watchUserPosts(
                    userId: _userId,
                    viewerUserId: _currentUserId,
                  ),
                  builder: (context, postsSnapshot) {
                    final storedPosts = CaRismaAppConfig.storeScreenshotMode
                        ? const <SocialPost>[]
                        : postsSnapshot.data ?? const <SocialPost>[];
                    final showDebugPosts =
                        CaRismaAppConfig.storeScreenshotMode ||
                        (kDebugMode && _isOwnProfile && storedPosts.isEmpty);
                    final posts = showDebugPosts
                        ? _debugSocialPosts
                        : storedPosts;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxHeight < 760;
                        final gap = compact ? 8.0 : 12.0;
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            CaRismaDesignTokens.mainScreenTopInset,
                            16,
                            8 + widget.bottomContentInset,
                          ),
                          child: Column(
                            children: [
                              _ProfileTopBar(
                                showBack:
                                    !_isOwnProfile &&
                                    Navigator.of(context).canPop(),
                                onBack: () => Navigator.of(context).maybePop(),
                              ),
                              SizedBox(height: gap),
                              _buildProfileHero(
                                profile,
                                posts.length,
                                primaryVehicle: primaryVehicle,
                                compact: compact,
                              ),
                              SizedBox(height: gap),
                              _ProfileTabs(
                                selectedIndex: _selectedTab,
                                onChanged: (index) =>
                                    setState(() => _selectedTab = index),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: _selectedTab == 1
                                      ? SingleChildScrollView(
                                          key: const ValueKey(
                                            'profile-vehicle-scroll',
                                          ),
                                          padding: EdgeInsets.only(
                                            bottom:
                                                MediaQuery.paddingOf(
                                                  context,
                                                ).bottom +
                                                56,
                                          ),
                                          physics:
                                              const ClampingScrollPhysics(),
                                          child: _buildVehiclePanel(
                                            profile: profile,
                                            postCount: posts.length,
                                            vehicles: resolvedVehicles,
                                            isLoading:
                                                vehicleSnapshot
                                                        .connectionState ==
                                                    ConnectionState.waiting &&
                                                !vehicleSnapshot.hasData,
                                            loadError: vehicleSnapshot.error,
                                          ),
                                        )
                                      : _buildPostsViewport(
                                          profile: profile,
                                          posts: posts
                                              .where(
                                                (post) =>
                                                    post.section ==
                                                    SocialPostSection.posts,
                                              )
                                              .toList(growable: false),
                                          snapshot: postsSnapshot,
                                          showDebugPosts: showDebugPosts,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  ProfileVehicle? _primaryVehicleFrom(List<ProfileVehicle> vehicles) {
    for (final vehicle in vehicles) {
      if (vehicle.isPrimary && !_isDebugProfileContent(vehicle.id)) {
        return vehicle;
      }
    }
    for (final vehicle in vehicles) {
      if (!_isDebugProfileContent(vehicle.id)) return vehicle;
    }
    return vehicles.isEmpty ? null : vehicles.first;
  }

  void _schedulePrimaryHeroGeneration(ProfileVehicle? vehicle) {
    if (!_isOwnProfile ||
        vehicle == null ||
        _isDebugProfileContent(vehicle.id) ||
        _autoHeroRequestedVehicleIds.contains(vehicle.id) ||
        vehicle.heroImageStatus == VehicleHeroImageStatus.ready ||
        vehicle.heroImageStatus == VehicleHeroImageStatus.queued ||
        vehicle.heroImageStatus == VehicleHeroImageStatus.generating) {
      return;
    }
    _autoHeroRequestedVehicleIds.add(vehicle.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestVehicleHeroImage(vehicle);
    });
  }

  List<ProfileVehicle> _resolvedProfileVehicles(List<ProfileVehicle> vehicles) {
    if (CaRismaAppConfig.storeScreenshotMode) {
      return const <ProfileVehicle>[debugProfileVehicle];
    }
    if (kDebugMode &&
        _isOwnProfile &&
        !vehicles.any((vehicle) => vehicle.id == debugProfileVehicleId)) {
      return <ProfileVehicle>[debugProfileVehicle, ...vehicles];
    }
    return vehicles;
  }

  Widget _buildPostsViewport({
    required profile_data.UserProfile? profile,
    required List<SocialPost> posts,
    required AsyncSnapshot<List<SocialPost>> snapshot,
    required bool showDebugPosts,
  }) {
    if (snapshot.hasError && !showDebugPosts) {
      return _SocialPostsFeedbackState(
        key: const ValueKey('social-posts-error'),
        icon: Icons.cloud_off_rounded,
        title: 'Beiträge konnten nicht geladen werden',
        description: 'Prüfe deine Verbindung und versuche es erneut.',
        actionLabel: 'Erneut versuchen',
        onAction: () => setState(() {}),
      );
    }
    if (!showDebugPosts &&
        snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const _SocialPostsLoadingState();
    }
    return _SocialPostSectionContent(
      key: const ValueKey('profile-posts'),
      posts: posts,
      canCreatePost: _canManageOwnProfile,
      onCreatePost: () => _showCreatePostSheet(profile),
      onOpenPost: (post) => _showPostDetails(post, profile),
      emptyTitle: 'Noch keine Beiträge',
      emptyDescription: _isOwnProfile
          ? 'Teile dein Fahrzeug, Treffen oder besondere Momente.'
          : 'Dieser Nutzer hat noch keine Beiträge geteilt.',
    );
  }

  Widget _buildVehiclePanel({
    required profile_data.UserProfile? profile,
    required int postCount,
    required List<ProfileVehicle> vehicles,
    required bool isLoading,
    required Object? loadError,
  }) {
    return ProfileVehiclePanel(
      profile: profile,
      postCount: postCount,
      vehicles: vehicles,
      isLoading: isLoading,
      loadError: loadError,
      isOwnProfile: _canManageOwnProfile,
      onAdd: () => _openVehicleEditor(profile),
      onEdit: (vehicle) => _openVehicleEditor(profile, vehicle: vehicle),
      onEditDetails: _openVehicleDetails,
      onEditEquipment: _openVehicleEquipment,
      onSetPrimary: _setPrimaryVehicle,
      onArchive: _archiveVehicle,
      onGenerateHero: _handleProfileHeroGeneration,
      isHeroRequestBusy: _busyHeroVehicleIds.contains,
      galleryMediaForVehicle: (vehicleId) => _isDebugProfileContent(vehicleId)
          ? Stream<List<ProfileVehicleGalleryMedia>>.value(_debugVehicleGallery)
          : _isOwnProfile
          ? _profileVehicleGalleryRepository.watchOwnerMedia(
              userId: _userId,
              vehicleId: vehicleId,
            )
          : _profileVehicleGalleryRepository.watchVisibleMedia(
              userId: _userId,
              vehicleId: vehicleId,
            ),
      onAddGalleryMedia: _addVehicleGalleryImage,
      onSetMainGalleryMedia: (_, media) => _setMainVehicleGalleryImage(media),
      onDeleteGalleryMedia: _deleteVehicleGalleryImage,
      modificationsForVehicle: (vehicleId) => _isDebugProfileContent(vehicleId)
          ? Stream<List<ProfileVehicleModification>>.value(
              _debugVehicleModifications,
            )
          : _isOwnProfile
          ? _profileVehicleModificationRepository.watchOwnerModifications(
              userId: _userId,
              vehicleId: vehicleId,
            )
          : _profileVehicleModificationRepository.watchVisibleModifications(
              userId: _userId,
              vehicleId: vehicleId,
            ),
      onAddModification: _openVehicleModificationEditor,
      onEditModification: (vehicle, modification) =>
          _openVehicleModificationEditor(vehicle, modification: modification),
      onDeleteModification: _deleteVehicleModification,
      timelineEntriesForVehicle: (vehicleId) =>
          _isDebugProfileContent(vehicleId)
          ? Stream<List<ProfileVehicleTimelineEntry>>.value(
              _debugVehicleTimeline,
            )
          : _isOwnProfile
          ? _profileVehicleTimelineRepository.watchOwnerEntries(
              userId: _userId,
              vehicleId: vehicleId,
            )
          : _profileVehicleTimelineRepository.watchVisibleEntries(
              userId: _userId,
              vehicleId: vehicleId,
            ),
      onAddTimelineEntry: _openVehicleTimelineEditor,
      onEditTimelineEntry: (vehicle, entry) =>
          _openVehicleTimelineEditor(vehicle, entry: entry),
      onDeleteTimelineEntry: _deleteVehicleTimelineEntry,
      profileViewCount: _profileRepository.watchProfileViewCount(_userId),
      totalLikeCount: _socialPostRepository.watchTotalLikeCount(_userId),
    );
  }

  void _scheduleLegacyVehicleSync(profile_data.UserProfile? profile) {
    if (!_isOwnProfile ||
        profile == null ||
        _legacyVehicleSyncScheduled ||
        profile.uid.trim().isEmpty) {
      return;
    }
    _legacyVehicleSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _profileVehicleRepository.ensureLegacyPrimaryVehicle(profile);
      } catch (_) {
        _legacyVehicleSyncScheduled = false;
      }
    });
  }

  Future<void> _requestVehicleHeroImage(ProfileVehicle vehicle) async {
    if (!_isOwnProfile || _busyHeroVehicleIds.contains(vehicle.id)) return;

    setState(() => _busyHeroVehicleIds.add(vehicle.id));
    try {
      final status = vehicle.heroImageStatus;
      final result = await _profileVehicleHeroService.requestGeneration(
        vehicleId: vehicle.id,
        forceRegeneration:
            status == VehicleHeroImageStatus.ready ||
            status == VehicleHeroImageStatus.failed ||
            status == VehicleHeroImageStatus.regenerationRequired,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.status == 'ready'
                ? 'Fahrzeugdarstellung wurde erstellt.'
                : 'Fahrzeugdarstellung wird erstellt.',
          ),
        ),
      );
    } on ProfileVehicleHeroException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Die Fahrzeugdarstellung konnte nicht gestartet werden.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyHeroVehicleIds.remove(vehicle.id));
      }
    }
  }

  Future<void> _handleProfileHeroGeneration(ProfileVehicle vehicle) async {
    if (_isDebugProfileContent(vehicle.id)) {
      if (_busyHeroVehicleIds.contains(vehicle.id)) return;
      setState(() => _busyHeroVehicleIds.add(vehicle.id));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _busyHeroVehicleIds.remove(vehicle.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KI-Testbild wurde aktualisiert.')),
      );
      return;
    }
    await _requestVehicleHeroImage(vehicle);
  }

  Future<void> _openVehicleEditor(
    profile_data.UserProfile? profile, {
    ProfileVehicle? vehicle,
  }) async {
    if (!_isOwnProfile || profile == null || _userId.isEmpty) return;
    final saved = await showProfileVehicleEditorSheet(
      context,
      userId: _userId,
      vehicleId:
          vehicle?.id ?? _profileVehicleRepository.createVehicleId(_userId),
      vehicle: vehicle,
      onSave: _profileVehicleRepository.saveVehicle,
    );
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          vehicle == null ? 'Fahrzeug hinzugefügt.' : 'Fahrzeug gespeichert.',
        ),
      ),
    );
  }

  Future<void> _setPrimaryVehicle(ProfileVehicle vehicle) async {
    try {
      await _profileVehicleRepository.setPrimaryVehicle(
        userId: _userId,
        vehicleId: vehicle.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hauptfahrzeug aktualisiert.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hauptfahrzeug konnte nicht geändert werden.')),
      );
    }
  }

  Future<void> _openVehicleDetails(ProfileVehicle vehicle) async {
    if (!_isOwnProfile) return;
    final saved = await showProfileVehicleDetailsSheet(
      context,
      vehicle: vehicle,
      onSave: _profileVehicleRepository.saveVehicle,
    );
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fahrzeugdaten gespeichert.')));
  }

  Future<void> _openVehicleEquipment(ProfileVehicle vehicle) async {
    if (!_isOwnProfile) return;
    final saved = await showProfileVehicleDetailsSheet(
      context,
      vehicle: vehicle,
      section: ProfileVehicleDetailsSection.equipment,
      onSave: _profileVehicleRepository.saveVehicle,
    );
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ausstattung gespeichert.')));
  }

  Future<void> _openVehicleModificationEditor(
    ProfileVehicle vehicle, {
    ProfileVehicleModification? modification,
  }) async {
    if (!_isOwnProfile || _userId.isEmpty) return;
    final saved = await showProfileVehicleModificationSheet(
      context,
      userId: _userId,
      vehicle: vehicle,
      modificationId:
          modification?.id ??
          _profileVehicleModificationRepository.createModificationId(
            userId: _userId,
            vehicleId: vehicle.id,
          ),
      modification: modification,
      onSave: _profileVehicleModificationRepository.saveModification,
    );
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          modification == null ? 'Umbau hinzugefügt.' : 'Umbau gespeichert.',
        ),
      ),
    );
  }

  Future<void> _addVehicleGalleryImage(ProfileVehicle vehicle) async {
    if (!_isOwnProfile || _userId.isEmpty) return;
    final action = await showModalBottomSheet<_VehicleGalleryPickerAction>(
      context: context,
      backgroundColor: CaRismaDesignTokens.background,

      useSafeArea: true,

      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Bild aus Galerie'),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_VehicleGalleryPickerAction.galleryImage),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Foto aufnehmen'),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_VehicleGalleryPickerAction.cameraImage),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Video aus Galerie'),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_VehicleGalleryPickerAction.galleryVideo),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video aufnehmen'),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_VehicleGalleryPickerAction.cameraVideo),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    try {
      final isVideo =
          action == _VehicleGalleryPickerAction.galleryVideo ||
          action == _VehicleGalleryPickerAction.cameraVideo;
      final source =
          action == _VehicleGalleryPickerAction.galleryImage ||
              action == _VehicleGalleryPickerAction.galleryVideo
          ? ImageSource.gallery
          : ImageSource.camera;
      final media = isVideo
          ? await _imagePicker.pickVideo(
              source: source,
              maxDuration: const Duration(seconds: 60),
            )
          : await _imagePicker.pickImage(
              source: source,
              imageQuality: 88,
              maxWidth: 2400,
            );
      if (media == null || !mounted) return;
      final category = await _chooseVehicleGalleryCategory();
      if (category == null || !mounted) return;
      if (isVideo) {
        await _profileVehicleGalleryRepository.uploadVideo(
          userId: _userId,
          vehicle: vehicle,
          videoFile: File(media.path),
          category: category,
        );
      } else {
        await _profileVehicleGalleryRepository.uploadImage(
          userId: _userId,
          vehicle: vehicle,
          imageFile: File(media.path),
          category: category,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVideo
                ? 'Video zur Fahrzeuggalerie hinzugefügt.'
                : 'Bild zur Fahrzeuggalerie hinzugefügt.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Medium konnte nicht gespeichert werden.')),
      );
    }
  }

  Future<ProfileVehicleGalleryCategory?> _chooseVehicleGalleryCategory() {
    const selectableCategories = <ProfileVehicleGalleryCategory>[
      ProfileVehicleGalleryCategory.exterior,
      ProfileVehicleGalleryCategory.interior,
      ProfileVehicleGalleryCategory.details,
      ProfileVehicleGalleryCategory.modifications,
    ];
    return showModalBottomSheet<ProfileVehicleGalleryCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CaRismaDesignTokens.background,

      useSafeArea: true,

      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kategorie auswählen',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Abbrechen',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final category in selectableCategories)
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(_vehicleGalleryCategoryLabel(category)),
                onTap: () => Navigator.of(sheetContext).pop(category),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setMainVehicleGalleryImage(
    ProfileVehicleGalleryMedia media,
  ) async {
    try {
      await _profileVehicleGalleryRepository.setMainMedia(media);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hauptbild aktualisiert.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hauptbild konnte nicht geändert werden.')),
      );
    }
  }

  Future<void> _deleteVehicleGalleryImage(
    ProfileVehicleGalleryMedia media,
  ) async {
    final isVideo = media.mediaType == ProfileVehicleGalleryMediaType.video;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isVideo ? 'Video entfernen?' : 'Bild entfernen?'),
        content: Text(
          isVideo
              ? 'Das Video wird aus der Fahrzeuggalerie entfernt.'
              : 'Das Bild wird aus der Fahrzeuggalerie entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _profileVehicleGalleryRepository.deleteMedia(media);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVideo ? 'Video entfernt.' : 'Bild entfernt.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medium konnte nicht entfernt werden.')),
      );
    }
  }

  Future<void> _deleteVehicleModification(
    ProfileVehicleModification modification,
  ) async {
    if (!_isOwnProfile) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Umbau entfernen?'),
        content: Text(
          '${modification.title} wird aus diesem Fahrzeug entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _profileVehicleModificationRepository.deleteModification(
        modification,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Umbau entfernt.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Umbau konnte nicht entfernt werden.')),
      );
    }
  }

  Future<void> _openVehicleTimelineEditor(
    ProfileVehicle vehicle, {
    ProfileVehicleTimelineEntry? entry,
  }) async {
    if (!_isOwnProfile || _userId.isEmpty) return;
    if (entry?.isAutomaticallyCreated == true) return;
    final saved = await showProfileVehicleTimelineSheet(
      context,
      userId: _userId,
      vehicle: vehicle,
      entryId:
          entry?.id ??
          _profileVehicleTimelineRepository.createEntryId(
            userId: _userId,
            vehicleId: vehicle.id,
          ),
      entry: entry,
      onSave: _profileVehicleTimelineRepository.saveEntry,
    );
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          entry == null
              ? 'Timeline-Ereignis hinzugefügt.'
              : 'Timeline-Ereignis gespeichert.',
        ),
      ),
    );
  }

  Future<void> _deleteVehicleTimelineEntry(
    ProfileVehicleTimelineEntry entry,
  ) async {
    if (!_isOwnProfile || entry.isAutomaticallyCreated) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ereignis entfernen?'),
        content: Text('${entry.title} wird aus der Timeline entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _profileVehicleTimelineRepository.deleteEntry(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timeline-Ereignis entfernt.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timeline-Ereignis konnte nicht entfernt werden.'),
        ),
      );
    }
  }

  Future<void> _archiveVehicle(ProfileVehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fahrzeug archivieren?'),
        content: Text(
          '${vehicle.displayName} wird aus deinem öffentlichen Profil entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archivieren'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _profileVehicleRepository.archiveVehicle(
        userId: _userId,
        vehicleId: vehicle.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fahrzeug archiviert.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fahrzeug konnte nicht archiviert werden.')),
      );
    }
  }

  Future<void> _openProfileStory(
    ChatStoryRecord story, [
    List<ChatStoryRecord> stories = const <ChatStoryRecord>[],
  ]) {
    return showProfileStoryViewer(
      context: context,
      currentUserId: _currentUserId,
      story: story,
      stories: stories,
    );
  }

  Future<void> _showProfileIdentityActions(
    profile_data.UserProfile? profile,
  ) async {
    if (!_isOwnProfile) return;

    final action = await showModalBottomSheet<_ProfileIdentityAction>(
      context: context,
      backgroundColor: Colors.transparent,

      useSafeArea: true,

      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetHeader(
                  icon: Icons.person_rounded,
                  title: 'Profilbild und Story',
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                _ProfilePhotoActionTile(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Neue Story hinzufügen',
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_ProfileIdentityAction.addStory),
                ),
                const SizedBox(height: 10),
                _ProfilePhotoActionTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Profilbild ändern',
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_ProfileIdentityAction.changePhoto),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    switch (action) {
      case _ProfileIdentityAction.addStory:
        await _createProfileStory();
      case _ProfileIdentityAction.changePhoto:
        await _showProfilePhotoSheet(profile);
      case null:
        break;
    }
  }

  Future<void> _showProfileCreateActions(
    profile_data.UserProfile? profile,
  ) async {
    if (!_canManageOwnProfile) return;

    final action = await showModalBottomSheet<_ProfileCreateAction>(
      context: context,
      backgroundColor: Colors.transparent,

      useSafeArea: true,

      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetHeader(
                  icon: Icons.photo_camera_rounded,
                  title: 'Inhalt hinzufügen',
                  onClose: () => Navigator.of(sheetContext).pop(),
                ),
                const SizedBox(height: 12),
                _ProfilePhotoActionTile(
                  icon: Icons.auto_stories_outlined,
                  title: 'Story hinzufügen',
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(_ProfileCreateAction.story),
                ),
                const SizedBox(height: 10),
                _ProfilePhotoActionTile(
                  icon: Icons.add_photo_alternate_outlined,
                  title: 'Beitrag erstellen',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_ProfileCreateAction.post),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    switch (action) {
      case _ProfileCreateAction.story:
        await _createProfileStory();
      case _ProfileCreateAction.post:
        await _showCreatePostSheet(profile);
      case null:
        break;
    }
  }

  Future<void> _createProfileStory() async {
    if (!_isOwnProfile || _isCreatingStory) return;
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
        SnackBar(content: Text('Story konnte nicht gespeichert werden.')),
      );
    } finally {
      if (mounted) setState(() => _isCreatingStory = false);
    }
  }

  Future<void> _showProfilePhotoSheet(profile_data.UserProfile? profile) async {
    if (!_isOwnProfile) return;

    final hasPhoto =
        (profile?.photoUrl?.trim().isNotEmpty ?? false) ||
        (profile?.profilePhotoLocalPath?.trim().isNotEmpty ?? false);

    final action = await showModalBottomSheet<_ProfilePhotoAction>(
      context: context,
      backgroundColor: Colors.transparent,

      useSafeArea: true,

      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetHeader(
                    icon: Icons.photo_camera_rounded,
                    title: 'Profilbild',
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 12),
                  _ProfilePhotoActionTile(
                    icon: Icons.photo_library_rounded,
                    title: 'Aus Galerie wählen',
                    onTap: () =>
                        Navigator.of(context).pop(_ProfilePhotoAction.gallery),
                  ),
                  const SizedBox(height: 10),
                  _ProfilePhotoActionTile(
                    icon: Icons.photo_camera_rounded,
                    title: 'Kamera öffnen',
                    onTap: () =>
                        Navigator.of(context).pop(_ProfilePhotoAction.camera),
                  ),
                  if (hasPhoto) ...[
                    const SizedBox(height: 10),
                    _ProfilePhotoActionTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Profilbild entfernen',
                      isDestructive: true,
                      onTap: () =>
                          Navigator.of(context).pop(_ProfilePhotoAction.remove),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    if (action == null) return;

    switch (action) {
      case _ProfilePhotoAction.gallery:
        await _pickAndSaveProfilePhoto(ImageSource.gallery, profile);
        break;
      case _ProfilePhotoAction.camera:
        await _pickAndSaveProfilePhoto(ImageSource.camera, profile);
        break;
      case _ProfilePhotoAction.remove:
        await _removeProfilePhoto(profile);
        break;
    }
  }

  Future<void> _pickAndSaveProfilePhoto(
    ImageSource source,
    profile_data.UserProfile? profile,
  ) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1400,
      );
      if (image == null) return;

      if (!mounted) return;
      final croppedImage = await Navigator.of(context).push<XFile>(
        MaterialPageRoute<XFile>(
          builder: (_) => ProfilePhotoCropScreen(sourceFile: image),
        ),
      );
      if (croppedImage == null || !mounted) return;

      final upload = await _profileMediaStorage.uploadProfilePhoto(
        userId: _userId,
        file: File(croppedImage.path),
      );
      await _profileRepository.updateProfilePreferences(
        uid: _userId,
        photoUrl: upload.url,
        allowContactRequests: profile?.allowContactRequests ?? true,
        allowAnonymousReports: profile?.allowAnonymousReports ?? true,
      );
      await _profileRepository.updatePublicProfilePhoto(
        uid: _userId,
        photoUrl: upload.url,
      );
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final previousPhotoUrl = firebaseUser?.photoURL?.trim();
      if (previousPhotoUrl != null && previousPhotoUrl.isNotEmpty) {
        await NetworkImage(previousPhotoUrl).evict();
      }
      await firebaseUser?.updatePhotoURL(upload.url);
      await NetworkImage(upload.url).evict();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profilbild gespeichert.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profilbild konnte nicht gespeichert werden. Bitte prüfe deine Verbindung und Berechtigungen.',
          ),
        ),
      );
    }
  }

  Future<void> _removeProfilePhoto(profile_data.UserProfile? profile) async {
    try {
      await _profileMediaStorage.deleteProfilePhoto(userId: _userId);
      await _profileRepository.updateProfilePreferences(
        uid: _userId,
        photoUrl: null,
        allowContactRequests: profile?.allowContactRequests ?? true,
        allowAnonymousReports: profile?.allowAnonymousReports ?? true,
      );
      await _profileRepository.updatePublicProfilePhoto(
        uid: _userId,
        photoUrl: null,
      );
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final previousPhotoUrl = firebaseUser?.photoURL?.trim();
      if (previousPhotoUrl != null && previousPhotoUrl.isNotEmpty) {
        await NetworkImage(previousPhotoUrl).evict();
      }
      await firebaseUser?.updatePhotoURL(null);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profilbild entfernt.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profilbild konnte nicht entfernt werden.')),
      );
    }
  }

  Future<void> _showEditPublicProfileSheet(
    profile_data.UserProfile? profile,
  ) async {
    final initialDisplayName = _displayNameFor(profile).trim();
    final initialRegion = _profileRegionFor(profile).trim();
    final displayNameController = TextEditingController(
      text: initialDisplayName,
    );
    final regionController = TextEditingController(text: initialRegion);
    var isSaving = false;
    var hasChanges = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateChangeState() {
              final changed =
                  displayNameController.text.trim() != initialDisplayName ||
                  regionController.text.trim() != initialRegion;
              if (changed != hasChanges) {
                setSheetState(() => hasChanges = changed);
              }
            }

            Future<void> savePublicProfile() async {
              if (!hasChanges) return;
              final displayName = displayNameController.text.trim();
              if (displayName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bitte gib einen Anzeigenamen ein.'),
                  ),
                );
                return;
              }

              setSheetState(() => isSaving = true);
              try {
                await _profileRepository.updatePublicProfile(
                  profile:
                      profile ??
                      profile_data.UserProfile.empty(
                        uid: _userId,
                        email: FirebaseAuth.instance.currentUser?.email ?? '',
                      ),
                  displayName: displayName,
                  publicBio: profile?.publicBio,
                  publicRegion: regionController.text,
                  showVehicleOnPublicProfile:
                      profile?.showVehicleOnPublicProfile ?? false,
                  showPlateOnPublicProfile:
                      profile?.showPlateOnPublicProfile ?? false,
                  isPrivateProfile: profile?.isPrivateProfile ?? true,
                  profileAccessEnabled: profile?.profileAccessEnabled ?? true,
                  followersVisibility:
                      profile?.followersVisibility ?? 'contacts',
                  followingVisibility:
                      profile?.followingVisibility ?? 'contacts',
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Öffentliches Profil gespeichert.'),
                  ),
                );
              } catch (error) {
                debugPrint(
                  'Public profile could not be saved: ${error.runtimeType}',
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Profil konnte gerade nicht gespeichert werden. Bitte versuche es erneut.',
                    ),
                  ),
                );
              } finally {
                if (context.mounted) {
                  setSheetState(() => isSaving = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + keyboardInset),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  top: true,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SheetHeader(
                          icon: Icons.edit_rounded,
                          title: 'Profil bearbeiten',
                          onClose: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(height: 14),
                        _SocialTextField(
                          controller: displayNameController,
                          label: 'Anzeigename',
                          icon: Icons.badge_outlined,
                          onChanged: (_) => updateChangeState(),
                        ),
                        const SizedBox(height: 10),
                        _SocialTextField(
                          controller: regionController,
                          label: 'Stadt / Region',
                          icon: Icons.location_city_rounded,
                          onChanged: (_) => updateChangeState(),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Sichtbarkeit, Fahrzeugdaten und Listen verwaltest du zentral in den Einstellungen.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: CaRismaDesignTokens.textSecondary,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 14),
                        _ProfileOutlineActionButton(
                          label: 'Übernehmen',
                          icon: Icons.check_rounded,
                          isLoading: isSaving,
                          isEnabled: hasChanges,
                          loadingLabel: 'Speichert...',
                          onPressed: savePublicProfile,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 400));
    displayNameController.dispose();
    regionController.dispose();
  }

  // Retained for the profile-management entry that is finalized separately.
  // ignore: unused_element
  Future<void> _showProfilePostActions(
    profile_data.UserProfile? profile,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(14),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(
                icon: Icons.grid_view_rounded,
                title: 'Beiträge',
                onClose: () => Navigator.of(sheetContext).pop(),
              ),
              const SizedBox(height: 14),
              _ProfilePhotoActionTile(
                icon: Icons.add_photo_alternate_outlined,
                title: 'Beitrag erstellen',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showCreatePostSheet(profile);
                },
              ),
              const SizedBox(height: 8),
              _ProfilePhotoActionTile(
                icon: Icons.qr_code_2_rounded,
                title: 'Profil teilen',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showProfileShareSheet(profile);
                },
              ),
              const SizedBox(height: 8),
              _ProfilePhotoActionTile(
                icon: Icons.archive_outlined,
                title: 'Archivierte Beiträge',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showArchivedPosts(profile);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showProfileShareSheet(profile_data.UserProfile? profile) async {
    final link = 'https://plaqa.de/profile/$_userId';
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(14),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(
                icon: Icons.qr_code_2_rounded,
                title: 'Profil teilen',
                onClose: () => Navigator.of(sheetContext).pop(),
              ),
              const SizedBox(height: 16),
              Container(
                width: 210,
                height: 210,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: QrImageView(
                  data: link,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _displayNameFor(profile),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: CaRismaSecondaryButton(
                      label: 'Link kopieren',
                      icon: Icons.link_rounded,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      borderRadius: 17,
                      fontSize: 13,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: CaRismaSecondaryButton(
                      label: 'Teilen',
                      icon: Icons.share_outlined,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      borderRadius: 17,
                      fontSize: 13,
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: 'Profil auf plaqa ansehen: $link'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showArchivedPosts(profile_data.UserProfile? profile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(14),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Column(
              children: [
                _SheetHeader(
                  icon: Icons.archive_outlined,
                  title: 'Archivierte Beiträge',
                  onClose: () => Navigator.of(sheetContext).pop(),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder<List<SocialPost>>(
                    stream: _socialPostRepository.watchUserPosts(
                      userId: _userId,
                      viewerUserId: _currentUserId,
                      archived: true,
                    ),
                    builder: (context, snapshot) {
                      final posts = snapshot.data ?? const <SocialPost>[];
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (posts.isEmpty) {
                        return const Center(
                          child: Text(
                            'Keine archivierten Beiträge.',
                            style: TextStyle(
                              color: CaRismaDesignTokens.textSecondary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        physics: const ClampingScrollPhysics(),
                        itemCount: posts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: CaRismaDesignTokens.controlSurface,
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox.square(
                                    dimension: 58,
                                    child: _SocialPostImage(post: post),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    post.caption?.trim().isNotEmpty == true
                                        ? post.caption!.trim()
                                        : 'Beitrag',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Wiederherstellen',
                                  onPressed: () =>
                                      _socialPostRepository.setPostArchived(
                                        userId: _userId,
                                        post: post,
                                        archived: false,
                                      ),
                                  icon: const Icon(
                                    Icons.unarchive_outlined,
                                    color: CaRismaDesignTokens.blueBright,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreatePostSheet(
    profile_data.UserProfile? profile, {
    SocialPostSection initialSection = SocialPostSection.posts,
  }) async {
    if (!_isOwnProfile) {
      return;
    }

    final selectedMedia = <XFile>[];
    bool isPicking = false;
    bool isPublishing = false;
    var selectedSection = initialSection;
    var selectedVisibility = SocialPostVisibility.public;
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickGalleryMedia() async {
              if (isPicking) return;
              setSheetState(() => isPicking = true);
              try {
                final media = await Navigator.of(context)
                    .push<List<ProfilePostGallerySelection>>(
                      MaterialPageRoute<List<ProfilePostGallerySelection>>(
                        builder: (_) => const ProfilePostGalleryScreen(
                          maxSelection: SocialPostRepository.maxMediaPerPost,
                        ),
                      ),
                    );
                if (media != null && media.isNotEmpty && context.mounted) {
                  setSheetState(() {
                    selectedMedia
                      ..clear()
                      ..addAll(media.map((item) => XFile(item.path)));
                  });
                }
              } finally {
                if (context.mounted) setSheetState(() => isPicking = false);
              }
            }

            Future<void> pickCameraMedia() async {
              if (isPicking) return;
              final type = await showDialog<SocialPostMediaType>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Kamera'),
                  content: const Text('Was möchtest du aufnehmen?'),
                  actions: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(
                        dialogContext,
                      ).pop(SocialPostMediaType.image),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Foto'),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(
                        dialogContext,
                      ).pop(SocialPostMediaType.video),
                      icon: const Icon(Icons.videocam_rounded),
                      label: const Text('Video'),
                    ),
                  ],
                ),
              );
              if (type == null || !context.mounted) return;
              setSheetState(() => isPicking = true);
              try {
                final media = type == SocialPostMediaType.video
                    ? await _imagePicker.pickVideo(
                        source: ImageSource.camera,
                        maxDuration: const Duration(minutes: 2),
                      )
                    : await _imagePicker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 88,
                        maxWidth: 1600,
                        requestFullMetadata: false,
                      );
                if (media != null) {
                  setSheetState(() {
                    if (selectedMedia.length ==
                        SocialPostRepository.maxMediaPerPost) {
                      selectedMedia.removeLast();
                    }
                    selectedMedia.add(media);
                  });
                }
              } finally {
                if (context.mounted) setSheetState(() => isPicking = false);
              }
            }

            Future<void> publishPost() async {
              if (selectedMedia.isEmpty || isPublishing) return;

              setSheetState(() => isPublishing = true);
              try {
                await _socialPostRepository.createMediaPost(
                  userId: _userId,
                  uploads: selectedMedia
                      .map(
                        (media) => SocialPostUpload(
                          file: File(media.path),
                          type: _postMediaTypeFor(media),
                        ),
                      )
                      .toList(growable: false),
                  caption: descriptionController.text,
                  vehicleLabel: _vehicleShortLabelFor(profile),
                  locationLabel: locationController.text,
                  section: selectedSection,
                  visibility: selectedVisibility,
                );

                if (!context.mounted) return;
                Navigator.of(context).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Beitrag veröffentlicht.')),
                );
              } catch (error) {
                debugPrint('Post could not be published: ${error.runtimeType}');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Beitrag konnte gerade nicht veröffentlicht werden. Bitte versuche es erneut.',
                    ),
                  ),
                );
              } finally {
                if (context.mounted) {
                  setSheetState(() => isPublishing = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + keyboardInset),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  top: true,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SheetHeader(
                          icon: Icons.add_photo_alternate_rounded,
                          title: 'Beitrag erstellen',
                          onClose: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(height: 14),
                        _PostMediaPicker(
                          media: selectedMedia,
                          isLoading: isPicking,
                          onGallery: pickGalleryMedia,
                          onCamera: pickCameraMedia,
                          onRemove: (media) =>
                              setSheetState(() => selectedMedia.remove(media)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Anzeigen unter',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: CaRismaDesignTokens.textSecondary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _ProfileTabs(
                          selectedIndex:
                              selectedSection == SocialPostSection.posts
                              ? 0
                              : 1,
                          onChanged: (index) => setSheetState(
                            () => selectedSection = index == 0
                                ? SocialPostSection.posts
                                : SocialPostSection.vehicle,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SocialTextField(
                          controller: descriptionController,
                          label: 'Beschreibung',
                          icon: Icons.notes_rounded,
                          maxLength: 220,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 10),
                        _PostMetaTile(
                          icon: Icons.directions_car_rounded,
                          title: 'Fahrzeug',
                          value: _vehicleShortLabelFor(profile),
                        ),
                        const SizedBox(height: 10),
                        _PostVisibilitySelector(
                          value: selectedVisibility,
                          onChanged: (value) =>
                              setSheetState(() => selectedVisibility = value),
                        ),
                        const SizedBox(height: 10),
                        _SocialTextField(
                          controller: locationController,
                          label: 'Ort (optional)',
                          icon: Icons.location_on_outlined,
                          maxLength: 120,
                        ),
                        const SizedBox(height: 14),
                        _ProfileOutlineActionButton(
                          label: 'Veröffentlichen',
                          icon: Icons.send_rounded,
                          isEnabled:
                              selectedMedia.isNotEmpty &&
                              !isPicking &&
                              !isPublishing,
                          isLoading: isPublishing,
                          loadingLabel: 'Veröffentlicht...',
                          onPressed: publishPost,
                        ),
                        const SizedBox(height: 10),
                        CaRismaSecondaryButton(
                          label: 'Abbrechen',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          borderRadius: 18,
                          fontSize: 14,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 400));
    descriptionController.dispose();
    locationController.dispose();
  }

  Future<void> _showPostDetails(
    SocialPost post,
    profile_data.UserProfile? profile,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ProfilePostDetailsSheet(
        post: post,
        repository: _socialPostRepository,
        viewerUserId: _currentUserId,
        viewerDisplayName:
            FirebaseAuth.instance.currentUser?.displayName?.trim().isNotEmpty ==
                true
            ? FirebaseAuth.instance.currentUser!.displayName!.trim()
            : 'Nutzer',
        viewerPhotoUrl:
            FirebaseAuth.instance.currentUser?.photoURL?.trim() ?? '',
        ownerDisplayName: _displayNameFor(profile),
        ownerPhotoUrl: profile?.photoUrl?.trim() ?? '',
        isOwner: _isOwnProfile,
        isDemo: _isDebugProfileContent(post.id),
        demoMediaBuilder: (post, _) => _SocialPostImage(post: post),
        onEdit: () {
          Navigator.of(sheetContext).pop();
          _showEditPostSheet(post);
        },
        onTogglePin: () {
          Navigator.of(sheetContext).pop();
          _togglePostPinned(post);
        },
        onArchive: () {
          Navigator.of(sheetContext).pop();
          _archivePost(post);
        },
        onDelete: () {
          Navigator.of(sheetContext).pop();
          _confirmDeletePost(post);
        },
        onShare: () => _sharePost(post),
      ),
    );
  }

  Future<void> _showEditPostSheet(SocialPost post) async {
    if (_isDebugProfileContent(post.id)) return;
    final captionController = TextEditingController(text: post.caption ?? '');
    final locationController = TextEditingController(
      text: post.locationLabel ?? '',
    );
    var visibility = post.visibilityMode;
    var isSaving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            12,
            14,
            14 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetHeader(
                  icon: Icons.edit_rounded,
                  title: 'Beitrag bearbeiten',
                  onClose: () => Navigator.of(sheetContext).pop(),
                ),
                const SizedBox(height: 14),
                _SocialTextField(
                  controller: captionController,
                  label: 'Beschreibung',
                  icon: Icons.notes_rounded,
                  maxLength: 220,
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                _SocialTextField(
                  controller: locationController,
                  label: 'Ort (optional)',
                  icon: Icons.location_on_outlined,
                  maxLength: 120,
                ),
                const SizedBox(height: 10),
                _PostVisibilitySelector(
                  value: visibility,
                  onChanged: (value) => setSheetState(() => visibility = value),
                ),
                const SizedBox(height: 14),
                _ProfileOutlineActionButton(
                  label: 'Änderungen speichern',
                  icon: Icons.check_rounded,
                  isLoading: isSaving,
                  loadingLabel: 'Speichert...',
                  onPressed: () async {
                    setSheetState(() => isSaving = true);
                    try {
                      await _socialPostRepository.updatePost(
                        userId: _userId,
                        post: post,
                        caption: captionController.text,
                        locationLabel: locationController.text,
                        visibility: visibility,
                      );
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Beitrag konnte gerade nicht gespeichert werden.',
                            ),
                          ),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        setSheetState(() => isSaving = false);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    captionController.dispose();
    locationController.dispose();
  }

  Future<void> _togglePostPinned(SocialPost post) async {
    if (_isDebugProfileContent(post.id)) return;
    try {
      await _socialPostRepository.setPostPinned(
        userId: _userId,
        post: post,
        pinned: !post.isPinned,
      );
    } on SocialPostRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _archivePost(SocialPost post) async {
    if (_isDebugProfileContent(post.id)) return;
    try {
      await _socialPostRepository.setPostArchived(
        userId: _userId,
        post: post,
        archived: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Beitrag archiviert.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beitrag konnte nicht archiviert werden.'),
        ),
      );
    }
  }

  Future<void> _sharePost(SocialPost post) async {
    final link = 'https://plaqa.de/profile/${post.ownerUserId}/post/${post.id}';
    await SharePlus.instance.share(
      ShareParams(text: 'Beitrag auf plaqa ansehen: $link'),
    );
  }

  Future<void> _confirmDeletePost(SocialPost post) async {
    if (_isDebugProfileContent(post.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Der Beispielbeitrag wird nur lokal angezeigt.'),
        ),
      );
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Beitrag löschen?'),
        content: const Text(
          'Das Bild und die Beschreibung können danach nicht wiederhergestellt werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await _socialPostRepository.deletePost(userId: _userId, post: post);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Beitrag gelöscht.')));
    } catch (error) {
      debugPrint('Post could not be deleted: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Beitrag konnte gerade nicht gelöscht werden. Bitte versuche es erneut.',
          ),
        ),
      );
    }
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.icon,
    required this.title,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CaRismaBlueIconBox(icon: icon, size: 40, iconSize: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
          color: Colors.white,
        ),
      ],
    );
  }
}

class _ProfileOutlineActionButton extends StatelessWidget {
  const _ProfileOutlineActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isEnabled = true,
    this.isLoading = false,
    this.loadingLabel,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isEnabled;
  final bool isLoading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = isEnabled && !isLoading;
    return Opacity(
      opacity: enabled || isLoading ? 1 : 0.46,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(18),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: CaRismaDesignTokens.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: enabled || isLoading
                    ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1.4,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CaRismaDesignTokens.blueBright,
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    isLoading ? loadingLabel ?? label : label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({required this.showBack, required this.onBack});

  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: showBack ? 42 : 0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: showBack
                ? IconButton(
                    tooltip: 'Zurück',
                    onPressed: onBack,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : const SizedBox.square(dimension: 42),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.primaryVehicle,
    required this.compact,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    required this.followState,
    required this.isFollowActionBusy,
    required this.isCreatingStory,
    required this.isOwnProfile,
    required this.isReadOnly,
    required this.showPreviewToggle,
    required this.isPreviewing,
    required this.onPreviewToggle,
    required this.activeStory,
    required this.onEditProfile,
    required this.onAvatarTap,
    required this.onAvatarLongPress,
    required this.onAddStory,
    required this.onFollow,
    required this.onMessage,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final profile_data.UserProfile? profile;
  final ProfileVehicle? primaryVehicle;
  final bool compact;
  final int postCount;
  final int? followerCount;
  final int? followingCount;
  final ProfileFollowState followState;
  final bool isFollowActionBusy;
  final bool isCreatingStory;
  final bool isOwnProfile;
  final bool isReadOnly;
  final bool showPreviewToggle;
  final bool isPreviewing;
  final VoidCallback onPreviewToggle;
  final ChatStoryRecord? activeStory;
  final VoidCallback? onEditProfile;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
  final VoidCallback? onAddStory;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  @override
  Widget build(BuildContext context) {
    final vehicle = primaryVehicle;
    final heroImageUrl = vehicle?.heroImageUrl?.trim() ?? '';
    final isDebugVehicle = vehicle?.id == debugProfileVehicleId;
    final canShowPlate =
        vehicle != null &&
        (isOwnProfile ||
            ((profile?.showPlateOnPublicProfile ?? false) &&
                vehicle.showPlate &&
                vehicle.plateDisplayMode != ProfilePlateDisplayMode.hidden));
    final isVerified = profile?.verificationStatus == 'verified';
    final region = profile?.publicRegion?.trim() ?? '';

    return GlassCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusCard),
        child: SizedBox(
          height: compact ? 206 : 226,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = compact ? 12.0 : 15.0;
              final statsWidth = constraints.maxWidth * 0.51;
              final avatarSize = compact ? 58.0 : 66.0;
              final logoWidth = compact ? 154.0 : 174.0;
              final availableVehicleWidth =
                  constraints.maxWidth -
                  statsWidth -
                  (horizontalPadding * 2) -
                  11;
              final vehicleCardWidth = math.min(availableVehicleWidth, 132.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF20242B),
                          Color(0xFF111419),
                          Color(0xFF080A0D),
                        ],
                      ),
                    ),
                  ),
                  if (vehicle != null)
                    Positioned(
                      top: 14,
                      right: -18,
                      width: constraints.maxWidth * 0.68,
                      height: compact ? 132 : 148,
                      child: _ProfileVehicleHeroArtwork(
                        imageUrl: heroImageUrl,
                        hasVehicle: true,
                        isDebugVehicle: isDebugVehicle,
                      ),
                    ),
                  if (showPreviewToggle)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _ProfileHeaderIconButton(
                        tooltip: isPreviewing
                            ? 'Eigene Ansicht öffnen'
                            : 'Profil als Besucher ansehen',
                        icon: isPreviewing
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onPressed: onPreviewToggle,
                      ),
                    ),
                  Positioned(
                    left: horizontalPadding,
                    top: compact ? 13 : 16,
                    right: constraints.maxWidth * 0.38,
                    child: Row(
                      children: [
                        _SocialAvatar(
                          profile: profile,
                          size: avatarSize,
                          hasActiveStory: activeStory != null,
                          showStoryBadge: isOwnProfile,
                          storyBadgeIcon: Icons.photo_camera_rounded,
                          isStoryActionBusy: isCreatingStory,
                          onTap: onAvatarTap,
                          onLongPress: onAvatarLongPress,
                          onStoryBadgeTap: onAddStory,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _displayNameFor(profile),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: compact ? 18 : 21,
                                          ),
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: CaRismaDesignTokens.blueBright,
                                      size: 18,
                                    ),
                                  ],
                                  if (isOwnProfile &&
                                      onEditProfile != null) ...[
                                    const SizedBox(width: 5),
                                    _ProfileHeaderIconButton(
                                      tooltip: 'Profil bearbeiten',
                                      icon: Icons.edit_rounded,
                                      onPressed: onEditProfile,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                region.isNotEmpty
                                    ? region
                                    : _profileSubtitleFor(profile),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: CaRismaDesignTokens.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: horizontalPadding,
                    top: compact ? 75 : 86,
                    width: logoWidth,
                    child: Image.asset(
                      'assets/images/plaqa_logo_transparent.png',
                      height: compact ? 39 : 47,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (_, _, _) => const Text(
                        'plaqa',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: horizontalPadding,
                    bottom: compact ? 14 : 16,
                    width: statsWidth,
                    child: _ProfileHeroStats(
                      posts: postCount,
                      followers: followerCount,
                      following: followingCount,
                      onFollowersTap: onFollowersTap,
                      onFollowingTap: onFollowingTap,
                      visitorActions:
                          !isOwnProfile && (!isReadOnly || isPreviewing)
                          ? _ProfileVisitorHeaderActions(
                              followState: followState,
                              isFollowActionBusy: isFollowActionBusy,
                              previewOnly: isPreviewing,
                              onFollow: onFollow,
                              onMessage: onMessage,
                            )
                          : null,
                    ),
                  ),
                  if (vehicle != null)
                    Positioned(
                      right: horizontalPadding,
                      bottom: compact ? 11 : 13,
                      width: vehicleCardWidth,
                      child: _ProfileMainVehicleCard(
                        vehicle: vehicle,
                        showPlate: canShowPlate,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileVisitorHeaderActions extends StatelessWidget {
  const _ProfileVisitorHeaderActions({
    required this.followState,
    required this.isFollowActionBusy,
    required this.previewOnly,
    required this.onFollow,
    required this.onMessage,
  });

  final ProfileFollowState followState;
  final bool isFollowActionBusy;
  final bool previewOnly;
  final VoidCallback onFollow;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final isFollowing =
        followState == ProfileFollowState.following ||
        followState == ProfileFollowState.mutual;
    final isRequested = followState == ProfileFollowState.followRequested;
    final isDisabled =
        followState == ProfileFollowState.blocked ||
        followState == ProfileFollowState.restricted;
    final followIcon = isRequested
        ? Icons.schedule_rounded
        : isFollowing
        ? Icons.how_to_reg_rounded
        : isDisabled
        ? Icons.block_rounded
        : Icons.person_add_alt_1_rounded;
    final followTooltip = isRequested
        ? 'Anfrage gesendet'
        : isFollowing
        ? 'Gefolgt'
        : isDisabled
        ? 'Folgen nicht verfügbar'
        : 'Folgen';

    return _ProfileVisitorActionsData(
      follow: _ProfileHeaderIconButton(
        tooltip: followTooltip,
        icon: followIcon,
        isBusy: isFollowActionBusy,
        isActive: isFollowing || isRequested,
        onPressed: previewOnly || isDisabled || isFollowActionBusy
            ? null
            : onFollow,
      ),
      message: _ProfileHeaderIconButton(
        tooltip: 'Nachricht senden',
        icon: Icons.chat_bubble_outline_rounded,
        onPressed: previewOnly ? null : onMessage,
      ),
    );
  }
}

class _ProfileVisitorActionsData extends StatelessWidget {
  const _ProfileVisitorActionsData({
    required this.follow,
    required this.message,
  });

  final Widget follow;
  final Widget message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Center(child: follow)),
        Expanded(child: Center(child: message)),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}

class _ProfileHeaderIconButton extends StatelessWidget {
  const _ProfileHeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isBusy = false,
    this.isActive = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isBusy;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Ink(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xE6080B12),
              border: Border.all(
                color: isActive
                    ? CaRismaDesignTokens.bluePrimary
                    : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Center(
              child: isBusy
                  ? const SizedBox.square(
                      dimension: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CaRismaDesignTokens.blueBright,
                      ),
                    )
                  : Icon(
                      icon,
                      color: isActive
                          ? CaRismaDesignTokens.blueBright
                          : Colors.white,
                      size: 17,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileVehicleHeroArtwork extends StatelessWidget {
  const _ProfileVehicleHeroArtwork({
    required this.imageUrl,
    required this.hasVehicle,
    required this.isDebugVehicle,
  });

  final String imageUrl;
  final bool hasVehicle;
  final bool isDebugVehicle;

  @override
  Widget build(BuildContext context) {
    final fallback = Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Icon(
          hasVehicle
              ? Icons.directions_car_filled_rounded
              : Icons.route_rounded,
          color: CaRismaDesignTokens.blueBright.withValues(alpha: 0.42),
          size: 72,
        ),
      ),
    );
    final image = isDebugVehicle
        ? Image.asset(
            'assets/images/debug_bmw_x6_m50d.png',
            fit: BoxFit.contain,
            alignment: Alignment.centerRight,
            filterQuality: FilterQuality.high,
          )
        : imageUrl.isEmpty
        ? fallback
        : Image.network(
            imageUrl,
            fit: BoxFit.contain,
            alignment: Alignment.centerRight,
            filterQuality: FilterQuality.high,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : fallback,
            errorBuilder: (_, _, _) => fallback,
          );
    final enhancedImage = ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1.12,
        0,
        0,
        0,
        8,
        0,
        1.12,
        0,
        0,
        10,
        0,
        0,
        1.18,
        0,
        16,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: image,
    );
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.transparent, Colors.white, Colors.white],
        stops: [0, 0.18, 1],
      ).createShader(bounds),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.88, 1],
        ).createShader(bounds),
        child: enhancedImage,
      ),
    );
  }
}

class _ProfileHeroStats extends StatelessWidget {
  const _ProfileHeroStats({
    required this.posts,
    required this.followers,
    required this.following,
    required this.onFollowersTap,
    required this.onFollowingTap,
    this.visitorActions,
  });

  final int posts;
  final int? followers;
  final int? following;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;
  final Widget? visitorActions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (visitorActions != null) ...[
          visitorActions!,
          const SizedBox(height: 3),
        ],
        Row(
          children: [
            Expanded(
              child: _ProfileHeroStat(label: 'Beiträge', value: posts),
            ),
            const _ProfileStatDivider(),
            Expanded(
              child: _ProfileHeroStat(
                label: 'Follower',
                value: followers,
                onTap: onFollowersTap,
              ),
            ),
            const _ProfileStatDivider(),
            Expanded(
              child: _ProfileHeroStat(
                label: 'Folgt',
                value: following,
                onTap: onFollowingTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileHeroStat extends StatelessWidget {
  const _ProfileHeroStat({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final int? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value?.toString() ?? '–',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CaRismaDesignTokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStatDivider extends StatelessWidget {
  const _ProfileStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: 0.13),
    );
  }
}

class _ProfileMainVehicleCard extends StatelessWidget {
  const _ProfileMainVehicleCard({
    required this.vehicle,
    required this.showPlate,
  });

  final ProfileVehicle vehicle;
  final bool showPlate;

  @override
  Widget build(BuildContext context) {
    final regionPresentation = registrationRegionPresentationFor(
      countryCode: vehicle.countryCode,
      plateCode: vehicle.plateRegion,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE5142C55), Color(0xED0A1427)],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const style = TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              );
              return Text(
                _fittingVehicleLabel(vehicle, constraints.maxWidth, style),
                maxLines: 1,
                style: style,
              );
            },
          ),
          const SizedBox(height: 5),
          if (showPlate)
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 30,
                width: 116,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 300,
                    height: 78,
                    child: CaRismaLicensePlatePreview(
                      countryCode: vehicle.countryCode,
                      region: vehicle.plateRegion,
                      letters: vehicle.plateLetters,
                      numbers: vehicle.plateNumbers,
                      regionPresentation: regionPresentation,
                    ),
                  ),
                ),
              ),
            )
          else
            const Text(
              'Kennzeichen verborgen',
              style: TextStyle(
                color: CaRismaDesignTokens.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

String _fittingVehicleLabel(
  ProfileVehicle vehicle,
  double maxWidth,
  TextStyle style,
) {
  final parts = <String>[
    vehicle.brand.trim(),
    vehicle.model.trim(),
    vehicle.series?.trim() ?? '',
  ].where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.isEmpty) return 'Fahrzeug';

  for (var length = parts.length; length > 0; length -= 1) {
    final candidate = parts.take(length).join(' ');
    final painter = TextPainter(
      text: TextSpan(text: candidate, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    if (!painter.didExceedMaxLines && painter.width <= maxWidth) {
      return candidate;
    }
  }
  return parts.first;
}

class _FollowRequestsBanner extends StatelessWidget {
  const _FollowRequestsBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: CaRismaDesignTokens.card,
            border: Border.all(
              color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.82),
              width: 1.3,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.person_add_alt_1_rounded,
                color: CaRismaDesignTokens.blueBright,
                size: 21,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  count == 1 ? '1 Folgeanfrage' : '$count Folgeanfragen',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: CaRismaDesignTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowListSheet extends StatefulWidget {
  const _FollowListSheet({
    required this.title,
    required this.relationships,
    required this.showFollower,
    required this.canManage,
    required this.onRemove,
  });

  final String title;
  final Stream<List<FollowRelationship>> relationships;
  final bool showFollower;
  final bool canManage;
  final Future<void> Function(FollowRelationship relationship) onRemove;

  @override
  State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _busyIds = <String>{};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _remove(FollowRelationship relationship) async {
    if (_busyIds.contains(relationship.id)) return;
    setState(() => _busyIds.add(relationship.id));
    try {
      await widget.onRemove(relationship);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die Beziehung konnte nicht entfernt werden.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(relationship.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  _SheetHeader(
                    icon: Icons.people_outline_rounded,
                    title: widget.title,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    style: const TextStyle(
                      color: CaRismaDesignTokens.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'In dieser Liste suchen',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<List<FollowRelationship>>(
                      stream: widget.relationships,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const _FollowListMessage(
                            icon: Icons.lock_outline_rounded,
                            text: 'Diese Liste kann nicht geladen werden.',
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final relationships = snapshot.data!
                            .where((item) {
                              final name = widget.showFollower
                                  ? item.followerDisplayName
                                  : item.followedDisplayName;
                              return _query.isEmpty ||
                                  name.toLowerCase().contains(_query);
                            })
                            .toList(growable: false);
                        if (relationships.isEmpty) {
                          return _FollowListMessage(
                            icon: Icons.people_outline_rounded,
                            text: _query.isEmpty
                                ? 'Noch keine Einträge.'
                                : 'Kein passender Eintrag.',
                          );
                        }
                        return ListView.separated(
                          controller: scrollController,
                          itemCount: relationships.length,
                          separatorBuilder: (_, _) => Divider(
                            color: CaRismaDesignTokens.textPrimary.withValues(
                              alpha: 0.06,
                            ),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final relationship = relationships[index];
                            return _FollowRelationshipTile(
                              name: widget.showFollower
                                  ? relationship.followerDisplayName
                                  : relationship.followedDisplayName,
                              photoUrl: widget.showFollower
                                  ? relationship.followerPhotoUrl
                                  : relationship.followedPhotoUrl,
                              trailing: widget.canManage
                                  ? IconButton(
                                      tooltip: widget.showFollower
                                          ? 'Follower entfernen'
                                          : 'Nicht mehr folgen',
                                      onPressed:
                                          _busyIds.contains(relationship.id)
                                          ? null
                                          : () => _remove(relationship),
                                      icon: _busyIds.contains(relationship.id)
                                          ? const SizedBox.square(
                                              dimension: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person_remove_outlined,
                                            ),
                                    )
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FollowRequestsSheet extends StatefulWidget {
  const _FollowRequestsSheet({
    required this.requests,
    required this.onAccept,
    required this.onDecline,
  });

  final Stream<List<FollowRelationship>> requests;
  final Future<void> Function(FollowRelationship request) onAccept;
  final Future<void> Function(FollowRelationship request) onDecline;

  @override
  State<_FollowRequestsSheet> createState() => _FollowRequestsSheetState();
}

class _FollowRequestsSheetState extends State<_FollowRequestsSheet> {
  final Set<String> _busyIds = <String>{};

  Future<void> _handle(
    FollowRelationship request, {
    required bool accept,
  }) async {
    if (_busyIds.contains(request.id)) return;
    setState(() => _busyIds.add(request.id));
    try {
      if (accept) {
        await widget.onAccept(request);
      } else {
        await widget.onDecline(request);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Die Folgeanfrage konnte nicht angenommen werden.'
                : 'Die Folgeanfrage konnte nicht abgelehnt werden.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _SheetHeader(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Folgeanfragen',
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<FollowRelationship>>(
                    stream: widget.requests,
                    builder: (context, snapshot) {
                      final items =
                          snapshot.data ?? const <FollowRelationship>[];
                      if (snapshot.hasError) {
                        return const _FollowListMessage(
                          icon: Icons.cloud_off_rounded,
                          text: 'Folgeanfragen konnten nicht geladen werden.',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (items.isEmpty) {
                        return const _FollowListMessage(
                          icon: Icons.person_add_disabled_outlined,
                          text: 'Keine offenen Folgeanfragen.',
                        );
                      }
                      return ListView.separated(
                        controller: scrollController,
                        itemCount: items.length,
                        separatorBuilder: (_, _) => Divider(
                          color: CaRismaDesignTokens.textPrimary.withValues(
                            alpha: 0.06,
                          ),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final request = items[index];
                          final isBusy = _busyIds.contains(request.id);
                          return _FollowRelationshipTile(
                            name: request.followerDisplayName,
                            photoUrl: request.followerPhotoUrl,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Ablehnen',
                                  onPressed: isBusy
                                      ? null
                                      : () => _handle(request, accept: false),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                                IconButton.filled(
                                  tooltip: 'Annehmen',
                                  onPressed: isBusy
                                      ? null
                                      : () => _handle(request, accept: true),
                                  icon: isBusy
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowRelationshipTile extends StatelessWidget {
  const _FollowRelationshipTile({
    required this.name,
    required this.photoUrl,
    this.trailing,
  });

  final String name;
  final String? photoUrl;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final imageUrl = photoUrl?.trim() ?? '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      leading: CircleAvatar(
        radius: 23,
        backgroundColor: CaRismaDesignTokens.blueDark,
        backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
        child: imageUrl.isEmpty
            ? const Icon(
                Icons.person_rounded,
                color: CaRismaDesignTokens.onAccent,
              )
            : null,
      ),
      title: Text(
        name.trim().isEmpty ? 'plaqa Nutzer' : name.trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: CaRismaDesignTokens.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      trailing: trailing,
    );
  }
}

class _FollowListMessage extends StatelessWidget {
  const _FollowListMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: CaRismaDesignTokens.textMuted, size: 32),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CaRismaDesignTokens.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialAvatar extends StatelessWidget {
  const _SocialAvatar({
    required this.profile,
    required this.size,
    required this.hasActiveStory,
    required this.showStoryBadge,
    required this.storyBadgeIcon,
    required this.isStoryActionBusy,
    this.onTap,
    this.onLongPress,
    this.onStoryBadgeTap,
  });

  final profile_data.UserProfile? profile;
  final double size;
  final bool hasActiveStory;
  final bool showStoryBadge;
  final IconData storyBadgeIcon;
  final bool isStoryActionBusy;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onStoryBadgeTap;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile?.photoUrl?.trim();
    final localPath = profile?.profilePhotoLocalPath?.trim();
    final localFile = localPath == null || localPath.isEmpty
        ? null
        : File(localPath);
    final hasLocalPhoto = localFile != null && localFile.existsSync();
    final hasRemotePhoto = photoUrl != null && photoUrl.isNotEmpty;
    final avatarChild = hasLocalPhoto
        ? Image.file(localFile, fit: BoxFit.cover)
        : hasRemotePhoto
        ? Image.network(
            photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.person_rounded,
              color: CaRismaDesignTokens.textPrimary,
              size: 38,
            ),
          )
        : const Icon(
            Icons.person_rounded,
            color: CaRismaDesignTokens.textPrimary,
            size: 38,
          );

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasActiveStory
                    ? CaRismaDesignTokens.blueGradient
                    : null,
                color: hasActiveStory
                    ? null
                    : CaRismaDesignTokens.textPrimary.withValues(alpha: 0.10),
                boxShadow: [
                  BoxShadow(
                    color: hasActiveStory
                        ? CaRismaDesignTokens.blueBright.withValues(alpha: 0.26)
                        : Colors.black.withValues(alpha: 0.28),
                    blurRadius: hasActiveStory ? 20 : 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: Container(
                  color: CaRismaDesignTokens.surface2,
                  child: avatarChild,
                ),
              ),
            ),
            if (showStoryBadge)
              Positioned(
                right: -12,
                bottom: -11,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isStoryActionBusy ? null : onStoryBadgeTap,
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CaRismaDesignTokens.bluePrimary,
                          border: Border.all(
                            color: CaRismaDesignTokens.background,
                            width: 3,
                          ),
                        ),
                        child: isStoryActionBusy
                            ? const Padding(
                                padding: EdgeInsets.all(4),
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                  color: CaRismaDesignTokens.onAccent,
                                ),
                              )
                            : Icon(
                                storyBadgeIcon,
                                color: CaRismaDesignTokens.onAccent,
                                size: 15,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _ProfileIdentityAction { addStory, changePhoto }

enum _ProfileCreateAction { story, post }

enum _ProfilePhotoAction { gallery, camera, remove }

enum _VehicleGalleryPickerAction {
  galleryImage,
  cameraImage,
  galleryVideo,
  cameraVideo,
}

String _vehicleGalleryCategoryLabel(ProfileVehicleGalleryCategory category) {
  return switch (category) {
    ProfileVehicleGalleryCategory.exterior => 'Außenansicht',
    ProfileVehicleGalleryCategory.interior => 'Innenraum',
    ProfileVehicleGalleryCategory.engineBay => 'Motorraum',
    ProfileVehicleGalleryCategory.details => 'Details',
    ProfileVehicleGalleryCategory.modifications => 'Umbauten',
    ProfileVehicleGalleryCategory.beforeAfter => 'Vorher/Nachher',
    ProfileVehicleGalleryCategory.documentation => 'Dokumentation',
  };
}

class _ProfilePhotoActionTile extends StatelessWidget {
  const _ProfilePhotoActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? CaRismaDesignTokens.danger
        : CaRismaDesignTokens.blueBright;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: CaRismaDesignTokens.controlSurface,
            border: Border.all(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.075),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDestructive
                        ? CaRismaDesignTokens.danger
                        : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: CaRismaDesignTokens.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: CaRismaDesignTokens.card,
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ProfileTabButton(
              label: 'Beiträge',
              icon: Icons.grid_view_rounded,
              isSelected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ProfileTabButton(
              label: 'Fahrzeug',
              icon: Icons.directions_car_rounded,
              isSelected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  const _ProfileTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: isSelected ? Colors.white : CaRismaDesignTokens.textMuted,
      fontWeight: FontWeight.w900,
    );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: CaRismaDesignTokens.card,
            border: Border.all(
              color: isSelected
                  ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.88)
                  : CaRismaDesignTokens.textPrimary.withValues(alpha: 0.08),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : CaRismaDesignTokens.textMuted,
                size: 19,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialPostSectionContent extends StatelessWidget {
  const _SocialPostSectionContent({
    super.key,
    required this.posts,
    required this.canCreatePost,
    required this.onCreatePost,
    required this.onOpenPost,
    required this.emptyTitle,
    required this.emptyDescription,
  });

  final List<SocialPost> posts;
  final bool canCreatePost;
  final VoidCallback onCreatePost;
  final ValueChanged<SocialPost> onOpenPost;
  final String emptyTitle;
  final String emptyDescription;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: _EmptyPostsState(
          canCreatePost: canCreatePost,
          onCreatePost: onCreatePost,
          title: emptyTitle,
          description: emptyDescription,
        ),
      );
    }

    return _ProfilePostGrid(posts: posts, onOpenPost: onOpenPost);
  }
}

class _SocialPostsLoadingState extends StatelessWidget {
  const _SocialPostsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      key: ValueKey('social-posts-loading'),
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _SocialPostsFeedbackState extends StatelessWidget {
  const _SocialPostsFeedbackState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          CaRismaBlueIconBox(icon: icon, size: 48, iconSize: 23),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: CaRismaDesignTokens.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CaRismaDesignTokens.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          CaRismaSecondaryButton(
            label: actionLabel,
            icon: Icons.refresh_rounded,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            borderRadius: 18,
            fontSize: 14,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

class _EmptyPostsState extends StatelessWidget {
  const _EmptyPostsState({
    required this.canCreatePost,
    required this.onCreatePost,
    required this.title,
    required this.description,
  });

  final bool canCreatePost;
  final VoidCallback onCreatePost;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      key: const ValueKey('empty-posts'),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const CaRismaBlueIconBox(
            icon: Icons.photo_library_outlined,
            size: 50,
            iconSize: 24,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: CaRismaDesignTokens.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CaRismaDesignTokens.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (canCreatePost) ...[
            const SizedBox(height: 16),
            CaRismaSecondaryButton(
              label: 'Ersten Beitrag erstellen',
              icon: Icons.add_rounded,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              borderRadius: 20,
              fontSize: 15,
              onPressed: onCreatePost,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfilePostGrid extends StatelessWidget {
  const _ProfilePostGrid({required this.posts, required this.onOpenPost});

  final List<SocialPost> posts;
  final ValueChanged<SocialPost> onOpenPost;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const ValueKey('profile-post-grid'),
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        final post = posts[index];
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: () => onOpenPost(post),
            borderRadius: BorderRadius.circular(13),
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CaRismaDesignTokens.surface2,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _SocialPostImage(post: post),
                    if (post.resolvedMedia.length > 1)
                      const Positioned(
                        top: 7,
                        right: 7,
                        child: Icon(
                          Icons.collections_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    if (post.resolvedMedia.first.isVideo)
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    if (post.isPinned)
                      const Positioned(
                        top: 7,
                        left: 7,
                        child: Icon(
                          Icons.push_pin_rounded,
                          color: CaRismaDesignTokens.blueBright,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SocialPostImage extends StatelessWidget {
  const _SocialPostImage({required this.post});

  final SocialPost post;

  @override
  Widget build(BuildContext context) {
    if (_isDebugProfileContent(post.id)) {
      return _DebugPostArtwork(source: post.imageUrl);
    }

    final media = post.resolvedMedia.first;
    if (media.isVideo) {
      return const ColoredBox(
        color: CaRismaDesignTokens.surface2,
        child: Center(
          child: Icon(
            Icons.videocam_rounded,
            color: CaRismaDesignTokens.textMuted,
            size: 34,
          ),
        ),
      );
    }

    return Image.network(
      media.url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: CaRismaDesignTokens.surface2,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: CaRismaDesignTokens.textMuted,
            size: 30,
          ),
        ),
      ),
    );
  }
}

class _DebugPostArtwork extends StatelessWidget {
  const _DebugPostArtwork({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final isRoad = source.endsWith('road');
    final isDetail = source.endsWith('detail');
    final isInterior = source.endsWith('interior');
    final isNight = source.endsWith('night');
    final icon = isRoad
        ? Icons.route_rounded
        : isDetail
        ? Icons.album_rounded
        : isInterior
        ? Icons.airline_seat_recline_extra_rounded
        : isNight
        ? Icons.nightlight_round
        : Icons.directions_car_filled_rounded;
    final title = isRoad
        ? 'ABENDFAHRT'
        : isDetail
        ? 'M50d DETAIL'
        : isInterior
        ? 'M INTERIEUR'
        : isNight
        ? 'NACHTAUFNAHME'
        : 'BMW X6 M50d';
    final accent = isDetail || isInterior
        ? const Color(0xFFFF7A1A)
        : CaRismaDesignTokens.blueBright;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 180;
        return ColoredBox(
          color: const Color(0xFF0D1016),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: -constraints.maxWidth * 0.12,
                right: constraints.maxWidth * 0.16,
                bottom: -constraints.maxHeight * 0.25,
                child: Container(
                  height: constraints.maxHeight * 0.68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      constraints.maxHeight * 0.3,
                    ),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.5),
                      width: compact ? 2 : 4,
                    ),
                  ),
                ),
              ),
              Center(
                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: compact ? 36 : 84,
                ),
              ),
              Positioned(
                left: compact ? 8 : 18,
                right: compact ? 8 : 18,
                bottom: compact ? 8 : 18,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 9 : 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (!CaRismaAppConfig.storeScreenshotMode)
                Positioned(
                  top: compact ? 7 : 14,
                  left: compact ? 7 : 14,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 6 : 9,
                      vertical: compact ? 3 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: CaRismaDesignTokens.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.78)),
                    ),
                    child: Text(
                      'BEISPIEL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 7 : 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SocialTextField extends StatelessWidget {
  const _SocialTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int? maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        counterStyle: TextStyle(
          color: CaRismaDesignTokens.textMuted.withValues(alpha: 0.85),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PostMediaPicker extends StatelessWidget {
  const _PostMediaPicker({
    required this.media,
    required this.isLoading,
    required this.onGallery,
    required this.onCamera,
    required this.onRemove,
  });

  final List<XFile> media;
  final bool isLoading;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final ValueChanged<XFile> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 210),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: media.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const CaRismaBlueIconBox(
                    icon: Icons.image_rounded,
                    size: 48,
                    iconSize: 23,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Fotos oder Videos auswählen',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wähle bis zu zehn Medien aus oder öffne die Kamera.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CaRismaDesignTokens.textSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CaRismaSecondaryButton(
                          label: 'Galerie',
                          icon: Icons.photo_library_rounded,
                          isEnabled: !isLoading,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          borderRadius: 18,
                          fontSize: 13.5,
                          onPressed: onGallery,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CaRismaSecondaryButton(
                          label: 'Kamera',
                          icon: Icons.photo_camera_rounded,
                          isEnabled: !isLoading,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          borderRadius: 18,
                          fontSize: 13.5,
                          onPressed: onCamera,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1.35,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _LocalPostMediaPreview(file: media.first),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: media.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final file = media[index];
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox.square(
                                dimension: 58,
                                child: _LocalPostMediaPreview(file: file),
                              ),
                            ),
                            Positioned(
                              top: -5,
                              right: -5,
                              child: GestureDetector(
                                onTap: () => onRemove(file),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Color(0xFFEF4444),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CaRismaSecondaryButton(
                          label: 'Galerie',
                          icon: Icons.photo_library_rounded,
                          isEnabled: !isLoading,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          borderRadius: 16,
                          fontSize: 13,
                          onPressed: onGallery,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CaRismaSecondaryButton(
                          label: 'Kamera',
                          icon: Icons.photo_camera_rounded,
                          isEnabled: !isLoading,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          borderRadius: 16,
                          fontSize: 13,
                          onPressed: onCamera,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _LocalPostMediaPreview extends StatelessWidget {
  const _LocalPostMediaPreview({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    if (_postMediaTypeFor(file) == SocialPostMediaType.video) {
      return const ColoredBox(
        color: CaRismaDesignTokens.surface2,
        child: Center(
          child: Icon(Icons.play_circle_fill_rounded, color: Colors.white),
        ),
      );
    }
    return Image.file(File(file.path), fit: BoxFit.cover);
  }
}

class _PostVisibilitySelector extends StatelessWidget {
  const _PostVisibilitySelector({required this.value, required this.onChanged});

  final SocialPostVisibility value;
  final ValueChanged<SocialPostVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = <SocialPostVisibility, String>{
      SocialPostVisibility.public: 'Öffentlich',
      SocialPostVisibility.contacts: 'Nur Kontakte',
      SocialPostVisibility.onlyMe: 'Nur ich',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 7, 10, 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.visibility_outlined,
            color: CaRismaDesignTokens.blueBright,
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Sichtbarkeit',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<SocialPostVisibility>(
              value: value,
              isDense: true,
              dropdownColor: CaRismaDesignTokens.surface2,
              borderRadius: BorderRadius.circular(16),
              iconEnabledColor: CaRismaDesignTokens.blueBright,
              icon: const Padding(
                padding: EdgeInsets.only(left: 5),
                child: Icon(Icons.keyboard_arrow_down_rounded),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              items: labels.entries
                  .map(
                    (entry) => DropdownMenuItem<SocialPostVisibility>(
                      value: entry.key,
                      child: Text(entry.value, maxLines: 1),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (selection) {
                if (selection != null) onChanged(selection);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PostMetaTile extends StatelessWidget {
  const _PostMetaTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: CaRismaDesignTokens.blueBright, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            width: 132,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CaRismaDesignTokens.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _displayNameFor(profile_data.UserProfile? profile) {
  if (CaRismaAppConfig.storeScreenshotMode) {
    return CaRismaAppConfig.storeDemoDisplayName;
  }
  final firstName = profile?.firstName.trim() ?? '';
  final lastName = profile?.lastName.trim() ?? '';
  final displayName = profile?.displayName.trim() ?? '';
  if (displayName.isNotEmpty) return displayName;
  if (firstName.isEmpty && lastName.isEmpty) return 'plaqa Nutzer';
  if (firstName.isEmpty) return '${lastName.characters.first.toUpperCase()}.';
  if (lastName.isEmpty) return firstName;
  return '$firstName ${lastName.characters.first.toUpperCase()}.';
}

String _profileSubtitleFor(profile_data.UserProfile? profile) {
  final parts = <String>[_profileRegionFor(profile)];
  return parts.where((part) => part.trim().isNotEmpty).join(' · ');
}

String _profileRegionFor(profile_data.UserProfile? profile) {
  if (CaRismaAppConfig.storeScreenshotMode) return 'Hamburg';
  final publicRegion = profile?.publicRegion?.trim() ?? '';
  if (publicRegion.isNotEmpty) return publicRegion;
  return _safeText(profile?.country, 'Region offen');
}

String _vehicleShortLabelFor(profile_data.UserProfile? profile) {
  final brand = profile?.vehicleBrand?.trim() ?? '';
  final model = profile?.vehicleModel?.trim() ?? '';
  if (brand.isEmpty && model.isEmpty) return 'Fahrzeug noch offen';
  return [brand, model].where((part) => part.isNotEmpty).join(' ');
}

SocialPostMediaType _postMediaTypeFor(XFile file) {
  final mimeType = file.mimeType?.toLowerCase() ?? '';
  final path = file.path.toLowerCase();
  if (mimeType.startsWith('video/') ||
      path.endsWith('.mp4') ||
      path.endsWith('.mov') ||
      path.endsWith('.m4v') ||
      path.endsWith('.webm')) {
    return SocialPostMediaType.video;
  }
  return SocialPostMediaType.image;
}

String _safeText(String? value, String fallback) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
}
