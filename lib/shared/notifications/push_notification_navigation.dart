import 'package:flutter/foundation.dart';

enum PushNotificationDestination { profile, chats, reports, settings }

class PushNotificationTarget {
  const PushNotificationTarget({required this.destination, this.resourceId});

  final PushNotificationDestination destination;
  final String? resourceId;

  static PushNotificationTarget? fromData(Map<String, dynamic> data) {
    final type = (data['type'] as String? ?? '').trim().toLowerCase();
    final resourceId = (data['resourceId'] as String?)?.trim();
    final destination = switch (type) {
      'profile' ||
      'follow' ||
      'social_post' => PushNotificationDestination.profile,
      'chat' ||
      'message' ||
      'contact_request' => PushNotificationDestination.chats,
      'report' || 'plate_hint' => PushNotificationDestination.reports,
      'verification' || 'security' => PushNotificationDestination.settings,
      _ => null,
    };

    if (destination == null) return null;
    return PushNotificationTarget(
      destination: destination,
      resourceId: resourceId?.isEmpty == true ? null : resourceId,
    );
  }
}

class PushNotificationNavigation extends ChangeNotifier {
  PushNotificationNavigation._();

  static final PushNotificationNavigation instance =
      PushNotificationNavigation._();

  PushNotificationTarget? _pendingTarget;

  PushNotificationTarget? takePendingTarget() {
    final target = _pendingTarget;
    _pendingTarget = null;
    return target;
  }

  void open(PushNotificationTarget target) {
    _pendingTarget = target;
    notifyListeners();
  }
}
