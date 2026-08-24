import 'package:plaqa/features/auth/data/auth_service.dart';
import 'package:plaqa/features/settings/presentation/account_security_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth account snapshot', () {
    test('maps and labels configured providers without exposing internals', () {
      const snapshot = AuthAccountSnapshot(
        email: 'user@example.com',
        isEmailVerified: true,
        providers: {AuthLoginProvider.password, AuthLoginProvider.google},
      );

      expect(snapshot.hasPasswordProvider, isTrue);
      expect(snapshot.isGoogleOnly, isFalse);
      expect(snapshot.providerLabel, 'E-Mail und Google');
      expect(
        AuthAccountSnapshot.providerFromId('apple.com'),
        AuthLoginProvider.apple,
      );
    });

    test('uses safe German error messages instead of Firebase details', () {
      expect(
        accountAuthErrorMessage(FirebaseAuthException(code: 'email-mismatch')),
        'Die eingegebene E-Mail Adresse gehört nicht zu diesem Konto.',
      );
      expect(
        accountAuthErrorMessage(
          FirebaseAuthException(
            code: 'unexpected-internal-code',
            message: 'raw Firebase detail',
          ),
        ),
        'Die Kontoaktion konnte gerade nicht durchgeführt werden.',
      );
      expect(
        accountAuthErrorMessage(
          FirebaseAuthException(code: 'email-not-verified'),
        ),
        'Bestätige zuerst deine E-Mail Adresse.',
      );
      expect(
        accountAuthErrorMessage(
          FirebaseAuthException(code: 'provider-already-linked'),
        ),
        'Apple ist bereits mit diesem Konto verknüpft.',
      );
      expect(
        accountAuthErrorMessage(
          FirebaseAuthException(code: 'credential-already-in-use'),
        ),
        contains('bereits zu einem anderen Konto'),
      );
    });
  });

  testWidgets('renders professional password account status without UID copy', (
    tester,
  ) async {
    final gateway = _FakeAccountAuthGateway(_passwordAccount);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityScreen(
          accountGateway: gateway,
          initialAccount: _passwordAccount,
          onLogout: () {},
          onRequestAccountDeletion: () {},
          onOpenSupport: () {},
        ),
      ),
    );

    expect(find.text('konto@example.com'), findsOneWidget);
    expect(find.text('Bestätigt'), findsWidgets);
    expect(find.text('Anmeldung über E-Mail Adresse'), findsOneWidget);
    expect(find.textContaining('UID'), findsNothing);
    expect(find.text('Kopieren'), findsNothing);
    expect(find.text('Passwort ändern'), findsOneWidget);
    expect(find.text('E-Mail Adresse ändern'), findsOneWidget);
  });

  testWidgets('google-only account explains provider-managed password', (
    tester,
  ) async {
    final gateway = _FakeAccountAuthGateway(_googleAccount);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityScreen(
          accountGateway: gateway,
          initialAccount: _googleAccount,
          onLogout: () {},
          onRequestAccountDeletion: () {},
          onOpenSupport: () {},
        ),
      ),
    );

    expect(find.text('Anmeldung über Google'), findsOneWidget);
    expect(
      find.text('Dein Passwort wird über Google verwaltet.'),
      findsOneWidget,
    );
    expect(find.text('Passwort ändern'), findsNothing);
  });

  testWidgets('links Apple once and refreshes the account status', (
    tester,
  ) async {
    final gateway = _FakeAccountAuthGateway(_passwordAccount);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityScreen(
          accountGateway: gateway,
          initialAccount: _passwordAccount,
          appleLinkAvailable: true,
          onLogout: () {},
          onRequestAccountDeletion: () {},
          onOpenSupport: () {},
        ),
      ),
    );

    expect(find.text('Mit Apple verknüpfen'), findsOneWidget);
    await tester.tap(find.text('Mit Apple verknüpfen'));
    await tester.pumpAndSettle();

    expect(gateway.appleLinkCalls, 1);
    expect(find.text('Mit Apple verknüpft'), findsOneWidget);
    expect(find.text('Aktiv'), findsOneWidget);
  });

  testWidgets('password reset sends only after controlled email confirmation', (
    tester,
  ) async {
    final gateway = _FakeAccountAuthGateway(_passwordAccount);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityScreen(
          accountGateway: gateway,
          initialAccount: _passwordAccount,
          onLogout: () {},
          onRequestAccountDeletion: () {},
          onOpenSupport: () {},
        ),
      ),
    );

    await tester.tap(find.text('Passwort ändern'));
    await tester.pumpAndSettle();
    expect(gateway.passwordResetCalls, 0);

    await tester.enterText(find.byType(TextField).first, 'falsch@example.com');
    await tester.tap(find.text('Zurücksetzungslink senden'));
    await tester.pump();

    expect(gateway.passwordResetCalls, 1);
    expect(
      find.text('Die eingegebene E-Mail Adresse gehört nicht zu diesem Konto.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, 'konto@example.com');
    await tester.tap(find.text('Zurücksetzungslink senden'));
    await tester.pump();

    expect(gateway.passwordResetCalls, 2);
    expect(find.text('Link wurde gesendet'), findsOneWidget);
  });

  testWidgets('verification email is sent only after explicit action', (
    tester,
  ) async {
    final gateway = _FakeAccountAuthGateway(_unverifiedAccount);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityScreen(
          accountGateway: gateway,
          initialAccount: _unverifiedAccount,
          onLogout: () {},
          onRequestAccountDeletion: () {},
          onOpenSupport: () {},
        ),
      ),
    );

    await tester.tap(find.text('E-Mail bestätigen'));
    await tester.pumpAndSettle();
    expect(gateway.verificationCalls, 0);

    await tester.tap(find.text('Bestätigungslink senden'));
    await tester.pump();

    expect(gateway.verificationCalls, 1);
    expect(find.textContaining('Bestätigungslink wurde an'), findsOneWidget);
  });

  testWidgets('password reset stays locked until email is verified', (
    tester,
  ) async {
    final gateway = _FakeAccountAuthGateway(_unverifiedAccount);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityScreen(
          accountGateway: gateway,
          initialAccount: _unverifiedAccount,
          onLogout: () {},
          onRequestAccountDeletion: () {},
          onOpenSupport: () {},
        ),
      ),
    );

    expect(find.text('Bestätige zuerst deine E-Mail Adresse.'), findsWidgets);
    expect(find.text('E-Mail offen'), findsOneWidget);

    await tester.tap(find.text('Passwort ändern'));
    await tester.pumpAndSettle();

    expect(find.text('Konto & Sicherheit'), findsOneWidget);
    expect(find.text('Zurücksetzungslink senden'), findsNothing);
    expect(gateway.passwordResetCalls, 0);
  });

  testWidgets('recovery keeps one clear support action', (tester) async {
    final gateway = _FakeAccountAuthGateway(_passwordAccount);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityScreen(
          accountGateway: gateway,
          initialAccount: _passwordAccount,
          onLogout: () {},
          onRequestAccountDeletion: () {},
          onOpenSupport: () {},
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Zugriff wiederherstellen'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Zugriff wiederherstellen'));
    await tester.pumpAndSettle();

    expect(find.text('Kontowiederherstellung'), findsOneWidget);
    expect(find.text('Kein Zugriff auf die E-Mail'), findsOneWidget);
    expect(find.text('Hilfe bei der Anmeldung'), findsNothing);
    expect(find.text('Support kontaktieren'), findsOneWidget);
  });

  testWidgets('session revocation requires controlled password confirmation', (
    tester,
  ) async {
    final gateway = _FakeAccountAuthGateway(_passwordAccount);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSessionsScreen(
          account: _passwordAccount,
          accountGateway: gateway,
        ),
      ),
    );

    await tester.tap(find.text('Alle Sitzungen abmelden'));
    await tester.pumpAndSettle();
    expect(gateway.revokeCalls, 0);

    await tester.enterText(find.byType(TextField), 'sicheres-passwort');
    await tester.tap(find.text('Alle abmelden'));
    await tester.pumpAndSettle();

    expect(gateway.revokeCalls, 1);
    expect(gateway.lastRevokePassword, 'sicheres-passwort');
  });
}

final AuthAccountSnapshot _passwordAccount = AuthAccountSnapshot(
  email: 'konto@example.com',
  isEmailVerified: true,
  providers: {AuthLoginProvider.password},
  creationTime: DateTime.utc(2026, 1, 2, 10, 30),
  lastSignInTime: DateTime.utc(2026, 8, 12, 8, 15),
);

const AuthAccountSnapshot _unverifiedAccount = AuthAccountSnapshot(
  email: 'konto@example.com',
  isEmailVerified: false,
  providers: {AuthLoginProvider.password},
);

const AuthAccountSnapshot _googleAccount = AuthAccountSnapshot(
  email: 'google@example.com',
  isEmailVerified: true,
  providers: {AuthLoginProvider.google},
);

class _FakeAccountAuthGateway implements AccountAuthGateway {
  _FakeAccountAuthGateway(this.account);

  AuthAccountSnapshot account;
  int passwordResetCalls = 0;
  int verificationCalls = 0;
  int appleLinkCalls = 0;
  int revokeCalls = 0;
  String? lastRevokePassword;

  @override
  Future<void> deleteCurrentUser({String? currentPassword}) async {}

  @override
  Future<void> linkCurrentUserWithApple() async {
    appleLinkCalls += 1;
    account = AuthAccountSnapshot(
      userId: account.userId,
      email: account.email,
      isEmailVerified: account.isEmailVerified,
      providers: {...account.providers, AuthLoginProvider.apple},
      creationTime: account.creationTime,
      lastSignInTime: account.lastSignInTime,
    );
  }

  @override
  Future<AuthAccountSnapshot?> loadCurrentAccount() async => account;

  @override
  Future<void> requestCurrentUserEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {}

  @override
  Future<void> revokeAllSessions({String? currentPassword}) async {
    revokeCalls += 1;
    lastRevokePassword = currentPassword;
  }

  @override
  Future<void> sendCurrentUserEmailVerification() async {
    verificationCalls += 1;
  }

  @override
  Future<void> sendCurrentUserPasswordReset({
    required String enteredEmail,
  }) async {
    passwordResetCalls += 1;
    if (enteredEmail.trim().toLowerCase() != account.email.toLowerCase()) {
      throw FirebaseAuthException(code: 'email-mismatch');
    }
  }
}
