import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../shared/security/trusted_firebase_media_url.dart';

final RegExp _storyStoragePathPattern = RegExp(
  r'^chat_stories/([^/]+)/(?:[0-9]{12,24}\.(?:jpg|mp4)|[0-9]{12,24}/media\.(?:jpg|mp4))$',
);

class ChatStoryStickerRecord {
  const ChatStoryStickerRecord({
    required this.type,
    required this.label,
    required this.payload,
    required this.alignmentX,
    required this.alignmentY,
  });

  final String type;
  final String label;
  final String payload;
  final double alignmentX;
  final double alignmentY;

  bool get isEmpty => type.trim().isEmpty || label.trim().isEmpty;
}

class ChatStoryRecord {
  const ChatStoryRecord({
    required this.id,
    required this.ownerUserId,
    required this.ownerDisplayName,
    this.ownerPhotoUrl,
    this.viewerUserIds = const <String>[],
    this.repliesEnabled = true,
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
    this.textAlign = 'center',
    this.textAlignmentX = 0.5,
    this.textAlignmentY = 0.58,
    this.filterType = 'normal',
    this.stickerType = '',
    this.stickerLabel = '',
    this.stickerPayload = '',
    this.stickerAlignmentX = 0.5,
    this.stickerAlignmentY = 0.76,
    this.stickers = const <ChatStoryStickerRecord>[],
    this.viewedAtBy = const <String, DateTime>{},
    this.viewerNameBy = const <String, String>{},
    this.viewerPhotoUrlBy = const <String, String>{},
    this.pollVoteBy = const <String, int>{},
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String ownerUserId;
  final String ownerDisplayName;
  final String? ownerPhotoUrl;
  final List<String> viewerUserIds;
  final bool repliesEnabled;
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
  final String textAlign;
  final double textAlignmentX;
  final double textAlignmentY;
  final String filterType;
  final String stickerType;
  final String stickerLabel;
  final String stickerPayload;
  final double stickerAlignmentX;
  final double stickerAlignmentY;
  final List<ChatStoryStickerRecord> stickers;
  final Map<String, DateTime> viewedAtBy;
  final Map<String, String> viewerNameBy;
  final Map<String, String> viewerPhotoUrlBy;
  final Map<String, int> pollVoteBy;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isExpired {
    return !expiresAt.isAfter(DateTime.now());
  }

  bool get isVideo {
    return mediaType == 'video' && videoUrl.trim().isNotEmpty;
  }

  bool get hasRenderableMedia {
    if (mediaType == 'video') {
      return videoUrl.trim().isNotEmpty;
    }

    return imageUrl.trim().isNotEmpty;
  }

  bool canReceiveReplyFrom(String viewerUserId) {
    final normalizedViewerUserId = viewerUserId.trim();
    return repliesEnabled &&
        normalizedViewerUserId.isNotEmpty &&
        normalizedViewerUserId != ownerUserId.trim() &&
        viewerUserIds.any(
          (userId) => userId.trim() == normalizedViewerUserId,
        ) &&
        !isExpired;
  }

  List<ChatStoryStickerRecord> get effectiveStickers {
    if (stickers.isNotEmpty) {
      return stickers;
    }

    if (stickerType.trim().isEmpty || stickerLabel.trim().isEmpty) {
      return const <ChatStoryStickerRecord>[];
    }

    return <ChatStoryStickerRecord>[
      ChatStoryStickerRecord(
        type: stickerType,
        label: stickerLabel,
        payload: stickerPayload,
        alignmentX: stickerAlignmentX,
        alignmentY: stickerAlignmentY,
      ),
    ];
  }
}

class ChatStoryRepository {
  ChatStoryRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  static const Set<int> _allowedStoryTextColorValues = <int>{
    4294967295,
    4294965429,
    4294956367,
    4294941245,
    4294925404,
    4294922138,
    4293425657,
    4290807036,
    4286331629,
    4282090230,
    4281908728,
    4280472558,
    4281193663,
    4283096704,
    4288931381,
    4293257195,
    4279310375,
    4278190080,
  };

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _storiesCollection {
    return _firestore.collection('chat_stories');
  }

  Stream<List<ChatStoryRecord>> watchOwnerStories({
    required String ownerUserId,
  }) {
    final trimmedOwnerUserId = ownerUserId.trim();

    if (trimmedOwnerUserId.isEmpty) {
      return Stream<List<ChatStoryRecord>>.value(const <ChatStoryRecord>[]);
    }

    return _storiesCollection
        .where('ownerUserId', isEqualTo: trimmedOwnerUserId)
        .snapshots()
        .map((snapshot) {
          final stories =
              snapshot.docs
                  .map(_storyFromSnapshot)
                  .where(
                    (story) => !story.isExpired && story.hasRenderableMedia,
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return stories;
        });
  }

  Stream<List<ChatStoryRecord>> watchVisibleStories({required String userId}) {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return Stream<List<ChatStoryRecord>>.value(const <ChatStoryRecord>[]);
    }

    return _storiesCollection
        .where('viewerUserIds', arrayContains: trimmedUserId)
        .where('isActive', isEqualTo: true)
        .where(
          'expiresAt',
          isGreaterThan: Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 1)),
          ),
        )
        .snapshots()
        .map((snapshot) {
          final stories =
              snapshot.docs
                  .map(_storyFromSnapshot)
                  .where(
                    (story) => !story.isExpired && story.hasRenderableMedia,
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return stories;
        });
  }

  Future<ChatStoryRecord?> getStoryById(String storyId) async {
    final trimmedStoryId = storyId.trim();

    if (trimmedStoryId.isEmpty) {
      return null;
    }

    final snapshot = await _storiesCollection.doc(trimmedStoryId).get();

    if (!snapshot.exists) {
      return null;
    }

    final story = _storyFromSnapshot(snapshot);
    return story.hasRenderableMedia ? story : null;
  }

  Future<void> setOwnImageStory({
    required String storyId,
    required String ownerUserId,
    required String ownerDisplayName,
    String? ownerPhotoUrl,
    required Iterable<String> viewerUserIds,
    bool repliesEnabled = true,
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
    String textAlign = 'center',
    double textAlignmentX = 0.5,
    double textAlignmentY = 0.58,
    String filterType = 'normal',
    String stickerType = '',
    String stickerLabel = '',
    String stickerPayload = '',
    double stickerAlignmentX = 0.5,
    double stickerAlignmentY = 0.76,
    List<ChatStoryStickerRecord> stickers = const <ChatStoryStickerRecord>[],
  }) async {
    final trimmedStoryId = storyId.trim();
    final trimmedOwnerUserId = ownerUserId.trim();
    final trimmedOwnerDisplayName = ownerDisplayName.trim();
    final safeOwnerPhotoUrl =
        trustedProfilePhotoUrl(
          url: ownerPhotoUrl,
          userId: trimmedOwnerUserId,
        ) ??
        '';
    final trimmedImageUrl = imageUrl.trim();
    final trimmedImagePath = imagePath.trim();
    final trimmedMediaType = mediaType.trim() == 'video' ? 'video' : 'image';
    final trimmedVideoUrl = videoUrl.trim();
    final trimmedVideoPath = videoPath.trim();
    final safeStoryText = _limitedText(text, 280);
    final safeTextColorValue = _safeStoryTextColorValue(textColorValue);
    final safeTextFontFamily = _safeStoryTextFontFamily(textFontFamily);
    final safeTextAlign = _safeStoryTextAlign(textAlign);
    final safeFilterType = _safeStoryFilterType(filterType);
    final safeStickers = _safeStoryStickers(stickers);
    final safeLegacySticker = _safeStorySticker(
      ChatStoryStickerRecord(
        type: stickerType,
        label: stickerLabel,
        payload: stickerPayload,
        alignmentX: stickerAlignmentX,
        alignmentY: stickerAlignmentY,
      ),
    );
    final effectiveStickers = safeStickers.isNotEmpty
        ? safeStickers
        : safeLegacySticker == null
        ? const <ChatStoryStickerRecord>[]
        : <ChatStoryStickerRecord>[safeLegacySticker];
    final legacySticker = effectiveStickers.isEmpty
        ? null
        : effectiveStickers.first;
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

    if (!RegExp(r'^[0-9]{12,24}$').hasMatch(trimmedStoryId) ||
        trimmedOwnerUserId.isEmpty ||
        trimmedOwnerDisplayName.isEmpty ||
        (trimmedMediaType == 'image' &&
            (trimmedImageUrl.isEmpty || trimmedImagePath.isEmpty)) ||
        (trimmedMediaType == 'video' &&
            (trimmedVideoUrl.isEmpty || trimmedVideoPath.isEmpty))) {
      throw ArgumentError('Die Story-Daten sind unvollständig oder ungültig.');
    }

    final now = DateTime.now();
    final storyReference = _storiesCollection.doc(trimmedStoryId);

    await storyReference.set({
      'ownerUserId': trimmedOwnerUserId,
      'ownerDisplayName': trimmedOwnerDisplayName,
      'ownerPhotoUrl': safeOwnerPhotoUrl.isEmpty ? null : safeOwnerPhotoUrl,
      'viewerUserIds': safeViewerUserIds,
      'repliesEnabled': repliesEnabled,
      'viewerNameBy': <String, String>{
        trimmedOwnerUserId: trimmedOwnerDisplayName,
      },
      if (safeOwnerPhotoUrl.isNotEmpty)
        'viewerPhotoUrlBy': <String, String>{
          trimmedOwnerUserId: safeOwnerPhotoUrl,
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
      'textColorValue': safeTextColorValue,
      'textFontFamily': safeTextFontFamily,
      'textIsBold': textIsBold,
      'textIsItalic': textIsItalic,
      'textIsUnderline': textIsUnderline,
      'textAlign': safeTextAlign,
      'textAlignmentX': textAlignmentX.clamp(0.08, 0.92),
      'textAlignmentY': textAlignmentY.clamp(0.18, 0.82),
      'filterType': safeFilterType,
      'stickerType': legacySticker?.type ?? '',
      'stickerLabel': legacySticker?.label ?? '',
      'stickerPayload': legacySticker?.payload ?? '',
      'stickerAlignmentX': legacySticker?.alignmentX ?? 0.5,
      'stickerAlignmentY': legacySticker?.alignmentY ?? 0.76,
      'stickers': <Map<String, Object>>[
        for (final sticker in effectiveStickers)
          <String, Object>{
            'type': sticker.type,
            'label': sticker.label,
            'payload': sticker.payload,
            'alignmentX': sticker.alignmentX,
            'alignmentY': sticker.alignmentY,
          },
      ],
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
      'isActive': true,
    });
  }

  Future<void> updateOwnStoryMediaUrl({
    required String storyId,
    required String ownerUserId,
    required String mediaType,
    required String url,
  }) async {
    final trimmedStoryId = storyId.trim();
    final trimmedOwnerUserId = ownerUserId.trim();
    final trimmedUrl = url.trim();
    final isVideo = mediaType.trim() == 'video';

    if (trimmedStoryId.isEmpty ||
        trimmedOwnerUserId.isEmpty ||
        trimmedUrl.isEmpty) {
      return;
    }

    final storyReference = _storiesCollection.doc(trimmedStoryId);
    final snapshot = await storyReference.get();
    if (!snapshot.exists ||
        (snapshot.data()?['ownerUserId'] as String? ?? '').trim() !=
            trimmedOwnerUserId) {
      return;
    }

    await storyReference.update({
      if (isVideo) 'videoUrl': trimmedUrl else 'imageUrl': trimmedUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    final safePhotoUrl =
        trustedProfilePhotoUrl(url: photoUrl, userId: trimmedUserId) ?? '';

    if (trimmedStoryId.isEmpty || trimmedUserId.isEmpty) {
      return;
    }

    await _storiesCollection.doc(trimmedStoryId).update({
      FieldPath(['viewedAtBy', trimmedUserId]): FieldValue.serverTimestamp(),
      FieldPath(['viewerNameBy', trimmedUserId]): trimmedDisplayName.isEmpty
          ? 'plaqa Nutzer'
          : trimmedDisplayName,
      if (safePhotoUrl.isNotEmpty)
        FieldPath(['viewerPhotoUrlBy', trimmedUserId]): safePhotoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStoryViewerPhotoUrl({
    required String storyId,
    required String userId,
    required String photoUrl,
  }) async {
    final trimmedStoryId = storyId.trim();
    final trimmedUserId = userId.trim();
    final safePhotoUrl =
        trustedProfilePhotoUrl(url: photoUrl, userId: trimmedUserId) ?? '';

    if (trimmedStoryId.isEmpty ||
        trimmedUserId.isEmpty ||
        safePhotoUrl.isEmpty) {
      return;
    }

    await _storiesCollection.doc(trimmedStoryId).update({
      FieldPath(['viewerPhotoUrlBy', trimmedUserId]): safePhotoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> voteStoryPoll({
    required String storyId,
    required String userId,
    required int optionIndex,
  }) async {
    return false;
  }

  Future<void> deleteOwnStory({
    required String storyId,
    required String ownerUserId,
  }) async {
    final trimmedStoryId = storyId.trim();
    final trimmedOwnerUserId = ownerUserId.trim();

    if (trimmedStoryId.isEmpty || trimmedOwnerUserId.isEmpty) {
      return;
    }

    final storyReference = _storiesCollection.doc(trimmedStoryId);
    final storySnapshot = await storyReference.get();

    if (!storySnapshot.exists) {
      return;
    }

    final storedOwnerUserId =
        (storySnapshot.data()?['ownerUserId'] as String? ?? '').trim();
    if (storedOwnerUserId != trimmedOwnerUserId) {
      return;
    }

    final imagePath = (storySnapshot.data()?['imagePath'] as String? ?? '')
        .trim();
    final videoPath = (storySnapshot.data()?['videoPath'] as String? ?? '')
        .trim();

    await _deleteStorageObjectIfExists(
      ownerUserId: trimmedOwnerUserId,
      path: imagePath,
    );
    await _deleteStorageObjectIfExists(
      ownerUserId: trimmedOwnerUserId,
      path: videoPath,
    );

    await storyReference.delete();
  }

  Future<void> deleteExpiredOwnStory({required String ownerUserId}) async {
    final trimmedOwnerUserId = ownerUserId.trim();

    if (trimmedOwnerUserId.isEmpty) {
      return;
    }

    final storySnapshots = await _storiesCollection
        .where('ownerUserId', isEqualTo: trimmedOwnerUserId)
        .get();

    for (final storySnapshot in storySnapshots.docs) {
      final story = _storyFromSnapshot(storySnapshot);
      if (!story.isExpired) continue;
      await deleteOwnStory(storyId: story.id, ownerUserId: trimmedOwnerUserId);
    }
  }

  Future<void> _deleteStorageObjectIfExists({
    required String ownerUserId,
    required String path,
  }) async {
    final trimmedOwnerUserId = ownerUserId.trim();
    final trimmedPath = path.trim();

    if (trimmedOwnerUserId.isEmpty ||
        trimmedPath.isEmpty ||
        !_isOwnStoryStoragePath(
          ownerUserId: trimmedOwnerUserId,
          path: trimmedPath,
        )) {
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

  bool _isOwnStoryStoragePath({
    required String ownerUserId,
    required String path,
  }) {
    final match = _storyStoragePathPattern.firstMatch(path.trim());

    return match != null && match.group(1) == ownerUserId.trim();
  }

  ChatStoryRecord _storyFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final imagePath = (data['imagePath'] as String? ?? '').trim();
    final videoPath = (data['videoPath'] as String? ?? '').trim();
    final imageUrl =
        trustedFirebaseMediaUrl(
          url: data['imageUrl'],
          storagePath: imagePath,
        ) ??
        '';
    final videoUrl =
        trustedFirebaseMediaUrl(
          url: data['videoUrl'],
          storagePath: videoPath,
        ) ??
        '';
    final safeMediaType = _safeStoryMediaType(data['mediaType']);
    final safeStickerType = _safeStoryStickerType(data['stickerType']);
    final safeStickerPayload = _safeStoryStickerPayload(
      safeStickerType,
      data['stickerPayload'],
    );
    final safeStickerLabel = _safeStoryStickerLabel(
      safeStickerType,
      data['stickerLabel'],
      safeStickerPayload,
    );
    final safeStickers = _storyStickersFromValue(data['stickers']);

    final ownerUserId = (data['ownerUserId'] as String? ?? '').trim();
    return ChatStoryRecord(
      id: snapshot.id,
      ownerUserId: ownerUserId,
      ownerDisplayName: data['ownerDisplayName'] as String? ?? 'plaqa Nutzer',
      ownerPhotoUrl: trustedProfilePhotoUrl(
        url: data['ownerPhotoUrl'],
        userId: ownerUserId,
      ),
      viewerUserIds: _stringListFromValue(data['viewerUserIds']),
      repliesEnabled: data['repliesEnabled'] as bool? ?? true,
      imageUrl: imageUrl,
      imagePath: imagePath,
      mediaType: safeMediaType,
      videoUrl: videoUrl,
      videoPath: videoPath,
      videoIsMuted: data['videoIsMuted'] as bool? ?? false,
      text: data['text'] as String? ?? '',
      textColorValue: _safeStoryTextColorValue(data['textColorValue']),
      textFontFamily: _safeStoryTextFontFamily(data['textFontFamily']),
      textIsBold: data['textIsBold'] as bool? ?? true,
      textIsItalic: data['textIsItalic'] as bool? ?? false,
      textIsUnderline: data['textIsUnderline'] as bool? ?? false,
      textAlign: _safeStoryTextAlign(data['textAlign']),
      textAlignmentX: _doubleFromValue(data['textAlignmentX']) ?? 0.5,
      textAlignmentY: _doubleFromValue(data['textAlignmentY']) ?? 0.58,
      filterType: _safeStoryFilterType(data['filterType']),
      stickerType: safeStickerType,
      stickerLabel: safeStickerLabel,
      stickerPayload: safeStickerPayload,
      stickerAlignmentX: _doubleFromValue(data['stickerAlignmentX']) ?? 0.5,
      stickerAlignmentY: _doubleFromValue(data['stickerAlignmentY']) ?? 0.76,
      stickers: safeStickers,
      viewedAtBy: _dateTimeMapFromValue(data['viewedAtBy']),
      viewerNameBy: _stringMapFromValue(data['viewerNameBy']),
      viewerPhotoUrlBy: _profilePhotoMapFromValue(data['viewerPhotoUrlBy']),
      pollVoteBy: _intMapFromValue(data['pollVoteBy']),
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

  Map<String, String> _profilePhotoMapFromValue(Object? value) {
    if (value is! Map) return const <String, String>{};
    final entries = <String, String>{};
    for (final entry in value.entries) {
      final userId = entry.key.toString().trim();
      final url = trustedProfilePhotoUrl(url: entry.value, userId: userId);
      if (url != null) entries[userId] = url;
    }
    return entries;
  }

  List<String> _stringListFromValue(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    final entries = <String>{
      for (final entry in value)
        if (entry.toString().trim().isNotEmpty) entry.toString().trim(),
    }.toList()..sort();

    return entries;
  }

  Map<String, int> _intMapFromValue(Object? value) {
    if (value is! Map) {
      return const <String, int>{};
    }

    final entries = <String, int>{};

    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      final parsedValue = entry.value is int
          ? entry.value as int
          : int.tryParse('${entry.value}') ?? -1;

      if (key.isNotEmpty && parsedValue >= 0 && parsedValue <= 1) {
        entries[key] = parsedValue;
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

  String _safeStoryTextAlign(Object? value) {
    final textAlign = value?.toString().trim() ?? '';

    return switch (textAlign) {
      'left' || 'right' => textAlign,
      _ => 'center',
    };
  }

  int _safeStoryTextColorValue(Object? value) {
    final parsedValue = value is int ? value : int.tryParse('$value');

    if (parsedValue == null) {
      return 0xFFFFFFFF;
    }

    return _allowedStoryTextColorValues.contains(parsedValue)
        ? parsedValue
        : 0xFFFFFFFF;
  }

  String _safeStoryFilterType(Object? value) {
    final filterType = value?.toString().trim() ?? '';

    return switch (filterType) {
      'warm' || 'cool' || 'mono' || 'soft' => filterType,
      _ => 'normal',
    };
  }

  String _safeStoryMediaType(Object? value) {
    final mediaType = value?.toString().trim() ?? '';

    return mediaType == 'video' ? 'video' : 'image';
  }

  String _safeStoryStickerType(Object? value) {
    final stickerType = value?.toString().trim() ?? '';

    return switch (stickerType) {
      'location' || 'vehicle' || 'status' => stickerType,
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

    if (type == 'vehicle') {
      return _limitedText(payload, 24);
    }

    if (type == 'status') {
      return _limitedText(payload, 32);
    }

    return '';
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

    if (type == 'vehicle') {
      final vehicleLabel = label.isEmpty ? 'Fahrzeug' : label;
      return _limitedText(vehicleLabel, 80);
    }

    if (type == 'status') {
      final statusLabel = label.isEmpty ? safePayload : label;
      return _limitedText(statusLabel, 32);
    }

    return '';
  }

  List<ChatStoryStickerRecord> _safeStoryStickers(
    Iterable<ChatStoryStickerRecord> values,
  ) {
    final stickers = <ChatStoryStickerRecord>[];

    for (final value in values) {
      final sticker = _safeStorySticker(value);
      if (sticker != null) {
        stickers.add(sticker);
      }
      if (stickers.length == 8) {
        break;
      }
    }

    return List<ChatStoryStickerRecord>.unmodifiable(stickers);
  }

  ChatStoryStickerRecord? _safeStorySticker(ChatStoryStickerRecord value) {
    final type = _safeStoryStickerType(value.type);
    final payload = _safeStoryStickerPayload(type, value.payload);
    final effectiveType = payload.isEmpty ? '' : type;
    final label = _safeStoryStickerLabel(effectiveType, value.label, payload);

    if (effectiveType.isEmpty || label.isEmpty) {
      return null;
    }

    return ChatStoryStickerRecord(
      type: effectiveType,
      label: label,
      payload: payload,
      alignmentX: value.alignmentX.clamp(0.08, 0.92).toDouble(),
      alignmentY: value.alignmentY.clamp(0.18, 0.86).toDouble(),
    );
  }

  List<ChatStoryStickerRecord> _storyStickersFromValue(Object? value) {
    if (value is! List) {
      return const <ChatStoryStickerRecord>[];
    }

    final stickers = <ChatStoryStickerRecord>[];
    for (final item in value) {
      if (item is! Map) {
        continue;
      }

      final sticker = _safeStorySticker(
        ChatStoryStickerRecord(
          type: item['type']?.toString() ?? '',
          label: item['label']?.toString() ?? '',
          payload: item['payload']?.toString() ?? '',
          alignmentX: _doubleFromValue(item['alignmentX']) ?? 0.5,
          alignmentY: _doubleFromValue(item['alignmentY']) ?? 0.76,
        ),
      );
      if (sticker != null) {
        stickers.add(sticker);
      }
      if (stickers.length == 8) {
        break;
      }
    }

    return List<ChatStoryStickerRecord>.unmodifiable(stickers);
  }

  String _limitedText(Object? value, int maxLength) {
    final text = value?.toString().trim() ?? '';

    if (text.length <= maxLength) {
      return text;
    }

    return text.substring(0, maxLength).trim();
  }
}
