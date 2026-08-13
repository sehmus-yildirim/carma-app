import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/config/carisma_app_config.dart';
import '../../../shared/firebase/carisma_firestore_paths.dart';
import '../../../shared/firebase/carisma_firestore_schema.dart';
import '../../../shared/models/search_credit.dart';
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
  static const String demoPlateKey = 'HHCR2026';
  static const String demoChatId = 'local-demo-hh-cr-2026';
  static const PlateSearchResult demoSearchResult = PlateSearchResult(
    found: true,
    targetUid: demoTargetUserId,
    displayName: 'plaqa Testnutzer',
    isVerified: true,
    distanceKm: 0.1,
    plateKey: demoPlateKey,
    displayPlate: 'HH-CR 2026',
    countryCode: 'DE',
    region: 'HH',
    letters: 'CR',
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

  String _contactRequestDocumentId({
    required String senderUserId,
    required String plateKey,
  }) {
    return '${senderUserId.trim()}_${plateKey.trim().toUpperCase()}';
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
    required String plateKey,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return null;
    }

    final normalizedTargetUid = targetUid.trim();
    final normalizedPlateKey = plateKey.trim().toUpperCase();

    if (normalizedTargetUid.isEmpty || normalizedPlateKey.isEmpty) {
      return null;
    }

    final snapshot = await _firestore
        .collection(CaRismaFirestoreCollections.contactRequests)
        .doc(
          _contactRequestDocumentId(
            senderUserId: currentUser.uid,
            plateKey: normalizedPlateKey,
          ),
        )
        .get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null || !_isRequestStillActive(data)) {
      return null;
    }

    final receiverUserId = (data['receiverUserId'] as String? ?? '').trim();

    if (receiverUserId.isNotEmpty && receiverUserId != normalizedTargetUid) {
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

    if (!isActive || isDeleted || !allowContactRequests) {
      return const PlateSearchResult(found: false);
    }

    final ownerUserId = data['ownerUserId'] as String?;
    final displayName = data['displayName'] as String?;
    final storedPlateKey = data['plateKey'] as String? ?? plateKey;
    final storedLatitude = (data['latitude'] as num?)?.toDouble();
    final storedLongitude = (data['longitude'] as num?)?.toDouble();
    final locationUpdatedAt = _dateTimeFromValue(data['locationUpdatedAt']);

    if (ownerUserId == null || ownerUserId.trim().isEmpty) {
      return const PlateSearchResult(found: false);
    }

    if (ownerUserId == _auth.currentUser?.uid) {
      return const PlateSearchResult(found: false);
    }

    final visibilitySettings = await _loadVisibilitySettingsForUser(
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
      profilePhotoUrl:
          (data['profilePhotoUrl'] as String?) ?? (data['photoUrl'] as String?),
      isVerified:
          data['verificationStatus'] == 'verified' ||
          data['isVerified'] == true,
      distanceKm: distanceKm,
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

    final senderUserId = sender.uid;
    final receiverUserId = targetUid.trim();
    final normalizedPlateKey = plateKey.trim().toUpperCase();

    if (receiverUserId.isEmpty || normalizedPlateKey.isEmpty) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'invalid-argument',
        message: 'Kontaktanfrage konnte nicht vorbereitet werden.',
      );
    }

    if (receiverUserId == senderUserId) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'invalid-argument',
        message: 'Du kannst dich nicht selbst kontaktieren.',
      );
    }

    final senderSummary = await _loadCurrentUserContactSummary(senderUserId);
    final normalizedDisplayPlate = displayPlate?.trim().isNotEmpty == true
        ? displayPlate!.trim()
        : normalizedPlateKey;
    final normalizedReceiverDisplayName =
        receiverDisplayName?.trim().isNotEmpty == true
        ? receiverDisplayName!.trim()
        : 'plaqa Nutzer';
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
    final normalizedRequestReason = requestReason?.trim();
    final normalizedMessage = message?.trim();

    if (normalizedMessage == null || normalizedMessage.isEmpty) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'invalid-argument',
        message: 'Bitte wähle einen Grund für deine Anfrage.',
      );
    }

    final contactFilters = await _loadContactFilterSettingsForUser(
      receiverUserId,
    );
    final requireVerifiedRequester =
        contactFilters['requireVerifiedRequester'] as bool? ?? false;
    final autoRejectUnverified =
        contactFilters['autoRejectUnverified'] as bool? ?? false;
    final quietModeUntil = _dateTimeFromValue(
      contactFilters['contactRequestQuietModeUntil'],
    );
    final allowedContactReasons =
        (contactFilters['allowedContactReasons'] as List<dynamic>?)
            ?.whereType<String>()
            .toSet() ??
        const <String>{
          'vehicle_question',
          'compliment',
          'meet_and_drive',
          'get_to_know',
        };

    if (quietModeUntil != null && quietModeUntil.isAfter(DateTime.now())) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'permission-denied',
        message: 'Dieser Nutzer nimmt gerade keine neuen Kontaktanfragen an.',
      );
    }

    if ((requireVerifiedRequester || autoRejectUnverified) &&
        !senderSummary.isVerified) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'permission-denied',
        message:
            'Dieser Nutzer erlaubt aktuell nur Anfragen von verifizierten Konten.',
      );
    }

    if (normalizedRequestReason == null ||
        normalizedRequestReason.isEmpty ||
        !allowedContactReasons.contains(normalizedRequestReason)) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'permission-denied',
        message: 'Dieser Anfragegrund ist für diesen Nutzer nicht erlaubt.',
      );
    }

    final now = DateTime.now();
    final expiresAt = now.add(
      const Duration(
        minutes: FirestoreDocumentDefaults.defaultRequestExpiryMinutes,
      ),
    );

    final document = _firestore
        .collection(CaRismaFirestoreCollections.contactRequests)
        .doc(
          _contactRequestDocumentId(
            senderUserId: senderUserId,
            plateKey: normalizedPlateKey,
          ),
        );
    final chatId = 'request_${document.id}';
    final creditDocument = _firestore.doc(
      CaRismaFirestorePaths.userSearchCredit(senderUserId),
    );
    final chatDocument = _firestore
        .collection(CaRismaFirestoreCollections.chats)
        .doc(chatId);

    final result = await _firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(document);
      final creditSnapshot = await transaction.get(creditDocument);
      final chatSnapshot = await transaction.get(chatDocument);

      final existingRequestData = requestSnapshot.data();
      final existingStatus = existingRequestData?['status'] as String?;
      if (existingRequestData != null &&
          _isRequestStillActive(existingRequestData) &&
          (existingStatus == FirestoreContactRequestStatus.pending ||
              existingStatus == FirestoreContactRequestStatus.accepted)) {
        if (!chatSnapshot.exists) {
          transaction.set(
            chatDocument,
            _chatDataForRequest(
              senderUserId: senderUserId,
              receiverUserId: receiverUserId,
              requestId: document.id,
              createdAt: now,
              senderDisplayName:
                  existingRequestData['senderDisplayName'] as String? ??
                  senderSummary.displayName,
              senderPhotoUrl:
                  existingRequestData['senderPhotoUrl'] as String? ??
                  senderSummary.photoUrl,
              receiverDisplayName:
                  existingRequestData['receiverDisplayName'] as String? ??
                  normalizedReceiverDisplayName,
              receiverPhotoUrl:
                  existingRequestData['receiverPhotoUrl'] as String? ??
                  receiverPhotoUrl?.trim(),
              displayPlate:
                  existingRequestData['displayPlate'] as String? ??
                  normalizedDisplayPlate,
              vehicleBrand:
                  existingRequestData['vehicleBrand'] as String? ??
                  normalizedVehicleBrand,
              vehicleModel:
                  existingRequestData['vehicleModel'] as String? ??
                  normalizedVehicleModel,
              vehicleColor:
                  existingRequestData['vehicleColor'] as String? ??
                  normalizedVehicleColor,
              vehicleLabel:
                  existingRequestData['vehicleLabel'] as String? ??
                  normalizedVehicleLabel,
              requestMessage:
                  existingRequestData['message'] as String? ??
                  normalizedMessage,
            ),
          );
        }

        return PlateContactRequestResult(
          requestId: document.id,
          chatId: chatId,
          status: existingStatus ?? FirestoreContactRequestStatus.pending,
          created: false,
        );
      }

      final creditData = creditSnapshot.data();
      if (creditData == null) {
        throw FirebaseException(
          plugin: 'plaqa',
          code: 'failed-precondition',
          message: 'Der Anfrage-Credit konnte nicht geladen werden.',
        );
      }

      final currentCredit = SearchCredit.fromMap(
        creditData,
      ).normalizeForCurrentMonth();
      if (!currentCredit.hasRemaining) {
        throw FirebaseException(
          plugin: 'plaqa',
          code: 'resource-exhausted',
          message: 'Du hast keine Anfragen mehr verfügbar.',
        );
      }

      final nextCredit = currentCredit.consume();

      transaction.set(document, {
        'senderUserId': senderUserId,
        'receiverUserId': receiverUserId,
        'targetUserId': receiverUserId,
        'plateKey': normalizedPlateKey,
        'senderDisplayName': senderSummary.displayName,
        'senderPhotoUrl': senderSummary.photoUrl,
        'receiverDisplayName': normalizedReceiverDisplayName,
        'receiverPhotoUrl': receiverPhotoUrl?.trim(),
        'displayPlate': normalizedDisplayPlate,
        'vehicleBrand': normalizedVehicleBrand,
        'vehicleModel': normalizedVehicleModel,
        'vehicleColor': normalizedVehicleColor,
        'vehicleLabel': normalizedVehicleLabel,
        'requestReason': normalizedRequestReason,
        'message': normalizedMessage,
        'status': FirestoreContactRequestStatus.pending,
        'chatId': chatId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isDeleted': false,
      });
      transaction.set(creditDocument, {
        ...nextCredit.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!chatSnapshot.exists) {
        transaction.set(
          chatDocument,
          _chatDataForRequest(
            senderUserId: senderUserId,
            receiverUserId: receiverUserId,
            requestId: document.id,
            createdAt: now,
            senderDisplayName: senderSummary.displayName,
            senderPhotoUrl: senderSummary.photoUrl,
            receiverDisplayName: normalizedReceiverDisplayName,
            receiverPhotoUrl: receiverPhotoUrl?.trim(),
            displayPlate: normalizedDisplayPlate,
            vehicleBrand: normalizedVehicleBrand,
            vehicleModel: normalizedVehicleModel,
            vehicleColor: normalizedVehicleColor,
            vehicleLabel: normalizedVehicleLabel,
            requestMessage: normalizedMessage,
          ),
        );
      }

      return PlateContactRequestResult(
        requestId: document.id,
        chatId: chatId,
        status: FirestoreContactRequestStatus.pending,
        created: true,
      );
    });

    await _ensureInitialContactMessage(
      result: result,
      message: normalizedMessage,
    );
    return result;
  }

  Future<void> _ensureInitialContactMessage({
    required PlateContactRequestResult result,
    required String? message,
  }) async {
    final sender = _auth.currentUser;
    final normalizedMessage = message?.trim() ?? '';
    final chatId = result.chatId.trim();
    final requestId = result.requestId.trim();

    if (sender == null ||
        normalizedMessage.isEmpty ||
        chatId.isEmpty ||
        requestId.isEmpty ||
        isDemoChat(chatId)) {
      return;
    }

    if (normalizedMessage.length >
        FirestoreDocumentDefaults.maxChatMessageLength) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'invalid-argument',
        message: 'Der automatische Nachrichtentext ist zu lang.',
      );
    }

    final senderUserId = sender.uid;
    final messageId = 'contact_request_${requestId}_initial';
    final chatDocument = _firestore.doc(CaRismaFirestorePaths.chat(chatId));
    final messageDocument = _firestore.doc(
      CaRismaFirestorePaths.chatMessage(chatId, messageId),
    );

    await _firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatDocument);
      final messageSnapshot = await transaction.get(messageDocument);

      if (messageSnapshot.exists) {
        return;
      }

      final chatData = chatSnapshot.data();
      final participants = (chatData?['participants'] as List<dynamic>? ?? [])
          .whereType<String>()
          .map((participant) => participant.trim())
          .where((participant) => participant.isNotEmpty)
          .toSet();
      final deletedBy = Map<String, dynamic>.from(
        chatData?['deletedBy'] as Map<dynamic, dynamic>? ?? const {},
      );
      final status = chatData?['status'];

      if (!chatSnapshot.exists ||
          participants.length != 2 ||
          !participants.contains(senderUserId) ||
          (status != FirestoreChatStatus.active &&
              status != FirestoreChatStatus.archived) ||
          deletedBy[senderUserId] == true) {
        throw FirebaseException(
          plugin: 'plaqa',
          code: 'failed-precondition',
          message: 'Der vorbereitete Chat ist noch nicht verfügbar.',
        );
      }

      final timestamp = Timestamp.fromDate(DateTime.now());

      transaction.set(messageDocument, {
        'chatId': chatId,
        'senderUserId': senderUserId,
        'type': FirestoreMessageTypes.text,
        'text': normalizedMessage,
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'isDeleted': false,
        'replyToMessageId': null,
        'replyToText': null,
      });
      transaction.set(chatDocument, {
        'lastMessage': normalizedMessage,
        'lastMessageAt': timestamp,
        'lastReadAtBy': {senderUserId: timestamp},
        'manualUnreadBy': {senderUserId: false},
        'manualUnreadUpdatedAtBy': {senderUserId: timestamp},
        'archivedBy': {
          for (final participant in participants) participant: false,
        },
        'archivedUpdatedAtBy': {
          for (final participant in participants) participant: timestamp,
        },
        'updatedAt': timestamp,
      }, SetOptions(merge: true));
    });
  }

  Map<String, Object?> _chatDataForRequest({
    required String senderUserId,
    required String receiverUserId,
    required String requestId,
    required DateTime createdAt,
    required String? senderDisplayName,
    required String? senderPhotoUrl,
    required String? receiverDisplayName,
    required String? receiverPhotoUrl,
    required String? displayPlate,
    required String? vehicleBrand,
    required String? vehicleModel,
    required String? vehicleColor,
    required String? vehicleLabel,
    required String requestMessage,
  }) {
    return {
      'participants': ([senderUserId, receiverUserId]..sort()),
      'status': FirestoreChatStatus.active,
      'requestId': requestId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(createdAt),
      'lastMessage': requestMessage,
      'lastMessageAt': Timestamp.fromDate(createdAt),
      'isDeleted': false,
      'senderUserId': senderUserId,
      'receiverUserId': receiverUserId,
      'senderDisplayName': senderDisplayName,
      'senderPhotoUrl': senderPhotoUrl,
      'receiverDisplayName': receiverDisplayName,
      'receiverPhotoUrl': receiverPhotoUrl,
      'displayPlate': displayPlate,
      'vehicleBrand': vehicleBrand,
      'vehicleModel': vehicleModel,
      'vehicleColor': vehicleColor,
      'vehicleLabel': vehicleLabel,
    };
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

  Future<_ContactUserSummary> _loadCurrentUserContactSummary(
    String userId,
  ) async {
    try {
      final profile = await _firestore
          .doc(CaRismaFirestorePaths.userProfile(userId))
          .get();

      final data = profile.data();

      if (data == null) {
        return _ContactUserSummary(
          displayName: _fallbackDisplayName(),
          photoUrl: _auth.currentUser?.photoURL,
          isVerified: false,
        );
      }

      final firstName = data['firstName'] as String? ?? '';
      final lastName = data['lastName'] as String? ?? '';
      final displayName = data['displayName'] as String? ?? '';
      final photoUrl =
          (data['profilePhotoUrl'] as String?) ?? (data['photoUrl'] as String?);
      final isVerified =
          data['verificationStatus'] == 'verified' ||
          data['isVerified'] == true;

      final fullName = '$firstName $lastName'.trim();

      if (fullName.isNotEmpty) {
        return _ContactUserSummary(
          displayName: fullName,
          photoUrl: photoUrl,
          isVerified: isVerified,
        );
      }

      if (displayName.trim().isNotEmpty) {
        return _ContactUserSummary(
          displayName: displayName.trim(),
          photoUrl: photoUrl,
          isVerified: isVerified,
        );
      }

      return _ContactUserSummary(
        displayName: _fallbackDisplayName(),
        photoUrl: photoUrl,
        isVerified: isVerified,
      );
    } catch (_) {
      return _ContactUserSummary(
        displayName: _fallbackDisplayName(),
        photoUrl: _auth.currentUser?.photoURL,
        isVerified: false,
      );
    }
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

  Future<Map<String, dynamic>> _loadContactFilterSettingsForUser(
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .doc(
            '${CaRismaFirestorePaths.user(userId)}/'
            '${CaRismaFirestoreCollections.settings}/contact_filters',
          )
          .get();
      return snapshot.data() ?? const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  String _fallbackDisplayName() {
    final authDisplayName = _auth.currentUser?.displayName;

    if (authDisplayName != null && authDisplayName.trim().isNotEmpty) {
      return authDisplayName.trim();
    }

    return 'plaqa Nutzer';
  }
}

class _ContactUserSummary {
  const _ContactUserSummary({
    required this.displayName,
    required this.isVerified,
    this.photoUrl,
  });

  final String displayName;
  final String? photoUrl;
  final bool isVerified;
}
