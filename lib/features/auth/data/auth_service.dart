import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../shared/firebase/firebase_emulator_configuration.dart';
import '../../../shared/notifications/push_notification_service.dart';

enum AuthLoginProvider { password, google, apple, unknown }

class AuthAccountSnapshot {
  const AuthAccountSnapshot({
    this.userId = '',
    required this.email,
    required this.isEmailVerified,
    required this.providers,
    this.creationTime,
    this.lastSignInTime,
  });

  factory AuthAccountSnapshot.fromUser(User user) {
    return AuthAccountSnapshot(
      userId: user.uid,
      email: user.email?.trim() ?? '',
      isEmailVerified: user.emailVerified,
      providers: user.providerData
          .map((provider) => provider.providerId)
          .map(AuthAccountSnapshot.providerFromId)
          .toSet(),
      creationTime: user.metadata.creationTime,
      lastSignInTime: user.metadata.lastSignInTime,
    );
  }

  final String userId;
  final String email;
  final bool isEmailVerified;
  final Set<AuthLoginProvider> providers;
  final DateTime? creationTime;
  final DateTime? lastSignInTime;

  bool get hasPasswordProvider =>
      providers.contains(AuthLoginProvider.password);

  bool get isGoogleOnly =>
      providers.contains(AuthLoginProvider.google) && !hasPasswordProvider;

  bool get isAppleOnly =>
      providers.contains(AuthLoginProvider.apple) && !hasPasswordProvider;

  bool get hasAppleProvider => providers.contains(AuthLoginProvider.apple);

  String get providerLabel {
    final labels = <String>[
      if (providers.contains(AuthLoginProvider.password)) 'E-Mail',
      if (providers.contains(AuthLoginProvider.google)) 'Google',
      if (providers.contains(AuthLoginProvider.apple)) 'Apple',
    ];

    if (labels.isEmpty) {
      return 'Nicht verfügbar';
    }

    return labels.join(' und ');
  }

  static AuthLoginProvider providerFromId(String providerId) {
    return switch (providerId) {
      'password' => AuthLoginProvider.password,
      'google.com' => AuthLoginProvider.google,
      'apple.com' => AuthLoginProvider.apple,
      _ => AuthLoginProvider.unknown,
    };
  }
}

abstract interface class AccountAuthGateway {
  Future<AuthAccountSnapshot?> loadCurrentAccount();

  Future<void> sendCurrentUserEmailVerification();

  Future<void> sendCurrentUserPasswordReset({required String enteredEmail});

  Future<void> requestCurrentUserEmailChange({
    required String currentPassword,
    required String newEmail,
  });

  Future<void> linkCurrentUserWithApple();

  Future<void> deleteCurrentUser({String? currentPassword});

  Future<void> revokeAllSessions({String? currentPassword});
}

class AuthService implements AccountAuthGateway {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFunctions? firebaseFunctions,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(),
       _firebaseFunctions =
           firebaseFunctions ??
           FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFunctions _firebaseFunctions;

  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<AuthAccountSnapshot?> loadCurrentAccount() async {
    final user = await reloadCurrentUser();
    return user == null ? null : AuthAccountSnapshot.fromUser(user);
  }

  Future<User?> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }

    await user.reload();
    return _firebaseAuth.currentUser;
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    if (kPlaqaUseFirebaseEmulators) {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      return;
    }

    try {
      await _firebaseFunctions
          .httpsCallable('sendBrandedPasswordResetEmail')
          .call({'email': email.trim()});
    } on FirebaseFunctionsException catch (error) {
      throw _authExceptionFromFunctions(error);
    }
  }

  Future<void> sendEmailVerification(User user) async {
    if (_firebaseAuth.currentUser?.uid != user.uid) {
      throw FirebaseAuthException(code: 'missing-user');
    }
    await user.getIdToken(true);

    if (kPlaqaUseFirebaseEmulators) {
      await user.sendEmailVerification();
      return;
    }

    try {
      await _firebaseFunctions
          .httpsCallable('sendBrandedEmailVerification')
          .call();
    } on FirebaseFunctionsException catch (error) {
      throw _authExceptionFromFunctions(error);
    }
  }

  @override
  Future<void> sendCurrentUserEmailVerification() async {
    final user = await reloadCurrentUser();
    if (user == null) {
      throw FirebaseAuthException(code: 'missing-user');
    }
    if (user.emailVerified) {
      return;
    }

    await sendEmailVerification(user);
  }

  @override
  Future<void> sendCurrentUserPasswordReset({
    required String enteredEmail,
  }) async {
    final snapshot = await loadCurrentAccount();
    if (snapshot == null || snapshot.email.isEmpty) {
      throw FirebaseAuthException(code: 'missing-email');
    }
    if (!snapshot.hasPasswordProvider) {
      throw FirebaseAuthException(code: 'password-managed-by-provider');
    }
    if (!snapshot.isEmailVerified) {
      throw FirebaseAuthException(code: 'email-not-verified');
    }
    if (!_emailsMatch(snapshot.email, enteredEmail)) {
      throw FirebaseAuthException(code: 'email-mismatch');
    }

    await sendPasswordResetEmail(email: snapshot.email);
  }

  @override
  Future<void> requestCurrentUserEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = await reloadCurrentUser();
    final currentEmail = user?.email?.trim() ?? '';
    if (user == null || currentEmail.isEmpty) {
      throw FirebaseAuthException(code: 'missing-email');
    }

    final snapshot = AuthAccountSnapshot.fromUser(user);
    if (!snapshot.hasPasswordProvider) {
      throw FirebaseAuthException(code: 'email-managed-by-provider');
    }

    final normalizedNewEmail = newEmail.trim();
    if (!_isValidEmail(normalizedNewEmail)) {
      throw FirebaseAuthException(code: 'invalid-email');
    }
    if (_emailsMatch(currentEmail, normalizedNewEmail)) {
      throw FirebaseAuthException(code: 'email-unchanged');
    }
    if (currentPassword.isEmpty) {
      throw FirebaseAuthException(code: 'missing-password');
    }

    final credential = EmailAuthProvider.credential(
      email: currentEmail,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.getIdToken(true);
    try {
      await _firebaseFunctions
          .httpsCallable('sendBrandedEmailChangeVerification')
          .call({'newEmail': normalizedNewEmail});
    } on FirebaseFunctionsException catch (error) {
      throw _authExceptionFromFunctions(error);
    }
  }

  @override
  Future<void> deleteCurrentUser({String? currentPassword}) async {
    final currentUser = await reloadCurrentUser();
    if (currentUser == null) {
      throw FirebaseAuthException(code: 'missing-user');
    }

    final account = AuthAccountSnapshot.fromUser(currentUser);
    late final User user;
    String? appleAuthorizationCode;

    if (account.hasAppleProvider) {
      final credential = await _reauthenticateWithApple(currentUser);
      user = credential.user ?? currentUser;
      appleAuthorizationCode = credential.additionalUserInfo?.authorizationCode
          ?.trim();
    } else {
      user = await reauthenticateCurrentUser(currentPassword: currentPassword);
    }
    await user.getIdToken(true);

    await executeAppleAwareAccountDeletion(
      hasAppleProvider: account.hasAppleProvider,
      appleAuthorizationCode: appleAuthorizationCode,
      revokeAppleToken: _revokeAppleToken,
      requestAccountDeletion: () async {
        try {
          await _firebaseFunctions.httpsCallable('requestAccountDeletion').call(
            {'platform': _securityPlatformCode()},
          );
        } on FirebaseFunctionsException catch (error) {
          throw _authExceptionFromFunctions(error);
        }
      },
    );

    await _signOutBestEffort();
  }

  @override
  Future<void> revokeAllSessions({String? currentPassword}) async {
    final user = await reauthenticateCurrentUser(
      currentPassword: currentPassword,
    );
    await user.getIdToken(true);

    try {
      await _firebaseFunctions.httpsCallable('revokeAccountSessions').call({
        'platform': _securityPlatformCode(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw _authExceptionFromFunctions(error);
    }

    await _signOutBestEffort();
  }

  Future<User> reauthenticateCurrentUser({String? currentPassword}) async {
    final user = await reloadCurrentUser();
    if (user == null) {
      throw FirebaseAuthException(code: 'missing-user');
    }

    final account = AuthAccountSnapshot.fromUser(user);
    if (account.hasPasswordProvider) {
      final password = currentPassword ?? '';
      final email = user.email?.trim() ?? '';
      if (email.isEmpty) {
        throw FirebaseAuthException(code: 'missing-email');
      }
      if (password.isEmpty) {
        throw FirebaseAuthException(code: 'missing-password');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      return user;
    }

    if (account.isGoogleOnly) {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(code: 'aborted-by-user');
      }
      final googleAuth = await googleUser.authentication;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
      return user;
    }

    if (account.hasAppleProvider) {
      await _reauthenticateWithApple(user);
      return user;
    }
    throw FirebaseAuthException(code: 'reauth-provider-not-supported');
  }

  Future<void> _signOutBestEffort() async {
    try {
      await PushNotificationService.instance.removeCurrentToken();
    } catch (_) {
      // A failed token cleanup must not keep the user signed in.
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Provider cleanup is best effort after the server-side action.
    }
    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // A deleted or revoked account may already have invalidated local auth.
    }
  }

  FirebaseAuthException _authExceptionFromFunctions(
    FirebaseFunctionsException error,
  ) {
    final details = error.details;
    final reason = details is Map ? details['reason'] as String? : null;
    final code = switch (reason) {
      'requires-recent-login' => 'requires-recent-login',
      'invalid-email' => 'invalid-email',
      'missing-email' => 'missing-email',
      'email-unchanged' => 'email-unchanged',
      'email-already-in-use' => 'email-already-in-use',
      'too-many-requests' => 'too-many-requests',
      _ when error.code == 'unauthenticated' => 'missing-user',
      _ when error.code == 'failed-precondition' => 'requires-recent-login',
      _ when error.code == 'invalid-argument' => 'invalid-email',
      _ when error.code == 'already-exists' => 'email-already-in-use',
      _ when error.code == 'resource-exhausted' => 'too-many-requests',
      _ => 'server-account-action-failed',
    };
    return FirebaseAuthException(code: code);
  }

  String _securityPlatformCode() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'unknown',
    };
  }

  Future<UserCredential> signInWithGoogle() async {
    await _googleSignIn.signOut();

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'aborted-by-user',
        message: 'Die Google-Anmeldung wurde abgebrochen.',
      );
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _firebaseAuth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithApple() async {
    try {
      final credential = await _firebaseAuth.signInWithProvider(
        _createAppleProvider(),
      );
      await _applyAppleDisplayName(credential);
      return credential;
    } on FirebaseAuthException catch (error) {
      throw normalizeAppleAuthException(error);
    }
  }

  @override
  Future<void> linkCurrentUserWithApple() async {
    final user = await reloadCurrentUser();
    if (user == null) {
      throw FirebaseAuthException(code: 'missing-user');
    }

    final account = AuthAccountSnapshot.fromUser(user);
    if (account.hasAppleProvider) {
      throw FirebaseAuthException(code: 'provider-already-linked');
    }

    try {
      final credential = await user.linkWithProvider(_createAppleProvider());
      await _applyAppleDisplayName(credential);
    } on FirebaseAuthException catch (error) {
      throw normalizeAppleAuthException(error);
    }
  }

  AppleAuthProvider _createAppleProvider() {
    return AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
  }

  Future<UserCredential> _reauthenticateWithApple(User user) async {
    try {
      return await user.reauthenticateWithProvider(_createAppleProvider());
    } on FirebaseAuthException catch (error) {
      throw normalizeAppleAuthException(error);
    }
  }

  Future<void> _revokeAppleToken(String authorizationCode) async {
    try {
      await _firebaseAuth.revokeTokenWithAuthorizationCode(authorizationCode);
    } on FirebaseAuthException catch (error) {
      final normalized = normalizeAppleAuthException(error);
      if (normalized.code == 'aborted-by-user') {
        throw normalized;
      }
      throw FirebaseAuthException(code: 'apple-token-revocation-failed');
    } catch (_) {
      throw FirebaseAuthException(code: 'apple-token-revocation-failed');
    }
  }

  Future<void> _applyAppleDisplayName(UserCredential credential) async {
    final user = credential.user;
    if (user == null) {
      return;
    }

    final displayName = appleDisplayNameToApply(
      isNewUser: credential.additionalUserInfo?.isNewUser ?? false,
      existingDisplayName: user.displayName,
      profile: credential.additionalUserInfo?.profile,
    );
    if (displayName != null) {
      await user.updateDisplayName(displayName);
    }
  }

  Future<void> signOut() async {
    await _signOutBestEffort();
  }

  static bool _emailsMatch(String first, String second) {
    return first.trim().toLowerCase() == second.trim().toLowerCase();
  }

  static bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }
}

@visibleForTesting
String? appleDisplayNameToApply({
  required bool isNewUser,
  required String? existingDisplayName,
  required Map<String, dynamic>? profile,
}) {
  if (!isNewUser || (existingDisplayName?.trim().isNotEmpty ?? false)) {
    return null;
  }

  String value(String key) => (profile?[key] as String?)?.trim() ?? '';

  final directNames = [
    value('name'),
    value('displayName'),
  ].where((entry) => entry.isNotEmpty);
  if (directNames.isNotEmpty) {
    return directNames.first;
  }

  final givenNames = [
    value('given_name'),
    value('firstName'),
    value('first_name'),
  ].where((entry) => entry.isNotEmpty);
  final familyNames = [
    value('family_name'),
    value('lastName'),
    value('last_name'),
  ].where((entry) => entry.isNotEmpty);
  final givenName = givenNames.isEmpty ? '' : givenNames.first;
  final familyName = familyNames.isEmpty ? '' : familyNames.first;
  final combined = [
    givenName,
    familyName,
  ].where((entry) => entry.isNotEmpty).join(' ').trim();
  return combined.isEmpty ? null : combined;
}

@visibleForTesting
Future<void> executeAppleAwareAccountDeletion({
  required bool hasAppleProvider,
  required String? appleAuthorizationCode,
  required Future<void> Function(String authorizationCode) revokeAppleToken,
  required Future<void> Function() requestAccountDeletion,
}) async {
  if (hasAppleProvider) {
    final authorizationCode = appleAuthorizationCode?.trim() ?? '';
    if (authorizationCode.isEmpty) {
      throw FirebaseAuthException(code: 'apple-authorization-code-missing');
    }
    await revokeAppleToken(authorizationCode);
  }

  await requestAccountDeletion();
}

@visibleForTesting
FirebaseAuthException normalizeAppleAuthException(FirebaseAuthException error) {
  const cancellationCodes = {
    'aborted-by-user',
    'canceled',
    'cancelled',
    'web-context-canceled',
    'popup-closed-by-user',
  };
  if (cancellationCodes.contains(error.code)) {
    return FirebaseAuthException(code: 'aborted-by-user');
  }
  return error;
}
