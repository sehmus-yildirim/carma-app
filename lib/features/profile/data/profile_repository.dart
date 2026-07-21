import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import 'user_profile.dart';

class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profileDocument(String uid) {
    return _firestore.doc(CaRismaFirestorePaths.userProfile(uid));
  }

  DocumentReference<Map<String, dynamic>> _publicProfileDocument(String uid) {
    return _firestore.doc(CaRismaFirestorePaths.publicProfile(uid));
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _profileDocument(uid).snapshots().map((document) {
      if (!document.exists) {
        return null;
      }

      return UserProfile.fromFirestore(document);
    });
  }

  Stream<UserProfile?> watchPublicProfile(String uid) {
    return _publicProfileDocument(uid).snapshots().map((document) {
      if (!document.exists) return null;
      return UserProfile.fromFirestore(document);
    });
  }

  Future<UserProfile?> getProfile(String uid) async {
    final document = await _profileDocument(uid).get();

    if (!document.exists) {
      return null;
    }

    return UserProfile.fromFirestore(document);
  }

  Future<void> createProfileIfMissing(User user) async {
    final document = _profileDocument(user.uid);
    final snapshot = await document.get();

    if (snapshot.exists) {
      final data = snapshot.data() ?? <String, dynamic>{};
      final existingProfile = UserProfile.fromFirestore(snapshot);
      final hasVerificationStatus =
          (data['verificationStatus'] as String?)?.trim().isNotEmpty == true;
      final existingDisplayName = existingProfile.displayName.trim();
      final authDisplayName = user.displayName?.trim() ?? '';
      final effectiveDisplayName = existingDisplayName.isNotEmpty
          ? existingDisplayName
          : authDisplayName;
      final existingPhotoUrl = existingProfile.photoUrl?.trim() ?? '';
      final effectivePhotoUrl = existingPhotoUrl.isNotEmpty
          ? existingPhotoUrl
          : user.photoURL;

      final updateData = <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': effectiveDisplayName,
        'photoUrl': effectivePhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!hasVerificationStatus) {
        updateData.addAll({
          'verificationStatus': 'unverified',
          'verificationSubmittedAt': null,
          'verificationReviewedAt': null,
          'verificationRejectionReason': null,
        });
      }

      final batch = _firestore.batch();
      batch.set(document, updateData, SetOptions(merge: true));
      batch.set(
        _publicProfileDocument(user.uid),
        _publicProfileDataFor(
          existingProfile,
          displayName: effectiveDisplayName,
          photoUrl: effectivePhotoUrl,
        ),
      );
      await batch.commit();
      return;
    }

    final profile = UserProfile.empty(uid: user.uid, email: user.email ?? '');
    final batch = _firestore.batch();
    batch.set(document, {
      ...profile.toFirestore(),
      'displayName': user.displayName ?? profile.displayName,
      'photoUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _publicProfileDocument(user.uid),
      _publicProfileDataFor(
        profile,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      ),
    );
    await batch.commit();
  }

  Future<void> saveProfile(UserProfile profile) async {
    final batch = _firestore.batch();
    batch.set(_profileDocument(profile.uid), {
      ...profile.toFirestore(),
      'createdAt': profile.createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(profile.createdAt!),
    }, SetOptions(merge: true));
    batch.set(
      _publicProfileDocument(profile.uid),
      _publicProfileDataFor(profile),
    );
    await batch.commit();
  }

  Future<void> updateProfilePreferences({
    required String uid,
    required String? photoUrl,
    required bool allowContactRequests,
    required bool allowAnonymousReports,
  }) async {
    final document = _profileDocument(uid);
    await document.set({
      'photoUrl': photoUrl,
      'profilePhotoLocalPath': null,
      'allowContactRequests': allowContactRequests,
      'allowAnonymousReports': allowAnonymousReports,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final snapshot = await document.get();
    if (!snapshot.exists) return;

    await _publicProfileDocument(
      uid,
    ).set(_publicProfileDataFor(UserProfile.fromFirestore(snapshot)));
  }

  Future<void> updatePublicProfile({
    required UserProfile profile,
    required String displayName,
    required String? publicBio,
    required String? publicRegion,
    required bool showVehicleOnPublicProfile,
    required bool showPlateOnPublicProfile,
    bool? isPrivateProfile,
    bool? profileAccessEnabled,
    String? followersVisibility,
    String? followingVisibility,
  }) async {
    final uid = profile.uid.trim();
    if (uid.isEmpty) {
      throw ArgumentError('Nutzer-ID darf nicht leer sein.');
    }

    final document = _profileDocument(uid);
    final snapshot = await document.get();
    final data = <String, Object?>{
      'uid': uid,
      'displayName': displayName.trim(),
      'publicBio': _trimmedOrNull(publicBio),
      'publicRegion': _trimmedOrNull(publicRegion),
      'showVehicleOnPublicProfile': showVehicleOnPublicProfile,
      'showPlateOnPublicProfile': showPlateOnPublicProfile,
      'isPrivateProfile': isPrivateProfile ?? profile.isPrivateProfile,
      'profileAccessEnabled':
          profileAccessEnabled ?? profile.profileAccessEnabled,
      'followersVisibility': followersVisibility ?? profile.followersVisibility,
      'followingVisibility': followingVisibility ?? profile.followingVisibility,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      data.addAll({
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
        'firstName': '',
        'lastName': '',
        'country': 'Deutschland',
        'countryCode': 'DE',
        'allowContactRequests': true,
        'allowAnonymousReports': true,
        'verificationStatus': 'unverified',
        'verificationSubmittedAt': null,
        'verificationReviewedAt': null,
        'verificationRejectionReason': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final batch = _firestore.batch();
    batch.set(document, data, SetOptions(merge: true));
    batch.set(
      _publicProfileDocument(uid),
      _publicProfileDataFor(
        profile,
        displayName: displayName,
        publicBio: publicBio,
        publicRegion: publicRegion,
        showVehicleOnPublicProfile: showVehicleOnPublicProfile,
        showPlateOnPublicProfile: showPlateOnPublicProfile,
        isPrivateProfile: isPrivateProfile,
        profileAccessEnabled: profileAccessEnabled,
        followersVisibility: followersVisibility,
        followingVisibility: followingVisibility,
      ),
    );
    await batch.commit();
  }

  Future<void> updatePublicProfilePhoto({
    required String uid,
    required String? photoUrl,
  }) async {
    final publicDocument = _publicProfileDocument(uid);
    final snapshot = await publicDocument.get();
    if (!snapshot.exists) return;

    await publicDocument.update({
      'photoUrl': _trimmedOrNull(photoUrl),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _trimmedUpperOrNull(String? value) {
    return _trimmedOrNull(value)?.toUpperCase();
  }

  Map<String, Object?> _publicProfileDataFor(
    UserProfile profile, {
    String? displayName,
    String? photoUrl,
    String? publicBio,
    String? publicRegion,
    bool? showVehicleOnPublicProfile,
    bool? showPlateOnPublicProfile,
    bool? isPrivateProfile,
    bool? profileAccessEnabled,
    String? followersVisibility,
    String? followingVisibility,
  }) {
    final safeDisplayName =
        _trimmedOrNull(displayName) ??
        _trimmedOrNull(profile.displayName) ??
        'CaRisma Nutzer';
    final showVehicle =
        showVehicleOnPublicProfile ?? profile.showVehicleOnPublicProfile;
    final showPlate =
        showPlateOnPublicProfile ?? profile.showPlateOnPublicProfile;

    return <String, Object?>{
      'uid': profile.uid.trim(),
      'displayName': safeDisplayName,
      'photoUrl': _trimmedOrNull(photoUrl ?? profile.photoUrl),
      'publicBio': _trimmedOrNull(publicBio ?? profile.publicBio),
      'publicRegion': _trimmedOrNull(publicRegion ?? profile.publicRegion),
      'showVehicleOnPublicProfile': showVehicle,
      'showPlateOnPublicProfile': showPlate,
      'isPrivateProfile': isPrivateProfile ?? profile.isPrivateProfile,
      'profileAccessEnabled':
          profileAccessEnabled ?? profile.profileAccessEnabled,
      'followersVisibility': followersVisibility ?? profile.followersVisibility,
      'followingVisibility': followingVisibility ?? profile.followingVisibility,
      'primaryVehicleId': _trimmedOrNull(profile.primaryVehicleId),
      'vehicleBrand': showVehicle ? _trimmedOrNull(profile.vehicleBrand) : null,
      'vehicleModel': showVehicle ? _trimmedOrNull(profile.vehicleModel) : null,
      'countryCode': showPlate
          ? _trimmedUpperOrNull(profile.countryCode)
          : null,
      'plateRegion': showPlate
          ? _trimmedUpperOrNull(profile.plateRegion)
          : null,
      'plateLetters': showPlate
          ? _trimmedUpperOrNull(profile.plateLetters)
          : null,
      'plateNumbers': showPlate
          ? _trimmedUpperOrNull(profile.plateNumbers)
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
