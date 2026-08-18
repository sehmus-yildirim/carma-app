import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_repository.dart';
import 'package:plaqa/features/profile/presentation/widgets/profile_vehicle_details_sheet.dart';
import 'package:plaqa/features/profile/presentation/widgets/profile_vehicle_editor_sheet.dart';
import 'package:plaqa/features/settings/presentation/profile_verification_settings_screen.dart';
import 'package:plaqa/shared/models/carisma_models.dart';

void main() {
  testWidgets('shows a clear empty vehicle state', (tester) async {
    final repository = _FakeVehicleRepository(const []);
    await tester.pumpWidget(_app(repository));
    await tester.pump();

    expect(find.text('Fahrzeuge'), findsOneWidget);
    expect(find.text('Fahrzeug hinzufügen'), findsOneWidget);
    expect(
      find.textContaining('Noch kein Fahrzeug hinterlegt'),
      findsOneWidget,
    );
  });

  testWidgets('shows primary, verification and visibility states', (
    tester,
  ) async {
    final repository = _FakeVehicleRepository([
      _vehicle(
        isPrimary: true,
        verificationStatus: ProfileVehicleVerificationStatus.inReview,
      ),
    ]);
    await tester.pumpWidget(_app(repository));
    await tester.pump();

    expect(find.text('BMW X6'), findsOneWidget);
    expect(find.text('HH-CR 2026'), findsOneWidget);
    expect(find.textContaining('In Prüfung'), findsOneWidget);
    expect(find.text('Öffentlich sichtbar'), findsOneWidget);
    expect(find.text('Hauptfahrzeug'), findsOneWidget);
  });

  testWidgets('explains soft-delete effects before removing a vehicle', (
    tester,
  ) async {
    final repository = _FakeVehicleRepository([_vehicle(isPrimary: false)]);
    await tester.pumpWidget(_app(repository));
    await tester.pump();

    await tester.tap(find.byTooltip('Fahrzeug verwalten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fahrzeug entfernen'));
    await tester.pumpAndSettle();

    expect(find.text('Fahrzeug entfernen?'), findsOneWidget);
    expect(find.textContaining('neuen Storys und Anfragen'), findsOneWidget);
    expect(
      find.textContaining('Bestehende Chats bleiben erhalten'),
      findsOneWidget,
    );
  });

  testWidgets('vehicle editor offers all requested vehicle kinds', (
    tester,
  ) async {
    final repository = _FakeVehicleRepository(const []);
    await tester.pumpWidget(_editorApp(repository));

    await tester.tap(find.text('Editor öffnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pkw'));
    await tester.pumpAndSettle();

    expect(find.text('Cabrio/Roadster'), findsOneWidget);
    expect(find.text('SUV'), findsOneWidget);
    expect(find.text('Van'), findsOneWidget);
  });

  testWidgets('motorcycle selection switches brands and matching models', (
    tester,
  ) async {
    final repository = _FakeVehicleRepository(const []);
    await tester.pumpWidget(_editorApp(repository));
    await tester.tap(find.text('Editor öffnen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pkw'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Motorrad'));
    await tester.pumpAndSettle();

    expect(find.text('Aprilia'), findsOneWidget);
    expect(find.text('Abarth'), findsNothing);

    await tester.tap(find.text('Aprilia'));
    await tester.pumpAndSettle();
    expect(find.text('BMW Motorrad'), findsOneWidget);
    expect(find.text('Audi'), findsNothing);
    await tester.tap(find.text('Honda'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CB125R'));
    await tester.pumpAndSettle();
    expect(find.text('CRF1100L Africa Twin'), findsOneWidget);
    expect(find.text('Civic'), findsNothing);
  });

  testWidgets('vehicle catalogs offer fallback brand and model', (
    tester,
  ) async {
    final repository = _FakeVehicleRepository(const []);
    await tester.pumpWidget(_editorApp(repository));
    await tester.tap(find.text('Editor öffnen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abarth'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sonstige Marke'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Sonstige Marke'));
    await tester.pumpAndSettle();

    expect(_fieldWithLabel('Eigene Marke'), findsOneWidget);
    expect(find.text('Sonstiges Modell'), findsOneWidget);
    expect(_fieldWithLabel('Eigenes Modell'), findsOneWidget);
    expect(find.text('Dokumente hochladen'), findsNothing);
  });

  testWidgets('standard plate accepts letters and at most four digits', (
    tester,
  ) async {
    final repository = _FakeVehicleRepository(const []);
    await tester.pumpWidget(_editorApp(repository));
    await tester.tap(find.text('Editor öffnen'));
    await tester.pumpAndSettle();

    await tester.enterText(_fieldWithLabel('Stadt'), 'h1h');
    await tester.enterText(_fieldWithLabel('Buchstaben'), 'c2r');
    await tester.enterText(_fieldWithLabel('Zahlen'), '12345');
    expect(_fieldController(tester, 'Stadt').text, 'HH');
    expect(_fieldController(tester, 'Buchstaben').text, 'CR');
    expect(_fieldController(tester, 'Zahlen').text, '1234');

    await tester.ensureVisible(find.text('Fahrzeug speichern'));
    await tester.tap(find.text('Fahrzeug speichern'));
    await tester.pumpAndSettle();

    expect(repository.savedVehicle, isNotNull);
    expect(repository.savedVehicle!.plateNumbers, '1234');
    expect(find.text('Fahrzeug hinzufügen'), findsNothing);
  });

  testWidgets('electric plate adds E and standard plate removes it', (
    tester,
  ) async {
    final repository = _FakeVehicleRepository(const []);
    await tester.pumpWidget(_editorApp(repository));
    await tester.tap(find.text('Editor öffnen'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Standard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elektro'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldWithLabel('Zahlen'), '12345E');
    expect(_fieldController(tester, 'Zahlen').text, '1234E');

    await tester.tap(find.text('Elektro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard'));
    await tester.pumpAndSettle();
    expect(_fieldController(tester, 'Zahlen').text, '1234');
  });

  testWidgets('vehicle editor saves all four vehicle card values', (
    tester,
  ) async {
    final repository = _FakeVehicleRepository(const []);
    await tester.pumpWidget(_editorApp(repository));
    await tester.tap(find.text('Editor öffnen'));
    await tester.pumpAndSettle();

    await tester.enterText(_fieldWithLabel('Stadt'), 'HH');
    await tester.enterText(_fieldWithLabel('Buchstaben'), 'SY');
    await tester.enterText(_fieldWithLabel('Zahlen'), '4700');
    await tester.enterText(_fieldWithLabel('Leistung (PS)'), '381');
    await tester.enterText(_fieldWithLabel('Erstzulassung'), '01.06.2015');
    await tester.enterText(_fieldWithLabel('Kilometerstand'), '123111');
    await tester.enterText(_fieldWithLabel('Besitzer seit'), '15.08.2020');

    await tester.ensureVisible(find.text('Fahrzeug speichern'));
    await tester.tap(find.text('Fahrzeug speichern'));
    await tester.pumpAndSettle();

    expect(repository.savedVehicle, isNotNull);
    expect(repository.savedVehicle!.horsepower, 381);
    expect(repository.savedVehicle!.mileage, 123111);
    expect(repository.savedVehicle!.firstRegistration, DateTime(2015, 6, 1));
    expect(repository.savedVehicle!.ownedSince, DateTime(2020, 8, 15));
  });

  testWidgets(
    'equipment can be selected, added, removed, saved and stays vehicle-specific',
    (tester) async {
      await tester.pumpWidget(
        _EquipmentHost(
          vehicles: [
            _vehicle(isPrimary: true).copyWith(equipment: const ['Panorama']),
            _vehicle(
              isPrimary: false,
              id: 'vehicle-b',
            ).copyWith(equipment: const ['Sitzheizung']),
          ],
        ),
      );

      await tester.tap(find.text('Ausstattung 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('equipment-option-M-Paket')));
      await tester.enterText(
        find.byKey(const ValueKey('custom-equipment-input')),
        'panorama',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('add-custom-equipment')),
      );
      await tester.tap(find.byKey(const ValueKey('add-custom-equipment')));
      await tester.pump();
      expect(
        find.text('Diese Ausstattung ist bereits ausgewählt.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('custom-equipment-input')),
        'Keramikversiegelung',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('add-custom-equipment')),
      );
      await tester.tap(find.byKey(const ValueKey('add-custom-equipment')));
      await tester.pump();
      final customChip = find.widgetWithText(InputChip, 'Keramikversiegelung');
      expect(customChip, findsOneWidget);
      tester.widget<InputChip>(customChip).onDeleted!.call();
      await tester.pump();
      expect(customChip, findsNothing);

      await tester.ensureVisible(
        find.byKey(const ValueKey('save-vehicle-details')),
      );
      await tester.tap(find.byKey(const ValueKey('save-vehicle-details')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ausstattung 1'));
      await tester.pumpAndSettle();
      final firstVehicleOption = tester.widget<FilterChip>(
        find.byKey(const ValueKey('equipment-option-M-Paket')),
      );
      expect(firstVehicleOption.selected, isTrue);
      await tester.tap(find.byTooltip('Schließen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ausstattung 2'));
      await tester.pumpAndSettle();
      final secondVehicleOption = tester.widget<FilterChip>(
        find.byKey(const ValueKey('equipment-option-M-Paket')),
      );
      expect(secondVehicleOption.selected, isFalse);
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const ValueKey('equipment-option-Sitzheizung')),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.byTooltip('Schließen'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('equipment limit and unsaved discard are explained', (
    tester,
  ) async {
    final fullVehicle = _vehicle(
      isPrimary: true,
    ).copyWith(equipment: List<String>.generate(40, (index) => 'Extra $index'));
    await tester.pumpWidget(_EquipmentHost(vehicles: [fullVehicle]));
    await tester.tap(find.text('Ausstattung 1'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('custom-equipment-input')),
      'Noch ein Extra',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('add-custom-equipment')),
    );
    await tester.tap(find.byKey(const ValueKey('add-custom-equipment')));
    await tester.pump();
    expect(find.textContaining('Maximal 40 Ausstattungen'), findsOneWidget);

    final customChip = find.widgetWithText(InputChip, 'Extra 0');
    tester.widget<InputChip>(customChip).onDeleted!.call();
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Schließen'));
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(find.text('Änderungen verwerfen?'), findsOneWidget);
    await tester.tap(find.text('Weiter bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.text('Ausstattung'), findsWidgets);
  });
}

Finder _fieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

TextEditingController _fieldController(WidgetTester tester, String label) {
  return tester.widget<TextField>(_fieldWithLabel(label)).controller!;
}

Widget _app(ProfileVehicleRepository repository) {
  return MaterialApp(
    home: ProfileVerificationSettingsScreen(
      userState: AppUserState.localRegistered(userId: 'user-a'),
      area: ProfileSettingsArea.vehicles,
      vehicleRepository: repository,
    ),
  );
}

Widget _editorApp(_FakeVehicleRepository repository) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showProfileVehicleEditorSheet(
            context,
            userId: 'user-a',
            vehicleId: repository.createVehicleId('user-a'),
            onSave: repository.saveVehicle,
          ),
          child: const Text('Editor öffnen'),
        ),
      ),
    ),
  );
}

ProfileVehicle _vehicle({
  required bool isPrimary,
  String id = 'vehicle-a',
  ProfileVehicleVerificationStatus verificationStatus =
      ProfileVehicleVerificationStatus.evidenceMissing,
}) {
  return ProfileVehicle(
    id: id,
    ownerUserId: 'user-a',
    brand: 'BMW',
    model: 'X6',
    color: 'Schwarz',
    countryCode: 'DE',
    plateRegion: 'HH',
    plateLetters: 'CR',
    plateNumbers: '2026',
    isPrimary: isPrimary,
    verificationStatus: verificationStatus,
    showOnPublicProfile: true,
    visibility: ProfileVehicleVisibility.contacts,
  );
}

class _FakeVehicleRepository extends ProfileVehicleRepository {
  _FakeVehicleRepository(this.vehicles);

  final List<ProfileVehicle> vehicles;
  ProfileVehicle? savedVehicle;

  @override
  String createVehicleId(String userId) => 'vehicle-new';

  @override
  Future<void> saveVehicle(ProfileVehicle vehicle) async {
    savedVehicle = vehicle;
  }

  @override
  Stream<List<ProfileVehicle>> watchOwnerVehicles(String userId) {
    return Stream.value(vehicles);
  }

  @override
  Future<void> archiveVehicle({
    required String userId,
    required String vehicleId,
  }) async {}
}

class _EquipmentHost extends StatefulWidget {
  const _EquipmentHost({required this.vehicles});

  final List<ProfileVehicle> vehicles;

  @override
  State<_EquipmentHost> createState() => _EquipmentHostState();
}

class _EquipmentHostState extends State<_EquipmentHost> {
  late final List<ProfileVehicle> _vehicles = [...widget.vehicles];

  Future<void> _open(BuildContext sheetContext, int index) async {
    await showProfileVehicleDetailsSheet(
      sheetContext,
      vehicle: _vehicles[index],
      section: ProfileVehicleDetailsSection.equipment,
      onSave: (vehicle) async => setState(() => _vehicles[index] = vehicle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (sheetContext) => Scaffold(
          body: ListView.builder(
            itemCount: _vehicles.length,
            itemBuilder: (context, index) => TextButton(
              onPressed: () => _open(sheetContext, index),
              child: Text('Ausstattung ${index + 1}'),
            ),
          ),
        ),
      ),
    );
  }
}
