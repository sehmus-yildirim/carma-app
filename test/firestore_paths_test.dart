import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/shared/firebase/carisma_firestore_paths.dart';

void main() {
  group('CaRismaFirestorePaths', () {
    test('builds private and public profile vehicle paths', () {
      expect(CaRismaFirestorePaths.user('user-a'), 'users/user-a');
      expect(
        CaRismaFirestorePaths.userProfile('user-a'),
        'users/user-a/profiles/main',
      );
      expect(
        CaRismaFirestorePaths.userVehicle('user-a', 'vehicle-1'),
        'users/user-a/vehicles/vehicle-1',
      );
      expect(
        CaRismaFirestorePaths.publicProfileVehicle('user-a', 'vehicle-1'),
        'public_profiles/user-a/vehicles/vehicle-1',
      );
    });

    test('builds nested gallery, modification and timeline paths', () {
      expect(
        CaRismaFirestorePaths.userVehicleGalleryMedia(
          'user-a',
          'vehicle-1',
          'media-1',
        ),
        'users/user-a/vehicles/vehicle-1/gallery/media-1',
      );
      expect(
        CaRismaFirestorePaths.publicVehicleModification(
          'user-a',
          'vehicle-1',
          'mod-1',
        ),
        'public_profiles/user-a/vehicles/vehicle-1/modifications/mod-1',
      );
      expect(
        CaRismaFirestorePaths.userVehicleTimelineEntry(
          'user-a',
          'vehicle-1',
          'entry-1',
        ),
        'users/user-a/vehicles/vehicle-1/timeline/entry-1',
      );
    });

    test('builds communication and safety paths', () {
      expect(
        CaRismaFirestorePaths.contactRequest('request-1'),
        'contact_requests/request-1',
      );
      expect(CaRismaFirestorePaths.chat('chat-1'), 'chats/chat-1');
      expect(
        CaRismaFirestorePaths.chatMessage('chat-1', 'message-1'),
        'chats/chat-1/messages/message-1',
      );
      expect(CaRismaFirestorePaths.report('report-1'), 'reports/report-1');
      expect(
        CaRismaFirestorePaths.userReportNotification('user-a', 'report-1'),
        'users/user-a/report_notifications/report-1',
      );
    });

    test('normalizes the country code in plate paths', () {
      expect(
        CaRismaFirestorePaths.plate('de', 'HH_SY_4700'),
        'plates/DE_HH_SY_4700',
      );
    });

    test('builds account settings, push and verification paths', () {
      expect(
        CaRismaFirestorePaths.userSearchCredit('user-a'),
        'users/user-a/search_credits/main',
      );
      expect(
        CaRismaFirestorePaths.userNotificationSettings('user-a'),
        'users/user-a/settings/notifications',
      );
      expect(
        CaRismaFirestorePaths.userPushToken('user-a', 'hash-1'),
        'users/user-a/push_tokens/hash-1',
      );
      expect(
        CaRismaFirestorePaths.verificationRequest('request-1'),
        'verification_requests/request-1',
      );
      expect(
        CaRismaFirestorePaths.userVerificationNotifications('user-a'),
        'users/user-a/verification_notifications',
      );
    });
  });
}
