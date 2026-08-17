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

Future<bool> showProfileVehicleDetailsSheet(
  BuildContext context, {
  required ProfileVehicle vehicle,
  required Future<void> Function(ProfileVehicle vehicle) onSave,
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
  final hsnController = TextEditingController(text: vehicle.hsn);
  final tsnController = TextEditingController(text: vehicle.tsn);
  final vinController = TextEditingController(text: vehicle.vin);
  final customEquipmentController = TextEditingController();

  var bodyStyle = vehicle.bodyStyle ?? 'SUV';
  var fuelType = vehicle.fuelType ?? 'Benzin';
  var transmission = vehicle.transmission ?? 'Automatik';
  var drivetrain = vehicle.drivetrain ?? 'Frontantrieb';
  var firstRegistration = vehicle.firstRegistration;
  var ownedSince = vehicle.ownedSince;
  var equipment = <String>{...vehicle.equipment};
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
            Future<void> selectDate({required bool registration}) async {
              final initialDate = registration
                  ? firstRegistration ?? DateTime.now()
                  : ownedSince ?? DateTime.now();
              final selected = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(1886),
                lastDate: DateTime.now(),
              );
              if (selected == null) return;
              setSheetState(() {
                if (registration) {
                  firstRegistration = selected;
                } else {
                  ownedSince = selected;
                }
              });
            }

            Future<void> submit() async {
              if (isSaving) return;
              FocusManager.instance.primaryFocus?.unfocus();
              final year = int.tryParse(yearController.text.trim());
              if (year != null && (year < 1886 || year > 2100)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(content: Text('Bitte prüfe das Baujahr.')),
                );
                return;
              }
              setSheetState(() => isSaving = true);
              try {
                await onSave(
                  vehicle.copyWith(
                    year: year,
                    firstRegistration: firstRegistration,
                    clearFirstRegistration: firstRegistration == null,
                    bodyStyle: bodyStyle,
                    engineDescription: engineController.text,
                    displacementCcm: int.tryParse(
                      displacementController.text.trim(),
                    ),
                    horsepower: int.tryParse(horsepowerController.text.trim()),
                    kilowatts: int.tryParse(kilowattsController.text.trim()),
                    fuelType: fuelType,
                    transmission: transmission,
                    drivetrain: drivetrain,
                    equipment: equipment.toList()..sort(),
                    hsn: hsnController.text,
                    tsn: tsnController.text,
                    vin: vinController.text,
                    ownedSince: ownedSince,
                    clearOwnedSince: ownedSince == null,
                    mileage: int.tryParse(mileageController.text.trim()),
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
                      'Fahrzeugdaten konnten nicht gespeichert werden: $error',
                    ),
                  ),
                );
              }
            }

            void addCustomEquipment() {
              final value = customEquipmentController.text.trim();
              if (value.isEmpty || equipment.length >= 40) return;
              setSheetState(() {
                equipment.add(value);
                customEquipmentController.clear();
              });
            }

            return Padding(
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
                              'Fahrzeugdaten',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
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
                                  child: _DateField(
                                    label: 'Erstzulassung',
                                    value: firstRegistration,
                                    onTap: () => selectDate(registration: true),
                                    onClear: () => setSheetState(
                                      () => firstRegistration = null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _DetailDropdown(
                              label: 'Karosserieform',
                              value: bodyStyle,
                              values: const [
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
                                    label: 'Hubraum cm³',
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
                                      'Frontantrieb',
                                      'Heckantrieb',
                                      'Allrad',
                                      'Kette',
                                      'Riemen',
                                      'Sonstiges',
                                    ],
                                    onChanged: (value) =>
                                        setSheetState(() => drivetrain = value),
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
                                  child: _DateField(
                                    label: 'Besitzer seit',
                                    value: ownedSince,
                                    onTap: () =>
                                        selectDate(registration: false),
                                    onClear: () =>
                                        setSheetState(() => ownedSince = null),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
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
                                  label: Text(option),
                                  selected: equipment.contains(option),
                                  onSelected: (selected) => setSheetState(() {
                                    selected
                                        ? equipment.add(option)
                                        : equipment.remove(option);
                                  }),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _DetailTextField(
                                    controller: customEquipmentController,
                                    label: 'Eigene Ausstattung',
                                    maxLength: 60,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  tooltip: 'Ausstattung hinzufügen',
                                  onPressed: addCustomEquipment,
                                  icon: const Icon(Icons.add_rounded),
                                ),
                              ],
                            ),
                            if (equipment
                                .where(
                                  (item) => !_equipmentOptions.contains(item),
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
                                        onDeleted: () => setSheetState(
                                          () => equipment.remove(item),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            const SizedBox(height: 20),
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
                                    color: CaRismaDesignTokens.textSecondary,
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
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Listener(
                      onPointerDown: (_) {
                        if (!isSaving &&
                            FocusManager.instance.primaryFocus?.hasFocus ==
                                true) {
                          submit();
                        }
                      },
                      child: SizedBox(
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
    yearController.dispose();
    engineController.dispose();
    displacementController.dispose();
    horsepowerController.dispose();
    kilowattsController.dispose();
    mileageController.dispose();
    hsnController.dispose();
    tsnController.dispose();
    vinController.dispose();
    customEquipmentController.dispose();
  }
}

class _DetailTextField extends StatelessWidget {
  const _DetailTextField({
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

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: _inputDecoration(label).copyWith(
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
