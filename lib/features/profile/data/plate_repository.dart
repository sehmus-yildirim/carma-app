import 'package:cloud_functions/cloud_functions.dart';

import 'user_profile.dart';

class PlateRepository {
  PlateRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<void> registerPlateForProfile(
    UserProfile profile, {
    double? latitude,
    double? longitude,
  }) async {
    if (profile.uid.trim().isEmpty) return;
    await _refreshPrimaryPlate(latitude: latitude, longitude: longitude);
  }

  Future<void> updatePlateProfileVisibility({
    required UserProfile profile,
  }) async {
    if (profile.uid.trim().isEmpty) return;
    await _refreshPrimaryPlate();
  }

  Future<void> deactivatePlateForProfile(UserProfile profile) async {
    // Kennzeichenwechsel und Deaktivierung sind Teil der atomaren
    // Fahrzeug-Functions. Dieser Legacy-Einstieg schreibt bewusst nicht mehr.
  }

  Future<void> _refreshPrimaryPlate({
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _functions.httpsCallable('updatePrimaryVehicleLocation').call({
        'latitude': ?latitude,
        'longitude': ?longitude,
      });
    } on FirebaseFunctionsException catch (error) {
      final message = error.message?.trim();
      throw StateError(
        message == null || message.isEmpty
            ? 'Das Kennzeichen konnte gerade nicht aktualisiert werden.'
            : message,
      );
    }
  }
}
