import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import '../../../shared/security/trusted_firebase_media_url.dart';

enum ContactRequestStatus {
  pending,
  accepted,
  declined,
  withdrawn,
  expired,
  blocked,
}

String _contactRequestDedupeKey({
  required String senderUserId,
  required String receiverUserId,
  required String countryCode,
  required String vehicleId,
  required String plateKey,
}) {
  return [
    senderUserId.trim(),
    receiverUserId.trim(),
    countryCode.trim().toUpperCase(),
    vehicleId.trim(),
    plateKey.trim().toUpperCase(),
  ].join('|');
}

class ContactRequestRecord {
  const ContactRequestRecord({
    required this.id,
    required this.senderUserId,
    required this.receiverUserId,
    required this.countryCode,
    required this.vehicleId,
    required this.plateKey,
    required this.message,
    required this.status,
    required this.createdAt,
    this.senderDisplayName,
    this.receiverDisplayName,
    this.senderPhotoUrl,
    this.receiverPhotoUrl,
    this.displayPlate,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleLabel,
    this.requestReason,
    this.updatedAt,
    this.expiresAt,
    this.chatId,
  });

  final String id;
  final String senderUserId;
  final String receiverUserId;
  final String countryCode;
  final String vehicleId;
  final String plateKey;
  final String message;
  final ContactRequestStatus status;
  final DateTime createdAt;
  final String? senderDisplayName;
  final String? receiverDisplayName;
  final String? senderPhotoUrl;
  final String? receiverPhotoUrl;
  final String? displayPlate;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehicleLabel;
  final String? requestReason;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final String? chatId;

  bool get isPending {
    return status == ContactRequestStatus.pending;
  }

  bool get isAccepted {
    return status == ContactRequestStatus.accepted;
  }

  bool get hasLinkedChat {
    return chatId?.trim().isNotEmpty ?? false;
  }

  bool get isExpiredByTime {
    final expiry = expiresAt;

    if (expiry == null) {
      return false;
    }

    return expiry.isBefore(DateTime.now());
  }

  bool get isVisibleInRequestLists {
    return !isExpiredByTime && isPending;
  }

  String get vehicleTitle {
    final label = vehicleLabel?.trim();

    if (label != null && label.isNotEmpty) {
      return label;
    }

    final parts = <String>[
      if (vehicleColor != null && vehicleColor!.trim().isNotEmpty)
        _vehicleColorAdjective(vehicleColor!),
      if (vehicleBrand != null && vehicleBrand!.trim().isNotEmpty)
        vehicleBrand!.trim(),
      if (vehicleModel != null && vehicleModel!.trim().isNotEmpty)
        vehicleModel!.trim(),
    ];

    final title = parts.join(' ').trim();
    return title.isEmpty ? 'Fahrzeug' : title;
  }

  String get introMessage {
    final requestMessage = message.trim();

    if (requestMessage.isNotEmpty) {
      return requestMessage;
    }

    final title = vehicleTitle;

    if (title == 'Fahrzeug') {
      return 'Hey, ich bin der Fahrer dieses Fahrzeugs. Ich bin eben an dir vorbeigefahren.';
    }

    return 'Hey, ich bin der Fahrer im $title. Ich bin eben an dir vorbeigefahren.';
  }

  String? profilePhotoUrl({required bool isIncoming}) {
    final candidate = isIncoming ? senderPhotoUrl : receiverPhotoUrl;
    final trimmed = candidate?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _vehicleColorAdjective(String color) {
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

  String get statusLabel {
    return switch (status) {
      ContactRequestStatus.pending => 'Ausstehend',
      ContactRequestStatus.accepted => 'Angenommen',
      ContactRequestStatus.declined => 'Abgelehnt',
      ContactRequestStatus.withdrawn => 'Zurückgezogen',
      ContactRequestStatus.expired => 'Abgelaufen',
      ContactRequestStatus.blocked => 'Blockiert',
    };
  }

  ContactRequestRecord copyWith({
    String? id,
    String? senderUserId,
    String? receiverUserId,
    String? countryCode,
    String? vehicleId,
    String? plateKey,
    String? message,
    ContactRequestStatus? status,
    DateTime? createdAt,
    String? senderDisplayName,
    String? receiverDisplayName,
    String? senderPhotoUrl,
    String? receiverPhotoUrl,
    String? displayPlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleLabel,
    String? requestReason,
    DateTime? updatedAt,
    DateTime? expiresAt,
    String? chatId,
  }) {
    return ContactRequestRecord(
      id: id ?? this.id,
      senderUserId: senderUserId ?? this.senderUserId,
      receiverUserId: receiverUserId ?? this.receiverUserId,
      countryCode: countryCode ?? this.countryCode,
      vehicleId: vehicleId ?? this.vehicleId,
      plateKey: plateKey ?? this.plateKey,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      receiverDisplayName: receiverDisplayName ?? this.receiverDisplayName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      receiverPhotoUrl: receiverPhotoUrl ?? this.receiverPhotoUrl,
      displayPlate: displayPlate ?? this.displayPlate,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      requestReason: requestReason ?? this.requestReason,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      chatId: chatId ?? this.chatId,
    );
  }

  factory ContactRequestRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final senderUserId = data['senderUserId'] as String? ?? '';
    final receiverUserId = data['receiverUserId'] as String? ?? '';

    return ContactRequestRecord(
      id: document.id,
      senderUserId: senderUserId,
      receiverUserId: receiverUserId,
      countryCode: data['countryCode'] as String? ?? '',
      vehicleId: data['vehicleId'] as String? ?? '',
      plateKey: data['plateKey'] as String? ?? '',
      message: data['message'] as String? ?? '',
      status: _statusFromName(data['status'] as String?),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime(1970),
      senderDisplayName: data['senderDisplayName'] as String?,
      receiverDisplayName: data['receiverDisplayName'] as String?,
      senderPhotoUrl: trustedProfilePhotoUrl(
        url: data['senderPhotoUrl'],
        userId: senderUserId,
      ),
      receiverPhotoUrl: trustedProfilePhotoUrl(
        url: data['receiverPhotoUrl'],
        userId: receiverUserId,
      ),
      displayPlate: data['displayPlate'] as String?,
      vehicleBrand: data['vehicleBrand'] as String?,
      vehicleModel: data['vehicleModel'] as String?,
      vehicleColor: data['vehicleColor'] as String?,
      vehicleLabel: data['vehicleLabel'] as String?,
      requestReason: data['requestReason'] as String?,
      updatedAt: _dateTimeFromValue(data['updatedAt']),
      expiresAt: _dateTimeFromValue(data['expiresAt']),
      chatId: data['chatId'] as String?,
    );
  }

  static ContactRequestStatus _statusFromName(String? name) {
    return ContactRequestStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => ContactRequestStatus.pending,
    );
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}

abstract class ContactRequestRepository {
  Future<List<ContactRequestRecord>> loadIncomingRequests({
    required String userId,
  });

  Future<List<ContactRequestRecord>> loadOutgoingRequests({
    required String userId,
  });

  Future<ContactRequestRecord> createRequest({
    required String senderUserId,
    required String receiverUserId,
    required String countryCode,
    required String vehicleId,
    required String plateKey,
    required String message,
  });

  Future<ContactRequestRecord> acceptRequest({
    required String requestId,
    String? chatId,
  });

  Future<ContactRequestRecord> declineRequest({required String requestId});

  Future<ContactRequestRecord> withdrawRequest({required String requestId});
}

class FirestoreContactRequestRepository implements ContactRequestRepository {
  FirestoreContactRequestRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection(CaRismaFirestoreCollections.contactRequests);
  }

  Future<ContactRequestRecord?> loadRequestById({
    required String requestId,
  }) async {
    final trimmedRequestId = requestId.trim();

    if (trimmedRequestId.isEmpty) {
      return null;
    }

    final snapshot = await _collection.doc(trimmedRequestId).get();
    return snapshot.exists
        ? ContactRequestRecord.fromFirestore(snapshot)
        : null;
  }

  Stream<ContactRequestRecord?> watchRequestById({required String requestId}) {
    final trimmedRequestId = requestId.trim();

    if (trimmedRequestId.isEmpty) {
      return Stream<ContactRequestRecord?>.value(null);
    }

    return _collection
        .doc(trimmedRequestId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? ContactRequestRecord.fromFirestore(snapshot)
              : null,
        );
  }

  Stream<List<ContactRequestRecord>> watchIncomingRequests({
    required String userId,
  }) {
    return _collection
        .where('receiverUserId', isEqualTo: userId)
        .snapshots()
        .map(_recordsFromSnapshot);
  }

  Stream<List<ContactRequestRecord>> watchIncomingRequestStates({
    required String userId,
  }) {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return Stream<List<ContactRequestRecord>>.value(
        const <ContactRequestRecord>[],
      );
    }

    return _collection
        .where('receiverUserId', isEqualTo: trimmedUserId)
        .snapshots()
        .map((snapshot) {
          final records =
              snapshot.docs
                  .map(ContactRequestRecord.fromFirestore)
                  .toList(growable: false)
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return records;
        });
  }

  Stream<List<ContactRequestRecord>> watchOutgoingRequests({
    required String userId,
  }) {
    return _collection
        .where('senderUserId', isEqualTo: userId)
        .snapshots()
        .map(_recordsFromSnapshot);
  }

  @override
  Future<List<ContactRequestRecord>> loadIncomingRequests({
    required String userId,
  }) async {
    final snapshot = await _collection
        .where('receiverUserId', isEqualTo: userId)
        .get();

    return _recordsFromSnapshot(snapshot);
  }

  @override
  Future<List<ContactRequestRecord>> loadOutgoingRequests({
    required String userId,
  }) async {
    final snapshot = await _collection
        .where('senderUserId', isEqualTo: userId)
        .get();

    return _recordsFromSnapshot(snapshot);
  }

  @override
  Future<ContactRequestRecord> createRequest({
    required String senderUserId,
    required String receiverUserId,
    required String countryCode,
    required String vehicleId,
    required String plateKey,
    required String message,
  }) async {
    final trimmedSenderUserId = senderUserId.trim();
    final trimmedReceiverUserId = receiverUserId.trim();
    final normalizedPlateKey = plateKey.trim().toUpperCase();
    final normalizedCountryCode = countryCode.trim().toUpperCase();
    final normalizedVehicleId = vehicleId.trim();
    if (trimmedSenderUserId.isEmpty ||
        trimmedReceiverUserId.isEmpty ||
        normalizedCountryCode.isEmpty ||
        normalizedVehicleId.isEmpty ||
        normalizedPlateKey.isEmpty ||
        message.trim().isEmpty) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'invalid-argument',
        message: 'Die Kontaktanfrage ist unvollständig.',
      );
    }
    final response = await _functions
        .httpsCallable('createContactRequest')
        .call<Map<String, dynamic>>({
          'targetUserId': trimmedReceiverUserId,
          'countryCode': normalizedCountryCode,
          'vehicleId': normalizedVehicleId,
          'plateKey': normalizedPlateKey,
          'requestReason': 'vehicle_question',
          'message': message.trim(),
        });
    final data = Map<String, dynamic>.from(response.data);
    final requestId = data['requestId'] as String? ?? '';
    if (requestId.isEmpty) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'internal',
        message: 'Die Kontaktanfrage wurde unvollständig beantwortet.',
      );
    }
    final snapshot = await _collection.doc(requestId).get();
    if (!snapshot.exists) {
      throw FirebaseException(
        plugin: 'plaqa',
        code: 'not-found',
        message: 'Die Kontaktanfrage konnte nicht geladen werden.',
      );
    }
    return ContactRequestRecord.fromFirestore(snapshot);
  }

  @override
  Future<ContactRequestRecord> acceptRequest({
    required String requestId,
    String? chatId,
  }) async {
    return _updateRequest(
      requestId: requestId,
      status: ContactRequestStatus.accepted,
      chatId: chatId,
    );
  }

  @override
  Future<ContactRequestRecord> declineRequest({
    required String requestId,
  }) async {
    return _updateRequest(
      requestId: requestId,
      status: ContactRequestStatus.declined,
    );
  }

  @override
  Future<ContactRequestRecord> withdrawRequest({
    required String requestId,
  }) async {
    return _updateRequest(
      requestId: requestId,
      status: ContactRequestStatus.withdrawn,
    );
  }

  Future<ContactRequestRecord> _updateRequest({
    required String requestId,
    required ContactRequestStatus status,
    String? chatId,
  }) async {
    final document = _collection.doc(requestId);

    final updateData = <String, dynamic>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (chatId != null) {
      updateData['chatId'] = chatId;
    }

    await document.update(updateData);

    final snapshot = await document.get();
    return ContactRequestRecord.fromFirestore(snapshot);
  }

  List<ContactRequestRecord> _recordsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final recordsByTarget = <String, ContactRequestRecord>{};

    for (final request
        in snapshot.docs
            .map(ContactRequestRecord.fromFirestore)
            .where((request) => request.isVisibleInRequestLists)) {
      final key = _contactRequestDedupeKey(
        senderUserId: request.senderUserId,
        receiverUserId: request.receiverUserId,
        countryCode: request.countryCode,
        vehicleId: request.vehicleId,
        plateKey: request.plateKey,
      );
      final existing = recordsByTarget[key];

      if (existing == null || request.createdAt.isAfter(existing.createdAt)) {
        recordsByTarget[key] = request;
      }
    }

    final records = recordsByTarget.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }
}

class LocalContactRequestRepository implements ContactRequestRepository {
  LocalContactRequestRepository({
    List<ContactRequestRecord> seedRequests = const [],
  }) : _requests = [...seedRequests];

  final List<ContactRequestRecord> _requests;

  @override
  Future<List<ContactRequestRecord>> loadIncomingRequests({
    required String userId,
  }) async {
    return _requests
        .where(
          (request) =>
              request.receiverUserId == userId &&
              request.isVisibleInRequestLists,
        )
        .toList();
  }

  @override
  Future<List<ContactRequestRecord>> loadOutgoingRequests({
    required String userId,
  }) async {
    return _requests
        .where(
          (request) =>
              request.senderUserId == userId && request.isVisibleInRequestLists,
        )
        .toList();
  }

  @override
  Future<ContactRequestRecord> createRequest({
    required String senderUserId,
    required String receiverUserId,
    required String countryCode,
    required String vehicleId,
    required String plateKey,
    required String message,
  }) async {
    final duplicateKey = _contactRequestDedupeKey(
      senderUserId: senderUserId,
      receiverUserId: receiverUserId,
      countryCode: countryCode,
      vehicleId: vehicleId,
      plateKey: plateKey,
    );
    final hasExistingRequest = _requests.any((request) {
      return _contactRequestDedupeKey(
                senderUserId: request.senderUserId,
                receiverUserId: request.receiverUserId,
                countryCode: request.countryCode,
                vehicleId: request.vehicleId,
                plateKey: request.plateKey,
              ) ==
              duplicateKey &&
          !request.isExpiredByTime;
    });

    if (hasExistingRequest) {
      throw StateError('Contact request already exists.');
    }

    final now = DateTime.now();

    final request = ContactRequestRecord(
      id: 'local-request-${now.microsecondsSinceEpoch}',
      senderUserId: senderUserId,
      receiverUserId: receiverUserId,
      countryCode: countryCode.toUpperCase(),
      vehicleId: vehicleId,
      plateKey: plateKey,
      message: message,
      status: ContactRequestStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    _requests.add(request);
    return request;
  }

  @override
  Future<ContactRequestRecord> acceptRequest({
    required String requestId,
    String? chatId,
  }) async {
    return _updateRequest(
      requestId: requestId,
      status: ContactRequestStatus.accepted,
      chatId: chatId,
    );
  }

  @override
  Future<ContactRequestRecord> declineRequest({
    required String requestId,
  }) async {
    return _updateRequest(
      requestId: requestId,
      status: ContactRequestStatus.declined,
    );
  }

  @override
  Future<ContactRequestRecord> withdrawRequest({
    required String requestId,
  }) async {
    return _updateRequest(
      requestId: requestId,
      status: ContactRequestStatus.withdrawn,
    );
  }

  ContactRequestRecord _updateRequest({
    required String requestId,
    required ContactRequestStatus status,
    String? chatId,
  }) {
    final index = _requests.indexWhere((request) => request.id == requestId);

    if (index < 0) {
      throw StateError('Contact request not found: $requestId');
    }

    final updated = _requests[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
      chatId: chatId,
    );

    _requests[index] = updated;
    return updated;
  }
}
