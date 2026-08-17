import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/profile_vehicle.dart';
import '../../data/profile_vehicle_gallery_media.dart';
import 'profile_section_add_button.dart';

class ProfileVehicleGalleryCard extends StatelessWidget {
  const ProfileVehicleGalleryCard({
    super.key,
    required this.vehicle,
    required this.media,
    required this.isOwnProfile,
    required this.onAdd,
    required this.onSetMain,
    required this.onDelete,
  });

  final ProfileVehicle vehicle;
  final Stream<List<ProfileVehicleGalleryMedia>> media;
  final bool isOwnProfile;
  final VoidCallback onAdd;
  final ValueChanged<ProfileVehicleGalleryMedia> onSetMain;
  final ValueChanged<ProfileVehicleGalleryMedia> onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProfileVehicleGalleryMedia>>(
      stream: media,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ProfileVehicleGalleryMedia>[];
        return GlassCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 21,
                    color: CaRismaDesignTokens.blueBright,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Galerie',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (isOwnProfile)
                    ProfileSectionAddButton(
                      tooltip: 'Medium hinzufügen',
                      onPressed: onAdd,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                Text(
                  'Galerie konnte nicht geladen werden.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CaRismaDesignTokens.textSecondary,
                  ),
                )
              else if (items.isEmpty)
                _EmptyGallery(isOwnProfile: isOwnProfile, onAdd: onAdd)
              else ...[
                SizedBox(
                  height: 154,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) => SizedBox(
                      width: 188,
                      child: _GalleryTile(
                        media: items[index],
                        isOwnProfile: isOwnProfile,
                        onOpen: () => showProfileVehicleGallery(
                          context,
                          media: items,
                          initialIndex: index,
                        ),
                        onSetMain: () => onSetMain(items[index]),
                        onDelete: () => onDelete(items[index]),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery({required this.isOwnProfile, required this.onAdd});

  final bool isOwnProfile;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.image_outlined,
            color: CaRismaDesignTokens.textMuted,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            isOwnProfile
                ? 'Füge die ersten Bilder oder Videos hinzu.'
                : 'Für dieses Fahrzeug wurden keine Medien freigegeben.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CaRismaDesignTokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.media,
    required this.isOwnProfile,
    required this.onOpen,
    required this.onSetMain,
    required this.onDelete,
  });

  final ProfileVehicleGalleryMedia media;
  final bool isOwnProfile;
  final VoidCallback onOpen;
  final VoidCallback onSetMain;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final imageProvider = _galleryImageProvider(media.mediaUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'vehicle-gallery-${media.ownerUserId}-${media.id}',
            child: Material(
              color: const Color(0xFF121722),
              child: media.mediaType == ProfileVehicleGalleryMediaType.video
                  ? InkWell(
                      onTap: onOpen,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Ink.image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      child: InkWell(onTap: onOpen),
                      onImageError: (_, _) {},
                    ),
            ),
          ),
          if (media.isMain)
            const Positioned(left: 6, top: 6, child: _MainBadge()),
          if (isOwnProfile)
            Positioned(
              right: 2,
              top: 2,
              child: PopupMenuButton<String>(
                tooltip: 'Medium verwalten',
                color: CaRismaDesignTokens.controlSurface,
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onSelected: (value) =>
                    value == 'main' ? onSetMain() : onDelete(),
                itemBuilder: (context) => [
                  if (!media.isMain &&
                      media.mediaType == ProfileVehicleGalleryMediaType.image)
                    const PopupMenuItem(
                      value: 'main',
                      child: Text('Als Hauptbild festlegen'),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Medium entfernen'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MainBadge extends StatelessWidget {
  const _MainBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.star_rounded, size: 13, color: Colors.white),
    );
  }
}

Future<void> showProfileVehicleGallery(
  BuildContext context, {
  required List<ProfileVehicleGalleryMedia> media,
  required int initialIndex,
}) async {
  if (media.isEmpty) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ProfileVehicleGalleryViewer(
        media: media,
        initialIndex: initialIndex.clamp(0, media.length - 1),
      ),
    ),
  );
}

class _ProfileVehicleGalleryViewer extends StatefulWidget {
  const _ProfileVehicleGalleryViewer({
    required this.media,
    required this.initialIndex,
  });

  final List<ProfileVehicleGalleryMedia> media;
  final int initialIndex;

  @override
  State<_ProfileVehicleGalleryViewer> createState() =>
      _ProfileVehicleGalleryViewerState();
}

class _ProfileVehicleGalleryViewerState
    extends State<_ProfileVehicleGalleryViewer> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.media.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final item = widget.media[index];
                if (item.mediaType == ProfileVehicleGalleryMediaType.video) {
                  return _GalleryVideoPage(media: item);
                }
                return Center(
                  child: Hero(
                    tag: 'vehicle-gallery-${item.ownerUserId}-${item.id}',
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image(
                        image: _galleryImageProvider(item.mediaUrl),
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 44,
                                color: Colors.white54,
                              ),
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 8,
              top: 8,
              child: IconButton.filledTonal(
                tooltip: 'Galerie schließen',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              right: 16,
              top: 18,
              child: Text(
                '${_currentIndex + 1} / ${widget.media.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if ((widget.media[_currentIndex].caption ?? '').trim().isNotEmpty)
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Text(
                  widget.media[_currentIndex].caption!.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

ImageProvider<Object> _galleryImageProvider(String mediaUrl) {
  const assetPrefix = 'asset://';
  if (mediaUrl.startsWith(assetPrefix)) {
    return AssetImage(mediaUrl.substring(assetPrefix.length));
  }
  return NetworkImage(mediaUrl);
}

class _GalleryVideoPage extends StatefulWidget {
  const _GalleryVideoPage({required this.media});

  final ProfileVehicleGalleryMedia media;

  @override
  State<_GalleryVideoPage> createState() => _GalleryVideoPageState();
}

class _GalleryVideoPageState extends State<_GalleryVideoPage> {
  late final VideoPlayerController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.media.mediaUrl),
    );
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _hasError = true);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Icon(
          Icons.videocam_off_outlined,
          size: 46,
          color: Colors.white54,
        ),
      );
    }
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              if (!_controller.value.isPlaying)
                const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 64,
                  color: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
