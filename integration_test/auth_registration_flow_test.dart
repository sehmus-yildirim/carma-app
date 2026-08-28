import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:plaqa/features/auth/presentation/login_screen.dart';
import 'package:plaqa/features/auth/presentation/register_screen.dart';
import 'package:plaqa/main.dart' as app;
import 'package:plaqa/shared/firebase/carisma_firestore_paths.dart';
import 'package:plaqa/shared/firebase/firebase_emulator_configuration.dart';
import 'package:plaqa/shared/widgets/carisma_primary_button.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registration, provisioning and login stay on local emulators', (
    WidgetTester tester,
  ) async {
    expect(
      kPlaqaUseFirebaseEmulators,
      isTrue,
      reason: 'Integrationstests duerfen nur im Firebase-Emulatormodus laufen.',
    );

    final email =
        'integration.user.${DateTime.now().microsecondsSinceEpoch}@plaqa.test';
    const password = 'Plaqa-Test-2026!';

    await app.main();
    await _pumpUntilFound(tester, find.text('Einloggen'));

    await tester.tap(find.text('Noch kein Konto? Registrieren'));
    await _pumpUntilFound(tester, find.text('Konto erstellen'));
    await tester.pump(const Duration(milliseconds: 300));

    final registerScreen = find.byType(RegisterScreen);
    await tester.enterText(
      _textFieldWithin(registerScreen, 'E-Mail-Adresse'),
      email,
    );
    await tester.enterText(
      _textFieldWithin(registerScreen, 'Passwort'),
      password,
    );
    await tester.enterText(
      _textFieldWithin(registerScreen, 'Passwort wiederholen'),
      password,
    );

    for (var index = 0; index < 3; index += 1) {
      final checkbox = find.byType(Checkbox).at(index);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
    }

    final createAccountButton = _enabledPrimaryButton('Konto erstellen');
    await _pumpUntilFound(tester, createAccountButton);
    await tester.ensureVisible(createAccountButton);
    await _tapPrimaryButton(tester, 'Konto erstellen');
    await _pumpUntilFound(
      tester,
      find.text('E-Mail bestätigen'),
      timeout: const Duration(seconds: 60),
    );

    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull);
    expect(user!.email, email);

    final firestore = FirebaseFirestore.instance;
    expect(
      (await firestore.doc(CaRismaFirestorePaths.user(user.uid)).get()).exists,
      isTrue,
    );
    expect(
      (await firestore.doc(CaRismaFirestorePaths.userProfile(user.uid)).get())
          .exists,
      isTrue,
    );
    expect(
      (await firestore
              .doc(CaRismaFirestorePaths.userSearchCredit(user.uid))
              .get())
          .exists,
      isTrue,
    );
    final consents = await firestore
        .collection(CaRismaFirestorePaths.userLegalConsents(user.uid))
        .get();
    expect(consents.docs, hasLength(4));

    await tester.tap(find.text('Weiter zur App'));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('app_shell')),
      timeout: const Duration(seconds: 45),
    );
    for (final label in const [
      'Suchen',
      'Profil',
      'Chats',
      'Melden',
      'Einstellungen',
    ]) {
      await tester.tap(find.bySemanticsLabel(label));
      await _pumpUntilFound(tester, find.text(label));
    }

    await FirebaseAuth.instance.signOut();
    await _pumpUntilFound(tester, find.text('Einloggen'));
    await tester.pump(const Duration(milliseconds: 300));

    final loginScreen = find.byType(LoginScreen);
    await tester.enterText(
      _textFieldWithin(loginScreen, 'E-Mail-Adresse'),
      email,
    );
    await tester.enterText(
      _textFieldWithin(loginScreen, 'Passwort'),
      'Falsches-Testpasswort!',
    );
    await tester.pump();
    await _tapPrimaryButton(tester, 'Einloggen');
    await _pumpUntilFound(
      tester,
      find.text('E-Mail oder Passwort ist falsch.'),
    );

    await _pumpUntilFound(tester, _enabledPrimaryButton('Einloggen'));
    final passwordInput = _textFieldWithin(loginScreen, 'Passwort');
    await tester.tap(passwordInput);
    await tester.pump();
    await tester.enterText(passwordInput, password);
    await tester.pump();
    final passwordField = tester.widget<TextField>(passwordInput);
    expect(passwordField.controller?.text, password);
    await _pumpUntilAbsent(
      tester,
      find.text('E-Mail oder Passwort ist falsch.'),
    );
    await _tapPrimaryButton(tester, 'Einloggen');
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('app_shell')),
      timeout: const Duration(seconds: 45),
    );

    await FirebaseAuth.instance.signOut();
  });
}

Finder _textFieldWithin(Finder screen, String hintText) {
  return find.descendant(
    of: screen,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == hintText,
      description: 'TextField mit Hinweis "$hintText"',
    ),
  );
}

Finder _enabledPrimaryButton(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is CaRismaPrimaryButton &&
        widget.label == label &&
        widget.isEnabled &&
        !widget.isLoading,
    description: 'Aktiver Primaerbutton "$label"',
  );
}

Future<void> _tapPrimaryButton(WidgetTester tester, String label) async {
  final button = _enabledPrimaryButton(label);
  await _pumpUntilFound(tester, button);
  final tapTarget = find.descendant(of: button, matching: find.byType(InkWell));
  expect(tapTarget, findsOneWidget);
  await tester.ensureVisible(tapTarget);
  await tester.tap(tapTarget);
  await tester.pump();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }

  if (finder.evaluate().isEmpty) {
    final visibleTexts = find
        .byType(Text)
        .evaluate()
        .map((element) => element.widget as Text)
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .where((text) => text.trim().isNotEmpty)
        .toSet()
        .join(' | ');
    fail(
      'Erwartetes Widget wurde nicht gefunden. Sichtbare Texte: $visibleTexts',
    );
  }
}

Future<void> _pumpUntilAbsent(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  if (finder.evaluate().isNotEmpty) {
    fail('Ein unerwartetes Widget blieb sichtbar.');
  }
}
