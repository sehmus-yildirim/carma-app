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
                      subtitle:
                          '${chat.vehicleModelLabel} - ${_formatChatPlateLabel(chat.displayPlate)}',
                      vehicleLabel: chat.vehicleModelLabel,
                      plateLabel: _formatChatPlateLabel(chat.displayPlate),
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
                            displayPlate: chat.displayPlate,
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
                  title: 'CaRisma Nutzer',
                  subtitle: messages.isNotEmpty
                      ? 'Letzte Nachricht: ${messages.last.text}'
                      : 'BMW 1er',
                  trailing: const _ChatOverflowMenu(
                    title: 'CaRisma Nutzer',
                    subtitle: 'BMW 1er - HH-HY 4747',
                    vehicleLabel: 'BMW 1er',
                    plateLabel: 'HH-HY 4747',
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

    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 18, 20, 112 + keyboardInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CaRismaSubPageHeader(
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isUnread
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.02),
              border: Border.all(
                color: isUnread
                    ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.06),
                width: isUnread ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.015),
                  blurRadius: 10,
                  offset: const Offset(-4, -4),
                ),
                if (isUnread)
                  BoxShadow(
                    color: CaRismaDesignTokens.bluePrimary.withValues(
                      alpha: 0.12,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(18),
                        child: Row(
                          children: [
                            _UserAvatarPlaceholder(
                              size: 50,
                              imageUrl: imageUrl,
                            ),
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: CaRismaDesignTokens
                                                    .textPrimary,
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
                                  const SizedBox(height: 5),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: CaRismaDesignTokens
                                              .textSecondary
                                              .withValues(alpha: 0.78),
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 6),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.02),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: CaRismaDesignTokens.blueGradient,
                  boxShadow: [
                    BoxShadow(
                      color: _carismaBlue.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: CaRismaDesignTokens.textSecondary.withValues(
                      alpha: 0.82,
                    ),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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

class _UserAvatarPlaceholder extends StatelessWidget {
  const _UserAvatarPlaceholder({required this.size, this.imageUrl});

  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.30;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: CaRismaDesignTokens.surface2,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.60),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: _AvatarCircle(
          size: size,
          imageUrl: imageUrl,
          iconSize: size * 0.56,
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.size,
    required this.iconSize,
    this.imageUrl,
    this.fallbackLabel,
  });

  final double size;
  final double iconSize;
  final String? imageUrl;
  final String? fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    return SizedBox(
      width: size,
      height: size,
      child: hasImage
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _AvatarFallbackIcon(size: iconSize, label: fallbackLabel),
            )
          : _AvatarFallbackIcon(size: iconSize, label: fallbackLabel),
    );
  }
}

class _AvatarFallbackIcon extends StatelessWidget {
  const _AvatarFallbackIcon({required this.size, this.label});

  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final initials = _avatarInitialsFrom(label);

    return ColoredBox(
      color: Colors.transparent,
      child: Center(
        child: initials.isEmpty
            ? Icon(
                Icons.person_rounded,
                color: CaRismaDesignTokens.bluePrimary,
                size: size,
              )
            : Text(
                initials,
                maxLines: 1,
                style: TextStyle(
                  color: CaRismaDesignTokens.bluePrimary,
                  fontSize: size * 0.72,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
      ),
    );
  }
}

String _avatarInitialsFrom(String? value) {
  final words =
      value
          ?.trim()
          .split(RegExp(r'\s+'))
          .where((word) => word.trim().isNotEmpty)
          .toList() ??
      const <String>[];

  if (words.isEmpty) {
    return '';
  }

  return words.take(2).map((word) {
    final runes = word.runes;

    if (runes.isEmpty) {
      return '';
    }

    return String.fromCharCode(runes.first).toUpperCase();
  }).join();
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
