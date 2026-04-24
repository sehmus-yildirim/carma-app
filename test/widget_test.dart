import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carma/app/carma_app.dart';

void main() {
  testWidgets('Carma app shows auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CarmaApp());

    expect(find.text('Carma'), findsOneWidget);
    expect(find.text('Einloggen'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}