import 'package:flutter/material.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/profile_vehicle.dart';

class ProfileVehicleManageCard extends StatelessWidget {
  const ProfileVehicleManageCard({
    super.key,
    required this.vehicle,
    required this.trailing,
  });

  final ProfileVehicle vehicle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final vehicleName = [
      vehicle.brand.trim(),
      vehicle.model.trim(),
    ].where((value) => value.isNotEmpty).join(' ');
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CaRismaBlueIconBox(
            icon: Icons.directions_car_filled_rounded,
            size: 46,
            iconSize: 23,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vehicleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _VehicleInfoChip(
                      icon: Icons.pin_outlined,
                      label: vehicle.displayPlate,
                    ),
                    if (vehicle.color.trim().isNotEmpty)
                      _VehicleInfoChip(
                        icon: Icons.palette_outlined,
                        label: vehicle.color.trim(),
                      ),
                  ],
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _VehicleInfoChip extends StatelessWidget {
  const _VehicleInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: CaRismaDesignTokens.blueBright),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CaRismaDesignTokens.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
