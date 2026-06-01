import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatStoryRecord {
  const ChatStoryRecord({
    required this.id,
    required this.ownerUserId,
    required this.ownerDisplayName,
    this.ownerPhotoUrl,
    required this.imageUrl,
    required this.imagePath,
    this.mediaType = 'image',
    this.videoUrl = '',
    this.videoPath = '',
    this.videoIsMuted = false,
    this.text = '',
    this.textColorValue = 0xFFFFFFFF,
    this.textFontFamily = 'standard',
    this.textIsBold = true,
    this.textIsItalic = false,
    this.textIsUnderline = false,
    this.textAlignmentX = 0.5,
    this.textAlignmentY = 0.58,
    this.filterType = 'normal',
    this.stickerType = '',
    this.stickerLabel = '',
    this.stickerPayload = '',
    this.stickerAlignmentX = 0.5,
    this.stickerAlignmentY = 0.76,
    this.viewedAtBy = const <String, DateTime>{},
    this.viewerNameBy = const <String, String>{},
    this.viewerPhotoUrlBy = const <String, String>{},
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String ownerUserId;
  final String ownerDisplayName;
  final String? ownerPhotoUrl;
  final String imageUrl;
  final String imagePath;
  final String mediaType;
  final String videoUrl;
  final String videoPath;
  final bool videoIsMuted;
  final String text;
  final int textColorValue;
  final String textFontFamily;
  final bool textIsBold;
  final bool textIsItalic;
  final bool textIsUnderline;
  final double textAlignmentX;
  final double textAlignmentY;
  final String filterType;
  final String stickerType;
  final String stickerLabel;
  final String stickerPayload;
  final double stickerAlignmentX;
  final double stickerAlignmentY;
  final Map<String, DateTime> viewedAtBy;
  final Map<String, String> viewerNameBy;
  final Map<String, String> viewerPhotoUrlBy;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isExpired {
    return !expiresAt.isAfter(DateTime.now());
  }

  bool get isVideo {
    return mediaType == 'video' && videoUrl.trim().isNotEmpty;
  }
}

class ChatStoryRepository {
  ChatStoryRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _storiesCollection {
    return _firestore.collection('chat_stories');
  }

  Stream<List<ChatStoryRecord>> watchVisibleStories({required String userId}) {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return Stream<List<ChatStoryRecord>>.value(const <ChatStoryRecord>[]);
    }

    final now = DateTime.now();

    return _storiesCollection
        .where('viewerUserIds', arrayContains: trimmedUserId)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .snapshots()
        .map((snapshot) {
          final stories =
              snapshot.docs
                  .map(_storyFromSnapshot)
                  .where((story) => !story.isExpired)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return stories;
        });
  }

  Future<void> setOwnImageStory({
    required String ownerUserId,
    required String ownerDisplayName,
    String? ownerPhotoUrl,
    required Iterable<String> viewerUserIds,
    required String imageUrl,
    required String imagePath,
    String mediaType = 'image',
    String videoUrl = '',
    String videoPath = '',
    bool videoIsMuted = false,
    String text = '',
    int textColorValue = 0xFFFFFFFF,
    String textFontFamily = 'standard',
    bool textIsBold = true,
    bool textIsItalic = false,
    bool textIsUnderline = false,
    double textAlignmentX = 0.5,
    double textAlignmentY = 0.58,
    String filterType = 'normal',
    String stickerType = '',
    String stickerLabel = '',
    String stickerPayload = '',
    double stickerAlignmentX = 0.5,
    double stickerAlignmentY = 0.76,
  }) async {
    final trimmedOwnerUserId = ownerUserId.trim();
    final trimmedOwnerDisplayName = ownerDisplayName.trim();
    final trimmedOwnerPhotoUrl = ownerPhotoUrl?.trim() ?? '';
    final trimmedImageUrl = imageUrl.trim();
    final trimmedImagePath = imagePath.trim();
    final trimmedMediaType = mediaType.trim() == 'video' ? 'video' : 'image';
    final trimmedVideoUrl = videoUrl.trim();
    final trimmedVideoPath = videoPath.trim();
    final safeStoryText = _limitedText(text, 280);
    final safeTextFontFamily = _safeStoryTextFontFamily(textFontFamily);
    final safeFilterType = _safeStoryFilterType(filterType);
    final safeStickerType = _safeStoryStickerType(stickerType);
    final safeStickerPayload = _safeStoryStickerPayload(
      safeStickerType,
      stickerPayload,
    );
    final effectiveStickerType = safeStickerPayload.isEmpty
        ? ''
        : safeStickerType;
    final safeStickerLabel = _safeStoryStickerLabel(
      effectiveStickerType,
      stickerLabel,
      safeStickerPayload,
    );
    final normalizedViewerUserIds = <String>{
      trimmedOwnerUserId,
      for (final userId in viewerUserIds)
        if (userId.trim().isNotEmpty) userId.trim(),
    }.toList()..sort();
    final safeViewerUserIds = <String>[
      trimmedOwnerUserId,
      ...normalizedViewerUserIds
          .where((userId) => userId != trimmedOwnerUserId)
          .take(199),
    ];

    if (trimmedOwnerUserId.isEmpty ||
        trimmedOwnerDisplayName.isEmpty ||
        (trimmedMediaType == 'image' &&
            (trimmedImageUrl.isEmpty || trimmedImagePath.isEmpty)) ||
        (trimmedMediaType == 'video' &&
            (trimmedVideoUrl.isEmpty || trimmedVideoPath.isEmpty))) {
      throw ArgumentError('Story owner and image data must not be empty.');
    }

    final now = DateTime.now();
    final storyReference = _storiesCollection.doc(trimmedOwnerUserId);
    final previousStorySnapshot = await storyReference.get();
    final previousImagePath =
        (previousStorySnapshot.data()?['imagePath'] as String? ?? '').trim();
    final previousVideoPath =
        (previousStorySnapshot.data()?['videoPath'] as String? ?? '').trim();

    await storyReference.set({
      'ownerUserId': trimmedOwnerUserId,
      'ownerDisplayName': trimmedOwnerDisplayName,
      'ownerPhotoUrl': trimmedOwnerPhotoUrl.isEmpty
          ? null
          : trimmedOwnerPhotoUrl,
      'viewerUserIds': safeViewerUserIds,
      'viewerNameBy': <String, String>{
        trimmedOwnerUserId: trimmedOwnerDisplayName,
      },
      if (trimmedOwnerPhotoUrl.isNotEmpty)
        'viewerPhotoUrlBy': <String, String>{
          trimmedOwnerUserId: trimmedOwnerPhotoUrl,
        },
      'viewedAtBy': <String, Timestamp>{
        trimmedOwnerUserId: Timestamp.fromDate(now),
      },
      'imageUrl': trimmedImageUrl,
      'imagePath': trimmedImagePath,
      'mediaType': trimmedMediaType,
      'videoUrl': trimmedVideoUrl,
      'videoPath': trimmedVideoPath,
      'videoIsMuted': videoIsMuted,
      'text': safeStoryText,
      'textColorValue': textColorValue,
      'textFontFamily': safeTextFontFamily,
      'textIsBold': textIsBold,
      'textIsItalic': textIsItalic,
      'textIsUnderline': textIsUnderline,
      'textAlignmentX': textAlignmentX.clamp(0.08, 0.92),
      'textAlignmentY': textAlignmentY.clamp(0.18, 0.82),
      'filterType': safeFilterType,
      'stickerType': effectiveStickerType,
      'stickerLabel': safeStickerLabel,
      'stickerPayload': safeStickerPayload,
      'stickerAlignmentX': stickerAlignmentX.clamp(0.08, 0.92),
      'stickerAlignmentY': stickerAlignmentY.clamp(0.18, 0.86),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
    });

    if (previousImagePath.isNotEmpty && previousImagePath != trimmedImagePath) {
      await _deleteStorageObjectIfExists(previousImagePath);
    }

    if (previousVideoPath.isNotEmpty && previousVideoPath != trimmedVideoPath) {
      await _deleteStorageObjectIfExists(previousVideoPath);
    }
  }

  Future<void> markStoryViewed({
    required String storyId,
    required String userId,
    required String displayName,
    String? photoUrl,
  }) async {
    final trimmedStoryId = storyId.trim();
    final trimmedUserId = userId.trim();
    final trimmedDisplayName = displayName.trim();
    final trimmedPhotoUrl = photoUrl?.trim() ?? '';

    if (trimmedStoryId.isEmpty || trimmedUserId.isEmpty) {
      return;
    }

    await _storiesCollection.doc(trimmedStoryId).set({
      'viewedAtBy.$trimmedUserId': FieldValue.serverTimestamp(),
      'viewerNameBy.$trimmedUserId': trimmedDisplayName.isEmpty
          ? 'Carma Nutzer'
          : trimmedDisplayName,
      if (trimmedPhotoUrl.isNotEmpty)
        'viewerPhotoUrlBy.$trimmedUserId': trimmedPhotoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateStoryViewerPhotoUrl({
    required String storyId,
    required String userId,
    required String photoUrl,
  }) async {
    final trimmedStoryId = storyId.trim();
    final trimmedUserId = userId.trim();
    final trimmedPhotoUrl = photoUrl.trim();

    if (trimmedStoryId.isEmpty ||
        trimmedUserId.isEmpty ||
        trimmedPhotoUrl.isEmpty) {
      return;
    }

    await _storiesCollection.doc(trimmedStoryId).set({
      'viewerPhotoUrlBy.$trimmedUserId': trimmedPhotoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteOwnStory({required String ownerUserId}) async {
    final trimmedOwnerUserId = ownerUserId.trim();

    if (trimmedOwnerUserId.isEmpty) {
      return;
    }

    final storyReference = _storiesCollection.doc(trimmedOwnerUserId);
    final storySnapshot = await storyReference.get();
    final imagePath = (storySnapshot.data()?['imagePath'] as String? ?? '')
        .trim();
    final videoPath = (storySnapshot.data()?['videoPath'] as String? ?? '')
        .trim();

    await _deleteStorageObjectIfExists(imagePath);
    await _deleteStorageObjectIfExists(videoPath);

    await storyReference.delete();
  }

  Future<void> deleteExpiredOwnStory({required String ownerUserId}) async {
    final trimmedOwnerUserId = ownerUserId.trim();

    if (trimmedOwnerUserId.isEmpty) {
      return;
    }

    final storySnapshot = await _storiesCollection
        .doc(trimmedOwnerUserId)
        .get();

    if (!storySnapshot.exists) {
      return;
    }

    final story = _storyFromSnapshot(storySnapshot);

    if (!story.isExpired) {
      return;
    }

    await deleteOwnStory(ownerUserId: trimmedOwnerUserId);
  }

  Future<void> _deleteStorageObjectIfExists(String path) async {
    final trimmedPath = path.trim();

    if (trimmedPath.isEmpty) {
      return;
    }

    try {
      await _storage.ref(trimmedPath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  ChatStoryRecord _storyFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return ChatStoryRecord(
      id: snapshot.id,
      ownerUserId: data['ownerUserId'] as String? ?? '',
      ownerDisplayName: data['ownerDisplayName'] as String? ?? 'Carma Nutzer',
      ownerPhotoUrl: data['ownerPhotoUrl'] as String?,
      imageUrl: data['imageUrl'] as String? ?? '',
      imagePath: data['imagePath'] as String? ?? '',
      mediaType: data['mediaType'] as String? ?? 'image',
      videoUrl: data['videoUrl'] as String? ?? '',
      videoPath: data['videoPath'] as String? ?? '',
      videoIsMuted: data['videoIsMuted'] as bool? ?? false,
      text: data['text'] as String? ?? '',
      textColorValue: data['textColorValue'] as int? ?? 0xFFFFFFFF,
      textFontFamily: _safeStoryTextFontFamily(data['textFontFamily']),
      textIsBold: data['textIsBold'] as bool? ?? true,
      textIsItalic: data['textIsItalic'] as bool? ?? false,
      textIsUnderline: data['textIsUnderline'] as bool? ?? false,
      textAlignmentX: _doubleFromValue(data['textAlignmentX']) ?? 0.5,
      textAlignmentY: _doubleFromValue(data['textAlignmentY']) ?? 0.58,
      filterType: _safeStoryFilterType(data['filterType']),
      stickerType: data['stickerType'] as String? ?? '',
      stickerLabel: data['stickerLabel'] as String? ?? '',
      stickerPayload: data['stickerPayload'] as String? ?? '',
      stickerAlignmentX: _doubleFromValue(data['stickerAlignmentX']) ?? 0.5,
      stickerAlignmentY: _doubleFromValue(data['stickerAlignmentY']) ?? 0.76,
      viewedAtBy: _dateTimeMapFromValue(data['viewedAtBy']),
      viewerNameBy: _stringMapFromValue(data['viewerNameBy']),
      viewerPhotoUrlBy: _stringMapFromValue(data['viewerPhotoUrlBy']),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime(1970),
      expiresAt: _dateTimeFromValue(data['expiresAt']) ?? DateTime(1970),
    );
  }

  DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  double? _doubleFromValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }

  Map<String, DateTime> _dateTimeMapFromValue(Object? value) {
    if (value is! Map) {
      return const <String, DateTime>{};
    }

    final entries = <String, DateTime>{};

    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      final dateTime = _dateTimeFromValue(entry.value);

      if (key.isNotEmpty && dateTime != null) {
        entries[key] = dateTime;
      }
    }

    return entries;
  }

  Map<String, String> _stringMapFromValue(Object? value) {
    if (value is! Map) {
      return const <String, String>{};
    }

    final entries = <String, String>{};

    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      final label = entry.value?.toString().trim() ?? '';

      if (key.isNotEmpty && label.isNotEmpty) {
        entries[key] = label;
      }
    }

    return entries;
  }

  String _safeStoryTextFontFamily(Object? value) {
    final textFontFamily = value?.toString().trim() ?? '';

    return switch (textFontFamily) {
      'rounded' ||
      'serif' ||
      'mono' ||
      'condensed' ||
      'light' ||
      'medium' ||
      'black' ||
      'casual' ||
      'cursive' => textFontFamily,
      _ => 'standard',
    };
  }

  String _safeStoryFilterType(Object? value) {
    final filterType = value?.toString().trim() ?? '';

    return switch (filterType) {
      'warm' || 'cool' || 'mono' || 'soft' => filterType,
      _ => 'normal',
    };
  }

  String _safeStoryStickerType(Object? value) {
    final stickerType = value?.toString().trim() ?? '';

    return switch (stickerType) {
      'location' ||
      'link' ||
      'hashtag' ||
      'vehicle' ||
      'status' ||
      'poll' => stickerType,
      _ => '',
    };
  }

  String _safeStoryStickerPayload(String type, Object? value) {
    final payload = value?.toString().trim() ?? '';

    if (type.isEmpty || payload.isEmpty) {
      return '';
    }

    if (type == 'location') {
      return RegExp(
            r'^-?[0-9]+\.[0-9]{1,6},-?[0-9]+\.[0-9]{1,6}$',
          ).hasMatch(payload)
          ? payload
          : '';
    }

    if (type == 'link') {
      final normalizedPayload =
          payload.startsWith('http://') || payload.startsWith('https://')
          ? payload
          : 'https://$payload';

      return _limitedText(normalizedPayload, 300);
    }

    if (type == 'vehicle') {
      return _limitedText(payload, 24);
    }

    if (type == 'status') {
      return _limitedText(payload, 32);
    }

    if (type == 'poll') {
      final options = payload
          .split('\n')
          .map((option) => _limitedText(option, 28))
          .where((option) => option.isNotEmpty)
          .take(2)
          .toList(growable: false);

      return options.length < 2 ? '' : options.join('\n');
    }

    return _limitedText(payload.replaceFirst(RegExp(r'^#+'), ''), 79);
  }

  String _safeStoryStickerLabel(
    String type,
    Object? value,
    String safePayload,
  ) {
    if (type.isEmpty || safePayload.isEmpty) {
      return '';
    }

    final label = value?.toString().trim() ?? '';

    if (type == 'location') {
      final locationLabel = label.isEmpty ? 'Aktueller Standort' : label;
      return _limitedText(locationLabel, 80);
    }

    if (type == 'link') {
      final linkLabel = label.isEmpty ? safePayload : label;
      return _limitedText(linkLabel, 80);
    }

    if (type == 'vehicle') {
      final vehicleLabel = label.isEmpty ? 'Fahrzeug' : label;
      return _limitedText(vehicleLabel, 80);
    }

    if (type == 'status') {
      final statusLabel = label.isEmpty ? safePayload : label;
      return _limitedText(statusLabel, 32);
    }

    if (type == 'poll') {
      return _limitedText(label, 80);
    }

    final hashtagLabel = label.replaceFirst(RegExp(r'^#+'), '');
    final hashtag = hashtagLabel.isEmpty ? safePayload : hashtagLabel;
    return '#${_limitedText(hashtag, 79)}';
  }

  String _limitedText(Object? value, int maxLength) {
    final text = value?.toString().trim() ?? '';

    if (text.length <= maxLength) {
      return text;
    }

    return text.substring(0, maxLength).trim();
  }
}
