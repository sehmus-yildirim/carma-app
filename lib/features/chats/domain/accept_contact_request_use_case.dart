import 'package:firebase_core/firebase_core.dart';

import '../../profile/data/profile_connection_repository.dart';
import '../data/chat_repository.dart';
import '../data/contact_request_repository.dart';

class AcceptContactRequestResult {
  const AcceptContactRequestResult({
    required this.request,
    required this.chat,
    this.profileConnectionSynced = true,
  });

  final ContactRequestRecord request;
  final ChatRecord chat;
  final bool profileConnectionSynced;
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
  AcceptContactRequestUseCase({
    required ContactRequestRepository contactRequestRepository,
    required ChatRepository chatRepository,
    ProfileConnectionRepository? profileConnectionRepository,
  }) : _contactRequestRepository = contactRequestRepository,
       _chatRepository = chatRepository,
       _profileConnectionRepository =
           profileConnectionRepository ?? ProfileConnectionRepository();

  final ContactRequestRepository _contactRequestRepository;
  final ChatRepository _chatRepository;
  final ProfileConnectionRepository _profileConnectionRepository;

  Future<AcceptContactRequestResult> call({
    required ContactRequestRecord request,
  }) async {
    final chatId = 'request_${request.id.trim()}';

    if (request.isAccepted && request.chatId?.trim() == chatId) {
      final chat = await _loadOrCreateChat(
        request: request,
        chatId: request.chatId!,
        failureStage: 'open-linked-chat',
      );

      return _completeWithProfileConnection(
        AcceptContactRequestResult(request: request, chat: chat),
      );
    }

    if (request.isAccepted) {
      final result = await _createAndLinkAcceptedRequest(
        request: request,
        chatId: chatId,
      );
      return _completeWithProfileConnection(result);
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

      return _completeWithProfileConnection(
        AcceptContactRequestResult(request: acceptedRequest, chat: chat),
      );
    } on AcceptContactRequestFailure catch (error) {
      if (!_isPermissionDenied(error.cause)) {
        rethrow;
      }

      final result = await _acceptFirstAndCreateChat(
        request: request,
        chatId: chatId,
      );
      return _completeWithProfileConnection(result);
    }
  }

  Future<AcceptContactRequestResult> _completeWithProfileConnection(
    AcceptContactRequestResult result,
  ) async {
    try {
      await _profileConnectionRepository.ensureAcceptedConnection(
        request: result.request,
        chat: result.chat,
      );
      return result;
    } catch (_) {
      // The request and chat are already committed. Keep that successful core
      // flow usable and surface the optional profile sync separately in the UI.
      return AcceptContactRequestResult(
        request: result.request,
        chat: result.chat,
        profileConnectionSynced: false,
      );
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
        systemMessage: request.introMessage,
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
