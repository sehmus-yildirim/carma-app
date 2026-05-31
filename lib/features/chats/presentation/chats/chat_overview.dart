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
          CarmaBlueIconBox(
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
                  'Chats nicht verf\u00FCgbar',
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
    return GlassCard(
      padding: const EdgeInsets.all(10),
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
          const SizedBox(width: 10),
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
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _myMessageBlueDark,
                      _myMessageBlue,
                      _myMessageBlueLight,
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _carmaBlue.withValues(alpha: 0.26),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                    letterSpacing: -0.1,
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

class _ChatSearchField extends StatelessWidget {
  const _ChatSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Suchen',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.48),
          fontWeight: FontWeight.w800,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: Colors.white.withValues(alpha: 0.58),
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) {
              return const SizedBox.shrink();
            }

            return IconButton(
              onPressed: controller.clear,
              icon: const Icon(Icons.close_rounded),
              color: Colors.white70,
              tooltip: 'Suche löschen',
            );
          },
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ChatsOverview extends StatelessWidget {
  const _ChatsOverview({
    required this.chats,
    required this.archivedChats,
    required this.blockedChats,
    required this.stories,
    required this.isAddingOwnStory,
    required this.isLoading,
    required this.hasLocalActiveChat,
    required this.localMessages,
    required this.searchQuery,
    required this.selectedListView,
    required this.matchesChat,
    required this.onListViewChanged,
    required this.onHorizontalSwipe,
    required this.onOpenChat,
    required this.onOpenLocalChat,
    required this.onAddOwnStory,
    required this.onOpenStory,
  });

  final List<ChatRecord> chats;
  final List<ChatRecord> archivedChats;
  final List<ChatRecord> blockedChats;
  final List<ChatStoryRecord> stories;
  final bool isAddingOwnStory;
  final bool isLoading;
  final bool hasLocalActiveChat;
  final List<_LocalChatMessage> localMessages;
  final String searchQuery;
  final _ChatListView selectedListView;
  final bool Function(ChatRecord chat) matchesChat;
  final ValueChanged<_ChatListView> onListViewChanged;
  final GestureDragEndCallback onHorizontalSwipe;
  final ValueChanged<ChatRecord> onOpenChat;
  final VoidCallback onOpenLocalChat;
  final ValueChanged<List<ChatRecord>> onAddOwnStory;
  final void Function(ChatStoryRecord story, List<ChatStoryRecord> stories)
  onOpenStory;

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final visibleChats = chats.where(matchesChat).toList();
    final visibleArchivedChats = archivedChats.where(matchesChat).toList();
    final visibleBlockedChats = blockedChats.where(matchesChat).toList();
    final hasSearchQuery = searchQuery.trim().isNotEmpty;
    final isArchivedView = selectedListView == _ChatListView.archived;
    final isBlockedView = selectedListView == _ChatListView.blocked;
    final selectedChats = switch (selectedListView) {
      _ChatListView.messages => visibleChats,
      _ChatListView.archived => visibleArchivedChats,
      _ChatListView.blocked => visibleBlockedChats,
    };
    final showLocalChat =
        selectedListView == _ChatListView.messages &&
        hasLocalActiveChat &&
        (searchQuery.trim().isEmpty ||
            'carma nutzer bmw 1er schwarz ${localMessages.map((message) => message.text).join(' ')}'
                .toLowerCase()
                .contains(searchQuery.trim().toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isKeyboardOpen) ...[
          _ChatStoriesStrip(
            chats: visibleChats,
            stories: stories,
            isAddingOwnStory: isAddingOwnStory,
            onAddOwnStory: () => onAddOwnStory([
              ...chats,
              ...archivedChats,
            ]),
            onOpenStory: onOpenStory,
          ),
          const SizedBox(height: 16),
        ],
        _InlineTextTabs<_ChatListView>(
          selectedValue: selectedListView,
          isCompact: isKeyboardOpen,
          items: const [
            _InlineTextTabItem(
              value: _ChatListView.messages,
              label: 'Nachrichten',
            ),
            _InlineTextTabItem(
              value: _ChatListView.archived,
              label: 'Archiviert',
            ),
            _InlineTextTabItem(
              value: _ChatListView.blocked,
              label: 'Blockiert',
            ),
          ],
          onChanged: onListViewChanged,
        ),
        SizedBox(height: isKeyboardOpen ? 6 : 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: onHorizontalSwipe,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLoading)
                    const _InlineLoadingRow(label: 'Chats werden geladen...')
                  else if (selectedChats.isEmpty && !showLocalChat)
                    _EmptyListCard(
                      icon: isBlockedView
                          ? Icons.block_rounded
                          : isArchivedView
                          ? Icons.archive_outlined
                          : Icons.chat_bubble_outline_rounded,
                      title: hasSearchQuery
                          ? 'Keine Treffer'
                          : isBlockedView
                          ? 'Keine blockierten Chats'
                          : isArchivedView
                          ? 'Keine archivierten Chats'
                          : 'Keine Chats',
                    )
                  else
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: onHorizontalSwipe,
                      child: Column(
                        children: [
                          for (final chat in selectedChats) ...[
                            _ActiveChatListTile(
                              title: chat.displayNameFor(currentUserId),
                              imageUrl: chat.profilePhotoUrlFor(currentUserId),
                              subtitle:
                                  chat.lastMessage?.trim().isNotEmpty == true
                                  ? chat.lastMessage!.trim()
                                  : chat.vehicleTitle,
                              isFavorite: chat.isFavoriteFor(currentUserId),
                              isPinned: chat.isPinnedFor(currentUserId),
                              isMuted: chat.isMutedFor(currentUserId),
                              isUnread: chat.hasUnreadFor(currentUserId),
                              trailing: _ChatOverflowMenu(
                                chatId: chat.id,
                                title: chat.displayNameFor(currentUserId),
                                subtitle:
                                    '${chat.vehicleModelLabel} - ${_formatChatPlateLabel(chat.displayPlate)}',
                                isFavorite: chat.isFavoriteFor(currentUserId),
                                isPinned: chat.isPinnedFor(currentUserId),
                                isMuted: chat.isMutedFor(currentUserId),
                                isUnread: chat.hasUnreadFor(currentUserId),
                                isBlocked: isBlockedView,
                                isArchived: isArchivedView,
                                popAfterStatusAction: false,
                              ),
                              onTap: isBlockedView
                                  ? () {}
                                  : () => onOpenChat(chat),
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (showLocalChat)
                            _ActiveChatListTile(
                              title: 'Carma Nutzer',
                              subtitle: localMessages.isNotEmpty
                                  ? localMessages.last.text
                                  : 'BMW 1er',
                              trailing: const _ChatOverflowMenu(
                                title: 'Carma Nutzer',
                                subtitle: 'BMW 1er - HH-HY 4747',
                                popAfterStatusAction: false,
                              ),
                              onTap: onOpenLocalChat,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestsOverview extends StatelessWidget {
  const _RequestsOverview({
    required this.incomingStream,
    required this.outgoingStream,
    required this.busyRequestIds,
    required this.searchQuery,
    required this.selectedListView,
    required this.matchesRequest,
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
  final String searchQuery;
  final _RequestListView selectedListView;
  final bool Function(ContactRequestRecord request) matchesRequest;
  final ValueChanged<_RequestListView> onListViewChanged;
  final GestureDragEndCallback onHorizontalSwipe;
  final ValueChanged<ContactRequestRecord> onAccept;
  final ValueChanged<ContactRequestRecord> onDecline;
  final ValueChanged<ContactRequestRecord> onWithdraw;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContactRequestRecord>>(
      stream: incomingStream,
      builder: (context, incomingSnapshot) {
        return StreamBuilder<List<ContactRequestRecord>>(
          stream: outgoingStream,
          builder: (context, outgoingSnapshot) {
            final incoming =
                (incomingSnapshot.data ?? const <ContactRequestRecord>[])
                    .where(matchesRequest)
                    .toList();
            final outgoing =
                (outgoingSnapshot.data ?? const <ContactRequestRecord>[])
                    .where(matchesRequest)
                    .toList();
            final isLoading =
                incomingSnapshot.connectionState == ConnectionState.waiting ||
                outgoingSnapshot.connectionState == ConnectionState.waiting;
            final error = incomingSnapshot.error ?? outgoingSnapshot.error;

            if (error != null) {
              return _InlineErrorCard(message: error.toString());
            }

            final isIncomingView =
                selectedListView == _RequestListView.incoming;
            final selectedRequests = isIncomingView ? incoming : outgoing;
            final hasSearchQuery = searchQuery.trim().isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InlineTextTabs<_RequestListView>(
                  selectedValue: selectedListView,
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
                  onChanged: onListViewChanged,
                ),
                SizedBox(
                  height: MediaQuery.of(context).viewInsets.bottom > 0 ? 6 : 12,
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: onHorizontalSwipe,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topLeft,
                          children: [...previousChildren, ?currentChild],
                        );
                      },
                      child: SingleChildScrollView(
                        key: ValueKey(selectedListView),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: isLoading
                            ? const _InlineLoadingRow(
                                label: 'Anfragen werden geladen...',
                              )
                            : selectedRequests.isEmpty
                            ? _EmptyListCard(
                                icon: isIncomingView
                                    ? Icons.mark_email_unread_outlined
                                    : Icons.schedule_send_outlined,
                                title: hasSearchQuery
                                    ? 'Keine Treffer'
                                    : isIncomingView
                                    ? 'Keine eingehenden Anfragen'
                                    : 'Keine gesendeten Anfragen',
                              )
                            : _InlineRequestList(
                                requests: selectedRequests,
                                isIncoming: isIncomingView,
                                busyRequestIds: busyRequestIds,
                                onAccept: onAccept,
                                onDecline: onDecline,
                                onWithdraw: onWithdraw,
                              ),
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
    return Row(
      children: [
        for (final item in items) ...[
          _InlineTextTab<T>(
            item: item,
            isSelected: item.value == selectedValue,
            isCompact: isCompact,
            onTap: () => onChanged(item.value),
          ),
          if (item != items.last) SizedBox(width: isCompact ? 18 : 22),
        ],
      ],
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isCompact ? 2 : 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: isCompact ? 16 : 18,
                  ),
                ),
                if (item.count != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    height: isCompact ? 21 : 24,
                    constraints: BoxConstraints(
                      minWidth: isCompact ? 21 : 24,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _carmaBlue.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? _carmaBlueLight.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      '${item.count}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: isCompact ? 3 : 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: isSelected ? (isCompact ? 24 : 28) : 0,
              height: isCompact ? 2.5 : 3,
              decoration: BoxDecoration(
                color: _carmaBlueLight,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatStoriesStrip extends StatelessWidget {
  const _ChatStoriesStrip({
    required this.chats,
    required this.stories,
    required this.isAddingOwnStory,
    required this.onAddOwnStory,
    required this.onOpenStory,
  });

  final List<ChatRecord> chats;
  final List<ChatStoryRecord> stories;
  final bool isAddingOwnStory;
  final VoidCallback onAddOwnStory;
  final void Function(ChatStoryRecord story, List<ChatStoryRecord> stories)
  onOpenStory;

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final visibleOwnerIds = <String>{
      for (final chat in chats)
        for (final participant in chat.participants)
          if (participant.trim().isNotEmpty) participant.trim(),
    };
    ChatStoryRecord? ownStory;

    for (final story in stories) {
      if (story.ownerUserId == currentUserId) {
        ownStory = story;
        break;
      }
    }

    final otherStories =
        stories
            .where(
              (story) =>
                  story.ownerUserId != currentUserId &&
                  visibleOwnerIds.contains(story.ownerUserId),
            )
            .toList()
          ..sort((a, b) {
            final aViewed = a.viewedAtBy.containsKey(currentUserId);
            final bViewed = b.viewedAtBy.containsKey(currentUserId);

            if (aViewed != bViewed) {
              return aViewed ? 1 : -1;
            }

            return b.createdAt.compareTo(a.createdAt);
          });
    final visibleStories = otherStories.take(12).toList();

    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visibleStories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            final currentOwnStory = ownStory;

            return _StoryBubble(
              label: 'Deine Story',
              imageUrl: currentOwnStory?.imageUrl,
              isVideo: currentOwnStory?.isVideo ?? false,
              isOwnStory: true,
              hasStory: currentOwnStory != null,
              isViewed: true,
              isBusy: isAddingOwnStory,
              onTap: isAddingOwnStory
                  ? () {}
                  : currentOwnStory == null
                  ? onAddOwnStory
                  : () => onOpenStory(
                      currentOwnStory,
                      <ChatStoryRecord>[currentOwnStory],
                    ),
              onAddTap: isAddingOwnStory ? null : onAddOwnStory,
            );
          }

          final story = visibleStories[index - 1];
          final storyImageUrl = story.ownerPhotoUrl?.trim().isNotEmpty == true
              ? story.ownerPhotoUrl
              : story.imageUrl;
          return _StoryBubble(
            label: story.ownerDisplayName,
            imageUrl: storyImageUrl,
            isVideo: story.isVideo,
            hasStory: true,
            isViewed: story.viewedAtBy.containsKey(currentUserId),
            onTap: () => onOpenStory(story, visibleStories),
          );
        },
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.label,
    this.imageUrl,
    this.isVideo = false,
    this.isOwnStory = false,
    this.hasStory = false,
    this.isViewed = false,
    this.isBusy = false,
    required this.onTap,
    this.onAddTap,
  });

  final String label;
  final String? imageUrl;
  final bool isVideo;
  final bool isOwnStory;
  final bool hasStory;
  final bool isViewed;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasStory && (!isViewed || isOwnStory)
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_carmaBlueDark, _carmaBlueLight],
                          )
                        : null,
                    color: hasStory && isViewed
                        ? Colors.white.withValues(alpha: 0.20)
                        : hasStory
                        ? null
                        : Colors.white.withValues(alpha: 0.10),
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
                        ? Image.network(
                            imageUrl!.trim(),
                            width: 62,
                            height: 62,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _AvatarCircle(
                              size: 62,
                              imageUrl: null,
                              iconSize: 34,
                            ),
                          )
                        : hasStory && isVideo
                        ? const _StoryVideoBubblePlaceholder()
                        : _AvatarCircle(
                            size: 62,
                            imageUrl: imageUrl,
                            iconSize: 34,
                          ),
                  ),
                ),
                if (isOwnStory)
                  Positioned(
                    right: -2,
                    bottom: -1,
                    child: GestureDetector(
                      onTap: onAddTap,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _carmaBlue,
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
                if (hasStory && !isViewed && !isOwnStory)
                  Positioned(
                    right: -3,
                    top: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _carmaBlueLight,
                        border: Border.all(
                          color: const Color(0xFF101827),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _carmaBlueLight.withValues(alpha: 0.45),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (hasStory && isVideo)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.58),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.72),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
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
              ),
            ),
          ],
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
            _carmaBlueDark.withValues(alpha: 0.86),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.videocam_rounded,
          color: Colors.white,
          size: 32,
        ),
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

class _InlineRequestList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final request in requests) ...[
          _InlineRequestTile(
            request: request,
            isIncoming: isIncoming,
            isBusy: busyRequestIds.contains(request.id),
            onAccept: () => onAccept(request),
            onDecline: () => onDecline(request),
            onWithdraw: () => onWithdraw(request),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _InlineRequestTile extends StatelessWidget {
  const _InlineRequestTile({
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

  String get _plate {
    final plate = request.displayPlate?.trim();
    final rawPlate = plate == null || plate.isEmpty ? request.plateKey : plate;
    return _formatPlate(rawPlate);
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

  static String _formatPlate(String value) {
    final normalized = value.trim().toUpperCase();

    if (normalized.isEmpty) {
      return '-';
    }

    if (normalized.contains('-') || normalized.contains(' ')) {
      return normalized.replaceAll(RegExp(r'\s+'), ' ');
    }

    final match = RegExp(
      r'^([A-ZÄÖÜ]{2,4})([0-9]{1,4})$',
    ).firstMatch(normalized);

    if (match == null) {
      return normalized;
    }

    final letters = match.group(1)!;
    final numbers = match.group(2)!;
    final regionLength = letters.length >= 4 ? 2 : 1;
    final region = letters.substring(0, regionLength);
    final serial = letters.substring(regionLength);

    if (serial.isEmpty) {
      return '$region $numbers';
    }

    return '$region-$serial $numbers';
  }

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = request.profilePhotoUrl(isIncoming: isIncoming);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          _UserAvatarPlaceholder(size: 46, imageUrl: profilePhotoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _color,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _plate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (isIncoming) ...[
                  const SizedBox(height: 8),
                  Text(
                    _incomingMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                isIncoming
                    ? Row(
                        children: [
                          Expanded(
                            child: _InlineRequestButton(
                              label: 'Annehmen',
                              icon: Icons.check_rounded,
                              isBusy: isBusy,
                              isPrimary: true,
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
                              onPressed: onDecline,
                            ),
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.centerRight,
                        child: _InlineRequestButton(
                          label: 'Zurückziehen',
                          icon: Icons.undo_rounded,
                          isBusy: isBusy,
                          isPrimary: false,
                          onPressed: onWithdraw,
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

class _InlineRequestButton extends StatelessWidget {
  const _InlineRequestButton({
    required this.label,
    required this.icon,
    required this.isBusy,
    required this.isPrimary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isBusy;
  final bool isPrimary;
  final VoidCallback onPressed;

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
          Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    if (isPrimary) {
      return FilledButton(
        onPressed: isBusy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _carmaBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _carmaBlue.withValues(alpha: 0.32),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.62),
          minimumSize: const Size(0, 44),
          shape: shape,
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: isBusy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.42),
        minimumSize: const Size(0, 44),
        shape: shape,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: child,
    );
  }
}
