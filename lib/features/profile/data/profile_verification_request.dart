import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileVerificationRequest {
  const ProfileVerificationRequest({
    required this.requestId,
    required this.userId,
    required this.profilePath,
    required this.status,
    required this.displayName,
    required this.email,
    required this.documentRemoteUrls,
    this.countryCode,
    this.plateRegion,
    this.plateLetters,
    this.plateNumbers,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.photoUrl,
    this.submittedAt,
    this.createdAt,
    this.updatedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  final String requestId;
  final String userId;
  final String profilePath;
  final String status;
  final String displayName;
  final String email;
  final Map<String, String?> documentRemoteUrls;
  final String? countryCode;
  final String? plateRegion;
  final String? plateLetters;
  final String? plateNumbers;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? photoUrl;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  factory ProfileVerificationRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return ProfileVerificationRequest(
      requestId: data['requestId'] as String? ?? document.id,
      userId: data['userId'] as String? ?? '',
      profilePath: data['profilePath'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      documentRemoteUrls: _stringMapFromValue(data['documentRemoteUrls']),
      countryCode: data['countryCode'] as String?,
      plateRegion: data['plateRegion'] as String?,
      plateLetters: data['plateLetters'] as String?,
      plateNumbers: data['plateNumbers'] as String?,
      vehicleBrand: data['vehicleBrand'] as String?,
      vehicleModel: data['vehicleModel'] as String?,
      vehicleColor: data['vehicleColor'] as String?,
      photoUrl: data['photoUrl'] as String?,
      submittedAt: _dateTimeFromTimestamp(data['submittedAt']),
      createdAt: _dateTimeFromTimestamp(data['createdAt']),
      updatedAt: _dateTimeFromTimestamp(data['updatedAt']),
      reviewedAt: _dateTimeFromTimestamp(data['reviewedAt']),
      reviewedBy: data['reviewedBy'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
    );
  }

  String get plateLabel {
    final region = plateRegion?.trim().toUpperCase() ?? '';
    final letters = plateLetters?.trim().toUpperCase() ?? '';
    final numbers = plateNumbers?.trim().toUpperCase() ?? '';

    if (region.isEmpty && letters.isEmpty && numbers.isEmpty) {
      return '';
    }

    final cityPart = letters.isEmpty ? region : '$region-$letters';
    return numbers.isEmpty ? cityPart : '$cityPart $numbers';
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
