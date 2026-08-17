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

enum SocialPostVisibility {
  public('public'),
  contacts('contacts'),
  onlyMe('onlyMe');

  const SocialPostVisibility(this.firestoreValue);

  final String firestoreValue;

  static SocialPostVisibility fromFirestore(dynamic value) {
    return SocialPostVisibility.values.firstWhere(
      (item) => item.firestoreValue == value,
      orElse: () => SocialPostVisibility.onlyMe,
    );
  }
}

enum SocialPostMediaType {
  image('image'),
  video('video');

  const SocialPostMediaType(this.firestoreValue);

  final String firestoreValue;

  static SocialPostMediaType fromFirestore(dynamic value) {
    return value == SocialPostMediaType.video.firestoreValue
        ? SocialPostMediaType.video
        : SocialPostMediaType.image;
  }
}

class SocialPostMedia {
  const SocialPostMedia({
    required this.url,
    required this.path,
    required this.type,
  });

  final String url;
  final String path;
  final SocialPostMediaType type;

  bool get isVideo => type == SocialPostMediaType.video;
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
    this.media = const <SocialPostMedia>[],
    this.isArchived = false,
    this.pinnedAt,
    this.caption,
    this.vehicleLabel,
    this.vehicleId,
    this.locationLabel,
  });

  final String id;
  final String ownerUserId;
  final String imageUrl;
  final String imagePath;
  final DateTime createdAt;
  final SocialPostSection section;
  final String visibility;
  final List<SocialPostMedia> media;
  final bool isArchived;
  final DateTime? pinnedAt;
  final String? caption;
  final String? vehicleLabel;
  final String? vehicleId;
  final String? locationLabel;

  SocialPostVisibility get visibilityMode =>
      SocialPostVisibility.fromFirestore(visibility);
  bool get isPinned => pinnedAt != null;
  List<SocialPostMedia> get resolvedMedia {
    if (media.isNotEmpty) return media;
    if (imageUrl.trim().isEmpty) return const <SocialPostMedia>[];
    return <SocialPostMedia>[
      SocialPostMedia(
        url: imageUrl,
        path: imagePath,
        type: SocialPostMediaType.image,
      ),
    ];
  }

  factory SocialPost.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    final mediaUrls = _stringList(data['mediaUrls']);
    final mediaPaths = _stringList(data['mediaPaths']);
    final mediaTypes = _stringList(data['mediaTypes']);
    final media = <SocialPostMedia>[];
    for (var index = 0; index < mediaUrls.length; index++) {
      final url = mediaUrls[index].trim();
      if (url.isEmpty) continue;
      media.add(
        SocialPostMedia(
          url: url,
          path: index < mediaPaths.length ? mediaPaths[index] : '',
          type: SocialPostMediaType.fromFirestore(
            index < mediaTypes.length ? mediaTypes[index] : 'image',
          ),
        ),
      );
    }

    return SocialPost(
      id: data['postId'] as String? ?? document.id,
      ownerUserId: data['ownerUserId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      imagePath: data['imagePath'] as String? ?? '',
      section: SocialPostSection.fromFirestore(data['section']),
      visibility: data['visibility'] as String? ?? 'private',
      media: media,
      isArchived: data['isArchived'] == true,
      pinnedAt: _dateTimeFromTimestamp(data['pinnedAt']),
      caption: data['caption'] as String?,
      vehicleLabel: data['vehicleLabel'] as String?,
      vehicleId: data['vehicleId'] as String?,
      locationLabel: data['locationLabel'] as String?,
      createdAt: _dateTimeFromTimestamp(data['createdAt']) ?? DateTime.now(),
    );
  }

  SocialPost copyWith({
    String? caption,
    String? vehicleLabel,
    String? vehicleId,
    String? locationLabel,
    String? visibility,
    bool? isArchived,
    DateTime? pinnedAt,
    bool clearPinnedAt = false,
  }) {
    return SocialPost(
      id: id,
      ownerUserId: ownerUserId,
      imageUrl: imageUrl,
      imagePath: imagePath,
      createdAt: createdAt,
      section: section,
      visibility: visibility ?? this.visibility,
      media: media,
      isArchived: isArchived ?? this.isArchived,
      pinnedAt: clearPinnedAt ? null : pinnedAt ?? this.pinnedAt,
      caption: caption ?? this.caption,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      vehicleId: vehicleId ?? this.vehicleId,
      locationLabel: locationLabel ?? this.locationLabel,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }

  static DateTime? _dateTimeFromTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }
}

class SocialPostComment {
  const SocialPostComment({
    required this.id,
    required this.postId,
    required this.postOwnerUserId,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.authorPhotoUrl,
    required this.text,
    required this.createdAt,
    required this.isDeleted,
  });

  final String id;
  final String postId;
  final String postOwnerUserId;
  final String authorUserId;
  final String authorDisplayName;
  final String authorPhotoUrl;
  final String text;
  final DateTime createdAt;
  final bool isDeleted;

  factory SocialPostComment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return SocialPostComment(
      id: data['commentId'] as String? ?? document.id,
      postId: data['postId'] as String? ?? '',
      postOwnerUserId: data['postOwnerUserId'] as String? ?? '',
      authorUserId: data['authorUserId'] as String? ?? '',
      authorDisplayName: data['authorDisplayName'] as String? ?? 'Nutzer',
      authorPhotoUrl: data['authorPhotoUrl'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt:
          SocialPost._dateTimeFromTimestamp(data['createdAt']) ??
          DateTime.now(),
      isDeleted: data['isDeleted'] == true,
    );
  }
}

class SocialPostLike {
  const SocialPostLike({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.createdAt,
  });

  final String userId;
  final String displayName;
  final String photoUrl;
  final DateTime createdAt;

  factory SocialPostLike.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return SocialPostLike(
      userId: data['userId'] as String? ?? document.id,
      displayName: data['displayName'] as String? ?? 'plaqa Nutzer',
      photoUrl: data['photoUrl'] as String? ?? '',
      createdAt:
          SocialPost._dateTimeFromTimestamp(data['createdAt']) ??
          DateTime.now(),
    );
  }
}

enum SocialPostCommentReaction {
  like('like'),
  dislike('dislike'),
  heart('heart');

  const SocialPostCommentReaction(this.firestoreValue);

  final String firestoreValue;

  static SocialPostCommentReaction? fromFirestore(dynamic value) {
    for (final reaction in values) {
      if (reaction.firestoreValue == value) return reaction;
    }
    return null;
  }
}
