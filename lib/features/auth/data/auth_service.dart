import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
    await _firebaseAuth.setLanguageCode('de');
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendEmailVerification(User user) async {
    await _firebaseAuth.setLanguageCode('de');
    await user.sendEmailVerification();
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
    await _firebaseAuth.setLanguageCode('de');
    await user.verifyBeforeUpdateEmail(normalizedNewEmail);
  }

  @override
  Future<void> deleteCurrentUser({String? currentPassword}) async {
    final user = await _reauthenticateCurrentUser(
      currentPassword: currentPassword,
    );
    await user.getIdToken(true);

    try {
      await _firebaseFunctions.httpsCallable('requestAccountDeletion').call({
        'platform': _securityPlatformCode(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw _authExceptionFromFunctions(error);
    }

    await _signOutBestEffort();
  }

  @override
  Future<void> revokeAllSessions({String? currentPassword}) async {
    final user = await _reauthenticateCurrentUser(
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

  Future<User> _reauthenticateCurrentUser({String? currentPassword}) async {
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

    if (account.isAppleOnly) {
      throw FirebaseAuthException(code: 'apple-reauth-not-configured');
    }
    throw FirebaseAuthException(code: 'reauth-provider-not-supported');
  }

  Future<void> _signOutBestEffort() async {
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
      _ when error.code == 'unauthenticated' => 'missing-user',
      _ when error.code == 'failed-precondition' => 'requires-recent-login',
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

  Future<void> signInWithApple() async {
    throw FirebaseAuthException(
      code: 'apple-not-configured',
      message:
          'Apple Login wird vorbereitet und später mit dem iOS-Setup aktiviert.',
    );
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  static bool _emailsMatch(String first, String second) {
    return first.trim().toLowerCase() == second.trim().toLowerCase();
  }

  static bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }
}
