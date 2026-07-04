import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.country,
    this.countryCode,
    this.plateRegion,
    this.plateLetters,
    this.plateNumbers,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.allowContactRequests = true,
    this.allowAnonymousReports = true,
    this.phoneNumber,
    this.birthDate,
    this.photoUrl,
    this.profilePhotoLocalPath,
    this.documentLocalPaths = const {},
    this.documentRemoteUrls = const {},
    this.verificationStatus = 'unverified',
    this.verificationSubmittedAt,
    this.verificationReviewedAt,
    this.verificationRejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String displayName;
  final String country;
  final String? countryCode;
  final String? plateRegion;
  final String? plateLetters;
  final String? plateNumbers;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final bool allowContactRequests;
  final bool allowAnonymousReports;
  final String? phoneNumber;
  final DateTime? birthDate;
  final String? photoUrl;
  final String? profilePhotoLocalPath;
  final Map<String, String?> documentLocalPaths;
  final Map<String, String?> documentRemoteUrls;
  final String verificationStatus;
  final DateTime? verificationSubmittedAt;
  final DateTime? verificationReviewedAt;
  final String? verificationRejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserProfile.empty({required String uid, required String email}) {
    return UserProfile(
      uid: uid,
      email: email,
      firstName: '',
      lastName: '',
      displayName: '',
      country: 'Deutschland',
      countryCode: 'DE',
    );
  }

  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return UserProfile(
      uid: data['uid'] as String? ?? document.id,
      email: data['email'] as String? ?? '',
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      country: data['country'] as String? ?? 'Deutschland',
      countryCode: data['countryCode'] as String?,
      plateRegion: data['plateRegion'] as String?,
      plateLetters: data['plateLetters'] as String?,
      plateNumbers: data['plateNumbers'] as String?,
      vehicleBrand: data['vehicleBrand'] as String?,
      vehicleModel: data['vehicleModel'] as String?,
      vehicleColor: data['vehicleColor'] as String?,
      allowContactRequests: data['allowContactRequests'] as bool? ?? true,
      allowAnonymousReports: data['allowAnonymousReports'] as bool? ?? true,
      phoneNumber: data['phoneNumber'] as String?,
      birthDate: _dateTimeFromTimestamp(data['birthDate']),
      photoUrl: data['photoUrl'] as String?,
      profilePhotoLocalPath: data['profilePhotoLocalPath'] as String?,
      documentLocalPaths: _stringMapFromValue(data['documentLocalPaths']),
      documentRemoteUrls: _stringMapFromValue(data['documentRemoteUrls']),
      verificationStatus: data['verificationStatus'] as String? ?? 'unverified',
      verificationSubmittedAt: _dateTimeFromTimestamp(
        data['verificationSubmittedAt'],
      ),
      verificationReviewedAt: _dateTimeFromTimestamp(
        data['verificationReviewedAt'],
      ),
      verificationRejectionReason:
          data['verificationRejectionReason'] as String?,
      createdAt: _dateTimeFromTimestamp(data['createdAt']),
      updatedAt: _dateTimeFromTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'displayName': displayName.trim(),
      'country': country.trim(),
      'countryCode': _trimmedUpperOrNull(countryCode),
      'plateRegion': _trimmedUpperOrNull(plateRegion),
      'plateLetters': _trimmedUpperOrNull(plateLetters),
      'plateNumbers': _trimmedUpperOrNull(plateNumbers),
      'vehicleBrand': _trimmedOrNull(vehicleBrand),
      'vehicleModel': _trimmedOrNull(vehicleModel),
      'vehicleColor': _trimmedOrNull(vehicleColor),
      'allowContactRequests': allowContactRequests,
      'allowAnonymousReports': allowAnonymousReports,
      'phoneNumber': _trimmedOrNull(phoneNumber),
      'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
      'photoUrl': photoUrl,
      'profilePhotoLocalPath': profilePhotoLocalPath,
      'documentLocalPaths': documentLocalPaths,
      'documentRemoteUrls': documentRemoteUrls,
      'verificationStatus': verificationStatus,
      'verificationSubmittedAt': verificationSubmittedAt == null
          ? null
          : Timestamp.fromDate(verificationSubmittedAt!),
      'verificationReviewedAt': verificationReviewedAt == null
          ? null
          : Timestamp.fromDate(verificationReviewedAt!),
      'verificationRejectionReason': verificationRejectionReason?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? displayName,
    String? country,
    String? countryCode,
    String? plateRegion,
    String? plateLetters,
    String? plateNumbers,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    bool? allowContactRequests,
    bool? allowAnonymousReports,
    String? phoneNumber,
    DateTime? birthDate,
    String? photoUrl,
    String? profilePhotoLocalPath,
    Map<String, String?>? documentLocalPaths,
    Map<String, String?>? documentRemoteUrls,
    String? verificationStatus,
    DateTime? verificationSubmittedAt,
    DateTime? verificationReviewedAt,
    String? verificationRejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      plateRegion: plateRegion ?? this.plateRegion,
      plateLetters: plateLetters ?? this.plateLetters,
      plateNumbers: plateNumbers ?? this.plateNumbers,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      allowContactRequests: allowContactRequests ?? this.allowContactRequests,
      allowAnonymousReports:
          allowAnonymousReports ?? this.allowAnonymousReports,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthDate: birthDate ?? this.birthDate,
      photoUrl: photoUrl ?? this.photoUrl,
      profilePhotoLocalPath:
          profilePhotoLocalPath ?? this.profilePhotoLocalPath,
      documentLocalPaths: documentLocalPaths ?? this.documentLocalPaths,
      documentRemoteUrls: documentRemoteUrls ?? this.documentRemoteUrls,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationSubmittedAt:
          verificationSubmittedAt ?? this.verificationSubmittedAt,
      verificationReviewedAt:
          verificationReviewedAt ?? this.verificationReviewedAt,
      verificationRejectionReason:
          verificationRejectionReason ?? this.verificationRejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _dateTimeFromTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _trimmedUpperOrNull(String? value) {
    return _trimmedOrNull(value)?.toUpperCase();
  }

  static Map<String, String?> _stringMapFromValue(dynamic value) {
    if (value is! Map) {
      return const {};
    }

    return value.map((key, mapValue) {
      return MapEntry(key.toString(), mapValue as String?);
    });
  }
}
