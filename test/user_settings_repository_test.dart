import 'package:plaqa/features/settings/data/user_settings_repository.dart';
import 'package:plaqa/shared/models/legal_consent.dart';
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
        requesterVerificationLevel:
            ContactRequesterVerificationLevel.identityVerified,
        contactRequestQuietModeUntil: until,
      ).toFirestore(userId: 'user-1');

      expect(data['requesterVerificationLevel'], 'identityVerified');
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

    test('legacy verified filter remains identity protected', () {
      final settings = ContactFilterSettings.fromMap(const {
        'requireVerifiedRequester': true,
        'autoRejectUnverified': true,
      });

      expect(
        settings.requesterVerificationLevel,
        ContactRequesterVerificationLevel.identityVerified,
      );
    });

    test(
      'contact reasons and country selection survive copy and serialization',
      () {
        const contact = ContactFilterSettings();
        final filtered = contact.copyWith(
          allowedContactReasons: const ['vehicle_question', 'compliment'],
        );
        final preferences = const AppPreferenceSettings().copyWith(
          defaultPlateCountry: 'AT',
          hapticsEnabled: false,
          messageSoundsEnabled: false,
        );

        expect(filtered.allowedContactReasons, [
          'vehicle_question',
          'compliment',
        ]);
        expect(
          preferences.toFirestore(userId: 'user-1')['defaultPlateCountry'],
          'AT',
        );
        expect(preferences.hapticsEnabled, isFalse);
        expect(preferences.messageSoundsEnabled, isFalse);
      },
    );

    test('chat, story and app preferences deserialize missing documents', () {
      expect(ChatPrivacySettings.fromMap(null).readReceiptsEnabled, isTrue);
      expect(StoryPrivacySettings.fromMap(null).storyRepliesEnabled, isTrue);
      expect(AppPreferenceSettings.fromMap(null).languageCode, 'de');
      expect(AppPreferenceSettings.fromMap(null).distanceUnit, 'km');
      expect(AppPreferenceSettings.fromMap(null).defaultPlateCountry, 'DE');
    });
  });

  group('Data rights requests', () {
    test('export request contains identity but no exported private data', () {
      final draft = DataRightsRequestDraftBuilder.buildExportRequest(
        appVersion: 'plaqa 1.0.0',
        userId: 'user-1',
        email: 'user@example.com',
      );

      expect(draft, contains('UID: user-1'));
      expect(draft, contains('Konto: user@example.com'));
      expect(draft, contains('Kein zusätzlicher Hinweis.'));
      expect(draft, isNot(contains('Chatinhalt')));
      expect(draft, isNot(contains('Dokumentdaten')));
      expect(draft, contains('nicht automatisch'));
    });

    test('deletion request requires explicit confirmation', () {
      expect(
        DataRightsRequestDraftBuilder.isDeletionConfirmed(
          confirmationText: 'Konto löschen',
          acceptedConsequences: false,
        ),
        isFalse,
      );
      expect(
        DataRightsRequestDraftBuilder.isDeletionConfirmed(
          confirmationText: 'Konto löschen',
          acceptedConsequences: true,
        ),
        isTrue,
      );
      expect(
        () => DataRightsRequestDraftBuilder.buildDeletionRequest(
          appVersion: 'plaqa 1.0.0',
          userId: 'user-1',
          confirmationText: '',
          acceptedConsequences: false,
        ),
        throwsArgumentError,
      );
    });

    test('legal consent status uses latest accepted version and fallback', () {
      final statuses = LegalConsentStatusResolver.resolve([
        LegalConsent(
          id: 'old-terms',
          userId: 'user-1',
          type: LegalConsentType.terms,
          version: '0.9.0',
          acceptedAt: DateTime.utc(2026, 1, 1),
        ),
        LegalConsent(
          id: 'current-terms',
          userId: 'user-1',
          type: LegalConsentType.terms,
          version: '1.0.0',
          acceptedAt: DateTime.utc(2026, 2, 1),
        ),
      ]);

      final terms = statuses.singleWhere(
        (status) => status.type == LegalConsentType.terms,
      );
      final privacy = statuses.singleWhere(
        (status) => status.type == LegalConsentType.privacy,
      );

      expect(terms.acceptedVersion, '1.0.0');
      expect(terms.isCurrent, isTrue);
      expect(privacy.acceptedVersion, isNull);
      expect(privacy.isAvailable, isFalse);
    });
  });
}
