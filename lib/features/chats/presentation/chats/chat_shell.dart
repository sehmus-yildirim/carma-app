part of '../chats_screen.dart';

enum _ChatsView { chats, requests }

enum _ChatListView { messages, archived, blocked }

enum _RequestListView { incoming, outgoing }

enum _ChatMenuAction {
  pin,
  favorite,
  mute,
  readState,
  vehicleDetails,
  archive,
  delete,
  block,
  unblock,
  report,
}

enum _LocalChatTestMode { empty, activeChat, activeChatWithMessages }

const _LocalChatTestMode _localChatTestMode = _LocalChatTestMode.empty;

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, required this.userState});

  final AppUserState userState;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final FirestoreChatRepository _chatRepository = FirestoreChatRepository();
  final FirestoreContactRequestRepository _requestRepository =
      FirestoreContactRequestRepository();
  final ChatStoryRepository _storyRepository = ChatStoryRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final ChatAttachmentStorage _attachmentStorage = ChatAttachmentStorage();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();

  _ChatsView _selectedView = _ChatsView.chats;
  _ChatListView _selectedChatListView = _ChatListView.messages;
  _RequestListView _selectedRequestListView = _RequestListView.incoming;
  String _searchQuery = '';
  String _streamUserId = '';
  bool _isAddingOwnStory = false;
  final Set<String> _busyRequestIds = <String>{};
  List<ChatStoryRecord> _cachedStories = const <ChatStoryRecord>[];
  Timer? _storyRefreshTimer;

  late Stream<List<ChatRecord>> _chatStream;
  late Stream<List<ChatRecord>> _archivedChatStream;
  late Stream<List<ChatRecord>> _blockedChatStream;
  late Stream<List<ChatStoryRecord>> _storyStream;
  late Stream<List<ContactRequestRecord>> _incomingRequestStream;
  late Stream<List<ContactRequestRecord>> _outgoingRequestStream;
  late bool _hasActiveChat;
  late List<_LocalChatMessage> _chatMessages;

  AppFeatureDecision get _chatGateDecision {
    return AppFeatureGate.evaluate(
      userState: widget.userState,
      feature: AppFeature.chat,
    );
  }

  String get _effectiveUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? widget.userState.userId;
  }

  @override
  void initState() {
    super.initState();
    _hasActiveChat =
        _localChatTestMode == _LocalChatTestMode.activeChat ||
        _localChatTestMode == _LocalChatTestMode.activeChatWithMessages;

    _chatMessages =
        _localChatTestMode == _LocalChatTestMode.activeChatWithMessages
        ? _buildLocalChatMessages()
        : <_LocalChatMessage>[];

    _streamUserId = _effectiveUserId.trim();
    _assignStreamsForCurrentUser(clearStories: true);
    _searchController.addListener(_handleSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanupExpiredOwnStory();
    });

    _storyRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _storyStream = _watchStories();
      });
      unawaited(_cleanupExpiredOwnStory(showError: false));
    });
  }

  @override
  void didUpdateWidget(covariant ChatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextUserId = _effectiveUserId.trim();

    if (nextUserId == _streamUserId) {
      return;
    }

    _streamUserId = nextUserId;
    _assignStreamsForCurrentUser(clearStories: true);
  }

  @override
  void dispose() {
    _storyRefreshTimer?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<ChatRecord>> _watchChats() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ChatRecord>>.value(const <ChatRecord>[]);
    }

    return _chatRepository.watchChats(userId: userId);
  }

  Stream<List<ChatRecord>> _watchArchivedChats() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ChatRecord>>.value(const <ChatRecord>[]);
    }

    return _chatRepository.watchArchivedChats(userId: userId);
  }

  Stream<List<ChatRecord>> _watchBlockedChats() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ChatRecord>>.value(const <ChatRecord>[]);
    }

    return _chatRepository.watchBlockedChats(userId: userId);
  }

  Stream<List<ChatStoryRecord>> _watchStories() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ChatStoryRecord>>.value(const <ChatStoryRecord>[]);
    }

    return _storyRepository.watchVisibleStories(userId: userId);
  }

  List<ChatStoryRecord> _visibleStoryRecords(List<ChatStoryRecord> stories) {
    final currentUserId = _effectiveUserId.trim();

    return stories
        .where((story) {
          return story.ownerUserId == currentUserId || !story.isExpired;
        })
        .toList(growable: false);
  }

  Stream<List<ContactRequestRecord>> _watchIncomingRequests() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ContactRequestRecord>>.value(
        const <ContactRequestRecord>[],
      );
    }

    return _requestRepository.watchIncomingRequests(userId: userId);
  }

  Stream<List<ContactRequestRecord>> _watchOutgoingRequests() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ContactRequestRecord>>.value(
        const <ContactRequestRecord>[],
      );
    }

    return _requestRepository.watchOutgoingRequests(userId: userId);
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text.trim();

    if (_searchQuery == nextQuery) {
      return;
    }

    setState(() {
      _searchQuery = nextQuery;
    });
  }

  bool _matchesSearch(String value) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    return value.toLowerCase().contains(query);
  }

  bool _matchesChatSearch(ChatRecord chat) {
    final currentUserId = _effectiveUserId;

    return _matchesSearch(
      [
        chat.displayNameFor(currentUserId),
        chat.vehicleTitle,
        chat.vehicleModelLabel,
        chat.vehicleColorLabel,
        chat.displayPlate,
        chat.lastMessage,
      ].whereType<String>().join(' '),
    );
  }

  bool _matchesRequestSearch(ContactRequestRecord request) {
    return _matchesSearch(
      [
        request.senderDisplayName,
        request.receiverDisplayName,
        request.displayPlate,
        request.plateKey,
        request.vehicleTitle,
        request.message,
      ].whereType<String>().join(' '),
    );
  }

  List<_LocalChatMessage> _buildLocalChatMessages() {
    return const [
      _LocalChatMessage(
        text:
            'Hey, ich bin gerade an deinem Fahrzeug vorbeigefahren. Dein Fenster scheint noch offen zu sein.',
        isMine: false,
        timeLabel: '14:21',
      ),
      _LocalChatMessage(
        text: 'Danke dir f\u00FCr den Hinweis. Ich schaue sofort nach.',
        isMine: true,
        timeLabel: '14:23',
      ),
      _LocalChatMessage(
        text: 'Gerne. Ich wollte nur kurz Bescheid geben.',
        isMine: false,
        timeLabel: '14:24',
      ),
    ];
  }

  void _selectView(_ChatsView view) {
    if (_selectedView == view) {
      return;
    }

    setState(() {
      _selectedView = view;
    });
  }

  void _handleViewSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() < 260) {
      return;
    }

    if (velocity < 0 && _selectedView == _ChatsView.chats) {
      _selectView(_ChatsView.requests);
      return;
    }

    if (velocity > 0 && _selectedView == _ChatsView.requests) {
      _selectView(_ChatsView.chats);
    }
  }

  void _selectChatListView(_ChatListView view) {
    if (_selectedChatListView == view) {
      return;
    }

    setState(() {
      _selectedChatListView = view;
    });
  }

  void _handleChatListSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() < 260) {
      return;
    }

    if (velocity < 0 && _selectedChatListView == _ChatListView.messages) {
      _selectChatListView(_ChatListView.archived);
      return;
    }

    if (velocity < 0 && _selectedChatListView == _ChatListView.archived) {
      _selectChatListView(_ChatListView.blocked);
      return;
    }

    if (velocity > 0 && _selectedChatListView == _ChatListView.archived) {
      _selectChatListView(_ChatListView.messages);
      return;
    }

    if (velocity > 0 && _selectedChatListView == _ChatListView.blocked) {
      _selectChatListView(_ChatListView.archived);
    }
  }

  void _selectRequestListView(_RequestListView view) {
    if (_selectedRequestListView == view) {
      return;
    }

    setState(() {
      _selectedRequestListView = view;
    });
  }

  void _handleRequestListSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() < 260) {
      return;
    }

    if (velocity < 0 && _selectedRequestListView == _RequestListView.incoming) {
      _selectRequestListView(_RequestListView.outgoing);
      return;
    }

    if (velocity > 0 && _selectedRequestListView == _RequestListView.outgoing) {
      _selectRequestListView(_RequestListView.incoming);
    }
  }

  void _refreshChatsAndRequests() {
    final nextUserId = _effectiveUserId.trim();

    setState(() {
      final userChanged = nextUserId != _streamUserId;

      if (userChanged) {
        _streamUserId = nextUserId;
      }

      _assignStreamsForCurrentUser(clearStories: userChanged);
    });
  }

  void _assignStreamsForCurrentUser({required bool clearStories}) {
    if (clearStories) {
      _cachedStories = const <ChatStoryRecord>[];
    }

    _chatStream = _watchChats();
    _archivedChatStream = _watchArchivedChats();
    _blockedChatStream = _watchBlockedChats();
    _storyStream = _watchStories();
    _incomingRequestStream = _watchIncomingRequests();
    _outgoingRequestStream = _watchOutgoingRequests();
  }

  Future<void> _cleanupExpiredOwnStory({bool showError = true}) async {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return;
    }

    try {
      await _storyRepository.deleteExpiredOwnStory(ownerUserId: userId);
    } catch (error) {
      if (!mounted || !showError) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Abgelaufene Story konnte nicht bereinigt werden: $error',
          ),
        ),
      );
    }
  }

  Future<void> _openChat(ChatRecord chat) async {
    final currentUserId = _effectiveUserId;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ChatConversationScreen(
          chatId: chat.id,
          initialMessages: const <_LocalChatMessage>[],
          displayName: chat.displayNameFor(currentUserId),
          profilePhotoUrl: chat.profilePhotoUrlFor(currentUserId),
          vehicleModel: chat.vehicleModelLabel,
          vehicleColor: chat.vehicleColorLabel,
          displayPlate: chat.displayPlate,
          isOnline: false,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _refreshChatsAndRequests();

    _refreshChatsAndRequests();
  }

  Future<void> _openLocalChat() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ChatConversationScreen(
          initialMessages: _chatMessages,
          isOnline: false,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _refreshChatsAndRequests();
  }

  Future<void> _openAcceptedChat(String chatId) async {
    final trimmedChatId = chatId.trim();

    if (trimmedChatId.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ChatConversationScreen(
          chatId: trimmedChatId,
          initialMessages: const <_LocalChatMessage>[],
          isOnline: false,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _refreshChatsAndRequests();
  }

  Future<void> _addOwnStory(List<ChatRecord> chats) async {
    final currentUserId = _effectiveUserId.trim();

    if (currentUserId.isEmpty || _isAddingOwnStory) {
      return;
    }

    setState(() {
      _isAddingOwnStory = true;
    });

    try {
      final captureResult = await Navigator.of(context)
          .push<_StoryCaptureResult>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => _StoryCaptureScreen(imagePicker: _imagePicker),
            ),
          );

      if (captureResult == null || captureResult.path.trim().isEmpty) {
        return;
      }

      if (!mounted) {
        return;
      }

      final vehicleStickerData = await _loadStoryVehicleStickerData(
        currentUserId,
      );

      if (!mounted) {
        return;
      }

      final draft = await Navigator.of(context).push<_StoryDraft>(
        MaterialPageRoute(
          builder: (_) => _StoryDraftEditorScreen(
            mediaPath: captureResult.path,
            isVideo: captureResult.isVideo,
            vehicleStickerData: vehicleStickerData,
          ),
        ),
      );

      if (draft == null) {
        return;
      }

      final storyId = DateTime.now().microsecondsSinceEpoch.toString();
      final upload = draft.isVideo
          ? await _attachmentStorage.uploadChatStoryVideo(
              userId: currentUserId,
              storyId: storyId,
              file: File(draft.mediaPath),
            )
          : await _attachmentStorage.uploadChatStoryImage(
              userId: currentUserId,
              storyId: storyId,
              file: File(draft.mediaPath),
            );
      final viewerUserIds = _storyViewerUserIdsFor(
        chats: chats,
        currentUserId: currentUserId,
      );
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final displayName = firebaseUser?.displayName?.trim().isNotEmpty == true
          ? firebaseUser!.displayName!.trim()
          : 'Carma Nutzer';

      await _storyRepository.setOwnImageStory(
        ownerUserId: currentUserId,
        ownerDisplayName: displayName,
        ownerPhotoUrl: firebaseUser?.photoURL,
        viewerUserIds: viewerUserIds,
        imageUrl: draft.isVideo ? '' : upload.url,
        imagePath: draft.isVideo ? '' : upload.path,
        mediaType: draft.isVideo ? 'video' : 'image',
        videoUrl: draft.isVideo ? upload.url : '',
        videoPath: draft.isVideo ? upload.path : '',
        videoIsMuted: draft.videoIsMuted,
        text: draft.text,
        textColorValue: draft.textColor.toARGB32(),
        textFontFamily: draft.textFontFamily,
        textIsBold: draft.textIsBold,
        textIsItalic: draft.textIsItalic,
        textIsUnderline: draft.textIsUnderline,
        textAlignmentX: (draft.textAlignment.x + 1) / 2,
        textAlignmentY: (draft.textAlignment.y + 1) / 2,
        filterType: draft.filterType,
        stickerType: draft.sticker.type,
        stickerLabel: draft.sticker.label,
        stickerPayload: draft.sticker.payload,
        stickerAlignmentX: (draft.sticker.alignment.x + 1) / 2,
        stickerAlignmentY: (draft.sticker.alignment.y + 1) / 2,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story wurde hinzugef\u00FCgt.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Story konnte nicht gespeichert werden: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingOwnStory = false;
        });
      } else {
        _isAddingOwnStory = false;
      }
    }
  }

  Future<_StoryVehicleStickerData?> _loadStoryVehicleStickerData(
    String userId,
  ) async {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return null;
    }

    try {
      final profile = await _profileRepository.getProfile(trimmedUserId);

      if (profile == null) {
        return null;
      }

      final vehicleParts = <String>[
        if ((profile.vehicleBrand ?? '').trim().isNotEmpty)
          profile.vehicleBrand!.trim(),
        if ((profile.vehicleModel ?? '').trim().isNotEmpty)
          profile.vehicleModel!.trim(),
      ];
      final vehicleLabel = vehicleParts.join(' ').trim();
      final plateLabel = formatDisplayPlate(
        countryCode: (profile.countryCode ?? profile.country).trim(),
        region: profile.plateRegion?.trim() ?? '',
        letters: profile.plateLetters?.trim() ?? '',
        numbers: profile.plateNumbers?.trim() ?? '',
      );

      final stickerData = _StoryVehicleStickerData(
        vehicleLabel: vehicleLabel,
        plateLabel: plateLabel,
      );

      return stickerData.isComplete ? stickerData : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _markStoryVisible(ChatStoryRecord story) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = _effectiveUserId.trim();
    final isOwnStory = story.ownerUserId == currentUserId;

    if (currentUserId.isEmpty || isOwnStory) {
      return;
    }

    try {
      final photoUrl = currentUser?.photoURL?.trim() ?? '';

      if (story.viewedAtBy.containsKey(currentUserId)) {
        final storedPhotoUrl =
            story.viewerPhotoUrlBy[currentUserId]?.trim() ?? '';

        if (photoUrl.isNotEmpty && storedPhotoUrl.isEmpty) {
          await _storyRepository.updateStoryViewerPhotoUrl(
            storyId: story.id,
            userId: currentUserId,
            photoUrl: photoUrl,
          );
        }

        return;
      }

      final displayName = currentUser?.displayName?.trim().isNotEmpty == true
          ? currentUser!.displayName!.trim()
          : 'Carma Nutzer';

      await _storyRepository.markStoryViewed(
        storyId: story.id,
        userId: currentUserId,
        displayName: displayName,
        photoUrl: photoUrl,
      );
    } catch (_) {
      // Viewing the story should not fail if the read receipt cannot be saved.
    }
  }

  List<String> _storyViewerUserIdsFor({
    required List<ChatRecord> chats,
    required String currentUserId,
  }) {
    final trimmedCurrentUserId = currentUserId.trim();

    if (trimmedCurrentUserId.isEmpty) {
      return const <String>[];
    }

    final viewerUserIds = <String>{trimmedCurrentUserId};

    for (final chat in chats) {
      if (!_canUseChatForStoryViewers(chat, trimmedCurrentUserId)) {
        continue;
      }

      for (final participant in chat.participants) {
        final trimmedParticipant = participant.trim();

        if (trimmedParticipant.isEmpty ||
            chat.isDeletedFor(trimmedParticipant)) {
          continue;
        }

        viewerUserIds.add(trimmedParticipant);
      }
    }

    final otherViewerUserIds =
        viewerUserIds.where((userId) => userId != trimmedCurrentUserId).toList()
          ..sort();

    return <String>[trimmedCurrentUserId, ...otherViewerUserIds.take(199)];
  }

  bool _canUseChatForStoryViewers(ChatRecord chat, String currentUserId) {
    return (chat.status == ChatStatus.active ||
            chat.status == ChatStatus.archived) &&
        chat.participants.contains(currentUserId) &&
        !chat.isDeletedFor(currentUserId);
  }

  Future<void> _openStory(
    ChatStoryRecord story,
    List<ChatStoryRecord> stories,
  ) async {
    final currentUserId = _effectiveUserId.trim();
    final isOwnStory = story.ownerUserId == currentUserId;

    if (story.isExpired && !isOwnStory) {
      setState(() {
        _storyStream = _watchStories();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diese Story ist abgelaufen.')),
      );
      return;
    }

    final visibleStories =
        (stories.isEmpty ? <ChatStoryRecord>[story] : stories)
            .where((visibleStory) {
              return visibleStory.ownerUserId == currentUserId ||
                  !visibleStory.isExpired;
            })
            .toList(growable: false);

    if (visibleStories.isEmpty) {
      setState(() {
        _storyStream = _watchStories();
      });
      return;
    }

    await _markStoryVisible(story);

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => _StoryViewerDialog(
        stories: visibleStories,
        initialStoryId: story.id,
        currentUserId: currentUserId,
        onStoryVisible: _markStoryVisible,
        onShowViewers: (visibleStory) =>
            _showStoryViewers(context, visibleStory),
        onDeleteStory: (_) => _confirmDeleteOwnStory(context),
        onOpenSticker: _openStorySticker,
        onReplyStory: _sendStoryReply,
        onVoteStoryPoll: _voteStoryPoll,
      ),
    );
  }

  Future<void> _voteStoryPoll(ChatStoryRecord story, int optionIndex) async {
    final currentUserId = _effectiveUserId.trim();

    if (currentUserId.isEmpty || story.ownerUserId == currentUserId) {
      return;
    }

    await _storyRepository.voteStoryPoll(
      storyId: story.id,
      userId: currentUserId,
      optionIndex: optionIndex,
    );
  }

  Future<void> _sendStoryReply(ChatStoryRecord story, String text) async {
    final currentUserId = _effectiveUserId.trim();
    final storyOwnerId = story.ownerUserId.trim();
    final trimmedText = text.trim();

    if (currentUserId.isEmpty ||
        storyOwnerId.isEmpty ||
        currentUserId == storyOwnerId ||
        trimmedText.isEmpty) {
      return;
    }

    final chats = await _chatRepository.loadChats(userId: currentUserId);
    ChatRecord? storyChat;

    for (final chat in chats) {
      if (chat.participants.contains(storyOwnerId) &&
          chat.isVisibleInActiveListFor(currentUserId)) {
        storyChat = chat;
        break;
      }
    }

    if (storyChat == null) {
      throw StateError('No active chat for story reply.');
    }

    await _chatRepository.sendTextMessage(
      chatId: storyChat.id,
      senderUserId: currentUserId,
      text: trimmedText,
      replyToText: _storyReplyPreview(story),
    );
  }

  String _storyReplyPreview(ChatStoryRecord story) {
    final label = story.text.trim().isNotEmpty
        ? story.text.trim()
        : story.stickerLabel.trim().isNotEmpty
        ? story.stickerLabel.trim()
        : story.isVideo
        ? 'Video-Story'
        : 'Foto-Story';

    final ownerName = story.ownerDisplayName.trim().isEmpty
        ? 'Carma Nutzer'
        : story.ownerDisplayName.trim();

    return 'Story von $ownerName: $label';
  }

  Future<void> _showStoryViewers(
    BuildContext context,
    ChatStoryRecord story,
  ) async {
    final viewers =
        story.viewedAtBy.entries
            .where((entry) => entry.key != story.ownerUserId)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.74;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _carmaBlue.withValues(alpha: 0.24),
                          Colors.white.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _carmaBlue.withValues(alpha: 0.82),
                          ),
                          child: const Icon(
                            Icons.visibility_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Story-Aufrufe',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Nur du kannst diese Liste sehen.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.62),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 34,
                          constraints: const BoxConstraints(minWidth: 34),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            '${viewers.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (viewers.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_off_rounded,
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Noch keine Aufrufe.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: viewers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final viewer = viewers[index];
                          final viewerName =
                              story.viewerNameBy[viewer.key]?.trim() ?? '';
                          final label = viewerName.isEmpty
                              ? 'Carma Nutzer'
                              : viewerName;
                          final photoUrl = story.viewerPhotoUrlBy[viewer.key]
                              ?.trim();

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                _AvatarCircle(
                                  size: 42,
                                  imageUrl: photoUrl,
                                  iconSize: 24,
                                  fallbackLabel: label,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _formatStorySeenAt(viewer.value),
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.58,
                                          ),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.visibility_rounded,
                                  color: Colors.white.withValues(alpha: 0.42),
                                  size: 20,
                                ),
                              ],
                            ),
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

  Future<void> _confirmDeleteOwnStory(BuildContext dialogContext) async {
    final shouldDelete = await showDialog<bool>(
      context: dialogContext,
      builder: (context) {
        return _StoryDeleteDialog(
          backgroundColor: const Color(0xFF101827),
          title: const Text(
            'Story löschen?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: Text(
            'Deine aktuelle Story wird entfernt.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final currentUserId = _effectiveUserId.trim();

    if (currentUserId.isEmpty) {
      return;
    }

    try {
      await _storyRepository.deleteOwnStory(ownerUserId: currentUserId);
    } catch (error) {
      if (!dialogContext.mounted) {
        return;
      }

      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(content: Text('Story konnte nicht gelöscht werden: $error')),
      );
      return;
    }

    if (!dialogContext.mounted) {
      return;
    }

    Navigator.of(dialogContext).pop();

    if (!mounted) {
      return;
    }

    _refreshChatsAndRequests();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Story wurde gelöscht.')));
  }

  Future<void> _openStorySticker(ChatStoryRecord story) async {
    final type = story.stickerType.trim();
    final payload = story.stickerPayload.trim();

    if (payload.isEmpty) {
      return;
    }

    void showStickerError() {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sticker konnte nicht geöffnet werden.')),
      );
    }

    try {
      if (type == 'location') {
        final parts = payload.split(',');

        if (parts.length != 2) {
          showStickerError();
          return;
        }

        final latitude = double.tryParse(parts[0].trim());
        final longitude = double.tryParse(parts[1].trim());

        if (latitude == null || longitude == null) {
          showStickerError();
          return;
        }

        await ChatNativeBridge().openMap(
          latitude: latitude,
          longitude: longitude,
        );
        return;
      }

      if (type == 'link') {
        await ChatNativeBridge().openDocumentUrl(
          url: _normalizeStoryLink(payload),
          contentType: 'text/html',
        );
        return;
      }

      if (type == 'hashtag') {
        final hashtag = payload.startsWith('#') ? payload : '#$payload';
        await Clipboard.setData(ClipboardData(text: hashtag));

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Hashtag wurde kopiert.')));
        return;
      }

      if (type == 'vehicle') {
        await _showStoryVehicleStickerSheet(story);
        return;
      }

      if (type == 'status') {
        await _showStoryStatusStickerSheet(story);
        return;
      }
    } catch (_) {
      showStickerError();
    }
  }

  Future<void> _showStoryVehicleStickerSheet(ChatStoryRecord story) async {
    final stickerLabel = story.stickerLabel.trim();
    final stickerPayload = story.stickerPayload.trim();
    final vehicleStyle = _vehicleStickerStyleFromPayload(stickerPayload);
    final payloadPlateLabel = _vehicleStickerDetailFromPayload(stickerPayload);
    final vehicleLabel = stickerLabel.isEmpty || vehicleStyle == 'plate'
        ? 'Fahrzeug'
        : stickerLabel;
    final plateLabel = payloadPlateLabel.isNotEmpty
        ? payloadPlateLabel
        : vehicleStyle == 'plate'
        ? stickerLabel
        : '';

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _StoryStickerInfoSheet(
          icon: Icons.directions_car_filled_rounded,
          title: vehicleLabel,
          subtitle: 'Fahrzeug-Sticker von ${story.ownerDisplayName}',
          rows: [
            _StoryStickerInfoRow(
              label: 'Fahrzeug',
              value: vehicleLabel,
              icon: Icons.directions_car_rounded,
            ),
            if (plateLabel.isNotEmpty)
              _StoryStickerInfoRow(
                label: 'Kennzeichen',
                value: plateLabel,
                icon: Icons.pin_rounded,
              ),
          ],
          actionIcon: Icons.copy_rounded,
          actionLabel: plateLabel.isEmpty ? null : 'Kennzeichen kopieren',
          onAction: plateLabel.isEmpty
              ? null
              : () async {
                  final navigator = Navigator.of(sheetContext);
                  final messenger = ScaffoldMessenger.of(context);

                  await Clipboard.setData(ClipboardData(text: plateLabel));

                  if (!mounted) {
                    return;
                  }

                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Kennzeichen wurde kopiert.')),
                  );
                },
        );
      },
    );
  }

  Future<void> _showStoryStatusStickerSheet(ChatStoryRecord story) async {
    final statusLabel = story.stickerLabel.trim().isEmpty
        ? story.stickerPayload.trim()
        : story.stickerLabel.trim();

    if (!mounted || statusLabel.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _StoryStickerInfoSheet(
          icon: _storyStatusStickerIcon(statusLabel),
          title: statusLabel,
          subtitle: 'Status von ${story.ownerDisplayName}',
          rows: [
            _StoryStickerInfoRow(
              label: 'Status',
              value: statusLabel,
              icon: _storyStatusStickerIcon(statusLabel),
            ),
          ],
          actionIcon: Icons.copy_rounded,
          actionLabel: 'Status kopieren',
          onAction: () async {
            final navigator = Navigator.of(sheetContext);
            final messenger = ScaffoldMessenger.of(context);

            await Clipboard.setData(ClipboardData(text: statusLabel));

            if (!mounted) {
              return;
            }

            navigator.pop();
            messenger.showSnackBar(
              const SnackBar(content: Text('Status wurde kopiert.')),
            );
          },
        );
      },
    );
  }

  Future<void> _runRequestAction({
    required ContactRequestRecord request,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (_busyRequestIds.contains(request.id)) {
      return;
    }

    setState(() {
      _busyRequestIds.add(request.id);
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      _refreshChatsAndRequests();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Aktion fehlgeschlagen: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestIds.remove(request.id);
        });
      }
    }
  }

  Future<void> _acceptRequest(ContactRequestRecord request) async {
    if (_busyRequestIds.contains(request.id)) {
      return;
    }

    setState(() {
      _busyRequestIds.add(request.id);
    });

    try {
      final useCase = AcceptContactRequestUseCase(
        contactRequestRepository: _requestRepository,
        chatRepository: _chatRepository,
      );

      final result = await useCase(request: request);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kontaktanfrage wurde angenommen.')),
      );
      _refreshChatsAndRequests();
      await _openAcceptedChat(result.chat.id);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Aktion fehlgeschlagen: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestIds.remove(request.id);
        });
      }
    }
  }

  Future<void> _declineRequest(ContactRequestRecord request) {
    return _runRequestAction(
      request: request,
      successMessage: 'Kontaktanfrage wurde abgelehnt.',
      action: () async {
        await _requestRepository.declineRequest(requestId: request.id);
      },
    );
  }

  Future<void> _withdrawRequest(ContactRequestRecord request) {
    return _runRequestAction(
      request: request,
      successMessage: 'Kontaktanfrage wurde zurückgezogen.',
      action: () async {
        await _requestRepository.withdrawRequest(requestId: request.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final chatGateDecision = _chatGateDecision;

    return CarmaBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 112 + keyboardInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CarmaPageHeader(
                icon: Icons.chat_bubble_rounded,
                title: 'Chats',
              ),
              const SizedBox(height: 22),
              if (!chatGateDecision.isAllowed)
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: _ChatAccessBlockedCard(
                      message:
                          chatGateDecision.reason ??
                          'Chats sind aktuell nicht verf\u00FCgbar.',
                    ),
                  ),
                )
              else ...[
                _ChatsSegmentedControl(
                  selectedView: _selectedView,
                  onChanged: _selectView,
                ),
                const SizedBox(height: 14),
                _ChatSearchField(controller: _searchController),
                const SizedBox(height: 16),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: _handleViewSwipe,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _selectedView == _ChatsView.chats
                          ? StreamBuilder<List<ChatRecord>>(
                              key: const ValueKey('chats_view'),
                              stream: _chatStream,
                              builder: (context, snapshot) {
                                final chats =
                                    snapshot.data ?? const <ChatRecord>[];
                                final isLoading =
                                    snapshot.connectionState ==
                                    ConnectionState.waiting;

                                return StreamBuilder<List<ChatRecord>>(
                                  stream: _archivedChatStream,
                                  builder: (context, archivedSnapshot) {
                                    final archivedChats =
                                        archivedSnapshot.data ??
                                        const <ChatRecord>[];
                                    final isArchivedLoading =
                                        archivedSnapshot.connectionState ==
                                        ConnectionState.waiting;

                                    return StreamBuilder<List<ChatRecord>>(
                                      stream: _blockedChatStream,
                                      builder: (context, blockedSnapshot) {
                                        final blockedChats =
                                            blockedSnapshot.data ??
                                            const <ChatRecord>[];
                                        final isBlockedLoading =
                                            blockedSnapshot.connectionState ==
                                            ConnectionState.waiting;

                                        return StreamBuilder<
                                          List<ChatStoryRecord>
                                        >(
                                          stream: _storyStream,
                                          initialData: _cachedStories,
                                          builder: (context, storySnapshot) {
                                            final storyData =
                                                storySnapshot.data;

                                            if (storyData != null &&
                                                !storySnapshot.hasError) {
                                              _cachedStories = storyData;
                                            }

                                            final stories =
                                                _visibleStoryRecords(
                                                  storyData ?? _cachedStories,
                                                );

                                            return _ChatsOverview(
                                              chats: chats,
                                              archivedChats: archivedChats,
                                              blockedChats: blockedChats,
                                              stories: stories,
                                              isAddingOwnStory:
                                                  _isAddingOwnStory,
                                              isLoading:
                                                  isLoading ||
                                                  isArchivedLoading ||
                                                  isBlockedLoading,
                                              hasLocalActiveChat:
                                                  _hasActiveChat,
                                              localMessages: _chatMessages,
                                              searchQuery: _searchQuery,
                                              selectedListView:
                                                  _selectedChatListView,
                                              matchesChat: _matchesChatSearch,
                                              onListViewChanged:
                                                  _selectChatListView,
                                              onHorizontalSwipe:
                                                  _handleChatListSwipe,
                                              onOpenChat: _openChat,
                                              onOpenLocalChat: _openLocalChat,
                                              onAddOwnStory: _addOwnStory,
                                              onOpenStory: _openStory,
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            )
                          : _RequestsOverview(
                              key: const ValueKey('requests_view'),
                              incomingStream: _incomingRequestStream,
                              outgoingStream: _outgoingRequestStream,
                              busyRequestIds: _busyRequestIds,
                              searchQuery: _searchQuery,
                              selectedListView: _selectedRequestListView,
                              matchesRequest: _matchesRequestSearch,
                              onListViewChanged: _selectRequestListView,
                              onHorizontalSwipe: _handleRequestListSwipe,
                              onAccept: _acceptRequest,
                              onDecline: _declineRequest,
                              onWithdraw: _withdrawRequest,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryDeleteDialog extends StatelessWidget {
  const _StoryDeleteDialog({
    Color? backgroundColor,
    Widget? title,
    Widget? content,
    List<Widget>? actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF101827).withValues(alpha: 0.94),
                  const Color(0xFF071120).withValues(alpha: 0.90),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.36),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.redAccent.withValues(alpha: 0.16),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Story löschen?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Deine aktuelle Story wird entfernt.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                    height: 1.32,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Abbrechen',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Löschen',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryStickerInfoRow {
  const _StoryStickerInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _StoryStickerInfoSheet extends StatelessWidget {
  const _StoryStickerInfoSheet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rows,
    this.actionIcon,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<_StoryStickerInfoRow> rows;
  final IconData? actionIcon;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final safeRows = rows
        .where((row) => row.value.trim().isNotEmpty)
        .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0B223B).withValues(alpha: 0.96),
                    const Color(0xFF122C48).withValues(alpha: 0.94),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: [
                  BoxShadow(
                    color: _carmaBlue.withValues(alpha: 0.2),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_carmaBlue, _carmaBlueLight],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _carmaBlue.withValues(alpha: 0.34),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                  ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (safeRows.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    for (final row in safeRows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _StoryStickerInfoTile(row: row),
                      ),
                  ],
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 4),
                    FilledButton.icon(
                      onPressed: onAction,
                      icon: Icon(actionIcon ?? Icons.copy_rounded, size: 19),
                      label: Text(actionLabel!),
                      style: FilledButton.styleFrom(
                        backgroundColor: _carmaBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryStickerInfoTile extends StatelessWidget {
  const _StoryStickerInfoTile({required this.row});

  final _StoryStickerInfoRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _carmaBlue.withValues(alpha: 0.2),
            ),
            child: Icon(row.icon, color: _carmaBlueLight, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  row.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatStorySeenAt(DateTime value) {
  final now = DateTime.now();
  final difference = now.difference(value);

  if (difference.isNegative || difference.inMinutes < 1) {
    return 'Gerade eben';
  }

  if (difference.inHours < 1) {
    return 'Vor ${difference.inMinutes} Min.';
  }

  if (difference.inDays < 1) {
    return 'Vor ${difference.inHours} Std.';
  }

  return 'Vor ${difference.inDays} T.';
}
