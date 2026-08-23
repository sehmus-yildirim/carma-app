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
        final groups = _galleryGroups
            .map(
              (group) => (
                group: group,
                items: items
                    .where((item) => group.categories.contains(item.category))
                    .toList(growable: false),
              ),
            )
            .toList(growable: false);
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
              else
                GridView.builder(
                  key: const ValueKey('profile-vehicle-gallery-grid'),
                  shrinkWrap: true,
                  primary: false,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 9,
                    childAspectRatio: 1.38,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _GalleryCategoryTile(
                      label: group.group.label,
                      icon: group.group.icon,
                      items: group.items,
                      isOwnProfile: isOwnProfile,
                      onAdd: onAdd,
                      onOpen: (initialIndex) => showProfileVehicleGallery(
                        context,
                        media: group.items,
                        initialIndex: initialIndex,
                      ),
                      onSetMain: onSetMain,
                      onDelete: onDelete,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

const _galleryGroups = <_GalleryGroup>[
  _GalleryGroup(
    label: 'Außenansicht',
    icon: Icons.directions_car_outlined,
    categories: <ProfileVehicleGalleryCategory>{
      ProfileVehicleGalleryCategory.exterior,
    },
  ),
  _GalleryGroup(
    label: 'Innenraum',
    icon: Icons.airline_seat_recline_normal_rounded,
    categories: <ProfileVehicleGalleryCategory>{
      ProfileVehicleGalleryCategory.interior,
    },
  ),
  _GalleryGroup(
    label: 'Details',
    icon: Icons.search_rounded,
    categories: <ProfileVehicleGalleryCategory>{
      ProfileVehicleGalleryCategory.engineBay,
      ProfileVehicleGalleryCategory.details,
      ProfileVehicleGalleryCategory.beforeAfter,
      ProfileVehicleGalleryCategory.documentation,
    },
  ),
  _GalleryGroup(
    label: 'Umbauten',
    icon: Icons.build_outlined,
    categories: <ProfileVehicleGalleryCategory>{
      ProfileVehicleGalleryCategory.modifications,
    },
  ),
];

class _GalleryGroup {
  const _GalleryGroup({
    required this.label,
    required this.icon,
    required this.categories,
  });

  final String label;
  final IconData icon;
  final Set<ProfileVehicleGalleryCategory> categories;
}

class _GalleryCategoryTile extends StatelessWidget {
  const _GalleryCategoryTile({
    required this.label,
    required this.icon,
    required this.items,
    required this.isOwnProfile,
    required this.onAdd,
    required this.onOpen,
    required this.onSetMain,
    required this.onDelete,
  });

  final String label;
  final IconData icon;
  final List<ProfileVehicleGalleryMedia> items;
  final bool isOwnProfile;
  final VoidCallback onAdd;
  final ValueChanged<int> onOpen;
  final ValueChanged<ProfileVehicleGalleryMedia> onSetMain;
  final ValueChanged<ProfileVehicleGalleryMedia> onDelete;

  @override
  Widget build(BuildContext context) {
    final coverIndex = items.indexWhere((item) => item.isMain);
    final resolvedCoverIndex = coverIndex >= 0 ? coverIndex : 0;
    final cover = items.isEmpty ? null : items[resolvedCoverIndex];
    return Material(
      color: CaRismaDesignTokens.controlSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: items.isEmpty ? (isOwnProfile ? onAdd : null) : () => onOpen(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: cover == null
                  ? Icon(icon, color: CaRismaDesignTokens.textMuted, size: 30)
                  : _GalleryCategoryPreview(
                      media: cover,
                      isOwnProfile: isOwnProfile,
                      canChooseCover:
                          items
                              .where(
                                (item) =>
                                    item.mediaType ==
                                    ProfileVehicleGalleryMediaType.image,
                              )
                              .length >
                          1,
                      onOpen: () => onOpen(resolvedCoverIndex),
                      onChooseCover: () => _chooseCover(context),
                      onDelete: () => onDelete(cover),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 8, 8),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: CaRismaDesignTokens.blueBright),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: CaRismaDesignTokens.textSecondary,
                      fontSize: 11,
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

  Future<void> _chooseCover(BuildContext context) async {
    final images = items
        .where((item) => item.mediaType == ProfileVehicleGalleryMediaType.image)
        .toList(growable: false);
    if (images.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: CaRismaDesignTokens.background,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.68,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Vorschaubild auswählen',
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Abbrechen',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  physics: const ClampingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final image = images[index];
                    return Material(
                      color: CaRismaDesignTokens.controlSurface,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Ink.image(
                        image: _galleryImageProvider(image.mediaUrl),
                        fit: BoxFit.cover,
                        child: InkWell(
                          onTap: () {
                            onSetMain(image);
                            Navigator.of(sheetContext).pop();
                          },
                          child: image.isMain
                              ? const Align(
                                  alignment: Alignment.topLeft,
                                  child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: _MainBadge(),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryCategoryPreview extends StatelessWidget {
  const _GalleryCategoryPreview({
    required this.media,
    required this.isOwnProfile,
    required this.canChooseCover,
    required this.onOpen,
    required this.onChooseCover,
    required this.onDelete,
  });

  final ProfileVehicleGalleryMedia media;
  final bool isOwnProfile;
  final bool canChooseCover;
  final VoidCallback onOpen;
  final VoidCallback onChooseCover;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (media.mediaType == ProfileVehicleGalleryMediaType.video)
          Material(
            color: const Color(0xFF121722),
            child: InkWell(
              onTap: onOpen,
              child: const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          )
        else
          Image(
            image: _galleryImageProvider(media.mediaUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFF121722),
              child: Icon(Icons.broken_image_outlined, color: Colors.white54),
            ),
          ),
        Material(
          color: Colors.transparent,
          child: InkWell(onTap: onOpen),
        ),
        if (media.isMain)
          const Positioned(left: 5, top: 5, child: _MainBadge()),
        if (isOwnProfile)
          Positioned(
            right: 0,
            top: 0,
            child: PopupMenuButton<String>(
              tooltip: 'Medium verwalten',
              color: CaRismaDesignTokens.controlSurface,
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: (value) =>
                  value == 'cover' ? onChooseCover() : onDelete(),
              itemBuilder: (context) => [
                if (canChooseCover)
                  const PopupMenuItem(
                    value: 'cover',
                    child: Text('Vorschaubild auswählen'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Medium entfernen'),
                ),
              ],
            ),
          ),
      ],
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
