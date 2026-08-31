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

const _otherVehicleBrand = 'Sonstige Marke';
const _otherVehicleModel = 'Sonstiges Modell';

const _vehicleKinds = <_VehicleKind>[
  _VehicleKind(label: 'Pkw', vehicleType: ProfileVehicleType.passengerCar),
  _VehicleKind(label: 'Motorrad', vehicleType: ProfileVehicleType.motorcycle),
  _VehicleKind(
    label: 'Transporter',
    vehicleType: ProfileVehicleType.transporter,
  ),
  _VehicleKind(
    label: 'Cabrio/Roadster',
    vehicleType: ProfileVehicleType.passengerCar,
    bodyStyle: 'Cabrio/Roadster',
  ),
  _VehicleKind(
    label: 'SUV',
    vehicleType: ProfileVehicleType.passengerCar,
    bodyStyle: 'SUV',
  ),
  _VehicleKind(
    label: 'Van',
    vehicleType: ProfileVehicleType.passengerCar,
    bodyStyle: 'Van',
  ),
];

Future<bool> showProfileVehicleEditorSheet(
  BuildContext context, {
  required String userId,
  required String vehicleId,
  required Future<void> Function(ProfileVehicle vehicle) onSave,
  ProfileVehicle? vehicle,
}) async {
  var vehicleKind = _vehicleKindFor(vehicle);
  var availableBrands = _brandsForVehicleKind(vehicleKind, vehicle?.brand);
  var selectedBrand = vehicle?.brand.trim() ?? availableBrands.first;
  var availableModels = _modelsForBrand(
    vehicleKind,
    selectedBrand,
    vehicle?.model,
  );
  var selectedModel = vehicle?.model.trim() ?? availableModels.first;
  var selectedColor = vehicle?.color.trim() ?? _vehicleColors.first;
  var countryCode = vehicle?.countryCode.trim().toUpperCase() ?? 'DE';
  var status = vehicle?.status ?? ProfileVehicleStatus.active;
  var useRelationship =
      vehicle?.useRelationship ?? ProfileVehicleUseRelationship.owner;
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
  final horsepowerController = TextEditingController(
    text: vehicle?.horsepower?.toString() ?? '',
  );
  final firstRegistrationController = TextEditingController(
    text: _formatVehicleDate(vehicle?.firstRegistration),
  );
  final ownedSinceController = TextEditingController(
    text: _formatVehicleDate(vehicle?.ownedSince),
  );
  final yearController = TextEditingController(
    text: vehicle?.year?.toString() ?? '',
  );
  final customBrandController = TextEditingController();
  final customModelController = TextEditingController();
  final lettersFocusNode = FocusNode();
  final numbersFocusNode = FocusNode();
  final verificationLocked = vehicle?.verificationLocked == true;
  void markDirty() => isDirty = true;
  for (final controller in [
    seriesController,
    regionController,
    lettersController,
    numbersController,
    mileageController,
    horsepowerController,
    firstRegistrationController,
    ownedSinceController,
    yearController,
    customBrandController,
    customModelController,
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
      backgroundColor: CaRismaDesignTokens.background,
      barrierColor: Colors.black.withValues(alpha: 0.72),
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
              final brand = selectedBrand == _otherVehicleBrand
                  ? customBrandController.text.trim()
                  : selectedBrand.trim();
              final model = selectedModel == _otherVehicleModel
                  ? customModelController.text.trim()
                  : selectedModel.trim();
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
              final horsepowerText = horsepowerController.text.trim();
              final horsepower = int.tryParse(horsepowerText);
              final firstRegistration = _parseVehicleDate(
                firstRegistrationController.text,
              );
              final ownedSince = _parseVehicleDate(ownedSinceController.text);
              if (brand.isEmpty || model.isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Bitte gib die Fahrzeugmarke und das Modell vollständig ein.',
                    ),
                  ),
                );
                return;
              }
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
              if (horsepowerText.isNotEmpty &&
                  (horsepower == null || horsepower < 1 || horsepower > 5000)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Bitte gib eine gültige Leistung in PS ein.'),
                  ),
                );
                return;
              }
              if (firstRegistrationController.text.trim().isNotEmpty &&
                  firstRegistration == null) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Bitte gib eine gültige Erstzulassung ein.'),
                  ),
                );
                return;
              }
              if (ownedSinceController.text.trim().isNotEmpty &&
                  ownedSince == null) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Bitte gib für „Besitzer seit“ ein gültiges Datum ein.',
                    ),
                  ),
                );
                return;
              }
              if (firstRegistration != null &&
                  ownedSince != null &&
                  ownedSince.isBefore(firstRegistration)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '„Besitzer seit“ darf nicht vor der Erstzulassung liegen.',
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
                    brand: brand,
                    model: model,
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
                    vehicleType: vehicleKind.vehicleType,
                    plateType: plateType,
                    seasonStartMonth: seasonStartMonth,
                    seasonEndMonth: seasonEndMonth,
                    showOnPublicProfile: showOnPublicProfile,
                    discoverableByPlate: discoverableByPlate,
                    selectableInStories: selectableInStories,
                    allowContactRequests: allowContactRequests,
                    plateDisplayMode: plateDisplayMode,
                    year: year,
                    firstRegistration: firstRegistration,
                    bodyStyle: vehicleKind.bodyStyle,
                    engineDescription: vehicle?.engineDescription,
                    displacementCcm: vehicle?.displacementCcm,
                    horsepower: horsepower,
                    kilowatts: vehicle?.kilowatts,
                    fuelType: vehicle?.fuelType,
                    transmission: vehicle?.transmission,
                    drivetrain: vehicle?.drivetrain,
                    equipment: vehicle?.equipment ?? const [],
                    hsn: vehicle?.hsn,
                    tsn: vehicle?.tsn,
                    vin: vehicle?.vin,
                    ownedSince: ownedSince,
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
                      _VehicleDropdown<_VehicleKind>(
                        label: 'Fahrzeugart',
                        value: vehicleKind,
                        values: _vehicleKinds,
                        labelFor: (value) => value.label,
                        enabled: !verificationLocked,
                        onChanged: (value) {
                          if (value == null) return;
                          updateEditor(() {
                            final switchesCatalog =
                                _usesMotorcycleCatalog(vehicleKind) !=
                                _usesMotorcycleCatalog(value);
                            vehicleKind = value;
                            availableBrands = _brandsForVehicleKind(
                              value,
                              switchesCatalog ? null : selectedBrand,
                            );
                            if (!availableBrands.contains(selectedBrand)) {
                              selectedBrand = availableBrands.first;
                            }
                            availableModels = _modelsForBrand(
                              value,
                              selectedBrand,
                              switchesCatalog ? null : selectedModel,
                            );
                            if (!availableModels.contains(selectedModel)) {
                              selectedModel = availableModels.first;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _VehicleDropdown<String>(
                        label: 'Marke',
                        value: selectedBrand,
                        values: availableBrands,
                        labelFor: (value) => value,
                        enabled: !verificationLocked,
                        onChanged: (value) {
                          if (value == null) return;
                          updateEditor(() {
                            selectedBrand = value;
                            availableModels = _modelsForBrand(
                              vehicleKind,
                              value,
                              null,
                            );
                            selectedModel = availableModels.first;
                          });
                        },
                      ),
                      if (selectedBrand == _otherVehicleBrand) ...[
                        const SizedBox(height: 10),
                        _VehicleTextField(
                          controller: customBrandController,
                          label: 'Eigene Marke',
                          maxLength: 120,
                          enabled: !verificationLocked,
                        ),
                      ],
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
                      if (selectedModel == _otherVehicleModel) ...[
                        const SizedBox(height: 10),
                        _VehicleTextField(
                          controller: customModelController,
                          label: 'Eigenes Modell',
                          maxLength: 120,
                          enabled: !verificationLocked,
                        ),
                      ],
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
                      _VehicleTextField(
                        controller: yearController,
                        label: 'Baujahr',
                        maxLength: 4,
                        numbersOnly: true,
                        enabled: !verificationLocked,
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
                            numbersController.text =
                                _numbersForSelectedPlateType(
                                  numbersController.text,
                                  countryCode: countryCode,
                                  plateType: value,
                                );
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
                              lettersOnly: true,
                              textAlign: TextAlign.center,
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
                                lettersOnly: true,
                                textAlign: TextAlign.center,
                                focusNode: lettersFocusNode,
                                labelFontSize: 10.5,
                                onChanged: (value) {
                                  if (value.trim().length >= 2) {
                                    numbersFocusNode.requestFocus();
                                  }
                                },
                                enabled: !verificationLocked,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Expanded(
                            child: _VehicleTextField(
                              controller: numbersController,
                              label: 'Zahlen',
                              maxLength: _plateNumberMaxLength(
                                countryCode,
                                plateType,
                                plateConfig,
                              ),
                              plateNumberCountryCode: countryCode,
                              plateType: plateType,
                              textAlign: TextAlign.center,
                              focusNode: numbersFocusNode,
                              enabled: !verificationLocked,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _VehicleTextField(
                              controller: horsepowerController,
                              label: 'Leistung (PS)',
                              maxLength: 4,
                              numbersOnly: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _VehicleDateTextField(
                              controller: firstRegistrationController,
                              label: 'Erstzulassung',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _VehicleTextField(
                              controller: mileageController,
                              label: 'Kilometerstand',
                              maxLength: 8,
                              numbersOnly: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _VehicleDateTextField(
                              controller: ownedSinceController,
                              label: 'Besitzer seit',
                            ),
                          ),
                        ],
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
                        surfaceTextColor: CaRismaDesignTokens.textPrimary,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      seriesController.dispose();
      regionController.dispose();
      lettersController.dispose();
      numbersController.dispose();
      mileageController.dispose();
      horsepowerController.dispose();
      firstRegistrationController.dispose();
      ownedSinceController.dispose();
      yearController.dispose();
      customBrandController.dispose();
      customModelController.dispose();
      lettersFocusNode.dispose();
      numbersFocusNode.dispose();
    });
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
    this.lettersOnly = false,
    this.numbersOnly = false,
    this.plateNumberCountryCode,
    this.plateType,
    this.textAlign = TextAlign.start,
    this.focusNode,
    this.onChanged,
    this.labelFontSize,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final int maxLength;
  final bool lettersOnly;
  final bool numbersOnly;
  final String? plateNumberCountryCode;
  final ProfilePlateType? plateType;
  final TextAlign textAlign;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final double? labelFontSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      textAlign: textAlign,
      onChanged: onChanged,
      textCapitalization: lettersOnly
          ? TextCapitalization.characters
          : TextCapitalization.sentences,
      keyboardType:
          numbersOnly ||
              (plateNumberCountryCode != null &&
                  plateType != ProfilePlateType.electric &&
                  plateType != ProfilePlateType.historic)
          ? TextInputType.number
          : TextInputType.text,
      inputFormatters: [
        if (numbersOnly) FilteringTextInputFormatter.digitsOnly,
        if (lettersOnly) const _UpperCaseVehicleFormatter(allowDigits: false),
        if (plateNumberCountryCode != null && plateType != null)
          _VehiclePlateNumberFormatter(
            countryCode: plateNumberCountryCode!,
            plateType: plateType!,
          ),
        LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: _inputDecoration(label).copyWith(
        floatingLabelAlignment: textAlign == TextAlign.center
            ? FloatingLabelAlignment.center
            : FloatingLabelAlignment.start,
        labelStyle: labelFontSize == null
            ? null
            : TextStyle(fontSize: labelFontSize),
      ),
    );
  }
}

class _VehicleDateTextField extends StatelessWidget {
  const _VehicleDateTextField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return TextField(
          controller: controller,
          keyboardType: TextInputType.datetime,
          inputFormatters: const [_VehicleDateInputFormatter()],
          decoration: _inputDecoration(label).copyWith(
            hintText: 'TT.MM.JJJJ',
            errorText: _vehicleDateInputError(value.text),
            errorMaxLines: 2,
          ),
        );
      },
    );
  }
}

class _VehicleDateInputFormatter extends TextInputFormatter {
  const _VehicleDateInputFormatter();

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

String _formatVehicleDate(DateTime? value) {
  if (value == null) return '';
  return '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';
}

DateTime? _parseVehicleDate(String source) {
  final parts = source.trim().split('.');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null || year < 1886) {
    return null;
  }
  final value = DateTime(year, month, day);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (value.year != year ||
      value.month != month ||
      value.day != day ||
      value.isAfter(today)) {
    return null;
  }
  return value;
}

String? _vehicleDateInputError(String source) {
  final text = source.trim();
  if (text.isEmpty) return null;

  final parts = text.split('.');
  final day = int.tryParse(parts.first);
  if (parts.first.length == 2 && (day == null || day < 1 || day > 31)) {
    return 'Tag: 01 bis 31';
  }
  if (parts.length > 1 && parts[1].length == 2) {
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) {
      return 'Monat: 01 bis 12';
    }
  }
  if (parts.length < 3 || parts[2].length < 4) return null;
  return _parseVehicleDate(text) == null ? 'Ungültiges Datum' : null;
}

bool _usesMotorcycleCatalog(_VehicleKind kind) =>
    kind.vehicleType == ProfileVehicleType.motorcycle;

List<String> _brandsForVehicleKind(_VehicleKind kind, String? currentBrand) {
  final brands = _usesMotorcycleCatalog(kind)
      ? [...VehicleCatalog.motorcycleBrands]
      : [...VehicleCatalog.brands];
  final normalizedCurrent = currentBrand?.trim() ?? '';
  if (normalizedCurrent.isNotEmpty && !brands.contains(normalizedCurrent)) {
    brands.insert(0, normalizedCurrent);
  }
  return brands;
}

List<String> _modelsForBrand(
  _VehicleKind kind,
  String brand,
  String? currentModel,
) {
  final catalog = _usesMotorcycleCatalog(kind)
      ? VehicleCatalog.motorcycleModelsByBrand
      : VehicleCatalog.modelsByBrand;
  final models = [...?catalog[brand]];
  if (!models.contains(_otherVehicleModel)) {
    models.add(_otherVehicleModel);
  }
  final normalizedCurrent = currentModel?.trim() ?? '';
  if (normalizedCurrent.isNotEmpty && !models.contains(normalizedCurrent)) {
    models.insert(0, normalizedCurrent);
  }
  return models.isEmpty ? const [_otherVehicleModel] : models;
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

class _VehicleKind {
  const _VehicleKind({
    required this.label,
    required this.vehicleType,
    this.bodyStyle,
  });

  final String label;
  final ProfileVehicleType vehicleType;
  final String? bodyStyle;
}

_VehicleKind _vehicleKindFor(ProfileVehicle? vehicle) {
  if (vehicle == null) return _vehicleKinds.first;
  final bodyStyle = vehicle.bodyStyle?.trim().toLowerCase();
  for (final kind in _vehicleKinds) {
    if (kind.bodyStyle?.toLowerCase() == bodyStyle && bodyStyle != null) {
      return kind;
    }
  }
  return _vehicleKinds.firstWhere(
    (kind) => kind.bodyStyle == null && kind.vehicleType == vehicle.vehicleType,
    orElse: () => _vehicleKinds.first,
  );
}

int _plateNumberMaxLength(
  String countryCode,
  ProfilePlateType plateType,
  PlateCountryConfig config,
) {
  if (countryCode != 'DE') return config.numbersMaxLength;
  return plateType == ProfilePlateType.electric ||
          plateType == ProfilePlateType.historic
      ? 5
      : 4;
}

String _numbersForSelectedPlateType(
  String value, {
  required String countryCode,
  required ProfilePlateType plateType,
}) {
  if (countryCode != 'DE') {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
  var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length > 4) digits = digits.substring(0, 4);
  if (digits.isEmpty) return '';
  return switch (plateType) {
    ProfilePlateType.electric => '${digits}E',
    ProfilePlateType.historic => '${digits}H',
    _ => digits,
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

class _UpperCaseVehicleFormatter extends TextInputFormatter {
  const _UpperCaseVehicleFormatter({this.allowDigits = true});

  final bool allowDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final disallowed = allowDigits ? r'[^A-ZÄÖÜ0-9]' : r'[^A-ZÄÖÜ]';
    final normalized = newValue.text.toUpperCase().replaceAll(
      RegExp(disallowed),
      '',
    );
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}

class _VehiclePlateNumberFormatter extends TextInputFormatter {
  const _VehiclePlateNumberFormatter({
    required this.countryCode,
    required this.plateType,
  });

  final String countryCode;
  final ProfilePlateType plateType;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final input = newValue.text.toUpperCase().replaceAll(' ', '');
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (countryCode == 'DE' && digits.length > 4) {
      digits = digits.substring(0, 4);
    }
    final suffix = switch ((countryCode, plateType)) {
      ('DE', ProfilePlateType.electric) when input.contains('E') => 'E',
      ('DE', ProfilePlateType.historic) when input.contains('H') => 'H',
      _ => '',
    };
    final normalized = '$digits$suffix';
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}
