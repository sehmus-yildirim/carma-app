import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carma_firestore_paths.dart';
import '../../../shared/firebase/carma_firestore_schema.dart';

enum ContactRequestStatus {
  pending,
  accepted,
  declined,
  withdrawn,
  expired,
  blocked,
}

class ContactRequestRecord {
  const ContactRequestRecord({
    required this.id,
    required this.senderUserId,
    required this.receiverUserId,
    required this.countryCode,
    required this.plateKey,
    required this.message,
    required this.status,
    required this.createdAt,
    this.senderDisplayName,
    this.receiverDisplayName,
    this.displayPlate,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleLabel,
    this.updatedAt,
    this.expiresAt,
    this.chatId,
  });

  final String id;
  final String senderUserId;
  final String receiverUserId;
  final String countryCode;
  final String plateKey;
  final String message;
  final ContactRequestStatus status;
  final DateTime createdAt;
  final String? senderDisplayName;
  final String? receiverDisplayName;
  final String? displayPlate;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehicleLabel;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final String? chatId;

  bool get isPending {
    return status == ContactRequestStatus.pending;
  }

  bool get isAccepted {
    return status == ContactRequestStatus.accepted;
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
    final title = vehicleTitle;

    if (title == 'Fahrzeug') {
      return 'Hey, ich möchte dich zu diesem Fahrzeug kontaktieren.';
    }

    return 'Hey, ich bin der Fahrer im $title.';
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
      ContactRequestStatus.withdrawn =>
        'ZurÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¼ckgezogen',
      ContactRequestStatus.expired => 'Abgelaufen',
      ContactRequestStatus.blocked => 'Blockiert',
    };
  }

  ContactRequestRecord copyWith({
    String? id,
    String? senderUserId,
    String? receiverUserId,
    String? countryCode,
    String? plateKey,
    String? message,
    ContactRequestStatus? status,
    DateTime? createdAt,
    String? senderDisplayName,
    String? receiverDisplayName,
    String? displayPlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleLabel,
    DateTime? updatedAt,
    DateTime? expiresAt,
    String? chatId,
  }) {
    return ContactRequestRecord(
      id: id ?? this.id,
      senderUserId: senderUserId ?? this.senderUserId,
      receiverUserId: receiverUserId ?? this.receiverUserId,
      countryCode: countryCode ?? this.countryCode,
      plateKey: plateKey ?? this.plateKey,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      receiverDisplayName: receiverDisplayName ?? this.receiverDisplayName,
      displayPlate: displayPlate ?? this.displayPlate,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      chatId: chatId ?? this.chatId,
    );
  }

  factory ContactRequestRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return ContactRequestRecord(
      id: document.id,
      senderUserId: data['senderUserId'] as String? ?? '',
      receiverUserId: data['receiverUserId'] as String? ?? '',
      countryCode: data['countryCode'] as String? ?? '',
      plateKey: data['plateKey'] as String? ?? '',
      message: data['message'] as String? ?? '',
      status: _statusFromName(data['status'] as String?),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime(1970),
      senderDisplayName: data['senderDisplayName'] as String?,
      receiverDisplayName: data['receiverDisplayName'] as String?,
      displayPlate: data['displayPlate'] as String?,
      vehicleBrand: data['vehicleBrand'] as String?,
      vehicleModel: data['vehicleModel'] as String?,
      vehicleColor: data['vehicleColor'] as String?,
      vehicleLabel: data['vehicleLabel'] as String?,
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
  FirestoreContactRequestRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection(CarmaFirestoreCollections.contactRequests);
  }

  Stream<List<ContactRequestRecord>> watchIncomingRequests({
    required String userId,
  }) {
    return _collection
        .where('receiverUserId', isEqualTo: userId)
        .where('status', isEqualTo: FirestoreContactRequestStatus.pending)
        .snapshots()
        .map(_recordsFromSnapshot);
  }

  Stream<List<ContactRequestRecord>> watchOutgoingRequests({
    required String userId,
  }) {
    return _collection
        .where('senderUserId', isEqualTo: userId)
        .where('status', isEqualTo: FirestoreContactRequestStatus.pending)
        .snapshots()
        .map(_recordsFromSnapshot);
  }

  @override
  Future<List<ContactRequestRecord>> loadIncomingRequests({
    required String userId,
  }) async {
    final snapshot = await _collection
        .where('receiverUserId', isEqualTo: userId)
        .where('status', isEqualTo: FirestoreContactRequestStatus.pending)
        .get();

    return _recordsFromSnapshot(snapshot);
  }

  @override
  Future<List<ContactRequestRecord>> loadOutgoingRequests({
    required String userId,
  }) async {
    final snapshot = await _collection
        .where('senderUserId', isEqualTo: userId)
        .where('status', isEqualTo: FirestoreContactRequestStatus.pending)
        .get();

    return _recordsFromSnapshot(snapshot);
  }

  @override
  Future<ContactRequestRecord> createRequest({
    required String senderUserId,
    required String receiverUserId,
    required String countryCode,
    required String plateKey,
    required String message,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(
      const Duration(
        hours: FirestoreDocumentDefaults.defaultRequestExpiryHours,
      ),
    );

    final document = await _collection.add({
      'senderUserId': senderUserId,
      'receiverUserId': receiverUserId,
      'targetUserId': receiverUserId,
      'countryCode': countryCode.toUpperCase(),
      'plateKey': plateKey.trim().toUpperCase(),
      'message': message.trim(),
      'status': FirestoreContactRequestStatus.pending,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isDeleted': false,
    });

    final snapshot = await document.get();
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

    await document.set(updateData, SetOptions(merge: true));

    final snapshot = await document.get();
    return ContactRequestRecord.fromFirestore(snapshot);
  }

  List<ContactRequestRecord> _recordsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final records = snapshot.docs
        .map(ContactRequestRecord.fromFirestore)
        .where((request) => !request.isAccepted)
        .toList();

    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
              request.status == ContactRequestStatus.pending,
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
              request.senderUserId == userId &&
              request.status == ContactRequestStatus.pending,
        )
        .toList();
  }

  @override
  Future<ContactRequestRecord> createRequest({
    required String senderUserId,
    required String receiverUserId,
    required String countryCode,
    required String plateKey,
    required String message,
  }) async {
    final now = DateTime.now();

    final request = ContactRequestRecord(
      id: 'local-request-${now.microsecondsSinceEpoch}',
      senderUserId: senderUserId,
      receiverUserId: receiverUserId,
      countryCode: countryCode.toUpperCase(),
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
