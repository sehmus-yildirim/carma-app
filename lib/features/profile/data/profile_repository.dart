import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import '../../../shared/security/trusted_firebase_media_url.dart';
import 'user_profile.dart';

class ProfileRepository {
  ProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore,
       _functions = functions;

  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get _cloudFunctions =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  DocumentReference<Map<String, dynamic>> _profileDocument(String uid) {
    return _database.doc(CaRismaFirestorePaths.userProfile(uid));
  }

  DocumentReference<Map<String, dynamic>> _publicProfileDocument(String uid) {
    return _database.doc(CaRismaFirestorePaths.publicProfile(uid));
  }

  DocumentReference<Map<String, dynamic>> _visibilitySettingsDocument(
    String uid,
  ) {
    return _database.doc(
      '${CaRismaFirestorePaths.user(uid)}/'
      '${CaRismaFirestoreCollections.settings}/visibility',
    );
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

  Stream<int> watchProfileViewCount(String uid) {
    final userId = uid.trim();
    if (userId.isEmpty) return Stream<int>.value(0);
    return _publicProfileDocument(userId).snapshots().map((document) {
      final value = document.data()?['profileViewCount'];
      return value is int && value >= 0 ? value : 0;
    });
  }

  Future<void> recordProfileView(String profileUserId) async {
    final userId = profileUserId.trim();
    if (userId.isEmpty) return;
    await _cloudFunctions.httpsCallable('recordProfileView').call<void>({
      'profileUserId': userId,
    });
  }

  Future<void> createProfileIfMissing(User user) async {
    final document = _profileDocument(user.uid);
    final snapshot = await document.get();
    final trustedAuthPhotoUrl = trustedProfilePhotoUrl(
      url: user.photoURL,
      userId: user.uid,
    );

    if (snapshot.exists) {
      final data = snapshot.data() ?? <String, dynamic>{};
      final existingProfile = UserProfile.fromFirestore(snapshot);
      final visibility = await _loadVisibilitySettings(user.uid);
      final hasVerificationStatus =
          (data['verificationStatus'] as String?)?.trim().isNotEmpty == true;
      final existingDisplayName = existingProfile.displayName.trim();
      final authDisplayName = user.displayName?.trim() ?? '';
      final effectiveDisplayName = existingDisplayName.isNotEmpty
          ? existingDisplayName
          : authDisplayName;
      final existingPhotoUrl = trustedProfilePhotoUrl(
        url: existingProfile.photoUrl,
        userId: user.uid,
      );
      final effectivePhotoUrl = existingPhotoUrl ?? trustedAuthPhotoUrl;

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

      final batch = _database.batch();
      batch.set(document, updateData, SetOptions(merge: true));
      batch.set(
        _publicProfileDocument(user.uid),
        _publicProfileDataFor(
          existingProfile,
          displayName: effectiveDisplayName,
          photoUrl: effectivePhotoUrl,
          publicRegion: _visibleRegion(existingProfile, visibility),
          showVehicleOnPublicProfile: _visibilityBool(
            visibility,
            'showVehicle',
            existingProfile.showVehicleOnPublicProfile,
          ),
          showPlateOnPublicProfile: _visibilityBool(
            visibility,
            'showPlate',
            existingProfile.showPlateOnPublicProfile,
          ),
          profileAccessEnabled: _profileAccessEnabled(
            visibility,
            existingProfile.profileAccessEnabled,
          ),
        ),
      );
      await batch.commit();
      return;
    }

    final profile = UserProfile.empty(uid: user.uid, email: user.email ?? '');
    final batch = _database.batch();
    batch.set(document, {
      ...profile.toFirestore(),
      'displayName': user.displayName ?? profile.displayName,
      'photoUrl': trustedAuthPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _publicProfileDocument(user.uid),
      _publicProfileDataFor(
        profile,
        displayName: user.displayName,
        photoUrl: trustedAuthPhotoUrl,
      ),
    );
    await batch.commit();
  }

  Future<void> saveProfile(UserProfile profile) async {
    final visibility = await _loadVisibilitySettings(profile.uid);
    final trustedPhotoUrl = trustedProfilePhotoUrl(
      url: profile.photoUrl,
      userId: profile.uid,
    );
    final batch = _database.batch();
    batch.set(_profileDocument(profile.uid), {
      ...profile.toFirestore(),
      'photoUrl': trustedPhotoUrl,
      'createdAt': profile.createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(profile.createdAt!),
    }, SetOptions(merge: true));
    batch.set(
      _publicProfileDocument(profile.uid),
      _publicProfileDataFor(
        profile,
        publicRegion: _visibleRegion(profile, visibility),
        showVehicleOnPublicProfile: _visibilityBool(
          visibility,
          'showVehicle',
          profile.showVehicleOnPublicProfile,
        ),
        showPlateOnPublicProfile: _visibilityBool(
          visibility,
          'showPlate',
          profile.showPlateOnPublicProfile,
        ),
        profileAccessEnabled: _profileAccessEnabled(
          visibility,
          profile.profileAccessEnabled,
        ),
      ),
    );
    await batch.commit();
  }

  Future<UserProfile?> updatePersonalData({
    required String uid,
    required String firstName,
    required String lastName,
    required String displayName,
    required DateTime birthDate,
    required String? photoUrl,
    required String verificationStatus,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw ArgumentError('Nutzer-ID darf nicht leer sein.');
    }

    final normalizedBirthDate = DateTime.utc(
      birthDate.year,
      birthDate.month,
      birthDate.day,
      12,
    );
    final trustedPhotoUrl = trustedProfilePhotoUrl(
      url: photoUrl,
      userId: normalizedUid,
    );
    final batch = _database.batch();
    batch.set(_profileDocument(normalizedUid), {
      'uid': normalizedUid,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'displayName': displayName.trim(),
      'birthDate': Timestamp.fromDate(normalizedBirthDate),
      'personalDataLocked': true,
      'photoUrl': trustedPhotoUrl,
      'profilePhotoLocalPath': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_publicProfileDocument(normalizedUid), {
      'uid': normalizedUid,
      'displayName': displayName.trim(),
      'photoUrl': trustedPhotoUrl,
      'verificationStatus': verificationStatus.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    return getProfile(normalizedUid);
  }

  Future<UserProfile?> updateProfilePhoto({
    required String uid,
    required String? photoUrl,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw ArgumentError('Nutzer-ID darf nicht leer sein.');
    }

    final normalizedPhotoUrl = trustedProfilePhotoUrl(
      url: photoUrl,
      userId: normalizedUid,
    );
    final batch = _database.batch();
    batch.set(_profileDocument(normalizedUid), {
      'photoUrl': normalizedPhotoUrl,
      'profilePhotoLocalPath': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.update(_publicProfileDocument(normalizedUid), {
      'photoUrl': normalizedPhotoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return getProfile(normalizedUid);
  }

  Future<void> updateProfilePreferences({
    required String uid,
    required String? photoUrl,
    required bool allowContactRequests,
    required bool allowAnonymousReports,
  }) async {
    final document = _profileDocument(uid);
    final trustedPhotoUrl = trustedProfilePhotoUrl(url: photoUrl, userId: uid);
    await document.set({
      'photoUrl': trustedPhotoUrl,
      'profilePhotoLocalPath': null,
      'allowContactRequests': allowContactRequests,
      'allowAnonymousReports': allowAnonymousReports,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final snapshot = await document.get();
    if (!snapshot.exists) return;

    final profile = UserProfile.fromFirestore(snapshot);
    final visibility = await _loadVisibilitySettings(uid);

    await _publicProfileDocument(uid).set(
      _publicProfileDataFor(
        profile,
        publicRegion: _visibleRegion(profile, visibility),
        showVehicleOnPublicProfile: _visibilityBool(
          visibility,
          'showVehicle',
          profile.showVehicleOnPublicProfile,
        ),
        showPlateOnPublicProfile: _visibilityBool(
          visibility,
          'showPlate',
          profile.showPlateOnPublicProfile,
        ),
        profileAccessEnabled: _profileAccessEnabled(
          visibility,
          profile.profileAccessEnabled,
        ),
      ),
    );
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
    final visibility = await _loadVisibilitySettings(uid);
    final effectiveShowVehicle = _visibilityBool(
      visibility,
      'showVehicle',
      showVehicleOnPublicProfile,
    );
    final effectiveShowPlate = _visibilityBool(
      visibility,
      'showPlate',
      showPlateOnPublicProfile,
    );
    final effectiveProfileAccess = _profileAccessEnabled(
      visibility,
      profileAccessEnabled ?? profile.profileAccessEnabled,
    );
    final effectivePublicRegion = _visibleRegion(
      profile,
      visibility,
      requestedRegion: publicRegion,
    );
    final data = <String, Object?>{
      'uid': uid,
      'displayName': displayName.trim(),
      'publicBio': _trimmedOrNull(publicBio),
      'publicRegion': effectivePublicRegion,
      'showVehicleOnPublicProfile': effectiveShowVehicle,
      'showPlateOnPublicProfile': effectiveShowPlate,
      'isPrivateProfile': isPrivateProfile ?? profile.isPrivateProfile,
      'profileAccessEnabled': effectiveProfileAccess,
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

    final batch = _database.batch();
    batch.set(document, data, SetOptions(merge: true));
    batch.set(
      _publicProfileDocument(uid),
      _publicProfileDataFor(
        profile,
        displayName: displayName,
        publicBio: publicBio,
        publicRegion: effectivePublicRegion,
        showVehicleOnPublicProfile: effectiveShowVehicle,
        showPlateOnPublicProfile: effectiveShowPlate,
        isPrivateProfile: isPrivateProfile,
        profileAccessEnabled: effectiveProfileAccess,
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
      'photoUrl': trustedProfilePhotoUrl(url: photoUrl, userId: uid),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> applyVisibilitySettings({
    required String uid,
    required String profileVisibility,
    required bool showVehicle,
    required bool showRegion,
    required bool showPlate,
    required bool allowContactRequests,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw ArgumentError('Nutzer-ID darf nicht leer sein.');
    }
    final document = _profileDocument(normalizedUid);
    final snapshot = await document.get();
    if (!snapshot.exists) return;

    final profile = UserProfile.fromFirestore(snapshot);
    final profileAccessEnabled = profileVisibility != 'onlyMe';
    final publicData = _publicProfileDataFor(
      profile,
      showVehicleOnPublicProfile: showVehicle,
      showPlateOnPublicProfile: showPlate,
      profileAccessEnabled: profileAccessEnabled,
      isPrivateProfile: true,
    );
    publicData['publicRegion'] = showRegion
        ? _trimmedOrNull(profile.publicRegion)
        : null;

    final batch = _database.batch();
    batch.set(document, {
      'showVehicleOnPublicProfile': showVehicle,
      'showPlateOnPublicProfile': showPlate,
      'allowContactRequests': allowContactRequests,
      'profileAccessEnabled': profileAccessEnabled,
      'isPrivateProfile': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_publicProfileDocument(normalizedUid), publicData);
    await batch.commit();
  }

  Future<Map<String, dynamic>?> _loadVisibilitySettings(String uid) async {
    final snapshot = await _visibilitySettingsDocument(uid).get();
    return snapshot.data();
  }

  bool _visibilityBool(
    Map<String, dynamic>? settings,
    String field,
    bool fallback,
  ) {
    return settings?[field] as bool? ?? fallback;
  }

  bool _profileAccessEnabled(Map<String, dynamic>? settings, bool fallback) {
    final visibility = settings?['profileVisibility'] as String?;
    return visibility == null ? fallback : visibility != 'onlyMe';
  }

  String? _visibleRegion(
    UserProfile profile,
    Map<String, dynamic>? settings, {
    String? requestedRegion,
  }) {
    final showRegion = settings?['showRegion'] as bool?;
    if (showRegion == false) return null;
    return _trimmedOrNull(requestedRegion ?? profile.publicRegion);
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
        'plaqa Nutzer';
    final showVehicle =
        showVehicleOnPublicProfile ?? profile.showVehicleOnPublicProfile;
    final showPlate =
        showPlateOnPublicProfile ?? profile.showPlateOnPublicProfile;

    return <String, Object?>{
      'uid': profile.uid.trim(),
      'displayName': safeDisplayName,
      'photoUrl': trustedProfilePhotoUrl(
        url: photoUrl ?? profile.photoUrl,
        userId: profile.uid,
      ),
      'publicBio': _trimmedOrNull(publicBio ?? profile.publicBio),
      'publicRegion': _trimmedOrNull(publicRegion ?? profile.publicRegion),
      'showVehicleOnPublicProfile': showVehicle,
      'showPlateOnPublicProfile': showPlate,
      'isPrivateProfile': isPrivateProfile ?? profile.isPrivateProfile,
      'profileAccessEnabled':
          profileAccessEnabled ?? profile.profileAccessEnabled,
      'followersVisibility': followersVisibility ?? profile.followersVisibility,
      'followingVisibility': followingVisibility ?? profile.followingVisibility,
      'verificationStatus': profile.verificationStatus,
      'primaryVehicleId': _trimmedOrNull(profile.primaryVehicleId),
      'vehicleBrand': showVehicle ? _trimmedOrNull(profile.vehicleBrand) : null,
      'vehicleModel': showVehicle ? _trimmedOrNull(profile.vehicleModel) : null,
      'vehicleColor': showVehicle ? _trimmedOrNull(profile.vehicleColor) : null,
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
