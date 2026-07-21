import 'package:cloud_firestore/cloud_firestore.dart';

enum SocialPostSection {
  posts('posts'),
  vehicle('vehicle');

  const SocialPostSection(this.firestoreValue);

  final String firestoreValue;

  static SocialPostSection fromFirestore(dynamic value) {
    return value == SocialPostSection.vehicle.firestoreValue
        ? SocialPostSection.vehicle
        : SocialPostSection.posts;
  }
}

class SocialPost {
  const SocialPost({
    required this.id,
    required this.ownerUserId,
    required this.imageUrl,
    required this.imagePath,
    required this.createdAt,
    required this.section,
    required this.visibility,
    this.caption,
    this.vehicleLabel,
    this.locationLabel,
  });

  final String id;
  final String ownerUserId;
  final String imageUrl;
  final String imagePath;
  final DateTime createdAt;
  final SocialPostSection section;
  final String visibility;
  final String? caption;
  final String? vehicleLabel;
  final String? locationLabel;

  factory SocialPost.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return SocialPost(
      id: data['postId'] as String? ?? document.id,
      ownerUserId: data['ownerUserId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      imagePath: data['imagePath'] as String? ?? '',
      section: SocialPostSection.fromFirestore(data['section']),
      visibility: data['visibility'] as String? ?? 'private',
      caption: data['caption'] as String?,
      vehicleLabel: data['vehicleLabel'] as String?,
      locationLabel: data['locationLabel'] as String?,
      createdAt: _dateTimeFromTimestamp(data['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _dateTimeFromTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }
}
