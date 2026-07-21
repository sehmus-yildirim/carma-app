import 'package:flutter/material.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/profile_vehicle.dart';
import '../../data/profile_vehicle_timeline_entry.dart';

class ProfileVehicleTimelineCard extends StatelessWidget {
  const ProfileVehicleTimelineCard({
    super.key,
    required this.vehicle,
    required this.entries,
    required this.isOwnProfile,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final ProfileVehicle vehicle;
  final Stream<List<ProfileVehicleTimelineEntry>> entries;
  final bool isOwnProfile;
  final VoidCallback onAdd;
  final ValueChanged<ProfileVehicleTimelineEntry> onEdit;
  final ValueChanged<ProfileVehicleTimelineEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProfileVehicleTimelineEntry>>(
      stream: entries,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ProfileVehicleTimelineEntry>[];
        final preview = items.take(4).toList(growable: false);
        return GlassCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.timeline_rounded,
                    size: 21,
                    color: CaRismaDesignTokens.blueBright,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fahrzeug-Timeline',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (isOwnProfile)
                    IconButton(
                      tooltip: 'Ereignis hinzufügen',
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded),
                      iconSize: 20,
                      color: CaRismaDesignTokens.blueBright,
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
                  'Timeline konnte nicht geladen werden.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CaRismaDesignTokens.textSecondary,
                  ),
                )
              else if (preview.isEmpty)
                Text(
                  isOwnProfile
                      ? 'Ergänze die Geschichte dieses Fahrzeugs.'
                      : 'Keine Timeline-Ereignisse freigegeben.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CaRismaDesignTokens.textSecondary,
                  ),
                )
              else ...[
                for (var index = 0; index < preview.length; index++)
                  _TimelineRow(
                    entry: preview[index],
                    showLine: index < preview.length - 1,
                    isOwnProfile: isOwnProfile,
                    onEdit: () => onEdit(preview[index]),
                    onDelete: () => onDelete(preview[index]),
                  ),
                if (items.length > preview.length)
                  TextButton.icon(
                    onPressed: () => _showAll(context, items),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text('Alle ${items.length} Ereignisse'),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showAll(BuildContext context, List<ProfileVehicleTimelineEntry> items) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1320),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.94,
        builder: (context, controller) => ListView.builder(
          controller: controller,
          padding: const EdgeInsets.all(20),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  'Timeline · ${vehicle.displayName}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            }
            final entry = items[index - 1];
            return _TimelineRow(
              entry: entry,
              showLine: index < items.length,
              isOwnProfile: isOwnProfile,
              onEdit: () {
                Navigator.of(sheetContext).pop();
                onEdit(entry);
              },
              onDelete: () {
                Navigator.of(sheetContext).pop();
                onDelete(entry);
              },
            );
          },
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.showLine,
    required this.isOwnProfile,
    required this.onEdit,
    required this.onDelete,
  });

  final ProfileVehicleTimelineEntry entry;
  final bool showLine;
  final bool isOwnProfile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: CaRismaDesignTokens.bluePrimary.withValues(
                    alpha: 0.16,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _timelineIcon(entry.type),
                  size: 15,
                  color: CaRismaDesignTokens.blueBright,
                ),
              ),
              if (showLine)
                Container(
                  width: 2,
                  height: 58,
                  color: CaRismaDesignTokens.bluePrimary.withValues(
                    alpha: 0.22,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(entry.eventDate),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CaRismaDesignTokens.blueBright,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ((entry.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.description!.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CaRismaDesignTokens.textSecondary,
                    ),
                  ),
                ],
                if (entry.isAutomaticallyCreated) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Automatisch',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: CaRismaDesignTokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isOwnProfile && !entry.isAutomaticallyCreated)
          PopupMenuButton<String>(
            tooltip: 'Ereignis verwalten',
            color: CaRismaDesignTokens.controlSurface,
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
              PopupMenuItem(value: 'delete', child: Text('Entfernen')),
            ],
          ),
      ],
    );
  }
}

IconData _timelineIcon(ProfileVehicleTimelineType type) {
  return switch (type) {
    ProfileVehicleTimelineType.vehicleCreated ||
    ProfileVehicleTimelineType.vehicleAcquired => Icons.directions_car_rounded,
    ProfileVehicleTimelineType.registered => Icons.assignment_turned_in_rounded,
    ProfileVehicleTimelineType.modificationAdded => Icons.build_rounded,
    ProfileVehicleTimelineType.maintenance ||
    ProfileVehicleTimelineType.repair => Icons.handyman_rounded,
    ProfileVehicleTimelineType.wheelsInstalled => Icons.tire_repair_rounded,
    ProfileVehicleTimelineType.mileageMilestone => Icons.speed_rounded,
    ProfileVehicleTimelineType.trip => Icons.route_rounded,
    ProfileVehicleTimelineType.meet => Icons.groups_rounded,
    ProfileVehicleTimelineType.seasonStart ||
    ProfileVehicleTimelineType.seasonEnd => Icons.calendar_month_rounded,
    ProfileVehicleTimelineType.sold ||
    ProfileVehicleTimelineType.archived => Icons.archive_outlined,
    ProfileVehicleTimelineType.statusChanged => Icons.sync_alt_rounded,
    ProfileVehicleTimelineType.custom => Icons.circle_outlined,
  };
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
