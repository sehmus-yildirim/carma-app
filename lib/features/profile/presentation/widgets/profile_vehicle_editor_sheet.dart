import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/plate/dach_plate_presentation.dart';
import '../../../../shared/plate/plate_country_config.dart';
import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/carisma_license_plate_preview.dart';
import '../../../../shared/widgets/carisma_primary_button.dart';
import '../../data/profile_vehicle.dart';
import '../../data/profile_vehicle_repository.dart';
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
  Future<void> Function()? onOpenVerification,
  ProfileVehicle? vehicle,
}) async {
  var selectedBrand = vehicle?.brand.trim() ?? VehicleCatalog.brands.first;
  var availableModels = _modelsForBrand(selectedBrand, vehicle?.model);
  var selectedModel = vehicle?.model.trim() ?? availableModels.first;
  var selectedColor = vehicle?.color.trim() ?? _vehicleColors.first;
  var countryCode = vehicle?.countryCode.trim().toUpperCase() ?? 'DE';
  var status = vehicle?.status ?? ProfileVehicleStatus.active;
  var useRelationship =
      vehicle?.useRelationship ?? ProfileVehicleUseRelationship.owner;
  var vehicleType = vehicle?.vehicleType ?? ProfileVehicleType.passengerCar;
  var plateType = vehicle?.plateType ?? ProfilePlateType.standard;
  var seasonStartMonth = vehicle?.seasonStartMonth;
  var seasonEndMonth = vehicle?.seasonEndMonth;
  var showOnPublicProfile = vehicle?.showOnPublicProfile ?? true;
  var discoverableByPlate = vehicle?.discoverableByPlate ?? true;
  var selectableInStories = vehicle?.selectableInStories ?? true;
  var allowContactRequests = vehicle?.allowContactRequests ?? true;
  var plateDisplayMode =
      vehicle?.plateDisplayMode ?? ProfilePlateDisplayMode.hidden;
  var isPrimary = vehicle?.isPrimary ?? false;
  var isSaving = false;
  var isDirty = false;
  if (countryCode != 'DE' &&
      (plateType == ProfilePlateType.electric ||
          plateType == ProfilePlateType.historic)) {
    plateType = ProfilePlateType.standard;
  }
  if (plateType == ProfilePlateType.seasonal) {
    seasonStartMonth ??= 3;
    seasonEndMonth ??= 10;
  }

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
  final yearController = TextEditingController(
    text: vehicle?.year?.toString() ?? '',
  );
  final verificationLocked = vehicle?.verificationLocked == true;
  void markDirty() => isDirty = true;
  for (final controller in [
    seriesController,
    regionController,
    lettersController,
    numbersController,
    mileageController,
    yearController,
  ]) {
    controller.addListener(markDirty);
  }

  try {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0D1320),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final plateConfig = plateConfigForCountry(countryCode);

            void updateEditor(VoidCallback update) {
              setSheetState(() {
                update();
                isDirty = true;
              });
            }

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
                  title: const Text(
                    'Änderungen verwerfen?',
                    style: TextStyle(color: CaRismaDesignTokens.textPrimary),
                  ),
                  content: const Text(
                    'Die Fahrzeugdaten wurden noch nicht gespeichert.',
                    style: TextStyle(color: CaRismaDesignTokens.textSecondary),
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
              if (isSaving) return;
              final region = regionController.text.trim().toUpperCase();
              final letters = lettersController.text.trim().toUpperCase();
              var numbers = numbersController.text.trim().toUpperCase();
              if (countryCode == 'DE' &&
                  plateType == ProfilePlateType.electric &&
                  !numbers.endsWith('E')) {
                numbers = '${numbers.replaceAll(RegExp(r'[EH]$'), '')}E';
              }
              if (countryCode == 'DE' &&
                  plateType == ProfilePlateType.historic &&
                  !numbers.endsWith('H')) {
                numbers = '${numbers.replaceAll(RegExp(r'[EH]$'), '')}H';
              }
              final yearText = yearController.text.trim();
              final year = int.tryParse(yearText);
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
              if (yearText.isNotEmpty &&
                  (year == null ||
                      year < 1886 ||
                      year > DateTime.now().year + 1)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Bitte gib ein gültiges Baujahr ein.'),
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
                    verificationStatus:
                        vehicle?.verificationStatus ??
                        ProfileVehicleVerificationStatus.unverified,
                    verificationLocked: vehicle?.verificationLocked ?? false,
                    verificationRejectionReason:
                        vehicle?.verificationRejectionReason,
                    status: status,
                    visibility: showOnPublicProfile
                        ? ProfileVehicleVisibility.contacts
                        : ProfileVehicleVisibility.onlyMe,
                    showPlate:
                        plateDisplayMode != ProfilePlateDisplayMode.hidden,
                    useRelationship: useRelationship,
                    vehicleType: vehicleType,
                    plateType: plateType,
                    seasonStartMonth: seasonStartMonth,
                    seasonEndMonth: seasonEndMonth,
                    showOnPublicProfile: showOnPublicProfile,
                    discoverableByPlate: discoverableByPlate,
                    selectableInStories: selectableInStories,
                    allowContactRequests: allowContactRequests,
                    plateDisplayMode: plateDisplayMode,
                    year: year,
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
                    deactivatedAt: vehicle?.deactivatedAt,
                  ),
                );
                if (sheetContext.mounted) {
                  isDirty = false;
                  Navigator.of(sheetContext).pop(true);
                }
              } catch (error) {
                if (!sheetContext.mounted) return;
                setSheetState(() => isSaving = false);
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      error is ProfileVehicleException
                          ? error.message
                          : 'Fahrzeug konnte nicht gespeichert werden. Bitte prüfe deine Angaben und versuche es erneut.',
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
                  20,
                  14,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Spacer(),
                          Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: closeEditor,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                      if (verificationLocked) ...[
                        const SizedBox(height: 12),
                        const _VehicleInfoBox(
                          icon: Icons.lock_outline_rounded,
                          text:
                              'Die verifizierungsrelevanten Stammdaten sind während der laufenden Prüfung gesperrt.',
                        ),
                      ],
                      const SizedBox(height: 18),
                      _VehicleDropdown<String>(
                        label: 'Marke',
                        value: selectedBrand,
                        values: VehicleCatalog.brands,
                        labelFor: (value) => value,
                        enabled: !verificationLocked,
                        onChanged: (value) {
                          if (value == null) return;
                          updateEditor(() {
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
                        enabled: !verificationLocked,
                        onChanged: (value) {
                          if (value == null) return;
                          updateEditor(() => selectedModel = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      _VehicleTextField(
                        controller: seriesController,
                        label: 'Baureihe (optional)',
                        maxLength: 120,
                        enabled: !verificationLocked,
                      ),
                      const SizedBox(height: 10),
                      _VehicleDropdown<String>(
                        label: 'Farbe',
                        value: selectedColor,
                        values: _vehicleColors,
                        labelFor: (value) => value,
                        enabled: !verificationLocked,
                        onChanged: (value) {
                          if (value == null) return;
                          updateEditor(() => selectedColor = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _VehicleTextField(
                              controller: yearController,
                              label: 'Baujahr (optional)',
                              maxLength: 4,
                              numbersOnly: true,
                              enabled: !verificationLocked,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _VehicleDropdown<ProfileVehicleType>(
                              label: 'Fahrzeugart',
                              value: vehicleType,
                              values: ProfileVehicleType.values,
                              labelFor: _vehicleTypeLabel,
                              enabled: !verificationLocked,
                              onChanged: (value) {
                                if (value == null) return;
                                updateEditor(() => vehicleType = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _VehicleDropdown<PlateCountryConfig>(
                        label: 'Land',
                        value: plateConfig,
                        values: plateCountryConfigs,
                        labelFor: (value) => value.countryLabel,
                        enabled: !verificationLocked,
                        onChanged: (value) {
                          if (value == null) return;
                          updateEditor(() {
                            countryCode = value.countryCode;
                            regionController.clear();
                            lettersController.clear();
                            numbersController.clear();
                            if (value.countryCode != 'DE' &&
                                (plateType == ProfilePlateType.electric ||
                                    plateType == ProfilePlateType.historic)) {
                              plateType = ProfilePlateType.standard;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _VehicleDropdown<ProfilePlateType>(
                        label: 'Kennzeichentyp',
                        value: plateType,
                        values: ProfilePlateType.values
                            .where(
                              (value) =>
                                  countryCode == 'DE' ||
                                  (value != ProfilePlateType.electric &&
                                      value != ProfilePlateType.historic),
                            )
                            .toList(growable: false),
                        labelFor: _plateTypeLabel,
                        enabled: !verificationLocked,
                        onChanged: (value) {
                          if (value == null) return;
                          updateEditor(() {
                            plateType = value;
                            if (value != ProfilePlateType.seasonal) {
                              seasonStartMonth = null;
                              seasonEndMonth = null;
                            } else {
                              seasonStartMonth ??= 3;
                              seasonEndMonth ??= 10;
                            }
                          });
                        },
                      ),
                      if (plateType == ProfilePlateType.seasonal) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _VehicleDropdown<int>(
                                label: 'Saison von',
                                value: seasonStartMonth ?? 3,
                                values: List<int>.generate(
                                  12,
                                  (index) => index + 1,
                                ),
                                labelFor: _monthLabel,
                                enabled: !verificationLocked,
                                onChanged: (value) {
                                  if (value == null) return;
                                  updateEditor(() => seasonStartMonth = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _VehicleDropdown<int>(
                                label: 'Saison bis',
                                value: seasonEndMonth ?? 10,
                                values: List<int>.generate(
                                  12,
                                  (index) => index + 1,
                                ),
                                labelFor: _monthLabel,
                                enabled: !verificationLocked,
                                onChanged: (value) {
                                  if (value == null) return;
                                  updateEditor(() => seasonEndMonth = value);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          regionController,
                          lettersController,
                          numbersController,
                        ]),
                        builder: (context, _) {
                          final region = regionController.text;
                          return CaRismaLicensePlatePreview(
                            countryCode: countryCode,
                            region: region,
                            letters: lettersController.text,
                            numbers: numbersController.text,
                            regionPresentation:
                                registrationRegionPresentationFor(
                                  countryCode: countryCode,
                                  plateCode: region,
                                ),
                          );
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
                              enabled: !verificationLocked,
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
                                enabled: !verificationLocked,
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
                              enabled: !verificationLocked,
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
                      _VehicleDropdown<ProfileVehicleUseRelationship>(
                        label: 'Fahrzeugzuordnung',
                        value: useRelationship,
                        values: ProfileVehicleUseRelationship.values,
                        labelFor: _relationshipLabel,
                        enabled: !verificationLocked,
                        onChanged: (value) {
                          if (value == null) return;
                          updateEditor(() => useRelationship = value);
                        },
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
                          updateEditor(() => status = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      _VehicleVerificationSummary(vehicle: vehicle),
                      if (onOpenVerification != null) ...[
                        const SizedBox(height: 10),
                        CaRismaPrimaryButton(
                          label:
                              vehicle?.verificationStatus ==
                                  ProfileVehicleVerificationStatus.rejected
                              ? 'Nachweis erneut einreichen'
                              : 'Dokumente hochladen',
                          icon: Icons.upload_file_rounded,
                          surfaceOutlined: true,
                          showShadow: false,
                          onPressed: () async {
                            await onOpenVerification();
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      _VehicleSwitch(
                        title: 'Im öffentlichen Profil anzeigen',
                        value: showOnPublicProfile,
                        onChanged: (value) =>
                            updateEditor(() => showOnPublicProfile = value),
                      ),
                      _VehicleSwitch(
                        title: 'Über Kennzeichen auffindbar',
                        value: discoverableByPlate,
                        onChanged: (value) =>
                            updateEditor(() => discoverableByPlate = value),
                      ),
                      _VehicleSwitch(
                        title: 'In Storys auswählbar',
                        value: selectableInStories,
                        onChanged: (value) =>
                            updateEditor(() => selectableInStories = value),
                      ),
                      _VehicleSwitch(
                        title: 'Kontaktanfragen erlauben',
                        value: allowContactRequests,
                        onChanged: (value) =>
                            updateEditor(() => allowContactRequests = value),
                      ),
                      const SizedBox(height: 8),
                      _VehicleDropdown<ProfilePlateDisplayMode>(
                        label: 'Kennzeichen öffentlich anzeigen',
                        value: plateDisplayMode,
                        values: ProfilePlateDisplayMode.values,
                        labelFor: _plateDisplayModeLabel,
                        onChanged: (value) {
                          if (value == null) return;
                          updateEditor(() => plateDisplayMode = value);
                        },
                      ),
                      _VehicleSwitch(
                        title: 'Als Hauptfahrzeug verwenden',
                        value: isPrimary,
                        onChanged: vehicle?.isPrimary == true
                            ? null
                            : (value) => updateEditor(() => isPrimary = value),
                      ),
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          seriesController,
                          regionController,
                          lettersController,
                          numbersController,
                        ]),
                        builder: (context, _) => _VehiclePublicPreview(
                          brand: selectedBrand,
                          model: selectedModel,
                          series: seriesController.text,
                          color: selectedColor,
                          countryCode: countryCode,
                          region: regionController.text,
                          letters: lettersController.text,
                          numbers: numbersController.text,
                          plateDisplayMode: plateDisplayMode,
                          showVehicle: showOnPublicProfile,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CaRismaPrimaryButton(
                        label: 'Fahrzeug speichern',
                        loadingLabel: 'Wird gespeichert...',
                        icon: Icons.check_rounded,
                        isLoading: isSaving,
                        surfaceOutlined: true,
                        showShadow: false,
                        onPressed: submit,
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
    seriesController.dispose();
    regionController.dispose();
    lettersController.dispose();
    numbersController.dispose();
    mileageController.dispose();
    yearController.dispose();
  }
}

class _VehicleDropdown<T> extends StatelessWidget {
  const _VehicleDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

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
      onChanged: enabled ? onChanged : null,
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
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final int maxLength;
  final bool upperCase;
  final bool numbersOnly;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
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

class _VehicleInfoBox extends StatelessWidget {
  const _VehicleInfoBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: CaRismaDesignTokens.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleVerificationSummary extends StatelessWidget {
  const _VehicleVerificationSummary({required this.vehicle});

  final ProfileVehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    final status =
        vehicle?.verificationStatus ??
        ProfileVehicleVerificationStatus.evidenceMissing;
    final (label, icon, color) = switch (status) {
      ProfileVehicleVerificationStatus.unverified => (
        'Nicht verifiziert',
        Icons.shield_outlined,
        CaRismaDesignTokens.textMuted,
      ),
      ProfileVehicleVerificationStatus.evidenceMissing => (
        'Nachweis fehlt',
        Icons.upload_file_outlined,
        CaRismaDesignTokens.textMuted,
      ),
      ProfileVehicleVerificationStatus.inReview => (
        'In Prüfung',
        Icons.manage_search_rounded,
        CaRismaDesignTokens.bluePrimary,
      ),
      ProfileVehicleVerificationStatus.verified => (
        'Verifiziert',
        Icons.verified_outlined,
        CaRismaDesignTokens.success,
      ),
      ProfileVehicleVerificationStatus.rejected => (
        'Abgelehnt',
        Icons.cancel_outlined,
        CaRismaDesignTokens.danger,
      ),
    };
    final reason = vehicle?.verificationRejectionReason?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Verifizierungsstatus',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reason,
              style: const TextStyle(
                color: CaRismaDesignTokens.danger,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VehiclePublicPreview extends StatelessWidget {
  const _VehiclePublicPreview({
    required this.brand,
    required this.model,
    required this.series,
    required this.color,
    required this.countryCode,
    required this.region,
    required this.letters,
    required this.numbers,
    required this.plateDisplayMode,
    required this.showVehicle,
  });

  final String brand;
  final String model;
  final String series;
  final String color;
  final String countryCode;
  final String region;
  final String letters;
  final String numbers;
  final ProfilePlateDisplayMode plateDisplayMode;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    final vehicleName = [
      brand.trim(),
      model.trim(),
      series.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    final fullPlate = formatDisplayPlate(
      countryCode: countryCode,
      region: region,
      letters: letters,
      numbers: numbers,
    );
    final plateLabel = switch (plateDisplayMode) {
      ProfilePlateDisplayMode.full => fullPlate,
      ProfilePlateDisplayMode.shortened =>
        '${region.trim().toUpperCase()}'
            '${letters.trim().isEmpty ? '' : ' ${letters.trim().substring(0, 1).toUpperCase()}'} •••',
      ProfilePlateDisplayMode.hidden => 'Kennzeichen verborgen',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.visibility_outlined, color: Colors.white, size: 21),
              SizedBox(width: 9),
              Text(
                'So sehen andere dein Fahrzeug',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!showVehicle)
            const Text(
              'Dieses Fahrzeug wird nicht im öffentlichen Profil angezeigt.',
              style: TextStyle(
                color: CaRismaDesignTokens.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            )
          else ...[
            Text(
              vehicleName.isEmpty ? 'Fahrzeugdaten fehlen' : vehicleName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              color,
              style: const TextStyle(
                color: CaRismaDesignTokens.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              plateLabel.isEmpty ? 'Kennzeichen unvollständig' : plateLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Diese Darstellung wird in Profil, Trefferkarte und Kontaktanfrage verwendet.',
              style: TextStyle(
                color: CaRismaDesignTokens.textMuted,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ],
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

String _relationshipLabel(ProfileVehicleUseRelationship relationship) {
  return switch (relationship) {
    ProfileVehicleUseRelationship.owner => 'Ich bin Halter',
    ProfileVehicleUseRelationship.leasingCompany =>
      'Leasing- oder Firmenfahrzeug',
    ProfileVehicleUseRelationship.authorizedUser =>
      'Ich nutze das Fahrzeug mit Erlaubnis',
  };
}

String _vehicleTypeLabel(ProfileVehicleType type) {
  return switch (type) {
    ProfileVehicleType.passengerCar => 'Pkw',
    ProfileVehicleType.motorcycle => 'Motorrad',
    ProfileVehicleType.transporter => 'Transporter',
  };
}

String _plateTypeLabel(ProfilePlateType type) {
  return switch (type) {
    ProfilePlateType.standard => 'Standard',
    ProfilePlateType.electric => 'Elektro',
    ProfilePlateType.historic => 'Historisch',
    ProfilePlateType.seasonal => 'Saisonkennzeichen',
  };
}

String _plateDisplayModeLabel(ProfilePlateDisplayMode mode) {
  return switch (mode) {
    ProfilePlateDisplayMode.full => 'Vollständig',
    ProfilePlateDisplayMode.shortened => 'Verkürzt',
    ProfilePlateDisplayMode.hidden => 'Verborgen',
  };
}

String _monthLabel(int month) => month.toString().padLeft(2, '0');
