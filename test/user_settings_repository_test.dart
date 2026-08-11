import 'package:carisma/features/settings/data/user_settings_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User settings models', () {
    test('visibility settings keep safe defaults', () {
      const settings = VisibilitySettings();

      expect(settings.profileVisibility, 'contacts');
      expect(settings.plateSearchVisibility, 'contacts');
      expect(settings.showVehicle, isFalse);
      expect(settings.showRegion, isFalse);
      expect(settings.showPlate, isFalse);
      expect(settings.allowContactRequests, isTrue);
    });

    test('visibility settings serialize only public preference fields', () {
      final data = const VisibilitySettings(
        showVehicle: true,
        showRegion: true,
        showPlate: false,
        allowContactRequests: false,
      ).toFirestore(userId: 'user-1');

      expect(data['userId'], 'user-1');
      expect(data['showVehicle'], isTrue);
      expect(data['showRegion'], isTrue);
      expect(data['showPlate'], isFalse);
      expect(data['allowContactRequests'], isFalse);
      expect(data.keys, isNot(contains('email')));
      expect(data.keys, isNot(contains('phoneNumber')));
      expect(data.keys, isNot(contains('documents')));
      expect(data['updatedAt'], isA<FieldValue>());
    });

    test('contact filter settings preserve quiet mode timestamp', () {
      final until = DateTime.utc(2026, 8, 11, 12);
      final data = ContactFilterSettings(
        requireVerifiedRequester: true,
        autoRejectUnverified: true,
        contactRequestQuietModeUntil: until,
      ).toFirestore(userId: 'user-1');

      expect(data['requireVerifiedRequester'], isTrue);
      expect(data['autoRejectUnverified'], isTrue);
      expect(data['contactRequestQuietModeUntil'], isA<Timestamp>());
      expect(
        (data['contactRequestQuietModeUntil'] as Timestamp)
            .toDate()
            .isAtSameMomentAs(until),
        isTrue,
      );
    });

    test('chat, story and app preferences deserialize missing documents', () {
      expect(ChatPrivacySettings.fromMap(null).readReceiptsEnabled, isTrue);
      expect(StoryPrivacySettings.fromMap(null).storyRepliesEnabled, isTrue);
      expect(AppPreferenceSettings.fromMap(null).languageCode, 'de');
      expect(AppPreferenceSettings.fromMap(null).distanceUnit, 'km');
      expect(AppPreferenceSettings.fromMap(null).defaultPlateCountry, 'DE');
    });
  });
}
