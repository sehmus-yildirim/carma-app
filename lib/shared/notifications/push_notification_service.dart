import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'push_notification_navigation.dart';
import 'push_token_repository.dart';

@pragma('vm:entry-point')
Future<void> plaqaFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final PushTokenRepository _tokenRepository = PushTokenRepository();

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  String? _registeredUserId;
  String? _registeredToken;
  bool _initialized = false;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_initialized || !isSupported) return;
    _initialized = true;

    try {
      await _messaging.setAutoInitEnabled(true);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _subscriptions
        ..add(FirebaseMessaging.onMessage.listen(_handleForegroundMessage))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen(_openMessage))
        ..add(
          _messaging.onTokenRefresh.listen((token) {
            unawaited(_guard(() => _saveToken(token)));
          }),
        )
        ..add(
          FirebaseAuth.instance.userChanges().listen((user) {
            unawaited(_guard(() => _handleUserChanged(user)));
          }),
        );

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _openMessage(initialMessage);
    } on Object {
      _logSetupIssue();
    }
  }

  Future<bool> requestPermissionAndSync() async {
    if (!isSupported) return false;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      final allowed = _isAuthorized(settings.authorizationStatus);
      if (allowed) await _syncCurrentToken();
      return allowed;
    } on Object {
      _logSetupIssue();
      return false;
    }
  }

  Future<void> removeCurrentToken() async {
    final userId = _registeredUserId;
    final token = _registeredToken;
    try {
      if (userId != null && token != null) {
        await _tokenRepository.remove(userId: userId, token: token);
      }
    } on Object {
      _logSetupIssue();
    } finally {
      _registeredUserId = null;
      _registeredToken = null;
    }
  }

  Future<void> _handleUserChanged(User? user) async {
    if (user == null) {
      await removeCurrentToken();
      return;
    }

    if (_registeredUserId != null && _registeredUserId != user.uid) {
      await removeCurrentToken();
    }
    await _syncCurrentToken();
  }

  Future<void> _syncCurrentToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final settings = await _messaging.getNotificationSettings();
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        !_isAuthorized(settings.authorizationStatus)) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken == null || apnsToken.trim().isEmpty) return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;
    await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    final normalizedToken = token.trim();
    if (user == null || normalizedToken.isEmpty) return;

    if (_registeredUserId == user.uid &&
        _registeredToken != null &&
        _registeredToken != normalizedToken) {
      await _tokenRepository.remove(userId: user.uid, token: _registeredToken!);
    }

    await _tokenRepository.save(
      userId: user.uid,
      token: normalizedToken,
      platform: Platform.operatingSystem,
    );
    _registeredUserId = user.uid;
    _registeredToken = normalizedToken;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // iOS presents these through the configured native foreground options.
  }

  void _openMessage(RemoteMessage message) {
    final target = PushNotificationTarget.fromData(message.data);
    if (target != null) PushNotificationNavigation.instance.open(target);
  }

  bool _isAuthorized(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  Future<void> _guard(Future<void> Function() operation) async {
    try {
      await operation();
    } on Object {
      _logSetupIssue();
    }
  }

  void _logSetupIssue() {
    if (kDebugMode) {
      debugPrint(
        'Mitteilungen konnten noch nicht vollstaendig eingerichtet werden.',
      );
    }
  }
}
