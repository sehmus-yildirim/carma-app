import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile_vehicle.dart';

enum ProfileVehicleTimelineType {
  vehicleCreated,
  vehicleAcquired,
  registered,
  modificationAdded,
  maintenance,
  repair,
  wheelsInstalled,
  mileageMilestone,
  trip,
  meet,
  seasonStart,
  seasonEnd,
  sold,
  archived,
  statusChanged,
  custom,
}

class ProfileVehicleTimelineEntry {
  const ProfileVehicleTimelineEntry({
    required this.id,
    required this.ownerUserId,
    required this.vehicleId,
    required this.type,
    required this.title,
    required this.eventDate,
    this.description,
    this.mediaUrls = const [],
    this.linkedPostId,
    this.linkedModificationId,
    this.isAutomaticallyCreated = false,
    this.visibility = ProfileVehicleVisibility.onlyMe,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String vehicleId;
  final ProfileVehicleTimelineType type;
  final String title;
  final String? description;
  final DateTime eventDate;
  final List<String> mediaUrls;
  final String? linkedPostId;
  final String? linkedModificationId;
  final bool isAutomaticallyCreated;
  final ProfileVehicleVisibility visibility;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPubliclyVisible =>
      visibility == ProfileVehicleVisibility.contacts && !isDeleted;

  factory ProfileVehicleTimelineEntry.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ProfileVehicleTimelineEntry(
      id: id,
      ownerUserId: data['ownerUserId'] as String? ?? '',
      vehicleId: data['vehicleId'] as String? ?? '',
      type: _typeFromName(data['type'] as String?),
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      eventDate: _dateTimeFromValue(data['eventDate']) ?? DateTime.now(),
      mediaUrls: _stringListFromValue(data['mediaUrls']),
      linkedPostId: data['linkedPostId'] as String?,
      linkedModificationId: data['linkedModificationId'] as String?,
      isAutomaticallyCreated: data['isAutomaticallyCreated'] as bool? ?? false,
      visibility: data['visibility'] == ProfileVehicleVisibility.contacts.name
          ? ProfileVehicleVisibility.contacts
          : ProfileVehicleVisibility.onlyMe,
      isDeleted: data['isDeleted'] as bool? ?? false,
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }

  Map<String, Object?> toPrivateFirestore() => _toFirestore();

  Map<String, Object?> toPublicFirestore() => _toFirestore(
    visibility: ProfileVehicleVisibility.contacts,
    isDeleted: false,
  );

  Map<String, Object?> _toFirestore({
    ProfileVehicleVisibility? visibility,
    bool? isDeleted,
  }) {
    return <String, Object?>{
      'entryId': id.trim(),
      'ownerUserId': ownerUserId.trim(),
      'vehicleId': vehicleId.trim(),
      'type': type.name,
      'title': title.trim(),
      'description': _trimmedOrNull(description),
      'eventDate': Timestamp.fromDate(eventDate),
      'mediaUrls': _normalizedStringList(mediaUrls),
      'linkedPostId': _trimmedOrNull(linkedPostId),
      'linkedModificationId': _trimmedOrNull(linkedModificationId),
      'isAutomaticallyCreated': isAutomaticallyCreated,
      'visibility': (visibility ?? this.visibility).name,
      'isDeleted': isDeleted ?? this.isDeleted,
    };
  }

  ProfileVehicleTimelineEntry copyWith({
    ProfileVehicleTimelineType? type,
    String? title,
    String? description,
    DateTime? eventDate,
    List<String>? mediaUrls,
    String? linkedPostId,
    String? linkedModificationId,
    bool? isAutomaticallyCreated,
    ProfileVehicleVisibility? visibility,
    bool? isDeleted,
  }) {
    return ProfileVehicleTimelineEntry(
      id: id,
      ownerUserId: ownerUserId,
      vehicleId: vehicleId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: eventDate ?? this.eventDate,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      linkedPostId: linkedPostId ?? this.linkedPostId,
      linkedModificationId: linkedModificationId ?? this.linkedModificationId,
      isAutomaticallyCreated:
          isAutomaticallyCreated ?? this.isAutomaticallyCreated,
      visibility: visibility ?? this.visibility,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static ProfileVehicleTimelineType _typeFromName(String? name) {
    for (final value in ProfileVehicleTimelineType.values) {
      if (value.name == name) return value;
    }
    return ProfileVehicleTimelineType.custom;
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<String> _stringListFromValue(Object? value) {
    if (value is! List) return const [];
    return _normalizedStringList(value.whereType<String>());
  }

  static List<String> _normalizedStringList(Iterable<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(10)
        .toList(growable: false);
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
