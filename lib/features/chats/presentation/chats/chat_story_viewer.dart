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
  });

  final List<ChatStoryRecord> stories;
  final String initialStoryId;
  final String currentUserId;
  final ValueChanged<ChatStoryRecord> onStoryVisible;
  final Future<void> Function(ChatStoryRecord story) onShowViewers;
  final Future<void> Function(ChatStoryRecord story) onDeleteStory;
  final Future<void> Function(ChatStoryRecord story) onOpenSticker;
  final Future<void> Function(ChatStoryRecord story, String text) onReplyStory;
  final Future<void> Function(ChatStoryRecord story, int optionIndex)
  onVoteStoryPoll;

  @override
  State<_StoryViewerDialog> createState() => _StoryViewerDialogState();
}

class _StoryViewerDialogState extends State<_StoryViewerDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  late int _storyIndex;
  Duration? _storyDuration;
  bool _isStoryPaused = false;
  bool _isLocallyMuted = false;
  bool _isSendingReply = false;
  int? _busyPollOptionIndex;
  String? _localMuteStoryId;
  double _verticalDragOffset = 0;
  final Map<String, int> _localPollVoteByStoryId = <String, int>{};

  ChatStoryRecord get _story => widget.stories[_storyIndex];

  bool get _isOwnStory => _story.ownerUserId == widget.currentUserId;

  bool _effectiveStoryVideoMuted(ChatStoryRecord story) {
    return story.videoIsMuted ||
        (_localMuteStoryId == story.id && _isLocallyMuted);
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.stories.indexWhere(
      (story) => story.id == widget.initialStoryId,
    );
    _storyIndex = initialIndex < 0 ? 0 : initialIndex;
    _progressController =
        AnimationController(vsync: this, duration: _defaultStoryDuration)
          ..addStatusListener(_handleProgressStatus)
          ..forward();
    _replyFocusNode.addListener(_handleReplyFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onStoryVisible(_story);
      }
    });
  }

  @override
  void dispose() {
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

  void _showPreviousStory() {
    if (_storyIndex <= 0) {
      _restartProgress();
      return;
    }

    setState(() {
      _storyIndex -= 1;
    });
    _replyController.clear();
    widget.onStoryVisible(_story);
    _restartProgress();
  }

  void _showNextStory() {
    if (_storyIndex >= widget.stories.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _storyIndex += 1;
    });
    _replyController.clear();
    widget.onStoryVisible(_story);
    _restartProgress();
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

    if (_isOwnStory && (velocity < -260 || dragOffset < -56)) {
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
    _pauseStory();
    try {
      await action(_story);
    } finally {
      if (mounted) {
        _resumeStory();
      }
    }
  }

  Map<String, int> _effectivePollVoteBy(ChatStoryRecord story) {
    final localVote = _localPollVoteByStoryId[story.id];

    if (localVote == null) {
      return story.pollVoteBy;
    }

    return <String, int>{...story.pollVoteBy, widget.currentUserId: localVote};
  }

  Future<void> _handlePollVote(int optionIndex) async {
    final story = _story;

    if (_isOwnStory ||
        story.stickerType != 'poll' ||
        _busyPollOptionIndex != null) {
      return;
    }

    setState(() {
      _busyPollOptionIndex = optionIndex;
    });
    _pauseStory();

    try {
      await widget.onVoteStoryPoll(story, optionIndex);

      if (!mounted) {
        return;
      }

      setState(() {
        _localPollVoteByStoryId[story.id] = optionIndex;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Umfrage-Stimme konnte nicht gespeichert werden.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyPollOptionIndex = null;
        });

        if (!_replyFocusNode.hasFocus) {
          _resumeStory();
        }
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
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Antwort konnte nicht gesendet werden.')),
      );
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
    final story = _story;
    final storyText = story.text.trim();
    final storyStickerLabel = story.stickerLabel.trim();
    final seenCount = story.viewedAtBy.keys
        .where((viewerId) => viewerId != story.ownerUserId)
        .length;
    final headerTimeLabel = _formatStoryHeaderTime(
      story,
      isOwnStory: _isOwnStory,
    );
    final textAlignment = Alignment(
      (story.textAlignmentX * 2) - 1,
      (story.textAlignmentY * 2) - 1,
    );
    final stickerAlignment = Alignment(
      (story.stickerAlignmentX * 2) - 1,
      (story.stickerAlignmentY * 2) - 1,
    );
    final fontFamily = _storyFontFamily(story.textFontFamily);
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
                        errorBuilder: (_, _, _) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white54,
                              size: 48,
                            ),
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
                      textAlign: TextAlign.center,
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
            if (storyStickerLabel.isNotEmpty)
              Positioned.fill(
                child: Align(
                  alignment: stickerAlignment,
                  child: story.stickerType == 'poll'
                      ? _StoryPollSticker(
                          question: storyStickerLabel,
                          payload: story.stickerPayload,
                          voteBy: _effectivePollVoteBy(story),
                          currentUserId: widget.currentUserId,
                          isOwnStory: _isOwnStory,
                          busyOptionIndex: _busyPollOptionIndex,
                          onVote: _handlePollVote,
                        )
                      : GestureDetector(
                          onTap: () => _pauseForAction(widget.onOpenSticker),
                          child: _StoryStickerChip(
                            type: story.stickerType,
                            label: storyStickerLabel,
                            payload: story.stickerPayload,
                          ),
                        ),
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
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF101827).withValues(alpha: 0.66),
                            Colors.black.withValues(alpha: 0.34),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
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
                                  headerTimeLabel,
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
                          if (_isOwnStory)
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
                    for (var index = 0; index < widget.stories.length; index++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == widget.stories.length - 1 ? 0 : 4,
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
            if (!_isOwnStory)
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
            if (_isOwnStory)
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: SafeArea(
                  child: Center(
                    child: _StorySeenButton(
                      count: seenCount,
                      onPressed: () => _pauseForAction(widget.onShowViewers),
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
          child: Row(
            children: [
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 42,
                height: 42,
                child: IconButton.filled(
                  onPressed: isSending ? null : onSend,
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
                    backgroundColor: _carmaBlue,
                    disabledBackgroundColor: _carmaBlue.withValues(alpha: 0.42),
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
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

class _StoryPollSticker extends StatelessWidget {
  const _StoryPollSticker({
    required this.question,
    required this.payload,
    required this.voteBy,
    required this.currentUserId,
    required this.isOwnStory,
    required this.busyOptionIndex,
    required this.onVote,
  });

  final String question;
  final String payload;
  final Map<String, int> voteBy;
  final String currentUserId;
  final bool isOwnStory;
  final int? busyOptionIndex;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final options = payload
        .split('\n')
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .take(2)
        .toList(growable: false);
    final effectiveOptions = options.length == 2
        ? options
        : const <String>['Ja', 'Nein'];
    final validVotes = voteBy.values
        .where((optionIndex) => optionIndex == 0 || optionIndex == 1)
        .toList(growable: false);
    final totalVotes = validVotes.length;
    final selectedOption = voteBy[currentUserId];
    final hasVoted = selectedOption != null;
    final voteHint = isOwnStory
        ? (totalVotes == 1 ? '1 Stimme' : '$totalVotes Stimmen')
        : hasVoted
        ? (totalVotes == 1
              ? 'Abgestimmt · 1 Stimme'
              : 'Abgestimmt · $totalVotes Stimmen')
        : 'Tippe zum Abstimmen';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0B223B).withValues(alpha: 0.88),
                  const Color(0xFF123F68).withValues(alpha: 0.74),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: _carmaBlue.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _carmaBlue.withValues(alpha: 0.9),
                      ),
                      child: const Icon(
                        Icons.poll_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < effectiveOptions.length; index++)
                  Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                    child: _StoryPollOptionButton(
                      label: effectiveOptions[index],
                      optionIndex: index,
                      voteCount: validVotes
                          .where((vote) => vote == index)
                          .length,
                      totalVotes: totalVotes,
                      isSelected: selectedOption == index,
                      showResults: isOwnStory || hasVoted,
                      isBusy: busyOptionIndex == index,
                      isDisabled:
                          busyOptionIndex != null || isOwnStory || hasVoted,
                      onTap: () => onVote(index),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  voteHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

class _StoryPollOptionButton extends StatelessWidget {
  const _StoryPollOptionButton({
    required this.label,
    required this.optionIndex,
    required this.voteCount,
    required this.totalVotes,
    required this.isSelected,
    required this.showResults,
    required this.isBusy,
    required this.isDisabled,
    required this.onTap,
  });

  final String label;
  final int optionIndex;
  final int voteCount;
  final int totalVotes;
  final bool isSelected;
  final bool showResults;
  final bool isBusy;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = totalVotes <= 0 ? 0.0 : voteCount / totalVotes;
    final percent = (progress * 100).round();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: isSelected
                  ? _carmaBlue.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              children: [
                if (showResults)
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    heightFactor: 1,
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _carmaBlue.withValues(alpha: 0.34),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      if (isSelected) ...[
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                      ],
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (isBusy)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      else if (showResults)
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
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

class _StorySeenButton extends StatelessWidget {
  const _StorySeenButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF101827).withValues(alpha: 0.76),
                    Colors.black.withValues(alpha: 0.44),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 4),
                  Container(
                    height: 26,
                    constraints: const BoxConstraints(minWidth: 26),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: _carmaBlue.withValues(alpha: 0.86),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aufrufe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      Text(
                        'hochziehen',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ],
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
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;

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
        setState(() {});
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

    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
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
              backgroundColor: Colors.black.withValues(alpha: 0.28),
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

String _formatStoryHeaderTime(
  ChatStoryRecord story, {
  required bool isOwnStory,
}) {
  final now = DateTime.now();

  if (isOwnStory) {
    final remaining = story.expiresAt.difference(now);

    if (remaining.isNegative) {
      return 'Läuft gleich ab';
    }

    if (remaining.inHours >= 1) {
      return 'Läuft noch ${remaining.inHours} Std.';
    }

    final minutes = remaining.inMinutes.clamp(1, 59);
    return 'Läuft noch $minutes Min.';
  }

  final difference = now.difference(story.createdAt);

  if (difference.inMinutes < 1) {
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
