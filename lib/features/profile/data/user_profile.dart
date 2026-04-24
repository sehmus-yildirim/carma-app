import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.country,
    this.phoneNumber,
    this.birthDate,
    this.photoUrl,
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
  final String? phoneNumber;
  final DateTime? birthDate;
  final String? photoUrl;
  final String verificationStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserProfile.empty({
    required String uid,
    required String email,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      firstName: '',
      lastName: '',
      displayName: '',
      country: 'Deutschland',
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
      phoneNumber: data['phoneNumber'] as String?,
      birthDate: _dateTimeFromTimestamp(data['birthDate']),
      photoUrl: data['photoUrl'] as String?,
      verificationStatus:
      data['verificationStatus'] as String? ?? 'unverified',
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
      'phoneNumber': phoneNumber?.trim(),
      'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
      'photoUrl': photoUrl,
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
    String? phoneNumber,
    DateTime? birthDate,
    String? photoUrl,
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
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthDate: birthDate ?? this.birthDate,
      photoUrl: photoUrl ?? this.photoUrl,
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
}