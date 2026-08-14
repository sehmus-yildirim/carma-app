import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/data/profile_verification_request.dart';

void main() {
  test('passport requires only the identity data page', () {
    final keys = ProfileVerificationDocumentKeys.requiredFor(
      ProfileIdentityDocumentType.passport,
    );

    expect(keys, hasLength(5));
    expect(keys, contains(ProfileVerificationDocumentKeys.identityFront));
    expect(keys, isNot(contains(ProfileVerificationDocumentKeys.identityBack)));
  });

  test('verification levels are calculated independently', () {
    final request =
        _requestWithStatuses(<String, ProfileVerificationDocumentStatus>{
          ProfileVerificationDocumentKeys.identityFront:
              ProfileVerificationDocumentStatus.verified,
          ProfileVerificationDocumentKeys.identityBack:
              ProfileVerificationDocumentStatus.verified,
          ProfileVerificationDocumentKeys.driverLicenseFront:
              ProfileVerificationDocumentStatus.verified,
          ProfileVerificationDocumentKeys.driverLicenseBack:
              ProfileVerificationDocumentStatus.verified,
          ProfileVerificationDocumentKeys.vehicleFront:
              ProfileVerificationDocumentStatus.rejected,
          ProfileVerificationDocumentKeys.vehicleBack:
              ProfileVerificationDocumentStatus.verified,
        });

    expect(request.identityVerified, isTrue);
    expect(request.driverLicenseVerified, isTrue);
    expect(request.vehicleVerified, isFalse);
    expect(request.fullyVerified, isFalse);
  });

  test('passport identity level ignores an unused back page', () {
    final request =
        _requestWithStatuses(<String, ProfileVerificationDocumentStatus>{
          ProfileVerificationDocumentKeys.identityFront:
              ProfileVerificationDocumentStatus.verified,
          ProfileVerificationDocumentKeys.identityBack:
              ProfileVerificationDocumentStatus.rejected,
        }, identityDocumentType: ProfileIdentityDocumentType.passport);

    expect(request.identityVerified, isTrue);
  });
}

ProfileVerificationRequest _requestWithStatuses(
  Map<String, ProfileVerificationDocumentStatus> statuses, {
  ProfileIdentityDocumentType identityDocumentType =
      ProfileIdentityDocumentType.identityCard,
}) {
  return ProfileVerificationRequest(
    requestId: 'user-1',
    userId: 'user-1',
    profilePath: 'users/user-1',
    status: ProfileVerificationStatus.rejected,
    displayName: 'Test User',
    documentStoragePaths: const <String, String?>{},
    documentStatuses: statuses,
    identityDocumentType: identityDocumentType,
  );
}
