import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../../../shared/domain/app_feature_gate.dart';
import '../../../shared/firebase/carisma_firestore_schema.dart';
import '../../../shared/models/carisma_models.dart';
import '../../../shared/plate/dach_plate_presentation.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_license_plate_preview.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../data/chat_attachment_storage.dart';
import '../data/chat_native_bridge.dart';
import '../data/chat_repository.dart';
import '../data/chat_story_repository.dart';
import '../data/contact_request_repository.dart';
import '../data/contact_request_repository.dart' as contact_requests;
import '../domain/accept_contact_request_use_case.dart';
import '../../settings/data/user_settings_repository.dart';
import '../../settings/data/app_runtime_preferences.dart';
import '../../profile/data/profile_connection_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/profile_vehicle_repository.dart';
import '../../profile/presentation/social_profile_screen.dart';
import '../../../shared/plate/plate_country_config.dart';

part 'chats/chat_shell.dart';
part 'chats/chat_models.dart';
part 'chats/chat_overview.dart';
part 'chats/chat_menus.dart';
part 'chats/chat_lists.dart';
part 'chats/chat_conversation.dart';
part 'chats/chat_message_bubbles.dart';
part 'chats/chat_composer.dart';
part 'chats/chat_media_gallery.dart';
part 'chats/chat_media_editor.dart';
part 'chats/chat_story_editor.dart';
part 'chats/chat_story_viewer.dart';

const Color _carismaBlue = CaRismaDesignTokens.bluePrimary;
const Color _carismaBlueLight = CaRismaDesignTokens.blueBright;
const Color _carismaBlueDark = CaRismaDesignTokens.blueDark;

const Color _myMessageBlueDark = CaRismaDesignTokens.bluePrimary;
const Color _myMessageBlue = CaRismaDesignTokens.bluePrimary;
const Color _myMessageBlueLight = CaRismaDesignTokens.bluePrimary;
const Color _myMessageBorder = CaRismaDesignTokens.bluePrimary;

const Color _myMessageCheckBlue = CaRismaDesignTokens.blueBright;

String _friendlyChatUiError(
  Object error, {
  String fallback = 'Die Chat-Aktion konnte nicht abgeschlossen werden.',
}) {
  final cause = error is AcceptContactRequestFailure ? error.cause : error;

  if (cause is ChatAttachmentStorageException) {
    return cause.message;
  }

  if (cause is FirebaseException) {
    return switch (cause.code) {
      'permission-denied' ||
      'unauthorized' => 'Du hast keine Berechtigung für diese Chat-Aktion.',
      'not-found' || 'object-not-found' =>
        'Die angeforderten Chat-Daten wurden nicht gefunden.',
      'unavailable' =>
        'Die Verbindung ist gerade nicht verfügbar. Bitte versuche es erneut.',
      'cancelled' || 'canceled' => 'Die Aktion wurde abgebrochen.',
      'retry-limit-exceeded' =>
        'Der Upload konnte nicht abgeschlossen werden. Bitte versuche es erneut.',
      'quota-exceeded' =>
        'Der Speicher ist gerade nicht verfügbar. Bitte versuche es später erneut.',
      _ => fallback,
    };
  }

  if (cause is StateError) {
    return _localizedChatErrorText(cause.message.toString(), fallback);
  }

  if (cause is ArgumentError) {
    return _localizedChatErrorText(
      cause.message?.toString() ?? '',
      'Die Eingabe ist ungültig.',
    );
  }

  return fallback;
}

String _localizedChatErrorText(String message, String fallback) {
  final normalized = message.trim().toLowerCase();

  if (normalized.isEmpty) {
    return fallback;
  }
  if (normalized.contains('contact request already exists')) {
    return 'Diese Kontaktanfrage besteht bereits.';
  }
  if (normalized.contains('contact request not found')) {
    return 'Die Kontaktanfrage wurde nicht gefunden.';
  }
  if (normalized.contains('only pending contact requests')) {
    return 'Nur offene Kontaktanfragen können angenommen werden.';
  }
  if (normalized.contains('chat not found')) {
    return 'Der Chat wurde nicht gefunden.';
  }
  if (normalized.contains('sender is not a participant')) {
    return 'Du bist kein Teilnehmer dieses Chats.';
  }
  if (normalized.contains('not open for new messages')) {
    return 'Dieser Chat ist für neue Nachrichten gesperrt.';
  }
  if (normalized.contains('deleted for the sender')) {
    return 'Dieser Chat wurde für dich gelöscht.';
  }
  if (normalized.contains('message not found')) {
    return 'Die Nachricht wurde nicht gefunden.';
  }
  if (normalized.contains('message text must not be empty')) {
    return 'Die Nachricht darf nicht leer sein.';
  }
  if (normalized.contains('message text is too long')) {
    return 'Die Nachricht ist zu lang.';
  }
  if (normalized.contains('requires exactly two participants')) {
    return 'Ein Chat benötigt genau zwei Teilnehmer.';
  }

  return message.trim();
}

Future<void> showProfileStoryViewer({
  required BuildContext context,
  required String currentUserId,
  required ChatStoryRecord story,
  List<ChatStoryRecord> stories = const <ChatStoryRecord>[],
}) async {
  final trimmedUserId = currentUserId.trim();
  final visibleStories =
      (stories.isEmpty ? <ChatStoryRecord>[story] : stories)
          .where(
            (candidate) =>
                !candidate.isExpired &&
                candidate.hasRenderableMedia &&
                (candidate.ownerUserId.trim() == trimmedUserId ||
                    candidate.viewerUserIds.any(
                      (userId) => userId.trim() == trimmedUserId,
                    )),
          )
          .toList(growable: false)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  if (trimmedUserId.isEmpty || visibleStories.isEmpty) {
    return;
  }

  final repository = ChatStoryRepository();

  Future<void> markStoryVisible(ChatStoryRecord visibleStory) async {
    if (visibleStory.ownerUserId.trim() == trimmedUserId) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    await repository.markStoryViewed(
      storyId: visibleStory.id,
      userId: trimmedUserId,
      displayName: currentUser?.displayName?.trim().isNotEmpty == true
          ? currentUser!.displayName!.trim()
          : 'plaqa Nutzer',
      photoUrl: currentUser?.photoURL,
    );
  }

  await showDialog<void>(
    context: context,
    builder: (context) => _StoryViewerDialog(
      stories: visibleStories,
      initialStoryId: story.id,
      currentUserId: trimmedUserId,
      onStoryVisible: (visibleStory) {
        markStoryVisible(visibleStory).catchError((_) {});
      },
      onShowViewers: (_) async {},
      onDeleteStory: (_) async {},
      onOpenSticker: (_) async {},
      onReplyStory: (_, _) async {},
      onVoteStoryPoll: (_, _) async => false,
      allowReplies: false,
      allowOwnerActions: false,
      enableStickerAction: false,
    ),
  );
}

class ProfileStoryCreationException implements Exception {
  const ProfileStoryCreationException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<ChatStoryRecord?> showProfileStoryComposer({
  required BuildContext context,
  required String currentUserId,
}) async {
  final userId = currentUserId.trim();
  if (userId.isEmpty) {
    throw const ProfileStoryCreationException(
      'Bitte melde dich neu an, um eine Story zu teilen.',
    );
  }

  final storyRepository = ChatStoryRepository();
  final attachmentStorage = ChatAttachmentStorage();
  final profileRepository = ProfileRepository();
  ChatImageUploadResult? uploadedStoryMedia;

  try {
    try {
      await storyRepository.deleteExpiredOwnStory(ownerUserId: userId);
    } catch (_) {
      // Eine fehlgeschlagene Bereinigung darf den Editor nicht blockieren.
    }

    if (!context.mounted) return null;
    final captureResult = await Navigator.of(context).push<_StoryCaptureResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _StoryCaptureScreen(
          imagePicker: ImagePicker(),
          useInAppGallery: true,
        ),
      ),
    );
    if (captureResult == null || captureResult.path.trim().isEmpty) return null;

    final profile = await profileRepository.getProfile(userId);
    final vehicleParts = <String>[
      if ((profile?.vehicleBrand ?? '').trim().isNotEmpty)
        profile!.vehicleBrand!.trim(),
      if ((profile?.vehicleModel ?? '').trim().isNotEmpty)
        profile!.vehicleModel!.trim(),
    ];
    final vehicleLabel = vehicleParts.join(' ').trim();
    final plateLabel = formatDisplayPlate(
      countryCode: (profile?.countryCode ?? profile?.country ?? 'DE').trim(),
      region: profile?.plateRegion?.trim() ?? '',
      letters: profile?.plateLetters?.trim() ?? '',
      numbers: profile?.plateNumbers?.trim() ?? '',
    );
    final stickerData = _StoryVehicleStickerData(
      vehicleLabel: vehicleLabel,
      plateLabel: plateLabel,
    );

    if (!context.mounted) return null;
    final draft = await Navigator.of(context).push<_StoryDraft>(
      MaterialPageRoute(
        builder: (_) => _StoryDraftEditorScreen(
          mediaPath: captureResult.path,
          isVideo: captureResult.isVideo,
          vehicleStickerData: stickerData.isComplete ? stickerData : null,
        ),
      ),
    );
    if (draft == null) return null;

    List<ChatRecord> chats;
    try {
      chats = await FirestoreChatRepository().loadChats(userId: userId);
    } catch (_) {
      // Eine eigene Story bleibt auch ohne verfügbare Chatliste möglich.
      chats = const <ChatRecord>[];
    }
    final viewerUserIds = _profileStoryViewerUserIds(
      chats: chats,
      currentUserId: userId,
    );
    final storyId = DateTime.now().microsecondsSinceEpoch.toString();
    uploadedStoryMedia = draft.isVideo
        ? await attachmentStorage.uploadChatStoryVideo(
            userId: userId,
            storyId: storyId,
            file: File(draft.mediaPath),
          )
        : await attachmentStorage.uploadChatStoryImage(
            userId: userId,
            storyId: storyId,
            file: File(draft.mediaPath),
          );

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final profileDisplayName = profile?.displayName.trim() ?? '';
    final firstName = profile?.firstName.trim() ?? '';
    final ownerDisplayName = profileDisplayName.isNotEmpty
        ? profileDisplayName
        : firstName.isNotEmpty
        ? firstName
        : firebaseUser?.displayName?.trim().isNotEmpty == true
        ? firebaseUser!.displayName!.trim()
        : 'plaqa Nutzer';
    final profilePhotoUrl = profile?.photoUrl?.trim() ?? '';
    final authPhotoUrl = firebaseUser?.photoURL?.trim() ?? '';

    await storyRepository.setOwnImageStory(
      storyId: storyId,
      ownerUserId: userId,
      ownerDisplayName: ownerDisplayName,
      ownerPhotoUrl: profilePhotoUrl.isNotEmpty
          ? profilePhotoUrl
          : authPhotoUrl,
      viewerUserIds: viewerUserIds,
      imageUrl: draft.isVideo ? '' : uploadedStoryMedia.url,
      imagePath: draft.isVideo ? '' : uploadedStoryMedia.path,
      mediaType: draft.isVideo ? 'video' : 'image',
      videoUrl: draft.isVideo ? uploadedStoryMedia.url : '',
      videoPath: draft.isVideo ? uploadedStoryMedia.path : '',
      videoIsMuted: draft.videoIsMuted,
      text: draft.text,
      textColorValue: draft.textColor.toARGB32(),
      textFontFamily: draft.textFontFamily,
      textIsBold: draft.textIsBold,
      textIsItalic: draft.textIsItalic,
      textIsUnderline: draft.textIsUnderline,
      textAlign: draft.textAlign,
      textAlignmentX: (draft.textAlignment.x + 1) / 2,
      textAlignmentY: (draft.textAlignment.y + 1) / 2,
      filterType: draft.filterType,
      stickers: <ChatStoryStickerRecord>[
        for (final sticker in draft.stickers)
          ChatStoryStickerRecord(
            type: sticker.type,
            label: sticker.label,
            payload: sticker.payload,
            alignmentX: (sticker.alignment.x + 1) / 2,
            alignmentY: (sticker.alignment.y + 1) / 2,
          ),
      ],
    );

    try {
      final downloadUrl = await attachmentStorage.getDownloadUrl(
        path: uploadedStoryMedia.path,
      );
      await storyRepository.updateOwnStoryMediaUrl(
        storyId: storyId,
        ownerUserId: userId,
        mediaType: draft.isVideo ? 'video' : 'image',
        url: downloadUrl,
      );
    } catch (_) {
      // Die bereits gespeicherte Story bleibt bei einem URL-Refresh gültig.
    }

    uploadedStoryMedia = null;
    return storyRepository.getStoryById(storyId);
  } catch (error) {
    final uploadedPath = uploadedStoryMedia?.path.trim() ?? '';
    Object? cleanupError;
    if (uploadedPath.isNotEmpty) {
      try {
        await attachmentStorage.deleteUploadedStoryMedia(path: uploadedPath);
      } catch (caughtCleanupError) {
        cleanupError = caughtCleanupError;
      }
    }

    final message = error is ChatAttachmentStorageException
        ? error.message
        : error is ProfileStoryCreationException
        ? error.message
        : 'Story konnte nicht gespeichert werden: $error';
    throw ProfileStoryCreationException(
      cleanupError == null
          ? message
          : '$message Die hochgeladene Datei konnte nicht bereinigt werden.',
    );
  }
}

List<String> _profileStoryViewerUserIds({
  required List<ChatRecord> chats,
  required String currentUserId,
}) {
  final userId = currentUserId.trim();
  final viewerUserIds = <String>{userId};

  for (final chat in chats) {
    final participantIds = chat.participants
        .map((participant) => participant.trim())
        .where((participant) => participant.isNotEmpty)
        .toSet();
    final canUseChat =
        (chat.status == ChatStatus.active ||
            chat.status == ChatStatus.archived) &&
        participantIds.length == 2 &&
        participantIds.contains(userId) &&
        !chat.isDeletedFor(userId);
    if (!canUseChat) continue;

    for (final participantId in participantIds) {
      if (!chat.isDeletedFor(participantId)) viewerUserIds.add(participantId);
    }
  }

  final otherViewerUserIds =
      viewerUserIds.where((viewerUserId) => viewerUserId != userId).toList()
        ..sort();
  return <String>[userId, ...otherViewerUserIds.take(199)];
}

Route<void> buildChatConversationRoute({
  required String chatId,
  String displayName = 'plaqa Nutzer',
  String? profilePhotoUrl,
  String vehicleModel = 'Fahrzeug',
  String vehicleColor = '',
  String? displayPlate,
  String? profileUserId,
}) {
  return MaterialPageRoute<void>(
    builder: (_) => _ChatConversationScreen(
      chatId: chatId,
      initialMessages: const <_LocalChatMessage>[],
      displayName: displayName,
      profilePhotoUrl: profilePhotoUrl,
      vehicleModel: vehicleModel,
      vehicleColor: vehicleColor,
      displayPlate: displayPlate,
      profileUserId: profileUserId,
      isOnline: false,
    ),
  );
}
