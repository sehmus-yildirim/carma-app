import 'package:plaqa/features/profile/data/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile', () {
    test('serializes verification metadata for Firestore', () {
      final submittedAt = DateTime.utc(2026, 6, 24, 8, 15);
      final reviewedAt = DateTime.utc(2026, 6, 25, 9, 30);

      final profile = UserProfile(
        uid: 'user-1',
        email: 'plaqa@example.com',
        firstName: 'Max',
        lastName: 'Muster',
        displayName: 'Max M.',
        country: 'Deutschland',
        verificationStatus: 'rejected',
        verificationSubmittedAt: submittedAt,
        verificationReviewedAt: reviewedAt,
        verificationRejectionReason: 'Fahrzeugschein ist nicht lesbar. ',
      );

      final data = profile.toFirestore();

      expect(data['verificationStatus'], 'rejected');
      expect(data['personalDataLocked'], isFalse);
      expect(data['verificationSubmittedAt'], isA<Timestamp>());
      expect(data['verificationReviewedAt'], isA<Timestamp>());
      expect(
        (data['verificationSubmittedAt'] as Timestamp)
            .toDate()
            .isAtSameMomentAs(submittedAt),
        isTrue,
      );
      expect(
        (data['verificationReviewedAt'] as Timestamp).toDate().isAtSameMomentAs(
          reviewedAt,
        ),
        isTrue,
      );
      expect(
        data['verificationRejectionReason'],
        'Fahrzeugschein ist nicht lesbar.',
      );
    });

    test('copyWith preserves verification metadata', () {
      final submittedAt = DateTime.utc(2026, 6, 24, 8, 15);
      final reviewedAt = DateTime.utc(2026, 6, 25, 9, 30);

      final profile = UserProfile(
        uid: 'user-1',
        email: 'plaqa@example.com',
        firstName: 'Max',
        lastName: 'Muster',
        displayName: 'Max M.',
        country: 'Deutschland',
        verificationStatus: 'rejected',
        verificationSubmittedAt: submittedAt,
        verificationReviewedAt: reviewedAt,
        verificationRejectionReason: 'Fahrzeugschein ist nicht lesbar.',
      );

      final updatedProfile = profile.copyWith(displayName: 'Max Mustermann');

      expect(updatedProfile.displayName, 'Max Mustermann');
      expect(updatedProfile.verificationStatus, 'rejected');
      expect(updatedProfile.personalDataLocked, isFalse);
      expect(updatedProfile.verificationSubmittedAt, submittedAt);
      expect(updatedProfile.verificationReviewedAt, reviewedAt);
      expect(
        updatedProfile.verificationRejectionReason,
        'Fahrzeugschein ist nicht lesbar.',
      );
    });

    test('persists an enabled personal data lock', () {
      final profile = UserProfile(
        uid: 'user-1',
        email: 'plaqa@example.com',
        firstName: 'Max',
        lastName: 'Muster',
        displayName: 'Max M.',
        country: 'Deutschland',
        personalDataLocked: true,
      );

      final data = profile.toFirestore();
      final copiedProfile = profile.copyWith(
        photoUrl: 'https://example.test/p.jpg',
      );

      expect(data['personalDataLocked'], isTrue);
      expect(copiedProfile.personalDataLocked, isTrue);
    });
  });
}
