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

class ChatNativeBridge {
  static const MethodChannel _channel = MethodChannel('carma/chat_tools');

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
      contentType: contentType.isEmpty
          ? 'application/octet-stream'
          : contentType,
    );
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
