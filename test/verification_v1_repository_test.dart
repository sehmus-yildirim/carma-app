import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/verification_v1/data/verification_v1_repository.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_models.dart';

void main() {
  group('VerificationV1Repository', () {
    test('creates a typed nonce-bound session', () async {
      final gateway = _RecordingGateway({
        'createVerificationSessionV1': {
          'sessionId': 'session-1',
          'nonce': 'nonce-1',
          'expiresAt': '2030-08-30T12:15:00.000Z',
          'state': 'created',
        },
      });
      final repository = VerificationV1Repository(gateway: gateway);

      final session = await repository.createSession(
        vehicleId: ' vehicle-1 ',
        relation: VerificationVehicleRelation.companyCar,
      );

      expect(session.sessionId, 'session-1');
      expect(session.nonce, 'nonce-1');
      expect(session.state, VerificationSessionState.created);
      expect(gateway.lastPayload, {
        'vehicleId': 'vehicle-1',
        'relation': 'company_car',
      });
    });

    test('rejects a malformed session response', () async {
      final repository = VerificationV1Repository(
        gateway: _RecordingGateway({
          'createVerificationSessionV1': {'expiresAt': 'not-a-date'},
        }),
      );

      await expectLater(
        repository.createSession(
          vehicleId: 'vehicle-1',
          relation: VerificationVehicleRelation.registeredHolder,
        ),
        throwsA(
          isA<VerificationV1Exception>().having(
            (error) => error.code,
            'code',
            'invalid-response',
          ),
        ),
      );
    });

    test(
      'submits only typed permitted OCR values and privacy version',
      () async {
        final gateway = _RecordingGateway({
          'submitVerificationDataV1': {
            'status': 'requires_declaration',
            'holderMatch': false,
          },
        });
        final repository = VerificationV1Repository(gateway: gateway);

        final result = await repository.submitData(
          session: _session,
          identity: _identity,
          vehicleRegistration: _registration,
        );

        expect(result.status, VerificationV1Status.requiresDeclaration);
        expect(result.holderMatch, isFalse);
        expect(gateway.lastPayload, {
          'sessionId': 'session-1',
          'nonce': 'nonce-1',
          'privacyVersion': VerificationV1Repository.privacyVersion,
          'identity': _identity.toSubmissionJson(),
          'vehicleRegistration': _registration.toSubmissionJson(),
        });
      },
    );

    test(
      'finalizes with fixed versions and normalized signature vectors',
      () async {
        final gateway = _RecordingGateway({
          'finalizeVehicleDeclarationV1': {
            'status': 'verified',
            'holderMatch': false,
            'declarationId': 'declaration-1',
          },
        });
        final repository = VerificationV1Repository(gateway: gateway);
        const signature = [
          [
            {'x': 0.1, 'y': 0.2},
            {'x': 0.8, 'y': 0.7},
          ],
        ];

        final result = await repository.finalizeDeclaration(
          session: _session,
          signatureStrokes: signature,
        );

        expect(result.status, VerificationV1Status.verified);
        expect(result.declarationId, 'declaration-1');
        expect(gateway.lastPayload, {
          'sessionId': 'session-1',
          'nonce': 'nonce-1',
          'privacyVersion': VerificationV1Repository.privacyVersion,
          'declarationVersion': VerificationV1Repository.declarationVersion,
          'declarationAccepted': true,
          'signature': {'strokes': signature},
        });
      },
    );

    test('sends a trimmed vehicle revocation with its reason', () async {
      final gateway = _RecordingGateway({
        'revokeOrInvalidateVerificationV1': {'status': 'revoked'},
      });
      final repository = VerificationV1Repository(gateway: gateway);

      await repository.revokeVehicle(
        vehicleId: ' vehicle-1 ',
        reason: 'vehicle_plate_changed',
      );

      expect(gateway.lastPayload, {
        'vehicleId': 'vehicle-1',
        'reason': 'vehicle_plate_changed',
      });
    });

    test(
      'preserves safe domain errors and masks unknown transport errors',
      () async {
        final safeRepository = VerificationV1Repository(
          gateway: _ThrowingGateway(
            const VerificationV1Exception('Sichere Meldung', code: 'safe'),
          ),
        );
        final maskedRepository = VerificationV1Repository(
          gateway: _ThrowingGateway(StateError('secret transport detail')),
        );

        await expectLater(
          safeRepository.revokeVehicle(vehicleId: 'vehicle-1'),
          throwsA(
            isA<VerificationV1Exception>()
                .having((error) => error.message, 'message', 'Sichere Meldung')
                .having((error) => error.code, 'code', 'safe'),
          ),
        );
        await expectLater(
          maskedRepository.revokeVehicle(vehicleId: 'vehicle-1'),
          throwsA(
            isA<VerificationV1Exception>()
                .having(
                  (error) => error.message,
                  'message',
                  contains('nicht erreichbar'),
                )
                .having((error) => error.code, 'code', 'unavailable'),
          ),
        );
      },
    );
  });
}

final _session = VerificationSession(
  sessionId: 'session-1',
  nonce: 'nonce-1',
  expiresAt: DateTime(2030, 8, 30, 12, 15),
  state: VerificationSessionState.created,
);

final _identity = IdentityDocumentData(
  firstNames: 'Erika Maria',
  lastName: 'Muster',
  dateOfBirth: DateTime(1990, 1, 1),
  expiresAt: DateTime(2030, 12, 31),
  documentType: VerificationIdentityDocumentType.idCard,
  parserVersion: 'identity-test-v1',
  issuingCountryCode: 'DE',
  documentProfileVersion: 'deu_bo_02004_2021_v1',
);

const _registration = VehicleRegistrationData(
  plate: 'HH AB 123',
  holderNameOrCompany: 'Muster',
  holderFirstNames: 'Erika Maria',
  parserVersion: 'vehicle-test-v1',
  registrationCountryCode: 'DE',
  documentProfileVersion: 'deu_go_01001_2005_v1',
);

class _RecordingGateway implements VerificationV1Gateway {
  _RecordingGateway(this.responses);

  final Map<String, Map<String, dynamic>> responses;
  String? lastCommand;
  Map<String, Object?>? lastPayload;

  @override
  Future<Map<String, dynamic>> call(
    String command,
    Map<String, Object?> payload,
  ) async {
    lastCommand = command;
    lastPayload = payload;
    return responses[command] ?? const {};
  }
}

class _ThrowingGateway implements VerificationV1Gateway {
  const _ThrowingGateway(this.error);

  final Object error;

  @override
  Future<Map<String, dynamic>> call(
    String command,
    Map<String, Object?> payload,
  ) async => throw error;
}
