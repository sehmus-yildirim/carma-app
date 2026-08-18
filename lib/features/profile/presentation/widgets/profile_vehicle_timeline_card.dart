import 'package:flutter/material.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/profile_vehicle_timeline_entry.dart';
import 'profile_section_add_button.dart';

class ProfileVehicleTimelineCard extends StatelessWidget {
  const ProfileVehicleTimelineCard({
    super.key,
    required this.entries,
    required this.isOwnProfile,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

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
                    ProfileSectionAddButton(
                      tooltip: 'Ereignis hinzufügen',
                      onPressed: onAdd,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 176,
                child:
                    snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Timeline konnte nicht geladen werden.',
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
                              ? 'Ergänze die Geschichte dieses Fahrzeugs.'
                              : 'Keine Timeline-Ereignisse freigegeben.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: CaRismaDesignTokens.textSecondary,
                              ),
                        ),
                      )
                    : ListView.builder(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemExtent: 88,
                        itemCount: items.length,
                        itemBuilder: (context, index) => _TimelineRow(
                          entry: items[index],
                          showLine: index < items.length - 1,
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
                  height: 60,
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
            padding: const EdgeInsets.only(bottom: 8),
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
                  maxLines: 1,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CaRismaDesignTokens.textSecondary,
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
  const months = <String>[
    'Jan',
    'Feb',
    'Mär',
    'Apr',
    'Mai',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Okt',
    'Nov',
    'Dez',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
