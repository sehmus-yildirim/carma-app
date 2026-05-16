part of '../chats_screen.dart';

class _ChatMessageList extends StatelessWidget {
  const _ChatMessageList({
    required this.messages,
    required this.playingAudioMessageKey,
    required this.onDeleteMessage,
    required this.onReplyMessage,
    required this.onStarMessage,
    required this.onReactMessage,
    required this.onOpenLocation,
    required this.onOpenDocument,
    required this.onToggleAudioMessage,
  });

  final List<_LocalChatMessage> messages;
  final String? playingAudioMessageKey;
  final ValueChanged<_LocalChatMessage> onDeleteMessage;

  final ValueChanged<_LocalChatMessage> onReplyMessage;
  final ValueChanged<_LocalChatMessage> onStarMessage;
  final void Function(_LocalChatMessage message, String reaction)
  onReactMessage;
  final ValueChanged<_LocationPayload> onOpenLocation;
  final ValueChanged<_LocalChatMessage> onOpenDocument;
  final ValueChanged<_LocalChatMessage> onToggleAudioMessage;

  String _audioMessageKey(_LocalChatMessage message) {
    final messageId = message.messageId?.trim();

    if (messageId != null && messageId.isNotEmpty) {
      return messageId;
    }

    return message.fileUrl?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: messages.map((message) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ChatMessageBubble(
            message: message,
            onDeleteMessage: onDeleteMessage,
            onReplyMessage: onReplyMessage,
            onStarMessage: onStarMessage,
            onReactMessage: onReactMessage,
            onOpenLocation: onOpenLocation,
            onOpenDocument: onOpenDocument,
            onToggleAudioMessage: onToggleAudioMessage,
            isAudioPlaying:
                playingAudioMessageKey != null &&
                playingAudioMessageKey == _audioMessageKey(message),
          ),
        );
      }).toList(),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.onDeleteMessage,
    required this.onReplyMessage,
    required this.onStarMessage,
    required this.onReactMessage,
    required this.onOpenLocation,
    required this.onOpenDocument,
    required this.onToggleAudioMessage,
    required this.isAudioPlaying,
  });

  final _LocalChatMessage message;
  final ValueChanged<_LocalChatMessage> onDeleteMessage;

  final ValueChanged<_LocalChatMessage> onReplyMessage;
  final ValueChanged<_LocalChatMessage> onStarMessage;
  final void Function(_LocalChatMessage message, String reaction)
  onReactMessage;
  final ValueChanged<_LocationPayload> onOpenLocation;
  final ValueChanged<_LocalChatMessage> onOpenDocument;
  final ValueChanged<_LocalChatMessage> onToggleAudioMessage;
  final bool isAudioPlaying;

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isNetworkImage(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Widget _buildRawImage(String imageUrl, {BoxFit fit = BoxFit.contain}) {
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) {
      return const _ImageLoadError();
    }

    return _isNetworkImage(trimmedUrl)
        ? Image.network(
            trimmedUrl,
            fit: fit,
            errorBuilder: (_, _, _) => const _ImageLoadError(),
          )
        : Image.file(
            File(trimmedUrl),
            fit: fit,
            errorBuilder: (_, _, _) => const _ImageLoadError(),
          );
  }

  Widget _buildMessageImage(BuildContext context, String imageUrl) {
    final maxWidth = MediaQuery.of(context).size.width * 0.72;
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 190,
          maxWidth: maxWidth,
          maxHeight: 360,
        ),
        child: _buildRawImage(imageUrl),
      ),
    );
  }

  Future<void> _showImagePreview(BuildContext context, String imageUrl) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Center(child: _buildRawImage(imageUrl)),
              ),
              Positioned(
                top: 22,
                right: 18,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                  tooltip: 'Schlie\u00DFen',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationCard(BuildContext context, _LocationPayload location) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onOpenLocation(location),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF075493), Color(0xFF052B55)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Standort',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'In Karten öffnen',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _carmaBlueLight,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, _ContactPayload contact) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_carmaBlue, _carmaBlueLight],
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.phoneNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return 'Datei';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).clamp(1, double.infinity).round()} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(int? durationMs) {
    final duration = Duration(milliseconds: durationMs ?? 0);
    final minutes = duration.inMinutes.toString();
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildDocumentCard(BuildContext context) {
    final fileName = message.fileName?.trim() ?? 'Dokument';
    final fileSize = _formatFileSize(message.fileSizeBytes);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onOpenDocument(message),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_myMessageBlue, _myMessageBlueLight],
                ),
              ),
              child: const Icon(
                Icons.insert_drive_file_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    fileSize,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioCard(BuildContext context) {
    final durationLabel = _formatDuration(message.fileDurationMs);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onToggleAudioMessage(message),
      child: Container(
        width: 238,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_myMessageBlue, _myMessageBlueLight],
                ),
              ),
              child: Icon(
                isAudioPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 29,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sprachnachricht',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    durationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMessageActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101827),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final emoji in const [
                        '\u2764\uFE0F',
                        '\u{1F44D}',
                        '\u{1F602}',
                        '\u{1F62E}',
                        '\u{1F622}',
                        '\u{1F64F}',
                      ])
                        _MessageReactionButton(
                          emoji: emoji,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onReactMessage(message, emoji);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MessageActionTile(
                    icon: Icons.reply_rounded,
                    label: 'Antworten',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onReplyMessage(message);
                    },
                  ),
                  _MessageActionTile(
                    icon: Icons.forward_rounded,
                    label: 'Weiterleiten',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      Navigator.of(sheetContext).pop();
                      _showSnackBar(
                        context,
                        'Nachricht wurde zum Weiterleiten kopiert.',
                      );
                    },
                  ),
                  _MessageActionTile(
                    icon: Icons.copy_rounded,
                    label: 'Kopieren',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      Navigator.of(sheetContext).pop();
                      _showSnackBar(context, 'Nachricht wurde kopiert.');
                    },
                  ),
                  _MessageActionTile(
                    icon: message.isStarred
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    label: message.isStarred
                        ? 'Stern entfernen'
                        : 'Mit Stern markieren',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onStarMessage(message);
                    },
                  ),
                  _MessageActionTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'L\u00F6schen',
                    isDestructive: true,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onDeleteMessage(message);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.72),
      fontWeight: FontWeight.w800,
      fontSize: 11,
    );
    final reactions = message.reactionBy.values
        .where((reaction) => reaction.trim().isNotEmpty)
        .toList();
    final locationPayload = message.locationPayload;
    final contactPayload = message.contactPayload;
    final imageUrl = message.imageUrl?.trim() ?? '';
    final isImageMessage = message.isImage && imageUrl.isNotEmpty;
    final isDocumentMessage = message.isDocument;
    final isAudioMessage = message.isAudio;
    final caption = message.text.trim();
    final bubblePadding = isImageMessage
        ? const EdgeInsets.all(4)
        : const EdgeInsets.fromLTRB(14, 10, 12, 8);
    final bubbleCrossAxisAlignment = message.isMine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(context),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          padding: bubblePadding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(message.isMine ? 20 : 5),
              bottomRight: Radius.circular(message.isMine ? 5 : 20),
            ),
            gradient: message.isMine
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
            color: message.isMine ? null : Colors.white.withValues(alpha: 0.09),
            border: Border.all(
              color: message.isMine
                  ? _myMessageBorder
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: bubbleCrossAxisAlignment,
            children: [
              if (message.replyToText != null &&
                  message.replyToText!.trim().isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    message.replyToText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
              if (isImageMessage) ...[
                GestureDetector(
                  onTap: () => _showImagePreview(context, imageUrl),
                  child: _buildMessageImage(context, imageUrl),
                ),
                if (caption.isNotEmpty && caption != 'Foto')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Text(
                      message.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.28,
                      ),
                    ),
                  ),
              ] else if (locationPayload != null)
                _buildLocationCard(context, locationPayload)
              else if (contactPayload != null)
                _buildContactCard(context, contactPayload)
              else if (isDocumentMessage)
                _buildDocumentCard(context)
              else if (isAudioMessage)
                _buildAudioCard(context)
              else
                Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.28,
                  ),
                ),
              SizedBox(height: isImageMessage ? 5 : 4),
              Align(
                alignment: Alignment.centerRight,
                widthFactor: 1,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: isImageMessage ? 6 : 0,
                    bottom: isImageMessage ? 3 : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message.timeLabel, style: timeStyle),
                      if (message.isMine) ...[
                        const SizedBox(width: 5),
                        _MessageDeliveryStatusIcon(message: message),
                      ],
                    ],
                  ),
                ),
              ),
              if (reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: _MessageReactionSummary(reactions: reactions),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageDeliveryStatusIcon extends StatelessWidget {
  const _MessageDeliveryStatusIcon({required this.message});

  final _LocalChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isDelivered = message.messageId?.trim().isNotEmpty == true;
    final isRead = message.isReadByOther;

    return Icon(
      isDelivered || isRead ? Icons.done_all_rounded : Icons.done_rounded,
      size: 17,
      color: isRead
          ? _myMessageCheckBlue
          : Colors.white.withValues(alpha: 0.62),
    );
  }
}

class _ImageLoadError extends StatelessWidget {
  const _ImageLoadError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_rounded,
        color: Colors.white.withValues(alpha: 0.72),
        size: 34,
      ),
    );
  }
}

class _MessageReactionSummary extends StatelessWidget {
  const _MessageReactionSummary({required this.reactions});

  final List<String> reactions;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};

    for (final reaction in reactions) {
      counts[reaction] = (counts[reaction] ?? 0) + 1;
    }

    final label = counts.entries
        .map(
          (entry) =>
              entry.value > 1 ? '${entry.key} ${entry.value}' : entry.key,
        )
        .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
      ),
    );
  }
}

class _MessageReactionButton extends StatelessWidget {
  const _MessageReactionButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }
}

class _MessageActionTile extends StatelessWidget {
  const _MessageActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : Colors.white;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ChatLoadingSpace extends StatelessWidget {
  const _ChatLoadingSpace();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }
}

class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(20),
          ),
          color: Colors.white.withValues(alpha: 0.09),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDot(delay: 0),
            const SizedBox(width: 4),
            _TypingDot(delay: 120),
            const SizedBox(width: 4),
            _TypingDot(delay: 240),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  const _TypingDot({required this.delay});

  final int delay;

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );

    _opacity = Tween<double>(
      begin: 0.35,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _ChatEmptySpace extends StatelessWidget {
  const _ChatEmptySpace();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Column(
        children: [
          const SizedBox(height: 18),
          CarmaBlueIconBox(
            icon: Icons.chat_bubble_outline_rounded,
            size: 60,
            iconSize: 30,
          ),
          const SizedBox(height: 18),
          Text(
            'Noch keine Nachrichten',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message, required this.onClear});

  final _LocalChatMessage message;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = message.isMine ? 'Antwort auf dich' : 'Antwort auf Nachricht';

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 38,
              decoration: BoxDecoration(
                color: _carmaBlueLight,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _carmaBlueLight,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (message.replyToText != null &&
                      message.replyToText!.trim().isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Text(
                        message.replyToText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    message.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              color: Colors.white70,
              tooltip: 'Antwort entfernen',
            ),
          ],
        ),
      ),
    );
  }
}
