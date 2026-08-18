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
  final modifiedAtController = TextEditingController(
    text: _formatModificationDate(modification?.modifiedAt),
  );

  var category =
      modification?.category ?? ProfileVehicleModificationCategory.other;
  var isRegistered = modification?.isRegistered ?? false;
  var isSaving = false;
  var isDirty = false;
  final trackedControllers = <TextEditingController>[
    titleController,
    manufacturerController,
    productController,
    descriptionController,
    workshopController,
    costController,
    powerController,
    modifiedAtController,
  ];
  void markDirty() => isDirty = true;
  for (final controller in trackedControllers) {
    controller.addListener(markDirty);
  }

  try {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: CaRismaDesignTokens.background,
      builder: (sheetContext) {
        return StatefulBuilder(
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
                    'Der Umbau wurde noch nicht gespeichert.',
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
              final modifiedAt = _parseModificationDate(
                modifiedAtController.text,
              );
              if (modifiedAtController.text.trim().isNotEmpty &&
                  modifiedAt == null) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Bitte gib das Datum als gültiges TT.MM.JJJJ ein.',
                    ),
                  ),
                );
                return;
              }
              final powerText = powerController.text.trim();
              final powerChange = int.tryParse(powerText);
              if (powerText.isNotEmpty && powerChange == null) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Bitte prüfe die Leistungsänderung.'),
                  ),
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
                    powerChangeHp: powerChange,
                    isRegistered: isRegistered,
                    documentPaths: modification?.documentPaths ?? const [],
                    visibility: vehicle.isPubliclyVisible
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
              } catch (_) {
                if (!sheetContext.mounted) return;
                setSheetState(() => isSaving = false);
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text('Umbau konnte nicht gespeichert werden.'),
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
                  20,
                  14,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
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
                                  Expanded(
                                    child: Text(
                                      modification == null
                                          ? 'Umbau hinzufügen'
                                          : 'Umbau bearbeiten',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
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
                              const SizedBox(height: 4),
                              Text(
                                vehicle.displayName,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
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
                              DropdownButtonFormField<
                                ProfileVehicleModificationCategory
                              >(
                                key: ValueKey(category),
                                initialValue: category,
                                isExpanded: true,
                                dropdownColor:
                                    CaRismaDesignTokens.controlSurface,
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
                                    setSheetState(() {
                                      category = value;
                                      isDirty = true;
                                    });
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
                                controller: modifiedAtController,
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
                                      onChanged: (value) => setSheetState(() {
                                        isRegistered = value;
                                        isDirty = true;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Private Angaben',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Werkstatt, Kosten und spätere Belege werden nicht öffentlich angezeigt.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
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
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isSaving ? null : submit,
                          icon: isSaving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(isSaving ? 'Speichern...' : 'Speichern'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    return result == true;
  } finally {
    for (final controller in trackedControllers) {
      controller.removeListener(markDirty);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      titleController.dispose();
      manufacturerController.dispose();
      productController.dispose();
      descriptionController.dispose();
      workshopController.dispose();
      costController.dispose();
      powerController.dispose();
      modifiedAtController.dispose();
    });
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
  const _ModificationDateField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final errorText = _modificationDateInputError(value.text);
        return TextField(
          controller: controller,
          keyboardType: TextInputType.datetime,
          inputFormatters: const [_ModificationDateInputFormatter()],
          decoration: _inputDecoration('Datum').copyWith(
            hintText: 'TT.MM.JJJJ',
            errorText: errorText,
            errorMaxLines: 2,
          ),
        );
      },
    );
  }
}

class _ModificationDateInputFormatter extends TextInputFormatter {
  const _ModificationDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var index = 0; index < limited.length; index++) {
      if (index == 2 || index == 4) buffer.write('.');
      buffer.write(limited[index]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String _formatModificationDate(DateTime? value) {
  if (value == null) return '';
  return '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';
}

DateTime? _parseModificationDate(String source) {
  final parts = source.trim().split('.');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null || year < 1950) return null;
  final value = DateTime(year, month, day);
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);
  if (value.year != year ||
      value.month != month ||
      value.day != day ||
      value.isAfter(todayOnly)) {
    return null;
  }
  return value;
}

String? _modificationDateInputError(String source) {
  final text = source.trim();
  if (text.isEmpty) return null;

  final parts = text.split('.');
  final day = int.tryParse(parts.first);
  if (parts.first.length == 2 && (day == null || day < 1 || day > 31)) {
    return 'Der Tag muss zwischen 01 und 31 liegen.';
  }

  if (parts.length > 1 && parts[1].length == 2) {
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) {
      return 'Der Monat muss zwischen 01 und 12 liegen.';
    }
  }

  if (parts.length < 3 || parts[2].length < 4) return null;
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  final currentYear = DateTime.now().year;
  if (year == null || year < 1950 || year > currentYear) {
    return 'Das Jahr muss zwischen 1950 und $currentYear liegen.';
  }
  if (day == null || month == null) return 'Das Datum ist ungültig.';

  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return 'Dieses Kalenderdatum gibt es nicht.';
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (date.isAfter(today)) return 'Das Datum darf nicht in der Zukunft liegen.';
  return null;
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
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
