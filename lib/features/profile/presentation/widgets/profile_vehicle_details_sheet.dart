import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../data/profile_vehicle.dart';

const _equipmentOptions = <String>[
  'M-Paket',
  'Sportpaket',
  'Panorama',
  'Head-up-Display',
  'Harman Kardon',
  'Sitzheizung',
  'Sitzbelüftung',
  'Standheizung',
  '360°-Kamera',
  'Anhängerkupplung',
  'Assistenzpaket',
  'Soft-Close',
  'Abstandsregeltempomat',
  'Spurhalteassistent',
  'Totwinkelassistent',
  'Notbremsassistent',
  'Matrix-LED',
  'Adaptives Kurvenlicht',
  'Keyless Entry',
  'Elektrische Heckklappe',
  'Memory-Sitze',
  'Massagefunktion',
  'Lenkradheizung',
  'Klimaautomatik',
  'Apple CarPlay',
  'Android Auto',
  'DAB-Radio',
  'Induktives Laden',
  'Parkassistent',
  'Nachtsichtassistent',
  'Luftfederung',
  'Sportabgasanlage',
];

const _unsetVehicleDetail = 'Auswählen';

String _equipmentKey(String value) => value.trim().toLowerCase();

Set<String> _deduplicatedEquipment(Iterable<String> values) {
  final result = <String>{};
  final keys = <String>{};
  for (final rawValue in values) {
    final value = rawValue.trim();
    if (value.isEmpty || !keys.add(_equipmentKey(value))) continue;
    result.add(value);
  }
  return result;
}

bool _containsEquipment(Iterable<String> values, String candidate) {
  final key = _equipmentKey(candidate);
  return values.any((value) => _equipmentKey(value) == key);
}

void _removeEquipment(Set<String> values, String candidate) {
  final key = _equipmentKey(candidate);
  values.removeWhere((value) => _equipmentKey(value) == key);
}

enum ProfileVehicleDetailsSection { vehicleData, equipment }

Future<bool> showProfileVehicleDetailsSheet(
  BuildContext context, {
  required ProfileVehicle vehicle,
  required Future<void> Function(ProfileVehicle vehicle) onSave,
  ProfileVehicleDetailsSection section =
      ProfileVehicleDetailsSection.vehicleData,
}) async {
  final yearController = TextEditingController(text: vehicle.year?.toString());
  final engineController = TextEditingController(
    text: vehicle.engineDescription,
  );
  final displacementController = TextEditingController(
    text: vehicle.displacementCcm?.toString(),
  );
  final horsepowerController = TextEditingController(
    text: vehicle.horsepower?.toString(),
  );
  final kilowattsController = TextEditingController(
    text: vehicle.kilowatts?.toString(),
  );
  final mileageController = TextEditingController(
    text: vehicle.mileage?.toString(),
  );
  final firstRegistrationController = TextEditingController(
    text: _formatDate(vehicle.firstRegistration),
  );
  final ownedSinceController = TextEditingController(
    text: _formatDate(vehicle.ownedSince),
  );
  final hsnController = TextEditingController(text: vehicle.hsn);
  final tsnController = TextEditingController(text: vehicle.tsn);
  final vinController = TextEditingController(text: vehicle.vin);
  final customEquipmentController = TextEditingController();

  var bodyStyle = vehicle.bodyStyle ?? _unsetVehicleDetail;
  var fuelType = vehicle.fuelType ?? _unsetVehicleDetail;
  var transmission = vehicle.transmission ?? _unsetVehicleDetail;
  var drivetrain = vehicle.drivetrain ?? _unsetVehicleDetail;
  var equipment = _deduplicatedEquipment(vehicle.equipment);
  var isSaving = false;
  var isDirty = false;

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
                  title: const Text(
                    'Änderungen verwerfen?',
                    style: TextStyle(color: CaRismaDesignTokens.textPrimary),
                  ),
                  content: const Text(
                    'Die Ausstattung wurde noch nicht gespeichert.',
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
              FocusManager.instance.primaryFocus?.unfocus();
              final currentYear = DateTime.now().year;
              final year = int.tryParse(yearController.text.trim());
              final displacement = int.tryParse(
                displacementController.text.trim(),
              );
              final horsepower = int.tryParse(horsepowerController.text.trim());
              final kilowatts = int.tryParse(kilowattsController.text.trim());
              final mileage = int.tryParse(mileageController.text.trim());
              if (year != null && (year < 1886 || year > currentYear + 1)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(content: Text('Bitte prüfe das Baujahr.')),
                );
                return;
              }
              if (!_validOptionalNumber(
                    displacementController.text,
                    displacement,
                    maximum: 20000,
                  ) ||
                  !_validOptionalNumber(
                    horsepowerController.text,
                    horsepower,
                    maximum: 5000,
                  ) ||
                  !_validOptionalNumber(
                    kilowattsController.text,
                    kilowatts,
                    maximum: 4000,
                  ) ||
                  !_validOptionalNumber(
                    mileageController.text,
                    mileage,
                    maximum: 99999999,
                  )) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Bitte prüfe die numerischen Angaben.'),
                  ),
                );
                return;
              }
              final firstRegistration = _parseDate(
                firstRegistrationController.text,
              );
              final ownedSince = _parseDate(ownedSinceController.text);
              if (section == ProfileVehicleDetailsSection.vehicleData &&
                  firstRegistrationController.text.trim().isNotEmpty &&
                  firstRegistration == null) {
                _showInvalidDateMessage(sheetContext, 'Erstzulassung');
                return;
              }
              if (section == ProfileVehicleDetailsSection.vehicleData &&
                  ownedSinceController.text.trim().isNotEmpty &&
                  ownedSince == null) {
                _showInvalidDateMessage(sheetContext, 'Besitzer seit');
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
                final updatedVehicle =
                    section == ProfileVehicleDetailsSection.vehicleData
                    ? vehicle.copyWith(
                        year: year,
                        clearYear: yearController.text.trim().isEmpty,
                        firstRegistration: firstRegistration,
                        clearFirstRegistration: firstRegistrationController.text
                            .trim()
                            .isEmpty,
                        bodyStyle: bodyStyle == _unsetVehicleDetail
                            ? null
                            : bodyStyle,
                        clearBodyStyle: bodyStyle == _unsetVehicleDetail,
                        engineDescription: engineController.text,
                        clearEngineDescription: engineController.text
                            .trim()
                            .isEmpty,
                        displacementCcm: displacement,
                        clearDisplacementCcm: displacementController.text
                            .trim()
                            .isEmpty,
                        horsepower: horsepower,
                        clearHorsepower: horsepowerController.text
                            .trim()
                            .isEmpty,
                        kilowatts: kilowatts,
                        clearKilowatts: kilowattsController.text.trim().isEmpty,
                        fuelType: fuelType == _unsetVehicleDetail
                            ? null
                            : fuelType,
                        clearFuelType: fuelType == _unsetVehicleDetail,
                        transmission: transmission == _unsetVehicleDetail
                            ? null
                            : transmission,
                        clearTransmission: transmission == _unsetVehicleDetail,
                        drivetrain: drivetrain == _unsetVehicleDetail
                            ? null
                            : drivetrain,
                        clearDrivetrain: drivetrain == _unsetVehicleDetail,
                        hsn: hsnController.text,
                        clearHsn: hsnController.text.trim().isEmpty,
                        tsn: tsnController.text,
                        clearTsn: tsnController.text.trim().isEmpty,
                        vin: vinController.text,
                        clearVin: vinController.text.trim().isEmpty,
                        ownedSince: ownedSince,
                        clearOwnedSince: ownedSinceController.text
                            .trim()
                            .isEmpty,
                        mileage: mileage,
                        clearMileage: mileageController.text.trim().isEmpty,
                      )
                    : vehicle.copyWith(equipment: equipment.toList()..sort());
                await onSave(updatedVehicle);
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(true);
                }
              } catch (error) {
                if (!sheetContext.mounted) return;
                setSheetState(() => isSaving = false);
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Fahrzeugdaten konnten nicht gespeichert werden: $error',
                    ),
                  ),
                );
              }
            }

            void addCustomEquipment() {
              final value = customEquipmentController.text.trim();
              if (value.isEmpty) return;
              if (_containsEquipment(equipment, value)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Diese Ausstattung ist bereits ausgewählt.'),
                  ),
                );
                return;
              }
              if (equipment.length >= 40) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Maximal 40 Ausstattungen sind möglich. Entferne zuerst einen Eintrag.',
                    ),
                  ),
                );
                return;
              }
              setSheetState(() {
                equipment.add(value);
                customEquipmentController.clear();
                isDirty = true;
              });
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
                                      section ==
                                              ProfileVehicleDetailsSection
                                                  .vehicleData
                                          ? 'Fahrzeugdaten'
                                          : 'Ausstattung',
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
                              if (section ==
                                  ProfileVehicleDetailsSection.vehicleData) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DetailTextField(
                                        controller: yearController,
                                        label: 'Baujahr',
                                        maxLength: 4,
                                        numbersOnly: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _DateTextField(
                                        label: 'Erstzulassung',
                                        controller: firstRegistrationController,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _DetailDropdown(
                                  label: 'Karosserieform',
                                  value: bodyStyle,
                                  values: const [
                                    _unsetVehicleDetail,
                                    'SUV',
                                    'Limousine',
                                    'Kombi',
                                    'Coupé',
                                    'Cabrio',
                                    'Van',
                                    'Transporter',
                                    'Pickup',
                                    'Motorrad',
                                    'Sonstiges',
                                  ],
                                  onChanged: (value) =>
                                      setSheetState(() => bodyStyle = value),
                                ),
                                const SizedBox(height: 10),
                                _DetailTextField(
                                  controller: engineController,
                                  label: 'Motorisierung',
                                  maxLength: 40,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DetailTextField(
                                        controller: displacementController,
                                        label: 'Hubraum',
                                        maxLength: 5,
                                        numbersOnly: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _DetailTextField(
                                        controller: horsepowerController,
                                        label: 'PS',
                                        maxLength: 4,
                                        numbersOnly: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _DetailTextField(
                                        controller: kilowattsController,
                                        label: 'kW',
                                        maxLength: 4,
                                        numbersOnly: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _DetailDropdown(
                                  label: 'Kraftstoff',
                                  value: fuelType,
                                  values: const [
                                    _unsetVehicleDetail,
                                    'Benzin',
                                    'Diesel',
                                    'Elektro',
                                    'Hybrid',
                                    'Plug-in-Hybrid',
                                    'LPG',
                                    'CNG',
                                    'Sonstiges',
                                  ],
                                  onChanged: (value) =>
                                      setSheetState(() => fuelType = value),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DetailDropdown(
                                        label: 'Getriebe',
                                        value: transmission,
                                        values: const [
                                          _unsetVehicleDetail,
                                          'Automatik',
                                          'Schaltgetriebe',
                                          'Doppelkupplung',
                                          'Stufenlos',
                                          'Sonstiges',
                                        ],
                                        onChanged: (value) => setSheetState(
                                          () => transmission = value,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _DetailDropdown(
                                        label: 'Antrieb',
                                        value: drivetrain,
                                        values: const [
                                          _unsetVehicleDetail,
                                          'Frontantrieb',
                                          'Heckantrieb',
                                          'Allrad',
                                          'Kette',
                                          'Riemen',
                                          'Sonstiges',
                                        ],
                                        onChanged: (value) => setSheetState(
                                          () => drivetrain = value,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DetailTextField(
                                        controller: mileageController,
                                        label: 'Kilometerstand',
                                        maxLength: 8,
                                        numbersOnly: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _DateTextField(
                                        label: 'Besitzer seit',
                                        controller: ownedSinceController,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                              if (section ==
                                  ProfileVehicleDetailsSection.equipment) ...[
                                Text(
                                  'Ausstattung',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _equipmentOptions.map((option) {
                                    return FilterChip(
                                      key: ValueKey('equipment-option-$option'),
                                      label: Text(option),
                                      selected: _containsEquipment(
                                        equipment,
                                        option,
                                      ),
                                      onSelected: (selected) => setSheetState(() {
                                        if (selected) {
                                          if (equipment.length >= 40) {
                                            ScaffoldMessenger.of(
                                              sheetContext,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Maximal 40 Ausstattungen sind möglich. Entferne zuerst einen Eintrag.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          equipment.add(option);
                                        } else {
                                          _removeEquipment(equipment, option);
                                        }
                                        isDirty = true;
                                      }),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DetailTextField(
                                        key: const ValueKey(
                                          'custom-equipment-input',
                                        ),
                                        controller: customEquipmentController,
                                        label: 'Eigene Ausstattung',
                                        maxLength: 60,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      key: const ValueKey(
                                        'add-custom-equipment',
                                      ),
                                      tooltip: 'Ausstattung hinzufügen',
                                      onPressed: addCustomEquipment,
                                      icon: const Icon(Icons.add_rounded),
                                    ),
                                  ],
                                ),
                                if (equipment
                                    .where(
                                      (item) =>
                                          !_equipmentOptions.contains(item),
                                    )
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: equipment
                                        .where(
                                          (item) =>
                                              !_equipmentOptions.contains(item),
                                        )
                                        .map(
                                          (item) => InputChip(
                                            label: Text(item),
                                            onDeleted: () => setSheetState(() {
                                              equipment.remove(item);
                                              isDirty = true;
                                            }),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 20),
                              ],
                              if (section ==
                                  ProfileVehicleDetailsSection.vehicleData) ...[
                                Text(
                                  'Private Fahrzeugdaten',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Diese Angaben werden niemals im öffentlichen Profil angezeigt.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color:
                                            CaRismaDesignTokens.textSecondary,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DetailTextField(
                                        controller: hsnController,
                                        label: 'HSN',
                                        maxLength: 8,
                                        upperCase: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _DetailTextField(
                                        controller: tsnController,
                                        label: 'TSN',
                                        maxLength: 8,
                                        upperCase: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _DetailTextField(
                                  controller: vinController,
                                  label: 'Fahrzeugidentifikationsnummer',
                                  maxLength: 40,
                                  upperCase: true,
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('save-vehicle-details'),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      yearController.dispose();
      engineController.dispose();
      displacementController.dispose();
      horsepowerController.dispose();
      kilowattsController.dispose();
      mileageController.dispose();
      firstRegistrationController.dispose();
      ownedSinceController.dispose();
      hsnController.dispose();
      tsnController.dispose();
      vinController.dispose();
      customEquipmentController.dispose();
    });
  }
}

class _DetailTextField extends StatelessWidget {
  const _DetailTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.maxLength,
    this.numbersOnly = false,
    this.upperCase = false,
  });

  final TextEditingController controller;
  final String label;
  final int maxLength;
  final bool numbersOnly;
  final bool upperCase;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onTapOutside: (_) {},
      keyboardType: numbersOnly ? TextInputType.number : TextInputType.text,
      textCapitalization: upperCase
          ? TextCapitalization.characters
          : TextCapitalization.sentences,
      inputFormatters: [
        LengthLimitingTextInputFormatter(maxLength),
        if (numbersOnly) FilteringTextInputFormatter.digitsOnly,
        if (upperCase)
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
      ],
      decoration: _inputDecoration(label),
    );
  }
}

class _DetailDropdown extends StatelessWidget {
  const _DetailDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final availableValues = values.contains(value)
        ? values
        : [value, ...values];
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      dropdownColor: CaRismaDesignTokens.controlSurface,
      decoration: _inputDecoration(label),
      items: availableValues
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _DateTextField extends StatelessWidget {
  const _DateTextField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final errorText = _dateInputError(value.text, minimumYear: 1886);
        return TextField(
          controller: controller,
          keyboardType: TextInputType.datetime,
          inputFormatters: const [_DateInputFormatter()],
          decoration: _inputDecoration(label).copyWith(
            hintText: 'TT.MM.JJJJ',
            errorText: errorText,
            errorMaxLines: 2,
          ),
        );
      },
    );
  }
}

class _DateInputFormatter extends TextInputFormatter {
  const _DateInputFormatter();

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

String _formatDate(DateTime? value) {
  if (value == null) return '';
  return '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';
}

DateTime? _parseDate(String source) {
  final parts = source.trim().split('.');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null || year < 1886) {
    return null;
  }
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

String? _dateInputError(String source, {required int minimumYear}) {
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
  if (year == null || year < minimumYear || year > currentYear) {
    return 'Das Jahr muss zwischen $minimumYear und $currentYear liegen.';
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

bool _validOptionalNumber(String source, int? value, {required int maximum}) {
  final text = source.trim();
  if (text.isEmpty) return true;
  return value != null && value >= 0 && value <= maximum;
}

void _showInvalidDateMessage(BuildContext context, String field) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$field muss als gültiges Datum eingegeben werden.'),
    ),
  );
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
