import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carma/main.dart';

void main() {
  testWidgets('Carma app shows Firebase connected text', (WidgetTester tester) async {
    await tester.pumpWidget(const CarmaApp());

    expect(find.text('Carma Firebase connected'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}