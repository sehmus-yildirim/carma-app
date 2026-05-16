part of '../chats_screen.dart';

// ignore: unused_element
class _ActiveChatsScreen extends StatelessWidget {
  const _ActiveChatsScreen({
    required this.chatStream,
    required this.initialChats,
    required this.hasLocalActiveChat,
    required this.messages,
  });

  final Stream<List<ChatRecord>> chatStream;
  final List<ChatRecord> initialChats;
  final bool hasLocalActiveChat;
  final List<_LocalChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatRecord>>(
      stream: chatStream,
      initialData: initialChats,
      builder: (context, snapshot) {
        final chats = snapshot.data ?? initialChats;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

        if (chats.isNotEmpty) {
          return _SubPageScaffold(
            icon: Icons.forum_rounded,
            headerTitle: 'Aktive Chats',
            child: Column(
              children: [
                for (final chat in chats) ...[
                  _ActiveChatListTile(
                    title: chat.displayNameFor(currentUserId),
                    imageUrl: chat.profilePhotoUrlFor(currentUserId),
                    subtitle: chat.lastMessage?.trim().isNotEmpty == true
                        ? 'Letzte Nachricht: ${chat.lastMessage!.trim()}'
                        : chat.vehicleTitle,
                    isFavorite: chat.isFavoriteFor(currentUserId),
                    isPinned: chat.isPinnedFor(currentUserId),
                    isMuted: chat.isMutedFor(currentUserId),
                    isUnread: chat.hasUnreadFor(currentUserId),
                    trailing: _ChatOverflowMenu(
                      chatId: chat.id,
                      title: chat.displayNameFor(currentUserId),
                      subtitle: chat.vehicleTitle,
                      isFavorite: chat.isFavoriteFor(currentUserId),
                      isPinned: chat.isPinnedFor(currentUserId),
                      isMuted: chat.isMutedFor(currentUserId),
                      isUnread: chat.hasUnreadFor(currentUserId),
                      popAfterStatusAction: false,
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _ChatConversationScreen(
                            chatId: chat.id,
                            initialMessages: const <_LocalChatMessage>[],
                            displayName: chat.displayNameFor(currentUserId),
                            profilePhotoUrl: chat.profilePhotoUrlFor(
                              currentUserId,
                            ),
                            vehicleModel: chat.vehicleModelLabel,
                            vehicleColor: chat.vehicleColorLabel,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        }

        return _SubPageScaffold(
          icon: Icons.forum_rounded,
          headerTitle: 'Aktive Chats',
          child: hasLocalActiveChat
              ? _ActiveChatListTile(
                  title: 'Carma Nutzer',
                  subtitle: messages.isNotEmpty
                      ? 'Letzte Nachricht: ${messages.last.text}'
                      : 'BMW 1er · Schwarz',
                  trailing: const _ChatOverflowMenu(
                    title: 'Carma Nutzer',
                    subtitle: 'BMW 1er · Schwarz',
                    popAfterStatusAction: false,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _ChatConversationScreen(initialMessages: messages),
                      ),
                    );
                  },
                )
              : const _EmptyListCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Noch keine aktiven Chats',
                ),
        );
      },
    );
  }
}

class _SubPageScaffold extends StatelessWidget {
  const _SubPageScaffold({
    required this.icon,
    required this.headerTitle,
    required this.child,
  });

  final IconData icon;
  final String headerTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 18, 20, 112 + keyboardInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CarmaSubPageHeader(
                  icon: icon,
                  title: headerTitle,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveChatListTile extends StatelessWidget {
  const _ActiveChatListTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.imageUrl,
    this.isFavorite = false,
    this.isPinned = false,
    this.isMuted = false,
    this.isUnread = false,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final bool isFavorite;
  final bool isPinned;
  final bool isMuted;
  final bool isUnread;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasStateIcons = isPinned || isFavorite || isMuted || isUnread;
    final stateIcons = <Widget>[
      if (isPinned)
        const _ChatStateIcon(
          icon: Icons.push_pin_rounded,
          tooltip: 'Angepinnt',
        ),
      if (isPinned && (isUnread || isFavorite || isMuted))
        const SizedBox(width: 6),
      if (isUnread)
        const _ChatStateIcon(
          icon: Icons.mark_chat_unread_rounded,
          tooltip: 'Ungelesen',
        ),
      if (isUnread && (isFavorite || isMuted)) const SizedBox(width: 6),
      if (isFavorite)
        const _ChatStateIcon(icon: Icons.star_rounded, tooltip: 'Favorit'),
      if (isFavorite && isMuted) const SizedBox(width: 6),
      if (isMuted)
        const _ChatStateIcon(
          icon: Icons.notifications_off_rounded,
          tooltip: 'Stummgeschaltet',
        ),
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          child: Row(
            children: [
              _UserAvatarPlaceholder(size: 48, imageUrl: imageUrl),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
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
                        if (hasStateIcons) ...[
                          const SizedBox(width: 8),
                          ...stateIcons,
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatStateIcon extends StatelessWidget {
  const _ChatStateIcon({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.09),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.84),
          size: 16,
        ),
      ),
    );
  }
}

class _EmptyListCard extends StatelessWidget {
  const _EmptyListCard({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.58),
              size: 20,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.62),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAvatarPlaceholder extends StatelessWidget {
  const _UserAvatarPlaceholder({required this.size, this.imageUrl});

  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_carmaBlueDark, _carmaBlueLight],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: _AvatarCircle(
        size: size,
        imageUrl: imageUrl,
        iconSize: size * 0.56,
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.size,
    required this.iconSize,
    this.imageUrl,
  });

  final double size;
  final double iconSize;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _AvatarFallbackIcon(size: iconSize),
              )
            : _AvatarFallbackIcon(size: iconSize),
      ),
    );
  }
}

class _AvatarFallbackIcon extends StatelessWidget {
  const _AvatarFallbackIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: Icon(Icons.person_rounded, color: Colors.white, size: size),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
