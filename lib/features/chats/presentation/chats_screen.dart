import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/domain/app_feature_gate.dart';
import '../../../shared/models/carma_models.dart';
import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_blue_icon_box.dart';
import '../../../shared/widgets/carma_page_header.dart';
import '../../../shared/widgets/carma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/chat_attachment_storage.dart';
import '../data/chat_native_bridge.dart';
import '../data/chat_repository.dart';
import '../data/contact_request_repository.dart';
import '../domain/accept_contact_request_use_case.dart';

part 'chats/chat_shell.dart';
part 'chats/chat_models.dart';
part 'chats/chat_overview.dart';
part 'chats/chat_menus.dart';
part 'chats/chat_lists.dart';
part 'chats/chat_conversation.dart';
part 'chats/chat_message_bubbles.dart';
part 'chats/chat_composer.dart';

const Color _carmaBlue = Color(0xFF139CFF);
const Color _carmaBlueLight = Color(0xFF63D5FF);
const Color _carmaBlueDark = Color(0xFF0A76FF);

const Color _myMessageBlueDark = Color(0xFF03172F);
const Color _myMessageBlue = Color(0xFF08264A);
const Color _myMessageBlueLight = Color(0xFF0D3566);
const Color _myMessageBorder = Color(0xFF164A86);
const Color _myMessageCheckBlue = Color(0xFF7FD6FF);
