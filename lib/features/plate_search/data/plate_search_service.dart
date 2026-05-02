import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../shared/config/carma_app_config.dart';
import '../../../shared/firebase/carma_firestore_paths.dart';
import 'plate_search_result.dart';

class PlateSearchService {
  PlateSearchService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    bool useMock = CarmaAppConfig.useMockPlateSearch,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: CarmaAppConfig.firebaseRegion),
       _useMock = useMock;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final bool _useMock;

  String normalizePlate(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String buildPlateKey({required String countryCode, required String plate}) {
    return normalizePlate(plate);
  }

  Future<PlateSearchResult> searchPlate({
    required String countryCode,
    required String plate,
    required double latitude,
    required double longitude,
    required int radiusKm,
  }) async {
    if (_useMock) {
      return _searchPlateFromFirestore(countryCode: countryCode, plate: plate);
    }

    final callable = _functions.httpsCallable('searchPlate');

    final response = await callable.call<Map<String, dynamic>>({
      'countryCode': countryCode,
      'plate': plate,
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
    });

    return PlateSearchResult.fromMap(Map<String, dynamic>.from(response.data));
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

  Future<PlateSearchResult> _searchPlateFromFirestore({
    required String countryCode,
    required String plate,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final normalizedCountryCode = countryCode.trim().toUpperCase();
    final plateKey = buildPlateKey(
      countryCode: normalizedCountryCode,
      plate: plate,
    );

    if (normalizedCountryCode.isEmpty || plateKey.isEmpty) {
      return const PlateSearchResult(found: false);
    }

    final document = await _firestore
        .doc(CarmaFirestorePaths.plate(normalizedCountryCode, plateKey))
        .get();

    if (!document.exists) {
      return const PlateSearchResult(found: false);
    }

    final data = document.data();

    if (data == null) {
      return const PlateSearchResult(found: false);
    }

    final isActive = data['isActive'] as bool? ?? false;
    final isDeleted = data['isDeleted'] as bool? ?? true;
    final allowContactRequests = data['allowContactRequests'] as bool? ?? false;

    if (!isActive || isDeleted || !allowContactRequests) {
      return const PlateSearchResult(found: false);
    }

    final ownerUserId = data['ownerUserId'] as String?;
    final displayName = data['displayName'] as String?;
    final storedPlateKey = data['plateKey'] as String? ?? plateKey;

    if (ownerUserId == null || ownerUserId.trim().isEmpty) {
      return const PlateSearchResult(found: false);
    }

    return PlateSearchResult(
      found: true,
      targetUid: ownerUserId,
      displayName: displayName?.trim().isEmpty == true ? null : displayName,
      distanceKm: null,
      plateKey: storedPlateKey,
    );
  }
}
