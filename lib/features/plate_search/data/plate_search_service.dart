import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/config/carisma_app_config.dart';
import '../../../shared/firebase/carisma_firestore_paths.dart';
import '../../../shared/firebase/carisma_firestore_schema.dart';
import '../../../shared/security/trusted_firebase_media_url.dart';
import 'plate_search_result.dart';

class PlateContactRequestState {
  const PlateContactRequestState({required this.status, this.chatId});

  const PlateContactRequestState.pending()
    : status = FirestoreContactRequestStatus.pending,
      chatId = null;

  final String status;
  final String? chatId;

  bool get isPending => status == FirestoreContactRequestStatus.pending;
  bool get isAccepted => status == FirestoreContactRequestStatus.accepted;
  bool get hasLinkedChat => chatId?.trim().isNotEmpty ?? false;
  bool get canOpenChat => hasLinkedChat;
  bool get isOpen => isPending || (isAccepted && !hasLinkedChat);

  factory PlateContactRequestState.fromMap(Map<String, dynamic> data) {
    return PlateContactRequestState(
      status:
          data['status'] as String? ?? FirestoreContactRequestStatus.pending,
      chatId: data['chatId'] as String?,
    );
  }
}

class PlateContactRequestResult {
  const PlateContactRequestResult({
    required this.requestId,
    required this.chatId,
    required this.status,
    required this.created,
  });

  final String requestId;
  final String chatId;
  final String status;
  final bool created;

  bool get isPending => status == FirestoreContactRequestStatus.pending;
  bool get isAccepted => status == FirestoreContactRequestStatus.accepted;
}

class PlateSearchService {
  static const String demoTargetUserId = 'plaqa-demo-plate-user';
  static const String demoPlateKey = 'HHPQ2026';
  static const String demoChatId = 'local-demo-hh-pq-2026';
  static const PlateSearchResult demoSearchResult = PlateSearchResult(
    found: true,
    targetUid: demoTargetUserId,
    displayName: CaRismaAppConfig.storeDemoDisplayName,
    isVerified: true,
    distanceKm: 0.1,
    vehicleId: 'plaqa-demo-vehicle-bmw-x6',
    plateKey: demoPlateKey,
    displayPlate: CaRismaAppConfig.storeDemoPlate,
    countryCode: 'DE',
    region: 'HH',
    letters: 'PQ',
    numbers: '2026',
    vehicleBrand: 'BMW',
    vehicleModel: 'X6',
    vehicleColor: 'Schwarz',
    vehicleLabel: 'BMW X6',
  );

  PlateSearchService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    bool useMock = CaRismaAppConfig.useMockPlateSearch,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(
             region: CaRismaAppConfig.firebaseRegion,
           ),
       _useMock = useMock;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final bool _useMock;

  static bool isDemoPlate({
    required String countryCode,
    required String plateKey,
  }) {
    return kDebugMode && plateKey.trim().toUpperCase() == demoPlateKey;
  }

  static bool isDemoTarget(String? targetUserId) {
    return kDebugMode && targetUserId?.trim() == demoTargetUserId;
  }

  static bool isDemoChat(String? chatId) {
    return kDebugMode && chatId?.trim() == demoChatId;
  }

  String normalizePlate(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-ZÄÖÜ0-9]'), '');
  }

  String buildPlateKey({required String countryCode, required String plate}) {
    return normalizePlate(plate);
  }

  String _legacyContactRequestDocumentId({
    required String senderUserId,
    required String plateKey,
  }) {
    return '${senderUserId.trim()}_${plateKey.trim().toUpperCase()}';
  }

  String _contactRequestDocumentId({
    required String senderUserId,
    required String countryCode,
    required String vehicleId,
  }) {
    return <String>[
      senderUserId.trim(),
      countryCode.trim().toUpperCase(),
      vehicleId.trim(),
    ].join('_');
  }

  bool _isRequestStillActive(Map<String, dynamic> data) {
    if (data['isDeleted'] == true) {
      return false;
    }

    final expiresAt = data['expiresAt'];
    final expiry = expiresAt is Timestamp
        ? expiresAt.toDate()
        : expiresAt is DateTime
        ? expiresAt
        : expiresAt is String
        ? DateTime.tryParse(expiresAt)
        : null;

    if (expiry == null) {
      return true;
    }

    return expiry.isAfter(DateTime.now());
  }

  Future<PlateContactRequestState?> loadExistingRequestState({
    required String targetUid,
    required String countryCode,
    required String vehicleId,
    required String plateKey,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return null;
    }

    final normalizedTargetUid = targetUid.trim();
    final normalizedCountryCode = countryCode.trim().toUpperCase();
    final normalizedVehicleId = vehicleId.trim();
    final normalizedPlateKey = plateKey.trim().toUpperCase();

    if (normalizedTargetUid.isEmpty ||
        normalizedCountryCode.isEmpty ||
        normalizedVehicleId.isEmpty ||
        normalizedPlateKey.isEmpty) {
      return null;
    }

    final collection = _firestore.collection(
      CaRismaFirestoreCollections.contactRequests,
    );
    var snapshot = await collection
        .doc(
          _contactRequestDocumentId(
            senderUserId: currentUser.uid,
            countryCode: normalizedCountryCode,
            vehicleId: normalizedVehicleId,
          ),
        )
        .get();

    // Pending requests created before stable vehicle IDs were introduced
    // remain discoverable until their normal 48-hour expiry.
    if (!snapshot.exists) {
      snapshot = await collection
          .doc(
            _legacyContactRequestDocumentId(
              senderUserId: currentUser.uid,
              plateKey: normalizedPlateKey,
            ),
          )
          .get();
    }

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null || !_isRequestStillActive(data)) {
      return null;
    }

    final receiverUserId = (data['receiverUserId'] as String? ?? '').trim();
    final storedVehicleId = (data['vehicleId'] as String? ?? '').trim();

    if (receiverUserId.isNotEmpty && receiverUserId != normalizedTargetUid) {
      return null;
    }

    if (storedVehicleId.isNotEmpty && storedVehicleId != normalizedVehicleId) {
      return null;
    }

    final requestState = PlateContactRequestState.fromMap(data);
    final linkedChatId = requestState.chatId?.trim() ?? '';

    if (linkedChatId.isEmpty) {
      return requestState;
    }

    final chatDocument = _firestore
        .collection(CaRismaFirestoreCollections.chats)
        .doc(linkedChatId);
    final chatSnapshot = await chatDocument.get();

    if (chatSnapshot.exists) {
      return requestState;
    }

    final senderUserId = (data['senderUserId'] as String? ?? '').trim();
    if (senderUserId.isEmpty || receiverUserId.isEmpty) {
      return PlateContactRequestState(
        status: requestState.status,
        chatId: null,
      );
    }

    try {
      final createdAt = data['createdAt'];
      final participants = [senderUserId, receiverUserId]..sort();

      await chatDocument.set({
        'participants': participants,
        'status': FirestoreChatStatus.active,
        'requestId': snapshot.id,
        'createdAt': createdAt is Timestamp
            ? createdAt
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage':
            'Kontaktanfrage gesendet. Ihr könnt jetzt geschützt schreiben.',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'senderUserId': senderUserId,
        'receiverUserId': receiverUserId,
        'senderDisplayName': data['senderDisplayName'],
        'senderPhotoUrl': data['senderPhotoUrl'],
        'receiverDisplayName': data['receiverDisplayName'],
        'receiverPhotoUrl': data['receiverPhotoUrl'],
        'displayPlate': data['displayPlate'],
        'vehicleBrand': data['vehicleBrand'],
        'vehicleModel': data['vehicleModel'],
        'vehicleColor': data['vehicleColor'],
        'vehicleLabel': data['vehicleLabel'],
      });

      return requestState;
    } on FirebaseException {
      return PlateContactRequestState(
        status: requestState.status,
        chatId: null,
      );
    }
  }

  Future<PlateSearchResult> searchPlate({
    required String countryCode,
    required String plate,
    required double latitude,
    required double longitude,
    required int radiusKm,
    String? region,
    String? letters,
    String? numbers,
  }) async {
    if (_useMock) {
      return _searchPlateFromFirestore(
        countryCode: countryCode,
        plate: plate,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        region: region,
        letters: letters,
        numbers: numbers,
      );
    }

    final callable = _functions.httpsCallable('searchPlate');

    final response = await callable.call<Map<String, dynamic>>({
      'countryCode': countryCode,
      'plate': plate,
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
      'region': region,
      'letters': letters,
      'numbers': numbers,
    });

    return PlateSearchResult.fromMap(Map<String, dynamic>.from(response.data));
  }

  Future<PlateContactRequestResult> requestPlateContact({
    required String targetUid,
    required String countryCode,
    required String vehicleId,
    required String plateKey,
    String? receiverDisplayName,
    String? receiverPhotoUrl,
    String? displayPlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleLabel,
    String? requestReason,
    String? message,
  }) async {
    if (_useMock &&
        isDemoTarget(targetUid) &&
        plateKey.trim().toUpperCase() == demoPlateKey) {
      await Future<void>.delayed(const Duration(milliseconds: 250));

      return const PlateContactRequestResult(
        requestId: 'demo-request-hh-cr-2026',
        chatId: demoChatId,
        status: FirestoreContactRequestStatus.accepted,
        created: true,
      );
    }

    return _createContactRequestInFirestore(
      targetUid: targetUid,
      countryCode: countryCode,
      vehicleId: vehicleId,
      plateKey: plateKey,
      receiverDisplayName: receiverDisplayName,
      receiverPhotoUrl: receiverPhotoUrl,
      displayPlate: displayPlate,
      vehicleBrand: vehicleBrand,
      vehicleModel: vehicleModel,
      vehicleColor: vehicleColor,
      vehicleLabel: vehicleLabel,
      requestReason: requestReason,
      message: message,
    );
  }

  Future<PlateSearchResult> _searchPlateFromFirestore({
    required String countryCode,
    required String plate,
    required double latitude,
    required double longitude,
    required int radiusKm,
    String? region,
    String? letters,
    String? numbers,
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

    if (isDemoPlate(countryCode: normalizedCountryCode, plateKey: plateKey)) {
      return demoSearchResult;
    }

    final DocumentSnapshot<Map<String, dynamic>> document;

    try {
      document = await _firestore
          .doc(CaRismaFirestorePaths.plate(normalizedCountryCode, plateKey))
          .get();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return const PlateSearchResult(found: false);
      }

      rethrow;
    }

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
    final isVehicleVerified = data['isVerified'] as bool? ?? false;

    if (!isActive || isDeleted || !allowContactRequests || !isVehicleVerified) {
      return const PlateSearchResult(found: false);
    }

    final ownerUserId = data['ownerUserId'] as String?;
    final vehicleId = (data['vehicleId'] as String? ?? '').trim();
    final displayName = data['displayName'] as String?;
    final storedPlateKey = data['plateKey'] as String? ?? plateKey;
    final storedLatitude = (data['latitude'] as num?)?.toDouble();
    final storedLongitude = (data['longitude'] as num?)?.toDouble();
    final locationUpdatedAt = _dateTimeFromValue(data['locationUpdatedAt']);

    if (ownerUserId == null ||
        ownerUserId.trim().isEmpty ||
        vehicleId.isEmpty) {
      return const PlateSearchResult(found: false);
    }

    if (ownerUserId == _auth.currentUser?.uid) {
      return const PlateSearchResult(found: false);
    }

    final visibilitySettings = await _loadVisibilitySettingsForUser(
      ownerUserId,
    );
    final ownerIdentityVerified = await _loadPublicIdentityVerification(
      ownerUserId,
    );
    final settingsAllowContactRequests =
        visibilitySettings['allowContactRequests'] as bool? ?? true;
    final settingsPlateSearchVisibility =
        visibilitySettings['plateSearchVisibility'] as String? ?? 'contacts';
    final settingsShowVehicle =
        visibilitySettings['showVehicle'] as bool? ?? true;
    final settingsShowPlate = visibilitySettings['showPlate'] as bool? ?? true;

    if (!settingsAllowContactRequests ||
        settingsPlateSearchVisibility == 'onlyMe') {
      return const PlateSearchResult(found: false);
    }

    if (locationUpdatedAt == null) {
      return const PlateSearchResult(found: false);
    }

    final freshestAllowedAt = DateTime.now().subtract(
      const Duration(
        minutes: FirestoreDocumentDefaults.defaultPlateLocationFreshnessMinutes,
      ),
    );

    if (locationUpdatedAt.isBefore(freshestAllowedAt)) {
      return const PlateSearchResult(found: false);
    }

    if (storedLatitude == null ||
        storedLongitude == null ||
        !_hasValidCoordinates(latitude, longitude) ||
        !_hasValidCoordinates(storedLatitude, storedLongitude)) {
      return const PlateSearchResult(found: false);
    }

    final effectiveRadiusKm = radiusKm.clamp(
      1,
      CaRismaAppConfig.defaultSearchRadiusKm,
    );
    final distanceMeters = Geolocator.distanceBetween(
      latitude,
      longitude,
      storedLatitude,
      storedLongitude,
    );
    final distanceKm = distanceMeters / 1000;

    if (distanceKm > effectiveRadiusKm) {
      return const PlateSearchResult(found: false);
    }

    return PlateSearchResult(
      found: true,
      targetUid: ownerUserId,
      displayName: displayName?.trim().isEmpty == true ? null : displayName,
      profilePhotoUrl: trustedProfilePhotoUrl(
        url: data['profilePhotoUrl'] ?? data['photoUrl'],
        userId: ownerUserId,
      ),
      isVerified: ownerIdentityVerified,
      distanceKm: distanceKm,
      vehicleId: vehicleId,
      plateKey: storedPlateKey,
      displayPlate: settingsShowPlate ? data['displayPlate'] as String? : null,
      countryCode: normalizedCountryCode,
      region: settingsShowPlate ? region?.trim().toUpperCase() : null,
      letters: settingsShowPlate ? letters?.trim().toUpperCase() : null,
      numbers: settingsShowPlate ? numbers?.trim().toUpperCase() : null,
      vehicleBrand: settingsShowVehicle
          ? data['vehicleBrand'] as String?
          : null,
      vehicleModel: settingsShowVehicle
          ? data['vehicleModel'] as String?
          : null,
      vehicleColor: settingsShowVehicle
          ? data['vehicleColor'] as String?
          : null,
      vehicleLabel: settingsShowVehicle
          ? data['vehicleLabel'] as String?
          : null,
    );
  }

  bool _hasValidCoordinates(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  Future<PlateContactRequestResult> _createContactRequestInFirestore({
    required String targetUid,
    required String countryCode,
    required String vehicleId,
    required String plateKey,
    String? receiverDisplayName,
    String? receiverPhotoUrl,
    String? displayPlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleLabel,
    String? requestReason,
    String? message,
  }) async {
    final sender = _auth.currentUser;
    if (sender == null) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'unauthenticated',
        message: 'Bitte melde dich an, um Kontakt anzufragen.',
      );
    }
    final receiverUserId = targetUid.trim();
    final normalizedCountryCode = countryCode.trim().toUpperCase();
    final normalizedVehicleId = vehicleId.trim();
    final normalizedPlateKey = plateKey.trim().toUpperCase();
    if (receiverUserId.isEmpty ||
        !const <String>{'DE', 'AT', 'CH'}.contains(normalizedCountryCode) ||
        normalizedVehicleId.isEmpty ||
        normalizedPlateKey.isEmpty) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'invalid-argument',
        message: 'Kontaktanfrage konnte nicht vorbereitet werden.',
      );
    }
    if (receiverUserId == sender.uid) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'invalid-argument',
        message: 'Du kannst dich nicht selbst kontaktieren.',
      );
    }
    final normalizedRequestReason = requestReason?.trim();
    final normalizedMessage = message?.trim();
    if (normalizedRequestReason == null ||
        normalizedRequestReason.isEmpty ||
        normalizedMessage == null ||
        normalizedMessage.isEmpty) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'invalid-argument',
        message: 'Bitte wähle einen Grund für deine Anfrage.',
      );
    }
    final callable = _functions.httpsCallable('createContactRequest');
    final response = await callable.call<Map<String, dynamic>>({
      'targetUserId': receiverUserId,
      'countryCode': normalizedCountryCode,
      'vehicleId': normalizedVehicleId,
      'plateKey': normalizedPlateKey,
      'requestReason': normalizedRequestReason,
      'message': normalizedMessage,
    });
    final data = Map<String, dynamic>.from(response.data);
    final requestId = data['requestId'] as String? ?? '';
    final chatId = data['chatId'] as String? ?? '';
    if (requestId.isEmpty || chatId.isEmpty) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'internal',
        message: 'Die Kontaktanfrage wurde unvollständig beantwortet.',
      );
    }
    return PlateContactRequestResult(
      requestId: requestId,
      chatId: chatId,
      status:
          data['status'] as String? ?? FirestoreContactRequestStatus.pending,
      created: data['created'] as bool? ?? false,
    );
  }

  Future<Map<String, dynamic>> _loadVisibilitySettingsForUser(
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .doc(
            '${CaRismaFirestorePaths.user(userId)}/'
            '${CaRismaFirestoreCollections.settings}/visibility',
          )
          .get();
      return snapshot.data() ?? const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Future<bool> _loadPublicIdentityVerification(String userId) async {
    try {
      final snapshot = await _firestore
          .doc(CaRismaFirestorePaths.publicProfile(userId))
          .get();
      final data = snapshot.data();
      return data?['verificationStatus'] == 'verified' ||
          data?['isVerified'] == true;
    } catch (_) {
      return false;
    }
  }

}
