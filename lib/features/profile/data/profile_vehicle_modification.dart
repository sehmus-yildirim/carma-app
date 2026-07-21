import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile_vehicle.dart';

enum ProfileVehicleModificationCategory {
  wheels,
  tires,
  suspension,
  brakes,
  engine,
  software,
  exhaust,
  lighting,
  body,
  wrap,
  interior,
  soundSystem,
  other,
}

class ProfileVehicleModification {
  const ProfileVehicleModification({
    required this.id,
    required this.ownerUserId,
    required this.vehicleId,
    required this.title,
    required this.category,
    this.manufacturer,
    this.product,
    this.description,
    this.modifiedAt,
    this.workshop,
    this.costCents,
    this.powerChangeHp,
    this.isRegistered = false,
    this.documentPaths = const [],
    this.visibility = ProfileVehicleVisibility.onlyMe,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String vehicleId;
  final String title;
  final ProfileVehicleModificationCategory category;
  final String? manufacturer;
  final String? product;
  final String? description;
  final DateTime? modifiedAt;
  final String? workshop;
  final int? costCents;
  final int? powerChangeHp;
  final bool isRegistered;
  final List<String> documentPaths;
  final ProfileVehicleVisibility visibility;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPubliclyVisible =>
      visibility == ProfileVehicleVisibility.contacts && !isDeleted;

  factory ProfileVehicleModification.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ProfileVehicleModification(
      id: id,
      ownerUserId: data['ownerUserId'] as String? ?? '',
      vehicleId: data['vehicleId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      category: _categoryFromName(data['category'] as String?),
      manufacturer: data['manufacturer'] as String?,
      product: data['product'] as String?,
      description: data['description'] as String?,
      modifiedAt: _dateTimeFromValue(data['modifiedAt']),
      workshop: data['workshop'] as String?,
      costCents: data['costCents'] as int?,
      powerChangeHp: data['powerChangeHp'] as int?,
      isRegistered: data['isRegistered'] as bool? ?? false,
      documentPaths: _stringListFromValue(data['documentPaths']),
      visibility: data['visibility'] == ProfileVehicleVisibility.contacts.name
          ? ProfileVehicleVisibility.contacts
          : ProfileVehicleVisibility.onlyMe,
      isDeleted: data['isDeleted'] as bool? ?? false,
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }

  Map<String, Object?> toPrivateFirestore() {
    return <String, Object?>{
      'modificationId': id.trim(),
      'ownerUserId': ownerUserId.trim(),
      'vehicleId': vehicleId.trim(),
      'title': title.trim(),
      'category': category.name,
      'manufacturer': _trimmedOrNull(manufacturer),
      'product': _trimmedOrNull(product),
      'description': _trimmedOrNull(description),
      'modifiedAt': modifiedAt == null ? null : Timestamp.fromDate(modifiedAt!),
      'workshop': _trimmedOrNull(workshop),
      'costCents': costCents,
      'powerChangeHp': powerChangeHp,
      'isRegistered': isRegistered,
      'documentPaths': _normalizedStringList(documentPaths),
      'visibility': visibility.name,
      'isDeleted': isDeleted,
    };
  }

  Map<String, Object?> toPublicFirestore() {
    return <String, Object?>{
      'modificationId': id.trim(),
      'ownerUserId': ownerUserId.trim(),
      'vehicleId': vehicleId.trim(),
      'title': title.trim(),
      'category': category.name,
      'manufacturer': _trimmedOrNull(manufacturer),
      'product': _trimmedOrNull(product),
      'description': _trimmedOrNull(description),
      'modifiedAt': modifiedAt == null ? null : Timestamp.fromDate(modifiedAt!),
      'powerChangeHp': powerChangeHp,
      'isRegistered': isRegistered,
      'visibility': ProfileVehicleVisibility.contacts.name,
      'isDeleted': false,
    };
  }

  ProfileVehicleModification copyWith({
    String? title,
    ProfileVehicleModificationCategory? category,
    String? manufacturer,
    String? product,
    String? description,
    DateTime? modifiedAt,
    String? workshop,
    int? costCents,
    int? powerChangeHp,
    bool? isRegistered,
    List<String>? documentPaths,
    ProfileVehicleVisibility? visibility,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileVehicleModification(
      id: id,
      ownerUserId: ownerUserId,
      vehicleId: vehicleId,
      title: title ?? this.title,
      category: category ?? this.category,
      manufacturer: manufacturer ?? this.manufacturer,
      product: product ?? this.product,
      description: description ?? this.description,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      workshop: workshop ?? this.workshop,
      costCents: costCents ?? this.costCents,
      powerChangeHp: powerChangeHp ?? this.powerChangeHp,
      isRegistered: isRegistered ?? this.isRegistered,
      documentPaths: documentPaths ?? this.documentPaths,
      visibility: visibility ?? this.visibility,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static ProfileVehicleModificationCategory _categoryFromName(String? name) {
    for (final value in ProfileVehicleModificationCategory.values) {
      if (value.name == name) return value;
    }
    return ProfileVehicleModificationCategory.other;
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

  static List<String> _stringListFromValue(Object? value) {
    if (value is! List) return const [];
    return _normalizedStringList(value.whereType<String>());
  }

  static List<String> _normalizedStringList(Iterable<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
