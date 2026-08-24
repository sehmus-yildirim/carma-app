import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/auth/data/auth_service.dart';

void main() {
  group('Apple profile data', () {
    test('uses the name only for a new account', () {
      expect(
        appleDisplayNameToApply(
          isNewUser: true,
          existingDisplayName: null,
          profile: const {'firstName': 'Plaqa', 'lastName': 'Nutzer'},
        ),
        'Plaqa Nutzer',
      );
      expect(
        appleDisplayNameToApply(
          isNewUser: false,
          existingDisplayName: null,
          profile: const {'name': 'Späterer Name'},
        ),
        isNull,
      );
    });

    test('never overwrites an existing display name', () {
      expect(
        appleDisplayNameToApply(
          isNewUser: true,
          existingDisplayName: 'Bestehender Name',
          profile: const {'name': 'Apple Name'},
        ),
        isNull,
      );
    });

    test('accepts an Apple private relay address unchanged', () {
      const snapshot = AuthAccountSnapshot(
        email: 'privat@privaterelay.appleid.com',
        isEmailVerified: true,
        providers: {AuthLoginProvider.apple},
      );

      expect(snapshot.email, 'privat@privaterelay.appleid.com');
      expect(snapshot.hasAppleProvider, isTrue);
      expect(snapshot.isAppleOnly, isTrue);
    });
  });

  group('Apple account deletion', () {
    test('revokes the Apple token exactly once before deletion', () async {
      final events = <String>[];

      await executeAppleAwareAccountDeletion(
        hasAppleProvider: true,
        appleAuthorizationCode: 'temporary-code',
        revokeAppleToken: (code) async {
          expect(code, 'temporary-code');
          events.add('revoke');
        },
        requestAccountDeletion: () async => events.add('delete'),
      );

      expect(events, ['revoke', 'delete']);
    });

    test('a revocation failure prevents the deletion request', () async {
      var deletionRequested = false;

      await expectLater(
        executeAppleAwareAccountDeletion(
          hasAppleProvider: true,
          appleAuthorizationCode: 'temporary-code',
          revokeAppleToken: (_) async {
            throw FirebaseAuthException(code: 'apple-token-revocation-failed');
          },
          requestAccountDeletion: () async => deletionRequested = true,
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'apple-token-revocation-failed',
          ),
        ),
      );

      expect(deletionRequested, isFalse);
    });

    test('missing authorization code prevents deletion', () async {
      var revocationRequested = false;
      var deletionRequested = false;

      await expectLater(
        executeAppleAwareAccountDeletion(
          hasAppleProvider: true,
          appleAuthorizationCode: null,
          revokeAppleToken: (_) async => revocationRequested = true,
          requestAccountDeletion: () async => deletionRequested = true,
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'apple-authorization-code-missing',
          ),
        ),
      );

      expect(revocationRequested, isFalse);
      expect(deletionRequested, isFalse);
    });

    test('non-Apple deletion remains unchanged', () async {
      var revocationCalls = 0;
      var deletionCalls = 0;

      await executeAppleAwareAccountDeletion(
        hasAppleProvider: false,
        appleAuthorizationCode: null,
        revokeAppleToken: (_) async => revocationCalls += 1,
        requestAccountDeletion: () async => deletionCalls += 1,
      );

      expect(revocationCalls, 0);
      expect(deletionCalls, 1);
    });
  });

  test('normalizes Apple cancellation without exposing provider details', () {
    final normalized = normalizeAppleAuthException(
      FirebaseAuthException(
        code: 'web-context-canceled',
        message: 'raw provider detail',
      ),
    );

    expect(normalized.code, 'aborted-by-user');
    expect(normalized.message, isNull);
  });
}
