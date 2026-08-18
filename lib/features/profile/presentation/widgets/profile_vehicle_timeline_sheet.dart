import 'package:flutter/material.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../data/profile_vehicle.dart';
import '../../data/profile_vehicle_timeline_entry.dart';

Future<bool> showProfileVehicleTimelineSheet(
  BuildContext context, {
  required String userId,
  required ProfileVehicle vehicle,
  required String entryId,
  required Future<void> Function(ProfileVehicleTimelineEntry entry) onSave,
  ProfileVehicleTimelineEntry? entry,
}) async {
  final titleController = TextEditingController(text: entry?.title);
  final descriptionController = TextEditingController(text: entry?.description);
  var type = entry?.type ?? ProfileVehicleTimelineType.custom;
  var eventDate = entry?.eventDate ?? DateTime.now();
  var isSaving = false;
  var isDirty = false;
  void markDirty() => isDirty = true;
  titleController.addListener(markDirty);
  descriptionController.addListener(markDirty);

  try {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: CaRismaDesignTokens.background,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> closeEditor() async {
            if (isSaving) return;
            if (!isDirty) {
              Navigator.of(sheetContext).pop(false);
              return;
            }
            final discard = await showDialog<bool>(
              context: sheetContext,
              builder: (dialogContext) => AlertDialog(
                backgroundColor: CaRismaDesignTokens.card,
                title: const Text('Änderungen verwerfen?'),
                content: const Text(
                  'Das Timeline-Ereignis wurde noch nicht gespeichert.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Weiter bearbeiten'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text(
                      'Verwerfen',
                      style: TextStyle(color: CaRismaDesignTokens.danger),
                    ),
                  ),
                ],
              ),
            );
            if (discard == true && sheetContext.mounted) {
              Navigator.of(sheetContext).pop(false);
            }
          }

          Future<void> save() async {
            final title = titleController.text.trim();
            if (isSaving) return;
            if (title.isEmpty) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(content: Text('Bitte gib einen Titel ein.')),
              );
              return;
            }
            final currentMonth = DateTime(
              DateTime.now().year,
              DateTime.now().month,
            );
            final selectedMonth = DateTime(eventDate.year, eventDate.month);
            if (selectedMonth.isAfter(currentMonth)) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Das Timeline-Datum darf nicht in der Zukunft liegen.',
                  ),
                ),
              );
              return;
            }
            setSheetState(() => isSaving = true);
            try {
              await onSave(
                ProfileVehicleTimelineEntry(
                  id: entryId,
                  ownerUserId: userId,
                  vehicleId: vehicle.id,
                  type: type,
                  title: title,
                  description: descriptionController.text.trim(),
                  eventDate: eventDate,
                  mediaUrls: entry?.mediaUrls ?? const [],
                  linkedPostId: entry?.linkedPostId,
                  linkedModificationId: entry?.linkedModificationId,
                  isAutomaticallyCreated:
                      entry?.isAutomaticallyCreated ?? false,
                  visibility: vehicle.isPubliclyVisible
                      ? ProfileVehicleVisibility.contacts
                      : ProfileVehicleVisibility.onlyMe,
                  createdAt: entry?.createdAt,
                  updatedAt: entry?.updatedAt,
                ),
              );
              if (sheetContext.mounted) Navigator.of(sheetContext).pop(true);
            } catch (error) {
              if (!sheetContext.mounted) return;
              setSheetState(() => isSaving = false);
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(
                  content: Text(
                    'Timeline-Eintrag konnte nicht gespeichert werden: $error',
                  ),
                ),
              );
            }
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (!didPop) await closeEditor();
            },
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                16,
                18,
                MediaQuery.viewInsetsOf(context).bottom + 18,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.timeline_rounded,
                                  color: CaRismaDesignTokens.blueBright,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry == null
                                        ? 'Ereignis hinzufügen'
                                        : 'Ereignis bearbeiten',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Schließen',
                                  onPressed: closeEditor,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<ProfileVehicleTimelineType>(
                              initialValue: type,
                              decoration: const InputDecoration(
                                labelText: 'Ereignis',
                              ),
                              items: ProfileVehicleTimelineType.values
                                  .where(
                                    (value) =>
                                        value !=
                                            ProfileVehicleTimelineType
                                                .vehicleCreated &&
                                        value !=
                                            ProfileVehicleTimelineType
                                                .modificationAdded &&
                                        value !=
                                            ProfileVehicleTimelineType
                                                .statusChanged,
                                  )
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        profileVehicleTimelineTypeLabel(value),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) {
                                  setSheetState(() {
                                    type = value;
                                    isDirty = true;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: titleController,
                              maxLength: 120,
                              decoration: const InputDecoration(
                                labelText: 'Titel',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: descriptionController,
                              maxLength: 600,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Beschreibung (optional)',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: eventDate.month,
                                    decoration: const InputDecoration(
                                      labelText: 'Monat',
                                    ),
                                    items:
                                        List<int>.generate(
                                              12,
                                              (index) => index + 1,
                                            )
                                            .map(
                                              (month) => DropdownMenuItem<int>(
                                                value: month,
                                                child: Text(_monthLabel(month)),
                                              ),
                                            )
                                            .toList(growable: false),
                                    onChanged: (month) {
                                      if (month == null) return;
                                      setSheetState(() {
                                        eventDate = DateTime(
                                          eventDate.year,
                                          month,
                                        );
                                        isDirty = true;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: eventDate.year,
                                    decoration: const InputDecoration(
                                      labelText: 'Jahr',
                                    ),
                                    items:
                                        List<int>.generate(
                                              DateTime.now().year - 1949,
                                              (index) =>
                                                  DateTime.now().year - index,
                                            )
                                            .map(
                                              (year) => DropdownMenuItem<int>(
                                                value: year,
                                                child: Text('$year'),
                                              ),
                                            )
                                            .toList(growable: false),
                                    onChanged: (year) {
                                      if (year == null) return;
                                      setSheetState(() {
                                        eventDate = DateTime(
                                          year,
                                          eventDate.month,
                                        );
                                        isDirty = true;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isSaving ? null : save,
                        icon: isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(isSaving ? 'Speichert …' : 'Speichern'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    return result == true;
  } finally {
    titleController.removeListener(markDirty);
    descriptionController.removeListener(markDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      titleController.dispose();
      descriptionController.dispose();
    });
  }
}

String profileVehicleTimelineTypeLabel(ProfileVehicleTimelineType type) {
  return switch (type) {
    ProfileVehicleTimelineType.vehicleCreated => 'Fahrzeug hinzugefügt',
    ProfileVehicleTimelineType.vehicleAcquired => 'Fahrzeug übernommen',
    ProfileVehicleTimelineType.registered => 'Fahrzeug angemeldet',
    ProfileVehicleTimelineType.modificationAdded => 'Umbau hinzugefügt',
    ProfileVehicleTimelineType.maintenance => 'Wartung durchgeführt',
    ProfileVehicleTimelineType.repair => 'Reparatur durchgeführt',
    ProfileVehicleTimelineType.wheelsInstalled => 'Neue Felgen montiert',
    ProfileVehicleTimelineType.mileageMilestone => 'Kilometer-Meilenstein',
    ProfileVehicleTimelineType.trip => 'Reise',
    ProfileVehicleTimelineType.meet => 'Treffen',
    ProfileVehicleTimelineType.seasonStart => 'Saisonstart',
    ProfileVehicleTimelineType.seasonEnd => 'Saisonende',
    ProfileVehicleTimelineType.sold => 'Fahrzeug verkauft',
    ProfileVehicleTimelineType.archived => 'Fahrzeug archiviert',
    ProfileVehicleTimelineType.statusChanged => 'Status geändert',
    ProfileVehicleTimelineType.custom => 'Eigenes Ereignis',
  };
}

String _monthLabel(int month) {
  const months = <String>[
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];
  return months[month - 1];
}
