import 'package:flutter/material.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/profile_vehicle.dart';
import '../../data/profile_vehicle_encounter.dart';

class ProfileVehicleEncountersCard extends StatelessWidget {
  const ProfileVehicleEncountersCard({
    super.key,
    required this.vehicle,
    required this.currentUserId,
    required this.encounters,
    required this.isOwnProfile,
    required this.onRequest,
    required this.onAccept,
    required this.onDecline,
    required this.onRemove,
  });

  final ProfileVehicle vehicle;
  final String currentUserId;
  final Stream<List<ProfileVehicleEncounter>> encounters;
  final bool isOwnProfile;
  final VoidCallback onRequest;
  final ValueChanged<ProfileVehicleEncounter> onAccept;
  final ValueChanged<ProfileVehicleEncounter> onDecline;
  final ValueChanged<ProfileVehicleEncounter> onRemove;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProfileVehicleEncounter>>(
      stream: encounters,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ProfileVehicleEncounter>[];
        final preview = items.take(4).toList(growable: false);
        return GlassCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.connect_without_contact_rounded,
                    size: 21,
                    color: CaRismaDesignTokens.blueBright,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Begegnungen',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (!isOwnProfile)
                    TextButton.icon(
                      onPressed: onRequest,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Anfragen'),
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
                  'Begegnungen konnten nicht geladen werden.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CaRismaDesignTokens.textSecondary,
                  ),
                )
              else if (preview.isEmpty)
                Text(
                  isOwnProfile
                      ? 'Noch keine Begegnungen für dieses Fahrzeug.'
                      : 'Für dieses Fahrzeug wurden keine Begegnungen freigegeben.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CaRismaDesignTokens.textSecondary,
                  ),
                )
              else ...[
                for (var index = 0; index < preview.length; index++) ...[
                  _EncounterRow(
                    encounter: preview[index],
                    vehicle: vehicle,
                    currentUserId: currentUserId,
                    isOwnProfile: isOwnProfile,
                    onAccept: () => onAccept(preview[index]),
                    onDecline: () => onDecline(preview[index]),
                    onRemove: () => onRemove(preview[index]),
                  ),
                  if (index < preview.length - 1)
                    Divider(color: Colors.white.withValues(alpha: 0.07)),
                ],
                if (items.length > preview.length)
                  Text(
                    '+ ${items.length - preview.length} weitere Begegnungen',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CaRismaDesignTokens.textMuted,
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

class _EncounterRow extends StatelessWidget {
  const _EncounterRow({
    required this.encounter,
    required this.vehicle,
    required this.currentUserId,
    required this.isOwnProfile,
    required this.onAccept,
    required this.onDecline,
    required this.onRemove,
  });

  final ProfileVehicleEncounter encounter;
  final ProfileVehicle vehicle;
  final String currentUserId;
  final bool isOwnProfile;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final selectedIsInitiator =
        encounter.initiatorUserId == vehicle.ownerUserId &&
        encounter.initiatorVehicleId == vehicle.id;
    final otherLabel = selectedIsInitiator
        ? encounter.recipientVehicleLabel
        : encounter.initiatorVehicleLabel;
    final otherPhoto = selectedIsInitiator
        ? encounter.recipientPhotoUrl
        : encounter.initiatorPhotoUrl;
    final incoming = encounter.isIncomingFor(currentUserId);
    final outgoing = encounter.isOutgoingFor(currentUserId);
    final photoUrl = otherPhoto?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: CaRismaDesignTokens.bluePrimary.withValues(
              alpha: 0.16,
            ),
            backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
            child: photoUrl.isEmpty
                ? const Icon(
                    Icons.directions_car_rounded,
                    color: CaRismaDesignTokens.blueBright,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherLabel.isEmpty ? 'Fahrzeug' : otherLabel,
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
                    profileVehicleEncounterTypeLabel(encounter.type),
                    _formatDate(encounter.encounterDate),
                    if ((encounter.locationLabel ?? '').trim().isNotEmpty)
                      encounter.locationLabel!.trim(),
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CaRismaDesignTokens.textSecondary,
                  ),
                ),
                if (isOwnProfile && incoming) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: onAccept,
                        icon: const Icon(Icons.check_rounded, size: 17),
                        label: const Text('Bestätigen'),
                      ),
                      TextButton(
                        onPressed: onDecline,
                        child: const Text('Ablehnen'),
                      ),
                    ],
                  ),
                ] else if (isOwnProfile && outgoing) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Anfrage ausstehend',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: CaRismaDesignTokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isOwnProfile && encounter.isConfirmed)
            IconButton(
              tooltip: 'Begegnung entfernen',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              iconSize: 19,
            ),
        ],
      ),
    );
  }
}

String profileVehicleEncounterTypeLabel(ProfileVehicleEncounterType type) {
  return switch (type) {
    ProfileVehicleEncounterType.spotted => 'Fahrzeug gesehen',
    ProfileVehicleEncounterType.meet => 'Treffen',
    ProfileVehicleEncounterType.trip => 'Gemeinsame Fahrt',
    ProfileVehicleEncounterType.event => 'Veranstaltung',
    ProfileVehicleEncounterType.other => 'Begegnung',
  };
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
