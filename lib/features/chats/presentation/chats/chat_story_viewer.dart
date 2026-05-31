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
  });

  final List<ChatStoryRecord> stories;
  final String initialStoryId;
  final String currentUserId;
  final ValueChanged<ChatStoryRecord> onStoryVisible;
  final Future<void> Function(ChatStoryRecord story) onShowViewers;
  final Future<void> Function(ChatStoryRecord story) onDeleteStory;
  final Future<void> Function(ChatStoryRecord story) onOpenSticker;

  @override
  State<_StoryViewerDialog> createState() => _StoryViewerDialogState();
}

class _StoryViewerDialogState extends State<_StoryViewerDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  late int _storyIndex;
  Duration? _storyDuration;
  bool _isStoryPaused = false;

  ChatStoryRecord get _story => widget.stories[_storyIndex];

  bool get _isOwnStory => _story.ownerUserId == widget.currentUserId;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.stories.indexWhere(
      (story) => story.id == widget.initialStoryId,
    );
    _storyIndex = initialIndex < 0 ? 0 : initialIndex;
    _progressController = AnimationController(
      vsync: this,
      duration: _defaultStoryDuration,
    )
      ..addStatusListener(_handleProgressStatus)
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onStoryVisible(_story);
      }
    });
  }

  @override
  void dispose() {
    _progressController
      ..removeStatusListener(_handleProgressStatus)
      ..dispose();
    super.dispose();
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
    widget.onStoryVisible(_story);
    _restartProgress();
  }

  void _handleTapUp(TapUpDetails details, double width) {
    final tapX = details.localPosition.dx;
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

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity > 320) {
      Navigator.of(context).maybePop();
      return;
    }

    if (_isOwnStory && velocity < -260) {
      _pauseForAction(widget.onShowViewers);
    }
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

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final storyText = story.text.trim();
    final storyStickerLabel = story.stickerLabel.trim();
    final seenCount = story.viewedAtBy.keys
        .where((viewerId) => viewerId != story.ownerUserId)
        .length;
    final headerTimeLabel = _formatStoryHeaderTime(story, isOwnStory: _isOwnStory);
    final textAlignment = Alignment(
      (story.textAlignmentX * 2) - 1,
      (story.textAlignmentY * 2) - 1,
    );
    final stickerAlignment = Alignment(
      (story.stickerAlignmentX * 2) - 1,
      (story.stickerAlignmentY * 2) - 1,
    );
    final fontFamily = _storyFontFamily(story.textFontFamily);

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) =>
            _handleTapUp(details, MediaQuery.sizeOf(context).width),
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        onHorizontalDragEnd: _handleHorizontalDragEnd,
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
                        isMuted: story.videoIsMuted,
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
                  child: GestureDetector(
                    onTap: () => _pauseForAction(widget.onOpenSticker),
                    child: _StoryStickerChip(
                      type: story.stickerType,
                      label: storyStickerLabel,
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

class _StorySeenButton extends StatelessWidget {
  const _StorySeenButton({
    required this.count,
    required this.onPressed,
  });

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
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
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
                  const Text(
                    'gesehen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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
