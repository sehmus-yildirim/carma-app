import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile_vehicle.dart';

enum ProfileVehicleGalleryCategory {
  exterior,
  interior,
  engineBay,
  details,
  modifications,
  beforeAfter,
  documentation,
}

enum ProfileVehicleGalleryMediaType { image, video }

class ProfileVehicleGalleryMedia {
  const ProfileVehicleGalleryMedia({
    required this.id,
    required this.ownerUserId,
    required this.vehicleId,
    required this.mediaUrl,
    required this.mediaPath,
    this.mediaType = ProfileVehicleGalleryMediaType.image,
    this.category = ProfileVehicleGalleryCategory.exterior,
    this.caption,
    this.isMain = false,
    this.visibility = ProfileVehicleVisibility.onlyMe,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String vehicleId;
  final String mediaUrl;
  final String mediaPath;
  final ProfileVehicleGalleryMediaType mediaType;
  final ProfileVehicleGalleryCategory category;
  final String? caption;
  final bool isMain;
  final ProfileVehicleVisibility visibility;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPubliclyVisible =>
      visibility == ProfileVehicleVisibility.contacts && !isDeleted;

  factory ProfileVehicleGalleryMedia.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ProfileVehicleGalleryMedia(
      id: id,
      ownerUserId: data['ownerUserId'] as String? ?? '',
      vehicleId: data['vehicleId'] as String? ?? '',
      mediaUrl:
          data['mediaUrl'] as String? ?? data['imageUrl'] as String? ?? '',
      mediaPath:
          data['mediaPath'] as String? ?? data['imagePath'] as String? ?? '',
      mediaType: data['mediaType'] == ProfileVehicleGalleryMediaType.video.name
          ? ProfileVehicleGalleryMediaType.video
          : ProfileVehicleGalleryMediaType.image,
      category: _categoryFromName(data['category'] as String?),
      caption: data['caption'] as String?,
      isMain: data['isMain'] as bool? ?? false,
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
      'mediaId': id.trim(),
      'ownerUserId': ownerUserId.trim(),
      'vehicleId': vehicleId.trim(),
      'mediaUrl': mediaUrl.trim(),
      'mediaPath': mediaPath.trim(),
      'mediaType': mediaType.name,
      'category': category.name,
      'caption': _trimmedOrNull(caption),
      'isMain': isMain,
      'visibility': (visibility ?? this.visibility).name,
      'isDeleted': isDeleted ?? this.isDeleted,
    };
  }

  ProfileVehicleGalleryMedia copyWith({
    String? caption,
    ProfileVehicleGalleryCategory? category,
    bool? isMain,
    ProfileVehicleVisibility? visibility,
    bool? isDeleted,
  }) {
    return ProfileVehicleGalleryMedia(
      id: id,
      ownerUserId: ownerUserId,
      vehicleId: vehicleId,
      mediaUrl: mediaUrl,
      mediaPath: mediaPath,
      mediaType: mediaType,
      category: category ?? this.category,
      caption: caption ?? this.caption,
      isMain: isMain ?? this.isMain,
      visibility: visibility ?? this.visibility,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static ProfileVehicleGalleryCategory _categoryFromName(String? name) {
    for (final value in ProfileVehicleGalleryCategory.values) {
      if (value.name == name) return value;
    }
    return ProfileVehicleGalleryCategory.exterior;
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
