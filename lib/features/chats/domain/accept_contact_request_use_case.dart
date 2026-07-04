import 'package:firebase_core/firebase_core.dart';

import '../data/chat_repository.dart';
import '../data/contact_request_repository.dart';

class AcceptContactRequestResult {
  const AcceptContactRequestResult({required this.request, required this.chat});

  final ContactRequestRecord request;
  final ChatRecord chat;
}

class AcceptContactRequestFailure implements Exception {
  const AcceptContactRequestFailure({
    required this.stage,
    required this.requestId,
    required this.chatId,
    required this.cause,
  });

  final String stage;
  final String requestId;
  final String chatId;
  final Object cause;

  @override
  String toString() {
    return 'stage=$stage request=$requestId chat=$chatId cause=$cause';
  }
}

class AcceptContactRequestUseCase {
  const AcceptContactRequestUseCase({
    required ContactRequestRepository contactRequestRepository,
    required ChatRepository chatRepository,
  }) : _contactRequestRepository = contactRequestRepository,
       _chatRepository = chatRepository;

  final ContactRequestRepository _contactRequestRepository;
  final ChatRepository _chatRepository;

  Future<AcceptContactRequestResult> call({
    required ContactRequestRecord request,
  }) async {
    final chatId = 'request_${request.id.trim()}';

    if (request.isAccepted && request.hasLinkedChat) {
      final chat = await _loadOrCreateChat(
        request: request,
        chatId: request.chatId!,
        failureStage: 'open-linked-chat',
      );

      return AcceptContactRequestResult(request: request, chat: chat);
    }

    if (request.isAccepted && !request.hasLinkedChat) {
      return _createAndLinkAcceptedRequest(request: request, chatId: chatId);
    }

    if (!request.isPending) {
      throw StateError('Only pending contact requests can be accepted.');
    }

    try {
      final chat = await _loadOrCreateChat(
        request: request,
        chatId: chatId,
        failureStage: 'create-chat',
      );
      final acceptedRequest = await _acceptRequest(
        request,
        chat.id,
        failureStage: 'accept-request',
      );

      return AcceptContactRequestResult(request: acceptedRequest, chat: chat);
    } on AcceptContactRequestFailure catch (error) {
      if (!_isPermissionDenied(error.cause)) {
        rethrow;
      }

      return _acceptFirstAndCreateChat(request: request, chatId: chatId);
    }
  }

  Future<AcceptContactRequestResult> _createAndLinkAcceptedRequest({
    required ContactRequestRecord request,
    required String chatId,
  }) async {
    final chat = await _loadOrCreateChat(
      request: request,
      chatId: chatId,
      failureStage: 'repair-chat',
    );
    final linkedRequest = await _acceptRequest(
      request,
      chat.id,
      failureStage: 'repair-link-chat',
    );

    return AcceptContactRequestResult(request: linkedRequest, chat: chat);
  }

  Future<AcceptContactRequestResult> _acceptFirstAndCreateChat({
    required ContactRequestRecord request,
    required String chatId,
  }) async {
    final acceptedWithoutChat = await _acceptRequest(
      request,
      null,
      failureStage: 'accept-request-first',
    );
    final chat = await _loadOrCreateChat(
      request: acceptedWithoutChat,
      chatId: chatId,
      failureStage: 'create-chat-after-accept',
    );
    final linkedRequest = await _acceptRequest(
      acceptedWithoutChat,
      chat.id,
      failureStage: 'link-chat',
    );

    return AcceptContactRequestResult(request: linkedRequest, chat: chat);
  }

  Future<ChatRecord> _loadOrCreateChat({
    required ContactRequestRecord request,
    required String chatId,
    required String failureStage,
  }) async {
    final existingChat = await _tryLoadChat(chatId);

    if (existingChat != null) {
      return existingChat;
    }

    try {
      return await _chatRepository.createChat(
        participants: [request.senderUserId, request.receiverUserId],
        requestId: request.id,
        systemMessage:
            'Kontaktanfrage angenommen. Ihr könnt jetzt geschützt schreiben.',
        senderUserId: request.senderUserId,
        receiverUserId: request.receiverUserId,
        senderDisplayName: request.senderDisplayName,
        receiverDisplayName: request.receiverDisplayName,
        senderPhotoUrl: request.senderPhotoUrl,
        receiverPhotoUrl: request.receiverPhotoUrl,
        displayPlate: request.displayPlate,
        vehicleBrand: request.vehicleBrand,
        vehicleModel: request.vehicleModel,
        vehicleColor: request.vehicleColor,
        vehicleLabel: request.vehicleLabel,
      );
    } catch (error) {
      final fallbackChat =
          error is FirebaseException && error.code == 'permission-denied'
          ? await _tryLoadChat(chatId)
          : null;

      if (fallbackChat != null) {
        return fallbackChat;
      }

      throw AcceptContactRequestFailure(
        stage: failureStage,
        requestId: request.id,
        chatId: chatId,
        cause: error,
      );
    }
  }

  Future<ContactRequestRecord> _acceptRequest(
    ContactRequestRecord request,
    String? chatId, {
    required String failureStage,
  }) async {
    try {
      return await _contactRequestRepository.acceptRequest(
        requestId: request.id,
        chatId: chatId,
      );
    } catch (error) {
      throw AcceptContactRequestFailure(
        stage: failureStage,
        requestId: request.id,
        chatId: chatId ?? '',
        cause: error,
      );
    }
  }

  bool _isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied';
  }

  Future<ChatRecord?> _tryLoadChat(String chatId) async {
    try {
      return await _chatRepository.loadChat(chatId: chatId);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return null;
      }

      rethrow;
    }
  }
}
