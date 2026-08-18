import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_modification.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_timeline_entry.dart';
import 'package:plaqa/features/profile/presentation/widgets/profile_vehicle_modification_sheet.dart';
import 'package:plaqa/features/profile/presentation/widgets/profile_vehicle_timeline_sheet.dart';

void main() {
  testWidgets('modification confirms discard and saves for selected vehicle', (
    tester,
  ) async {
    ProfileVehicleModification? saved;
    await tester.pumpWidget(
      _EditorHost(
        onOpen: (context) => showProfileVehicleModificationSheet(
          context,
          userId: 'user-a',
          vehicle: _vehicle('vehicle-b'),
          modificationId: 'modification-a',
          onSave: (value) async => saved = value,
        ),
      ),
    );
    await tester.tap(find.text('Editor öffnen'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldWithLabel('Titel'), 'Sportfahrwerk');
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(find.text('Änderungen verwerfen?'), findsOneWidget);
    await tester.tap(find.text('Weiter bearbeiten'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Speichern'));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(saved?.vehicleId, 'vehicle-b');
    expect(saved?.title, 'Sportfahrwerk');
  });

  testWidgets('timeline confirms discard and saves for selected vehicle', (
    tester,
  ) async {
    ProfileVehicleTimelineEntry? saved;
    await tester.pumpWidget(
      _EditorHost(
        onOpen: (context) => showProfileVehicleTimelineSheet(
          context,
          userId: 'user-a',
          vehicle: _vehicle('vehicle-c'),
          entryId: 'timeline-a',
          onSave: (value) async => saved = value,
        ),
      ),
    );
    await tester.tap(find.text('Editor öffnen'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldWithLabel('Titel'), 'Ölwechsel');
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(find.text('Änderungen verwerfen?'), findsOneWidget);
    await tester.tap(find.text('Weiter bearbeiten'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Speichern'));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(saved?.vehicleId, 'vehicle-c');
    expect(saved?.title, 'Ölwechsel');
  });
}

Finder _fieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

ProfileVehicle _vehicle(String id) => ProfileVehicle(
  id: id,
  ownerUserId: 'user-a',
  brand: 'BMW',
  model: 'X6',
  color: 'Schwarz',
  countryCode: 'DE',
  plateRegion: 'HH',
  plateLetters: 'SY',
  plateNumbers: '4700',
  visibility: ProfileVehicleVisibility.contacts,
  showOnPublicProfile: true,
);

class _EditorHost extends StatelessWidget {
  const _EditorHost({required this.onOpen});

  final Future<bool> Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (sheetContext) => Scaffold(
          body: TextButton(
            onPressed: () => onOpen(sheetContext),
            child: const Text('Editor öffnen'),
          ),
        ),
      ),
    );
  }
}
