import 'package:flutter/material.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/glass_card.dart';

class ProfileVehicleStatisticsCard extends StatelessWidget {
  const ProfileVehicleStatisticsCard({
    super.key,
    required this.profileViews,
    required this.totalLikes,
  });

  final Stream<int> profileViews;
  final Stream<int> totalLikes;

  @override
  Widget build(BuildContext context) {
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
              Text(
                'Statistik',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatisticTile(
                  statistic: _VehicleStatistic(
                    icon: Icons.visibility_outlined,
                    label: 'Profilaufrufe',
                    values: profileViews,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatisticTile(
                  statistic: _VehicleStatistic(
                    icon: Icons.favorite_outline_rounded,
                    label: 'Gefällt mir',
                    values: totalLikes,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatisticTile extends StatelessWidget {
  const _StatisticTile({required this.statistic});

  final _VehicleStatistic statistic;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: statistic.values,
      initialData: 0,
      builder: (context, snapshot) => Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusSmall),
          color: CaRismaDesignTokens.controlSurface,
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(
              statistic.icon,
              size: 21,
              color: CaRismaDesignTokens.blueBright,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${snapshot.hasError ? 0 : snapshot.data ?? 0}',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleStatistic {
  const _VehicleStatistic({
    required this.icon,
    required this.label,
    required this.values,
  });

  final IconData icon;
  final String label;
  final Stream<int> values;
}
