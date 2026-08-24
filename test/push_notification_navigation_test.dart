import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/shared/notifications/push_notification_navigation.dart';

void main() {
  test('maps supported notification types to safe destinations', () {
    expect(
      PushNotificationTarget.fromData(const {'type': 'contact_request'})
          ?.destination,
      PushNotificationDestination.chats,
    );
    expect(
      PushNotificationTarget.fromData(const {'type': 'social_post'})
          ?.destination,
      PushNotificationDestination.profile,
    );
    expect(
      PushNotificationTarget.fromData(const {'type': 'plate_hint'})
          ?.destination,
      PushNotificationDestination.reports,
    );
    expect(
      PushNotificationTarget.fromData(const {'type': 'verification'})
          ?.destination,
      PushNotificationDestination.settings,
    );
  });

  test('ignores unsupported notification destinations', () {
    expect(
      PushNotificationTarget.fromData(const {'type': 'external_url'}),
      isNull,
    );
  });
}
