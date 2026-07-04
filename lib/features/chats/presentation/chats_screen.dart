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
import 'package:video_player/video_player.dart';

import '../../../shared/domain/app_feature_gate.dart';
import '../../../shared/firebase/carisma_firestore_schema.dart';
import '../../../shared/models/carisma_models.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_page_header.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../data/chat_attachment_storage.dart';
import '../data/chat_native_bridge.dart';
import '../data/chat_repository.dart';
import '../data/chat_story_repository.dart';
import '../data/contact_request_repository.dart';
import '../domain/accept_contact_request_use_case.dart';
import '../../profile/data/profile_repository.dart';
import '../../../shared/plate/plate_country_config.dart';

part 'chats/chat_shell.dart';
part 'chats/chat_models.dart';
part 'chats/chat_overview.dart';
part 'chats/chat_menus.dart';
part 'chats/chat_lists.dart';
part 'chats/chat_conversation.dart';
part 'chats/chat_message_bubbles.dart';
part 'chats/chat_composer.dart';
part 'chats/chat_story_editor.dart';
part 'chats/chat_story_viewer.dart';

const Color _carismaBlue = CaRismaDesignTokens.bluePrimary;
const Color _carismaBlueLight = CaRismaDesignTokens.blueBright;
const Color _carismaBlueDark = CaRismaDesignTokens.blueDark;

const Color _myMessageBlueDark = Color(0xFF052142);
const Color _myMessageBlue = Color(0xFF0A3C78);
const Color _myMessageBlueLight = Color(0xFF105EA8);
const Color _myMessageBorder = Color(0xFF1E7BFF);

const Color _myMessageCheckBlue = CaRismaDesignTokens.blueBright;

Route<void> buildChatConversationRoute({
  required String chatId,
  String displayName = 'CaRisma Nutzer',
  String? profilePhotoUrl,
  String vehicleModel = 'Fahrzeug',
  String vehicleColor = '',
  String? displayPlate,
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
      isOnline: false,
    ),
  );
}
