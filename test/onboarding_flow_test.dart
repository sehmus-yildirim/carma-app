import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/auth/data/user_profile_repository.dart';
import 'package:plaqa/features/onboarding/presentation/onboarding_flow_screen.dart';

void main() {
  test('onboarding completion state accepts only explicit completion', () {
    expect(UserProfileRepository.onboardingCompletedFromData(null), isFalse);
    expect(
      UserProfileRepository.onboardingCompletedFromData({
        'onboardingCompleted': false,
      }),
      isFalse,
    );
    expect(
      UserProfileRepository.onboardingCompletedFromData({
        'onboardingCompleted': true,
      }),
      isTrue,
    );
    expect(
      UserProfileRepository.onboardingCompletedFromData({
        'onboardingCompletedAt': DateTime.utc(2026, 8, 29),
      }),
      isTrue,
    );
  });

  testWidgets('onboarding completes only after all four steps', (tester) async {
    var completionCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlowScreen(
          onCompleted: () async {
            completionCalls += 1;
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Schritt 1 von 4'), findsOneWidget);

    for (var step = 1; step < 4; step += 1) {
      await _tapVisible(tester, find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(completionCalls, 0);
      expect(find.text('Schritt ${step + 1} von 4'), findsOneWidget);
    }

    await _tapVisible(tester, find.text('Speichern und starten'));
    await tester.pumpAndSettle();
    expect(completionCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding shows a retryable persistence error', (tester) async {
    final completion = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlowScreen(onCompleted: () => completion.future),
      ),
    );

    for (var step = 1; step < 4; step += 1) {
      await _tapVisible(tester, find.text('Weiter'));
      await tester.pumpAndSettle();
    }

    await _tapVisible(tester, find.text('Speichern und starten'));
    await tester.pump();
    expect(find.text('Wird gespeichert'), findsOneWidget);

    completion.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Abschluss konnte gerade nicht gespeichert werden'),
      findsOneWidget,
    );
    expect(find.text('Speichern und starten'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all onboarding steps fit a compact phone without scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlowScreen(onCompleted: () async {}),
      ),
    );

    const headings = <String>[
      'Willkommen bei plaqa',
      'Profil vorbereiten',
      'Fahrzeug hinzufügen',
      'Verifizierung verstehen',
    ];

    for (var step = 0; step < headings.length; step += 1) {
      expect(find.text(headings[step]), findsOneWidget);
      expect(find.byType(Scrollable), findsNothing);
      expect(tester.takeException(), isNull);

      if (step < headings.length - 1) {
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
      }
    }

    expect(find.text('Speichern und starten'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}
