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
    this.verificationStatus = 'unverified',
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
  final String verificationStatus;
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
      verificationStatus: data['verificationStatus'] as String? ?? 'unverified',
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
      'countryCode': countryCode?.trim(),
      'plateRegion': plateRegion?.trim().toUpperCase(),
      'plateLetters': plateLetters?.trim().toUpperCase(),
      'plateNumbers': plateNumbers?.trim().toUpperCase(),
      'vehicleBrand': vehicleBrand?.trim(),
      'vehicleModel': vehicleModel?.trim(),
      'vehicleColor': vehicleColor?.trim(),
      'allowContactRequests': allowContactRequests,
      'allowAnonymousReports': allowAnonymousReports,
      'phoneNumber': phoneNumber?.trim(),
      'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
      'photoUrl': photoUrl,
      'profilePhotoLocalPath': profilePhotoLocalPath,
      'documentLocalPaths': documentLocalPaths,
      'verificationStatus': verificationStatus,
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
    String? verificationStatus,
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
      verificationStatus: verificationStatus ?? this.verificationStatus,
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

  static Map<String, String?> _stringMapFromValue(dynamic value) {
    if (value is! Map) {
      return const {};
    }

    return value.map((key, mapValue) {
      return MapEntry(key.toString(), mapValue as String?);
    });
  }
}
