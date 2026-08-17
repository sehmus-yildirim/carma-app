import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';

class ProfilePostGallerySelection {
  const ProfilePostGallerySelection({
    required this.path,
    required this.isVideo,
  });

  final String path;
  final bool isVideo;
}

class ProfilePostGalleryScreen extends StatefulWidget {
  const ProfilePostGalleryScreen({
    super.key,
    this.maxSelection = 10,
  });

  final int maxSelection;

  @override
  State<ProfilePostGalleryScreen> createState() =>
      _ProfilePostGalleryScreenState();
}

class _ProfilePostGalleryScreenState extends State<ProfilePostGalleryScreen> {
  static const int _pageSize = 80;

  final ScrollController _scrollController = ScrollController();
  final List<AssetEntity> _assets = <AssetEntity>[];
  final List<AssetEntity> _selected = <AssetEntity>[];

  AssetPathEntity? _recentAlbum;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isResolving = false;
  bool _hasMediaAccess = false;
  bool _hasMore = true;
  int _nextPage = 0;
  String? _errorMessage;

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.common,
            mediaLocation: false,
          ),
        ),
      );
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
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
    final album = _recentAlbum;
    if (album == null || !_hasMore || _isLoadingMore || _isLoading) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextAssets = await album.getAssetListPaged(
        page: _nextPage,
        size: _pageSize,
      );
      if (!mounted) return;
      final knownIds = _assets.map((asset) => asset.id).toSet();
      setState(() {
        _assets.addAll(nextAssets.where((asset) => knownIds.add(asset.id)));
        _hasMore = nextAssets.length == _pageSize;
        _nextPage += 1;
      });
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _toggleSelection(AssetEntity asset) {
    final index = _selected.indexWhere((selected) => selected.id == asset.id);
    if (index >= 0) {
      setState(() => _selected.removeAt(index));
      return;
    }
    if (_selected.length >= widget.maxSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Du kannst höchstens ${widget.maxSelection} Medien auswählen.',
          ),
        ),
      );
      return;
    }
    setState(() => _selected.add(asset));
  }

  Future<void> _finishSelection() async {
    if (_selected.isEmpty || _isResolving) return;
    setState(() => _isResolving = true);
    try {
      final result = <ProfilePostGallerySelection>[];
      for (final asset in _selected) {
        final file = await asset.file;
        if (file == null) continue;
        result.add(
          ProfilePostGallerySelection(
            path: file.path,
            isVideo: asset.type == AssetType.video,
          ),
        );
      }
      if (!mounted) return;
      if (result.isEmpty) {
        throw StateError('Ausgewählte Medien sind nicht verfügbar.');
      }
      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isResolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die ausgewählten Medien konnten nicht geöffnet werden.'),
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
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Schließen',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _selected.isEmpty
                            ? 'Galerie'
                            : '${_selected.length} ausgewählt',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _selected.isEmpty || _isResolving
                          ? null
                          : _finishSelection,
                      icon: _isResolving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('Hinzufügen'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildContent()),
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
      return _GalleryMessage(
        icon: Icons.photo_library_outlined,
        title: 'Zugriff auf Fotos erlauben',
        message: 'Erlaube plaqa den Zugriff, um deine Galerie anzuzeigen.',
        actionLabel: 'Erneut versuchen',
        onAction: _loadGallery,
        secondaryActionLabel: 'Einstellungen öffnen',
        onSecondaryAction: PhotoManager.openSetting,
      );
    }
    if (_errorMessage != null) {
      return _GalleryMessage(
        icon: Icons.error_outline_rounded,
        title: 'Galerie nicht verfügbar',
        message: _errorMessage!,
        actionLabel: 'Erneut versuchen',
        onAction: _loadGallery,
      );
    }
    if (_assets.isEmpty) {
      return const _GalleryMessage(
        icon: Icons.photo_library_outlined,
        title: 'Keine Medien gefunden',
        message: 'Auf deinem Gerät sind keine Fotos oder Videos verfügbar.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 118).floor().clamp(3, 7);
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemCount: _assets.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _assets.length) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            final asset = _assets[index];
            final selectedIndex = _selected.indexWhere(
              (selected) => selected.id == asset.id,
            );
            return _GalleryTile(
              asset: asset,
              selectionNumber: selectedIndex < 0 ? null : selectedIndex + 1,
              onTap: () => _toggleSelection(asset),
            );
          },
        );
      },
    );
  }
}

class _GalleryTile extends StatefulWidget {
  const _GalleryTile({
    required this.asset,
    required this.selectionNumber,
    required this.onTap,
  });

  final AssetEntity asset;
  final int? selectionNumber;
  final VoidCallback onTap;

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  late Future<Uint8List?> _thumbnail;

  @override
  void initState() {
    super.initState();
    _thumbnail = _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant _GalleryTile oldWidget) {
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
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
                  return bytes == null
                      ? const Icon(
                          Icons.image_outlined,
                          color: CaRismaDesignTokens.textMuted,
                        )
                      : Image.memory(bytes, fit: BoxFit.cover);
                },
              ),
            ),
            if (widget.asset.type == AssetType.video)
              const Positioned(
                left: 7,
                bottom: 7,
                child: Icon(
                  Icons.videocam_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            Positioned(
              top: 7,
              right: 7,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.selectionNumber == null
                      ? Colors.black54
                      : CaRismaDesignTokens.bluePrimary,
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                child: widget.selectionNumber == null
                    ? null
                    : Text(
                        '${widget.selectionNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
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

class _GalleryMessage extends StatelessWidget {
  const _GalleryMessage({
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CaRismaDesignTokens.blueBright, size: 38),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CaRismaDesignTokens.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null)
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
