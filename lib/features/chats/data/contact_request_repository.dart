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
    this.updatedAt,
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
  final DateTime? updatedAt;
  final String? chatId;

  bool get isPending {
    return status == ContactRequestStatus.pending;
  }

  bool get isAccepted {
    return status == ContactRequestStatus.accepted;
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
    DateTime? updatedAt,
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
      updatedAt: updatedAt ?? this.updatedAt,
      chatId: chatId ?? this.chatId,
    );
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
    required String chatId,
  });

  Future<ContactRequestRecord> declineRequest({
    required String requestId,
  });

  Future<ContactRequestRecord> withdrawRequest({
    required String requestId,
  });
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
    required String chatId,
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