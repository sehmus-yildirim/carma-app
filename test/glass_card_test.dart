import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/shared/widgets/glass_card.dart';

void main() {
  testWidgets('GlassCard uses a flat outer surface by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GlassCard(child: Text('Bereich'))),
      ),
    );

    final card = tester.widget<GlassCard>(find.byType(GlassCard));
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(GlassCard),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(card.showOuterEffects, isFalse);
    expect(decoration.boxShadow, isNull);
  });

  testWidgets('GlassCard keeps legacy effect requests flat', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassCard(showOuterEffects: true, child: Text('Sonderfall')),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(GlassCard),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.boxShadow, isNull);
  });
}
