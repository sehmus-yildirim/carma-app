import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../data/profile_vehicle.dart';
import '../../data/profile_vehicle_modification.dart';

Future<bool> showProfileVehicleModificationSheet(
  BuildContext context, {
  required String userId,
  required ProfileVehicle vehicle,
  required String modificationId,
  required Future<void> Function(ProfileVehicleModification modification)
  onSave,
  ProfileVehicleModification? modification,
}) async {
  final titleController = TextEditingController(text: modification?.title);
  final manufacturerController = TextEditingController(
    text: modification?.manufacturer,
  );
  final productController = TextEditingController(text: modification?.product);
  final descriptionController = TextEditingController(
    text: modification?.description,
  );
  final workshopController = TextEditingController(
    text: modification?.workshop,
  );
  final costController = TextEditingController(
    text: modification?.costCents == null
        ? ''
        : (modification!.costCents! / 100).toStringAsFixed(2),
  );
  final powerController = TextEditingController(
    text: modification?.powerChangeHp?.toString(),
  );

  var category =
      modification?.category ?? ProfileVehicleModificationCategory.other;
  var modifiedAt = modification?.modifiedAt;
  var isRegistered = modification?.isRegistered ?? false;
  var isPublic =
      modification?.visibility == ProfileVehicleVisibility.contacts &&
      vehicle.isPubliclyVisible;
  var isSaving = false;

  try {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: CaRismaDesignTokens.background,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> chooseDate() async {
              final selected = await showDatePicker(
                context: context,
                initialDate: modifiedAt ?? DateTime.now(),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (selected != null) {
                setSheetState(() => modifiedAt = selected);
              }
            }

            Future<void> submit() async {
              final title = titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(content: Text('Bitte gib einen Titel ein.')),
                );
                return;
              }
              final costText = costController.text.trim().replaceAll(',', '.');
              final cost = costText.isEmpty ? null : double.tryParse(costText);
              if (costText.isNotEmpty && (cost == null || cost < 0)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(content: Text('Bitte prüfe die Kosten.')),
                );
                return;
              }

              setSheetState(() => isSaving = true);
              try {
                await onSave(
                  ProfileVehicleModification(
                    id: modification?.id ?? modificationId,
                    ownerUserId: userId,
                    vehicleId: vehicle.id,
                    title: title,
                    category: category,
                    manufacturer: manufacturerController.text,
                    product: productController.text,
                    description: descriptionController.text,
                    modifiedAt: modifiedAt,
                    workshop: workshopController.text,
                    costCents: cost == null ? null : (cost * 100).round(),
                    powerChangeHp: int.tryParse(powerController.text.trim()),
                    isRegistered: isRegistered,
                    documentPaths: modification?.documentPaths ?? const [],
                    visibility: isPublic
                        ? ProfileVehicleVisibility.contacts
                        : ProfileVehicleVisibility.onlyMe,
                    isDeleted: false,
                    createdAt: modification?.createdAt,
                    updatedAt: modification?.updatedAt,
                  ),
                );
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(true);
                }
              } catch (error) {
                if (!sheetContext.mounted) return;
                setSheetState(() => isSaving = false);
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Umbau konnte nicht gespeichert werden: $error',
                    ),
                  ),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      modification == null
                          ? 'Umbau hinzufügen'
                          : 'Umbau bearbeiten',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CaRismaDesignTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ModificationTextField(
                      controller: titleController,
                      label: 'Titel',
                      maxLength: 120,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ProfileVehicleModificationCategory>(
                      key: ValueKey(category),
                      initialValue: category,
                      isExpanded: true,
                      dropdownColor: CaRismaDesignTokens.controlSurface,
                      decoration: _inputDecoration('Kategorie'),
                      items: ProfileVehicleModificationCategory.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_categoryLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => category = value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ModificationTextField(
                            controller: manufacturerController,
                            label: 'Hersteller',
                            maxLength: 120,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ModificationTextField(
                            controller: productController,
                            label: 'Produkt',
                            maxLength: 120,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ModificationTextField(
                      controller: descriptionController,
                      label: 'Beschreibung',
                      maxLength: 600,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    _ModificationDateField(
                      value: modifiedAt,
                      onTap: chooseDate,
                      onClear: () => setSheetState(() => modifiedAt = null),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ModificationTextField(
                            controller: powerController,
                            label: 'Leistungsänderung',
                            maxLength: 5,
                            signedNumbersOnly: true,
                            suffixText: 'PS',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Eingetragen'),
                            value: isRegistered,
                            onChanged: (value) =>
                                setSheetState(() => isRegistered = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Private Angaben',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Werkstatt, Kosten und spätere Belege werden nicht öffentlich angezeigt.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CaRismaDesignTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ModificationTextField(
                            controller: workshopController,
                            label: 'Werkstatt',
                            maxLength: 160,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ModificationTextField(
                            controller: costController,
                            label: 'Kosten in €',
                            maxLength: 12,
                            decimalNumbersOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Für Kontakte sichtbar'),
                      subtitle: vehicle.isPubliclyVisible
                          ? null
                          : const Text(
                              'Aktiviere zuerst die Sichtbarkeit des Fahrzeugs.',
                            ),
                      value: isPublic,
                      onChanged: vehicle.isPubliclyVisible
                          ? (value) => setSheetState(() => isPublic = value)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isSaving ? null : submit,
                        icon: isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(isSaving ? 'Speichern...' : 'Speichern'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    return result == true;
  } finally {
    titleController.dispose();
    manufacturerController.dispose();
    productController.dispose();
    descriptionController.dispose();
    workshopController.dispose();
    costController.dispose();
    powerController.dispose();
  }
}

class _ModificationTextField extends StatelessWidget {
  const _ModificationTextField({
    required this.controller,
    required this.label,
    required this.maxLength,
    this.maxLines = 1,
    this.signedNumbersOnly = false,
    this.decimalNumbersOnly = false,
    this.suffixText,
  });

  final TextEditingController controller;
  final String label;
  final int maxLength;
  final int maxLines;
  final bool signedNumbersOnly;
  final bool decimalNumbersOnly;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: signedNumbersOnly || decimalNumbersOnly
          ? const TextInputType.numberWithOptions(signed: true, decimal: true)
          : TextInputType.text,
      inputFormatters: [
        LengthLimitingTextInputFormatter(maxLength),
        if (signedNumbersOnly)
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
        if (decimalNumbersOnly)
          FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}')),
      ],
      decoration: _inputDecoration(label).copyWith(suffixText: suffixText),
    );
  }
}

class _ModificationDateField extends StatelessWidget {
  const _ModificationDateField({
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: _inputDecoration('Datum').copyWith(
          suffixIcon: value == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(
                  tooltip: 'Datum entfernen',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
        child: Text(
          value == null
              ? 'Nicht angegeben'
              : '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}',
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: CaRismaDesignTokens.controlSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    ),
  );
}

String profileVehicleModificationCategoryLabel(
  ProfileVehicleModificationCategory category,
) => _categoryLabel(category);

String _categoryLabel(ProfileVehicleModificationCategory category) {
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
