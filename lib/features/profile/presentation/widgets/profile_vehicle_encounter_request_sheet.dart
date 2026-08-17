import 'package:flutter/material.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../data/profile_vehicle.dart';
import '../../data/profile_vehicle_encounter.dart';
import 'profile_vehicle_encounters_card.dart';

class ProfileVehicleEncounterRequestDraft {
  const ProfileVehicleEncounterRequestDraft({
    required this.ownVehicle,
    required this.type,
    required this.encounterDate,
    this.locationLabel,
  });

  final ProfileVehicle ownVehicle;
  final ProfileVehicleEncounterType type;
  final DateTime encounterDate;
  final String? locationLabel;
}

Future<ProfileVehicleEncounterRequestDraft?>
showProfileVehicleEncounterRequestSheet(
  BuildContext context, {
  required List<ProfileVehicle> ownVehicles,
  required ProfileVehicle targetVehicle,
}) async {
  final locationController = TextEditingController();
  var selectedVehicle = ownVehicles.first;
  var type = ProfileVehicleEncounterType.meet;
  var encounterDate = DateTime.now();

  try {
    return await showModalBottomSheet<ProfileVehicleEncounterRequestDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: CaRismaDesignTokens.background,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> chooseDate() async {
            final selected = await showDatePicker(
              context: context,
              initialDate: encounterDate,
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
            );
            if (selected != null) {
              setSheetState(() => encounterDate = selected);
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.connect_without_contact_rounded,
                        color: CaRismaDesignTokens.blueBright,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Begegnung anfragen',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Schließen',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mit ${targetVehicle.displayName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CaRismaDesignTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ProfileVehicle>(
                    initialValue: selectedVehicle,
                    decoration: const InputDecoration(
                      labelText: 'Dein Fahrzeug',
                    ),
                    items: ownVehicles
                        .map(
                          (vehicle) => DropdownMenuItem(
                            value: vehicle,
                            child: Text(vehicle.displayName),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => selectedVehicle = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProfileVehicleEncounterType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Art'),
                    items: ProfileVehicleEncounterType.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              profileVehicleEncounterTypeLabel(value),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setSheetState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Datum'),
                    subtitle: Text(_formatDate(encounterDate)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: chooseDate,
                  ),
                  TextField(
                    controller: locationController,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Ort oder Region (optional)',
                      helperText: 'Wird nur nach Bestätigung veröffentlicht.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(
                        ProfileVehicleEncounterRequestDraft(
                          ownVehicle: selectedVehicle,
                          type: type,
                          encounterDate: encounterDate,
                          locationLabel: locationController.text.trim(),
                        ),
                      ),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Anfrage senden'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  } finally {
    locationController.dispose();
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
