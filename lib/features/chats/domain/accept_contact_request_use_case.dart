import '../data/chat_repository.dart';
import '../data/contact_request_repository.dart';

class AcceptContactRequestResult {
  const AcceptContactRequestResult({required this.request, required this.chat});

  final ContactRequestRecord request;
  final ChatRecord chat;
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
    if (!request.isPending) {
      throw StateError('Only pending contact requests can be accepted.');
    }

    final chat = await _chatRepository.createChat(
      participants: [request.senderUserId, request.receiverUserId],
      requestId: request.id,
      systemMessage:
          'Kontaktanfrage angenommen. Ihr könnt jetzt geschützt schreiben.',
    );

    final acceptedRequest = await _contactRequestRepository.acceptRequest(
      requestId: request.id,
      chatId: chat.id,
    );

    return AcceptContactRequestResult(request: acceptedRequest, chat: chat);
  }
}
