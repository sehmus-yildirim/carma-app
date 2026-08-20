part of '../chats_screen.dart';

class _ChatAccessBlockedCard extends StatelessWidget {
  const _ChatAccessBlockedCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CaRismaBlueIconBox(
            icon: Icons.lock_outline_rounded,
            size: 48,
            iconSize: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chats nicht verfügbar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                    height: 1.34,
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

class _ChatsSegmentedControl extends StatelessWidget {
  const _ChatsSegmentedControl({
    required this.selectedView,
    required this.onChanged,
  });

  final _ChatsView selectedView;
  final ValueChanged<_ChatsView> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: CaRismaDesignTokens.card,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  label: 'Chats',
                  icon: Icons.forum_rounded,
                  isSelected: selectedView == _ChatsView.chats,
                  onTap: () => onChanged(_ChatsView.chats),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SegmentButton(
                  label: 'Anfragen',
                  icon: Icons.mark_chat_unread_rounded,
                  isSelected: selectedView == _ChatsView.requests,
                  onTap: () => onChanged(_ChatsView.requests),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isSelected
                ? CaRismaDesignTokens.controlSurface
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.88)
                  : Colors.transparent,
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _carismaBlue.withValues(alpha: 0.16),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? CaRismaDesignTokens.bluePrimary
                    : CaRismaDesignTokens.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : CaRismaDesignTokens.textSecondary,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0,
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

class _ChatsOverview extends StatelessWidget {
  const _ChatsOverview({
    required this.chats,
    required this.archivedChats,
    required this.stories,
    required this.currentUserPhotoUrl,
    required this.currentUserDisplayName,
    required this.isAddingOwnStory,
    required this.isLoading,
    required this.hasLocalActiveChat,
    required this.localMessages,
    required this.selectedListView,
    required this.showArchiveShortcut,
    required this.onOpenArchived,
    required this.onShowMessages,
    required this.onHideArchiveShortcut,
    required this.onOpenChat,
    required this.onToggleChatRead,
    required this.onToggleChatPinned,
    required this.onToggleChatArchived,
    required this.onShowChatVehicleDetails,
    required this.onOpenLocalChat,
    required this.onAddOwnStory,
    required this.onOpenStory,
    required this.showStories,
  });

  final List<ChatRecord> chats;
  final List<ChatRecord> archivedChats;
  final List<ChatStoryRecord> stories;
  final String currentUserPhotoUrl;
  final String currentUserDisplayName;
  final bool isAddingOwnStory;
  final bool isLoading;
  final bool hasLocalActiveChat;
  final List<_LocalChatMessage> localMessages;
  final _ChatListView selectedListView;
  final bool showArchiveShortcut;
  final VoidCallback onOpenArchived;
  final VoidCallback onShowMessages;
  final VoidCallback onHideArchiveShortcut;
  final ValueChanged<ChatRecord> onOpenChat;
  final Future<void> Function(ChatRecord chat) onToggleChatRead;
  final Future<void> Function(ChatRecord chat) onToggleChatPinned;
  final Future<void> Function(ChatRecord chat) onToggleChatArchived;
  final Future<void> Function(ChatRecord chat) onShowChatVehicleDetails;
  final VoidCallback onOpenLocalChat;
  final ValueChanged<List<ChatRecord>> onAddOwnStory;
  final void Function(ChatStoryRecord story, List<ChatStoryRecord> stories)
  onOpenStory;
  final bool showStories;

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final visibleChats = chats;
    final visibleArchivedChats = archivedChats;
    final isArchivedView = selectedListView == _ChatListView.archived;
    final selectedChats = switch (selectedListView) {
      _ChatListView.messages => visibleChats,
      _ChatListView.archived => visibleArchivedChats,
    };
    final showLocalChat =
        selectedListView == _ChatListView.messages && hasLocalActiveChat;

    final listChildren = <Widget>[
      if (isLoading)
        const _InlineLoadingRow(label: 'Chats werden geladen...')
      else if (selectedChats.isEmpty && !showLocalChat)
        _EmptyListCard(
          icon: isArchivedView
              ? Icons.archive_outlined
              : Icons.chat_bubble_outline_rounded,
          title: isArchivedView ? 'Keine archivierten Chats' : 'Keine Chats',
        )
      else ...[
        for (final chat in selectedChats) ...[
          _ActiveChatListTile(
            key: ValueKey('chat_${chat.id}_$isArchivedView'),
            title: chat.displayNameFor(currentUserId),
            imageUrl: chat.profilePhotoUrlFor(currentUserId),
            subtitle: chat.lastMessage?.trim().isNotEmpty == true
                ? chat.lastMessage!.trim()
                : chat.vehicleTitle,
            isFavorite: chat.isFavoriteFor(currentUserId),
            isPinned: chat.isPinnedFor(currentUserId),
            isMuted: chat.isMutedFor(currentUserId),
            isUnread: chat.hasUnreadFor(currentUserId),
            isArchived: isArchivedView,
            onToggleRead: () => onToggleChatRead(chat),
            onTogglePinned: () => onToggleChatPinned(chat),
            onToggleArchived: () => onToggleChatArchived(chat),
            onShowVehicleDetails: () => onShowChatVehicleDetails(chat),
            trailing: _ChatOverflowMenu(
              chatId: chat.id,
              title: chat.displayNameFor(currentUserId),
              subtitle:
                  '${chat.vehicleModelLabel} - ${_formatChatPlateLabel(chat.displayPlate)}',
              vehicleLabel: chat.vehicleModelLabel,
              plateLabel: _formatChatPlateLabel(chat.displayPlate),
              isFavorite: chat.isFavoriteFor(currentUserId),
              isPinned: chat.isPinnedFor(currentUserId),
              isMuted: chat.isMutedFor(currentUserId),
              isUnread: chat.hasUnreadFor(currentUserId),
              isArchived: isArchivedView,
              popAfterStatusAction: false,
            ),
            onTap: () => onOpenChat(chat),
          ),
          const SizedBox(height: 6),
        ],
        if (showLocalChat) ...[
          _ActiveChatListTile(
            title: 'plaqa Nutzer',
            subtitle: localMessages.isNotEmpty
                ? localMessages.last.text
                : 'BMW 1er',
            trailing: const _ChatOverflowMenu(
              title: 'plaqa Nutzer',
              subtitle: 'BMW 1er - HH-HY 4747',
              vehicleLabel: 'BMW 1er',
              plateLabel: 'HH-HY 4747',
              popAfterStatusAction: false,
            ),
            onTap: onOpenLocalChat,
          ),
          const SizedBox(height: 6),
        ],
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showStories &&
            !isKeyboardOpen &&
            selectedListView == _ChatListView.messages) ...[
          _ChatStoriesStrip(
            chats: [...visibleChats, ...visibleArchivedChats],
            stories: stories,
            currentUserPhotoUrl: currentUserPhotoUrl,
            currentUserDisplayName: currentUserDisplayName,
            isAddingOwnStory: isAddingOwnStory,
            onAddOwnStory: () => onAddOwnStory([...chats, ...archivedChats]),
            onOpenStory: onOpenStory,
          ),
          const SizedBox(height: 16),
        ],
        if (selectedListView == _ChatListView.messages &&
            showArchiveShortcut) ...[
          _ArchivedChatsReveal(
            archivedCount: archivedChats.length,
            onOpen: onOpenArchived,
            onCollapse: onHideArchiveShortcut,
          ),
          const SizedBox(height: 12),
        ],
        if (isArchivedView) ...[
          _ArchivedChatsHeader(onBack: onShowMessages),
          SizedBox(height: isKeyboardOpen ? 8 : 14),
        ],
        Expanded(
          child: _ChatListScrollViewport(
            alwaysScrollable: selectedListView == _ChatListView.messages,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: listChildren,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatListScrollViewport extends StatefulWidget {
  const _ChatListScrollViewport({
    required this.child,
    required this.alwaysScrollable,
  });

  final Widget child;
  final bool alwaysScrollable;

  @override
  State<_ChatListScrollViewport> createState() =>
      _ChatListScrollViewportState();
}

class _ChatListScrollViewportState extends State<_ChatListScrollViewport> {
  final GlobalKey _contentKey = GlobalKey();
  double _contentHeight = 0;

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final renderObject = _contentKey.currentContext?.findRenderObject();
      final nextHeight = renderObject is RenderBox
          ? renderObject.size.height
          : 0.0;

      if ((nextHeight - _contentHeight).abs() > 0.5) {
        setState(() {
          _contentHeight = nextHeight;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final navigationGap = MediaQuery.of(context).viewInsets.bottom > 0
            ? 12.0
            : CaRismaDesignTokens.mainScreenBottomInset + 12;
        final availableHeight = constraints.maxHeight - navigationGap;
        final needsNavigationGap = _contentHeight > availableHeight;
        final bottomPadding = needsNavigationGap ? navigationGap : 10.0;
        final canScroll =
            _contentHeight + bottomPadding > constraints.maxHeight + 0.5;
        final physics = widget.alwaysScrollable
            ? const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              )
            : canScroll
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics();

        _scheduleMeasure();

        return SingleChildScrollView(
          physics: physics,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: KeyedSubtree(key: _contentKey, child: widget.child),
          ),
        );
      },
    );
  }
}

class _ArchivedChatsReveal extends StatelessWidget {
  const _ArchivedChatsReveal({
    required this.archivedCount,
    required this.onOpen,
    required this.onCollapse,
  });

  final int archivedCount;
  final VoidCallback onOpen;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: CaRismaDesignTokens.card,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.archive_outlined,
                      color: _carismaBlueLight,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Archiviert',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (archivedCount > 0)
                      Text(
                        '$archivedCount',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCollapse,
            child: SizedBox(
              width: 48,
              height: 54,
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white.withValues(alpha: 0.66),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedChatsHeader extends StatelessWidget {
  const _ArchivedChatsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onBack,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            const Icon(
              Icons.arrow_back_rounded,
              color: _carismaBlueLight,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Archivierte Chats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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

enum _RequestSortOrder { newest, oldest }

class _RequestsOverview extends StatefulWidget {
  const _RequestsOverview({
    required this.incomingStream,
    required this.outgoingStream,
    required this.busyRequestIds,
    required this.selectedListView,
    required this.onListViewChanged,
    required this.onHorizontalSwipe,
    required this.onAccept,
    required this.onDecline,
    required this.onWithdraw,
    super.key,
  });

  final Stream<List<ContactRequestRecord>> incomingStream;
  final Stream<List<ContactRequestRecord>> outgoingStream;
  final Set<String> busyRequestIds;
  final _RequestListView selectedListView;
  final ValueChanged<_RequestListView> onListViewChanged;
  final GestureDragEndCallback onHorizontalSwipe;
  final ValueChanged<ContactRequestRecord> onAccept;
  final ValueChanged<ContactRequestRecord> onDecline;
  final ValueChanged<ContactRequestRecord> onWithdraw;

  @override
  State<_RequestsOverview> createState() => _RequestsOverviewState();
}

class _RequestsOverviewState extends State<_RequestsOverview> {
  _RequestSortOrder _sortOrder = _RequestSortOrder.newest;
  Timer? _requestCountdownTimer;

  @override
  void initState() {
    super.initState();
    _requestCountdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _requestCountdownTimer?.cancel();
    super.dispose();
  }

  List<ContactRequestRecord> _sortedRequests(
    List<ContactRequestRecord> requests,
  ) {
    final sorted = [...requests];
    sorted.sort((a, b) {
      final comparison = b.createdAt.compareTo(a.createdAt);
      return _sortOrder == _RequestSortOrder.newest ? comparison : -comparison;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContactRequestRecord>>(
      stream: widget.incomingStream,
      builder: (context, incomingSnapshot) {
        return StreamBuilder<List<ContactRequestRecord>>(
          stream: widget.outgoingStream,
          builder: (context, outgoingSnapshot) {
            final incoming =
                incomingSnapshot.data ?? const <ContactRequestRecord>[];
            final outgoing =
                outgoingSnapshot.data ?? const <ContactRequestRecord>[];
            final isLoading =
                incomingSnapshot.connectionState == ConnectionState.waiting ||
                outgoingSnapshot.connectionState == ConnectionState.waiting;
            final error = incomingSnapshot.error ?? outgoingSnapshot.error;

            final isIncomingView =
                widget.selectedListView == _RequestListView.incoming;
            final selectedRequests = _sortedRequests(
              isIncomingView ? incoming : outgoing,
            );
            final selectedContent = error != null
                ? _InlineErrorCard(
                    message: _friendlyChatUiError(
                      error,
                      fallback: 'Kontaktanfragen konnten nicht geladen werden.',
                    ),
                  )
                : isLoading
                ? const _InlineLoadingRow(label: 'Anfragen werden geladen...')
                : selectedRequests.isEmpty
                ? _EmptyListCard(
                    icon: isIncomingView
                        ? Icons.mark_email_unread_outlined
                        : Icons.schedule_send_outlined,
                    title: isIncomingView
                        ? 'Keine eingehenden Anfragen'
                        : 'Keine gesendeten Anfragen',
                  )
                : _InlineRequestList(
                    requests: selectedRequests,
                    isIncoming: isIncomingView,
                    busyRequestIds: widget.busyRequestIds,
                    onAccept: widget.onAccept,
                    onDecline: widget.onDecline,
                    onWithdraw: widget.onWithdraw,
                  );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InlineTextTabs<_RequestListView>(
                  selectedValue: widget.selectedListView,
                  isCompact: MediaQuery.of(context).viewInsets.bottom > 0,
                  items: [
                    _InlineTextTabItem(
                      value: _RequestListView.incoming,
                      label: 'Eingehend',
                      count: incoming.length,
                    ),
                    _InlineTextTabItem(
                      value: _RequestListView.outgoing,
                      label: 'Gesendet',
                      count: outgoing.length,
                    ),
                  ],
                  onChanged: widget.onListViewChanged,
                ),
                const SizedBox(height: 8),
                _RequestSortToggle(
                  selectedOrder: _sortOrder,
                  onChanged: (order) {
                    setState(() {
                      _sortOrder = order;
                    });
                  },
                ),
                SizedBox(
                  height: MediaQuery.of(context).viewInsets.bottom > 0 ? 6 : 10,
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: widget.onHorizontalSwipe,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            for (final child in previousChildren)
                              Positioned.fill(child: child),
                            if (currentChild != null)
                              Positioned.fill(child: currentChild),
                          ],
                        );
                      },
                      child: _RequestScrollViewport(
                        key: ValueKey('${widget.selectedListView}_$_sortOrder'),
                        child: selectedContent,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RequestScrollViewport extends StatefulWidget {
  const _RequestScrollViewport({super.key, required this.child});

  final Widget child;

  @override
  State<_RequestScrollViewport> createState() => _RequestScrollViewportState();
}

class _RequestScrollViewportState extends State<_RequestScrollViewport> {
  final GlobalKey _contentKey = GlobalKey();
  double _contentHeight = 0;

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final renderObject = _contentKey.currentContext?.findRenderObject();
      final nextHeight = renderObject is RenderBox
          ? renderObject.size.height
          : 0.0;
      if ((nextHeight - _contentHeight).abs() > 0.5) {
        setState(() {
          _contentHeight = nextHeight;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final navigationGap = MediaQuery.of(context).viewInsets.bottom > 0
            ? 12.0
            : CaRismaDesignTokens.mainScreenBottomInset + 12;
        final availableHeight = constraints.maxHeight - navigationGap;
        final needsNavigationGap = _contentHeight > availableHeight;
        final bottomPadding = needsNavigationGap ? navigationGap : 12.0;
        final canScroll =
            _contentHeight + bottomPadding > constraints.maxHeight + 0.5;

        _scheduleMeasure();

        return SingleChildScrollView(
          physics: canScroll
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            key: _contentKey,
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _RequestSortToggle extends StatelessWidget {
  const _RequestSortToggle({
    required this.selectedOrder,
    required this.onChanged,
  });

  final _RequestSortOrder selectedOrder;
  final ValueChanged<_RequestSortOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: CaRismaDesignTokens.controlSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RequestSortChip(
              label: 'Neueste',
              isSelected: selectedOrder == _RequestSortOrder.newest,
              onTap: () => onChanged(_RequestSortOrder.newest),
            ),
            _RequestSortChip(
              label: 'Älteste',
              isSelected: selectedOrder == _RequestSortOrder.oldest,
              onTap: () => onChanged(_RequestSortOrder.oldest),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestSortChip extends StatelessWidget {
  const _RequestSortChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: CaRismaDesignTokens.controlSurface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isSelected
                ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.58)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isSelected
                ? CaRismaDesignTokens.textPrimary
                : CaRismaDesignTokens.textSecondary.withValues(alpha: 0.74),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _InlineTextTabItem<T> {
  const _InlineTextTabItem({
    required this.value,
    required this.label,
    this.count,
  });

  final T value;
  final String label;
  final int? count;
}

class _InlineTextTabs<T> extends StatelessWidget {
  const _InlineTextTabs({
    required this.selectedValue,
    required this.items,
    required this.onChanged,
    this.isCompact = false,
  });

  final T selectedValue;
  final List<_InlineTextTabItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(isCompact ? 5 : 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: CaRismaDesignTokens.card,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (final item in items) ...[
                Expanded(
                  child: _InlineTextTab<T>(
                    item: item,
                    isSelected: item.value == selectedValue,
                    isCompact: isCompact,
                    onTap: () => onChanged(item.value),
                  ),
                ),
                if (item != items.last) SizedBox(width: isCompact ? 3 : 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineTextTab<T> extends StatelessWidget {
  const _InlineTextTab({
    required this.item,
    required this.isSelected,
    required this.isCompact,
    required this.onTap,
  });

  final _InlineTextTabItem<T> item;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.48);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 4 : 6,
            vertical: isCompact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            color: isSelected
                ? CaRismaDesignTokens.controlSurface
                : Colors.white.withValues(alpha: isCompact ? 0.02 : 0.03),
            border: Border.all(
              color: isSelected
                  ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.88)
                  : Colors.transparent,
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _carismaBlue.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: isCompact ? 12 : 13.5,
                      ),
                    ),
                  ),
                  if (item.count != null) ...[
                    const SizedBox(width: 8),
                    _InlineTabCountBadge(
                      count: item.count!,
                      isSelected: isSelected,
                      isCompact: isCompact,
                    ),
                  ],
                ],
              ),
              SizedBox(height: isCompact ? 2 : 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: isSelected ? (isCompact ? 18 : 22) : 0,
                height: isCompact ? 2 : 2.4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineTabCountBadge extends StatelessWidget {
  const _InlineTabCountBadge({
    required this.count,
    required this.isSelected,
    required this.isCompact,
  });

  final int count;
  final bool isSelected;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.54)
        : Colors.white.withValues(alpha: 0.10);
    final iconColor = isSelected
        ? CaRismaDesignTokens.bluePrimary
        : CaRismaDesignTokens.textSecondary.withValues(alpha: 0.72);
    final textColor = isSelected
        ? CaRismaDesignTokens.textPrimary
        : CaRismaDesignTokens.textSecondary.withValues(alpha: 0.78);

    return Container(
      height: isCompact ? 22 : 24,
      constraints: BoxConstraints(minWidth: isCompact ? 34 : 38),
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 7),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mark_chat_unread_outlined,
            size: isCompact ? 11 : 12,
            color: iconColor,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: isCompact ? 10.5 : 11,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileStoryStrip extends StatelessWidget {
  const ProfileStoryStrip({
    super.key,
    required this.stories,
    required this.currentUserId,
    required this.currentUserPhotoUrl,
    required this.currentUserDisplayName,
    required this.isAddingOwnStory,
    required this.onAddOwnStory,
    required this.onOpenStory,
  });

  final List<ChatStoryRecord> stories;
  final String currentUserId;
  final String currentUserPhotoUrl;
  final String currentUserDisplayName;
  final bool isAddingOwnStory;
  final VoidCallback onAddOwnStory;
  final void Function(ChatStoryRecord story, List<ChatStoryRecord> stories)
  onOpenStory;

  @override
  Widget build(BuildContext context) {
    final normalizedUserId = currentUserId.trim();
    final ownStories =
        stories
            .where(
              (story) =>
                  story.ownerUserId.trim() == normalizedUserId &&
                  !story.isExpired &&
                  story.hasRenderableMedia,
            )
            .toList(growable: true)
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    final ownStory = ownStories.isEmpty ? null : ownStories.last;
    final storiesByOwner = <String, List<ChatStoryRecord>>{};
    for (final story in stories) {
      final ownerUserId = story.ownerUserId.trim();
      if (ownerUserId.isEmpty ||
          ownerUserId == normalizedUserId ||
          story.isExpired ||
          !story.hasRenderableMedia) {
        continue;
      }
      storiesByOwner.putIfAbsent(ownerUserId, () => []).add(story);
    }
    for (final ownerStories in storiesByOwner.values) {
      ownerStories.sort(
        (left, right) => left.createdAt.compareTo(right.createdAt),
      );
    }
    final visibleGroups = storiesByOwner.values.toList(growable: false)
      ..sort((left, right) {
        final leftHasNew = left.any(
          (story) => !story.viewedAtBy.containsKey(normalizedUserId),
        );
        final rightHasNew = right.any(
          (story) => !story.viewedAtBy.containsKey(normalizedUserId),
        );
        if (leftHasNew != rightHasNew) return leftHasNew ? -1 : 1;
        return right.last.createdAt.compareTo(left.last.createdAt);
      });

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 124,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: CaRismaDesignTokens.card,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visibleGroups.take(16).length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                final ownStoryViewCount = ownStories
                    .expand((story) => story.viewedAtBy.keys)
                    .where((viewerId) => viewerId.trim() != normalizedUserId)
                    .toSet()
                    .length;
                return Align(
                  alignment: Alignment.center,
                  child: _StoryBubble(
                    label: 'Deine Story',
                    fallbackLabel: currentUserDisplayName,
                    imageUrl: currentUserPhotoUrl.trim().isEmpty
                        ? null
                        : currentUserPhotoUrl.trim(),
                    preferAvatarFallback: true,
                    isVideo: ownStory?.isVideo ?? false,
                    isOwnStory: true,
                    hasStory: ownStory != null,
                    isViewed: true,
                    createdAt: ownStory?.createdAt,
                    viewCount: ownStoryViewCount,
                    isBusy: isAddingOwnStory,
                    onTap: isAddingOwnStory
                        ? () {}
                        : ownStory == null
                        ? onAddOwnStory
                        : () => onOpenStory(ownStory, ownStories),
                    onAddTap: isAddingOwnStory ? null : onAddOwnStory,
                  ),
                );
              }

              final ownerStories = visibleGroups[index - 1];
              ChatStoryRecord? firstUnviewed;
              for (final candidate in ownerStories) {
                if (!candidate.viewedAtBy.containsKey(normalizedUserId)) {
                  firstUnviewed = candidate;
                  break;
                }
              }
              final story = firstUnviewed ?? ownerStories.last;
              final storyImageUrl =
                  story.ownerPhotoUrl?.trim().isNotEmpty == true
                  ? story.ownerPhotoUrl
                  : null;
              return Align(
                alignment: Alignment.center,
                child: _StoryBubble(
                  label: story.ownerDisplayName,
                  fallbackLabel: story.ownerDisplayName,
                  imageUrl: storyImageUrl,
                  preferAvatarFallback: true,
                  isVideo: story.isVideo,
                  hasStory: true,
                  isViewed: ownerStories.every(
                    (item) => item.viewedAtBy.containsKey(normalizedUserId),
                  ),
                  createdAt: story.createdAt,
                  onTap: () => onOpenStory(story, ownerStories),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChatStoriesStrip extends StatelessWidget {
  const _ChatStoriesStrip({
    required this.chats,
    required this.stories,
    required this.currentUserPhotoUrl,
    required this.currentUserDisplayName,
    required this.isAddingOwnStory,
    required this.onAddOwnStory,
    required this.onOpenStory,
  });

  final List<ChatRecord> chats;
  final List<ChatStoryRecord> stories;
  final String currentUserPhotoUrl;
  final String currentUserDisplayName;
  final bool isAddingOwnStory;
  final VoidCallback onAddOwnStory;
  final void Function(ChatStoryRecord story, List<ChatStoryRecord> stories)
  onOpenStory;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? '';
    final trimmedCurrentUserId = currentUserId.trim();
    final ownProfilePhotoUrl = currentUserPhotoUrl.trim().isNotEmpty
        ? currentUserPhotoUrl.trim()
        : currentUser?.photoURL?.trim();
    final visibleOwnerIds = <String>{};

    if (trimmedCurrentUserId.isNotEmpty) {
      for (final chat in chats) {
        final participantIds = chat.participants
            .map((participant) => participant.trim())
            .where((participant) => participant.isNotEmpty)
            .toSet();

        if ((chat.status != ChatStatus.active &&
                chat.status != ChatStatus.archived) ||
            participantIds.length != 2 ||
            !participantIds.contains(trimmedCurrentUserId) ||
            chat.isDeletedFor(trimmedCurrentUserId)) {
          continue;
        }

        for (final participantId in participantIds) {
          if (!chat.isDeletedFor(participantId)) {
            visibleOwnerIds.add(participantId);
          }
        }
      }
    }
    final ownStories =
        stories
            .where(
              (story) =>
                  story.ownerUserId.trim() == trimmedCurrentUserId &&
                  !story.isExpired &&
                  story.hasRenderableMedia,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final ownStory = ownStories.isEmpty ? null : ownStories.last;

    final groupedStories = <String, List<ChatStoryRecord>>{};
    for (final story in stories) {
      final ownerUserId = story.ownerUserId.trim();
      if (ownerUserId == trimmedCurrentUserId ||
          story.isExpired ||
          !story.hasRenderableMedia ||
          !visibleOwnerIds.contains(ownerUserId)) {
        continue;
      }
      groupedStories.putIfAbsent(ownerUserId, () => []).add(story);
    }
    for (final ownerStories in groupedStories.values) {
      ownerStories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final visibleStoryGroups = groupedStories.values.toList()
      ..sort((a, b) {
        final aHasUnviewed = a.any(
          (story) => !story.viewedAtBy.containsKey(trimmedCurrentUserId),
        );
        final bHasUnviewed = b.any(
          (story) => !story.viewedAtBy.containsKey(trimmedCurrentUserId),
        );
        if (aHasUnviewed != bHasUnviewed) return aHasUnviewed ? -1 : 1;
        return b.last.createdAt.compareTo(a.last.createdAt);
      });
    final visibleGroups = visibleStoryGroups.take(12).toList(growable: false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: visibleGroups.isEmpty ? 116 : 128,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: CaRismaDesignTokens.card,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visibleGroups.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                final currentOwnStory = ownStory;
                final ownBubbleImageUrl = ownProfilePhotoUrl?.isNotEmpty == true
                    ? ownProfilePhotoUrl
                    : null;
                final ownStoryViewCount = ownStories
                    .expand((story) => story.viewedAtBy.keys)
                    .where(
                      (viewerId) => viewerId.trim() != trimmedCurrentUserId,
                    )
                    .toSet()
                    .length;

                return Align(
                  alignment: Alignment.center,
                  child: _StoryBubble(
                    label: 'Deine Story',
                    fallbackLabel: currentUserDisplayName,
                    imageUrl: ownBubbleImageUrl,
                    preferAvatarFallback: true,
                    isVideo: currentOwnStory?.isVideo ?? false,
                    isOwnStory: true,
                    hasStory: currentOwnStory != null,
                    isViewed: true,
                    createdAt: currentOwnStory?.createdAt,
                    viewCount: ownStoryViewCount,
                    isBusy: isAddingOwnStory,
                    onTap: isAddingOwnStory
                        ? () {}
                        : currentOwnStory == null
                        ? onAddOwnStory
                        : () => onOpenStory(currentOwnStory, ownStories),
                    onAddTap: isAddingOwnStory ? null : onAddOwnStory,
                  ),
                );
              }

              final ownerStories = visibleGroups[index - 1];
              final firstUnviewed = ownerStories
                  .cast<ChatStoryRecord?>()
                  .firstWhere(
                    (story) =>
                        story != null &&
                        !story.viewedAtBy.containsKey(trimmedCurrentUserId),
                    orElse: () => null,
                  );
              final story = firstUnviewed ?? ownerStories.last;
              final storyImageUrl =
                  story.ownerPhotoUrl?.trim().isNotEmpty == true
                  ? story.ownerPhotoUrl
                  : null;
              return Align(
                alignment: Alignment.center,
                child: _StoryBubble(
                  label: story.ownerDisplayName,
                  fallbackLabel: story.ownerDisplayName,
                  imageUrl: storyImageUrl,
                  preferAvatarFallback: true,
                  isVideo: story.isVideo,
                  hasStory: true,
                  isViewed: ownerStories.every(
                    (item) => item.viewedAtBy.keys.any(
                      (viewerId) => viewerId.trim() == trimmedCurrentUserId,
                    ),
                  ),
                  createdAt: story.createdAt,
                  onTap: () => onOpenStory(story, ownerStories),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.label,
    this.fallbackLabel,
    this.imageUrl,
    this.preferAvatarFallback = false,
    this.isVideo = false,
    this.isOwnStory = false,
    this.hasStory = false,
    this.isViewed = false,
    this.createdAt,
    this.viewCount = 0,
    this.isBusy = false,
    required this.onTap,
    this.onAddTap,
  });

  final String label;
  final String? fallbackLabel;
  final String? imageUrl;
  final bool preferAvatarFallback;
  final bool isVideo;
  final bool isOwnStory;
  final bool hasStory;
  final bool isViewed;
  final DateTime? createdAt;
  final int viewCount;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    final viewCountLabel = viewCount > 99 ? '99+' : '$viewCount';
    final isNewStory = hasStory && !isViewed && !isOwnStory;
    final semanticsLabel = isOwnStory
        ? hasStory
              ? 'Deine Story öffnen'
              : 'Deine Story hinzufügen'
        : isViewed
        ? 'Gesehene Story von $label'
        : 'Neue Story von $label';
    final ringGradient = hasStory
        ? isNewStory || isOwnStory
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_carismaBlueDark, _carismaBlueLight],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.28),
                    Colors.white.withValues(alpha: 0.10),
                  ],
                )
        : null;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: SizedBox(
        width: 94,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: ringGradient,
                      color: hasStory
                          ? null
                          : Colors.white.withValues(alpha: 0.10),
                      boxShadow: isNewStory
                          ? [
                              BoxShadow(
                                color: _carismaBlueLight.withValues(
                                  alpha: 0.26,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: ClipOval(
                      child: isBusy
                          ? Container(
                              color: Colors.white.withValues(alpha: 0.08),
                              child: const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : hasStory && imageUrl?.trim().isNotEmpty == true
                          ? Image(
                              image: _storyImageProvider(imageUrl!.trim()),
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  isVideo && !preferAvatarFallback
                                  ? const _StoryVideoBubblePlaceholder()
                                  : _AvatarCircle(
                                      size: 72,
                                      imageUrl: null,
                                      iconSize: 38,
                                      fallbackLabel: fallbackLabel ?? label,
                                    ),
                            )
                          : hasStory && isVideo && !preferAvatarFallback
                          ? const _StoryVideoBubblePlaceholder()
                          : _AvatarCircle(
                              size: 72,
                              imageUrl: imageUrl,
                              iconSize: 38,
                              fallbackLabel: fallbackLabel ?? label,
                            ),
                    ),
                  ),
                  if (isOwnStory)
                    Positioned(
                      right: -12,
                      bottom: -11,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onAddTap,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _carismaBlue,
                                border: Border.all(
                                  color: const Color(0xFF101827),
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (hasStory && !isViewed && !isOwnStory)
                    Positioned(
                      right: -7,
                      top: -3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: _carismaBlueLight,
                          border: Border.all(color: const Color(0xFF101827)),
                          boxShadow: [
                            BoxShadow(
                              color: _carismaBlueLight.withValues(alpha: 0.36),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Text(
                            'Neu',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (isOwnStory && hasStory && viewCount > 0)
                    Positioned(
                      left: -4,
                      top: -2,
                      child: Container(
                        height: 22,
                        constraints: const BoxConstraints(minWidth: 30),
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: const Color(
                            0xFF101827,
                          ).withValues(alpha: 0.92),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.24),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_rounded,
                              color: Colors.white.withValues(alpha: 0.82),
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              viewCountLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: hasStory && (!isViewed || isOwnStory)
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.78),
                  fontWeight: hasStory && (!isViewed || isOwnStory)
                      ? FontWeight.w900
                      : FontWeight.w800,
                  fontSize: 12.2,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryVideoBubblePlaceholder extends StatelessWidget {
  const _StoryVideoBubblePlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _myMessageBlueLight,
            _carismaBlueDark.withValues(alpha: 0.86),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.videocam_rounded, color: Colors.white, size: 32),
      ),
    );
  }
}

class _InlineLoadingRow extends StatelessWidget {
  const _InlineLoadingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.76),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineRequestList extends StatefulWidget {
  const _InlineRequestList({
    required this.requests,
    required this.isIncoming,
    required this.busyRequestIds,
    required this.onAccept,
    required this.onDecline,
    required this.onWithdraw,
  });

  final List<ContactRequestRecord> requests;
  final bool isIncoming;
  final Set<String> busyRequestIds;
  final ValueChanged<ContactRequestRecord> onAccept;
  final ValueChanged<ContactRequestRecord> onDecline;
  final ValueChanged<ContactRequestRecord> onWithdraw;

  @override
  State<_InlineRequestList> createState() => _InlineRequestListState();
}

class _InlineRequestListState extends State<_InlineRequestList> {
  final Set<String> _autoRepairRequestIds = <String>{};

  @override
  void didUpdateWidget(covariant _InlineRequestList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final visibleRequestIds = widget.requests
        .map((request) => request.id)
        .toSet();
    _autoRepairRequestIds.removeWhere(
      (requestId) => !visibleRequestIds.contains(requestId),
    );
  }

  void _scheduleAcceptedRequestRepair() {
    for (final request in widget.requests) {
      final shouldRepair =
          request.isAccepted &&
          !request.hasLinkedChat &&
          !widget.busyRequestIds.contains(request.id) &&
          !_autoRepairRequestIds.contains(request.id);

      if (!shouldRepair) {
        continue;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoRepairRequestIds.contains(request.id)) {
          return;
        }

        setState(() {
          _autoRepairRequestIds.add(request.id);
        });
        widget.onAccept(request);
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleAcceptedRequestRepair();

    return Column(
      children: [
        for (final request in widget.requests) ...[
          _CollapsibleInlineRequestTile(
            request: request,
            isIncoming: widget.isIncoming,
            isBusy: widget.busyRequestIds.contains(request.id),
            onAccept: () => widget.onAccept(request),
            onDecline: () => widget.onDecline(request),
            onWithdraw: () => widget.onWithdraw(request),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CollapsibleInlineRequestTile extends StatefulWidget {
  const _CollapsibleInlineRequestTile({
    required this.request,
    required this.isIncoming,
    required this.isBusy,
    required this.onAccept,
    required this.onDecline,
    required this.onWithdraw,
  });

  final ContactRequestRecord request;
  final bool isIncoming;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onWithdraw;

  @override
  State<_CollapsibleInlineRequestTile> createState() =>
      _CollapsibleInlineRequestTileState();
}

class _CollapsibleInlineRequestTileState
    extends State<_CollapsibleInlineRequestTile> {
  bool _isExpanded = false;

  String get _personName {
    final rawName = widget.isIncoming
        ? widget.request.senderDisplayName?.trim()
        : widget.request.receiverDisplayName?.trim();
    if (rawName != null && rawName.isNotEmpty) {
      return _InlineRequestTile._shortDisplayName(rawName);
    }
    return widget.isIncoming ? 'Neue Anfrage' : 'Gesendete Anfrage';
  }

  DateTime get _expiresAt {
    return widget.request.expiresAt ??
        widget.request.createdAt.add(const Duration(hours: 48));
  }

  void _setExpanded(bool value) {
    if (_isExpanded == value) {
      return;
    }
    setState(() {
      _isExpanded = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _isExpanded
            ? _InlineRequestTile(
                key: ValueKey('expanded-${widget.request.id}'),
                request: widget.request,
                isIncoming: widget.isIncoming,
                isBusy: widget.isBusy,
                onAccept: widget.onAccept,
                onDecline: widget.onDecline,
                onWithdraw: widget.onWithdraw,
                onCollapse: () => _setExpanded(false),
              )
            : _CompactInlineRequestTile(
                key: ValueKey('compact-${widget.request.id}'),
                personName: _personName,
                profilePhotoUrl: widget.request.profilePhotoUrl(
                  isIncoming: widget.isIncoming,
                ),
                expiresAt: _expiresAt,
                onExpand: () => _setExpanded(true),
              ),
      ),
    );
  }
}

class _CompactInlineRequestTile extends StatelessWidget {
  const _CompactInlineRequestTile({
    super.key,
    required this.personName,
    required this.profilePhotoUrl,
    required this.expiresAt,
    required this.onExpand,
  });

  final String personName;
  final String? profilePhotoUrl;
  final DateTime expiresAt;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: CaRismaDesignTokens.surfaceDecoration(
        radius: 24,
        borderAlpha: 0.11,
        darkShadowAlpha: 0.34,
        blueShadowAlpha: 0.03,
      ),
      child: Row(
        children: [
          _UserAvatarPlaceholder(size: 50, imageUrl: profilePhotoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              personName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: CaRismaDesignTokens.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RequestExpiryBadge(expiresAt: expiresAt),
          const SizedBox(width: 6),
          _RequestExpansionButton(isExpanded: false, onTap: onExpand),
        ],
      ),
    );
  }
}

class _RequestExpansionButton extends StatelessWidget {
  const _RequestExpansionButton({
    required this.isExpanded,
    required this.onTap,
  });

  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isExpanded ? 'Anfrage einklappen' : 'Anfrage öffnen',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CaRismaDesignTokens.controlSurface,
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withValues(alpha: 0.78),
              size: 23,
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestPlateSegments {
  const _RequestPlateSegments({
    required this.region,
    required this.letters,
    required this.numbers,
  });

  final String region;
  final String letters;
  final String numbers;
}

class _InlineRequestTile extends StatelessWidget {
  const _InlineRequestTile({
    super.key,
    required this.request,
    required this.isIncoming,
    required this.isBusy,
    required this.onAccept,
    required this.onDecline,
    required this.onWithdraw,
    required this.onCollapse,
  });

  final ContactRequestRecord request;
  final bool isIncoming;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onWithdraw;
  final VoidCallback onCollapse;

  String get _brand {
    final brand = request.vehicleBrand?.trim();
    return brand == null || brand.isEmpty ? 'Automarke' : brand;
  }

  String get _model {
    final model = request.vehicleModel?.trim();
    return model == null || model.isEmpty ? 'Automodell' : model;
  }

  String get _color {
    final color = request.vehicleColor?.trim();
    return color == null || color.isEmpty ? 'Farbe unbekannt' : color;
  }

  String get _personName {
    final name = isIncoming
        ? request.senderDisplayName?.trim()
        : request.receiverDisplayName?.trim();

    if (name != null && name.isNotEmpty) {
      return _shortDisplayName(name);
    }

    return isIncoming ? 'Neue Anfrage' : 'Gesendete Anfrage';
  }

  String get _countryCode {
    final country = request.countryCode.trim().toUpperCase();
    return country.isEmpty ? 'DE' : country;
  }

  _RequestPlateSegments get _plateSegments {
    return _parsePlateSegments(
      request.displayPlate?.trim().isNotEmpty == true
          ? request.displayPlate!.trim()
          : request.plateKey,
      _countryCode,
    );
  }

  String get _requestReasonKey {
    final key = request.requestReason?.trim().toLowerCase();

    if (key != null && key.isNotEmpty) {
      return key;
    }

    final message = request.message.toLowerCase();
    if (message.contains('kompliment') ||
        message.contains('schönes auto') ||
        message.contains('positiv aufgefallen')) {
      return 'compliment';
    }
    if (message.contains('treffen') || message.contains('ausfahrt')) {
      return 'meet_and_drive';
    }
    if (message.contains('kennenlernen')) {
      return 'get_to_know';
    }
    return 'vehicle_question';
  }

  String get _requestReasonTitle {
    return switch (_requestReasonKey) {
      'compliment' => 'Kompliment zum Fahrzeug',
      'meet_and_drive' => 'Treffen & Ausfahrt',
      'get_to_know' => 'Kennenlernen',
      _ => 'Frage zum Fahrzeug',
    };
  }

  IconData get _requestReasonIcon {
    return switch (_requestReasonKey) {
      'compliment' => Icons.thumb_up_alt_outlined,
      'meet_and_drive' => Icons.groups_2_outlined,
      'get_to_know' => Icons.favorite_outline_rounded,
      _ => Icons.help_outline_rounded,
    };
  }

  String get _requestMessage {
    final message = request.message.trim();
    return message.isEmpty ? _incomingMessage : message;
  }

  DateTime get _effectiveExpiresAt {
    return request.expiresAt ??
        request.createdAt.add(const Duration(hours: 48));
  }

  String get _profileTargetUserId {
    return isIncoming
        ? request.senderUserId.trim()
        : request.receiverUserId.trim();
  }

  String get _incomingMessage {
    final vehicle = [
      if (request.vehicleColor != null &&
          request.vehicleColor!.trim().isNotEmpty)
        _vehicleColorAdjective(request.vehicleColor!),
      if (request.vehicleBrand != null &&
          request.vehicleBrand!.trim().isNotEmpty)
        request.vehicleBrand!.trim(),
      if (request.vehicleModel != null &&
          request.vehicleModel!.trim().isNotEmpty)
        request.vehicleModel!.trim(),
    ].join(' ').trim();

    if (vehicle.isEmpty) {
      return 'Hey, ich bin der Fahrer dieses Fahrzeugs.';
    }

    return 'Hey, ich bin der Fahrer im $vehicle.';
  }

  static String _vehicleColorAdjective(String color) {
    return switch (color.trim().toLowerCase()) {
      'schwarz' => 'schwarzen',
      'weiss' || 'weiß' => 'weißen',
      'silber' => 'silbernen',
      'grau' => 'grauen',
      'blau' => 'blauen',
      'rot' => 'roten',
      'gruen' || 'grün' => 'grünen',
      'braun' => 'braunen',
      'gelb' => 'gelben',
      'orange' => 'orangenen',
      _ => color.trim(),
    };
  }

  static String _shortDisplayName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return name.trim();
    }

    final firstName = parts.first;
    if (parts.length == 1) {
      return firstName;
    }

    final initial = parts.last.characters.first.toUpperCase();
    return '$firstName $initial.';
  }

  static _RequestPlateSegments _parsePlateSegments(
    String value,
    String countryCode,
  ) {
    final normalized = value
        .trim()
        .toUpperCase()
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    if (normalized.isEmpty) {
      return const _RequestPlateSegments(region: '', letters: '', numbers: '');
    }

    final tokens = normalized.split(' ');
    if (countryCode == 'CH') {
      return _RequestPlateSegments(
        region: tokens.first,
        letters: '',
        numbers: tokens.length > 1 ? tokens.sublist(1).join('') : '',
      );
    }

    if (tokens.length >= 3) {
      return _RequestPlateSegments(
        region: tokens[0],
        letters: tokens[1],
        numbers: tokens.sublist(2).join(''),
      );
    }

    if (tokens.length == 2) {
      final tailMatch = RegExp(
        r'^([A-ZÄÖÜ]{1,3})([0-9]{1,4})$',
      ).firstMatch(tokens[1]);

      if (tailMatch != null) {
        return _RequestPlateSegments(
          region: tokens[0],
          letters: tailMatch.group(1)!,
          numbers: tailMatch.group(2)!,
        );
      }

      return _RequestPlateSegments(
        region: tokens[0],
        letters: '',
        numbers: tokens[1],
      );
    }

    final compactMatch = RegExp(
      r'^([A-ZÄÖÜ]{1,3})([A-ZÄÖÜ]{1,3})([0-9]{1,4})$',
    ).firstMatch(normalized);

    if (compactMatch != null) {
      return _RequestPlateSegments(
        region: compactMatch.group(1)!,
        letters: compactMatch.group(2)!,
        numbers: compactMatch.group(3)!,
      );
    }

    return _RequestPlateSegments(region: normalized, letters: '', numbers: '');
  }

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = request.profilePhotoUrl(isIncoming: isIncoming);
    final isExpired = request.isExpiredByTime;
    final canActOnRequest = request.isPending && !isExpired;
    final statusLabel = isExpired
        ? 'Abgelaufen'
        : request.isAccepted && !request.hasLinkedChat
        ? 'Angenommen'
        : request.statusLabel;
    final plateSegments = _plateSegments;
    final regionPresentation = registrationRegionPresentationFor(
      countryCode: _countryCode,
      plateCode: plateSegments.region,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: CaRismaDesignTokens.surfaceDecoration(
          radius: 24,
          borderAlpha: 0.11,
          darkShadowAlpha: 0.34,
          blueShadowAlpha: 0.03,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 58,
                  child: Column(
                    children: [
                      _UserAvatarPlaceholder(
                        size: 58,
                        imageUrl: profilePhotoUrl,
                      ),
                      const SizedBox(height: 7),
                      _ProfileViewBadge(
                        onTap: () => _openRequestProfile(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _personName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: CaRismaDesignTokens.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _RequestExpiryBadge(expiresAt: _effectiveExpiresAt),
                          const SizedBox(width: 6),
                          _RequestExpansionButton(
                            isExpanded: true,
                            onTap: onCollapse,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 78,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SizedBox(
                                    height: 22,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _RequestVehicleLine(
                                        label: 'Marke',
                                        value: _brand,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 22,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _RequestVehicleLine(
                                        label: 'Modell',
                                        value: _model,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 22,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _RequestVehicleLine(
                                        label: 'Farbe',
                                        value: _color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _CompactReasonBadge(
                                icon: _requestReasonIcon,
                                label: _requestReasonTitle,
                              ),
                              const SizedBox(height: 6),
                              Transform.translate(
                                offset: const Offset(0, 1),
                                child: _CompactRequestPlate(
                                  countryCode: _countryCode,
                                  region: plateSegments.region,
                                  letters: plateSegments.letters,
                                  numbers: plateSegments.numbers,
                                  regionPresentation: regionPresentation,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RequestInfoPanel(
              icon: Icons.chat_bubble_outline_rounded,
              title: null,
              subtitle: _requestMessage,
              maxSubtitleLines: 3,
            ),
            const SizedBox(height: 12),
            if (canActOnRequest)
              isIncoming
                  ? Row(
                      children: [
                        Expanded(
                          child: _InlineRequestButton(
                            label: 'Annehmen',
                            icon: Icons.check_rounded,
                            isBusy: isBusy,
                            isPrimary: true,
                            borderColor: CaRismaDesignTokens.success.withValues(
                              alpha: 0.62,
                            ),
                            onPressed: onAccept,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InlineRequestButton(
                            label: 'Ablehnen',
                            icon: Icons.close_rounded,
                            isBusy: isBusy,
                            isPrimary: false,
                            borderColor: CaRismaDesignTokens.danger.withValues(
                              alpha: 0.62,
                            ),
                            onPressed: onDecline,
                          ),
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: double.infinity,
                        child: _InlineRequestButton(
                          label: 'Zurückziehen',
                          icon: Icons.undo_rounded,
                          isBusy: isBusy,
                          isPrimary: false,
                          borderColor: CaRismaDesignTokens.danger.withValues(
                            alpha: 0.62,
                          ),
                          onPressed: onWithdraw,
                        ),
                      ),
                    )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final canOpenChat =
                      request.isAccepted && request.hasLinkedChat;
                  final useColumn = canOpenChat && constraints.maxWidth < 270;
                  final status = _InlineRequestStatusPill(
                    label: statusLabel,
                    icon: Icons.info_outline_rounded,
                  );

                  if (!canOpenChat) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: status,
                    );
                  }

                  final openChatButton = _InlineRequestButton(
                    label: 'Chat öffnen',
                    icon: Icons.forum_rounded,
                    isBusy: isBusy,
                    isPrimary: true,
                    onPressed: onAccept,
                  );

                  if (useColumn) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(alignment: Alignment.centerLeft, child: status),
                        const SizedBox(height: 8),
                        openChatButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Flexible(child: status),
                      const SizedBox(width: 10),
                      Expanded(child: openChatButton),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openRequestProfile(BuildContext context) {
    final targetUserId = _profileTargetUserId;

    if (targetUserId.isEmpty || targetUserId.startsWith('local-test-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dieses Testprofil ist nur lokal sichtbar.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      buildSocialProfileRoute(profileUserId: targetUserId, readOnly: true),
    );
  }
}

class _RequestVehicleLine extends StatelessWidget {
  const _RequestVehicleLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            '$label:',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: CaRismaDesignTokens.textSecondary.withValues(alpha: 0.66),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.92),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileViewBadge extends StatelessWidget {
  const _ProfileViewBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: CaRismaDesignTokens.controlSurface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.42),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_search_outlined,
              size: 14,
              color: CaRismaDesignTokens.bluePrimary,
            ),
            const SizedBox(height: 2),
            Text(
              'Profil\nansehen',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.90),
                fontWeight: FontWeight.w900,
                fontSize: 9.5,
                height: 1.02,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestExpiryBadge extends StatelessWidget {
  const _RequestExpiryBadge({required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final remaining = expiresAt.difference(DateTime.now());
    final isExpired = remaining.isNegative;
    final hoursLeft = isExpired ? 0 : (remaining.inMinutes / 60).ceil();
    final isUrgent = !isExpired && hoursLeft <= 5;
    final color = CaRismaDesignTokens.textSecondary.withValues(alpha: 0.86);

    return Container(
      width: 116,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color:
              (isUrgent || isExpired
                      ? CaRismaDesignTokens.danger
                      : Colors.white)
                  .withValues(alpha: isUrgent || isExpired ? 0.42 : 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isExpired ? 'Abgelaufen' : 'Noch $hoursLeft Std.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactReasonBadge extends StatelessWidget {
  const _CompactReasonBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: CaRismaDesignTokens.controlSurface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.38),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: CaRismaDesignTokens.bluePrimary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactRequestPlate extends StatelessWidget {
  const _CompactRequestPlate({
    required this.countryCode,
    required this.region,
    required this.letters,
    required this.numbers,
    required this.regionPresentation,
  });

  final String countryCode;
  final String region;
  final String letters;
  final String numbers;
  final RegistrationRegionPresentationData regionPresentation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 36,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 300,
          height: 78,
          child: CaRismaLicensePlatePreview(
            countryCode: countryCode,
            region: region,
            letters: letters,
            numbers: numbers,
            regionPresentation: regionPresentation,
          ),
        ),
      ),
    );
  }
}

class _RequestInfoPanel extends StatelessWidget {
  const _RequestInfoPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.maxSubtitleLines = 2,
  });

  final IconData icon;
  final String? title;
  final String subtitle;
  final int maxSubtitleLines;

  @override
  Widget build(BuildContext context) {
    final title = this.title?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(icon, size: 18, color: CaRismaDesignTokens.bluePrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title.isNotEmpty) ...[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: CaRismaDesignTokens.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  subtitle,
                  maxLines: maxSubtitleLines,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CaRismaDesignTokens.textSecondary.withValues(
                      alpha: title == null || title.isEmpty ? 0.92 : 0.84,
                    ),
                    fontWeight: title == null || title.isEmpty
                        ? FontWeight.w800
                        : FontWeight.w700,
                    height: 1.22,
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

class _InlineRequestStatusPill extends StatelessWidget {
  const _InlineRequestStatusPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(
          color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: CaRismaDesignTokens.blueBright.withValues(alpha: 0.9),
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CaRismaDesignTokens.textSecondary.withValues(
                  alpha: 0.86,
                ),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineRequestButton extends StatelessWidget {
  const _InlineRequestButton({
    required this.label,
    required this.icon,
    required this.isBusy,
    required this.isPrimary,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final bool isBusy;
  final bool isPrimary;
  final VoidCallback onPressed;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBusy)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, size: 17),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final resolvedBorderColor =
        borderColor ??
        (isPrimary
            ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.62)
            : Colors.white.withValues(alpha: 0.16));
    final foregroundColor = isPrimary
        ? CaRismaDesignTokens.textPrimary
        : CaRismaDesignTokens.textSecondary.withValues(alpha: 0.9);

    return OutlinedButton(
      onPressed: isBusy ? null : onPressed,
      style:
          OutlinedButton.styleFrom(
            backgroundColor: CaRismaDesignTokens.controlSurface,
            foregroundColor: foregroundColor,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.42),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: shape,
            side: BorderSide(color: resolvedBorderColor),
          ).copyWith(
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            shadowColor: WidgetStateProperty.all(Colors.transparent),
          ),
      child: child,
    );
  }
}
