import 'package:cloud_firestore/cloud_firestore.dart';

enum ProfileVehicleEncounterStatus { requested, confirmed, declined, removed }

enum ProfileVehicleEncounterType { spotted, meet, trip, event, other }

class ProfileVehicleEncounter {
  const ProfileVehicleEncounter({
    required this.id,
    required this.initiatorUserId,
    required this.recipientUserId,
    required this.initiatorVehicleId,
    required this.recipientVehicleId,
    required this.initiatorVehicleLabel,
    required this.recipientVehicleLabel,
    required this.participantUserIds,
    required this.type,
    required this.status,
    required this.encounterDate,
    this.initiatorPhotoUrl,
    this.recipientPhotoUrl,
    this.locationLabel,
    this.linkedPostId,
    this.confirmedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String initiatorUserId;
  final String recipientUserId;
  final String initiatorVehicleId;
  final String recipientVehicleId;
  final String initiatorVehicleLabel;
  final String recipientVehicleLabel;
  final List<String> participantUserIds;
  final String? initiatorPhotoUrl;
  final String? recipientPhotoUrl;
  final ProfileVehicleEncounterType type;
  final ProfileVehicleEncounterStatus status;
  final String? locationLabel;
  final DateTime encounterDate;
  final String? linkedPostId;
  final DateTime? confirmedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isConfirmed => status == ProfileVehicleEncounterStatus.confirmed;

  bool isIncomingFor(String userId) =>
      status == ProfileVehicleEncounterStatus.requested &&
      recipientUserId == userId;

  bool isOutgoingFor(String userId) =>
      status == ProfileVehicleEncounterStatus.requested &&
      initiatorUserId == userId;

  String otherVehicleLabel(String userId) =>
      userId == initiatorUserId ? recipientVehicleLabel : initiatorVehicleLabel;

  String? otherPhotoUrl(String userId) =>
      userId == initiatorUserId ? recipientPhotoUrl : initiatorPhotoUrl;

  factory ProfileVehicleEncounter.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ProfileVehicleEncounter(
      id: id,
      initiatorUserId: data['initiatorUserId'] as String? ?? '',
      recipientUserId: data['recipientUserId'] as String? ?? '',
      initiatorVehicleId: data['initiatorVehicleId'] as String? ?? '',
      recipientVehicleId: data['recipientVehicleId'] as String? ?? '',
      initiatorVehicleLabel: data['initiatorVehicleLabel'] as String? ?? '',
      recipientVehicleLabel: data['recipientVehicleLabel'] as String? ?? '',
      participantUserIds: _stringList(data['participantUserIds']),
      initiatorPhotoUrl: data['initiatorPhotoUrl'] as String?,
      recipientPhotoUrl: data['recipientPhotoUrl'] as String?,
      type: _typeFromName(data['type'] as String?),
      status: _statusFromName(data['status'] as String?),
      locationLabel: data['locationLabel'] as String?,
      encounterDate: _dateTime(data['encounterDate']) ?? DateTime.now(),
      linkedPostId: data['linkedPostId'] as String?,
      confirmedAt: _dateTime(data['confirmedAt']),
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _dateTime(data['updatedAt']),
    );
  }

  Map<String, Object?> toFirestore() {
    return <String, Object?>{
      'encounterId': id.trim(),
      'initiatorUserId': initiatorUserId.trim(),
      'recipientUserId': recipientUserId.trim(),
      'initiatorVehicleId': initiatorVehicleId.trim(),
      'recipientVehicleId': recipientVehicleId.trim(),
      'initiatorVehicleLabel': initiatorVehicleLabel.trim(),
      'recipientVehicleLabel': recipientVehicleLabel.trim(),
      'participantUserIds': participantUserIds.toSet().toList(growable: false),
      'initiatorPhotoUrl': _trimmedOrNull(initiatorPhotoUrl),
      'recipientPhotoUrl': _trimmedOrNull(recipientPhotoUrl),
      'type': type.name,
      'status': status.name,
      'locationLabel': _trimmedOrNull(locationLabel),
      'encounterDate': Timestamp.fromDate(encounterDate),
      'linkedPostId': _trimmedOrNull(linkedPostId),
      'confirmedAt': confirmedAt == null
          ? null
          : Timestamp.fromDate(confirmedAt!),
    };
  }

  ProfileVehicleEncounter copyWith({
    ProfileVehicleEncounterStatus? status,
    DateTime? confirmedAt,
    DateTime? updatedAt,
  }) {
    return ProfileVehicleEncounter(
      id: id,
      initiatorUserId: initiatorUserId,
      recipientUserId: recipientUserId,
      initiatorVehicleId: initiatorVehicleId,
      recipientVehicleId: recipientVehicleId,
      initiatorVehicleLabel: initiatorVehicleLabel,
      recipientVehicleLabel: recipientVehicleLabel,
      participantUserIds: participantUserIds,
      initiatorPhotoUrl: initiatorPhotoUrl,
      recipientPhotoUrl: recipientPhotoUrl,
      type: type,
      status: status ?? this.status,
      locationLabel: locationLabel,
      encounterDate: encounterDate,
      linkedPostId: linkedPostId,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static ProfileVehicleEncounterStatus _statusFromName(String? name) {
    for (final value in ProfileVehicleEncounterStatus.values) {
      if (value.name == name) return value;
    }
    return ProfileVehicleEncounterStatus.requested;
  }

  static ProfileVehicleEncounterType _typeFromName(String? name) {
    for (final value in ProfileVehicleEncounterType.values) {
      if (value.name == name) return value;
    }
    return ProfileVehicleEncounterType.other;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toSet().toList(growable: false);
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
