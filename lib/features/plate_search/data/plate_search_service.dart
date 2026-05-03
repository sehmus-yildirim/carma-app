import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../shared/config/carma_app_config.dart';
import '../../../shared/firebase/carma_firestore_paths.dart';
import '../../../shared/firebase/carma_firestore_schema.dart';
import 'plate_search_result.dart';

class PlateSearchService {
  PlateSearchService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    bool useMock = CarmaAppConfig.useMockPlateSearch,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: CarmaAppConfig.firebaseRegion),
       _useMock = useMock;

  final FirebaseAuth _auth;
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
    String? receiverDisplayName,
    String? displayPlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleLabel,
  }) async {
    if (_useMock) {
      return _createContactRequestInFirestore(
        targetUid: targetUid,
        plateKey: plateKey,
        receiverDisplayName: receiverDisplayName,
        displayPlate: displayPlate,
        vehicleBrand: vehicleBrand,
        vehicleModel: vehicleModel,
        vehicleColor: vehicleColor,
        vehicleLabel: vehicleLabel,
      );
    }

    final callable = _functions.httpsCallable('requestPlateContact');

    final response = await callable.call<Map<String, dynamic>>({
      'targetUid': targetUid,
      'plateKey': plateKey,
      'receiverDisplayName': receiverDisplayName,
      'displayPlate': displayPlate,
      'vehicleBrand': vehicleBrand,
      'vehicleModel': vehicleModel,
      'vehicleColor': vehicleColor,
      'vehicleLabel': vehicleLabel,
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

    if (ownerUserId == _auth.currentUser?.uid) {
      return const PlateSearchResult(found: false);
    }

    return PlateSearchResult(
      found: true,
      targetUid: ownerUserId,
      displayName: displayName?.trim().isEmpty == true ? null : displayName,
      distanceKm: null,
      plateKey: storedPlateKey,
      displayPlate: data['displayPlate'] as String?,
      vehicleBrand: data['vehicleBrand'] as String?,
      vehicleModel: data['vehicleModel'] as String?,
      vehicleColor: data['vehicleColor'] as String?,
      vehicleLabel: data['vehicleLabel'] as String?,
    );
  }

  Future<String> _createContactRequestInFirestore({
    required String targetUid,
    required String plateKey,
    String? receiverDisplayName,
    String? displayPlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleLabel,
  }) async {
    final sender = _auth.currentUser;

    if (sender == null) {
      throw FirebaseException(
        plugin: 'carma',
        code: 'unauthenticated',
        message: 'Bitte melde dich an, um Kontakt anzufragen.',
      );
    }

    final senderUserId = sender.uid;
    final receiverUserId = targetUid.trim();

    if (receiverUserId.isEmpty || plateKey.trim().isEmpty) {
      throw FirebaseException(
        plugin: 'carma',
        code: 'invalid-argument',
        message: 'Kontaktanfrage konnte nicht vorbereitet werden.',
      );
    }

    if (receiverUserId == senderUserId) {
      throw FirebaseException(
        plugin: 'carma',
        code: 'invalid-argument',
        message: 'Du kannst dich nicht selbst kontaktieren.',
      );
    }

    final senderDisplayName = await _loadCurrentUserDisplayName(senderUserId);
    final normalizedDisplayPlate = displayPlate?.trim().isNotEmpty == true
        ? displayPlate!.trim()
        : plateKey.trim().toUpperCase();
    final normalizedReceiverDisplayName =
        receiverDisplayName?.trim().isNotEmpty == true
        ? receiverDisplayName!.trim()
        : 'Carma Nutzer';
    final normalizedVehicleBrand = vehicleBrand?.trim();
    final normalizedVehicleModel = vehicleModel?.trim();
    final normalizedVehicleColor = vehicleColor?.trim();
    final normalizedVehicleLabel = vehicleLabel?.trim().isNotEmpty == true
        ? vehicleLabel!.trim()
        : _vehicleLabel(
            color: normalizedVehicleColor,
            brand: normalizedVehicleBrand,
            model: normalizedVehicleModel,
          );

    final now = DateTime.now();
    final expiresAt = now.add(
      const Duration(
        hours: FirestoreDocumentDefaults.defaultRequestExpiryHours,
      ),
    );

    final document = await _firestore
        .collection(CarmaFirestoreCollections.contactRequests)
        .add({
          'senderUserId': senderUserId,
          'receiverUserId': receiverUserId,
          'targetUserId': receiverUserId,
          'plateKey': plateKey.trim().toUpperCase(),
          'senderDisplayName': senderDisplayName,
          'receiverDisplayName': normalizedReceiverDisplayName,
          'displayPlate': normalizedDisplayPlate,
          'vehicleBrand': normalizedVehicleBrand,
          'vehicleModel': normalizedVehicleModel,
          'vehicleColor': normalizedVehicleColor,
          'vehicleLabel': normalizedVehicleLabel,
          'status': FirestoreContactRequestStatus.pending,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'isDeleted': false,
        });

    return document.id;
  }

  String _vehicleLabel({
    required String? color,
    required String? brand,
    required String? model,
  }) {
    final parts = <String>[
      if (color != null && color.trim().isNotEmpty)
        _vehicleColorAdjective(color),
      if (brand != null && brand.trim().isNotEmpty) brand.trim(),
      if (model != null && model.trim().isNotEmpty) model.trim(),
    ];

    return parts.join(' ').trim();
  }

  String _vehicleColorAdjective(String color) {
    return switch (color.trim().toLowerCase()) {
      'schwarz' => 'schwarzer',
      'weiß' || 'weiss' => 'weißer',
      'silber' => 'silberner',
      'grau' => 'grauer',
      'blau' => 'blauer',
      'rot' => 'roter',
      'grün' || 'gruen' => 'grüner',
      'braun' => 'brauner',
      'gelb' => 'gelber',
      'orange' => 'oranger',
      _ => color.trim(),
    };
  }

  Future<String> _loadCurrentUserDisplayName(String userId) async {
    try {
      final profile = await _firestore
          .doc(CarmaFirestorePaths.userProfile(userId))
          .get();

      final data = profile.data();

      if (data == null) {
        return _fallbackDisplayName();
      }

      final firstName = data['firstName'] as String? ?? '';
      final lastName = data['lastName'] as String? ?? '';
      final displayName = data['displayName'] as String? ?? '';

      final fullName = '$firstName $lastName'.trim();

      if (fullName.isNotEmpty) {
        return fullName;
      }

      if (displayName.trim().isNotEmpty) {
        return displayName.trim();
      }

      return _fallbackDisplayName();
    } catch (_) {
      return _fallbackDisplayName();
    }
  }

  String _fallbackDisplayName() {
    final authDisplayName = _auth.currentUser?.displayName;

    if (authDisplayName != null && authDisplayName.trim().isNotEmpty) {
      return authDisplayName.trim();
    }

    return 'Carma Nutzer';
  }
}
