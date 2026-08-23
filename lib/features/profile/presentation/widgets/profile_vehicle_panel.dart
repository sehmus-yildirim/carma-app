import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/profile_vehicle.dart';
import '../../data/profile_vehicle_gallery_media.dart';
import '../../data/profile_vehicle_modification.dart';
import '../../data/profile_vehicle_timeline_entry.dart';
import '../../data/user_profile.dart';
import 'profile_vehicle_gallery_card.dart';
import 'profile_vehicle_statistics_card.dart';
import 'profile_vehicle_timeline_card.dart';
import 'profile_section_add_button.dart';

enum ProfileVehicleMenuAction { edit, details, setPrimary, archive }

const String debugProfileVehicleId = 'plaqa-debug-bmw-x6-m50d';

const ProfileVehicle debugProfileVehicle = ProfileVehicle(
  id: debugProfileVehicleId,
  ownerUserId: 'plaqa-debug-profile',
  brand: 'BMW',
  model: 'X6',
  series: 'M50d',
  color: 'Schwarz',
  countryCode: 'DE',
  plateRegion: 'HH',
  plateLetters: 'PQ',
  plateNumbers: '2026',
  isPrimary: true,
  status: ProfileVehicleStatus.active,
  visibility: ProfileVehicleVisibility.contacts,
  showPlate: true,
  vehicleType: ProfileVehicleType.passengerCar,
  plateType: ProfilePlateType.standard,
  showOnPublicProfile: true,
  discoverableByPlate: false,
  selectableInStories: false,
  allowContactRequests: false,
  plateDisplayMode: ProfilePlateDisplayMode.full,
  year: 2015,
  bodyStyle: 'SUV',
  engineDescription: '3.0 Diesel',
  horsepower: 381,
  kilowatts: 280,
  fuelType: 'Diesel',
  transmission: '8-Gang Automatik',
  drivetrain: 'Allrad',
  equipment: <String>[
    'M Sportpaket',
    'xDrive',
    'Lederausstattung',
    'Navigationssystem',
    'Rückfahrkamera',
    'Sitzheizung',
  ],
);

const double _vehicleSectionContentHeight = 176;

class ProfileVehiclePanel extends StatefulWidget {
  const ProfileVehiclePanel({
    super.key,
    required this.profile,
    required this.postCount,
    required this.vehicles,
    required this.isLoading,
    required this.loadError,
    required this.isOwnProfile,
    required this.onAdd,
    required this.onEdit,
    required this.onEditDetails,
    required this.onEditEquipment,
    required this.onSetPrimary,
    required this.onArchive,
    required this.onGenerateHero,
    required this.isHeroRequestBusy,
    required this.galleryMediaForVehicle,
    required this.onAddGalleryMedia,
    required this.onSetMainGalleryMedia,
    required this.onDeleteGalleryMedia,
    required this.modificationsForVehicle,
    required this.onAddModification,
    required this.onEditModification,
    required this.onDeleteModification,
    required this.timelineEntriesForVehicle,
    required this.onAddTimelineEntry,
    required this.onEditTimelineEntry,
    required this.onDeleteTimelineEntry,
    required this.profileViewCount,
    required this.totalLikeCount,
  });

  final UserProfile? profile;
  final int postCount;
  final List<ProfileVehicle> vehicles;
  final bool isLoading;
  final Object? loadError;
  final bool isOwnProfile;
  final VoidCallback onAdd;
  final ValueChanged<ProfileVehicle> onEdit;
  final ValueChanged<ProfileVehicle> onEditDetails;
  final ValueChanged<ProfileVehicle> onEditEquipment;
  final ValueChanged<ProfileVehicle> onSetPrimary;
  final ValueChanged<ProfileVehicle> onArchive;
  final ValueChanged<ProfileVehicle> onGenerateHero;
  final bool Function(String vehicleId) isHeroRequestBusy;
  final Stream<List<ProfileVehicleGalleryMedia>> Function(String vehicleId)
  galleryMediaForVehicle;
  final ValueChanged<ProfileVehicle> onAddGalleryMedia;
  final void Function(ProfileVehicle vehicle, ProfileVehicleGalleryMedia media)
  onSetMainGalleryMedia;
  final ValueChanged<ProfileVehicleGalleryMedia> onDeleteGalleryMedia;
  final Stream<List<ProfileVehicleModification>> Function(String vehicleId)
  modificationsForVehicle;
  final ValueChanged<ProfileVehicle> onAddModification;
  final void Function(
    ProfileVehicle vehicle,
    ProfileVehicleModification modification,
  )
  onEditModification;
  final ValueChanged<ProfileVehicleModification> onDeleteModification;
  final Stream<List<ProfileVehicleTimelineEntry>> Function(String vehicleId)
  timelineEntriesForVehicle;
  final ValueChanged<ProfileVehicle> onAddTimelineEntry;
  final void Function(ProfileVehicle vehicle, ProfileVehicleTimelineEntry entry)
  onEditTimelineEntry;
  final ValueChanged<ProfileVehicleTimelineEntry> onDeleteTimelineEntry;
  final Stream<int> profileViewCount;
  final Stream<int> totalLikeCount;

  @override
  State<ProfileVehiclePanel> createState() => _ProfileVehiclePanelState();
}

class _ProfileVehiclePanelState extends State<ProfileVehiclePanel> {
  String? _selectedVehicleId;

  @override
  Widget build(BuildContext context) {
    final resolvedVehicles = _resolvedVehicles(widget.vehicles);
    final selectedVehicle = _selectedVehicle(resolvedVehicles);
    final isDebugVehicle = selectedVehicle?.id == debugProfileVehicleId;
    final canManageSelected = widget.isOwnProfile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isLoading && resolvedVehicles.isEmpty)
          const _VehicleLoadingState()
        else if (widget.loadError != null)
          const _VehicleMessageState(
            icon: Icons.cloud_off_rounded,
            title: 'Fahrzeuge konnten nicht geladen werden',
            message: 'Prüfe deine Verbindung und versuche es erneut.',
          )
        else if (resolvedVehicles.isEmpty)
          _VehicleMessageState(
            icon: Icons.directions_car_outlined,
            title: 'Noch kein Fahrzeug',
            message: widget.isOwnProfile
                ? 'Füge dein erstes Fahrzeug zu deinem Profil hinzu.'
                : 'Dieser Nutzer zeigt aktuell kein Fahrzeug.',
            actionLabel: widget.isOwnProfile ? 'Fahrzeug hinzufügen' : null,
            onAction: widget.isOwnProfile ? widget.onAdd : null,
          )
        else ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) => _selectFromSwipe(
              resolvedVehicles,
              selectedVehicle,
              details.primaryVelocity ?? 0,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _VehicleHeroCard(
                key: ValueKey(selectedVehicle!.id),
                vehicle: selectedVehicle,
                showGenerationControl: widget.isOwnProfile,
                isGenerationBusy: widget.isHeroRequestBusy(selectedVehicle.id),
                onGenerate: () => widget.onGenerateHero(selectedVehicle),
                onAddVehicle: widget.isOwnProfile ? widget.onAdd : null,
              ),
            ),
          ),
          if (resolvedVehicles.length > 1) ...[
            const SizedBox(height: 12),
            _VehicleSelector(
              vehicles: resolvedVehicles,
              selectedVehicleId: selectedVehicle.id,
              onSelected: (vehicle) {
                setState(() => _selectedVehicleId = vehicle.id);
              },
            ),
          ],
          const SizedBox(height: 12),
          ProfileVehicleGalleryCard(
            vehicle: selectedVehicle,
            media: widget.galleryMediaForVehicle(selectedVehicle.id),
            isOwnProfile: canManageSelected,
            onAdd: () => widget.onAddGalleryMedia(selectedVehicle),
            onSetMain: (media) =>
                widget.onSetMainGalleryMedia(selectedVehicle, media),
            onDelete: widget.onDeleteGalleryMedia,
          ),
          const SizedBox(height: 12),
          _VehicleDataCard(
            vehicle: selectedVehicle,
            isOwnProfile: canManageSelected,
            onEdit: () => widget.onEditDetails(selectedVehicle),
          ),
          const SizedBox(height: 12),
          _VehicleEquipmentCard(
            vehicle: selectedVehicle,
            isOwnProfile: canManageSelected,
            onEdit: () => widget.onEditEquipment(selectedVehicle),
          ),
          const SizedBox(height: 12),
          _VehicleModificationsCard(
            modifications: widget.modificationsForVehicle(selectedVehicle.id),
            isOwnProfile: canManageSelected,
            onAdd: () => widget.onAddModification(selectedVehicle),
            onEdit: (modification) =>
                widget.onEditModification(selectedVehicle, modification),
            onDelete: widget.onDeleteModification,
          ),
          const SizedBox(height: 12),
          ProfileVehicleTimelineCard(
            entries: widget.timelineEntriesForVehicle(selectedVehicle.id),
            isOwnProfile: canManageSelected,
            onAdd: () => widget.onAddTimelineEntry(selectedVehicle),
            onEdit: (entry) =>
                widget.onEditTimelineEntry(selectedVehicle, entry),
            onDelete: widget.onDeleteTimelineEntry,
          ),
          if (widget.isOwnProfile) ...[
            const SizedBox(height: 12),
            ProfileVehicleStatisticsCard(
              profileViews: widget.profileViewCount,
              totalLikes: widget.totalLikeCount,
            ),
          ],
          if (widget.isOwnProfile && !isDebugVehicle) ...[
            const SizedBox(height: 18),
            Text(
              'Verwalten',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            for (var index = 0; index < resolvedVehicles.length; index++) ...[
              _ProfileVehicleCard(
                vehicle: resolvedVehicles[index],
                isOwnProfile: true,
                onAction: (action) {
                  switch (action) {
                    case ProfileVehicleMenuAction.edit:
                      widget.onEdit(resolvedVehicles[index]);
                    case ProfileVehicleMenuAction.details:
                      widget.onEditDetails(resolvedVehicles[index]);
                    case ProfileVehicleMenuAction.setPrimary:
                      widget.onSetPrimary(resolvedVehicles[index]);
                    case ProfileVehicleMenuAction.archive:
                      widget.onArchive(resolvedVehicles[index]);
                  }
                },
              ),
              if (index < resolvedVehicles.length - 1)
                const SizedBox(height: 10),
            ],
          ],
        ],
      ],
    );
  }

  List<ProfileVehicle> _resolvedVehicles(List<ProfileVehicle> vehicles) {
    if (vehicles.isNotEmpty) return vehicles;
    final currentProfile = widget.profile;
    if (currentProfile != null) {
      final legacyVehicle = ProfileVehicle.fromLegacyProfile(currentProfile);
      if (legacyVehicle.hasRequiredData) return <ProfileVehicle>[legacyVehicle];
    }
    if (kDebugMode && widget.isOwnProfile) {
      return const <ProfileVehicle>[debugProfileVehicle];
    }
    return const <ProfileVehicle>[];
  }

  ProfileVehicle? _selectedVehicle(List<ProfileVehicle> vehicles) {
    if (vehicles.isEmpty) return null;
    final selectedId = _selectedVehicleId;
    if (selectedId != null) {
      for (final vehicle in vehicles) {
        if (vehicle.id == selectedId) return vehicle;
      }
    }
    for (final vehicle in vehicles) {
      if (vehicle.isPrimary) return vehicle;
    }
    return vehicles.first;
  }

  void _selectFromSwipe(
    List<ProfileVehicle> vehicles,
    ProfileVehicle selected,
    double velocity,
  ) {
    if (vehicles.length < 2 || velocity.abs() < 180) return;
    final index = vehicles.indexWhere((vehicle) => vehicle.id == selected.id);
    if (index < 0) return;
    final nextIndex = velocity < 0 ? index + 1 : index - 1;
    if (nextIndex < 0 || nextIndex >= vehicles.length) return;
    setState(() => _selectedVehicleId = vehicles[nextIndex].id);
  }
}

class _VehicleHeroCard extends StatelessWidget {
  const _VehicleHeroCard({
    super.key,
    required this.vehicle,
    required this.showGenerationControl,
    required this.isGenerationBusy,
    required this.onGenerate,
    required this.onAddVehicle,
  });

  final ProfileVehicle vehicle;
  final bool showGenerationControl;
  final bool isGenerationBusy;
  final VoidCallback onGenerate;
  final VoidCallback? onAddVehicle;

  @override
  Widget build(BuildContext context) {
    final imageUrl = vehicle.heroImageUrl?.trim() ?? '';
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF20242B),
                          Color(0xFF111419),
                          Color(0xFF080A0D),
                        ],
                      ),
                    ),
                  ),
                  if (vehicle.id == debugProfileVehicleId)
                    const _DebugVehicleHeroPlaceholder()
                  else if (imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) =>
                            const _VehicleHeroPlaceholder(),
                      ),
                    )
                  else
                    const _VehicleHeroPlaceholder(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.74),
                        ],
                      ),
                    ),
                  ),
                  if (showGenerationControl)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _VehicleHeroGenerationControl(
                        status: vehicle.heroImageStatus,
                        isBusy: isGenerationBusy,
                        onPressed: onGenerate,
                      ),
                    ),
                  if (onAddVehicle != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: ProfileSectionAddButton(
                        tooltip: 'Fahrzeug hinzufügen',
                        onPressed: onAddVehicle!,
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            vehicle.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _VehicleChip(
                          icon: Icons.circle,
                          label: _statusLabel(vehicle.status),
                          iconColor: const Color(0xFF22C55E),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 15),
              child: SizedBox(
                height: 120,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 56,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    final item = _fixedVehicleHighlights(vehicle)[index];
                    return _VehicleHighlightTile(
                      icon: item.icon,
                      title: item.title,
                      value: item.value,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleHeroPlaceholder extends StatelessWidget {
  const _VehicleHeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.directions_car_filled_rounded,
        size: 84,
        color: Colors.white.withValues(alpha: 0.13),
      ),
    );
  }
}

class _DebugVehicleHeroPlaceholder extends StatelessWidget {
  const _DebugVehicleHeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
        child: Image.asset(
          'assets/images/debug_bmw_x6_m50d.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _VehicleHeroGenerationControl extends StatelessWidget {
  const _VehicleHeroGenerationControl({
    required this.status,
    required this.isBusy,
    required this.onPressed,
  });

  final VehicleHeroImageStatus status;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isPending =
        isBusy ||
        status == VehicleHeroImageStatus.queued ||
        status == VehicleHeroImageStatus.generating;
    final label = switch (status) {
      VehicleHeroImageStatus.notGenerated => 'KI-Bild',
      VehicleHeroImageStatus.failed => 'Erneut versuchen',
      VehicleHeroImageStatus.regenerationRequired => 'Neu erstellen',
      VehicleHeroImageStatus.ready => 'KI-Bild neu',
      VehicleHeroImageStatus.queued ||
      VehicleHeroImageStatus.generating => 'Wird erstellt',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isPending ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF080B12).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPending)
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CaRismaDesignTokens.blueBright,
                  ),
                )
              else
                const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: CaRismaDesignTokens.blueBright,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleSelector extends StatelessWidget {
  const _VehicleSelector({
    required this.vehicles,
    required this.selectedVehicleId,
    required this.onSelected,
  });

  final List<ProfileVehicle> vehicles;
  final String selectedVehicleId;
  final ValueChanged<ProfileVehicle> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: vehicles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final vehicle = vehicles[index];
          final isSelected = vehicle.id == selectedVehicleId;
          return ChoiceChip(
            selected: isSelected,
            onSelected: (_) => onSelected(vehicle),
            showCheckmark: false,
            selectedColor: CaRismaDesignTokens.card,
            backgroundColor: CaRismaDesignTokens.card,
            side: BorderSide(
              color: isSelected
                  ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.10),
              width: isSelected ? 1.4 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            labelStyle: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
            ),
            avatar: Icon(
              vehicle.isPrimary
                  ? Icons.star_rounded
                  : Icons.directions_car_rounded,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : CaRismaDesignTokens.textSecondary,
            ),
            label: Text(vehicle.displayName),
          );
        },
      ),
    );
  }
}

class _VehicleDataCard extends StatelessWidget {
  const _VehicleDataCard({
    required this.vehicle,
    required this.isOwnProfile,
    required this.onEdit,
  });

  final ProfileVehicle vehicle;
  final bool isOwnProfile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final values = <MapEntry<String, String>>[
      MapEntry('Marke', vehicle.brand),
      MapEntry('Modell', vehicle.model),
      if ((vehicle.series ?? '').trim().isNotEmpty)
        MapEntry('Baureihe', vehicle.series!.trim()),
      if (vehicle.year != null) MapEntry('Baujahr', '${vehicle.year}'),
      if (vehicle.firstRegistration != null)
        MapEntry(
          'Erstzulassung',
          _compactVehicleDate(vehicle.firstRegistration),
        ),
      if (vehicle.ownedSince != null)
        MapEntry('Besitzer seit', _compactVehicleDate(vehicle.ownedSince)),
      if ((vehicle.bodyStyle ?? '').trim().isNotEmpty)
        MapEntry('Karosserie', vehicle.bodyStyle!.trim()),
      if ((vehicle.engineDescription ?? '').trim().isNotEmpty)
        MapEntry('Motor', vehicle.engineDescription!.trim()),
      if (vehicle.displacementCcm != null)
        MapEntry('Hubraum', '${vehicle.displacementCcm} cm³'),
      if (vehicle.horsepower != null || vehicle.kilowatts != null)
        MapEntry(
          'Leistung',
          [
            if (vehicle.horsepower != null) '${vehicle.horsepower} PS',
            if (vehicle.kilowatts != null) '${vehicle.kilowatts} kW',
          ].join(' / '),
        ),
      if ((vehicle.fuelType ?? '').trim().isNotEmpty)
        MapEntry('Kraftstoff', vehicle.fuelType!.trim()),
      if ((vehicle.transmission ?? '').trim().isNotEmpty)
        MapEntry('Getriebe', vehicle.transmission!.trim()),
      if ((vehicle.drivetrain ?? '').trim().isNotEmpty)
        MapEntry('Antrieb', vehicle.drivetrain!.trim()),
      MapEntry('Farbe', vehicle.color),
      if (vehicle.mileage != null)
        MapEntry('Kilometer', '${_formatNumber(vehicle.mileage!)} km'),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VehicleSectionHeader(
            title: 'Fahrzeugdaten',
            icon: Icons.fact_check_outlined,
            onEdit: isOwnProfile ? onEdit : null,
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: _vehicleSectionContentHeight,
            child: GridView.builder(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 8,
                mainAxisExtent: 38,
              ),
              itemCount: values.length,
              itemBuilder: (context, index) => _VehicleDataValue(
                label: values[index].key,
                value: values[index].value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleEquipmentCard extends StatelessWidget {
  const _VehicleEquipmentCard({
    required this.vehicle,
    required this.isOwnProfile,
    required this.onEdit,
  });

  final ProfileVehicle vehicle;
  final bool isOwnProfile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VehicleSectionHeader(
            title: 'Ausstattung',
            icon: Icons.auto_awesome_outlined,
            onEdit: isOwnProfile ? onEdit : null,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _vehicleSectionContentHeight,
            child: vehicle.equipment.isEmpty
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      isOwnProfile
                          ? 'Noch keine Ausstattung hinterlegt.'
                          : 'Keine Ausstattung freigegeben.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CaRismaDesignTokens.textSecondary,
                      ),
                    ),
                  )
                : GridView.builder(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          mainAxisExtent: 48,
                        ),
                    itemCount: vehicle.equipment.length,
                    itemBuilder: (context, index) =>
                        _EquipmentTile(label: vehicle.equipment[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _VehicleSectionHeader extends StatelessWidget {
  const _VehicleSectionHeader({
    required this.title,
    required this.icon,
    this.onEdit,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: CaRismaDesignTokens.blueBright),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (onEdit != null)
          ProfileSectionAddButton(
            tooltip: '$title hinzufügen oder bearbeiten',
            onPressed: onEdit!,
          ),
      ],
    );
  }
}

class _VehicleModificationsCard extends StatelessWidget {
  const _VehicleModificationsCard({
    required this.modifications,
    required this.isOwnProfile,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final Stream<List<ProfileVehicleModification>> modifications;
  final bool isOwnProfile;
  final VoidCallback onAdd;
  final ValueChanged<ProfileVehicleModification> onEdit;
  final ValueChanged<ProfileVehicleModification> onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProfileVehicleModification>>(
      stream: modifications,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ProfileVehicleModification>[];
        return GlassCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VehicleSectionHeader(
                title: 'Umbauten',
                icon: Icons.build_circle_outlined,
                onEdit: isOwnProfile ? onAdd : null,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: _vehicleSectionContentHeight,
                child:
                    snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Umbauten konnten nicht geladen werden.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: CaRismaDesignTokens.textSecondary,
                              ),
                        ),
                      )
                    : items.isEmpty
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          isOwnProfile
                              ? 'Noch keine Umbauten hinterlegt.'
                              : 'Keine Umbauten freigegeben.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: CaRismaDesignTokens.textSecondary,
                              ),
                        ),
                      )
                    : ListView.separated(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: items.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                        itemBuilder: (context, index) => _ModificationRow(
                          modification: items[index],
                          isOwnProfile: isOwnProfile,
                          onEdit: () => onEdit(items[index]),
                          onDelete: () => onDelete(items[index]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModificationRow extends StatelessWidget {
  const _ModificationRow({
    required this.modification,
    required this.isOwnProfile,
    required this.onEdit,
    required this.onDelete,
  });

  final ProfileVehicleModification modification;
  final bool isOwnProfile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if ((modification.manufacturer ?? '').trim().isNotEmpty)
        modification.manufacturer!.trim(),
      if ((modification.product ?? '').trim().isNotEmpty)
        modification.product!.trim(),
      if (modification.powerChangeHp != null)
        '${modification.powerChangeHp! >= 0 ? '+' : ''}${modification.powerChangeHp} PS',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.build_rounded,
              size: 18,
              color: CaRismaDesignTokens.blueBright,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _modificationCategoryLabel(modification.category),
                    ...details,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CaRismaDesignTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (modification.isRegistered)
            const Tooltip(
              message: 'Eintragung vorhanden',
              child: Icon(
                Icons.verified_outlined,
                size: 18,
                color: CaRismaDesignTokens.success,
              ),
            ),
          if (isOwnProfile)
            PopupMenuButton<String>(
              tooltip: 'Umbau verwalten',
              color: CaRismaDesignTokens.controlSurface,
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                PopupMenuItem(value: 'delete', child: Text('Entfernen')),
              ],
            ),
        ],
      ),
    );
  }
}

String _modificationCategoryLabel(ProfileVehicleModificationCategory category) {
  return switch (category) {
    ProfileVehicleModificationCategory.wheels => 'Felgen',
    ProfileVehicleModificationCategory.tires => 'Reifen',
    ProfileVehicleModificationCategory.suspension => 'Fahrwerk',
    ProfileVehicleModificationCategory.brakes => 'Bremsen',
    ProfileVehicleModificationCategory.engine => 'Motor',
    ProfileVehicleModificationCategory.software => 'Software',
    ProfileVehicleModificationCategory.exhaust => 'Abgasanlage',
    ProfileVehicleModificationCategory.lighting => 'Beleuchtung',
    ProfileVehicleModificationCategory.body => 'Karosserie',
    ProfileVehicleModificationCategory.wrap => 'Folierung',
    ProfileVehicleModificationCategory.interior => 'Innenraum',
    ProfileVehicleModificationCategory.soundSystem => 'Soundsystem',
    ProfileVehicleModificationCategory.other => 'Sonstiges',
  };
}

class _VehicleDataValue extends StatelessWidget {
  const _VehicleDataValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: CaRismaDesignTokens.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EquipmentTile extends StatelessWidget {
  const _EquipmentTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_rounded,
            size: 15,
            color: CaRismaDesignTokens.blueBright,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileVehicleCard extends StatelessWidget {
  const _ProfileVehicleCard({
    required this.vehicle,
    required this.isOwnProfile,
    required this.onAction,
  });

  final ProfileVehicle vehicle;
  final bool isOwnProfile;
  final ValueChanged<ProfileVehicleMenuAction> onAction;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CaRismaBlueIconBox(
                icon: Icons.directions_car_filled_rounded,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _statusLabel(vehicle.status),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CaRismaDesignTokens.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (vehicle.isPrimary)
                const _VehicleChip(
                  icon: Icons.star_rounded,
                  label: 'Hauptfahrzeug',
                ),
              if (isOwnProfile)
                PopupMenuButton<ProfileVehicleMenuAction>(
                  tooltip: 'Fahrzeug verwalten',
                  color: CaRismaDesignTokens.controlSurface,
                  onSelected: onAction,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ProfileVehicleMenuAction.edit,
                      child: Text('Bearbeiten'),
                    ),
                    const PopupMenuItem(
                      value: ProfileVehicleMenuAction.details,
                      child: Text('Fahrzeugdaten & Ausstattung'),
                    ),
                    if (!vehicle.isPrimary && !vehicle.isArchived)
                      const PopupMenuItem(
                        value: ProfileVehicleMenuAction.setPrimary,
                        child: Text('Als Hauptfahrzeug festlegen'),
                      ),
                    if (!vehicle.isPrimary && !vehicle.isArchived)
                      const PopupMenuItem(
                        value: ProfileVehicleMenuAction.archive,
                        child: Text('Archivieren'),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (vehicle.showPlate || isOwnProfile)
                _VehicleChip(
                  icon: Icons.pin_outlined,
                  label: vehicle.displayPlate,
                ),
              if (vehicle.color.trim().isNotEmpty)
                _VehicleChip(
                  icon: Icons.palette_outlined,
                  label: vehicle.color.trim(),
                ),
              if (vehicle.isVerified)
                const _VehicleChip(
                  icon: Icons.verified_rounded,
                  label: 'Verifiziert',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleChip extends StatelessWidget {
  const _VehicleChip({
    required this.icon,
    required this.label,
    this.iconColor = CaRismaDesignTokens.blueBright,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleHighlightTile extends StatelessWidget {
  const _VehicleHighlightTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: CaRismaDesignTokens.blueBright),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: CaRismaDesignTokens.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleLoadingState extends StatelessWidget {
  const _VehicleLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _VehicleMessageState extends StatelessWidget {
  const _VehicleMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CaRismaBlueIconBox(icon: icon, size: 40, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CaRismaDesignTokens.textSecondary,
                    height: 1.3,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(ProfileVehicleStatus status) {
  return switch (status) {
    ProfileVehicleStatus.active => 'Aktiv',
    ProfileVehicleStatus.modification => 'Im Umbau',
    ProfileVehicleStatus.repair => 'In Reparatur',
    ProfileVehicleStatus.seasonal => 'Saisonfahrzeug',
    ProfileVehicleStatus.deregistered => 'Abgemeldet',
    ProfileVehicleStatus.sold => 'Verkauft',
    ProfileVehicleStatus.noLongerOwned => 'Nicht mehr im Besitz',
    ProfileVehicleStatus.archived => 'Archiviert',
  };
}

List<_FixedVehicleHighlight> _fixedVehicleHighlights(ProfileVehicle vehicle) {
  final power = vehicle.horsepower != null
      ? '${vehicle.horsepower} PS'
      : vehicle.kilowatts != null
      ? '${vehicle.kilowatts} kW'
      : '-';
  return [
    _FixedVehicleHighlight(
      icon: Icons.bolt_rounded,
      title: 'Leistung',
      value: power,
    ),
    _FixedVehicleHighlight(
      icon: Icons.speed_rounded,
      title: 'Kilometerstand',
      value: vehicle.mileage == null
          ? '-'
          : '${_formatNumber(vehicle.mileage!)} km',
    ),
    _FixedVehicleHighlight(
      icon: Icons.event_available_outlined,
      title: 'Erstzulassung',
      value: _compactVehicleDate(vehicle.firstRegistration),
    ),
    _FixedVehicleHighlight(
      icon: Icons.calendar_month_outlined,
      title: 'Besitzer seit',
      value: _compactVehicleDate(vehicle.ownedSince),
    ),
  ];
}

String _compactVehicleDate(DateTime? value) {
  if (value == null) return '-';
  return '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';
}

class _FixedVehicleHighlight {
  const _FixedVehicleHighlight({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;
}

String _formatNumber(int value) {
  final source = '$value';
  final buffer = StringBuffer();
  for (var index = 0; index < source.length; index++) {
    if (index > 0 && (source.length - index) % 3 == 0) buffer.write('.');
    buffer.write(source[index]);
  }
  return buffer.toString();
}
