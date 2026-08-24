import 'package:plaqa/features/auth/data/auth_service.dart';
import 'package:plaqa/features/auth/data/mfa_service.dart';
import 'package:plaqa/features/auth/presentation/mfa_screens.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MFA phone data', () {
    test('normalizes supported DACH phone numbers', () {
      expect(normalizeDachPhoneNumber('+49 170-1234567'), '+491701234567');
      expect(normalizeDachPhoneNumber('0043 660 1234567'), '+436601234567');
      expect(normalizeDachPhoneNumber('+41 79 123 45 67'), '+41791234567');
    });

    test(
      'rejects unsupported regions and never exposes full phone numbers',
      () {
        expect(
          () => normalizeDachPhoneNumber('+33 612345678'),
          throwsA(
            isA<FirebaseAuthException>().having(
              (error) => error.code,
              'code',
              'unsupported-phone-region',
            ),
          ),
        );

        final masked = maskPhoneNumber('+491701234567');
        expect(masked, '+49 ••• •• 567');
        expect(masked, isNot(contains('1701234')));
      },
    );

    test('maps Firebase errors to safe German messages', () {
      expect(
        mfaErrorMessage(
          FirebaseAuthException(
            code: 'invalid-verification-code',
            message: 'raw provider detail',
          ),
        ),
        'Der eingegebene SMS-Code ist falsch.',
      );
      expect(
        mfaErrorMessage(
          FirebaseAuthException(
            code: 'unexpected-provider-error',
            message: 'raw provider detail',
          ),
        ),
        'Der Zwei-Faktor-Vorgang konnte gerade nicht abgeschlossen werden.',
      );
    });
  });

  testWidgets('unverified email blocks MFA enrollment', (tester) async {
    final accountGateway = _FakeAccountGateway(_unverifiedAccount);
    final mfaGateway = _FakeMfaGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: MfaManagementScreen(
          initialAccount: _unverifiedAccount,
          accountGateway: accountGateway,
          mfaGateway: mfaGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Bestätige zuerst deine E-Mail Adresse'),
      findsOneWidget,
    );
    expect(find.text('Zwei-Faktor-Schutz aktivieren'), findsNothing);
    expect(find.text('E-Mail erneut senden'), findsOneWidget);
  });

  testWidgets('verified user starts enrollment only after explicit consent', (
    tester,
  ) async {
    final gateway = _FakeMfaGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: MfaEnrollmentScreen(
          account: _verifiedAccount,
          mfaGateway: gateway,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '+49 170 1234567');
    await tester.enterText(find.byType(TextField).at(1), 'sicheres-passwort');
    await tester.ensureVisible(find.text('SMS-Code anfordern'));
    await tester.tap(find.text('SMS-Code anfordern'));
    await tester.pump();

    expect(gateway.reauthenticateCalls, 0);
    expect(gateway.enrollmentCodeRequests, 0);
    expect(
      find.textContaining('Bestätige zuerst die Datenschutzhinweise'),
      findsOneWidget,
    );

    await tester.tap(find.textContaining('Ich stimme zu'));
    await tester.tap(find.text('SMS-Code anfordern'));
    await tester.tap(find.text('SMS-Code anfordern'));
    await tester.pumpAndSettle();

    expect(gateway.reauthenticateCalls, 1);
    expect(gateway.enrollmentCodeRequests, 1);
    expect(find.text('SMS-Code bestätigen'), findsOneWidget);
    expect(find.textContaining('+49 ••• •• 567'), findsOneWidget);
  });

  testWidgets('password fields can be shown and hidden', (tester) async {
    final gateway = _FakeMfaGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: MfaEnrollmentScreen(
          account: _verifiedAccount,
          mfaGateway: gateway,
        ),
      ),
    );

    var passwordField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(passwordField.obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    passwordField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(passwordField.obscureText, isFalse);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    passwordField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(passwordField.obscureText, isTrue);
  });

  testWidgets('registered factors stay masked and last removal warns user', (
    tester,
  ) async {
    final factor = MfaFactorSnapshot(
      uid: 'factor-1',
      displayName: 'Mobiltelefon',
      maskedPhoneNumber: maskPhoneNumber('+491701234567'),
    );
    final mfaGateway = _FakeMfaGateway(factors: [factor]);

    await tester.pumpWidget(
      MaterialApp(
        home: MfaManagementScreen(
          initialAccount: _verifiedAccount,
          accountGateway: _FakeAccountGateway(_verifiedAccount),
          mfaGateway: mfaGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+49 ••• •• 567'), findsOneWidget);
    expect(find.textContaining('+491701234567'), findsNothing);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Letzten Faktor entfernen?'), findsOneWidget);
    expect(
      find.textContaining('nicht mehr durch einen zweiten Faktor geschützt'),
      findsOneWidget,
    );
  });

  testWidgets('password reauthentication removes the selected factor', (
    tester,
  ) async {
    final factor = MfaFactorSnapshot(
      uid: 'factor-1',
      displayName: 'Mobiltelefon',
      maskedPhoneNumber: maskPhoneNumber('+491701234567'),
    );
    final mfaGateway = _FakeMfaGateway(factors: [factor]);

    await tester.pumpWidget(
      MaterialApp(
        home: MfaManagementScreen(
          initialAccount: _verifiedAccount,
          accountGateway: _FakeAccountGateway(_verifiedAccount),
          mfaGateway: mfaGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entfernen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sicheres-passwort');
    await tester.tap(find.text('Bestätigen'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(mfaGateway.reauthenticateCalls, 1);
    expect(mfaGateway.removedFactorUids, ['factor-1']);
    expect(find.text('+49 ••• •• 567'), findsNothing);
    expect(find.text('Nicht eingerichtet'), findsOneWidget);
    expect(
      find.text('Der Zwei-Faktor-Schutz wurde deaktiviert.'),
      findsOneWidget,
    );
  });

  testWidgets('sign-in challenge preselects one factor and sends SMS once', (
    tester,
  ) async {
    final gateway = _FakeMfaGateway();
    final challenge = MfaSignInChallenge.forTesting(
      factors: [
        MfaFactorSnapshot(
          uid: 'factor-1',
          displayName: 'Privates Mobiltelefon',
          maskedPhoneNumber: maskPhoneNumber('+491701234567'),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MfaSignInChallengeScreen(
          challenge: challenge,
          mfaGateway: gateway,
        ),
      ),
    );

    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    expect(find.text('+49 ••• •• 567'), findsOneWidget);
    expect(find.textContaining('+491701234567'), findsNothing);

    await tester.tap(find.text('SMS-Code senden'));
    await tester.tap(find.text('SMS-Code senden'));
    await tester.pumpAndSettle();

    expect(gateway.signInCodeRequests, 1);
    expect(gateway.requestedFactorUids, ['factor-1']);
    expect(find.textContaining('Erneut senden in'), findsOneWidget);
  });

  testWidgets('removal challenge uses explicit removal actions', (
    tester,
  ) async {
    final gateway = _FakeMfaGateway();
    final challenge = MfaSignInChallenge.forTesting(
      factors: [
        MfaFactorSnapshot(
          uid: 'factor-1',
          displayName: 'Mobiltelefon',
          maskedPhoneNumber: maskPhoneNumber('+491701234567'),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MfaSignInChallengeScreen(
          challenge: challenge,
          mfaGateway: gateway,
          title: 'Entfernen bestätigen',
          description:
              'Tippe auf „SMS-Code zum Entfernen senden“ und bestätige den Code.',
          sendCodeLabel: 'SMS-Code zum Entfernen senden',
          confirmCodeLabel: 'Telefonnummer entfernen',
        ),
      ),
    );

    expect(find.text('SMS-Code zum Entfernen senden'), findsOneWidget);
    await tester.tap(find.text('SMS-Code zum Entfernen senden'));
    await tester.pumpAndSettle();
    expect(find.text('Telefonnummer entfernen'), findsOneWidget);
    expect(find.text('Sicher anmelden'), findsNothing);
  });

  testWidgets('sign-in challenge lets the user choose among phone factors', (
    tester,
  ) async {
    final gateway = _FakeMfaGateway();
    final challenge = MfaSignInChallenge.forTesting(
      factors: [
        MfaFactorSnapshot(
          uid: 'factor-1',
          displayName: 'Privat',
          maskedPhoneNumber: maskPhoneNumber('+491701234567'),
        ),
        MfaFactorSnapshot(
          uid: 'factor-2',
          displayName: 'Geschäftlich',
          maskedPhoneNumber: maskPhoneNumber('+436601234567'),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MfaSignInChallengeScreen(
          challenge: challenge,
          mfaGateway: gateway,
        ),
      ),
    );

    await tester.tap(find.text('Geschäftlich'));
    await tester.tap(find.text('SMS-Code senden'));
    await tester.pumpAndSettle();

    expect(gateway.requestedFactorUids, ['factor-2']);
  });

  testWidgets('wrong sign-in code shows a safe German error', (tester) async {
    final gateway = _FakeMfaGateway(
      signInErrorCode: 'invalid-verification-code',
    );
    final challenge = MfaSignInChallenge.forTesting(
      factors: [
        MfaFactorSnapshot(
          uid: 'factor-1',
          displayName: 'Mobiltelefon',
          maskedPhoneNumber: maskPhoneNumber('+491701234567'),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MfaSignInChallengeScreen(
          challenge: challenge,
          mfaGateway: gateway,
        ),
      ),
    );
    await tester.tap(find.text('SMS-Code senden'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Sicher anmelden'));
    await tester.pumpAndSettle();

    expect(find.text('Der eingegebene SMS-Code ist falsch.'), findsOneWidget);
    expect(gateway.confirmSignInCalls, 1);
  });

  testWidgets('system back aborts the challenge without a credential', (
    tester,
  ) async {
    Object? routeResult = 'pending';
    final challenge = MfaSignInChallenge.forTesting(
      factors: [
        MfaFactorSnapshot(
          uid: 'factor-1',
          displayName: 'Mobiltelefon',
          maskedPhoneNumber: maskPhoneNumber('+491701234567'),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              routeResult = await Navigator.of(context).push<UserCredential>(
                MaterialPageRoute<UserCredential>(
                  builder: (_) => MfaSignInChallengeScreen(
                    challenge: challenge,
                    mfaGateway: _FakeMfaGateway(),
                  ),
                ),
              );
            },
            child: const Text('Challenge öffnen'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Challenge öffnen'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(routeResult, isNull);
  });

  testWidgets('challenge recovery explains the safe authenticated path', (
    tester,
  ) async {
    final challenge = MfaSignInChallenge.forTesting(
      factors: [
        MfaFactorSnapshot(
          uid: 'factor-1',
          displayName: 'Mobiltelefon',
          maskedPhoneNumber: maskPhoneNumber('+491701234567'),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MfaSignInChallengeScreen(
          challenge: challenge,
          mfaGateway: _FakeMfaGateway(),
        ),
      ),
    );

    await tester.tap(find.text('Kein Zugriff auf dieses Mobiltelefon?'));
    await tester.pumpAndSettle();

    expect(find.text('Zugriff wiederherstellen'), findsOneWidget);
    expect(find.textContaining('MFA bleibt aktiv'), findsOneWidget);
    expect(find.textContaining('Passwort oder SMS-Code'), findsOneWidget);
    expect(find.textContaining('+491701234567'), findsNothing);
  });

  testWidgets('authenticated recovery request shows pending review', (
    tester,
  ) async {
    final gateway = _FakeMfaGateway();
    await tester.pumpWidget(
      MaterialApp(home: MfaRecoveryScreen(mfaGateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keine offene Anfrage'), findsOneWidget);
    await tester.tap(find.text('Sicherheitsprüfung anfordern'));
    await tester.pumpAndSettle();

    expect(gateway.recoveryRequests, 1);
    expect(find.text('Prüfung läuft'), findsOneWidget);
    expect(find.text('Sicherheitsprüfung anfordern'), findsNothing);
  });
}

const AuthAccountSnapshot _verifiedAccount = AuthAccountSnapshot(
  userId: 'user-1',
  email: 'konto@example.com',
  isEmailVerified: true,
  providers: {AuthLoginProvider.password},
);

const AuthAccountSnapshot _unverifiedAccount = AuthAccountSnapshot(
  userId: 'user-1',
  email: 'konto@example.com',
  isEmailVerified: false,
  providers: {AuthLoginProvider.password},
);

class _FakeAccountGateway implements AccountAuthGateway {
  _FakeAccountGateway(this.account);

  AuthAccountSnapshot account;

  @override
  Future<void> deleteCurrentUser({String? currentPassword}) async {}

  @override
  Future<void> linkCurrentUserWithApple() async {}

  @override
  Future<AuthAccountSnapshot?> loadCurrentAccount() async => account;

  @override
  Future<void> requestCurrentUserEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {}

  @override
  Future<void> revokeAllSessions({String? currentPassword}) async {}

  @override
  Future<void> sendCurrentUserEmailVerification() async {}

  @override
  Future<void> sendCurrentUserPasswordReset({
    required String enteredEmail,
  }) async {}
}

class _FakeMfaGateway implements MfaGateway {
  _FakeMfaGateway({
    List<MfaFactorSnapshot> factors = const [],
    this.signInErrorCode,
  }) : _factors = List.of(factors);

  final List<MfaFactorSnapshot> _factors;
  final String? signInErrorCode;
  int reauthenticateCalls = 0;
  int enrollmentCodeRequests = 0;
  int signInCodeRequests = 0;
  int confirmSignInCalls = 0;
  int recoveryRequests = 0;
  final List<String> removedFactorUids = [];
  MfaRecoverySnapshot recovery = const MfaRecoverySnapshot(
    status: MfaRecoveryStatus.none,
  );
  final List<String> requestedFactorUids = [];

  @override
  MfaSignInChallenge challengeFromException(
    FirebaseAuthMultiFactorException exception,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> confirmEnrollment({
    required String verificationId,
    required String smsCode,
    String displayName = 'Mobiltelefon',
  }) async {
    if (smsCode != '123456') {
      throw FirebaseAuthException(code: 'invalid-verification-code');
    }
  }

  @override
  Future<UserCredential> confirmSignIn({
    required MfaSignInChallenge challenge,
    required String verificationId,
    required String smsCode,
  }) async {
    confirmSignInCalls += 1;
    throw FirebaseAuthException(
      code: signInErrorCode ?? 'invalid-verification-code',
    );
  }

  @override
  Future<MfaStatusSnapshot> loadStatus() async {
    return MfaStatusSnapshot(factors: List.unmodifiable(_factors));
  }

  @override
  Future<MfaRecoverySnapshot> loadRecoveryStatus() async => recovery;

  @override
  Future<void> reauthenticate({String? currentPassword}) async {
    reauthenticateCalls += 1;
    if (currentPassword != 'sicheres-passwort') {
      throw FirebaseAuthException(code: 'wrong-password');
    }
  }

  @override
  Future<void> removeFactor(String factorUid) async {
    removedFactorUids.add(factorUid);
    _factors.removeWhere((factor) => factor.uid == factorUid);
  }

  @override
  Future<void> requestEnrollmentCode({
    required String phoneNumber,
    required MfaCodeSent onCodeSent,
    required MfaVerificationFailed onVerificationFailed,
    required MfaEnrollmentCompleted onAutoVerified,
    int? forceResendingToken,
  }) async {
    enrollmentCodeRequests += 1;
    onCodeSent(
      const MfaCodeDispatch(verificationId: 'verification-1', resendToken: 7),
    );
  }

  @override
  Future<MfaRecoverySnapshot> requestRecovery() async {
    recoveryRequests += 1;
    recovery = const MfaRecoverySnapshot(
      status: MfaRecoveryStatus.pending,
      requestId: 'recovery-1',
    );
    return recovery;
  }

  @override
  Future<void> requestSignInCode({
    required MfaSignInChallenge challenge,
    required String factorUid,
    required MfaCodeSent onCodeSent,
    required MfaVerificationFailed onVerificationFailed,
    required MfaSignInCompleted onAutoVerified,
    int? forceResendingToken,
  }) async {
    signInCodeRequests += 1;
    requestedFactorUids.add(factorUid);
    onCodeSent(
      const MfaCodeDispatch(
        verificationId: 'sign-in-verification-1',
        resendToken: 11,
      ),
    );
  }
}
