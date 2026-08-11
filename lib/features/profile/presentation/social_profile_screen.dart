import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/models/carisma_models.dart';
import '../../../shared/plate/plate_country_config.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/carisma_secondary_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../chats/data/chat_story_repository.dart';
import '../../chats/presentation/chats_screen.dart';
import '../data/follow_repository.dart';
import '../data/profile_media_storage.dart';
import '../data/profile_repository.dart';
import '../data/profile_vehicle.dart';
import '../data/profile_vehicle_encounter.dart';
import '../data/profile_vehicle_encounter_repository.dart';
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
import 'widgets/profile_vehicle_encounter_request_sheet.dart';
import 'widgets/profile_vehicle_editor_sheet.dart';
import 'widgets/profile_vehicle_modification_sheet.dart';
import 'widgets/profile_vehicle_panel.dart';
import 'widgets/profile_vehicle_timeline_sheet.dart';

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
  });

  final AppUserState? userState;
  final String? profileUserId;
  final bool isOwnProfile;
  final bool readOnly;

  @override
  State<SocialProfileScreen> createState() => _SocialProfileScreenState();
}

class _SocialProfileScreenState extends State<SocialProfileScreen> {
  final ProfileRepository _profileRepository = ProfileRepository();
  final ProfileMediaStorage _profileMediaStorage = ProfileMediaStorage();
  final SocialPostRepository _socialPostRepository = SocialPostRepository();
  final ChatStoryRepository _storyRepository = ChatStoryRepository();
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
  final ProfileVehicleEncounterRepository _profileVehicleEncounterRepository =
      ProfileVehicleEncounterRepository();
  final ImagePicker _imagePicker = ImagePicker();
  late final Stream<int> _followerCountStream;
  late final Stream<int> _followingCountStream;
  Stream<FollowSummary>? _followSummaryStream;
  int _selectedTab = 0;
  bool _isFollowActionBusy = false;
  bool _isCreatingStory = false;
  bool _legacyVehicleSyncScheduled = false;
  final Set<String> _busyHeroVehicleIds = <String>{};

  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? widget.userState?.userId ?? '';

  String get _userId {
    final targetUserId = widget.profileUserId?.trim() ?? '';
    return targetUserId.isNotEmpty ? targetUserId : _currentUserId;
  }

  bool get _isOwnProfile => widget.isOwnProfile && _userId == _currentUserId;

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
    if (!widget.readOnly &&
        !_isOwnProfile &&
        currentUserId.isNotEmpty &&
        profileUserId.isNotEmpty) {
      _followSummaryStream = _followRepository.watchSummary(
        currentUserId: currentUserId,
        profileUserId: profileUserId,
      );
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
    } catch (error, stackTrace) {
      debugPrint('Vehicle hero request could not start: $error\n$stackTrace');
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
      builder: (context) => _FollowRequestsSheet(
        requests: _followRepository.watchFollowRequests(_userId),
        onAccept: _followRepository.acceptRequest,
        onDecline: _followRepository.declineRequest,
      ),
    );
  }

  Widget _buildProfileHero(profile_data.UserProfile? profile, int postCount) {
    final storyStream = _currentUserId.trim().isEmpty
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
                          postCount: postCount,
                          followerCount: followerSnapshot.hasError
                              ? null
                              : followerSnapshot.data,
                          followingCount: followingSnapshot.hasError
                              ? null
                              : followingSnapshot.data,
                          followState: summary.state,
                          isFollowActionBusy: _isFollowActionBusy,
                          isCreatingStory: _isCreatingStory,
                          isOwnProfile: _isOwnProfile,
                          isReadOnly: widget.readOnly,
                          activeStory: activeStory,
                          onAvatarTap: activeStory != null
                              ? () => _openProfileStory(
                                  activeStory,
                                  profileStories,
                                )
                              : _isOwnProfile
                              ? () => _showProfileIdentityActions(profile)
                              : null,
                          onAvatarLongPress: _isOwnProfile
                              ? () => _showProfileIdentityActions(profile)
                              : null,
                          onAddStory: _isOwnProfile
                              ? () => _createProfileStory()
                              : null,
                          onEdit: () => _showEditPublicProfileSheet(profile),
                          onCreatePost: () => _showCreatePostSheet(profile),
                          onFollow: () => _handleFollowAction(profile, summary),
                          onMessage: () => Navigator.of(context).maybePop(),
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
                        if (_isOwnProfile)
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
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CaRismaBackground(
      child: SafeArea(
        child: StreamBuilder<profile_data.UserProfile?>(
          stream: _isOwnProfile
              ? _profileRepository.watchProfile(_userId)
              : _profileRepository.watchPublicProfile(_userId),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            _scheduleLegacyVehicleSync(profile);
            return StreamBuilder<List<SocialPost>>(
              stream: _socialPostRepository.watchUserPosts(
                userId: _userId,
                viewerUserId: _currentUserId,
              ),
              builder: (context, postsSnapshot) {
                final posts = postsSnapshot.data ?? const <SocialPost>[];
                final isLoadingPosts =
                    postsSnapshot.connectionState == ConnectionState.waiting &&
                    !postsSnapshot.hasData;
                final isVehicleTab = _selectedTab == 1;
                final visiblePosts = posts
                    .where(
                      (post) =>
                          post.section ==
                          (isVehicleTab
                              ? SocialPostSection.vehicle
                              : SocialPostSection.posts),
                    )
                    .toList(growable: false);
                final postsContent = postsSnapshot.hasError
                    ? _SocialPostsFeedbackState(
                        key: const ValueKey('social-posts-error'),
                        icon: Icons.cloud_off_rounded,
                        title: 'Beiträge konnten nicht geladen werden',
                        description:
                            'Prüfe deine Verbindung und versuche es erneut.',
                        actionLabel: 'Erneut versuchen',
                        onAction: () => setState(() {}),
                      )
                    : isLoadingPosts
                    ? const _SocialPostsLoadingState()
                    : _SocialPostSectionContent(
                        key: ValueKey(
                          isVehicleTab ? 'vehicle-posts' : 'profile-posts',
                        ),
                        posts: visiblePosts,
                        canCreatePost: _isOwnProfile,
                        onCreatePost: () => _showCreatePostSheet(
                          profile,
                          initialSection: isVehicleTab
                              ? SocialPostSection.vehicle
                              : SocialPostSection.posts,
                        ),
                        onOpenPost: _showPostDetails,
                        emptyTitle: isVehicleTab
                            ? 'Noch keine Fahrzeugbilder'
                            : 'Noch keine Beiträge',
                        emptyDescription: isVehicleTab
                            ? _isOwnProfile
                                  ? 'Zeige dein Fahrzeug aus den besten Perspektiven.'
                                  : 'Dieser Nutzer hat noch keine Fahrzeugbilder geteilt.'
                            : _isOwnProfile
                            ? 'Teile dein Fahrzeug, Treffen oder besondere Momente.'
                            : 'Dieser Nutzer hat noch keine Beiträge geteilt.',
                      );
                return CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        CaRismaDesignTokens.mainScreenTopInset,
                        20,
                        CaRismaDesignTokens.mainScreenBottomInset +
                            keyboardInset +
                            10,
                      ),
                      sliver: SliverList.list(
                        children: [
                          _buildProfileHero(profile, posts.length),
                          const SizedBox(height: 22),
                          _ProfileTabs(
                            selectedIndex: _selectedTab,
                            onChanged: (index) =>
                                setState(() => _selectedTab = index),
                          ),
                          const SizedBox(height: 16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: isVehicleTab
                                ? Column(
                                    key: const ValueKey('vehicle-posts'),
                                    children: [
                                      ProfileVehiclePanel(
                                        profile: profile,
                                        postCount: posts.length,
                                        vehicles: _isOwnProfile
                                            ? _profileVehicleRepository
                                                  .watchOwnerVehicles(_userId)
                                            : _profileVehicleRepository
                                                  .watchVisibleVehicles(
                                                    _userId,
                                                  ),
                                        isOwnProfile: _isOwnProfile,
                                        onAdd: () =>
                                            _openVehicleEditor(profile),
                                        onEdit: (vehicle) => _openVehicleEditor(
                                          profile,
                                          vehicle: vehicle,
                                        ),
                                        onEditDetails: _openVehicleDetails,
                                        onSetPrimary: _setPrimaryVehicle,
                                        onArchive: _archiveVehicle,
                                        onGenerateHero:
                                            _requestVehicleHeroImage,
                                        isHeroRequestBusy: (vehicleId) =>
                                            _busyHeroVehicleIds.contains(
                                              vehicleId,
                                            ),
                                        galleryMediaForVehicle: (vehicleId) =>
                                            _isOwnProfile
                                            ? _profileVehicleGalleryRepository
                                                  .watchOwnerMedia(
                                                    userId: _userId,
                                                    vehicleId: vehicleId,
                                                  )
                                            : _profileVehicleGalleryRepository
                                                  .watchVisibleMedia(
                                                    userId: _userId,
                                                    vehicleId: vehicleId,
                                                  ),
                                        onAddGalleryMedia:
                                            _addVehicleGalleryImage,
                                        onSetMainGalleryMedia: (_, media) =>
                                            _setMainVehicleGalleryImage(media),
                                        onDeleteGalleryMedia:
                                            _deleteVehicleGalleryImage,
                                        modificationsForVehicle: (vehicleId) =>
                                            _isOwnProfile
                                            ? _profileVehicleModificationRepository
                                                  .watchOwnerModifications(
                                                    userId: _userId,
                                                    vehicleId: vehicleId,
                                                  )
                                            : _profileVehicleModificationRepository
                                                  .watchVisibleModifications(
                                                    userId: _userId,
                                                    vehicleId: vehicleId,
                                                  ),
                                        onAddModification:
                                            _openVehicleModificationEditor,
                                        onEditModification:
                                            (vehicle, modification) =>
                                                _openVehicleModificationEditor(
                                                  vehicle,
                                                  modification: modification,
                                                ),
                                        onDeleteModification:
                                            _deleteVehicleModification,
                                        timelineEntriesForVehicle:
                                            (vehicleId) => _isOwnProfile
                                            ? _profileVehicleTimelineRepository
                                                  .watchOwnerEntries(
                                                    userId: _userId,
                                                    vehicleId: vehicleId,
                                                  )
                                            : _profileVehicleTimelineRepository
                                                  .watchVisibleEntries(
                                                    userId: _userId,
                                                    vehicleId: vehicleId,
                                                  ),
                                        onAddTimelineEntry:
                                            _openVehicleTimelineEditor,
                                        onEditTimelineEntry: (vehicle, entry) =>
                                            _openVehicleTimelineEditor(
                                              vehicle,
                                              entry: entry,
                                            ),
                                        onDeleteTimelineEntry:
                                            _deleteVehicleTimelineEntry,
                                        currentUserId: _currentUserId,
                                        encountersForVehicle: (vehicleId) =>
                                            _isOwnProfile
                                            ? _profileVehicleEncounterRepository
                                                  .watchOwnerEncounters(
                                                    userId: _userId,
                                                    vehicleId: vehicleId,
                                                  )
                                            : _profileVehicleEncounterRepository
                                                  .watchVisibleEncounters(
                                                    userId: _userId,
                                                    vehicleId: vehicleId,
                                                  ),
                                        onRequestEncounter: (vehicle) =>
                                            _requestVehicleEncounter(
                                              profile,
                                              vehicle,
                                            ),
                                        onAcceptEncounter:
                                            _acceptVehicleEncounter,
                                        onDeclineEncounter:
                                            _declineVehicleEncounter,
                                        onRemoveEncounter:
                                            _removeVehicleEncounter,
                                      ),
                                      const SizedBox(height: 16),
                                      postsContent,
                                    ],
                                  )
                                : postsContent,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hauptfahrzeug konnte nicht geändert werden: $error'),
        ),
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
      backgroundColor: const Color(0xFF0D1320),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medium konnte nicht gespeichert werden: $error'),
        ),
      );
    }
  }

  Future<ProfileVehicleGalleryCategory?> _chooseVehicleGalleryCategory() {
    return showModalBottomSheet<ProfileVehicleGalleryCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1320),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Text(
              'Kategorie wählen',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final category in ProfileVehicleGalleryCategory.values)
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hauptbild konnte nicht geändert werden: $error'),
        ),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Medium konnte nicht entfernt werden: $error')),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Umbau konnte nicht entfernt werden: $error')),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Timeline-Ereignis konnte nicht entfernt werden: $error',
          ),
        ),
      );
    }
  }

  Future<void> _requestVehicleEncounter(
    profile_data.UserProfile? targetProfile,
    ProfileVehicle targetVehicle,
  ) async {
    if (_isOwnProfile ||
        _currentUserId.isEmpty ||
        _userId.isEmpty ||
        targetProfile == null) {
      return;
    }
    try {
      final vehicles = await _profileVehicleRepository
          .watchOwnerVehicles(_currentUserId)
          .first;
      final visibleVehicles = vehicles
          .where((vehicle) => vehicle.isPubliclyVisible)
          .toList(growable: false);
      if (!mounted) return;
      if (visibleVehicles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gib zuerst mindestens ein Fahrzeug für Kontakte frei.',
            ),
          ),
        );
        return;
      }
      final draft = await showProfileVehicleEncounterRequestSheet(
        context,
        ownVehicles: visibleVehicles,
        targetVehicle: targetVehicle,
      );
      if (draft == null || !mounted) return;
      final currentProfile = await _profileRepository.getProfile(
        _currentUserId,
      );
      final encounterId = _profileVehicleEncounterRepository.encounterIdFor(
        firstUserId: _currentUserId,
        firstVehicleId: draft.ownVehicle.id,
        secondUserId: _userId,
        secondVehicleId: targetVehicle.id,
      );
      await _profileVehicleEncounterRepository.createRequest(
        ProfileVehicleEncounter(
          id: encounterId,
          initiatorUserId: _currentUserId,
          recipientUserId: _userId,
          initiatorVehicleId: draft.ownVehicle.id,
          recipientVehicleId: targetVehicle.id,
          initiatorVehicleLabel: draft.ownVehicle.displayName,
          recipientVehicleLabel: targetVehicle.displayName,
          participantUserIds: [_currentUserId, _userId],
          initiatorPhotoUrl: currentProfile?.photoUrl,
          recipientPhotoUrl: targetProfile.photoUrl,
          type: draft.type,
          status: ProfileVehicleEncounterStatus.requested,
          locationLabel: draft.locationLabel,
          encounterDate: draft.encounterDate,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Begegnungsanfrage gesendet.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Begegnung konnte nicht angefragt werden: $error'),
        ),
      );
    }
  }

  Future<void> _acceptVehicleEncounter(
    ProfileVehicleEncounter encounter,
  ) async {
    try {
      await _profileVehicleEncounterRepository.accept(encounter);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Begegnung bestätigt.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Begegnung konnte nicht bestätigt werden: $error'),
        ),
      );
    }
  }

  Future<void> _declineVehicleEncounter(
    ProfileVehicleEncounter encounter,
  ) async {
    try {
      await _profileVehicleEncounterRepository.decline(encounter);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Begegnungsanfrage abgelehnt.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Anfrage konnte nicht abgelehnt werden: $error'),
        ),
      );
    }
  }

  Future<void> _removeVehicleEncounter(
    ProfileVehicleEncounter encounter,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Begegnung entfernen?'),
        content: const Text(
          'Die Begegnung wird aus beiden Fahrzeugprofilen entfernt.',
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
      await _profileVehicleEncounterRepository.remove(encounter);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Begegnung entfernt.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Begegnung konnte nicht entfernt werden: $error'),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fahrzeug konnte nicht archiviert werden: $error'),
        ),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Story konnte nicht gespeichert werden: $error'),
        ),
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

      final upload = await _profileMediaStorage.uploadProfilePhoto(
        userId: _userId,
        file: File(image.path),
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

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profilbild gespeichert.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profilbild konnte nicht gespeichert werden: $error'),
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

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profilbild entfernt.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profilbild konnte nicht entfernt werden: $error'),
        ),
      );
    }
  }

  Future<void> _showEditPublicProfileSheet(
    profile_data.UserProfile? profile,
  ) async {
    final displayNameController = TextEditingController(
      text: _displayNameFor(profile),
    );
    final bioController = TextEditingController(text: _publicBioFor(profile));
    final regionController = TextEditingController(
      text: _profileRegionFor(profile),
    );
    var isSaving = false;
    var showVehicle = profile?.showVehicleOnPublicProfile ?? false;
    var showPlate = profile?.showPlateOnPublicProfile ?? false;
    var isPrivateProfile = profile?.isPrivateProfile ?? true;
    var profileAccessEnabled = profile?.profileAccessEnabled ?? true;
    var followersVisibility = profile?.followersVisibility ?? 'contacts';
    var followingVisibility = profile?.followingVisibility ?? 'contacts';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> savePublicProfile() async {
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
                  publicBio: bioController.text,
                  publicRegion: regionController.text,
                  showVehicleOnPublicProfile: showVehicle,
                  showPlateOnPublicProfile: showPlate,
                  isPrivateProfile: isPrivateProfile,
                  profileAccessEnabled: profileAccessEnabled,
                  followersVisibility: followersVisibility,
                  followingVisibility: followingVisibility,
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
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Profil konnte nicht gespeichert werden: $error',
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
              padding: EdgeInsets.fromLTRB(14, 0, 14, 14 + keyboardInset),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SheetHeader(
                          icon: Icons.edit_rounded,
                          title: 'Öffentliches Profil',
                          onClose: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(height: 14),
                        _SocialTextField(
                          controller: displayNameController,
                          label: 'Anzeigename',
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 10),
                        _SocialTextField(
                          controller: bioController,
                          label: 'Biografie / Fahrzeugzeile',
                          icon: Icons.directions_car_filled_outlined,
                        ),
                        const SizedBox(height: 10),
                        _SocialTextField(
                          controller: regionController,
                          label: 'Stadt / Region',
                          icon: Icons.location_city_rounded,
                        ),
                        const SizedBox(height: 10),
                        _PublicVisibilitySwitch(
                          icon: Icons.directions_car_filled_outlined,
                          title: 'Fahrzeug öffentlich anzeigen',
                          value: showVehicle,
                          onChanged: (value) =>
                              setSheetState(() => showVehicle = value),
                        ),
                        const SizedBox(height: 10),
                        _PublicVisibilitySwitch(
                          icon: Icons.pin_outlined,
                          title: 'Kennzeichen öffentlich anzeigen',
                          value: showPlate,
                          onChanged: (value) =>
                              setSheetState(() => showPlate = value),
                        ),
                        const SizedBox(height: 10),
                        _PublicVisibilitySwitch(
                          icon: Icons.visibility_outlined,
                          title: 'Profil für Kontakte freigeben',
                          value: profileAccessEnabled,
                          onChanged: (value) =>
                              setSheetState(() => profileAccessEnabled = value),
                        ),
                        const SizedBox(height: 10),
                        _PublicVisibilitySwitch(
                          icon: Icons.lock_outline_rounded,
                          title: 'Privates Profil',
                          value: isPrivateProfile,
                          onChanged: (value) =>
                              setSheetState(() => isPrivateProfile = value),
                        ),
                        const SizedBox(height: 10),
                        _ProfileVisibilitySelector(
                          icon: Icons.people_outline_rounded,
                          title: 'Follower-Liste',
                          value: followersVisibility,
                          onChanged: (value) =>
                              setSheetState(() => followersVisibility = value),
                        ),
                        const SizedBox(height: 10),
                        _ProfileVisibilitySelector(
                          icon: Icons.person_search_outlined,
                          title: 'Gefolgt-Liste',
                          value: followingVisibility,
                          onChanged: (value) =>
                              setSheetState(() => followingVisibility = value),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Persönliche Daten, Dokumente und Kennzeichen verwaltest du sicher in den Einstellungen.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: CaRismaDesignTokens.textSecondary,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 14),
                        CaRismaPrimaryButton(
                          label: 'Übernehmen',
                          icon: Icons.check_rounded,
                          isLoading: isSaving,
                          loadingLabel: 'Speichert...',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          borderRadius: 20,
                          iconSize: 21,
                          fontSize: 15,
                          showShadow: false,
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

    displayNameController.dispose();
    bioController.dispose();
    regionController.dispose();
  }

  Future<void> _showCreatePostSheet(
    profile_data.UserProfile? profile, {
    SocialPostSection initialSection = SocialPostSection.posts,
  }) async {
    if (!_isOwnProfile) {
      return;
    }

    XFile? selectedImage;
    bool isPicking = false;
    bool isPublishing = false;
    var selectedSection = initialSection;
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickImage(ImageSource source) async {
              if (isPicking) return;
              setSheetState(() => isPicking = true);
              try {
                final image = await _imagePicker.pickImage(
                  source: source,
                  imageQuality: 88,
                  maxWidth: 1600,
                );
                if (image != null) setSheetState(() => selectedImage = image);
              } finally {
                if (context.mounted) setSheetState(() => isPicking = false);
              }
            }

            Future<void> publishPost() async {
              final image = selectedImage;
              if (image == null || isPublishing) return;

              setSheetState(() => isPublishing = true);
              try {
                await _socialPostRepository.createImagePost(
                  userId: _userId,
                  imageFile: File(image.path),
                  caption: descriptionController.text,
                  vehicleLabel: _vehicleShortLabelFor(profile),
                  locationLabel: locationController.text,
                  section: selectedSection,
                );

                if (!context.mounted) return;
                Navigator.of(context).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Beitrag veröffentlicht.')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Beitrag konnte nicht veröffentlicht werden: $error',
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
              padding: EdgeInsets.fromLTRB(14, 0, 14, 14 + keyboardInset),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  top: false,
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
                        _PostImagePicker(
                          image: selectedImage,
                          isLoading: isPicking,
                          onGallery: () => pickImage(ImageSource.gallery),
                          onCamera: () => pickImage(ImageSource.camera),
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
                        _SocialTextField(
                          controller: locationController,
                          label: 'Ort (optional)',
                          icon: Icons.location_on_outlined,
                          maxLength: 120,
                        ),
                        const SizedBox(height: 14),
                        CaRismaPrimaryButton(
                          label: 'Veröffentlichen',
                          icon: Icons.send_rounded,
                          isEnabled:
                              selectedImage != null &&
                              !isPicking &&
                              !isPublishing,
                          isLoading: isPublishing,
                          loadingLabel: 'Veröffentlicht...',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          borderRadius: 20,
                          iconSize: 21,
                          fontSize: 15,
                          showShadow: false,
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

    descriptionController.dispose();
    locationController.dispose();
  }

  Future<void> _showPostDetails(SocialPost post) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final maxImageHeight = MediaQuery.of(context).size.height * 0.56;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetHeader(
                      icon: Icons.photo_outlined,
                      title: 'Beitrag',
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxImageHeight),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.network(
                            post.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                DecoratedBox(
                                  decoration: const BoxDecoration(
                                    color: CaRismaDesignTokens.surface2,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: CaRismaDesignTokens.textMuted,
                                      size: 34,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                    if (post.caption?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 14),
                      Text(
                        post.caption!.trim(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (post.vehicleLabel?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 14),
                      _PostMetaTile(
                        icon: Icons.directions_car_filled_outlined,
                        title: 'Fahrzeug',
                        value: post.vehicleLabel!.trim(),
                      ),
                    ],
                    if (post.locationLabel?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 10),
                      _PostMetaTile(
                        icon: Icons.location_on_outlined,
                        title: 'Ort',
                        value: post.locationLabel!.trim(),
                      ),
                    ],
                    if (_isOwnProfile) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDeletePost(post),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Beitrag löschen'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeletePost(SocialPost post) async {
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
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Beitrag gelöscht.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beitrag konnte nicht gelöscht werden: $error')),
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

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    required this.followState,
    required this.isFollowActionBusy,
    required this.isCreatingStory,
    required this.isOwnProfile,
    required this.isReadOnly,
    required this.activeStory,
    required this.onAvatarTap,
    required this.onAvatarLongPress,
    required this.onAddStory,
    required this.onEdit,
    required this.onCreatePost,
    required this.onFollow,
    required this.onMessage,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final profile_data.UserProfile? profile;
  final int postCount;
  final int? followerCount;
  final int? followingCount;
  final ProfileFollowState followState;
  final bool isFollowActionBusy;
  final bool isCreatingStory;
  final bool isOwnProfile;
  final bool isReadOnly;
  final ChatStoryRecord? activeStory;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
  final VoidCallback? onAddStory;
  final VoidCallback onEdit;
  final VoidCallback onCreatePost;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SocialAvatar(
                profile: profile,
                size: 68,
                hasActiveStory: activeStory != null,
                showStoryBadge: isOwnProfile,
                storyBadgeIcon: activeStory == null
                    ? Icons.photo_camera_rounded
                    : Icons.add_rounded,
                isStoryActionBusy: isCreatingStory,
                onTap: onAvatarTap,
                onLongPress: onAvatarLongPress,
                onStoryBadgeTap: onAddStory,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayNameFor(profile),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 23,
                            height: 1,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _profileSubtitleFor(profile),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CaRismaDesignTokens.textSecondary,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ProfileStatsRow(
            posts: postCount,
            followers: followerCount,
            following: followingCount,
            onFollowersTap: onFollowersTap,
            onFollowingTap: onFollowingTap,
          ),
          if (isOwnProfile) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: CaRismaSecondaryButton(
                    label: 'Profil bearbeiten',
                    icon: Icons.edit_rounded,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    borderRadius: 18,
                    fontSize: 13.5,
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CaRismaPrimaryButton(
                    label: 'Beitrag erstellen',
                    icon: Icons.add_rounded,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    borderRadius: 18,
                    iconSize: 18,
                    fontSize: 12,
                    showShadow: false,
                    onPressed: onCreatePost,
                  ),
                ),
              ],
            ),
          ] else if (!isReadOnly) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _FollowProfileButton(
                    state: followState,
                    isLoading: isFollowActionBusy,
                    onPressed: onFollow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CaRismaSecondaryButton(
                    label: 'Nachricht',
                    icon: Icons.chat_bubble_outline_rounded,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    borderRadius: 18,
                    fontSize: 13.5,
                    onPressed: onMessage,
                  ),
                ),
              ],
            ),
            if (followState == ProfileFollowState.followedBy) ...[
              const SizedBox(height: 9),
              Text(
                'Folgt dir',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CaRismaDesignTokens.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FollowProfileButton extends StatelessWidget {
  const _FollowProfileButton({
    required this.state,
    required this.isLoading,
    required this.onPressed,
  });

  final ProfileFollowState state;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isFollowing =
        state == ProfileFollowState.following ||
        state == ProfileFollowState.mutual;
    final isRequested = state == ProfileFollowState.followRequested;
    final isDisabled =
        state == ProfileFollowState.blocked ||
        state == ProfileFollowState.restricted;
    final label = switch (state) {
      ProfileFollowState.notFollowing => 'Folgen',
      ProfileFollowState.followRequested => 'Angefragt',
      ProfileFollowState.following => 'Gefolgt',
      ProfileFollowState.followedBy => 'Zurückfolgen',
      ProfileFollowState.mutual => 'Gefolgt',
      ProfileFollowState.blocked => 'Blockiert',
      ProfileFollowState.restricted => 'Eingeschränkt',
    };

    if (isFollowing || isRequested || isDisabled) {
      return CaRismaSecondaryButton(
        label: isLoading ? 'Wird geändert...' : label,
        icon: isRequested
            ? Icons.schedule_rounded
            : isFollowing
            ? Icons.person_remove_outlined
            : Icons.block_rounded,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        borderRadius: 18,
        fontSize: 13.5,
        isEnabled: !isLoading && !isDisabled,
        onPressed: onPressed,
      );
    }

    return CaRismaPrimaryButton(
      label: isLoading ? 'Wird geändert...' : label,
      icon: Icons.person_add_alt_1_rounded,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      borderRadius: 18,
      iconSize: 20,
      fontSize: 13.5,
      showShadow: false,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
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
            color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.12),
            border: Border.all(
              color: CaRismaDesignTokens.blueBright.withValues(alpha: 0.24),
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
                    color: Colors.white,
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
                    style: const TextStyle(color: Colors.white),
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
                            color: Colors.white.withValues(alpha: 0.06),
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
                          color: Colors.white.withValues(alpha: 0.06),
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
            ? const Icon(Icons.person_rounded, color: Colors.white)
            : null,
      ),
      title: Text(
        name.trim().isEmpty ? 'CaRisma Nutzer' : name.trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.white,
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
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.person_rounded, color: Colors.white, size: 38),
          )
        : const Icon(Icons.person_rounded, color: Colors.white, size: 38);

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
                    : Colors.white.withValues(alpha: 0.10),
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
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                storyBadgeIcon,
                                color: Colors.white,
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
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

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({
    required this.posts,
    required this.followers,
    required this.following,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final int posts;
  final int? followers;
  final int? following;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProfileStat(label: 'Beiträge', value: posts),
        ),
        Expanded(
          child: _ProfileStat(
            label: 'Follower',
            value: followers,
            onTap: onFollowersTap,
          ),
        ),
        Expanded(
          child: _ProfileStat(
            label: 'Folgt',
            value: following,
            onTap: onFollowingTap,
          ),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value, this.onTap});

  final String label;
  final int? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: CaRismaDesignTokens.controlSurface,
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: [
                Text(
                  value?.toString() ?? '–',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CaRismaDesignTokens.textSecondary,
                    fontWeight: FontWeight.w800,
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

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(6),
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
                  : Colors.white.withValues(alpha: 0.08),
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? Colors.white
                        : CaRismaDesignTokens.textMuted,
                    fontWeight: FontWeight.w900,
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
      return _EmptyPostsState(
        canCreatePost: canCreatePost,
        onCreatePost: onCreatePost,
        title: emptyTitle,
        description: emptyDescription,
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
              color: Colors.white,
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
              color: Colors.white,
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
            CaRismaPrimaryButton(
              label: 'Ersten Beitrag erstellen',
              icon: Icons.add_rounded,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              borderRadius: 20,
              iconSize: 21,
              fontSize: 15,
              showShadow: false,
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
                    Image.network(
                      post.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.broken_image_outlined,
                        color: CaRismaDesignTokens.textMuted,
                        size: 24,
                      ),
                    ),
                    if ((post.caption?.trim().isNotEmpty ?? false))
                      Positioned(
                        right: 7,
                        bottom: 7,
                        child: Icon(
                          Icons.notes_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 15,
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

class _SocialTextField extends StatelessWidget {
  const _SocialTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLength,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int? maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
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

class _PublicVisibilitySwitch extends StatelessWidget {
  const _PublicVisibilitySwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 9, 9, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: CaRismaDesignTokens.blueBright, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ProfileVisibilitySelector extends StatelessWidget {
  const _ProfileVisibilitySelector({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = <String, String>{
      'contacts': 'Profilkontakte',
      'followers': 'Nur Follower',
      'onlyMe': 'Nur ich',
    };
    final effectiveValue = labels.containsKey(value) ? value : 'contacts';

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 7, 10, 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: CaRismaDesignTokens.blueBright, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveValue,
              dropdownColor: CaRismaDesignTokens.surface2,
              borderRadius: BorderRadius.circular(16),
              iconEnabledColor: CaRismaDesignTokens.blueBright,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              items: labels.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
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

class _PostImagePicker extends StatelessWidget {
  const _PostImagePicker({
    required this.image,
    required this.isLoading,
    required this.onGallery,
    required this.onCamera,
  });

  final XFile? image;
  final bool isLoading;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final selectedImage = image;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 210),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: selectedImage == null
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
                    'Bild auswählen',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wähle ein Foto aus deiner Galerie oder öffne die Kamera.',
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
          : ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.file(File(selectedImage.path), fit: BoxFit.cover),
              ),
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
          Flexible(
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
  final firstName = profile?.firstName.trim() ?? '';
  final lastName = profile?.lastName.trim() ?? '';
  final displayName = profile?.displayName.trim() ?? '';
  if (displayName.isNotEmpty) return displayName;
  if (firstName.isEmpty && lastName.isEmpty) return 'CaRisma Nutzer';
  if (firstName.isEmpty) return '${lastName.characters.first.toUpperCase()}.';
  if (lastName.isEmpty) return firstName;
  return '$firstName ${lastName.characters.first.toUpperCase()}.';
}

String _profileSubtitleFor(profile_data.UserProfile? profile) {
  final publicBio = _publicBioFor(profile);
  if (publicBio.isNotEmpty) return publicBio;

  final parts = <String>[
    _vehicleShortLabelFor(profile),
    _profileRegionFor(profile),
    _displayPlateFor(profile),
  ];
  return parts.where((part) => part.trim().isNotEmpty).join(' · ');
}

String _vehicleLineFor(profile_data.UserProfile? profile) =>
    '${_vehicleShortLabelFor(profile)} · ${_displayPlateFor(profile)}';

String _publicBioFor(profile_data.UserProfile? profile) {
  final publicBio = profile?.publicBio?.trim() ?? '';
  return publicBio.isNotEmpty ? publicBio : _vehicleLineFor(profile);
}

String _profileRegionFor(profile_data.UserProfile? profile) {
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

String _displayPlateFor(profile_data.UserProfile? profile) {
  final displayPlate = formatDisplayPlate(
    countryCode: profile?.countryCode ?? 'DE',
    region: profile?.plateRegion ?? '',
    letters: profile?.plateLetters ?? '',
    numbers: profile?.plateNumbers ?? '',
  );
  return displayPlate.isEmpty ? 'Kennzeichen nicht öffentlich' : displayPlate;
}

String _safeText(String? value, String fallback) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
}
