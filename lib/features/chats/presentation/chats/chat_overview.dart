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
            color: Colors.white.withValues(alpha: 0.02),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1260E8),
                      Color(0xFF1E7BFF),
                      Color(0xFF28A8FF),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _carismaBlue.withValues(alpha: 0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
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
                    ? Colors.white
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

class _ChatSearchField extends StatelessWidget {
  const _ChatSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: CaRismaDesignTokens.textPrimary,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            hintText: 'Suchen',
            hintStyle: TextStyle(
              color: CaRismaDesignTokens.textMuted,
              fontWeight: FontWeight.w900,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: CaRismaDesignTokens.textSecondary.withValues(alpha: 0.74),
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
                  color: CaRismaDesignTokens.textSecondary,
                  tooltip: 'Suche löschen',
                );
              },
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.02),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              borderSide: BorderSide(
                color: CaRismaDesignTokens.blueBright.withValues(alpha: 0.8),
                width: 1.6,
              ),
            ),
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
    required this.blockedChats,
    required this.stories,
    required this.currentUserPhotoUrl,
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
  final String currentUserPhotoUrl;
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
            'carisma nutzer bmw 1er schwarz ${localMessages.map((message) => message.text).join(' ')}'
                .toLowerCase()
                .contains(searchQuery.trim().toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isKeyboardOpen) ...[
          _ChatStoriesStrip(
            chats: [...visibleChats, ...visibleArchivedChats],
            stories: stories,
            currentUserPhotoUrl: currentUserPhotoUrl,
            isAddingOwnStory: isAddingOwnStory,
            onAddOwnStory: () => onAddOwnStory([...chats, ...archivedChats]),
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
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: onHorizontalSwipe,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final chat in selectedChats) ...[
                      _ActiveChatListTile(
                        title: chat.displayNameFor(currentUserId),
                        imageUrl: chat.profilePhotoUrlFor(currentUserId),
                        subtitle: chat.lastMessage?.trim().isNotEmpty == true
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
                          vehicleLabel: chat.vehicleModelLabel,
                          plateLabel: _formatChatPlateLabel(chat.displayPlate),
                          isFavorite: chat.isFavoriteFor(currentUserId),
                          isPinned: chat.isPinnedFor(currentUserId),
                          isMuted: chat.isMutedFor(currentUserId),
                          isUnread: chat.hasUnreadFor(currentUserId),
                          isBlocked: isBlockedView,
                          isArchived: isArchivedView,
                          popAfterStatusAction: false,
                        ),
                        onTap: isBlockedView ? () {} : () => onOpenChat(chat),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (showLocalChat) ...[
                      _ActiveChatListTile(
                        title: 'CaRisma Nutzer',
                        subtitle: localMessages.isNotEmpty
                            ? localMessages.last.text
                            : 'BMW 1er',
                        trailing: const _ChatOverflowMenu(
                          title: 'CaRisma Nutzer',
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
                ),
            ],
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
              mainAxisSize: MainAxisSize.min,
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
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: onHorizontalSwipe,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      key: ValueKey(selectedListView),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(isCompact ? 5 : 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withValues(alpha: 0.015),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 4 : 6,
            vertical: isCompact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            gradient: isSelected ? CaRismaDesignTokens.blueGradient : null,
            color: isSelected
                ? null
                : Colors.white.withValues(alpha: isCompact ? 0.02 : 0.03),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.transparent,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _carismaBlue.withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
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
                    Container(
                      height: isCompact ? 21 : 24,
                      constraints: BoxConstraints(
                        minWidth: isCompact ? 21 : 24,
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.24)
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

class _ChatStoriesStrip extends StatelessWidget {
  const _ChatStoriesStrip({
    required this.chats,
    required this.stories,
    required this.currentUserPhotoUrl,
    required this.isAddingOwnStory,
    required this.onAddOwnStory,
    required this.onOpenStory,
  });

  final List<ChatRecord> chats;
  final List<ChatStoryRecord> stories;
  final String currentUserPhotoUrl;
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
    ChatStoryRecord? ownStory;

    for (final story in stories) {
      if (story.ownerUserId.trim() != trimmedCurrentUserId ||
          story.isExpired ||
          !story.hasRenderableMedia) {
        continue;
      }

      if (ownStory == null || story.createdAt.isAfter(ownStory.createdAt)) {
        ownStory = story;
      }
    }

    final otherStories =
        stories
            .where(
              (story) =>
                  story.ownerUserId.trim() != trimmedCurrentUserId &&
                  !story.isExpired &&
                  story.hasRenderableMedia &&
                  visibleOwnerIds.contains(story.ownerUserId.trim()),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 128,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: 0.015),
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
            itemCount: visibleStories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                final currentOwnStory = ownStory;
                final ownBubbleImageUrl = ownProfilePhotoUrl?.isNotEmpty == true
                    ? ownProfilePhotoUrl
                    : currentOwnStory?.imageUrl;
                final ownStoryViewCount =
                    currentOwnStory?.viewedAtBy.keys
                        .where(
                          (viewerId) =>
                              viewerId.trim() !=
                              currentOwnStory.ownerUserId.trim(),
                        )
                        .length ??
                    0;

                return _StoryBubble(
                  label: 'Deine Story',
                  imageUrl: ownBubbleImageUrl,
                  isVideo: currentOwnStory?.isVideo ?? false,
                  isOwnStory: true,
                  hasStory: currentOwnStory != null,
                  isViewed: true,
                  createdAt: currentOwnStory?.createdAt,
                  expiresAt: currentOwnStory?.expiresAt,
                  viewCount: ownStoryViewCount,
                  isBusy: isAddingOwnStory,
                  onTap: isAddingOwnStory
                      ? () {}
                      : currentOwnStory == null
                      ? onAddOwnStory
                      : () => onOpenStory(currentOwnStory, <ChatStoryRecord>[
                          currentOwnStory,
                        ]),
                  onAddTap: isAddingOwnStory ? null : onAddOwnStory,
                );
              }

              final story = visibleStories[index - 1];
              final storyImageUrl =
                  story.ownerPhotoUrl?.trim().isNotEmpty == true
                  ? story.ownerPhotoUrl
                  : story.imageUrl;
              return _StoryBubble(
                label: story.ownerDisplayName,
                imageUrl: storyImageUrl,
                isVideo: story.isVideo,
                hasStory: true,
                isViewed: story.viewedAtBy.keys.any(
                  (viewerId) => viewerId.trim() == trimmedCurrentUserId,
                ),
                createdAt: story.createdAt,
                expiresAt: story.expiresAt,
                onTap: () => onOpenStory(story, visibleStories),
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
    this.imageUrl,
    this.isVideo = false,
    this.isOwnStory = false,
    this.hasStory = false,
    this.isViewed = false,
    this.createdAt,
    this.expiresAt,
    this.viewCount = 0,
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
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final int viewCount;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    final viewCountLabel = viewCount > 99 ? '99+' : '$viewCount';
    final isNewStory = hasStory && !isViewed && !isOwnStory;
    final ageLabel = _storyBubbleAgeLabel(createdAt);
    final remainingLabel = _storyBubbleRemainingLabel(expiresAt);
    final statusLabel = isOwnStory
        ? isBusy
              ? 'Lädt'
              : hasStory
              ? remainingLabel == null
                    ? 'Aktiv'
                    : 'Noch $remainingLabel'
              : 'Hinzufügen'
        : isNewStory
        ? ageLabel == null
              ? 'Neu'
              : 'Neu · $ageLabel'
        : ageLabel ?? 'Gesehen';
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

    return SizedBox(
      width: 84,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 68,
                  height: 68,
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
                              color: _carismaBlueLight.withValues(alpha: 0.26),
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
                        ? Image.network(
                            imageUrl!.trim(),
                            width: 63,
                            height: 63,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => isVideo
                                ? const _StoryVideoBubblePlaceholder()
                                : _AvatarCircle(
                                    size: 63,
                                    imageUrl: null,
                                    iconSize: 34,
                                    fallbackLabel: label,
                                  ),
                          )
                        : hasStory && isVideo
                        ? const _StoryVideoBubblePlaceholder()
                        : _AvatarCircle(
                            size: 63,
                            imageUrl: imageUrl,
                            iconSize: 34,
                            fallbackLabel: label,
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
                if (hasStory && isVideo)
                  Positioned(
                    left: isOwnStory ? 1 : null,
                    right: isOwnStory ? null : 1,
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
                        color: const Color(0xFF101827).withValues(alpha: 0.92),
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
            const SizedBox(height: 2),
            Text(
              statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isNewStory
                    ? _carismaBlueLight
                    : Colors.white.withValues(alpha: 0.58),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _storyBubbleAgeLabel(DateTime? createdAt) {
  if (createdAt == null) {
    return null;
  }

  final difference = DateTime.now().difference(createdAt);

  if (difference.isNegative || difference.inMinutes < 1) {
    return 'Jetzt';
  }

  if (difference.inHours < 1) {
    return '${difference.inMinutes}m';
  }

  if (difference.inDays < 1) {
    return '${difference.inHours}h';
  }

  return '${difference.inDays}T';
}

String? _storyBubbleRemainingLabel(DateTime? expiresAt) {
  if (expiresAt == null) {
    return null;
  }

  final difference = expiresAt.difference(DateTime.now());

  if (difference.isNegative) {
    return null;
  }

  if (difference.inHours >= 1) {
    return '${difference.inHours}h';
  }

  if (difference.inMinutes >= 1) {
    return '${difference.inMinutes}m';
  }

  return '<1m';
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
          _InlineRequestTile(
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
    final canActOnRequest = request.isPending;
    final statusLabel = request.isAccepted && !request.hasLinkedChat
        ? 'Angenommen'
        : request.statusLabel;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.02),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UserAvatarPlaceholder(size: 50, imageUrl: profilePhotoUrl),
                const SizedBox(width: 14),
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
                                    color: CaRismaDesignTokens.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16.5,
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
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: CaRismaDesignTokens.textSecondary
                                        .withValues(alpha: 0.72),
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _color,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: CaRismaDesignTokens.textSecondary
                                        .withValues(alpha: 0.58),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _plate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: CaRismaDesignTokens.textPrimary
                                      .withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                      if (isIncoming) ...[
                        const SizedBox(height: 10),
                        Text(
                          _incomingMessage,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: CaRismaDesignTokens.textSecondary
                                    .withValues(alpha: 0.85),
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                        ),
                      ],
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
                              )
                      else
                        Row(
                          children: [
                            _InlineRequestStatusPill(
                              label: statusLabel,
                              icon: Icons.info_outline_rounded,
                            ),
                            if (request.isAccepted &&
                                request.hasLinkedChat) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: _InlineRequestButton(
                                  label: 'Chat öffnen',
                                  icon: Icons.forum_rounded,
                                  isBusy: isBusy,
                                  isPrimary: true,
                                  onPressed: onAccept,
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
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
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CaRismaDesignTokens.textSecondary.withValues(alpha: 0.86),
              fontWeight: FontWeight.w800,
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
          backgroundColor: _carismaBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _carismaBlue.withValues(alpha: 0.32),
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
