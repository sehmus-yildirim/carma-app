import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/plate/plate_country_config.dart';
import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../data/profile_vehicle.dart';
import '../../data/vehicle_catalog.dart';

const _vehicleColors = <String>[
  'Schwarz',
  'Weiß',
  'Silber',
  'Grau',
  'Blau',
  'Rot',
  'Grün',
  'Braun',
  'Beige',
  'Gelb',
];

Future<bool> showProfileVehicleEditorSheet(
  BuildContext context, {
  required String userId,
  required String vehicleId,
  required Future<void> Function(ProfileVehicle vehicle) onSave,
  ProfileVehicle? vehicle,
}) async {
  var selectedBrand = vehicle?.brand.trim() ?? VehicleCatalog.brands.first;
  var availableModels = _modelsForBrand(selectedBrand, vehicle?.model);
  var selectedModel = vehicle?.model.trim() ?? availableModels.first;
  var selectedColor = vehicle?.color.trim() ?? _vehicleColors.first;
  var countryCode = vehicle?.countryCode.trim().toUpperCase() ?? 'DE';
  var status = vehicle?.status ?? ProfileVehicleStatus.active;
  var visibility = vehicle?.visibility ?? ProfileVehicleVisibility.contacts;
  var showPlate = vehicle?.showPlate ?? false;
  var isPrimary = vehicle?.isPrimary ?? false;
  var isSaving = false;

  final seriesController = TextEditingController(text: vehicle?.series ?? '');
  final regionController = TextEditingController(
    text: vehicle?.plateRegion ?? '',
  );
  final lettersController = TextEditingController(
    text: vehicle?.plateLetters ?? '',
  );
  final numbersController = TextEditingController(
    text: vehicle?.plateNumbers ?? '',
  );
  final mileageController = TextEditingController(
    text: vehicle?.mileage?.toString() ?? '',
  );

  try {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0D1320),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final plateConfig = plateConfigForCountry(countryCode);

            Future<void> submit() async {
              final region = regionController.text.trim().toUpperCase();
              final letters = lettersController.text.trim().toUpperCase();
              final numbers = numbersController.text.trim().toUpperCase();
              if (region.isEmpty ||
                  numbers.isEmpty ||
                  (plateConfig.usesLettersField && letters.isEmpty)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Bitte fülle das Kennzeichen vollständig aus.',
                    ),
                  ),
                );
                return;
              }

              setSheetState(() => isSaving = true);
              try {
                await onSave(
                  ProfileVehicle(
                    id: vehicle?.id ?? vehicleId,
                    ownerUserId: userId,
                    brand: selectedBrand,
                    model: selectedModel,
                    series: seriesController.text,
                    color: selectedColor,
                    countryCode: countryCode,
                    plateRegion: region,
                    plateLetters: plateConfig.usesLettersField ? letters : '',
                    plateNumbers: numbers,
                    isPrimary: isPrimary,
                    isVerified: vehicle?.isVerified ?? false,
                    status: status,
                    visibility: visibility,
                    showPlate: showPlate,
                    year: vehicle?.year,
                    firstRegistration: vehicle?.firstRegistration,
                    bodyStyle: vehicle?.bodyStyle,
                    engineDescription: vehicle?.engineDescription,
                    displacementCcm: vehicle?.displacementCcm,
                    horsepower: vehicle?.horsepower,
                    kilowatts: vehicle?.kilowatts,
                    fuelType: vehicle?.fuelType,
                    transmission: vehicle?.transmission,
                    drivetrain: vehicle?.drivetrain,
                    equipment: vehicle?.equipment ?? const [],
                    hsn: vehicle?.hsn,
                    tsn: vehicle?.tsn,
                    vin: vehicle?.vin,
                    ownedSince: vehicle?.ownedSince,
                    mileage: int.tryParse(mileageController.text.trim()),
                    heroImageUrl: vehicle?.heroImageUrl,
                    heroImagePath: vehicle?.heroImagePath,
                    heroImageStatus:
                        vehicle?.heroImageStatus ??
                        VehicleHeroImageStatus.notGenerated,
                    heroSourceHash: vehicle?.heroSourceHash,
                    heroPromptVersion: vehicle?.heroPromptVersion,
                    heroProvider: vehicle?.heroProvider,
                    heroError: vehicle?.heroError,
                    createdAt: vehicle?.createdAt,
                    updatedAt: vehicle?.updatedAt,
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
                      'Fahrzeug konnte nicht gespeichert werden: $error',
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
                      vehicle == null
                          ? 'Fahrzeug hinzufügen'
                          : 'Fahrzeug bearbeiten',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 18),
                    _VehicleDropdown<String>(
                      label: 'Marke',
                      value: selectedBrand,
                      values: VehicleCatalog.brands,
                      labelFor: (value) => value,
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          selectedBrand = value;
                          availableModels = _modelsForBrand(value, null);
                          selectedModel = availableModels.first;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _VehicleDropdown<String>(
                      label: 'Modell',
                      value: selectedModel,
                      values: availableModels,
                      labelFor: (value) => value,
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => selectedModel = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    _VehicleTextField(
                      controller: seriesController,
                      label: 'Baureihe (optional)',
                      maxLength: 120,
                    ),
                    const SizedBox(height: 10),
                    _VehicleDropdown<String>(
                      label: 'Farbe',
                      value: selectedColor,
                      values: _vehicleColors,
                      labelFor: (value) => value,
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => selectedColor = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    _VehicleDropdown<PlateCountryConfig>(
                      label: 'Land',
                      value: plateConfig,
                      values: plateCountryConfigs,
                      labelFor: (value) => value.countryLabel,
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          countryCode = value.countryCode;
                          regionController.clear();
                          lettersController.clear();
                          numbersController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _VehicleTextField(
                            controller: regionController,
                            label: plateConfig.regionLabel,
                            maxLength: plateConfig.regionMaxLength,
                            upperCase: true,
                          ),
                        ),
                        if (plateConfig.usesLettersField) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _VehicleTextField(
                              controller: lettersController,
                              label: 'Buchstaben',
                              maxLength: plateConfig.lettersMaxLength,
                              upperCase: true,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          child: _VehicleTextField(
                            controller: numbersController,
                            label: 'Zahlen',
                            maxLength: plateConfig.numbersMaxLength,
                            upperCase: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _VehicleTextField(
                      controller: mileageController,
                      label: 'Kilometerstand (optional)',
                      maxLength: 8,
                      numbersOnly: true,
                    ),
                    const SizedBox(height: 10),
                    _VehicleDropdown<ProfileVehicleStatus>(
                      label: 'Status',
                      value: status,
                      values: ProfileVehicleStatus.values
                          .where(
                            (value) => value != ProfileVehicleStatus.archived,
                          )
                          .toList(),
                      labelFor: _statusLabel,
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => status = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    _VehicleSwitch(
                      title: 'Für Kontakte sichtbar',
                      value: visibility == ProfileVehicleVisibility.contacts,
                      onChanged: (value) => setSheetState(
                        () => visibility = value
                            ? ProfileVehicleVisibility.contacts
                            : ProfileVehicleVisibility.onlyMe,
                      ),
                    ),
                    _VehicleSwitch(
                      title: 'Kennzeichen anzeigen',
                      value: showPlate,
                      onChanged: (value) =>
                          setSheetState(() => showPlate = value),
                    ),
                    _VehicleSwitch(
                      title: 'Als Hauptfahrzeug verwenden',
                      value: isPrimary,
                      onChanged: vehicle?.isPrimary == true
                          ? null
                          : (value) => setSheetState(() => isPrimary = value),
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
    seriesController.dispose();
    regionController.dispose();
    lettersController.dispose();
    numbersController.dispose();
    mileageController.dispose();
  }
}

class _VehicleDropdown<T> extends StatelessWidget {
  const _VehicleDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      dropdownColor: CaRismaDesignTokens.controlSurface,
      decoration: _inputDecoration(label),
      items: values
          .map(
            (value) => DropdownMenuItem<T>(
              value: value,
              child: Text(labelFor(value), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _VehicleTextField extends StatelessWidget {
  const _VehicleTextField({
    required this.controller,
    required this.label,
    required this.maxLength,
    this.upperCase = false,
    this.numbersOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final int maxLength;
  final bool upperCase;
  final bool numbersOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: upperCase
          ? TextCapitalization.characters
          : TextCapitalization.sentences,
      keyboardType: numbersOnly ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        LengthLimitingTextInputFormatter(maxLength),
        if (numbersOnly) FilteringTextInputFormatter.digitsOnly,
        if (upperCase)
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9ÄÖÜäöü]')),
      ],
      decoration: _inputDecoration(label),
    );
  }
}

class _VehicleSwitch extends StatelessWidget {
  const _VehicleSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: onChanged == null
              ? CaRismaDesignTokens.textSecondary
              : Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      value: value,
      onChanged: onChanged,
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

List<String> _modelsForBrand(String brand, String? currentModel) {
  final models = [...?VehicleCatalog.modelsByBrand[brand]];
  final normalizedCurrent = currentModel?.trim() ?? '';
  if (normalizedCurrent.isNotEmpty && !models.contains(normalizedCurrent)) {
    models.insert(0, normalizedCurrent);
  }
  return models.isEmpty ? const ['Sonstiges'] : models;
}

String _statusLabel(ProfileVehicleStatus status) {
  return switch (status) {
    ProfileVehicleStatus.active => 'Aktiv',
    ProfileVehicleStatus.modification => 'Im Umbau',
    ProfileVehicleStatus.repair => 'In Reparatur',
    ProfileVehicleStatus.seasonal => 'Saisonfahrzeug',
    ProfileVehicleStatus.deregistered => 'Abgemeldet',
    ProfileVehicleStatus.sold => 'Verkauft',
    ProfileVehicleStatus.noLongerOwned => 'Nicht mehr im Besitz',
    ProfileVehicleStatus.archived => 'Archiviert',
  };
}
