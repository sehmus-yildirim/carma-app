part of '../chats_screen.dart';

enum _ChatsView { chats, requests }

enum _ChatListView { messages, archived }

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

// ignore: unused_field
enum _LocalChatTestMode { empty, activeChat, activeChatWithMessages }

const _LocalChatTestMode _localChatTestMode = _LocalChatTestMode.empty;
const bool _showLocalContactRequestSamples = true;
const String _localContactRequestPrefix = 'local-contact-request-';
const int _maxStoryReplyPreviewLength = 280;

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
  final UserSettingsRepository _userSettingsRepository =
      UserSettingsRepository();
  final ImagePicker _imagePicker = ImagePicker();

  _ChatsView _selectedView = _ChatsView.chats;
  _ChatListView _selectedChatListView = _ChatListView.messages;
  _RequestListView _selectedRequestListView = _RequestListView.incoming;
  String _streamUserId = '';
  bool _isAddingOwnStory = false;
  bool _isArchiveShortcutVisible = false;
  StoryPrivacySettings _storyPrivacySettings = const StoryPrivacySettings();
  final Set<String> _busyRequestIds = <String>{};
  final Set<String> _busyChatSwipeActions = <String>{};
  final Set<String> _hiddenLocalRequestIds = <String>{};
  List<ChatStoryRecord> _cachedStories = const <ChatStoryRecord>[];
  String _currentUserProfilePhotoUrl = '';
  Timer? _storyRefreshTimer;

  late Stream<List<ChatRecord>> _chatStream;
  late Stream<List<ChatRecord>> _archivedChatStream;
  late Stream<List<ChatStoryRecord>> _storyStream;
  late Stream<List<ContactRequestRecord>> _incomingRequestStream;
  late Stream<List<ContactRequestRecord>> _incomingRequestStateStream;
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
    unawaited(_loadCurrentUserProfilePhotoUrl());
    unawaited(_loadStoryPrivacySettings());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanupExpiredOwnStory(showError: false);
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
    unawaited(_loadCurrentUserProfilePhotoUrl());
    unawaited(_loadStoryPrivacySettings());
  }

  @override
  void dispose() {
    _storyRefreshTimer?.cancel();
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

  Stream<List<ChatStoryRecord>> _watchStories() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ChatStoryRecord>>.value(const <ChatStoryRecord>[]);
    }

    return _storyRepository.watchVisibleStories(userId: userId);
  }

  Future<void> _loadStoryPrivacySettings() async {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return;
    }

    try {
      final settings = await _userSettingsRepository.load(userId);

      if (!mounted) {
        return;
      }

      setState(() {
        _storyPrivacySettings = settings.storyPrivacy;
      });
    } catch (_) {
      // Story privacy defaults keep the existing Story behavior.
    }
  }

  List<ChatStoryRecord> _visibleStoryRecords(
    List<ChatStoryRecord> stories, {
    Set<String>? allowedOwnerIds,
    String? currentUserId,
  }) {
    final trimmedCurrentUserId = currentUserId?.trim();

    return stories
        .where(
          (story) =>
              !story.isExpired &&
              story.hasRenderableMedia &&
              (trimmedCurrentUserId == null ||
                  trimmedCurrentUserId.isEmpty ||
                  _canCurrentUserViewStory(story, trimmedCurrentUserId)) &&
              (allowedOwnerIds == null ||
                  allowedOwnerIds.contains(story.ownerUserId.trim())),
        )
        .toList(growable: false);
  }

  Stream<List<ContactRequestRecord>> _watchIncomingRequests() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ContactRequestRecord>>.value(
        const <ContactRequestRecord>[],
      );
    }

    if (_showLocalContactRequestSamples) {
      return Stream<List<ContactRequestRecord>>.value(
        _visibleLocalContactRequestSamples(
          userId,
          (request) => request.receiverUserId == userId,
        ),
      );
    }

    return _requestRepository.watchIncomingRequests(userId: userId);
  }

  Stream<List<ContactRequestRecord>> _watchIncomingRequestStates() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ContactRequestRecord>>.value(
        const <ContactRequestRecord>[],
      );
    }

    if (_showLocalContactRequestSamples) {
      return Stream<List<ContactRequestRecord>>.value(
        _visibleLocalContactRequestSamples(
          userId,
          (request) => request.receiverUserId == userId,
        ),
      );
    }

    return _requestRepository.watchIncomingRequestStates(userId: userId);
  }

  Stream<List<ContactRequestRecord>> _watchOutgoingRequests() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ContactRequestRecord>>.value(
        const <ContactRequestRecord>[],
      );
    }

    if (_showLocalContactRequestSamples) {
      return Stream<List<ContactRequestRecord>>.value(
        _visibleLocalContactRequestSamples(
          userId,
          (request) => request.senderUserId == userId,
        ),
      );
    }

    return _requestRepository.watchOutgoingRequests(userId: userId);
  }

  List<ContactRequestRecord> _visibleLocalContactRequestSamples(
    String currentUserId,
    bool Function(ContactRequestRecord request) filter,
  ) {
    return _buildLocalContactRequestSamples(currentUserId)
        .where(
          (request) =>
              request.isVisibleInRequestLists &&
              !_hiddenLocalRequestIds.contains(request.id) &&
              filter(request),
        )
        .toList(growable: false);
  }

  List<ContactRequestRecord> _buildLocalContactRequestSamples(
    String currentUserId,
  ) {
    final now = DateTime.now();

    return <ContactRequestRecord>[
      ContactRequestRecord(
        id: '${_localContactRequestPrefix}incoming',
        senderUserId: 'local-test-sender',
        receiverUserId: currentUserId,
        countryCode: 'DE',
        plateKey: 'HH-TA-2040',
        displayPlate: 'HH-TA 2040',
        vehicleBrand: 'BMW',
        vehicleModel: 'X6',
        vehicleColor: 'Schwarz',
        vehicleLabel: 'BMW X6 in Schwarz',
        requestReason: 'compliment',
        senderDisplayName: 'plaqa Nutzer',
        receiverDisplayName: 'Du',
        message:
            'Hallo, dein BMW X6 ist mir positiv aufgefallen. Wirklich ein sehr schönes Auto.',
        status: contact_requests.ContactRequestStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 12)),
        updatedAt: now.subtract(const Duration(minutes: 12)),
        expiresAt: now.add(const Duration(hours: 48)),
      ),
      ContactRequestRecord(
        id: '${_localContactRequestPrefix}outgoing',
        senderUserId: currentUserId,
        receiverUserId: 'local-test-receiver',
        countryCode: 'DE',
        plateKey: 'B-CR-2026',
        displayPlate: 'B-CR 2026',
        vehicleBrand: 'Mercedes',
        vehicleModel: 'GLS',
        vehicleColor: 'Weiß',
        vehicleLabel: 'Mercedes GLS in Weiß',
        requestReason: 'vehicle_question',
        senderDisplayName: 'Du',
        receiverDisplayName: 'plaqa Testnutzer',
        message:
            'Hallo, ich habe eine Frage zu deinem Mercedes GLS und würde mich gerne kurz mit dir darüber austauschen.',
        status: contact_requests.ContactRequestStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 6)),
        updatedAt: now.subtract(const Duration(minutes: 6)),
        expiresAt: now.add(const Duration(hours: 48)),
      ),
    ];
  }

  bool _isLocalContactRequest(ContactRequestRecord request) {
    return request.id.startsWith(_localContactRequestPrefix);
  }

  void _completeLocalRequestAction(
    ContactRequestRecord request,
    String message,
  ) {
    setState(() {
      _hiddenLocalRequestIds.add(request.id);
    });
    _refreshChatsAndRequests();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        text: 'Danke dir für den Hinweis. Ich schaue sofort nach.',
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

  bool _handleChatScrollNotification(ScrollNotification notification) {
    if (_selectedView != _ChatsView.chats ||
        _selectedChatListView != _ChatListView.messages ||
        _isArchiveShortcutVisible) {
      return false;
    }

    final pulledBeyondTop =
        notification is ScrollUpdateNotification &&
        notification.metrics.pixels < -18;
    final overscrolledTop =
        notification is OverscrollNotification && notification.overscroll < -8;

    if (pulledBeyondTop || overscrolledTop) {
      setState(() => _isArchiveShortcutVisible = true);
    }

    return false;
  }

  void _openArchivedChats() {
    setState(() {
      _selectedChatListView = _ChatListView.archived;
      _isArchiveShortcutVisible = false;
    });
  }

  void _showMessageChats() {
    setState(() {
      _selectedChatListView = _ChatListView.messages;
      _isArchiveShortcutVisible = false;
    });
  }

  void _hideArchiveShortcut() {
    if (!_isArchiveShortcutVisible) return;
    setState(() => _isArchiveShortcutVisible = false);
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

  Future<void> _runChatSwipeAction({
    required ChatRecord chat,
    required String actionName,
    required String successMessage,
    required Future<void> Function(String userId) action,
  }) async {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte melde dich erneut an.')),
      );
      return;
    }

    final actionKey = '${chat.id}::$userId::$actionName';
    if (!_busyChatSwipeActions.add(actionKey)) return;

    try {
      await action(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyChatUiError(
              error,
              fallback: 'Die Chat-Aktion konnte nicht ausgeführt werden.',
            ),
          ),
        ),
      );
    } finally {
      _busyChatSwipeActions.remove(actionKey);
    }
  }

  Future<void> _toggleChatReadFromSwipe(ChatRecord chat) async {
    final userId = _effectiveUserId.trim();
    final markAsRead = chat.hasUnreadFor(userId);

    await _runChatSwipeAction(
      chat: chat,
      actionName: 'read',
      successMessage: markAsRead
          ? 'Chat wurde als gelesen markiert.'
          : 'Chat wurde als ungelesen markiert.',
      action: (resolvedUserId) async {
        if (markAsRead) {
          await _chatRepository.markChatRead(
            chatId: chat.id,
            userId: resolvedUserId,
          );
        } else {
          await _chatRepository.markChatUnread(
            chatId: chat.id,
            userId: resolvedUserId,
          );
        }
      },
    );
  }

  Future<void> _toggleChatPinnedFromSwipe(ChatRecord chat) async {
    final userId = _effectiveUserId.trim();
    final nextIsPinned = !chat.isPinnedFor(userId);

    await _runChatSwipeAction(
      chat: chat,
      actionName: 'pin',
      successMessage: nextIsPinned
          ? 'Chat wurde angepinnt.'
          : 'Chat wurde gelöst.',
      action: (resolvedUserId) => _chatRepository.setChatPinned(
        chatId: chat.id,
        userId: resolvedUserId,
        isPinned: nextIsPinned,
      ),
    );
  }

  Future<void> _toggleChatArchivedFromSwipe(ChatRecord chat) async {
    final userId = _effectiveUserId.trim();
    final restoreChat = chat.isVisibleInArchivedListFor(userId);

    await _runChatSwipeAction(
      chat: chat,
      actionName: 'archive',
      successMessage: restoreChat
          ? 'Chat wurde aus dem Archiv geholt.'
          : 'Chat wurde archiviert.',
      action: (resolvedUserId) async {
        if (restoreChat) {
          await _chatRepository.unarchiveChat(
            chatId: chat.id,
            userId: resolvedUserId,
          );
        } else {
          await _chatRepository.archiveChat(
            chatId: chat.id,
            userId: resolvedUserId,
          );
        }
      },
    );
  }

  Future<void> _showChatVehicleDetailsFromSwipe(ChatRecord chat) {
    final currentUserId = _effectiveUserId.trim();

    return _ChatOverflowMenu(
      title: chat.displayNameFor(currentUserId),
      subtitle:
          '${chat.vehicleModelLabel} - ${_formatChatPlateLabel(chat.displayPlate)}',
      vehicleLabel: chat.vehicleModelLabel,
      plateLabel: _formatChatPlateLabel(chat.displayPlate),
      popAfterStatusAction: false,
    )._showVehicleDetails(context);
  }

  void _assignStreamsForCurrentUser({required bool clearStories}) {
    if (clearStories) {
      _cachedStories = const <ChatStoryRecord>[];
    }

    _chatStream = _watchChats();
    _archivedChatStream = _watchArchivedChats();
    _storyStream = _watchStories();
    _incomingRequestStream = _reusableRequestStream(_watchIncomingRequests());
    _incomingRequestStateStream = _reusableRequestStream(
      _watchIncomingRequestStates(),
    );
    _outgoingRequestStream = _reusableRequestStream(_watchOutgoingRequests());
  }

  Stream<List<ContactRequestRecord>> _reusableRequestStream(
    Stream<List<ContactRequestRecord>> stream,
  ) {
    return stream.isBroadcast ? stream : stream.asBroadcastStream();
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

  Future<void> _loadCurrentUserProfilePhotoUrl() async {
    final userId = _effectiveUserId.trim();
    final authPhotoUrl =
        FirebaseAuth.instance.currentUser?.photoURL?.trim() ?? '';
    var nextPhotoUrl = authPhotoUrl;

    if (userId.isNotEmpty) {
      try {
        final profile = await _profileRepository.getProfile(userId);
        final profilePhotoUrl = profile?.photoUrl?.trim() ?? '';

        if (profilePhotoUrl.isNotEmpty) {
          nextPhotoUrl = profilePhotoUrl;
        }
      } catch (_) {
        // The auth photo remains a safe fallback if the profile cannot be read.
      }
    }

    if (!mounted || _currentUserProfilePhotoUrl == nextPhotoUrl) {
      return;
    }

    setState(() {
      _currentUserProfilePhotoUrl = nextPhotoUrl;
    });
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
          profileUserId: chat.otherParticipantIdFor(currentUserId),
          isOnline: false,
        ),
      ),
    );

    if (!context.mounted) {
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

    if (!context.mounted) {
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
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final currentUserId = firebaseUser?.uid.trim() ?? '';

    if (currentUserId.isEmpty || _isAddingOwnStory) {
      if (currentUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte melde dich neu an, um Storys zu teilen.'),
          ),
        );
      }

      return;
    }

    final viewerUserIds = _storyViewerUserIdsFor(
      chats: chats,
      currentUserId: currentUserId,
    );

    setState(() {
      _isAddingOwnStory = true;
    });

    ChatImageUploadResult? uploadedStoryMedia;

    try {
      await _cleanupExpiredOwnStory(showError: false);

      if (!mounted) {
        return;
      }

      final captureResult = await Navigator.of(context)
          .push<_StoryCaptureResult>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => _StoryCaptureScreen(
                imagePicker: _imagePicker,
                useInAppGallery: true,
              ),
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
      final initialVehicleSticker =
          _storyPrivacySettings.defaultStoryVehicleData
          ? _defaultVehicleStorySticker(vehicleStickerData)
          : null;

      if (!mounted) {
        return;
      }

      final draft = await Navigator.of(context).push<_StoryDraft>(
        MaterialPageRoute(
          builder: (_) => _StoryDraftEditorScreen(
            mediaPath: captureResult.path,
            isVideo: captureResult.isVideo,
            vehicleStickerData: vehicleStickerData,
            initialStickers: [?initialVehicleSticker],
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
      uploadedStoryMedia = upload;
      final profilePhotoUrl = _currentUserProfilePhotoUrl.trim().isNotEmpty
          ? _currentUserProfilePhotoUrl.trim()
          : firebaseUser?.photoURL?.trim();
      final displayName = firebaseUser?.displayName?.trim().isNotEmpty == true
          ? firebaseUser!.displayName!.trim()
          : 'plaqa Nutzer';

      await _storyRepository.setOwnImageStory(
        storyId: storyId,
        ownerUserId: currentUserId,
        ownerDisplayName: displayName,
        ownerPhotoUrl: profilePhotoUrl,
        viewerUserIds: viewerUserIds,
        repliesEnabled: _storyPrivacySettings.storyRepliesEnabled,
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
        textAlign: draft.textAlign,
        textAlignmentX: (draft.textAlignment.x + 1) / 2,
        textAlignmentY: (draft.textAlignment.y + 1) / 2,
        filterType: draft.filterType,
        stickers: <ChatStoryStickerRecord>[
          for (final sticker in draft.stickers)
            ChatStoryStickerRecord(
              type: sticker.type,
              label: sticker.label,
              payload: sticker.payload,
              alignmentX: (sticker.alignment.x + 1) / 2,
              alignmentY: (sticker.alignment.y + 1) / 2,
            ),
        ],
      );

      try {
        final downloadUrl = await _attachmentStorage.getDownloadUrl(
          path: upload.path,
        );
        await _storyRepository.updateOwnStoryMediaUrl(
          storyId: storyId,
          ownerUserId: currentUserId,
          mediaType: draft.isVideo ? 'video' : 'image',
          url: downloadUrl,
        );
      } catch (_) {
        // The story document is already saved; a transient URL refresh must not
        // turn a successful upload into a failed publish.
      }

      uploadedStoryMedia = null;

      final savedStory = await _storyRepository.getStoryById(storyId);

      if (mounted) {
        setState(() {
          _storyStream = _watchStories();
          if (savedStory != null) {
            _cachedStories = <ChatStoryRecord>[
              savedStory,
              ..._cachedStories.where((story) => story.id != savedStory.id),
            ];
          }
        });
      } else {
        _storyStream = _watchStories();
        if (savedStory != null) {
          _cachedStories = <ChatStoryRecord>[
            savedStory,
            ..._cachedStories.where((story) => story.id != savedStory.id),
          ];
        }
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Story wurde hinzugefügt.')));
    } catch (error) {
      final cleanupError = await _cleanupFailedStoryUpload(uploadedStoryMedia);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _storySaveErrorMessage(error, cleanupError: cleanupError),
          ),
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

  Future<Object?> _cleanupFailedStoryUpload(
    ChatImageUploadResult? upload,
  ) async {
    final path = upload?.path.trim() ?? '';

    if (path.isEmpty) {
      return null;
    }

    try {
      await _attachmentStorage.deleteUploadedStoryMedia(path: path);
      return null;
    } catch (error) {
      return error;
    }
  }

  String _storySaveErrorMessage(Object error, {Object? cleanupError}) {
    final message = error is ChatAttachmentStorageException
        ? error.message
        : 'Story konnte nicht gespeichert werden: $error';

    if (cleanupError == null) {
      return message;
    }

    return '$message Hochgeladene Story-Datei konnte nicht bereinigt werden: $cleanupError';
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
    final isOwnStory = story.ownerUserId.trim() == currentUserId;

    if (currentUserId.isEmpty ||
        isOwnStory ||
        !_canCurrentUserViewStory(story, currentUserId)) {
      return;
    }

    try {
      final photoUrl = currentUser?.photoURL?.trim() ?? '';
      final profilePhotoUrl = _currentUserProfilePhotoUrl.trim();
      final effectivePhotoUrl = profilePhotoUrl.isNotEmpty
          ? profilePhotoUrl
          : photoUrl;

      if (story.viewedAtBy.containsKey(currentUserId)) {
        final storedPhotoUrl =
            story.viewerPhotoUrlBy[currentUserId]?.trim() ?? '';

        if (effectivePhotoUrl.isNotEmpty && storedPhotoUrl.isEmpty) {
          await _storyRepository.updateStoryViewerPhotoUrl(
            storyId: story.id,
            userId: currentUserId,
            photoUrl: effectivePhotoUrl,
          );
        }

        return;
      }

      final displayName = currentUser?.displayName?.trim().isNotEmpty == true
          ? currentUser!.displayName!.trim()
          : 'plaqa Nutzer';

      await _storyRepository.markStoryViewed(
        storyId: story.id,
        userId: currentUserId,
        displayName: displayName,
        photoUrl: effectivePhotoUrl,
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

    final storyPrivacy = _storyPrivacySettings;
    final excludedUserIds = storyPrivacy.excludedStoryUserIds
        .map((userId) => userId.trim())
        .where((userId) => userId.isNotEmpty)
        .toSet();
    final viewerUserIds = <String>{trimmedCurrentUserId};

    if (storyPrivacy.storyVisibility == 'onlyMe') {
      return <String>[trimmedCurrentUserId];
    }

    if (_localChatTestMode != _LocalChatTestMode.empty &&
        !excludedUserIds.contains('mock-user-id')) {
      viewerUserIds.add('mock-user-id');
    }

    for (final chat in chats) {
      if (!_canUseChatForStoryViewers(chat, trimmedCurrentUserId)) {
        continue;
      }

      for (final participant in chat.participants) {
        final trimmedParticipant = participant.trim();

        if (trimmedParticipant.isEmpty ||
            excludedUserIds.contains(trimmedParticipant) ||
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

  _StoryStickerDraft? _defaultVehicleStorySticker(
    _StoryVehicleStickerData? vehicleStickerData,
  ) {
    if (vehicleStickerData == null || !vehicleStickerData.isComplete) {
      return null;
    }

    final vehicleLabel = vehicleStickerData.vehicleLabel.trim().isEmpty
        ? 'Fahrzeug'
        : vehicleStickerData.vehicleLabel.trim();
    final plateLabel = vehicleStickerData.plateLabel.trim();

    return _StoryStickerDraft(
      type: 'vehicle',
      label: vehicleLabel,
      payload: _vehicleStickerPayload(style: 'card', plateLabel: plateLabel),
      alignment: const Alignment(0, 0.52),
    );
  }

  Set<String> _storyVisibleOwnerIdsFor({
    required List<ChatRecord> chats,
    required String currentUserId,
  }) {
    final trimmedCurrentUserId = currentUserId.trim();

    if (trimmedCurrentUserId.isEmpty) {
      return const <String>{};
    }

    final ownerIds = <String>{trimmedCurrentUserId};
    if (_localChatTestMode != _LocalChatTestMode.empty) {
      ownerIds.add('mock-user-id');
    }

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

        ownerIds.add(trimmedParticipant);
      }
    }

    return ownerIds;
  }

  bool _canUseChatForStoryViewers(ChatRecord chat, String currentUserId) {
    final trimmedCurrentUserId = currentUserId.trim();
    final participantIds = chat.participants
        .map((participant) => participant.trim())
        .where((participant) => participant.isNotEmpty)
        .toSet();

    return (chat.status == ChatStatus.active ||
            chat.status == ChatStatus.archived) &&
        participantIds.length == 2 &&
        participantIds.contains(trimmedCurrentUserId) &&
        !chat.isDeletedFor(trimmedCurrentUserId);
  }

  bool _canCurrentUserViewStory(ChatStoryRecord story, String currentUserId) {
    final trimmedCurrentUserId = currentUserId.trim();

    if (trimmedCurrentUserId.isEmpty) {
      return false;
    }

    return story.ownerUserId.trim() == trimmedCurrentUserId ||
        story.viewerUserIds.any(
          (userId) => userId.trim() == trimmedCurrentUserId,
        );
  }

  Future<void> _openStory(
    ChatStoryRecord story,
    List<ChatStoryRecord> stories,
  ) async {
    final currentUserId = _effectiveUserId.trim();

    if (story.isExpired ||
        !story.hasRenderableMedia ||
        !_canCurrentUserViewStory(story, currentUserId)) {
      setState(() {
        _storyStream = _watchStories();
      });

      if (story.isExpired) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diese Story ist abgelaufen.')),
        );
      }
      return;
    }

    final visibleStories =
        (stories.isEmpty ? <ChatStoryRecord>[story] : stories)
            .where(
              (visibleStory) =>
                  !visibleStory.isExpired &&
                  visibleStory.hasRenderableMedia &&
                  _canCurrentUserViewStory(visibleStory, currentUserId),
            )
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
        onDeleteStory: (visibleStory) =>
            _confirmDeleteOwnStory(context, visibleStory),
        onOpenSticker: _openStorySticker,
        onReplyStory: _sendStoryReply,
        onVoteStoryPoll: _voteStoryPoll,
      ),
    );

    if (!mounted) {
      return;
    }

    _refreshChatsAndRequests();
  }

  Future<bool> _voteStoryPoll(ChatStoryRecord story, int optionIndex) async {
    final currentUserId = _effectiveUserId.trim();

    if (currentUserId.isEmpty ||
        story.ownerUserId == currentUserId ||
        story.isExpired ||
        !story.hasRenderableMedia ||
        !_canCurrentUserViewStory(story, currentUserId)) {
      return false;
    }

    return _storyRepository.voteStoryPoll(
      storyId: story.id,
      userId: currentUserId,
      optionIndex: optionIndex,
    );
  }

  Future<void> _sendStoryReply(ChatStoryRecord story, String text) async {
    final currentUserId = _effectiveUserId.trim();
    final trimmedText = text.trim();

    if (currentUserId.isEmpty || trimmedText.isEmpty) {
      return;
    }

    final currentStory = await _storyRepository
        .getStoryById(story.id)
        .catchError((_) => null);

    if (currentStory == null || currentStory.isExpired) {
      throw StateError('expired_story');
    }

    if (!currentStory.hasRenderableMedia ||
        !_canCurrentUserViewStory(currentStory, currentUserId)) {
      throw StateError('story_not_visible');
    }

    if (!currentStory.repliesEnabled) {
      throw StateError('story_replies_disabled');
    }

    if (trimmedText.length > FirestoreDocumentDefaults.maxChatMessageLength) {
      throw StateError('story_reply_too_long');
    }

    final storyOwnerId = currentStory.ownerUserId.trim();

    if (storyOwnerId.isEmpty || currentUserId == storyOwnerId) {
      return;
    }

    final chats = <ChatRecord>[
      ...await _chatRepository.loadChats(userId: currentUserId),
      ...await _chatRepository.watchArchivedChats(userId: currentUserId).first,
    ];
    ChatRecord? storyChat;

    for (final chat in chats) {
      final participantIds = chat.participants
          .map((participant) => participant.trim())
          .where((participant) => participant.isNotEmpty)
          .toSet();

      if (participantIds.contains(storyOwnerId) &&
          !chat.isDeletedFor(storyOwnerId) &&
          _canUseChatForStoryViewers(chat, currentUserId)) {
        storyChat = chat;
        break;
      }
    }

    if (storyChat == null) {
      throw StateError('No visible chat for story reply.');
    }

    if (storyChat.isVisibleInArchivedListFor(currentUserId)) {
      await _chatRepository.unarchiveChat(
        chatId: storyChat.id,
        userId: currentUserId,
      );
    }

    await _chatRepository.sendTextMessage(
      chatId: storyChat.id,
      senderUserId: currentUserId,
      text: trimmedText,
      replyToText: _storyReplyPreview(currentStory),
    );

    if (mounted) {
      _refreshChatsAndRequests();
    }
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
        ? 'plaqa Nutzer'
        : story.ownerDisplayName.trim();

    final preview = 'Story von $ownerName: $label';

    if (preview.length <= _maxStoryReplyPreviewLength) {
      return preview;
    }

    return '${preview.substring(0, _maxStoryReplyPreviewLength - 1)}...';
  }

  Future<void> _showStoryViewers(
    BuildContext context,
    ChatStoryRecord story,
  ) async {
    final currentUserId = _effectiveUserId.trim();
    final currentStory =
        await _storyRepository.getStoryById(story.id).catchError((_) => null) ??
        story;

    if (currentUserId.isEmpty ||
        currentStory.ownerUserId.trim() != currentUserId) {
      return;
    }

    final viewers =
        currentStory.viewedAtBy.entries
            .where((entry) => entry.key != currentStory.ownerUserId)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final pollOptions = _storyPollOptions(currentStory);

    if (!context.mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CaRismaDesignTokens.card,
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
                      color: CaRismaDesignTokens.card,
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
                            color: CaRismaDesignTokens.controlSurface,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
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
                            color: CaRismaDesignTokens.controlSurface,
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
                        color: CaRismaDesignTokens.controlSurface,
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
                              currentStory.viewerNameBy[viewer.key]?.trim() ??
                              '';
                          final label = viewerName.isEmpty
                              ? 'plaqa Nutzer'
                              : viewerName;
                          final photoUrl = currentStory
                              .viewerPhotoUrlBy[viewer.key]
                              ?.trim();
                          final pollVote = currentStory.pollVoteBy[viewer.key];
                          final pollVoteLabel =
                              pollVote != null &&
                                  pollVote >= 0 &&
                                  pollVote < pollOptions.length
                              ? pollOptions[pollVote]
                              : '';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: CaRismaDesignTokens.controlSurface,
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
                                      if (pollVoteLabel.isNotEmpty) ...[
                                        const SizedBox(height: 7),
                                        _StoryViewerPollVoteChip(
                                          label: pollVoteLabel,
                                        ),
                                      ],
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

  Future<void> _confirmDeleteOwnStory(
    BuildContext dialogContext,
    ChatStoryRecord story,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: dialogContext,
      builder: (context) {
        return const _StoryDeleteDialog();
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
      await _storyRepository.deleteOwnStory(
        storyId: story.id,
        ownerUserId: currentUserId,
      );
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

        await _showStoryLocationStickerSheet(
          story,
          latitude: latitude,
          longitude: longitude,
        );
        return;
      }

      if (type == 'link') {
        await _showStoryLinkStickerSheet(story);
        return;
      }

      if (type == 'hashtag') {
        await _showStoryHashtagStickerSheet(story);
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

  Future<void> _showStoryLocationStickerSheet(
    ChatStoryRecord story, {
    required double latitude,
    required double longitude,
  }) async {
    final stickerLabel = story.stickerLabel.trim();
    final title = stickerLabel.isEmpty ? 'Standort' : stickerLabel;
    final coordinateLabel =
        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    final canReply =
        story.repliesEnabled && story.ownerUserId != _effectiveUserId.trim();

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _StoryStickerInfoSheet(
          icon: Icons.location_on_rounded,
          title: title,
          subtitle: 'Ort von ${story.ownerDisplayName}',
          rows: [
            _StoryStickerInfoRow(
              label: 'Ort',
              value: title,
              icon: Icons.place_rounded,
            ),
            _StoryStickerInfoRow(
              label: 'Koordinaten',
              value: coordinateLabel,
              icon: Icons.my_location_rounded,
            ),
          ],
          actionIcon: Icons.map_rounded,
          actionLabel: 'In Karten öffnen',
          onAction: () async {
            final navigator = Navigator.of(sheetContext);
            final messenger = ScaffoldMessenger.of(context);

            try {
              await ChatNativeBridge().openMap(
                latitude: latitude,
                longitude: longitude,
              );

              if (!mounted) {
                return;
              }

              navigator.pop();
            } catch (error) {
              if (!mounted) {
                return;
              }

              messenger.showSnackBar(
                SnackBar(
                  content: Text('Karten konnten nicht geöffnet werden: $error'),
                ),
              );
            }
          },
          secondaryActionIcon: Icons.copy_rounded,
          secondaryActionLabel: 'Koordinaten kopieren',
          onSecondaryAction: () async {
            final navigator = Navigator.of(sheetContext);
            final messenger = ScaffoldMessenger.of(context);

            await Clipboard.setData(ClipboardData(text: coordinateLabel));

            if (!mounted) {
              return;
            }

            navigator.pop();
            messenger.showSnackBar(
              const SnackBar(content: Text('Koordinaten wurden kopiert.')),
            );
          },
          tertiaryActionIcon: canReply ? Icons.reply_rounded : null,
          tertiaryActionLabel: canReply ? 'Antworten' : null,
          onTertiaryAction: canReply
              ? () => _replyToStoryStickerFromSheet(
                  sheetContext: sheetContext,
                  story: story,
                  text: title,
                )
              : null,
        );
      },
    );
  }

  Future<void> _showStoryLinkStickerSheet(ChatStoryRecord story) async {
    final rawLink = story.stickerPayload.trim();
    final normalizedLink = _normalizeStoryLink(rawLink);
    final stickerLabel = story.stickerLabel.trim();
    final title = stickerLabel.isEmpty ? 'Link' : stickerLabel;
    final canReply =
        story.repliesEnabled && story.ownerUserId != _effectiveUserId.trim();

    if (!mounted || rawLink.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _StoryStickerInfoSheet(
          icon: Icons.link_rounded,
          title: title,
          subtitle: 'Link von ${story.ownerDisplayName}',
          rows: [
            _StoryStickerInfoRow(
              label: 'Adresse',
              value: normalizedLink,
              icon: Icons.language_rounded,
            ),
          ],
          actionIcon: Icons.open_in_new_rounded,
          actionLabel: 'Link öffnen',
          onAction: () async {
            final navigator = Navigator.of(sheetContext);
            final messenger = ScaffoldMessenger.of(context);

            try {
              await ChatNativeBridge().openDocumentUrl(
                url: normalizedLink,
                contentType: 'text/html',
              );

              if (!mounted) {
                return;
              }

              navigator.pop();
            } catch (error) {
              if (!mounted) {
                return;
              }

              messenger.showSnackBar(
                SnackBar(
                  content: Text('Link konnte nicht geöffnet werden: $error'),
                ),
              );
            }
          },
          secondaryActionIcon: Icons.copy_rounded,
          secondaryActionLabel: 'Link kopieren',
          onSecondaryAction: () async {
            final navigator = Navigator.of(sheetContext);
            final messenger = ScaffoldMessenger.of(context);

            await Clipboard.setData(ClipboardData(text: normalizedLink));

            if (!mounted) {
              return;
            }

            navigator.pop();
            messenger.showSnackBar(
              const SnackBar(content: Text('Link wurde kopiert.')),
            );
          },
          tertiaryActionIcon: canReply ? Icons.reply_rounded : null,
          tertiaryActionLabel: canReply ? 'Antworten' : null,
          onTertiaryAction: canReply
              ? () => _replyToStoryStickerFromSheet(
                  sheetContext: sheetContext,
                  story: story,
                  text: normalizedLink,
                )
              : null,
        );
      },
    );
  }

  Future<void> _showStoryHashtagStickerSheet(ChatStoryRecord story) async {
    final payload = story.stickerPayload.trim();
    final hashtag = payload.startsWith('#') ? payload : '#$payload';
    final canReply =
        story.repliesEnabled && story.ownerUserId != _effectiveUserId.trim();

    if (!mounted || payload.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _StoryStickerInfoSheet(
          icon: Icons.tag_rounded,
          title: hashtag,
          subtitle: 'Hashtag von ${story.ownerDisplayName}',
          rows: [
            _StoryStickerInfoRow(
              label: 'Hashtag',
              value: hashtag,
              icon: Icons.tag_rounded,
            ),
          ],
          actionIcon: Icons.copy_rounded,
          actionLabel: 'Hashtag kopieren',
          onAction: () async {
            final navigator = Navigator.of(sheetContext);
            final messenger = ScaffoldMessenger.of(context);

            await Clipboard.setData(ClipboardData(text: hashtag));

            if (!mounted) {
              return;
            }

            navigator.pop();
            messenger.showSnackBar(
              const SnackBar(content: Text('Hashtag wurde kopiert.')),
            );
          },
          secondaryActionIcon: canReply ? Icons.reply_rounded : null,
          secondaryActionLabel: canReply ? 'Antworten' : null,
          onSecondaryAction: canReply
              ? () => _replyToStoryStickerFromSheet(
                  sheetContext: sheetContext,
                  story: story,
                  text: hashtag,
                )
              : null,
        );
      },
    );
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
    final vehicleReplyText = [
      if (vehicleLabel.isNotEmpty && vehicleLabel != 'Fahrzeug') vehicleLabel,
      if (plateLabel.isNotEmpty) plateLabel,
    ].join(' - ');
    final canReply =
        story.repliesEnabled &&
        story.ownerUserId != _effectiveUserId.trim() &&
        vehicleReplyText.isNotEmpty;

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
          secondaryActionIcon: canReply ? Icons.reply_rounded : null,
          secondaryActionLabel: canReply ? 'Antworten' : null,
          onSecondaryAction: canReply
              ? () => _replyToStoryStickerFromSheet(
                  sheetContext: sheetContext,
                  story: story,
                  text: vehicleReplyText,
                )
              : null,
        );
      },
    );
  }

  Future<void> _showStoryStatusStickerSheet(ChatStoryRecord story) async {
    final statusLabel = story.stickerLabel.trim().isEmpty
        ? story.stickerPayload.trim()
        : story.stickerLabel.trim();
    final canReply =
        story.repliesEnabled && story.ownerUserId != _effectiveUserId.trim();

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
          secondaryActionIcon: canReply ? Icons.reply_rounded : null,
          secondaryActionLabel: canReply ? 'Antworten' : null,
          onSecondaryAction: canReply
              ? () => _replyToStoryStickerFromSheet(
                  sheetContext: sheetContext,
                  story: story,
                  text: statusLabel,
                )
              : null,
        );
      },
    );
  }

  Future<void> _replyToStoryStickerFromSheet({
    required BuildContext sheetContext,
    required ChatStoryRecord story,
    required String text,
  }) async {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      return;
    }

    final navigator = Navigator.of(sheetContext);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _sendStoryReply(story, trimmedText);

      if (!mounted) {
        return;
      }

      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Antwort gesendet.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text(_storyReplyErrorMessage(error))),
      );
    }
  }

  Future<void> _runRequestAction({
    required ContactRequestRecord request,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (_isLocalContactRequest(request)) {
      _completeLocalRequestAction(request, successMessage);
      return;
    }

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyChatUiError(
              error,
              fallback: 'Die Anfrage konnte nicht bearbeitet werden.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestIds.remove(request.id);
        });
      }
    }
  }

  Future<void> _acceptRequest(ContactRequestRecord request) async {
    if (_isLocalContactRequest(request)) {
      _completeLocalRequestAction(
        request,
        'Lokale Testanfrage wurde angenommen.',
      );
      return;
    }

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
        SnackBar(
          content: Text(
            result.profileConnectionSynced
                ? 'Kontaktanfrage wurde angenommen.'
                : 'Kontaktanfrage wurde angenommen. Die Profilverknüpfung wird später synchronisiert.',
          ),
        ),
      );
      _refreshChatsAndRequests();
      try {
        await _openAcceptedChat(result.chat.id);
      } catch (error) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Anfrage angenommen, aber der Chat konnte nicht geöffnet werden: '
              '${_friendlyChatUiError(error)}',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_acceptRequestErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestIds.remove(request.id);
        });
      }
    }
  }

  String _acceptRequestErrorMessage(Object error) {
    return _friendlyChatUiError(
      error,
      fallback: 'Die Kontaktanfrage konnte nicht angenommen werden.',
    );
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

    return CaRismaBackground(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            CaRismaDesignTokens.mainScreenTopInset,
            20,
            keyboardInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!chatGateDecision.isAllowed)
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: _ChatAccessBlockedCard(
                      message:
                          chatGateDecision.reason ??
                          'Chats sind aktuell nicht verfügbar.',
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: StreamBuilder<List<ChatRecord>>(
                    stream: _chatStream,
                    builder: (context, chatsSnapshot) {
                      final chats = chatsSnapshot.data ?? const <ChatRecord>[];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ChatsSegmentedControl(
                            selectedView: _selectedView,
                            onChanged: _selectView,
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: _handleChatScrollNotification,
                              child: _buildChatsOrRequestsView(chats),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatsOrRequestsView(List<ChatRecord> chats) {
    if (_selectedView == _ChatsView.chats) {
      return StreamBuilder<List<ContactRequestRecord>>(
        stream: _incomingRequestStateStream,
        builder: (context, requestStateSnapshot) {
          final acceptedIncomingRequestIds =
              (requestStateSnapshot.data ?? const <ContactRequestRecord>[])
                  .where((request) => request.isAccepted)
                  .map((request) => request.id.trim())
                  .where((requestId) => requestId.isNotEmpty)
                  .toSet();
          final visibleChats = chats
              .where(
                (chat) => isChatVisibleForRequestState(
                  chat: chat,
                  currentUserId: _effectiveUserId,
                  acceptedIncomingRequestIds: acceptedIncomingRequestIds,
                ),
              )
              .toList(growable: false);

          return _buildChatsOverview(visibleChats, acceptedIncomingRequestIds);
        },
      );
    } else {
      return _RequestsOverview(
        key: const ValueKey('requests_view'),
        incomingStream: _incomingRequestStream,
        outgoingStream: _outgoingRequestStream,
        busyRequestIds: _busyRequestIds,
        selectedListView: _selectedRequestListView,
        onListViewChanged: _selectRequestListView,
        onHorizontalSwipe: _handleRequestListSwipe,
        onAccept: _acceptRequest,
        onDecline: _declineRequest,
        onWithdraw: _withdrawRequest,
      );
    }
  }

  Widget _buildChatsOverview(
    List<ChatRecord> chats,
    Set<String> acceptedIncomingRequestIds,
  ) {
    return StreamBuilder<List<ChatRecord>>(
      stream: _archivedChatStream,
      builder: (context, archivedSnapshot) {
        final archivedChats = (archivedSnapshot.data ?? const <ChatRecord>[])
            .where(
              (chat) => isChatVisibleForRequestState(
                chat: chat,
                currentUserId: _effectiveUserId,
                acceptedIncomingRequestIds: acceptedIncomingRequestIds,
              ),
            )
            .toList(growable: false);
        final isArchivedLoading =
            archivedSnapshot.connectionState == ConnectionState.waiting;

        return StreamBuilder<List<ChatStoryRecord>>(
          stream: _storyStream,
          initialData: _cachedStories,
          builder: (context, storySnapshot) {
            final storyData = storySnapshot.data;
            if (storyData != null && !storySnapshot.hasError) {
              _cachedStories = storyData;
            }

            final storyVisibleOwnerIds = _storyVisibleOwnerIdsFor(
              chats: [...chats, ...archivedChats],
              currentUserId: _effectiveUserId,
            );
            final stories = _visibleStoryRecords(
              storyData ?? _cachedStories,
              allowedOwnerIds: storyVisibleOwnerIds,
              currentUserId: _effectiveUserId,
            );

            return _ChatsOverview(
              chats: chats,
              archivedChats: archivedChats,
              stories: stories,
              currentUserPhotoUrl: _currentUserProfilePhotoUrl,
              isAddingOwnStory: _isAddingOwnStory,
              isLoading: isArchivedLoading,
              hasLocalActiveChat: _hasActiveChat,
              localMessages: _chatMessages,
              selectedListView: _selectedChatListView,
              showArchiveShortcut: _isArchiveShortcutVisible,
              onOpenArchived: _openArchivedChats,
              onShowMessages: _showMessageChats,
              onHideArchiveShortcut: _hideArchiveShortcut,
              onOpenChat: _openChat,
              onToggleChatRead: _toggleChatReadFromSwipe,
              onToggleChatPinned: _toggleChatPinnedFromSwipe,
              onToggleChatArchived: _toggleChatArchivedFromSwipe,
              onShowChatVehicleDetails: _showChatVehicleDetailsFromSwipe,
              onOpenLocalChat: _openLocalChat,
              onAddOwnStory: _addOwnStory,
              onOpenStory: _openStory,
            );
          },
        );
      },
    );
  }
}

class _StoryDeleteDialog extends StatelessWidget {
  const _StoryDeleteDialog();

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
              color: CaRismaDesignTokens.card,
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
                        color: CaRismaDesignTokens.controlSurface,
                        border: Border.all(
                          color: CaRismaDesignTokens.bluePrimary.withValues(
                            alpha: 0.42,
                          ),
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: CaRismaDesignTokens.bluePrimary,
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
                        style:
                            OutlinedButton.styleFrom(
                              backgroundColor:
                                  CaRismaDesignTokens.controlSurface,
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ).copyWith(
                              overlayColor: const WidgetStatePropertyAll(
                                Colors.transparent,
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
                        style:
                            FilledButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ).copyWith(
                              overlayColor: const WidgetStatePropertyAll(
                                Colors.transparent,
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
    this.secondaryActionIcon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.tertiaryActionIcon,
    this.tertiaryActionLabel,
    this.onTertiaryAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<_StoryStickerInfoRow> rows;
  final IconData? actionIcon;
  final String? actionLabel;
  final Future<void> Function()? onAction;
  final IconData? secondaryActionIcon;
  final String? secondaryActionLabel;
  final Future<void> Function()? onSecondaryAction;
  final IconData? tertiaryActionIcon;
  final String? tertiaryActionLabel;
  final Future<void> Function()? onTertiaryAction;

  @override
  Widget build(BuildContext context) {
    final safeRows = rows
        .where((row) => row.value.trim().isNotEmpty)
        .toList(growable: false);
    final hasPrimaryAction = actionLabel != null && onAction != null;
    final hasSecondaryAction =
        secondaryActionLabel != null && onSecondaryAction != null;
    final hasTertiaryAction =
        tertiaryActionLabel != null && onTertiaryAction != null;

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
                color: CaRismaDesignTokens.card,
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: [
                  BoxShadow(
                    color: _carismaBlue.withValues(alpha: 0.2),
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
                          color: CaRismaDesignTokens.controlSurface,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
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
                  if (hasPrimaryAction ||
                      hasSecondaryAction ||
                      hasTertiaryAction) ...[
                    const SizedBox(height: 4),
                    Column(
                      children: [
                        if (hasPrimaryAction || hasSecondaryAction)
                          Row(
                            children: [
                              if (hasPrimaryAction)
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: onAction,
                                    icon: Icon(
                                      actionIcon ?? Icons.copy_rounded,
                                      size: 19,
                                    ),
                                    label: Text(
                                      actionLabel!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    style:
                                        FilledButton.styleFrom(
                                          backgroundColor: _carismaBlue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 13,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ).copyWith(
                                          overlayColor:
                                              const WidgetStatePropertyAll(
                                                Colors.transparent,
                                              ),
                                        ),
                                  ),
                                ),
                              if (hasPrimaryAction && hasSecondaryAction)
                                const SizedBox(width: 10),
                              if (hasSecondaryAction)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: onSecondaryAction,
                                    icon: Icon(
                                      secondaryActionIcon ?? Icons.copy_rounded,
                                      size: 19,
                                    ),
                                    label: Text(
                                      secondaryActionLabel!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    style:
                                        OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.18,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 13,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ).copyWith(
                                          overlayColor:
                                              const WidgetStatePropertyAll(
                                                Colors.transparent,
                                              ),
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        if (hasTertiaryAction) ...[
                          if (hasPrimaryAction || hasSecondaryAction)
                            const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: onTertiaryAction,
                              icon: Icon(
                                tertiaryActionIcon ?? Icons.reply_rounded,
                                size: 19,
                              ),
                              label: Text(
                                tertiaryActionLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style:
                                  OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: _carismaBlueLight.withValues(
                                        alpha: 0.32,
                                      ),
                                    ),
                                    backgroundColor: _carismaBlue.withValues(
                                      alpha: 0.1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ).copyWith(
                                    overlayColor: const WidgetStatePropertyAll(
                                      Colors.transparent,
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ],
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
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _carismaBlue.withValues(alpha: 0.2),
            ),
            child: Icon(row.icon, color: _carismaBlueLight, size: 20),
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

class _StoryViewerPollVoteChip extends StatelessWidget {
  const _StoryViewerPollVoteChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: _carismaBlue.withValues(alpha: 0.18),
          border: Border.all(color: _carismaBlueLight.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.poll_rounded, color: _carismaBlueLight, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _storyPollOptions(ChatStoryRecord story) {
  if (story.stickerType != 'poll') {
    return const <String>[];
  }

  final options = story.stickerPayload
      .split('\n')
      .map((option) => option.trim())
      .where((option) => option.isNotEmpty)
      .take(2)
      .toList(growable: false);

  return options.length == 2 ? options : const <String>['Ja', 'Nein'];
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

// ignore: unused_element
class _PendingRequestTile extends StatelessWidget {
  const _PendingRequestTile({required this.request, required this.onTap});

  final ContactRequestRecord request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayPlate = (request.displayPlate?.trim().isNotEmpty ?? false)
        ? request.displayPlate!.trim()
        : request.plateKey;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: CaRismaDesignTokens.card,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 16,
            offset: const Offset(5, 5),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(-5, -5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: CaRismaDesignTokens.surface2,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.50),
                        blurRadius: 12,
                        offset: const Offset(4, 4),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.015),
                        blurRadius: 8,
                        offset: const Offset(-4, -4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: CaRismaDesignTokens.bluePrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (request.senderDisplayName?.trim().isNotEmpty ?? false)
                            ? request.senderDisplayName!.trim()
                            : 'plaqa Nutzer',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: CaRismaDesignTokens.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 16.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kennzeichen: $displayPlate',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: CaRismaDesignTokens.textSecondary.withValues(
                            alpha: 0.78,
                          ),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Ausstehend',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CaRismaDesignTokens.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: CaRismaDesignTokens.textMuted,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
