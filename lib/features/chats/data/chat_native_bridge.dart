import 'package:flutter/services.dart';

class PickedPhoneContact {
  const PickedPhoneContact({required this.name, required this.phoneNumber});

  final String name;
  final String phoneNumber;
}

class PickedDocumentFile {
  const PickedDocumentFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.contentType,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final String contentType;
}

class PickedVoiceMemoFile {
  const PickedVoiceMemoFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.contentType,
    required this.durationMs,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final String contentType;
  final int durationMs;
}

class ResolvedLocationPlace {
  const ResolvedLocationPlace({
    required this.label,
    required this.city,
    required this.region,
    required this.country,
  });

  final String label;
  final String city;
  final String region;
  final String country;
}

class ChatNativeBridge {
  static const MethodChannel _channel = MethodChannel('carisma/chat_tools');
  static const Map<String, String> _documentContentTypesByExtension = {
    'txt': 'text/plain',
    'md': 'text/markdown',
    'csv': 'text/csv',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'rtf': 'application/rtf',
  };

  Future<PickedPhoneContact?> pickPhoneContact() async {
    final result = await _channel.invokeMapMethod<String, String>(
      'pickPhoneContact',
    );

    if (result == null) {
      return null;
    }

    final name = result['name']?.trim() ?? '';
    final phoneNumber = result['phoneNumber']?.trim() ?? '';

    if (name.isEmpty && phoneNumber.isEmpty) {
      return null;
    }

    return PickedPhoneContact(
      name: name.isEmpty ? 'Kontakt' : name,
      phoneNumber: phoneNumber,
    );
  }

  Future<void> openMap({
    required double latitude,
    required double longitude,
  }) async {
    await _channel.invokeMethod<void>('openMap', <String, Object>{
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<List<ResolvedLocationPlace>> reverseGeocodeLocation({
    required double latitude,
    required double longitude,
  }) async {
    final result = await _channel.invokeMethod<Object?>(
      'reverseGeocodeLocation',
      <String, Object>{'latitude': latitude, 'longitude': longitude},
    );

    if (result is! Map) {
      return const <ResolvedLocationPlace>[];
    }

    final rawPlaces = result['places'];
    if (rawPlaces is! List) {
      return const <ResolvedLocationPlace>[];
    }

    return rawPlaces
        .whereType<Map>()
        .map((place) {
          final label = place['label']?.toString().trim() ?? '';
          final city = place['city']?.toString().trim() ?? '';
          final region = place['region']?.toString().trim() ?? '';
          final country = place['country']?.toString().trim() ?? '';

          if (label.isEmpty) {
            return null;
          }

          return ResolvedLocationPlace(
            label: label,
            city: city,
            region: region,
            country: country,
          );
        })
        .whereType<ResolvedLocationPlace>()
        .toList(growable: false);
  }

  Future<PickedDocumentFile?> pickDocumentFile() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'pickDocumentFile',
    );

    if (result == null) {
      return null;
    }

    final path = result['path']?.toString().trim() ?? '';
    final name = result['name']?.toString().trim() ?? '';
    final contentType =
        result['contentType']?.toString().trim() ?? 'application/octet-stream';
    final sizeValue = result['sizeBytes'];
    final sizeBytes = sizeValue is int
        ? sizeValue
        : int.tryParse(sizeValue?.toString() ?? '') ?? 0;

    if (path.isEmpty || name.isEmpty || sizeBytes <= 0) {
      return null;
    }

    return PickedDocumentFile(
      path: path,
      name: name,
      sizeBytes: sizeBytes,
      contentType: _documentContentTypeFor(
        fileName: name,
        contentType: contentType,
      ),
    );
  }

  String _documentContentTypeFor({
    required String fileName,
    required String contentType,
  }) {
    final normalizedContentType = contentType.trim().toLowerCase();

    if (normalizedContentType.isNotEmpty &&
        normalizedContentType != 'application/octet-stream') {
      return normalizedContentType;
    }

    final trimmedFileName = fileName.trim();
    final fileNameParts = trimmedFileName.split('.');

    if (fileNameParts.length < 2) {
      return 'application/octet-stream';
    }

    final extension = fileNameParts.last.toLowerCase();

    return _documentContentTypesByExtension[extension] ??
        'application/octet-stream';
  }

  Future<void> openDocumentUrl({
    required String url,
    required String contentType,
  }) async {
    await _channel.invokeMethod<void>('openDocumentUrl', <String, Object>{
      'url': url,
      'contentType': contentType,
    });
  }

  Future<void> shareText({required String text}) async {
    await _channel.invokeMethod<void>('shareText', <String, Object>{
      'text': text,
    });
  }

  Future<void> saveImageToGallery({
    required String url,
    required String fileName,
    required String contentType,
  }) async {
    await _channel.invokeMethod<void>('saveImageToGallery', <String, Object>{
      'url': url,
      'fileName': fileName,
      'contentType': contentType,
    });
  }

  Future<void> saveVideoToGallery({
    required String url,
    required String fileName,
    required String contentType,
  }) async {
    await _channel.invokeMethod<void>('saveVideoToGallery', <String, Object>{
      'url': url,
      'fileName': fileName,
      'contentType': contentType,
    });
  }

  Future<void> saveDocumentToDownloads({
    required String url,
    required String fileName,
    required String contentType,
  }) async {
    await _channel.invokeMethod<void>(
      'saveDocumentToDownloads',
      <String, Object>{
        'url': url,
        'fileName': fileName,
        'contentType': contentType,
      },
    );
  }

  Future<void> startVoiceMemo() async {
    await _channel.invokeMethod<void>('startVoiceMemo');
  }

  Future<PickedVoiceMemoFile> stopVoiceMemo() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'stopVoiceMemo',
    );

    final path = result?['path']?.toString().trim() ?? '';
    final name = result?['name']?.toString().trim() ?? '';
    final contentType =
        result?['contentType']?.toString().trim() ?? 'audio/mp4';
    final sizeValue = result?['sizeBytes'];
    final durationValue = result?['durationMs'];
    final sizeBytes = sizeValue is int
        ? sizeValue
        : int.tryParse(sizeValue?.toString() ?? '') ?? 0;
    final durationMs = durationValue is int
        ? durationValue
        : int.tryParse(durationValue?.toString() ?? '') ?? 0;

    if (path.isEmpty || sizeBytes <= 0) {
      throw StateError('Sprachmemo konnte nicht gelesen werden.');
    }

    return PickedVoiceMemoFile(
      path: path,
      name: name.isEmpty ? 'Sprachmemo.m4a' : name,
      sizeBytes: sizeBytes,
      contentType: contentType.isEmpty ? 'audio/mp4' : contentType,
      durationMs: durationMs,
    );
  }

  Future<void> cancelVoiceMemo() async {
    await _channel.invokeMethod<void>('cancelVoiceMemo');
  }

  Future<void> playVoiceMemo({required String url}) async {
    await _channel.invokeMethod<void>('playVoiceMemo', <String, Object>{
      'url': url,
    });
  }

  Future<void> stopVoiceMemoPlayback() async {
    await _channel.invokeMethod<void>('stopVoiceMemoPlayback');
  }
}
