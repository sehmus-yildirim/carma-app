import 'vehicle.dart';
import 'verification_document.dart';

enum UserProfileVisibility {
  visible,
  hidden,
}

enum UserVerificationStatus {
  notSubmitted,
  pending,
  verified,
  rejected,
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.visibility,
    required this.verificationStatus,
    required this.vehicles,
    required this.documents,
    this.profilePhotoLocalPath,
    this.profilePhotoUrl,
    this.allowContactRequests = true,
    this.allowAnonymousReports = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final UserProfileVisibility visibility;
  final UserVerificationStatus verificationStatus;
  final List<Vehicle> vehicles;
  final List<VerificationDocument> documents;
  final String? profilePhotoLocalPath;
  final String? profilePhotoUrl;
  final bool allowContactRequests;
  final bool allowAnonymousReports;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final normalizedFirstName = firstName.trim();
    final normalizedLastName = lastName.trim();

    if (normalizedFirstName.isEmpty && normalizedLastName.isEmpty) {
      return 'Carma Nutzer';
    }

    if (normalizedFirstName.isEmpty) {
      return '${normalizedLastName.substring(0, 1).toUpperCase()}.';
    }

    if (normalizedLastName.isEmpty) {
      return normalizedFirstName;
    }

    return '$normalizedFirstName ${normalizedLastName.substring(0, 1).toUpperCase()}.';
  }

  bool get hasName {
    return firstName.trim().isNotEmpty && lastName.trim().isNotEmpty;
  }

  bool get hasPrimaryVehicle {
    return vehicles.any((vehicle) => vehicle.isPrimary);
  }

  Vehicle? get primaryVehicle {
    for (final vehicle in vehicles) {
      if (vehicle.isPrimary) {
        return vehicle;
      }
    }

    return vehicles.isNotEmpty ? vehicles.first : null;
  }

  bool get isLocked {
    return verificationStatus == UserVerificationStatus.pending ||
        verificationStatus == UserVerificationStatus.verified;
  }

  bool get isVerified {
    return verificationStatus == UserVerificationStatus.verified;
  }

  bool get allRequiredDocumentsUploaded {
    final requiredTypes = VerificationDocumentType.values.toSet();
    final uploadedTypes = documents
        .where((document) => document.isUploaded)
        .map((document) => document.type)
        .toSet();

    return requiredTypes.every(uploadedTypes.contains);
  }

  bool get canSubmitForVerification {
    final vehicle = primaryVehicle;

    return hasName &&
        vehicle != null &&
        vehicle.hasRequiredData &&
        allRequiredDocumentsUploaded;
  }

  UserProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    UserProfileVisibility? visibility,
    UserVerificationStatus? verificationStatus,
    List<Vehicle>? vehicles,
    List<VerificationDocument>? documents,
    String? profilePhotoLocalPath,
    String? profilePhotoUrl,
    bool? allowContactRequests,
    bool? allowAnonymousReports,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      visibility: visibility ?? this.visibility,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      vehicles: vehicles ?? this.vehicles,
      documents: documents ?? this.documents,
      profilePhotoLocalPath:
      profilePhotoLocalPath ?? this.profilePhotoLocalPath,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      allowContactRequests: allowContactRequests ?? this.allowContactRequests,
      allowAnonymousReports:
      allowAnonymousReports ?? this.allowAnonymousReports,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName,
      'visibility': visibility.name,
      'verificationStatus': verificationStatus.name,
      'vehicles': vehicles.map((vehicle) => vehicle.toMap()).toList(),
      'documents': documents.map((document) => document.toMap()).toList(),
      'profilePhotoLocalPath': profilePhotoLocalPath,
      'profilePhotoUrl': profilePhotoUrl,
      'allowContactRequests': allowContactRequests,
      'allowAnonymousReports': allowAnonymousReports,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final rawVehicles = map['vehicles'];
    final rawDocuments = map['documents'];

    return UserProfile(
      id: map['id'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      visibility: _visibilityFromName(map['visibility'] as String?),
      verificationStatus:
      _verificationStatusFromName(map['verificationStatus'] as String?),
      vehicles: rawVehicles is List
          ? rawVehicles
          .whereType<Map<String, dynamic>>()
          .map(Vehicle.fromMap)
          .toList()
          : const [],
      documents: rawDocuments is List
          ? rawDocuments
          .whereType<Map<String, dynamic>>()
          .map(VerificationDocument.fromMap)
          .toList()
          : const [],
      profilePhotoLocalPath: map['profilePhotoLocalPath'] as String?,
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      allowContactRequests: map['allowContactRequests'] as bool? ?? true,
      allowAnonymousReports: map['allowAnonymousReports'] as bool? ?? true,
      createdAt: _dateTimeFromValue(map['createdAt']),
      updatedAt: _dateTimeFromValue(map['updatedAt']),
    );
  }

  static UserProfileVisibility _visibilityFromName(String? name) {
    return UserProfileVisibility.values.firstWhere(
          (visibility) => visibility.name == name,
      orElse: () => UserProfileVisibility.visible,
    );
  }

  static UserVerificationStatus _verificationStatusFromName(String? name) {
    return UserVerificationStatus.values.firstWhere(
          (status) => status.name == name,
      orElse: () => UserVerificationStatus.notSubmitted,
    );
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  @override
  String toString() {
    return displayName;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UserProfile &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            firstName == other.firstName &&
            lastName == other.lastName &&
            visibility == other.visibility &&
            verificationStatus == other.verificationStatus &&
            vehicles == other.vehicles &&
            documents == other.documents &&
            profilePhotoLocalPath == other.profilePhotoLocalPath &&
            profilePhotoUrl == other.profilePhotoUrl &&
            allowContactRequests == other.allowContactRequests &&
            allowAnonymousReports == other.allowAnonymousReports &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      firstName,
      lastName,
      visibility,
      verificationStatus,
      vehicles,
      documents,
      profilePhotoLocalPath,
      profilePhotoUrl,
      allowContactRequests,
      allowAnonymousReports,
      createdAt,
      updatedAt,
    );
  }
}