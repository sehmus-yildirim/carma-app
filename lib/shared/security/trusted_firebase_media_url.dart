import 'package:flutter/foundation.dart';

const Set<String> _plaqaStorageBuckets = <String>{
  'carma-a84e4.firebasestorage.app',
  'carma-a84e4.appspot.com',
};

bool isTrustedPlaqaFirebaseDownloadUrl(
  Object? url, {
  bool allowEmulator = kDebugMode,
}) {
  final normalizedUrl = url is String ? url.trim() : '';
  if (normalizedUrl.isEmpty || normalizedUrl.length > 2000) return false;
  final uri = Uri.tryParse(normalizedUrl);
  if (uri == null ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      uri.pathSegments.length < 5 ||
      uri.pathSegments[0] != 'v0' ||
      uri.pathSegments[1] != 'b' ||
      uri.pathSegments[3] != 'o') {
    return false;
  }
  final isProduction =
      uri.scheme == 'https' && uri.host == 'firebasestorage.googleapis.com';
  final isEmulator =
      allowEmulator &&
      uri.scheme == 'http' &&
      const <String>{'127.0.0.1', 'localhost', '10.0.2.2'}.contains(uri.host);
  if ((!isProduction && !isEmulator) ||
      !_plaqaStorageBuckets.contains(uri.pathSegments[2])) {
    return false;
  }
  final query = uri.queryParametersAll;
  final unknownQueryKeys = query.keys.where(
    (key) => key != 'alt' && key != 'token',
  );
  final altValues = query['alt'] ?? const <String>[];
  final tokenValues = query['token'] ?? const <String>[];
  return unknownQueryKeys.isEmpty &&
      altValues.length == 1 &&
      altValues.single == 'media' &&
      tokenValues.length <= 1 &&
      (tokenValues.isEmpty ||
          RegExp(r'^[A-Za-z0-9_%.,-]{1,512}$').hasMatch(tokenValues.single));
}

String? trustedFirebaseMediaUrl({
  required Object? url,
  required Object? storagePath,
  bool allowEmulator = kDebugMode,
}) {
  final normalizedUrl = url is String ? url.trim() : '';
  final normalizedPath = storagePath is String ? storagePath.trim() : '';
  if (!isTrustedPlaqaFirebaseDownloadUrl(
        normalizedUrl,
        allowEmulator: allowEmulator,
      ) ||
      normalizedPath.isEmpty ||
      normalizedPath.length > 1024 ||
      normalizedPath.startsWith('/') ||
      normalizedPath.contains('..') ||
      normalizedPath.contains('\\')) {
    return null;
  }

  final uri = Uri.tryParse(normalizedUrl);
  if (uri == null) return null;
  final objectPath = uri.pathSegments.sublist(4).join('/');
  if (objectPath != normalizedPath) return null;
  return normalizedUrl;
}

bool isTrustedFirebaseMediaUrl({
  required Object? url,
  required Object? storagePath,
  bool allowEmulator = kDebugMode,
}) {
  return trustedFirebaseMediaUrl(
        url: url,
        storagePath: storagePath,
        allowEmulator: allowEmulator,
      ) !=
      null;
}

String? trustedProfilePhotoUrl({
  required Object? url,
  required Object? userId,
  bool allowEmulator = kDebugMode,
}) {
  final normalizedUserId = userId is String ? userId.trim() : '';
  if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalizedUserId)) {
    return null;
  }
  return trustedFirebaseMediaUrl(
    url: url,
    storagePath: 'profile_photos/$normalizedUserId/profile.png',
    allowEmulator: allowEmulator,
  );
}
