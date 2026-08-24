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
    required this.onOpenViewOnceMedia,
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
  final ValueChanged<_LocalChatMessage> onOpenViewOnceMedia;
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
      children: List.generate(messages.length, (index) {
        final message = messages[index];
        final isNewestMessage = index == messages.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isNewestMessage ? 2 : 10),
          child: _ChatMessageBubble(
            message: message,
            onDeleteMessage: onDeleteMessage,
            onReplyMessage: onReplyMessage,
            onStarMessage: onStarMessage,
            onReactMessage: onReactMessage,
            onOpenLocation: onOpenLocation,
            onOpenDocument: onOpenDocument,
            onOpenViewOnceMedia: onOpenViewOnceMedia,
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
    required this.onOpenViewOnceMedia,
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
  final ValueChanged<_LocalChatMessage> onOpenViewOnceMedia;
  final ValueChanged<_LocalChatMessage> onToggleAudioMessage;
  final bool isAudioPlaying;

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _copyContactPhoneNumber(BuildContext context, _ContactPayload contact) {
    final phoneNumber = contact.phoneNumber.trim();

    if (phoneNumber.isEmpty) {
      _showSnackBar(context, 'Dieser Kontakt hat keine Rufnummer.');
      return;
    }

    Clipboard.setData(ClipboardData(text: phoneNumber));
    _showSnackBar(context, 'Rufnummer wurde kopiert.');
  }

  String _clipboardTextForMessage() {
    if (message.isViewOnce) {
      return message.viewOnceOpenedAtBy.isNotEmpty
          ? 'Geöffnet'
          : message.isVideo
          ? 'Video'
          : 'Foto';
    }

    final location = message.locationPayload;
    if (location != null) {
      return 'Standort: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
    }

    final contact = message.contactPayload;
    if (contact != null) {
      final phoneNumber = contact.phoneNumber.trim();
      return phoneNumber.isEmpty ? contact.name.trim() : phoneNumber;
    }

    final imageUrl = message.imageUrl?.trim() ?? '';
    if (message.isImage && imageUrl.isNotEmpty) {
      return imageUrl;
    }

    final fileUrl = message.fileUrl?.trim() ?? '';
    if (message.isDocument) {
      final fileName = message.fileName?.trim() ?? '';
      if (fileName.isEmpty) {
        return fileUrl;
      }

      return fileUrl.isEmpty ? fileName : '$fileName\n$fileUrl';
    }

    if (message.isAudio) {
      return fileUrl.isEmpty ? 'Sprachnachricht' : 'Sprachnachricht\n$fileUrl';
    }

    return message.text.trim();
  }

  Widget _buildViewOnceCard(BuildContext context, bool isOpened) {
    final label = isOpened
        ? 'Geöffnet'
        : message.isVideo
        ? 'Video'
        : 'Foto';
    final canOpen = !message.isMine && !isOpened;
    final iconColor = isOpened
        ? Colors.white.withValues(alpha: 0.48)
        : Colors.white;
    final borderColor = isOpened
        ? Colors.white.withValues(alpha: 0.16)
        : CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.54);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canOpen ? () => onOpenViewOnceMedia(message) : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 142),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CaRismaDesignTokens.card,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CaRismaDesignTokens.controlSurface,
                border: Border.all(color: borderColor),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    isOpened
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: iconColor,
                    size: 20,
                  ),
                  Positioned(
                    right: 4,
                    bottom: 3,
                    child: Container(
                      width: 13,
                      height: 13,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CaRismaDesignTokens.card,
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 8,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isOpened ? Colors.white54 : Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyMessageText(BuildContext context, String successMessage) {
    final clipboardText = _clipboardTextForMessage().trim();

    if (clipboardText.isEmpty) {
      _showSnackBar(context, 'Diese Nachricht kann nicht kopiert werden.');
      return;
    }

    Clipboard.setData(ClipboardData(text: clipboardText));
    _showSnackBar(context, successMessage);
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: _buildRawImage(imageUrl, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: 22,
                    right: 18,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                      tooltip: 'Schließen',
                    ),
                  ),
                ],
              );
            },
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
        width: 236,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: CaRismaDesignTokens.surface2.withValues(alpha: 0.90),
          border: Border.all(
            color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.09),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.14),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: CaRismaDesignTokens.textPrimary,
                size: 24,
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
                      color: CaRismaDesignTokens.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CaRismaDesignTokens.textPrimary.withValues(
                        alpha: 0.76,
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'In Karten öffnen',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _carismaBlueLight,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _copyContactPhoneNumber(context, contact),
      child: Container(
        width: 236,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: CaRismaDesignTokens.surface2.withValues(alpha: 0.90),
          border: Border.all(
            color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.09),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_carismaBlue, _carismaBlueLight],
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: CaRismaDesignTokens.textPrimary,
                size: 23,
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
                      color: CaRismaDesignTokens.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.phoneNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CaRismaDesignTokens.textPrimary.withValues(
                        alpha: 0.74,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Rufnummer kopieren',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _carismaBlueLight,
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
          color: CaRismaDesignTokens.surface2.withValues(alpha: 0.90),
          border: Border.all(
            color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.09),
          ),
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
                color: CaRismaDesignTokens.textPrimary,
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
                      color: CaRismaDesignTokens.textPrimary,
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
                      color: CaRismaDesignTokens.textPrimary.withValues(
                        alpha: 0.74,
                      ),
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
        width: 226,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: CaRismaDesignTokens.surface2.withValues(alpha: 0.90),
          border: Border.all(
            color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.09),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
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
                color: CaRismaDesignTokens.textPrimary,
                size: 27,
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
                      color: CaRismaDesignTokens.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isAudioPlaying
                        ? 'Wird abgespielt • $durationLabel'
                        : durationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CaRismaDesignTokens.textPrimary.withValues(
                        alpha: 0.74,
                      ),
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

  bool _isStoryReplyPreview(String value) {
    return value.trim().startsWith('Story von ');
  }

  bool _isStoryQuickReaction(String value) {
    return switch (value.trim()) {
      '\u{1F44D}' ||
      '\u{1F604}' ||
      '\u{1F525}' ||
      '\u{1F440}' ||
      '\u{2764}\u{FE0F}' => true,
      _ => false,
    };
  }

  bool _isStoryReactionMessage(_LocalChatMessage message) {
    final replyText = message.replyToText?.trim() ?? '';

    return _isStoryReplyPreview(replyText) &&
        _isStoryQuickReaction(message.text);
  }

  String _storyReplyTitle(String value) {
    final text = value.trim();
    final separatorIndex = text.indexOf(':');

    if (separatorIndex < 0) {
      return 'Story-Antwort';
    }

    return text.substring(0, separatorIndex).trim();
  }

  String _storyReplySubtitle(String value) {
    final text = value.trim();
    final separatorIndex = text.indexOf(':');

    if (separatorIndex < 0 || separatorIndex >= text.length - 1) {
      return 'Story';
    }

    return text.substring(separatorIndex + 1).trim();
  }

  Widget _buildReplyPreview(
    BuildContext context,
    String replyText,
    String? replyToSenderName,
  ) {
    final isStoryReply = _isStoryReplyPreview(replyText);

    if (!isStoryReply) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: CaRismaDesignTokens.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                color: CaRismaDesignTokens.bluePrimary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    replyToSenderName?.trim().isNotEmpty == true
                        ? replyToSenderName!.trim()
                        : 'Nachricht',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CaRismaDesignTokens.bluePrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    replyText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CaRismaDesignTokens.textPrimary.withValues(
                        alpha: 0.78,
                      ),
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(9, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _carismaBlue.withValues(alpha: 0.34),
            CaRismaDesignTokens.textPrimary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _carismaBlue.withValues(alpha: 0.86),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: CaRismaDesignTokens.textPrimary,
              size: 17,
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _storyReplyTitle(replyText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _storyReplySubtitle(replyText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CaRismaDesignTokens.textPrimary.withValues(
                      alpha: 0.72,
                    ),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryReactionCard(
    BuildContext context,
    _LocalChatMessage message,
  ) {
    final replyText = message.replyToText?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _carismaBlue.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Text(
              message.text.trim(),
              style: const TextStyle(fontSize: 22, height: 1),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Story-Reaktion',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _storyReplySubtitle(replyText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 11,
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

  Future<void> _showMessageActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CaRismaDesignTokens.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),

      useSafeArea: true,

      builder: (sheetContext) {
        void runAfterClose(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) {
              return;
            }
            action();
          });
        }

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
                            runAfterClose(() => onReactMessage(message, emoji));
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MessageActionTile(
                    icon: Icons.reply_rounded,
                    label: 'Antworten',
                    onTap: () {
                      runAfterClose(() => onReplyMessage(message));
                    },
                  ),
                  _MessageActionTile(
                    icon: Icons.copy_rounded,
                    label: 'Kopieren',
                    onTap: () {
                      runAfterClose(
                        () => _copyMessageText(
                          context,
                          'Nachricht wurde kopiert.',
                        ),
                      );
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
                      runAfterClose(() => onStarMessage(message));
                    },
                  ),
                  _MessageActionTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Löschen',
                    isDestructive: true,
                    onTap: () {
                      runAfterClose(() => onDeleteMessage(message));
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
    final reactions = message.reactionBy.values
        .where((reaction) => reaction.trim().isNotEmpty)
        .toList();
    final locationPayload = message.locationPayload;
    final contactPayload = message.contactPayload;
    final isStructuredCardMessage =
        locationPayload != null || contactPayload != null;
    final imageUrl = message.imageUrl?.trim() ?? '';
    final isImageMessage = message.isImage && imageUrl.isNotEmpty;
    final isDocumentMessage = message.isDocument;
    final isAudioMessage = message.isAudio;
    final isVideoMessage = message.isVideo;
    final isViewOnceMedia =
        message.isViewOnce && (isImageMessage || isVideoMessage);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final isViewOnceOpened =
        message.isViewOnce &&
        (message.viewOnceOpenedAtBy.isNotEmpty ||
            (currentUserId.isNotEmpty &&
                message.isViewOnceOpenedFor(currentUserId)));
    final caption = message.text.trim();
    final isCompactTextMessage =
        !isImageMessage &&
        locationPayload == null &&
        contactPayload == null &&
        !isDocumentMessage &&
        !isAudioMessage &&
        !isVideoMessage &&
        !_isStoryReactionMessage(message);
    final isStructuredVisualMessage =
        isStructuredCardMessage ||
        isDocumentMessage ||
        isAudioMessage ||
        isViewOnceMedia;
    final usesAccentBubble = message.isMine && !isStructuredVisualMessage;
    final bubbleTextColor = usesAccentBubble
        ? CaRismaDesignTokens.onAccent
        : CaRismaDesignTokens.textPrimary;
    final timeStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: bubbleTextColor.withValues(alpha: 0.72),
      fontWeight: FontWeight.w800,
      fontSize: 11,
    );
    final bubblePadding =
        isImageMessage || isVideoMessage || isStructuredVisualMessage
        ? const EdgeInsets.all(4)
        : isCompactTextMessage
        ? const EdgeInsets.fromLTRB(11, 6, 8, 5)
        : const EdgeInsets.fromLTRB(14, 10, 12, 8);
    final bubbleCrossAxisAlignment = message.isMine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final isStoryReactionMessage = _isStoryReactionMessage(message);
    final deliveryMetadata = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message.timeLabel, style: timeStyle),
        if (message.isMine) ...[
          const SizedBox(width: 4),
          _MessageDeliveryStatusIcon(message: message),
        ],
      ],
    );

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          if (contactPayload != null) {
            _copyContactPhoneNumber(context, contactPayload);
            return;
          }

          _showMessageActions(context);
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          padding: bubblePadding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(message.isMine ? 20 : 5),
              bottomRight: Radius.circular(message.isMine ? 5 : 20),
            ),
            gradient: message.isMine && !isStructuredVisualMessage
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
            color: isStructuredVisualMessage
                ? CaRismaDesignTokens.surface2.withValues(alpha: 0.90)
                : message.isMine
                ? null
                : CaRismaDesignTokens.surface2.withValues(alpha: 0.86),
            border: Border.all(
              color: usesAccentBubble
                  ? _myMessageBorder
                  : CaRismaDesignTokens.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: bubbleCrossAxisAlignment,
            children: [
              if (message.replyToText != null &&
                  message.replyToText!.trim().isNotEmpty &&
                  !isStoryReactionMessage) ...[
                _buildReplyPreview(
                  context,
                  message.replyToText!.trim(),
                  message.replyToSenderName,
                ),
              ],
              if (isViewOnceMedia)
                _buildViewOnceCard(context, isViewOnceOpened)
              else if (isImageMessage) ...[
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
                        color: bubbleTextColor,
                        fontWeight: FontWeight.w800,
                        height: 1.28,
                      ),
                    ),
                  ),
              ] else if (isVideoMessage)
                _InlineChatVideo(message: message)
              else if (locationPayload != null)
                _buildLocationCard(context, locationPayload)
              else if (contactPayload != null)
                _buildContactCard(context, contactPayload)
              else if (isDocumentMessage)
                _buildDocumentCard(context)
              else if (isAudioMessage)
                _buildAudioCard(context)
              else if (isStoryReactionMessage)
                _buildStoryReactionCard(context, message)
              else if (isCompactTextMessage)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        message.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: bubbleTextColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: deliveryMetadata,
                    ),
                  ],
                )
              else
                Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: bubbleTextColor,
                    fontWeight: FontWeight.w800,
                    height: 1.28,
                  ),
                ),
              if (!isCompactTextMessage) ...[
                SizedBox(height: isImageMessage ? 5 : 4),
                Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: isImageMessage ? 6 : 0,
                      bottom: isImageMessage ? 3 : 0,
                    ),
                    child: deliveryMetadata,
                  ),
                ),
              ],
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

class _InlineChatVideo extends StatefulWidget {
  const _InlineChatVideo({required this.message});

  final _LocalChatMessage message;

  @override
  State<_InlineChatVideo> createState() => _InlineChatVideoState();
}

class _InlineChatVideoState extends State<_InlineChatVideo> {
  VideoPlayerController? _controller;
  Future<void>? _initialization;
  String? _errorMessage;
  bool _lastIsPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    final source = widget.message.fileUrl?.trim() ?? '';
    if (source.isEmpty) {
      _errorMessage = 'Video nicht verfügbar.';
      return;
    }

    try {
      final uri = Uri.tryParse(source);
      final controller =
          uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
          ? VideoPlayerController.networkUrl(uri)
          : VideoPlayerController.file(File(source));
      _controller = controller;
      controller.addListener(_handlePlaybackStateChanged);
      _initialization = controller
          .initialize()
          .then((_) {
            controller.setLooping(false);
            if (mounted) {
              setState(() {});
            }
          })
          .catchError((Object _) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Video konnte nicht geladen werden.';
              });
            }
          });
    } catch (_) {
      _errorMessage = 'Video konnte nicht geladen werden.';
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handlePlaybackStateChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _handlePlaybackStateChanged() {
    final controller = _controller;
    if (!mounted || controller == null) {
      return;
    }

    final isPlaying = controller.value.isPlaying;
    if (isPlaying == _lastIsPlaying) {
      return;
    }

    _lastIsPlaying = isPlaying;
    setState(() {});
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
      _lastIsPlaying = controller.value.isPlaying;
    });
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return 'Video';
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final errorMessage = _errorMessage;

    return SizedBox(
      width: 270,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: ColoredBox(
          color: CaRismaDesignTokens.surface2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio:
                    controller?.value.isInitialized == true &&
                        controller!.value.aspectRatio > 0
                    ? controller.value.aspectRatio.clamp(0.75, 1.8)
                    : 16 / 9,
                child: errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: CaRismaDesignTokens.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    : FutureBuilder<void>(
                        future: _initialization,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                                  ConnectionState.done ||
                              controller == null ||
                              !controller.value.isInitialized) {
                            return const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: CaRismaDesignTokens.bluePrimary,
                              ),
                            );
                          }

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _togglePlayback,
                            child: Stack(
                              fit: StackFit.expand,
                              alignment: Alignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: controller.value.size.width,
                                    height: controller.value.size.height,
                                    child: VideoPlayer(controller),
                                  ),
                                ),
                                Center(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 160),
                                    opacity: controller.value.isPlaying ? 0 : 1,
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(
                                          alpha: 0.62,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 34,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 8,
                                  right: 8,
                                  bottom: 6,
                                  child: VideoProgressIndicator(
                                    controller,
                                    allowScrubbing: true,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    colors: VideoProgressColors(
                                      playedColor:
                                          CaRismaDesignTokens.blueBright,
                                      bufferedColor: Colors.white.withValues(
                                        alpha: 0.28,
                                      ),
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.videocam_rounded,
                      size: 16,
                      color: CaRismaDesignTokens.blueBright,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(widget.message.fileDurationMs),
                      style: const TextStyle(
                        color: CaRismaDesignTokens.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatFileSize(widget.message.fileSizeBytes),
                      style: const TextStyle(
                        color: CaRismaDesignTokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
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
      color: CaRismaDesignTokens.card,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
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
    final color = isDestructive
        ? CaRismaDesignTokens.danger
        : CaRismaDesignTokens.bluePrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: CaRismaDesignTokens.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
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
          color: CaRismaDesignTokens.surface2.withValues(alpha: 0.86),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
          CaRismaBlueIconBox(
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
  const _ReplyPreview({
    required this.message,
    required this.senderName,
    required this.onClear,
  });

  final _LocalChatMessage message;
  final String senderName;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: CaRismaDesignTokens.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 38,
              decoration: BoxDecoration(
                color: _carismaBlueLight,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _carismaBlueLight,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
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
