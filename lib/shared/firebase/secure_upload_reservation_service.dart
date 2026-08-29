import 'package:cloud_functions/cloud_functions.dart';

import '../config/carisma_app_config.dart';

class SecureUploadReservationService {
  SecureUploadReservationService({FirebaseFunctions? functions})
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(
            region: CaRismaAppConfig.firebaseRegion,
          );

  final FirebaseFunctions _functions;

  Future<String> reserve({
    required String storagePath,
    required String contentType,
    required int sizeBytes,
  }) async {
    final response = await _functions
        .httpsCallable('reserveMediaUpload')
        .call<Map<String, dynamic>>(<String, Object>{
          'storagePath': storagePath,
          'contentType': contentType,
          'sizeBytes': sizeBytes,
        });
    final reservationId = (response.data['reservationId'] as String? ?? '')
        .trim();
    if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(reservationId)) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Der Upload wurde nicht sicher freigegeben.',
      );
    }
    return reservationId;
  }
}
