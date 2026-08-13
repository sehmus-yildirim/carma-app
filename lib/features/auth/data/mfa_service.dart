import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

class MfaFactorSnapshot {
  const MfaFactorSnapshot({
    required this.uid,
    required this.displayName,
    required this.maskedPhoneNumber,
    this.enrolledAt,
  });

  final String uid;
  final String displayName;
  final String maskedPhoneNumber;
  final DateTime? enrolledAt;
}

class MfaStatusSnapshot {
  const MfaStatusSnapshot({required this.factors});

  final List<MfaFactorSnapshot> factors;

  bool get isEnabled => factors.isNotEmpty;
}

class MfaCodeDispatch {
  const MfaCodeDispatch({required this.verificationId, this.resendToken});

  final String verificationId;
  final int? resendToken;
}

enum MfaRecoveryStatus { none, pending, approved, rejected, completed }

class MfaRecoverySnapshot {
  const MfaRecoverySnapshot({
    required this.status,
    this.requestId = '',
    this.requestedAt,
    this.updatedAt,
  });

  final MfaRecoveryStatus status;
  final String requestId;
  final DateTime? requestedAt;
  final DateTime? updatedAt;

  bool get hasActiveReview =>
      status == MfaRecoveryStatus.pending ||
      status == MfaRecoveryStatus.approved;
}

class MfaSignInChallenge {
  MfaSignInChallenge._({
    required MultiFactorResolver resolver,
    required Map<String, PhoneMultiFactorInfo> phoneFactors,
  }) : _resolver = resolver,
       _phoneFactors = phoneFactors,
       factors = List.unmodifiable(
         phoneFactors.values.map(_factorSnapshotFromInfo),
       );

  MfaSignInChallenge.forTesting({required List<MfaFactorSnapshot> factors})
    : assert(factors.isNotEmpty),
      _resolver = null,
      _phoneFactors = const {},
      factors = List.unmodifiable(factors);

  final MultiFactorResolver? _resolver;
  final Map<String, PhoneMultiFactorInfo> _phoneFactors;
  final List<MfaFactorSnapshot> factors;
}

typedef MfaCodeSent = void Function(MfaCodeDispatch dispatch);
typedef MfaVerificationFailed = void Function(FirebaseAuthException error);
typedef MfaEnrollmentCompleted = void Function();
typedef MfaSignInCompleted = void Function(UserCredential credential);

abstract interface class MfaGateway {
  MfaSignInChallenge challengeFromException(
    FirebaseAuthMultiFactorException exception,
  );

  Future<MfaStatusSnapshot> loadStatus();

  Future<MfaRecoverySnapshot> loadRecoveryStatus();

  Future<MfaRecoverySnapshot> requestRecovery();

  Future<void> reauthenticate({String? currentPassword});

  Future<void> requestEnrollmentCode({
    required String phoneNumber,
    required MfaCodeSent onCodeSent,
    required MfaVerificationFailed onVerificationFailed,
    required MfaEnrollmentCompleted onAutoVerified,
    int? forceResendingToken,
  });

  Future<void> confirmEnrollment({
    required String verificationId,
    required String smsCode,
    String displayName,
  });

  Future<void> removeFactor(String factorUid);

  Future<void> requestSignInCode({
    required MfaSignInChallenge challenge,
    required String factorUid,
    required MfaCodeSent onCodeSent,
    required MfaVerificationFailed onVerificationFailed,
    required MfaSignInCompleted onAutoVerified,
    int? forceResendingToken,
  });

  Future<UserCredential> confirmSignIn({
    required MfaSignInChallenge challenge,
    required String verificationId,
    required String smsCode,
  });
}

class FirebaseMfaService implements MfaGateway {
  FirebaseMfaService({
    FirebaseAuth? firebaseAuth,
    AuthService? authService,
    FirebaseFunctions? firebaseFunctions,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _authService =
           authService ??
           AuthService(firebaseAuth: firebaseAuth ?? FirebaseAuth.instance),
       _firebaseFunctions =
           firebaseFunctions ??
           FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseAuth _firebaseAuth;
  final AuthService _authService;
  final FirebaseFunctions _firebaseFunctions;
  bool _smsRequestInFlight = false;
  bool _completionInFlight = false;

  @override
  MfaSignInChallenge challengeFromException(
    FirebaseAuthMultiFactorException exception,
  ) {
    final phoneFactors = <String, PhoneMultiFactorInfo>{};
    for (final factor in exception.resolver.hints) {
      if (factor is PhoneMultiFactorInfo) {
        phoneFactors[factor.uid] = factor;
      }
    }
    if (phoneFactors.isEmpty) {
      throw FirebaseAuthException(code: 'unsupported-second-factor');
    }
    return MfaSignInChallenge._(
      resolver: exception.resolver,
      phoneFactors: phoneFactors,
    );
  }

  @override
  Future<MfaStatusSnapshot> loadStatus() async {
    final user = _requireCurrentUser();
    final factors = await user.multiFactor.getEnrolledFactors();
    return MfaStatusSnapshot(
      factors: factors
          .whereType<PhoneMultiFactorInfo>()
          .map(_factorSnapshotFromInfo)
          .toList(growable: false),
    );
  }

  @override
  Future<MfaRecoverySnapshot> loadRecoveryStatus() async {
    try {
      final result = await _firebaseFunctions
          .httpsCallable('getMfaRecoveryStatus')
          .call<Map<Object?, Object?>>();
      return _recoverySnapshot(result.data);
    } on FirebaseFunctionsException catch (error) {
      throw _mfaRecoveryException(error);
    }
  }

  @override
  Future<MfaRecoverySnapshot> requestRecovery() async {
    try {
      final result = await _firebaseFunctions
          .httpsCallable('requestMfaRecovery')
          .call<Map<Object?, Object?>>({'platform': _platformCode()});
      return _recoverySnapshot(result.data);
    } on FirebaseFunctionsException catch (error) {
      throw _mfaRecoveryException(error);
    }
  }

  @override
  Future<void> reauthenticate({String? currentPassword}) async {
    await _authService.reauthenticateCurrentUser(
      currentPassword: currentPassword,
    );
  }

  @override
  Future<void> requestEnrollmentCode({
    required String phoneNumber,
    required MfaCodeSent onCodeSent,
    required MfaVerificationFailed onVerificationFailed,
    required MfaEnrollmentCompleted onAutoVerified,
    int? forceResendingToken,
  }) async {
    if (_smsRequestInFlight) {
      throw FirebaseAuthException(code: 'sms-request-in-progress');
    }

    final normalizedPhoneNumber = normalizeDachPhoneNumber(phoneNumber);
    final user = _requireCurrentUser();
    if (!user.emailVerified) {
      throw FirebaseAuthException(code: 'email-not-verified');
    }

    _smsRequestInFlight = true;
    var requestReleased = false;
    void releaseRequest() {
      if (requestReleased) return;
      requestReleased = true;
      _smsRequestInFlight = false;
    }

    try {
      final session = await user.multiFactor.getSession();
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: normalizedPhoneNumber,
        multiFactorSession: session,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (credential) async {
          releaseRequest();
          if (_completionInFlight) return;
          _completionInFlight = true;
          try {
            await user.multiFactor.enroll(
              PhoneMultiFactorGenerator.getAssertion(credential),
              displayName: 'Mobiltelefon',
            );
            onAutoVerified();
          } on FirebaseAuthException catch (error) {
            onVerificationFailed(error);
          } finally {
            _completionInFlight = false;
          }
        },
        verificationFailed: (error) {
          releaseRequest();
          onVerificationFailed(error);
        },
        codeSent: (verificationId, resendToken) {
          releaseRequest();
          onCodeSent(
            MfaCodeDispatch(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) => releaseRequest(),
      );
    } catch (_) {
      releaseRequest();
      rethrow;
    }
  }

  @override
  Future<void> confirmEnrollment({
    required String verificationId,
    required String smsCode,
    String displayName = 'Mobiltelefon',
  }) async {
    if (_completionInFlight) {
      throw FirebaseAuthException(code: 'verification-in-progress');
    }
    final normalizedCode = _normalizeSmsCode(smsCode);
    final user = _requireCurrentUser();
    _completionInFlight = true;
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: normalizedCode,
      );
      await user.multiFactor.enroll(
        PhoneMultiFactorGenerator.getAssertion(credential),
        displayName: displayName,
      );
    } finally {
      _completionInFlight = false;
    }
  }

  @override
  Future<void> removeFactor(String factorUid) async {
    if (factorUid.trim().isEmpty) {
      throw FirebaseAuthException(code: 'missing-multi-factor-info');
    }
    final user = _requireCurrentUser();
    await user.multiFactor.unenroll(factorUid: factorUid);
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
    if (_smsRequestInFlight) {
      throw FirebaseAuthException(code: 'sms-request-in-progress');
    }
    final factor = challenge._phoneFactors[factorUid];
    if (factor == null) {
      throw FirebaseAuthException(code: 'missing-multi-factor-info');
    }

    final resolver = challenge._resolver;
    if (resolver == null) {
      throw FirebaseAuthException(code: 'missing-multi-factor-session');
    }

    _smsRequestInFlight = true;
    var requestReleased = false;
    void releaseRequest() {
      if (requestReleased) return;
      requestReleased = true;
      _smsRequestInFlight = false;
    }

    try {
      await _firebaseAuth.verifyPhoneNumber(
        multiFactorSession: resolver.session,
        multiFactorInfo: factor,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (credential) async {
          releaseRequest();
          if (_completionInFlight) return;
          _completionInFlight = true;
          try {
            final result = await resolver.resolveSignIn(
              PhoneMultiFactorGenerator.getAssertion(credential),
            );
            onAutoVerified(result);
          } on FirebaseAuthException catch (error) {
            onVerificationFailed(error);
          } finally {
            _completionInFlight = false;
          }
        },
        verificationFailed: (error) {
          releaseRequest();
          onVerificationFailed(error);
        },
        codeSent: (verificationId, resendToken) {
          releaseRequest();
          onCodeSent(
            MfaCodeDispatch(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) => releaseRequest(),
      );
    } catch (_) {
      releaseRequest();
      rethrow;
    }
  }

  @override
  Future<UserCredential> confirmSignIn({
    required MfaSignInChallenge challenge,
    required String verificationId,
    required String smsCode,
  }) async {
    if (_completionInFlight) {
      throw FirebaseAuthException(code: 'verification-in-progress');
    }
    final normalizedCode = _normalizeSmsCode(smsCode);
    _completionInFlight = true;
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: normalizedCode,
      );
      final resolver = challenge._resolver;
      if (resolver == null) {
        throw FirebaseAuthException(code: 'missing-multi-factor-session');
      }
      return await resolver.resolveSignIn(
        PhoneMultiFactorGenerator.getAssertion(credential),
      );
    } finally {
      _completionInFlight = false;
    }
  }

  User _requireCurrentUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'missing-user');
    }
    return user;
  }

  String _platformCode() {
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
}

MfaRecoverySnapshot _recoverySnapshot(Map<Object?, Object?> data) {
  final statusValue = data['status']?.toString().trim() ?? 'none';
  final status = MfaRecoveryStatus.values.firstWhere(
    (candidate) => candidate.name == statusValue,
    orElse: () => MfaRecoveryStatus.none,
  );
  return MfaRecoverySnapshot(
    status: status,
    requestId: data['requestId']?.toString().trim() ?? '',
    requestedAt: _dateTimeFromMillis(data['requestedAtMs']),
    updatedAt: _dateTimeFromMillis(data['updatedAtMs']),
  );
}

DateTime? _dateTimeFromMillis(Object? value) {
  final milliseconds = value is num ? value.toInt() : null;
  return milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

FirebaseAuthException _mfaRecoveryException(FirebaseFunctionsException error) {
  final details = error.details;
  final reason = details is Map ? details['reason']?.toString() : null;
  return FirebaseAuthException(code: reason ?? error.code);
}

String normalizeDachPhoneNumber(String value) {
  var normalized = value.trim().replaceAll(RegExp(r'[\s()\-\/]'), '');
  if (normalized.startsWith('00')) {
    normalized = '+${normalized.substring(2)}';
  }
  if (!RegExp(r'^\+\d{8,15}$').hasMatch(normalized)) {
    throw FirebaseAuthException(code: 'invalid-phone-number');
  }

  final isGermany = RegExp(r'^\+49[1-9]\d{6,12}$').hasMatch(normalized);
  final isAustria = RegExp(r'^\+43[1-9]\d{6,11}$').hasMatch(normalized);
  final isSwitzerland = RegExp(r'^\+41[1-9]\d{8}$').hasMatch(normalized);
  if (!isGermany && !isAustria && !isSwitzerland) {
    throw FirebaseAuthException(code: 'unsupported-phone-region');
  }
  return normalized;
}

String maskPhoneNumber(String value) {
  final normalized = value.trim();
  if (normalized.length < 6) return 'Telefonnummer geschützt';
  final prefixLength = normalized.startsWith('+4') ? 3 : 2;
  final prefix = normalized.substring(0, prefixLength);
  final suffix = normalized.substring(normalized.length - 3);
  return '$prefix ••• •• $suffix';
}

String mfaErrorMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'email-not-verified' =>
      'Bestätige zuerst deine E-Mail Adresse, bevor du den Zwei-Faktor-Schutz aktivierst.',
    'invalid-phone-number' =>
      'Gib eine gültige Telefonnummer im internationalen Format ein.',
    'unsupported-phone-region' =>
      'Der Zwei-Faktor-Schutz unterstützt derzeit Nummern aus Deutschland, Österreich und der Schweiz.',
    'invalid-verification-code' => 'Der eingegebene SMS-Code ist falsch.',
    'session-expired' || 'code-expired' =>
      'Der SMS-Code ist abgelaufen. Fordere bitte einen neuen Code an.',
    'too-many-requests' =>
      'Zu viele Versuche. Bitte warte und versuche es später erneut.',
    'quota-exceeded' =>
      'Das SMS-Kontingent ist erreicht. Bitte versuche es später erneut.',
    'network-request-failed' =>
      'Netzwerkfehler. Bitte prüfe deine Internetverbindung.',
    'operation-not-allowed' || 'admin-restricted-operation' =>
      'Der SMS-Zwei-Faktor-Schutz ist aktuell nicht verfügbar.',
    'captcha-check-failed' || 'app-not-authorized' =>
      'CaRisma konnte für den SMS-Versand nicht bestätigt werden. Bitte starte die App neu und versuche es erneut.',
    'sms-region-not-allowed' || 'phone-number-not-allowed' =>
      'SMS-Anmeldungen sind für diese Region nicht freigegeben.',
    'multi-factor-info-not-found' =>
      'Der ausgewählte zweite Faktor ist nicht mehr verfügbar. Bitte melde dich erneut an.',
    'missing-multi-factor-session' ||
    'missing-multi-factor-info' ||
    'unsupported-second-factor' =>
      'Der Zwei-Faktor-Vorgang ist nicht mehr gültig. Bitte beginne erneut.',
    'second-factor-already-in-use' =>
      'Diese Telefonnummer ist bereits als zweiter Faktor registriert.',
    'maximum-second-factor-count-exceeded' =>
      'Die maximal mögliche Anzahl an zweiten Faktoren ist erreicht.',
    'requires-recent-login' =>
      'Bitte bestätige deine Anmeldung erneut und versuche es dann noch einmal.',
    'wrong-password' ||
    'invalid-credential' => 'Das aktuelle Passwort ist nicht korrekt.',
    'aborted-by-user' => 'Die Sicherheitsbestätigung wurde abgebrochen.',
    'sms-request-in-progress' ||
    'verification-in-progress' => 'Die Anfrage wird bereits verarbeitet.',
    'missing-user' => 'Bitte melde dich erneut an.',
    'mfa-not-enrolled' =>
      'Für dieses Konto ist kein zweiter Faktor eingerichtet.',
    'recovery-cooldown' || 'resource-exhausted' =>
      'Eine neue Wiederherstellungsanfrage ist noch nicht möglich.',
    'permission-denied' =>
      'Du darfst diese Wiederherstellungsaktion nicht ausführen.',
    _ => 'Der Zwei-Faktor-Vorgang konnte gerade nicht abgeschlossen werden.',
  };
}

MfaFactorSnapshot _factorSnapshotFromInfo(PhoneMultiFactorInfo info) {
  final displayName = info.displayName?.trim();
  return MfaFactorSnapshot(
    uid: info.uid,
    displayName: displayName == null || displayName.isEmpty
        ? 'Mobiltelefon'
        : displayName,
    maskedPhoneNumber: maskPhoneNumber(info.phoneNumber),
    enrolledAt: info.enrollmentTimestamp <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (info.enrollmentTimestamp * 1000).round(),
            isUtc: true,
          ),
  );
}

String _normalizeSmsCode(String value) {
  final normalized = value.trim();
  if (!RegExp(r'^\d{6}$').hasMatch(normalized)) {
    throw FirebaseAuthException(code: 'invalid-verification-code');
  }
  return normalized;
}
