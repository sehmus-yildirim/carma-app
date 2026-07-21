import 'package:flutter/material.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/profile_vehicle.dart';
import '../../data/profile_vehicle_encounter.dart';

class ProfileVehicleStatisticsCard extends StatelessWidget {
  const ProfileVehicleStatisticsCard({
    super.key,
    required this.vehicle,
    required this.postCount,
    required this.encounters,
    required this.isOwnProfile,
  });

  final ProfileVehicle vehicle;
  final int postCount;
  final Stream<List<ProfileVehicleEncounter>> encounters;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProfileVehicleEncounter>>(
      stream: encounters,
      builder: (context, snapshot) {
        final confirmedEncounterCount = (snapshot.data ?? const [])
            .where((encounter) => encounter.isConfirmed)
            .length;
        final statistics = <_VehicleStatistic>[
          _VehicleStatistic(
            icon: Icons.grid_view_rounded,
            label: 'Beiträge',
            value: '$postCount',
          ),
          _VehicleStatistic(
            icon: Icons.connect_without_contact_rounded,
            label: 'Begegnungen',
            value: snapshot.hasError ? '–' : '$confirmedEncounterCount',
          ),
          if (isOwnProfile)
            _VehicleStatistic(
              icon: Icons.speed_rounded,
              label: 'Kilometerstand',
              value: _formatMileage(vehicle.mileage),
            ),
          if (isOwnProfile)
            _VehicleStatistic(
              icon: Icons.checklist_rounded,
              label: 'Ausstattung',
              value: '${vehicle.equipment.length}',
            ),
          _VehicleStatistic(
            icon: Icons.calendar_month_rounded,
            label: 'Bei CaRisma seit',
            value: _formatMembershipDate(vehicle.createdAt),
          ),
        ];

        return GlassCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    size: 21,
                    color: CaRismaDesignTokens.blueBright,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Statistik',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final statistic in statistics)
                        SizedBox(
                          width: tileWidth,
                          child: _StatisticTile(statistic: statistic),
                        ),
                    ],
                  );
                },
              ),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) ...[
                const SizedBox(height: 10),
                Text(
                  'Begegnungen werden aktualisiert …',
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

class _StatisticTile extends StatelessWidget {
  const _StatisticTile({required this.statistic});

  final _VehicleStatistic statistic;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusSmall),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statistic.icon, size: 19, color: CaRismaDesignTokens.blueBright),
          const SizedBox(height: 8),
          Text(
            statistic.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            statistic.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CaRismaDesignTokens.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleStatistic {
  const _VehicleStatistic({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

String _formatMileage(int? mileage) {
  if (mileage == null) return 'Nicht angegeben';
  final digits = mileage.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return '$buffer km';
}

String _formatMembershipDate(DateTime? date) {
  if (date == null) return 'Nicht angegeben';
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
