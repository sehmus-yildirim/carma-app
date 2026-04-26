import 'package:cloud_functions/cloud_functions.dart';

import 'plate_search_result.dart';

class PlateSearchService {
  PlateSearchService({
    FirebaseFunctions? functions,
  }) : _functions =
      functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  String normalizePlate(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String buildPlateKey({
    required String countryCode,
    required String plate,
  }) {
    final normalizedPlate = normalizePlate(plate);
    return '$countryCode:$normalizedPlate';
  }

  Future<PlateSearchResult> searchPlate({
    required String countryCode,
    required String plate,
    required double latitude,
    required double longitude,
    required int radiusKm,
  }) async {
    final callable = _functions.httpsCallable('searchPlate');

    final response = await callable.call<Map<String, dynamic>>({
      'countryCode': countryCode,
      'plate': plate,
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
    });

    return PlateSearchResult.fromMap(
      Map<String, dynamic>.from(response.data),
    );
  }

  Future<String> requestPlateContact({
    required String targetUid,
    required String plateKey,
  }) async {
    final callable = _functions.httpsCallable('requestPlateContact');

    final response = await callable.call<Map<String, dynamic>>({
      'targetUid': targetUid,
      'plateKey': plateKey,
    });

    final data = Map<String, dynamic>.from(response.data);
    return data['requestId'] as String;
  }
}