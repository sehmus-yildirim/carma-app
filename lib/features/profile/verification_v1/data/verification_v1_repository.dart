import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/verification_models.dart';

class VerificationV1Exception implements Exception {
  const VerificationV1Exception(this.message, {this.code, this.reason});

  final String message;
  final String? code;
  final String? reason;

  @override
  String toString() => message;
}

abstract interface class VerificationV1Gateway {
  Future<Map<String, dynamic>> call(
    String command,
    Map<String, Object?> payload,
  );
}

class FirebaseVerificationV1Gateway implements VerificationV1Gateway {
  FirebaseVerificationV1Gateway({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, dynamic>> call(
    String command,
    Map<String, Object?> payload,
  ) async {
    final result = await _functions
        .httpsCallable(
          command,
          options: HttpsCallableOptions(limitedUseAppCheckToken: true),
        )
        .call(payload);
    return result.data is Map
        ? Map<String, dynamic>.from(result.data as Map)
        : const <String, dynamic>{};
  }
}

class VerificationV1Repository {
  VerificationV1Repository({
    VerificationV1Gateway? gateway,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _gateway = gateway ?? FirebaseVerificationV1Gateway(),
       _firestore = firestore,
       _storage = storage;

  static const String privacyVersion = VerificationV1Policy.privacyVersion;
  static const String declarationVersion =
      VerificationV1Policy.declarationVersion;

  final VerificationV1Gateway _gateway;
  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;
  FirebaseStorage get _files => _storage ?? FirebaseStorage.instance;

  Future<VerificationSession> createSession({
    required String vehicleId,
    required VerificationVehicleRelation relation,
  }) async {
    final data = await _call('createVerificationSessionV1', {
      'vehicleId': vehicleId.trim(),
      'relation': relation.value,
    });
    final expiresAt = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
    if (expiresAt == null) {
      throw const VerificationV1Exception(
        'Die Verifizierungssession ist unvollständig.',
        code: 'invalid-response',
      );
    }
    return VerificationSession(
      sessionId: data['sessionId']?.toString() ?? '',
      nonce: data['nonce']?.toString() ?? '',
      expiresAt: expiresAt,
      state: VerificationSessionState.fromValue(data['state']),
    );
  }

  Future<VerificationSubmissionResult> submitData({
    required VerificationSession session,
    required IdentityDocumentData identity,
    required VehicleRegistrationData vehicleRegistration,
  }) async {
    final data = await _call('submitVerificationDataV1', {
      'sessionId': session.sessionId,
      'nonce': session.nonce,
      'privacyVersion': privacyVersion,
      'identity': identity.toSubmissionJson(),
      'vehicleRegistration': vehicleRegistration.toSubmissionJson(),
    });
    return _submissionResult(data);
  }

  Future<VerificationSubmissionResult> finalizeDeclaration({
    required VerificationSession session,
    required List<List<Map<String, double>>> signatureStrokes,
  }) async {
    final data = await _call('finalizeVehicleDeclarationV1', {
      'sessionId': session.sessionId,
      'nonce': session.nonce,
      'privacyVersion': privacyVersion,
      'declarationVersion': declarationVersion,
      'declarationAccepted': true,
      'signature': {'strokes': signatureStrokes},
    });
    return _submissionResult(data);
  }

  Future<void> revokeVehicle({
    required String vehicleId,
    String reason = 'user_requested',
  }) async {
    await _call('revokeOrInvalidateVerificationV1', {
      'vehicleId': vehicleId.trim(),
      'reason': reason,
    });
  }

  Stream<VerificationV1Record?> watchVehicleVerification({
    required String userId,
    required String vehicleId,
  }) {
    return _database
        .doc('users/$userId/vehicle_verifications/$vehicleId')
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) return null;
          return VerificationV1Record(
            status: VerificationV1Status.fromValue(data['status']),
            assuranceLevel: data['assuranceLevel']?.toString() ?? '',
            verificationMethod: data['verificationMethod']?.toString() ?? '',
            verifiedAt: _dateTime(data['verifiedAt']),
            vehicleId: vehicleId,
            declarationId: data['declarationId']?.toString(),
          );
        });
  }

  Future<Uint8List> loadDeclarationPdf({
    required String userId,
    required String declarationId,
    int maxBytes = 2 * 1024 * 1024,
  }) async {
    final snapshot = await _database
        .doc('users/$userId/verification_declarations/$declarationId')
        .get();
    final path = snapshot.data()?['pdfPath']?.toString().trim() ?? '';
    if (!snapshot.exists || path.isEmpty) {
      throw const VerificationV1Exception(
        'Die Eigenerklärung wurde nicht gefunden.',
        code: 'not-found',
      );
    }
    final bytes = await _files.ref(path).getData(maxBytes);
    if (bytes == null) {
      throw const VerificationV1Exception(
        'Die Eigenerklärung konnte nicht geladen werden.',
        code: 'unavailable',
      );
    }
    return bytes;
  }

  Future<Map<String, dynamic>> _call(
    String command,
    Map<String, Object?> payload,
  ) async {
    try {
      return await _gateway.call(command, payload);
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final reason = details is Map ? details['reason']?.toString() : null;
      throw VerificationV1Exception(
        _messageFor(error),
        code: error.code,
        reason: reason,
      );
    } on VerificationV1Exception {
      rethrow;
    } catch (_) {
      throw const VerificationV1Exception(
        'Die Verifizierung ist gerade nicht erreichbar. Bitte prüfe deine Verbindung und versuche es erneut.',
        code: 'unavailable',
      );
    }
  }

  static VerificationSubmissionResult _submissionResult(
    Map<String, dynamic> data,
  ) {
    return VerificationSubmissionResult(
      status: VerificationV1Status.fromValue(data['status']),
      holderMatch: data['holderMatch'] == true,
      declarationId: data['declarationId']?.toString(),
    );
  }

  static String _messageFor(FirebaseFunctionsException error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) return message;
    return switch (error.code) {
      'unauthenticated' => 'Bitte melde dich erneut an.',
      'permission-denied' => 'Du hast keine Berechtigung für diese Aktion.',
      'deadline-exceeded' =>
        'Die Session ist abgelaufen. Bitte starte die Verifizierung erneut.',
      'resource-exhausted' =>
        'Zu viele Versuche. Bitte versuche es später erneut.',
      'failed-precondition' =>
        'Die Verifizierung konnte noch nicht abgeschlossen werden.',
      _ =>
        'Die Verifizierung ist gerade nicht erreichbar. Bitte versuche es erneut.',
    };
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }
}
