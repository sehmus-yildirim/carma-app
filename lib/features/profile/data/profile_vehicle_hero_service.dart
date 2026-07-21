import 'package:cloud_functions/cloud_functions.dart';

import '../../../shared/config/carisma_app_config.dart';

class ProfileVehicleHeroRequestResult {
  const ProfileVehicleHeroRequestResult({
    required this.accepted,
    required this.status,
  });

  final bool accepted;
  final String status;
}

class ProfileVehicleHeroException implements Exception {
  const ProfileVehicleHeroException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileVehicleHeroService {
  ProfileVehicleHeroService({FirebaseFunctions? functions})
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(
            region: CaRismaAppConfig.firebaseRegion,
          );

  static const String callableName = 'requestVehicleHeroImage';

  final FirebaseFunctions _functions;

  Future<ProfileVehicleHeroRequestResult> requestGeneration({
    required String vehicleId,
    bool forceRegeneration = false,
  }) async {
    final normalizedVehicleId = vehicleId.trim();
    if (normalizedVehicleId.isEmpty) {
      throw const ProfileVehicleHeroException(
        'Das Fahrzeug konnte nicht bestimmt werden.',
      );
    }

    try {
      final callable = _functions.httpsCallable(callableName);
      final response = await callable.call<Map<String, dynamic>>({
        'vehicleId': normalizedVehicleId,
        'forceRegeneration': forceRegeneration,
      });
      final data = response.data;
      final accepted = data['accepted'] == true;
      final status = (data['status'] as String? ?? '').trim();
      if (!accepted) {
        throw const ProfileVehicleHeroException(
          'Die Fahrzeugdarstellung konnte nicht gestartet werden.',
        );
      }
      return ProfileVehicleHeroRequestResult(
        accepted: true,
        status: status.isEmpty ? 'queued' : status,
      );
    } on FirebaseFunctionsException catch (error) {
      throw ProfileVehicleHeroException(_messageForFunctionsError(error));
    } on ProfileVehicleHeroException {
      rethrow;
    } catch (_) {
      throw const ProfileVehicleHeroException(
        'Der KI-Dienst ist momentan nicht erreichbar.',
      );
    }
  }

  String _messageForFunctionsError(FirebaseFunctionsException error) {
    return switch (error.code) {
      'unauthenticated' =>
        'Bitte melde dich neu an, um ein Fahrzeugbild zu erstellen.',
      'permission-denied' =>
        'Für dieses Fahrzeug darf kein Bild erstellt werden.',
      'not-found' ||
      'unimplemented' => 'Der KI-Dienst ist noch nicht freigeschaltet.',
      'resource-exhausted' =>
        'Das Erstellungslimit ist erreicht. Versuche es später erneut.',
      'failed-precondition' => 'Vervollständige zuerst die Fahrzeugdaten.',
      'already-exists' => 'Die Fahrzeugdarstellung wird bereits erstellt.',
      'unavailable' ||
      'deadline-exceeded' => 'Der KI-Dienst ist momentan nicht erreichbar.',
      _ =>
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Die Fahrzeugdarstellung konnte nicht gestartet werden.',
    };
  }
}
