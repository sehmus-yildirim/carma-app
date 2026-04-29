import 'package:cloud_functions/cloud_functions.dart';

import 'plate_search_result.dart';

class PlateSearchService {
  PlateSearchService({
    FirebaseFunctions? functions,
    bool useMock = true,
  })  : _functions =
      functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3'),
        _useMock = useMock;

  final FirebaseFunctions _functions;
  final bool _useMock;

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
    if (_useMock) {
      return _searchPlateMock(
        countryCode: countryCode,
        plate: plate,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
      );
    }

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
    if (_useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      return 'local-request-${DateTime.now().millisecondsSinceEpoch}';
    }

    final callable = _functions.httpsCallable('requestPlateContact');

    final response = await callable.call<Map<String, dynamic>>({
      'targetUid': targetUid,
      'plateKey': plateKey,
    });

    final data = Map<String, dynamic>.from(response.data);
    return data['requestId'] as String;
  }

  Future<PlateSearchResult> _searchPlateMock({
    required String countryCode,
    required String plate,
    required double latitude,
    required double longitude,
    required int radiusKm,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final plateKey = buildPlateKey(
      countryCode: countryCode,
      plate: plate,
    );

    final normalizedPlate = normalizePlate(plate);

    if (normalizedPlate.isEmpty || normalizedPlate.endsWith('0')) {
      return const PlateSearchResult(
        found: false,
      );
    }

    return PlateSearchResult(
      found: true,
      targetUid: 'local-target-user',
      displayName: 'Carma Nutzer',
      distanceKm: 1.2,
      plateKey: plateKey,
    );
  }
}