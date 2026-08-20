import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/social_post.dart';
import '../../data/social_post_repository.dart';

final List<SocialPostLike> _demoLikes =
    List<SocialPostLike>.unmodifiable(<SocialPostLike>[
      SocialPostLike(
        userId: 'demo-like-mila',
        displayName: 'Mila K.',
        photoUrl: '',
        createdAt: DateTime(2026, 8, 17, 18, 42),
      ),
      SocialPostLike(
        userId: 'demo-like-emre',
        displayName: 'Emre A.',
        photoUrl: '',
        createdAt: DateTime(2026, 8, 17, 18, 31),
      ),
      SocialPostLike(
        userId: 'demo-like-aylin',
        displayName: 'Aylin D.',
        photoUrl: '',
        createdAt: DateTime(2026, 8, 17, 18, 17),
      ),
      SocialPostLike(
        userId: 'demo-like-jonas',
        displayName: 'Jonas R.',
        photoUrl: '',
        createdAt: DateTime(2026, 8, 17, 18, 2),
      ),
      SocialPostLike(
        userId: 'demo-like-luca',
        displayName: 'Luca M.',
        photoUrl: '',
        createdAt: DateTime(2026, 8, 17, 17, 48),
      ),
    ]);

List<SocialPostComment> _buildDemoComments(SocialPost post) {
  const entries = <(String, String, String)>[
    ('demo-comment-mila', 'Mila K.', 'Sehr stimmiger X6.'),
    ('demo-comment-emre', 'Emre A.', 'Die Felgen passen richtig gut.'),
    ('demo-comment-jonas', 'Jonas R.', 'Starke Aufnahme aus Hamburg.'),
    ('demo-comment-aylin', 'Aylin D.', 'Die schwarze Ausstattung steht ihm.'),
    ('demo-comment-luca', 'Luca M.', 'Tolles Fahrzeug und sauberes Foto.'),
  ];
  return entries.indexed
      .map(
        (entry) => SocialPostComment(
          id: entry.$2.$1,
          postId: post.id,
          postOwnerUserId: post.ownerUserId,
          authorUserId: entry.$2.$1,
          authorDisplayName: entry.$2.$2,
          authorPhotoUrl: '',
          text: entry.$2.$3,
          createdAt: DateTime(2026, 8, 17, 17, 30 + entry.$1),
          isDeleted: false,
        ),
      )
      .toList(growable: true);
}

enum ProfilePostEngagementView { likes, comments }

class ProfilePostDetailsSheet extends StatefulWidget {
  const ProfilePostDetailsSheet({
    super.key,
    required this.post,
    required this.repository,
    required this.viewerUserId,
    required this.viewerDisplayName,
    required this.viewerPhotoUrl,
    required this.ownerDisplayName,
    required this.ownerPhotoUrl,
    required this.isOwner,
    required this.isDemo,
    required this.demoMediaBuilder,
    required this.onEdit,
    required this.onTogglePin,
    required this.onArchive,
    required this.onDelete,
    required this.onShare,
    this.initialEngagement,
    this.engagementOnly = false,
  });

  final SocialPost post;
  final SocialPostRepository repository;
  final String viewerUserId;
  final String viewerDisplayName;
  final String viewerPhotoUrl;
  final String ownerDisplayName;
  final String ownerPhotoUrl;
  final bool isOwner;
  final bool isDemo;
  final Widget Function(SocialPost post, SocialPostMedia media)
  demoMediaBuilder;
  final VoidCallback onEdit;
  final VoidCallback onTogglePin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final ProfilePostEngagementView? initialEngagement;
  final bool engagementOnly;

  @override
  State<ProfilePostDetailsSheet> createState() =>
      _ProfilePostDetailsSheetState();
}

class _ProfilePostDetailsSheetState extends State<ProfilePostDetailsSheet> {
  final TextEditingController _commentController = TextEditingController();
  late final List<SocialPostComment> _demoComments;
  int _mediaIndex = 0;
  ProfilePostEngagementView? _engagementView;
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _demoComments = _buildDemoComments(widget.post);
    _engagementView = widget.initialEngagement;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (widget.isDemo) return;
    try {
      await widget.repository.toggleLike(
        post: widget.post,
        userId: widget.viewerUserId,
        displayName: widget.viewerDisplayName,
        photoUrl: widget.viewerPhotoUrl,
      );
    } catch (_) {
      _showError('Gefällt mir konnte gerade nicht aktualisiert werden.');
    }
  }

  Future<void> _sendComment() async {
    if (_isSendingComment) return;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (widget.isDemo) {
      setState(() {
        _demoComments.add(
          SocialPostComment(
            id: 'demo-comment-${DateTime.now().microsecondsSinceEpoch}',
            postId: widget.post.id,
            postOwnerUserId: widget.post.ownerUserId,
            authorUserId: widget.viewerUserId,
            authorDisplayName: widget.viewerDisplayName,
            authorPhotoUrl: widget.viewerPhotoUrl,
            text: text,
            createdAt: DateTime.now(),
            isDeleted: false,
          ),
        );
        _commentController.clear();
      });
      return;
    }
    setState(() => _isSendingComment = true);
    try {
      await widget.repository.addComment(
        post: widget.post,
        authorUserId: widget.viewerUserId,
        authorDisplayName: widget.viewerDisplayName,
        authorPhotoUrl: widget.viewerPhotoUrl,
        text: text,
      );
      _commentController.clear();
    } catch (_) {
      _showError('Kommentar konnte gerade nicht gesendet werden.');
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _deleteComment(SocialPostComment comment) async {
    if (widget.isDemo) {
      setState(
        () => _demoComments.removeWhere((item) => item.id == comment.id),
      );
      return;
    }
    try {
      await widget.repository.deleteComment(
        post: widget.post,
        comment: comment,
      );
    } catch (_) {
      _showError('Kommentar konnte gerade nicht gelöscht werden.');
    }
  }

  Future<void> _reportComment(SocialPostComment comment) async {
    if (widget.isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beispielkommentar wurde gemeldet.')),
      );
      return;
    }
    try {
      await widget.repository.reportComment(
        post: widget.post,
        comment: comment,
        reporterUserId: widget.viewerUserId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kommentar wurde gemeldet.')),
      );
    } catch (_) {
      _showError('Kommentar konnte gerade nicht gemeldet werden.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showEngagement(ProfilePostEngagementView view) {
    setState(() {
      _engagementView = _engagementView == view ? null : view;
    });
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final media = post.resolvedMedia;
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final availableHeight =
        mediaQuery.size.height - keyboardInset - mediaQuery.padding.top - 20;
    final maxHeight = math.max(
      260.0,
      math.min(mediaQuery.size.height * 0.92, availableHeight),
    );
    final dialogWidth = math.max(240.0, mediaQuery.size.width - 28);
    final targetHeight = _engagementView != null || keyboardInset > 0
        ? maxHeight
        : math.min(maxHeight, dialogWidth + 170);
    if (widget.engagementOnly && _engagementView != null) {
      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + keyboardInset),
        child: SizedBox(
          height: math.min(maxHeight, mediaQuery.size.height * 0.72),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _engagementView == ProfilePostEngagementView.likes
                              ? 'Gefällt mir'
                              : 'Kommentare',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Schließen',
                        onPressed: () => Navigator.of(context).pop(),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _CommentsPanel(
                      repository: widget.repository,
                      post: post,
                      isDemo: widget.isDemo,
                      isPostOwner: widget.isOwner,
                      viewerUserId: widget.viewerUserId,
                      viewerDisplayName: widget.viewerDisplayName,
                      viewerPhotoUrl: widget.viewerPhotoUrl,
                      controller: _commentController,
                      demoComments: _demoComments,
                      isSending: _isSendingComment,
                      view: _engagementView!,
                      onSend: _sendComment,
                      onDelete: _deleteComment,
                      onReport: _reportComment,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + keyboardInset),
      child: SizedBox(
        height: targetHeight,
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mediaHeight = math.min(
                  constraints.maxWidth,
                  math.max(
                    150.0,
                    constraints.maxHeight *
                        (_engagementView == null ? 0.64 : 0.46),
                  ),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: mediaHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: PageView.builder(
                              itemCount: media.length,
                              onPageChanged: (index) =>
                                  setState(() => _mediaIndex = index),
                              itemBuilder: (context, index) {
                                final item = media[index];
                                if (widget.isDemo) {
                                  return widget.demoMediaBuilder(post, item);
                                }
                                return _PostMediaView(media: item);
                              },
                            ),
                          ),
                          Positioned(
                            left: 9,
                            right: 9,
                            top: 9,
                            child: _PostHeader(
                              name: widget.ownerDisplayName,
                              photoUrl: widget.ownerPhotoUrl,
                              onClose: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (media.length > 1) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          '${_mediaIndex + 1} / ${media.length}',
                          style: const TextStyle(
                            color: CaRismaDesignTokens.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    if (post.caption?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 9),
                      Text(
                        post.caption!.trim(),
                        maxLines: _engagementView == null ? 4 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    _PostInteractionRow(
                      repository: widget.repository,
                      post: post,
                      userId: widget.viewerUserId,
                      isDemo: widget.isDemo,
                      likesVisible:
                          _engagementView == ProfilePostEngagementView.likes,
                      commentsVisible:
                          _engagementView == ProfilePostEngagementView.comments,
                      onLike: _toggleLike,
                      onLikes: () =>
                          _showEngagement(ProfilePostEngagementView.likes),
                      onComments: () =>
                          _showEngagement(ProfilePostEngagementView.comments),
                      onShare: widget.onShare,
                      isOwner: widget.isOwner && !widget.isDemo,
                      isPinned: post.isPinned,
                      onEdit: widget.onEdit,
                      onTogglePin: widget.onTogglePin,
                      onArchive: widget.onArchive,
                      onDelete: widget.onDelete,
                      locationLabel: post.locationLabel,
                    ),
                    if (_engagementView != null) ...[
                      const SizedBox(height: 9),
                      Expanded(
                        child: _CommentsPanel(
                          repository: widget.repository,
                          post: post,
                          isDemo: widget.isDemo,
                          isPostOwner: widget.isOwner,
                          viewerUserId: widget.viewerUserId,
                          viewerDisplayName: widget.viewerDisplayName,
                          viewerPhotoUrl: widget.viewerPhotoUrl,
                          controller: _commentController,
                          demoComments: _demoComments,
                          isSending: _isSendingComment,
                          view: _engagementView!,
                          onSend: _sendComment,
                          onDelete: _deleteComment,
                          onReport: _reportComment,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.name,
    required this.photoUrl,
    required this.onClose,
  });

  final String name;
  final String photoUrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PostAvatar(name: name, photoUrl: photoUrl, radius: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Schließen',
          onPressed: onClose,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

enum _PostOwnerAction { edit, pin, archive, delete }

class _PostMenuRow extends StatelessWidget {
  const _PostMenuRow({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFEF4444) : Colors.white;
    return Row(
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _PostOwnerMenu extends StatelessWidget {
  const _PostOwnerMenu({
    required this.isPinned,
    required this.onEdit,
    required this.onTogglePin,
    required this.onArchive,
    required this.onDelete,
  });

  final bool isPinned;
  final VoidCallback onEdit;
  final VoidCallback onTogglePin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PostOwnerAction>(
      tooltip: 'Beitrag verwalten',
      color: CaRismaDesignTokens.surface1,
      surfaceTintColor: Colors.transparent,
      splashRadius: 22,
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      onSelected: (action) {
        switch (action) {
          case _PostOwnerAction.edit:
            onEdit();
          case _PostOwnerAction.pin:
            onTogglePin();
          case _PostOwnerAction.archive:
            onArchive();
          case _PostOwnerAction.delete:
            onDelete();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _PostOwnerAction.edit,
          child: _PostMenuRow(icon: Icons.edit_rounded, label: 'Bearbeiten'),
        ),
        PopupMenuItem(
          value: _PostOwnerAction.pin,
          child: _PostMenuRow(
            icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
            label: isPinned ? 'Lösen' : 'Oben anpinnen',
          ),
        ),
        const PopupMenuItem(
          value: _PostOwnerAction.archive,
          child: _PostMenuRow(
            icon: Icons.archive_outlined,
            label: 'Archivieren',
          ),
        ),
        const PopupMenuItem(
          value: _PostOwnerAction.delete,
          child: _PostMenuRow(
            icon: Icons.delete_outline_rounded,
            label: 'Löschen',
            destructive: true,
          ),
        ),
      ],
    );
  }
}

class _PostAvatar extends StatelessWidget {
  const _PostAvatar({
    required this.name,
    required this.photoUrl,
    this.radius = 21,
  });

  final String name;
  final String photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: CaRismaDesignTokens.surface2,
      foregroundImage: photoUrl.trim().isEmpty ? null : NetworkImage(photoUrl),
      child: photoUrl.trim().isEmpty
          ? Icon(Icons.person_rounded, color: Colors.white, size: radius * 1.1)
          : null,
    );
  }
}

class _PostMediaView extends StatefulWidget {
  const _PostMediaView({required this.media});

  final SocialPostMedia media;

  @override
  State<_PostMediaView> createState() => _PostMediaViewState();
}

class _PostMediaViewState extends State<_PostMediaView> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.media.isVideo) {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.media.url))
            ..initialize().then((_) {
              if (mounted) setState(() {});
            });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.media.isVideo) {
      return Image.network(
        widget.media.url,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (_, _, _) => const _BrokenMedia(),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: CaRismaDesignTokens.surface2,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        Center(
          child: IconButton.filled(
            onPressed: () {
              controller.value.isPlaying
                  ? controller.pause()
                  : controller.play();
              setState(() {});
            },
            icon: Icon(
              controller.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 8,
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: CaRismaDesignTokens.blueBright,
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrokenMedia extends StatelessWidget {
  const _BrokenMedia();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: CaRismaDesignTokens.surface2,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: CaRismaDesignTokens.textMuted,
          size: 32,
        ),
      ),
    );
  }
}

class _PostInteractionRow extends StatelessWidget {
  const _PostInteractionRow({
    required this.repository,
    required this.post,
    required this.userId,
    required this.isDemo,
    required this.likesVisible,
    required this.commentsVisible,
    required this.onLike,
    required this.onLikes,
    required this.onComments,
    required this.onShare,
    required this.isOwner,
    required this.isPinned,
    required this.onEdit,
    required this.onTogglePin,
    required this.onArchive,
    required this.onDelete,
    required this.locationLabel,
  });

  final SocialPostRepository repository;
  final SocialPost post;
  final String userId;
  final bool isDemo;
  final bool likesVisible;
  final bool commentsVisible;
  final VoidCallback onLike;
  final VoidCallback onLikes;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final bool isOwner;
  final bool isPinned;
  final VoidCallback onEdit;
  final VoidCallback onTogglePin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final String? locationLabel;

  @override
  Widget build(BuildContext context) {
    if (isDemo) {
      return _InteractionButtons(
        likeCount: 5,
        commentCount: 5,
        liked: false,
        likesVisible: likesVisible,
        commentsVisible: commentsVisible,
        onLike: onLike,
        onLikes: onLikes,
        onComments: onComments,
        onShare: onShare,
        isOwner: isOwner,
        isPinned: isPinned,
        onEdit: onEdit,
        onTogglePin: onTogglePin,
        onArchive: onArchive,
        onDelete: onDelete,
        locationLabel: locationLabel,
      );
    }
    return StreamBuilder<int>(
      stream: repository.watchLikeCount(post),
      initialData: 0,
      builder: (context, likesSnapshot) {
        return StreamBuilder<bool>(
          stream: repository.watchLikedBy(post: post, userId: userId),
          initialData: false,
          builder: (context, likedSnapshot) {
            return StreamBuilder<List<SocialPostComment>>(
              stream: repository.watchComments(post),
              initialData: const <SocialPostComment>[],
              builder: (context, commentsSnapshot) => _InteractionButtons(
                likeCount: likesSnapshot.data ?? 0,
                commentCount: commentsSnapshot.data?.length ?? 0,
                liked: likedSnapshot.data ?? false,
                likesVisible: likesVisible,
                commentsVisible: commentsVisible,
                onLike: onLike,
                onLikes: onLikes,
                onComments: onComments,
                onShare: onShare,
                isOwner: isOwner,
                isPinned: isPinned,
                onEdit: onEdit,
                onTogglePin: onTogglePin,
                onArchive: onArchive,
                onDelete: onDelete,
                locationLabel: locationLabel,
              ),
            );
          },
        );
      },
    );
  }
}

class _InteractionButtons extends StatelessWidget {
  const _InteractionButtons({
    required this.likeCount,
    required this.commentCount,
    required this.liked,
    required this.likesVisible,
    required this.commentsVisible,
    required this.onLike,
    required this.onLikes,
    required this.onComments,
    required this.onShare,
    required this.isOwner,
    required this.isPinned,
    required this.onEdit,
    required this.onTogglePin,
    required this.onArchive,
    required this.onDelete,
    required this.locationLabel,
  });

  final int likeCount;
  final int commentCount;
  final bool liked;
  final bool likesVisible;
  final bool commentsVisible;
  final VoidCallback onLike;
  final VoidCallback onLikes;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final bool isOwner;
  final bool isPinned;
  final VoidCallback onEdit;
  final VoidCallback onTogglePin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final String? locationLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CountAction(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          count: likeCount,
          active: liked || likesVisible,
          tooltip: 'Gefällt mir',
          onTap: onLikes,
          onIconTap: onLike,
        ),
        const SizedBox(width: 8),
        _CountAction(
          icon: commentsVisible
              ? Icons.chat_bubble_rounded
              : Icons.chat_bubble_outline_rounded,
          count: commentCount,
          active: commentsVisible,
          tooltip: 'Kommentare',
          onTap: onComments,
        ),
        if (isOwner)
          _PostOwnerMenu(
            isPinned: isPinned,
            onEdit: onEdit,
            onTogglePin: onTogglePin,
            onArchive: onArchive,
            onDelete: onDelete,
          ),
        if (locationLabel?.trim().isNotEmpty ?? false) ...[
          const SizedBox(width: 8),
          Expanded(child: _PostLocationChip(label: locationLabel!.trim())),
        ] else
          const Spacer(),
        IconButton(
          tooltip: 'Beitrag teilen',
          onPressed: onShare,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          icon: const Icon(Icons.share_outlined, color: Colors.white),
        ),
      ],
    );
  }
}

class _PostLocationChip extends StatelessWidget {
  const _PostLocationChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 104,
        maxWidth: 190,
        minHeight: 40,
      ),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: CaRismaDesignTokens.blueBright,
            size: 17,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountAction extends StatelessWidget {
  const _CountAction({
    required this.icon,
    required this.count,
    required this.active,
    required this.tooltip,
    required this.onTap,
    this.onIconTap,
  });

  final IconData icon;
  final int count;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback? onIconTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: CaRismaDesignTokens.controlSurface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: active
                  ? CaRismaDesignTokens.bluePrimary
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onIconTap,
                child: SizedBox.square(
                  dimension: 36,
                  child: Center(
                    child: Icon(
                      icon,
                      size: 19,
                      color: active
                          ? CaRismaDesignTokens.blueBright
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
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

class _CommentsPanel extends StatelessWidget {
  const _CommentsPanel({
    required this.repository,
    required this.post,
    required this.isDemo,
    required this.isPostOwner,
    required this.viewerUserId,
    required this.viewerDisplayName,
    required this.viewerPhotoUrl,
    required this.controller,
    required this.demoComments,
    required this.isSending,
    required this.view,
    required this.onSend,
    required this.onDelete,
    required this.onReport,
  });

  final SocialPostRepository repository;
  final SocialPost post;
  final bool isDemo;
  final bool isPostOwner;
  final String viewerUserId;
  final String viewerDisplayName;
  final String viewerPhotoUrl;
  final TextEditingController controller;
  final List<SocialPostComment> demoComments;
  final bool isSending;
  final ProfilePostEngagementView view;
  final VoidCallback onSend;
  final ValueChanged<SocialPostComment> onDelete;
  final ValueChanged<SocialPostComment> onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildScrollableContent()),
          if (view == ProfilePostEngagementView.comments) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLength: 500,
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: const InputDecoration(
                      hintText: 'Kommentar schreiben',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: 'Kommentar senden',
                  onPressed: isSending ? null : onSend,
                  style: IconButton.styleFrom(
                    foregroundColor: CaRismaDesignTokens.blueBright,
                    side: const BorderSide(
                      color: CaRismaDesignTokens.bluePrimary,
                      width: 1.4,
                    ),
                  ),
                  icon: isSending
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScrollableContent() {
    if (view == ProfilePostEngagementView.likes) {
      if (isDemo) {
        return _LikesList(repository: repository, likes: _demoLikes);
      }
      return StreamBuilder<List<SocialPostLike>>(
        stream: repository.watchLikes(post),
        initialData: const <SocialPostLike>[],
        builder: (context, snapshot) => _LikesList(
          repository: repository,
          likes: snapshot.data ?? const <SocialPostLike>[],
        ),
      );
    }
    if (isDemo) {
      return _CommentsList(
        repository: repository,
        post: post,
        comments: demoComments,
        viewerUserId: viewerUserId,
        viewerDisplayName: viewerDisplayName,
        viewerPhotoUrl: viewerPhotoUrl,
        isDemo: true,
        isPostOwner: isPostOwner,
        onDelete: onDelete,
        onReport: onReport,
      );
    }
    return StreamBuilder<List<SocialPostComment>>(
      stream: repository.watchComments(post),
      initialData: const <SocialPostComment>[],
      builder: (context, snapshot) => _CommentsList(
        repository: repository,
        post: post,
        comments: snapshot.data ?? const <SocialPostComment>[],
        viewerUserId: viewerUserId,
        viewerDisplayName: viewerDisplayName,
        viewerPhotoUrl: viewerPhotoUrl,
        isDemo: false,
        isPostOwner: isPostOwner,
        onDelete: onDelete,
        onReport: onReport,
      ),
    );
  }
}

class _CommentsList extends StatelessWidget {
  const _CommentsList({
    required this.repository,
    required this.post,
    required this.comments,
    required this.viewerUserId,
    required this.viewerDisplayName,
    required this.viewerPhotoUrl,
    required this.isDemo,
    required this.isPostOwner,
    required this.onDelete,
    required this.onReport,
  });

  final SocialPostRepository repository;
  final SocialPost post;
  final List<SocialPostComment> comments;
  final String viewerUserId;
  final String viewerDisplayName;
  final String viewerPhotoUrl;
  final bool isDemo;
  final bool isPostOwner;
  final ValueChanged<SocialPostComment> onDelete;
  final ValueChanged<SocialPostComment> onReport;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const Center(
        child: Text(
          'Noch keine Kommentare.',
          style: TextStyle(
            color: CaRismaDesignTokens.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return _CommentTile(
          repository: repository,
          post: post,
          comment: comment,
          viewerUserId: viewerUserId,
          viewerDisplayName: viewerDisplayName,
          viewerPhotoUrl: viewerPhotoUrl,
          isDemo: isDemo,
          canDelete: isPostOwner || comment.authorUserId == viewerUserId,
          onDelete: () => onDelete(comment),
          onReport: () => onReport(comment),
        );
      },
    );
  }
}

class _CommentTile extends StatefulWidget {
  const _CommentTile({
    required this.repository,
    required this.post,
    required this.comment,
    required this.viewerUserId,
    required this.viewerDisplayName,
    required this.viewerPhotoUrl,
    required this.isDemo,
    required this.canDelete,
    required this.onDelete,
    required this.onReport,
  });

  final SocialPostRepository repository;
  final SocialPost post;
  final SocialPostComment comment;
  final String viewerUserId;
  final String viewerDisplayName;
  final String viewerPhotoUrl;
  final bool isDemo;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  SocialPostCommentReaction? _demoReaction;
  late final List<SocialPostCommentReply> _demoReplies;
  bool _showReplyComposer = false;
  bool _showAllReplies = false;
  bool _isSendingReply = false;
  final Map<SocialPostCommentReaction, int> _demoCounts = {
    SocialPostCommentReaction.like: 2,
    SocialPostCommentReaction.dislike: 0,
    SocialPostCommentReaction.heart: 1,
  };

  @override
  void initState() {
    super.initState();
    _demoReplies = widget.comment.id == 'demo-comment-mila'
        ? <SocialPostCommentReply>[
            SocialPostCommentReply(
              id: 'demo-reply-emre',
              commentId: widget.comment.id,
              postId: widget.post.id,
              postOwnerUserId: widget.post.ownerUserId,
              authorUserId: 'demo-like-emre',
              authorDisplayName: 'Emre A.',
              authorPhotoUrl: '',
              text: 'Finde ich auch, besonders mit den Felgen.',
              createdAt: DateTime(2026, 8, 17, 18, 45),
              isDeleted: false,
            ),
            SocialPostCommentReply(
              id: 'demo-reply-aylin',
              commentId: widget.comment.id,
              postId: widget.post.id,
              postOwnerUserId: widget.post.ownerUserId,
              authorUserId: 'demo-like-aylin',
              authorDisplayName: 'Aylin D.',
              authorPhotoUrl: '',
              text: 'Die Farbe wirkt auf dem Bild richtig stark.',
              createdAt: DateTime(2026, 8, 17, 18, 47),
              isDeleted: false,
            ),
            SocialPostCommentReply(
              id: 'demo-reply-jonas',
              commentId: widget.comment.id,
              postId: widget.post.id,
              postOwnerUserId: widget.post.ownerUserId,
              authorUserId: 'demo-like-jonas',
              authorDisplayName: 'Jonas R.',
              authorPhotoUrl: '',
              text: 'Ein sehr sauberer Auftritt.',
              createdAt: DateTime(2026, 8, 17, 18, 49),
              isDeleted: false,
            ),
          ]
        : <SocialPostCommentReply>[];
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  void _openReplyComposer() {
    setState(() => _showReplyComposer = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _replyFocusNode.requestFocus();
    });
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isSendingReply) return;
    if (widget.isDemo) {
      setState(() {
        _demoReplies.add(
          SocialPostCommentReply(
            id: 'demo-reply-${DateTime.now().microsecondsSinceEpoch}',
            commentId: widget.comment.id,
            postId: widget.post.id,
            postOwnerUserId: widget.post.ownerUserId,
            authorUserId: widget.viewerUserId,
            authorDisplayName: widget.viewerDisplayName,
            authorPhotoUrl: widget.viewerPhotoUrl,
            text: text,
            createdAt: DateTime.now(),
            isDeleted: false,
          ),
        );
        _showAllReplies = true;
        _replyController.clear();
      });
      _replyFocusNode.unfocus();
      return;
    }
    setState(() => _isSendingReply = true);
    try {
      await widget.repository.addCommentReply(
        post: widget.post,
        comment: widget.comment,
        authorUserId: widget.viewerUserId,
        authorDisplayName: widget.viewerDisplayName,
        authorPhotoUrl: widget.viewerPhotoUrl,
        text: text,
      );
      _replyController.clear();
      _replyFocusNode.unfocus();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Antwort konnte gerade nicht gespeichert werden.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingReply = false);
    }
  }

  Future<void> _deleteReply(SocialPostCommentReply reply) async {
    if (widget.isDemo) {
      setState(() => _demoReplies.removeWhere((item) => item.id == reply.id));
      return;
    }
    try {
      await widget.repository.deleteCommentReply(
        post: widget.post,
        comment: widget.comment,
        reply: reply,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Antwort konnte nicht gelöscht werden.')),
      );
    }
  }

  Future<void> _reportReply(SocialPostCommentReply reply) async {
    if (widget.isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beispielantwort wurde gemeldet.')),
      );
      return;
    }
    try {
      await widget.repository.reportCommentReply(
        post: widget.post,
        comment: widget.comment,
        reply: reply,
        reporterUserId: widget.viewerUserId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Antwort wurde gemeldet.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Antwort konnte nicht gemeldet werden.')),
      );
    }
  }

  Future<void> _react(SocialPostCommentReaction reaction) async {
    if (widget.isDemo) {
      setState(() {
        if (_demoReaction != null) {
          _demoCounts[_demoReaction!] = math.max(
            0,
            (_demoCounts[_demoReaction!] ?? 0) - 1,
          );
        }
        if (_demoReaction == reaction) {
          _demoReaction = null;
        } else {
          _demoReaction = reaction;
          _demoCounts[reaction] = (_demoCounts[reaction] ?? 0) + 1;
        }
      });
      return;
    }
    try {
      await widget.repository.setCommentReaction(
        post: widget.post,
        comment: widget.comment,
        userId: widget.viewerUserId,
        reaction: reaction,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reaktion konnte gerade nicht gespeichert werden.'),
        ),
      );
    }
  }

  Widget _buildReplies(List<SocialPostCommentReply> replies) {
    if (replies.isEmpty) return const SizedBox.shrink();
    final visibleReplies = _showAllReplies
        ? replies
        : replies.take(2).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 12, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final reply in visibleReplies)
            _CommentReplyTile(
              repository: widget.repository,
              reply: reply,
              canDelete:
                  widget.canDelete || reply.authorUserId == widget.viewerUserId,
              onDelete: () => _deleteReply(reply),
              onReport: () => _reportReply(reply),
            ),
          if (replies.length > 2)
            TextButton(
              onPressed: () =>
                  setState(() => _showAllReplies = !_showAllReplies),
              style: TextButton.styleFrom(
                foregroundColor: CaRismaDesignTokens.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _showAllReplies
                    ? 'Weniger Antworten anzeigen'
                    : '${replies.length - 2} weitere Antworten anzeigen',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyComposer(String recipientName) {
    if (!_showReplyComposer) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              focusNode: _replyFocusNode,
              maxLength: 500,
              minLines: 1,
              maxLines: 2,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendReply(),
              decoration: InputDecoration(
                hintText: 'Antwort an $recipientName',
                counterText: '',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            tooltip: 'Antwort senden',
            onPressed: _isSendingReply ? null : _sendReply,
            style: IconButton.styleFrom(
              foregroundColor: CaRismaDesignTokens.blueBright,
              side: const BorderSide(
                color: CaRismaDesignTokens.bluePrimary,
                width: 1.3,
              ),
            ),
            icon: _isSendingReply
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SocialPostPublicIdentity>(
      stream: widget.repository.watchPublicIdentity(
        userId: widget.comment.authorUserId,
        fallbackDisplayName: widget.comment.authorDisplayName,
        fallbackPhotoUrl: widget.comment.authorPhotoUrl,
      ),
      initialData: SocialPostPublicIdentity(
        displayName: widget.comment.authorDisplayName,
        photoUrl: widget.comment.authorPhotoUrl,
      ),
      builder: (context, identitySnapshot) {
        final identity =
            identitySnapshot.data ??
            SocialPostPublicIdentity(
              displayName: widget.comment.authorDisplayName.trim().isEmpty
                  ? 'plaqa Nutzer'
                  : widget.comment.authorDisplayName.trim(),
              photoUrl: widget.comment.authorPhotoUrl.trim(),
            );
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PostAvatar(
                        name: identity.displayName,
                        photoUrl: identity.photoUrl,
                        radius: 18,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 34),
                              child: Text(
                                identity.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.comment.text,
                              style: const TextStyle(
                                color: CaRismaDesignTokens.textSecondary,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 7),
                            if (widget.isDemo)
                              _CommentReactionBar(
                                counts: _demoCounts,
                                selected: _demoReaction,
                                onSelected: _react,
                              )
                            else
                              StreamBuilder<
                                Map<SocialPostCommentReaction, int>
                              >(
                                stream: widget.repository
                                    .watchCommentReactionCounts(
                                      post: widget.post,
                                      comment: widget.comment,
                                    ),
                                initialData:
                                    const <SocialPostCommentReaction, int>{},
                                builder: (context, countsSnapshot) =>
                                    StreamBuilder<SocialPostCommentReaction?>(
                                      stream: widget.repository
                                          .watchCommentReactionForViewer(
                                            post: widget.post,
                                            comment: widget.comment,
                                            viewerUserId: widget.viewerUserId,
                                          ),
                                      builder: (context, viewerSnapshot) =>
                                          _CommentReactionBar(
                                            counts:
                                                countsSnapshot.data ??
                                                const <
                                                  SocialPostCommentReaction,
                                                  int
                                                >{},
                                            selected: viewerSnapshot.data,
                                            onSelected: _react,
                                          ),
                                    ),
                              ),
                            TextButton(
                              onPressed: _openReplyComposer,
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    CaRismaDesignTokens.textSecondary,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Antworten',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: -8,
                    right: -4,
                    child: PopupMenuButton<String>(
                      tooltip: 'Kommentaroptionen',
                      color: CaRismaDesignTokens.surface1,
                      surfaceTintColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      child: const SizedBox.square(
                        dimension: 34,
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: CaRismaDesignTokens.textMuted,
                          size: 19,
                        ),
                      ),
                      onSelected: (value) => value == 'delete'
                          ? widget.onDelete()
                          : widget.onReport(),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'report',
                          child: Text('Melden'),
                        ),
                        if (widget.canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Löschen',
                              style: TextStyle(color: Color(0xFFEF4444)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.isDemo)
                _buildReplies(_demoReplies)
              else
                StreamBuilder<List<SocialPostCommentReply>>(
                  stream: widget.repository.watchCommentReplies(
                    post: widget.post,
                    comment: widget.comment,
                  ),
                  initialData: const <SocialPostCommentReply>[],
                  builder: (context, snapshot) => _buildReplies(
                    snapshot.data ?? const <SocialPostCommentReply>[],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 45),
                child: _buildReplyComposer(identity.displayName),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentReplyTile extends StatelessWidget {
  const _CommentReplyTile({
    required this.repository,
    required this.reply,
    required this.canDelete,
    required this.onDelete,
    required this.onReport,
  });

  final SocialPostRepository repository;
  final SocialPostCommentReply reply;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SocialPostPublicIdentity>(
      stream: repository.watchPublicIdentity(
        userId: reply.authorUserId,
        fallbackDisplayName: reply.authorDisplayName,
        fallbackPhotoUrl: reply.authorPhotoUrl,
      ),
      initialData: SocialPostPublicIdentity(
        displayName: reply.authorDisplayName,
        photoUrl: reply.authorPhotoUrl,
      ),
      builder: (context, snapshot) {
        final identity =
            snapshot.data ??
            SocialPostPublicIdentity(
              displayName: reply.authorDisplayName,
              photoUrl: reply.authorPhotoUrl,
            );
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostAvatar(
                name: identity.displayName,
                photoUrl: identity.photoUrl,
                radius: 12,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      identity.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reply.text,
                      style: const TextStyle(
                        color: CaRismaDesignTokens.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Antwortoptionen',
                color: CaRismaDesignTokens.surface1,
                surfaceTintColor: Colors.transparent,
                padding: EdgeInsets.zero,
                child: const SizedBox.square(
                  dimension: 26,
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: CaRismaDesignTokens.textMuted,
                    size: 17,
                  ),
                ),
                onSelected: (value) =>
                    value == 'delete' ? onDelete() : onReport(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'report', child: Text('Melden')),
                  if (canDelete)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Löschen',
                        style: TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentReactionBar extends StatelessWidget {
  const _CommentReactionBar({
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  final Map<SocialPostCommentReaction, int> counts;
  final SocialPostCommentReaction? selected;
  final ValueChanged<SocialPostCommentReaction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        _CommentReactionButton(
          icon: Icons.thumb_up_alt_outlined,
          count: counts[SocialPostCommentReaction.like] ?? 0,
          selected: selected == SocialPostCommentReaction.like,
          onTap: () => onSelected(SocialPostCommentReaction.like),
        ),
        _CommentReactionButton(
          icon: Icons.thumb_down_alt_outlined,
          count: counts[SocialPostCommentReaction.dislike] ?? 0,
          selected: selected == SocialPostCommentReaction.dislike,
          onTap: () => onSelected(SocialPostCommentReaction.dislike),
        ),
        _CommentReactionButton(
          icon: selected == SocialPostCommentReaction.heart
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          count: counts[SocialPostCommentReaction.heart] ?? 0,
          selected: selected == SocialPostCommentReaction.heart,
          onTap: () => onSelected(SocialPostCommentReaction.heart),
        ),
      ],
    );
  }
}

class _CommentReactionButton extends StatelessWidget {
  const _CommentReactionButton({
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected
                  ? CaRismaDesignTokens.blueBright
                  : CaRismaDesignTokens.textSecondary,
            ),
            if (count > 0) ...[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? CaRismaDesignTokens.blueBright
                      : CaRismaDesignTokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LikesList extends StatelessWidget {
  const _LikesList({required this.repository, required this.likes});

  final SocialPostRepository repository;
  final List<SocialPostLike> likes;

  @override
  Widget build(BuildContext context) {
    if (likes.isEmpty) {
      return const Center(
        child: Text(
          'Noch keine Likes.',
          style: TextStyle(
            color: CaRismaDesignTokens.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: likes.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
      itemBuilder: (context, index) {
        final like = likes[index];
        return StreamBuilder<SocialPostPublicIdentity>(
          stream: repository.watchPublicIdentity(
            userId: like.userId,
            fallbackDisplayName: like.displayName,
            fallbackPhotoUrl: like.photoUrl,
          ),
          initialData: SocialPostPublicIdentity(
            displayName: like.displayName,
            photoUrl: like.photoUrl,
          ),
          builder: (context, identitySnapshot) {
            final identity =
                identitySnapshot.data ??
                SocialPostPublicIdentity(
                  displayName: like.displayName.trim().isEmpty
                      ? 'plaqa Nutzer'
                      : like.displayName.trim(),
                  photoUrl: like.photoUrl.trim(),
                );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  _PostAvatar(
                    name: identity.displayName,
                    photoUrl: identity.photoUrl,
                    radius: 19,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      identity.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.favorite_rounded,
                    color: CaRismaDesignTokens.blueBright,
                    size: 18,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
