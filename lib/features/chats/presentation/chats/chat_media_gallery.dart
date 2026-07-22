part of '../chats_screen.dart';

class _ChatMediaGalleryScreen extends StatefulWidget {
  const _ChatMediaGalleryScreen();

  @override
  State<_ChatMediaGalleryScreen> createState() =>
      _ChatMediaGalleryScreenState();
}

class _ChatMediaGalleryScreenState extends State<_ChatMediaGalleryScreen> {
  static const int _pageSize = 80;

  final ScrollController _scrollController = ScrollController();
  final List<AssetEntity> _assets = <AssetEntity>[];

  AssetPathEntity? _recentAlbum;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMediaAccess = false;
  bool _hasMore = true;
  int _nextPage = 0;
  String? _errorMessage;
  String? _selectedAssetId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearEnd);
    _loadGallery();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadGallery() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.common,
            mediaLocation: false,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      if (!permission.hasAccess) {
        setState(() {
          _hasMediaAccess = false;
          _isLoading = false;
        });
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.common,
      );
      final recentAlbum = albums.isEmpty ? null : albums.first;
      final assets = recentAlbum == null
          ? <AssetEntity>[]
          : await recentAlbum.getAssetListPaged(page: 0, size: _pageSize);

      if (!mounted) {
        return;
      }

      setState(() {
        _recentAlbum = recentAlbum;
        _assets
          ..clear()
          ..addAll(assets);
        _hasMediaAccess = true;
        _hasMore = assets.length == _pageSize;
        _nextPage = 1;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Deine Galerie konnte nicht geladen werden.';
      });
    }
  }

  void _loadMoreNearEnd() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 720) {
      return;
    }
    unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    final recentAlbum = _recentAlbum;
    if (recentAlbum == null || !_hasMore || _isLoadingMore || _isLoading) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextAssets = await recentAlbum.getAssetListPaged(
        page: _nextPage,
        size: _pageSize,
      );
      if (!mounted) {
        return;
      }

      final existingIds = _assets.map((asset) => asset.id).toSet();
      setState(() {
        _assets.addAll(nextAssets.where((asset) => existingIds.add(asset.id)));
        _hasMore = nextAssets.length == _pageSize;
        _nextPage += 1;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weitere Medien konnten nicht geladen werden.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _selectAsset(AssetEntity asset) async {
    if (_selectedAssetId != null) {
      return;
    }

    setState(() {
      _selectedAssetId = asset.id;
    });

    try {
      final file = await asset.file;
      if (!mounted) {
        return;
      }
      if (file == null) {
        throw StateError('Medium nicht verfügbar.');
      }

      Navigator.of(context).pop(
        _StoryCaptureResult(
          path: file.path,
          isVideo: asset.type == AssetType.video,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedAssetId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Das Medium konnte nicht geöffnet werden.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaRismaDesignTokens.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Schließen',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              color: CaRismaDesignTokens.textPrimary,
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Galerie',
                style: TextStyle(
                  color: CaRismaDesignTokens.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: CaRismaDesignTokens.bluePrimary,
        ),
      );
    }

    if (!_hasMediaAccess) {
      return _ChatGalleryMessage(
        icon: Icons.photo_library_outlined,
        title: 'Zugriff auf Fotos erlauben',
        message:
            'Erlaube CaRisma den Zugriff, damit deine Galerie direkt angezeigt werden kann.',
        actionLabel: 'Erneut versuchen',
        onAction: _loadGallery,
        secondaryActionLabel: 'Einstellungen öffnen',
        onSecondaryAction: () => PhotoManager.openSetting(),
      );
    }

    if (_errorMessage != null) {
      return _ChatGalleryMessage(
        icon: Icons.error_outline_rounded,
        title: 'Galerie nicht verfügbar',
        message: _errorMessage!,
        actionLabel: 'Erneut versuchen',
        onAction: _loadGallery,
      );
    }

    if (_assets.isEmpty) {
      return const _ChatGalleryMessage(
        icon: Icons.photo_library_outlined,
        title: 'Keine Medien gefunden',
        message: 'Auf deinem Gerät sind keine Fotos oder Videos verfügbar.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 118)
            .floor()
            .clamp(3, 6)
            .toInt();

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemCount: _assets.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _assets.length) {
              return const Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CaRismaDesignTokens.bluePrimary,
                  ),
                ),
              );
            }

            final asset = _assets[index];
            return _ChatGalleryTile(
              asset: asset,
              isSelecting: _selectedAssetId == asset.id,
              onTap: () => _selectAsset(asset),
            );
          },
        );
      },
    );
  }
}

class _ChatGalleryTile extends StatefulWidget {
  const _ChatGalleryTile({
    required this.asset,
    required this.isSelecting,
    required this.onTap,
  });

  final AssetEntity asset;
  final bool isSelecting;
  final VoidCallback onTap;

  @override
  State<_ChatGalleryTile> createState() => _ChatGalleryTileState();
}

class _ChatGalleryTileState extends State<_ChatGalleryTile> {
  late Future<Uint8List?> _thumbnail;

  @override
  void initState() {
    super.initState();
    _thumbnail = _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant _ChatGalleryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _thumbnail = _loadThumbnail();
    }
  }

  Future<Uint8List?> _loadThumbnail() {
    return widget.asset.thumbnailDataWithSize(
      const ThumbnailSize.square(320),
      quality: 88,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.asset.type == AssetType.video
          ? 'Video auswählen'
          : 'Foto auswählen',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isSelecting ? null : widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: CaRismaDesignTokens.surface1,
                child: FutureBuilder<Uint8List?>(
                  future: _thumbnail,
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    if (bytes == null) {
                      return const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: CaRismaDesignTokens.textMuted,
                        ),
                      );
                    }
                    return Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    );
                  },
                ),
              ),
              if (widget.asset.type == AssetType.video)
                Positioned(
                  right: 6,
                  bottom: 5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatGalleryDuration(widget.asset.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.isSelecting)
                const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
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

class _ChatGalleryMessage extends StatelessWidget {
  const _ChatGalleryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: CaRismaDesignTokens.bluePrimary),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CaRismaDesignTokens.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CaRismaDesignTokens.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: CaRismaDesignTokens.bluePrimary,
                  foregroundColor: Colors.white,
                ),
                child: Text(actionLabel!),
              ),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatGalleryDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
