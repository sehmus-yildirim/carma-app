part of '../chats_screen.dart';

class _StoryViewerDialog extends StatefulWidget {
  const _StoryViewerDialog({
    required this.stories,
    required this.initialStoryId,
    required this.currentUserId,
    required this.onStoryVisible,
    required this.onShowViewers,
    required this.onDeleteStory,
    required this.onOpenSticker,
    required this.onReplyStory,
    required this.onVoteStoryPoll,
    this.allowReplies = true,
    this.allowOwnerActions = true,
    this.enableStickerAction = true,
  });

  final List<ChatStoryRecord> stories;
  final String initialStoryId;
  final String currentUserId;
  final ValueChanged<ChatStoryRecord> onStoryVisible;
  final Future<void> Function(ChatStoryRecord story) onShowViewers;
  final Future<void> Function(ChatStoryRecord story) onDeleteStory;
  final Future<void> Function(ChatStoryRecord story) onOpenSticker;
  final Future<void> Function(ChatStoryRecord story, String text) onReplyStory;
  final Future<bool> Function(ChatStoryRecord story, int optionIndex)
  onVoteStoryPoll;
  final bool allowReplies;
  final bool allowOwnerActions;
  final bool enableStickerAction;

  @override
  State<_StoryViewerDialog> createState() => _StoryViewerDialogState();
}

class _StoryViewerDialogState extends State<_StoryViewerDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  final ProfileRepository _profileRepository = ProfileRepository();
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  final Map<String, String> _vehicleLabelByOwnerUserId = <String, String>{};
  final Set<String> _loadingVehicleOwnerUserIds = <String>{};
  Timer? _expirationTimer;
  late final List<ChatStoryRecord> _stories;
  late int _storyIndex;
  Duration? _storyDuration;
  bool _isStoryPaused = false;
  bool _isLocallyMuted = false;
  bool _isSendingReply = false;
  String? _localMuteStoryId;
  double _verticalDragOffset = 0;

  ChatStoryRecord get _story => _stories[_storyIndex];

  String get _currentUserId => widget.currentUserId.trim();

  bool get _isOwnStory => _story.ownerUserId.trim() == _currentUserId;

  bool _canCurrentUserViewStory(ChatStoryRecord story) {
    if (_currentUserId.isEmpty) {
      return false;
    }

    return story.ownerUserId.trim() == _currentUserId ||
        story.viewerUserIds.any((userId) => userId.trim() == _currentUserId);
  }

  bool _effectiveStoryVideoMuted(ChatStoryRecord story) {
    return story.videoIsMuted ||
        (_localMuteStoryId == story.id && _isLocallyMuted);
  }

  @override
  void initState() {
    super.initState();
    _stories = widget.stories
        .where(
          (story) =>
              !story.isExpired &&
              story.hasRenderableMedia &&
              _canCurrentUserViewStory(story),
        )
        .toList(growable: false);
    final initialIndex = _stories.indexWhere(
      (story) => story.id == widget.initialStoryId,
    );
    _storyIndex = initialIndex < 0 ? 0 : initialIndex;
    _progressController =
        AnimationController(vsync: this, duration: _defaultStoryDuration)
          ..addStatusListener(_handleProgressStatus)
          ..forward();
    _replyFocusNode.addListener(_handleReplyFocusChanged);
    if (_stories.isNotEmpty) {
      unawaited(_loadStoryOwnerVehicleLabel(_story));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_stories.isEmpty) {
        Navigator.of(context).maybePop();
        return;
      }

      widget.onStoryVisible(_story);
      _scheduleStoryExpirationTimer();
    });
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    _replyFocusNode
      ..removeListener(_handleReplyFocusChanged)
      ..dispose();
    _replyController.dispose();
    _progressController
      ..removeStatusListener(_handleProgressStatus)
      ..dispose();
    super.dispose();
  }

  void _handleReplyFocusChanged() {
    if (_replyFocusNode.hasFocus) {
      _pauseStory();
      return;
    }

    if (!_isSendingReply) {
      _resumeStory();
    }
  }

  void _handleProgressStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }

    _showNextStory();
  }

  void _pauseStory() {
    if (_progressController.isAnimating) {
      _progressController.stop();
    }

    if (!_isStoryPaused && mounted) {
      setState(() {
        _isStoryPaused = true;
      });
    }
  }

  void _resumeStory() {
    if (_progressController.status != AnimationStatus.completed) {
      _progressController.forward();
    }

    if (_isStoryPaused && mounted) {
      setState(() {
        _isStoryPaused = false;
      });
    }
  }

  void _restartProgress() {
    _storyDuration = null;
    _isStoryPaused = false;
    _progressController
      ..duration = _defaultStoryDuration
      ..reset()
      ..forward();
    _scheduleStoryExpirationTimer();
  }

  void _updateStoryDuration(Duration duration) {
    if (!mounted || duration <= Duration.zero) {
      return;
    }

    final clampedDuration = duration < const Duration(seconds: 4)
        ? const Duration(seconds: 4)
        : duration > const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : duration;

    if (_storyDuration == clampedDuration) {
      return;
    }

    _storyDuration = clampedDuration;
    _progressController
      ..duration = clampedDuration
      ..forward(from: 0);
  }

  bool _isPlayableStory(ChatStoryRecord story) {
    return !story.isExpired &&
        story.hasRenderableMedia &&
        _canCurrentUserViewStory(story);
  }

  int? _previousPlayableStoryIndex() {
    for (var index = _storyIndex - 1; index >= 0; index--) {
      if (_isPlayableStory(_stories[index])) {
        return index;
      }
    }

    return null;
  }

  int? _nextPlayableStoryIndex() {
    for (var index = _storyIndex + 1; index < _stories.length; index++) {
      if (_isPlayableStory(_stories[index])) {
        return index;
      }
    }

    return null;
  }

  void _showStoryAt(int index) {
    setState(() {
      _storyIndex = index;
    });
    unawaited(_loadStoryOwnerVehicleLabel(_story));
    _replyController.clear();
    widget.onStoryVisible(_story);
    _restartProgress();
  }

  Future<void> _loadStoryOwnerVehicleLabel(ChatStoryRecord story) async {
    final ownerUserId = story.ownerUserId.trim();

    if (ownerUserId.isEmpty ||
        _vehicleLabelByOwnerUserId.containsKey(ownerUserId) ||
        !_loadingVehicleOwnerUserIds.add(ownerUserId)) {
      return;
    }

    var vehicleLabel = 'Fahrzeug nicht angegeben';

    try {
      final profile = ownerUserId == _currentUserId
          ? await _profileRepository.getProfile(ownerUserId)
          : await _profileRepository.watchPublicProfile(ownerUserId).first;
      final vehicleParts = <String>[
        if ((profile?.vehicleBrand ?? '').trim().isNotEmpty)
          profile!.vehicleBrand!.trim(),
        if ((profile?.vehicleModel ?? '').trim().isNotEmpty)
          profile!.vehicleModel!.trim(),
      ];
      final loadedLabel = vehicleParts.join(' ').trim();

      if (loadedLabel.isNotEmpty) {
        vehicleLabel = loadedLabel;
      }
    } catch (_) {
      // Fehlende oder nicht freigegebene Fahrzeugdaten bleiben neutral.
    } finally {
      _loadingVehicleOwnerUserIds.remove(ownerUserId);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _vehicleLabelByOwnerUserId[ownerUserId] = vehicleLabel;
    });
  }

  void _showPreviousStory() {
    final previousIndex = _previousPlayableStoryIndex();

    if (previousIndex == null) {
      _restartProgress();
      return;
    }

    _showStoryAt(previousIndex);
  }

  void _showNextStory() {
    final nextIndex = _nextPlayableStoryIndex();

    if (nextIndex == null) {
      Navigator.of(context).maybePop();
      return;
    }

    _showStoryAt(nextIndex);
  }

  void _scheduleStoryExpirationTimer() {
    _expirationTimer?.cancel();
    _expirationTimer = null;

    if (!mounted || _stories.isEmpty) {
      return;
    }

    final remaining = _story.expiresAt.difference(DateTime.now());

    if (remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleCurrentStoryExpired();
        }
      });
      return;
    }

    _expirationTimer = Timer(remaining, _handleCurrentStoryExpired);
  }

  void _handleCurrentStoryExpired() {
    if (!mounted || _stories.isEmpty) {
      return;
    }

    final nextIndex = _nextPlayableStoryIndex();

    if (nextIndex == null) {
      Navigator.of(context).maybePop();
      return;
    }

    _showStoryAt(nextIndex);
  }

  void _handleTapUp(TapUpDetails details, Size size) {
    final tap = details.localPosition;

    if (_isTapInsideStoryControls(tap, size)) {
      return;
    }

    final tapX = tap.dx;
    final width = size.width;
    if (tapX < width * 0.34) {
      _showPreviousStory();
      return;
    }

    if (tapX > width * 0.66) {
      _showNextStory();
      return;
    }

    _restartProgress();
  }

  bool _isTapInsideStoryControls(Offset tap, Size size) {
    const headerTapHeight = 128.0;
    final bottomTapHeight = _isOwnStory ? 144.0 : 164.0;

    return tap.dy < headerTapHeight || tap.dy > size.height - bottomTapHeight;
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() < 260) {
      return;
    }

    if (velocity < 0) {
      _showNextStory();
      return;
    }

    _showPreviousStory();
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    _verticalDragOffset = 0;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    _verticalDragOffset += details.primaryDelta ?? 0;
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dragOffset = _verticalDragOffset;

    _verticalDragOffset = 0;

    if (velocity > 320) {
      Navigator.of(context).maybePop();
      return;
    }

    if (widget.allowOwnerActions &&
        _isOwnStory &&
        (velocity < -260 || dragOffset < -56)) {
      _pauseForAction(widget.onShowViewers);
    }
  }

  void _toggleStoryVideoSound() {
    final story = _story;

    if (!story.isVideo || story.videoIsMuted) {
      return;
    }

    setState(() {
      _localMuteStoryId = story.id;
      _isLocallyMuted = !_effectiveStoryVideoMuted(story);
    });
  }

  Future<void> _pauseForAction(
    Future<void> Function(ChatStoryRecord story) action,
  ) async {
    if (_story.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diese Story ist abgelaufen.')),
      );
      return;
    }

    _pauseStory();
    try {
      await action(_story);
    } finally {
      if (mounted) {
        _resumeStory();
      }
    }
  }

  Future<void> _sendStoryReply() async {
    final text = _replyController.text.trim();

    await _sendStoryReplyText(text, clearComposer: true, showSuccess: true);
  }

  Future<void> _sendStoryReaction(String reaction) async {
    await _sendStoryReplyText(reaction, clearComposer: false);
  }

  Future<void> _sendStoryReplyText(
    String text, {
    required bool clearComposer,
    bool showSuccess = false,
  }) async {
    final trimmedText = text.trim();

    if (_isOwnStory || trimmedText.isEmpty || _isSendingReply) {
      return;
    }

    if (_story.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diese Story ist abgelaufen.')),
      );
      return;
    }

    setState(() {
      _isSendingReply = true;
    });
    _pauseStory();

    try {
      await widget.onReplyStory(_story, trimmedText);

      if (!mounted) {
        return;
      }

      if (clearComposer) {
        _replyController.clear();
        _replyFocusNode.unfocus();
      }

      if (showSuccess) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Antwort gesendet.')));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_storyReplyErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isSendingReply = false;
        });

        if (!_replyFocusNode.hasFocus) {
          _resumeStory();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return const SizedBox.shrink();
    }

    final story = _story;
    final storyText = story.text.trim();
    final storyStickers = story.effectiveStickers;
    final seenCount = story.viewedAtBy.keys
        .where((viewerId) => viewerId != story.ownerUserId)
        .length;
    final headerVehicleLabel =
        _vehicleLabelByOwnerUserId[story.ownerUserId.trim()] ?? 'Fahrzeug';
    final textAlignment = Alignment(
      (story.textAlignmentX * 2) - 1,
      (story.textAlignmentY * 2) - 1,
    );
    final fontFamily = _storyFontFamily(story.textFontFamily);
    final textAlign = _storyTextAlign(story.textAlign);
    final isVideoMuted = _effectiveStoryVideoMuted(story);

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _handleTapUp(details, MediaQuery.sizeOf(context)),
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        onVerticalDragStart: _handleVerticalDragStart,
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: story.isVideo
                    ? _StoryViewerVideo(
                        videoUrl: story.videoUrl,
                        isMuted: isVideoMuted,
                        isPaused: _isStoryPaused,
                        filterType: story.filterType,
                        onDurationReady: _updateStoryDuration,
                      )
                    : _StoryFilteredImage(
                        image: NetworkImage(story.imageUrl),
                        filterType: story.filterType,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }

                          return const ColoredBox(color: Colors.black);
                        },
                        errorBuilder: (_, _, _) {
                          return const _StoryMediaStatus(
                            icon: Icons.broken_image_rounded,
                            title: 'Bild nicht verfügbar',
                            message:
                                'Die Story konnte gerade nicht geladen werden.',
                          );
                        },
                      ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.46),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.32),
                      ],
                      stops: const [0, 0.36, 1],
                    ),
                  ),
                ),
              ),
            ),
            if (storyText.isNotEmpty)
              Positioned.fill(
                child: Align(
                  alignment: textAlignment,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      storyText,
                      textAlign: textAlign,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(story.textColorValue),
                        fontSize: 30,
                        height: 1.08,
                        fontWeight: story.textIsBold
                            ? FontWeight.w900
                            : FontWeight.w600,
                        fontStyle: story.textIsItalic
                            ? FontStyle.italic
                            : FontStyle.normal,
                        fontFamily: fontFamily,
                        decoration: story.textIsUnderline
                            ? TextDecoration.underline
                            : TextDecoration.none,
                        decorationColor: Color(story.textColorValue),
                        decorationThickness: 2,
                        shadows: const [
                          Shadow(
                            blurRadius: 12,
                            color: Colors.black87,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            for (final sticker in storyStickers)
              if (!sticker.isEmpty)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final alignmentX = (sticker.alignmentX * 2) - 1;
                      final alignmentY = (sticker.alignmentY * 2) - 1;

                      return Align(
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: Offset(
                            alignmentX * constraints.maxWidth * 0.43,
                            alignmentY * constraints.maxHeight * 0.42,
                          ),
                          child: widget.enableStickerAction
                              ? GestureDetector(
                                  onTap: () =>
                                      _pauseForAction(widget.onOpenSticker),
                                  child: _StoryStickerChip(
                                    type: sticker.type,
                                    label: sticker.label,
                                    payload: sticker.payload,
                                  ),
                                )
                              : _StoryStickerChip(
                                  type: sticker.type,
                                  label: sticker.label,
                                  payload: sticker.payload,
                                ),
                        ),
                      );
                    },
                  ),
                ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: CaRismaDesignTokens.card,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Row(
                        children: [
                          _AvatarCircle(
                            size: 40,
                            imageUrl: story.ownerPhotoUrl,
                            iconSize: 22,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  story.ownerDisplayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  headerVehicleLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isOwnStory && widget.allowOwnerActions)
                            _StoryViewerSeenMiniChip(
                              count: seenCount,
                              onTap: () =>
                                  _pauseForAction(widget.onShowViewers),
                            ),
                          if (_isOwnStory && widget.allowOwnerActions)
                            _StoryViewerActionButton(
                              onPressed: () =>
                                  _pauseForAction(widget.onDeleteStory),
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Story löschen',
                            ),
                          _StoryViewerActionButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icons.close_rounded,
                            tooltip: 'Schließen',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: SafeArea(
                child: Row(
                  children: [
                    for (var index = 0; index < _stories.length; index++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == _stories.length - 1 ? 0 : 4,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, _) {
                                final value = index < _storyIndex
                                    ? 1.0
                                    : index == _storyIndex
                                    ? _progressController.value
                                    : 0.0;

                                return LinearProgressIndicator(
                                  value: value,
                                  minHeight: 3,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.22,
                                  ),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (story.isVideo)
              Positioned(
                left: 16,
                bottom: _isOwnStory ? 86 : 92,
                child: SafeArea(
                  child: _StoryVideoSoundPill(
                    isMuted: isVideoMuted,
                    isLocked: story.videoIsMuted,
                    onTap: story.videoIsMuted ? null : _toggleStoryVideoSound,
                  ),
                ),
              ),
            if (!_isOwnStory && widget.allowReplies)
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_replyFocusNode.hasFocus) ...[
                          _StoryQuickReactions(
                            isSending: _isSendingReply,
                            onReaction: _sendStoryReaction,
                          ),
                          const SizedBox(height: 10),
                        ],
                        _StoryReplyComposer(
                          controller: _replyController,
                          focusNode: _replyFocusNode,
                          isSending: _isSendingReply,
                          onSend: _sendStoryReply,
                        ),
                      ],
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

class _StoryReplyComposer extends StatelessWidget {
  const _StoryReplyComposer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(0xFF101827).withValues(alpha: 0.74),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, textValue, _) {
              final canSend = textValue.text.trim().isNotEmpty && !isSending;

              return Row(
                children: [
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: isSending,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (canSend) {
                          onSend();
                        }
                      },
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Auf Story antworten',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.56),
                          fontWeight: FontWeight.w700,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: IconButton.filled(
                      onPressed: canSend ? onSend : null,
                      icon: isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: _carismaBlue,
                        disabledBackgroundColor: Colors.white.withValues(
                          alpha: 0.12,
                        ),
                        disabledForegroundColor: Colors.white.withValues(
                          alpha: 0.34,
                        ),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StoryQuickReactions extends StatelessWidget {
  const _StoryQuickReactions({
    required this.isSending,
    required this.onReaction,
  });

  static const List<String> _reactions = [
    '\u{1F44D}',
    '\u{1F604}',
    '\u{1F525}',
    '\u{1F440}',
    '\u{2764}\u{FE0F}',
  ];

  final bool isSending;
  final ValueChanged<String> onReaction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(0xFF101827).withValues(alpha: 0.58),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final reaction in _reactions)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _StoryQuickReactionButton(
                    reaction: reaction,
                    isDisabled: isSending,
                    onTap: () => onReaction(reaction),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryQuickReactionButton extends StatelessWidget {
  const _StoryQuickReactionButton({
    required this.reaction,
    required this.isDisabled,
    required this.onTap,
  });

  final String reaction;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(
            child: Text(
              reaction,
              style: TextStyle(
                fontSize: 23,
                color: Colors.white.withValues(alpha: isDisabled ? 0.42 : 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryVideoSoundPill extends StatelessWidget {
  const _StoryVideoSoundPill({
    required this.isMuted,
    required this.isLocked,
    required this.onTap,
  });

  final bool isMuted;
  final bool isLocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.black.withValues(alpha: 0.36),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isMuted ? 'Stumm' : 'Ton an',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (!isLocked) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.touch_app_rounded,
                      color: Colors.white.withValues(alpha: 0.72),
                      size: 13,
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

class _StoryViewerSeenMiniChip extends StatelessWidget {
  const _StoryViewerSeenMiniChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: CaRismaDesignTokens.controlSurface,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.42),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.visibility_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

class _StoryViewerVideo extends StatefulWidget {
  const _StoryViewerVideo({
    required this.videoUrl,
    required this.isMuted,
    required this.isPaused,
    required this.filterType,
    required this.onDurationReady,
  });

  final String videoUrl;
  final bool isMuted;
  final bool isPaused;
  final String filterType;
  final ValueChanged<Duration> onDurationReady;

  @override
  State<_StoryViewerVideo> createState() => _StoryViewerVideoState();
}

class _StoryViewerVideoState extends State<_StoryViewerVideo> {
  VideoPlayerController? _controller;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant _StoryViewerVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _hasLoadError = false;
      _initializeVideo();
      return;
    }

    if (oldWidget.isMuted != widget.isMuted) {
      _controller?.setVolume(widget.isMuted ? 0 : 1);
    }

    if (oldWidget.isPaused != widget.isPaused) {
      _syncPlaybackState();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final url = widget.videoUrl.trim();

    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _hasLoadError = true;
        });
      }
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    _hasLoadError = false;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(widget.isMuted ? 0 : 1);
      if (!widget.isPaused) {
        await controller.play();
      }
      widget.onDurationReady(controller.value.duration);

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasLoadError = true;
        });
      }
    }
  }

  Future<void> _syncPlaybackState() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (widget.isPaused) {
      await controller.pause();
      return;
    }

    await controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_hasLoadError) {
      return const _StoryMediaStatus(
        icon: Icons.videocam_off_rounded,
        title: 'Video nicht verfügbar',
        message: 'Die Story konnte gerade nicht abgespielt werden.',
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return _StoryFilteredContent(
      filterType: widget.filterType,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _StoryMediaStatus extends StatelessWidget {
  const _StoryMediaStatus({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 270,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF101827).withValues(alpha: 0.88),
                    const Color(0xFF071120).withValues(alpha: 0.72),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _carismaBlue.withValues(alpha: 0.88),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryViewerActionButton extends StatelessWidget {
  const _StoryViewerActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon),
            color: Colors.white,
            tooltip: tooltip,
            style: IconButton.styleFrom(
              backgroundColor: CaRismaDesignTokens.controlSurface,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.42)),
              shape: const CircleBorder(),
            ),
          ),
        ),
      ),
    );
  }
}

const Duration _defaultStoryDuration = Duration(seconds: 7);

String? _storyFontFamily(String value) {
  return switch (value.trim()) {
    'serif' => 'serif',
    'mono' => 'monospace',
    'rounded' => 'sans-serif-medium',
    'condensed' => 'sans-serif-condensed',
    'light' => 'sans-serif-light',
    'medium' => 'sans-serif-medium',
    'black' => 'sans-serif-black',
    'casual' => 'casual',
    'cursive' => 'cursive',
    _ => null,
  };
}

TextAlign _storyTextAlign(String value) {
  return switch (value.trim()) {
    'left' => TextAlign.left,
    'right' => TextAlign.right,
    _ => TextAlign.center,
  };
}
