import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:plaqa/main.dart' as app;
import 'package:plaqa/shared/firebase/firebase_emulator_configuration.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plaqa starts without an uncaught Flutter exception', (
    WidgetTester tester,
  ) async {
    expect(
      kPlaqaUseFirebaseEmulators,
      isTrue,
      reason: 'Integrationstests duerfen nur im Firebase-Emulatormodus laufen.',
    );
    await app.main();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
