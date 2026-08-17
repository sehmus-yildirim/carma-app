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

  @override
  State<ProfilePostDetailsSheet> createState() =>
      _ProfilePostDetailsSheetState();
}

class _ProfilePostDetailsSheetState extends State<ProfilePostDetailsSheet> {
  final TextEditingController _commentController = TextEditingController();
  late final List<SocialPostComment> _demoComments;
  int _mediaIndex = 0;
  _PostEngagementView? _engagementView;
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _demoComments = _buildDemoComments(widget.post);
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

  void _showEngagement(_PostEngagementView view) {
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
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
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
                                      return widget.demoMediaBuilder(
                                        post,
                                        item,
                                      );
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
                          const SizedBox(height: 8),
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
                          const SizedBox(height: 12),
                          Text(
                            post.caption!.trim(),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _PostInteractionRow(
                          repository: widget.repository,
                          post: post,
                          userId: widget.viewerUserId,
                          isDemo: widget.isDemo,
                          likesVisible:
                              _engagementView == _PostEngagementView.likes,
                          commentsVisible:
                              _engagementView == _PostEngagementView.comments,
                          onLike: _toggleLike,
                          onLikes: () =>
                              _showEngagement(_PostEngagementView.likes),
                          onComments: () =>
                              _showEngagement(_PostEngagementView.comments),
                          onShare: widget.onShare,
                          isOwner: widget.isOwner && !widget.isDemo,
                          isPinned: post.isPinned,
                          onEdit: widget.onEdit,
                          onTogglePin: widget.onTogglePin,
                          onArchive: widget.onArchive,
                          onDelete: widget.onDelete,
                        ),
                        if (_engagementView != null) ...[
                          const SizedBox(height: 12),
                          _CommentsPanel(
                            repository: widget.repository,
                            post: post,
                            isDemo: widget.isDemo,
                            isPostOwner: widget.isOwner,
                            viewerUserId: widget.viewerUserId,
                            controller: _commentController,
                            demoComments: _demoComments,
                            isSending: _isSendingComment,
                            view: _engagementView!,
                            onSend: _sendComment,
                            onDelete: _deleteComment,
                            onReport: _reportComment,
                          ),
                        ],
                        if (post.locationLabel?.trim().isNotEmpty ?? false) ...[
                          const SizedBox(height: 10),
                          _PostInfoTile(
                            icon: Icons.location_on_outlined,
                            label: post.locationLabel!.trim(),
                          ),
                        ],
                      ],
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

enum _PostEngagementView { likes, comments }

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

  @override
  Widget build(BuildContext context) {
    if (isDemo) {
      return _InteractionButtons(
        likeCount: 18,
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
        const Spacer(),
        if (isOwner)
          _PostOwnerMenu(
            isPinned: isPinned,
            onEdit: onEdit,
            onTogglePin: onTogglePin,
            onArchive: onArchive,
            onDelete: onDelete,
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
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
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    icon,
                    size: 19,
                    color: active
                        ? CaRismaDesignTokens.blueBright
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
  final TextEditingController controller;
  final List<SocialPostComment> demoComments;
  final bool isSending;
  final _PostEngagementView view;
  final VoidCallback onSend;
  final ValueChanged<SocialPostComment> onDelete;
  final ValueChanged<SocialPostComment> onReport;

  @override
  Widget build(BuildContext context) {
    final commentsStream = isDemo ? null : repository.watchComments(post);
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
          if (view == _PostEngagementView.likes)
            if (isDemo)
              _LikesList(likes: _demoLikes)
            else
              StreamBuilder<List<SocialPostLike>>(
                stream: repository.watchLikes(post),
                initialData: const <SocialPostLike>[],
                builder: (context, snapshot) => _LikesList(
                  likes: snapshot.data ?? const <SocialPostLike>[],
                ),
              )
          else ...[
            if (isDemo)
              Column(
                children: demoComments
                    .map(
                      (comment) => _CommentTile(
                        repository: repository,
                        post: post,
                        comment: comment,
                        viewerUserId: viewerUserId,
                        isDemo: true,
                        canDelete:
                            isPostOwner || comment.authorUserId == viewerUserId,
                        onDelete: () => onDelete(comment),
                        onReport: () => onReport(comment),
                      ),
                    )
                    .toList(growable: false),
              )
            else
              StreamBuilder<List<SocialPostComment>>(
                stream: commentsStream,
                initialData: const <SocialPostComment>[],
                builder: (context, snapshot) {
                  final comments = snapshot.data ?? const <SocialPostComment>[];
                  if (comments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Noch keine Kommentare.',
                        style: TextStyle(
                          color: CaRismaDesignTokens.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: comments
                        .map(
                          (comment) => _CommentTile(
                            repository: repository,
                            post: post,
                            comment: comment,
                            viewerUserId: viewerUserId,
                            isDemo: false,
                            canDelete:
                                isPostOwner ||
                                comment.authorUserId == viewerUserId,
                            onDelete: () => onDelete(comment),
                            onReport: () => onReport(comment),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
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
}

class _CommentTile extends StatefulWidget {
  const _CommentTile({
    required this.repository,
    required this.post,
    required this.comment,
    required this.viewerUserId,
    required this.isDemo,
    required this.canDelete,
    required this.onDelete,
    required this.onReport,
  });

  final SocialPostRepository repository;
  final SocialPost post;
  final SocialPostComment comment;
  final String viewerUserId;
  final bool isDemo;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  SocialPostCommentReaction? _demoReaction;
  final Map<SocialPostCommentReaction, int> _demoCounts = {
    SocialPostCommentReaction.like: 2,
    SocialPostCommentReaction.dislike: 0,
    SocialPostCommentReaction.heart: 1,
  };

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostAvatar(
            name: widget.comment.authorDisplayName,
            photoUrl: widget.comment.authorPhotoUrl,
            radius: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.comment.authorDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
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
                  StreamBuilder<Map<SocialPostCommentReaction, int>>(
                    stream: widget.repository.watchCommentReactionCounts(
                      post: widget.post,
                      comment: widget.comment,
                    ),
                    initialData: const <SocialPostCommentReaction, int>{},
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
                                    const <SocialPostCommentReaction, int>{},
                                selected: viewerSnapshot.data,
                                onSelected: _react,
                              ),
                        ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Kommentaroptionen',
            color: CaRismaDesignTokens.surface1,
            surfaceTintColor: Colors.transparent,
            icon: const Icon(
              Icons.more_vert_rounded,
              color: CaRismaDesignTokens.textMuted,
              size: 19,
            ),
            onSelected: (value) =>
                value == 'delete' ? widget.onDelete() : widget.onReport(),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'report', child: Text('Melden')),
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
        ],
      ),
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
  const _LikesList({required this.likes});

  final List<SocialPostLike> likes;

  @override
  Widget build(BuildContext context) {
    if (likes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Noch keine Likes.',
          style: TextStyle(
            color: CaRismaDesignTokens.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: likes.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
        itemBuilder: (context, index) {
          final like = likes[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                _PostAvatar(
                  name: like.displayName,
                  photoUrl: like.photoUrl,
                  radius: 19,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    like.displayName,
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
      ),
    );
  }
}

class _PostInfoTile extends StatelessWidget {
  const _PostInfoTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: CaRismaDesignTokens.blueBright, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
