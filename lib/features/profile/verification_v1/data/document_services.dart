import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as image;

import '../domain/verification_models.dart';

const verificationDocumentMaxSourceBytes = 20 * 1024 * 1024;
const verificationDocumentMaxDimension = 4096;

Directory defaultVerificationTemporaryDirectory() =>
    Directory('${Directory.systemTemp.path}/plaqa_verify_v1');

void validateVerificationSourceImage({
  required int byteLength,
  required int width,
  required int height,
}) {
  if (byteLength <= 0 || width <= 0 || height <= 0) {
    throw const FormatException('Das ausgewählte Bild ist beschädigt.');
  }
  if (byteLength > verificationDocumentMaxSourceBytes ||
      width > verificationDocumentMaxDimension ||
      height > verificationDocumentMaxDimension) {
    throw const FormatException(
      'Das ausgewählte Bild ist zu groß. Bitte wähle ein kleineres Foto.',
    );
  }
}

abstract interface class DocumentCaptureService {
  Future<CapturedVerificationDocument?> capture(VerificationDocumentKind kind);
}

abstract interface class DocumentOcrService {
  Future<List<OcrBlock>> recognize(String imagePath);

  Future<void> close();
}

abstract interface class ImageQualityService {
  Future<ImageQualityResult> inspect(String imagePath);
}

abstract interface class VerificationTemporaryFileService {
  Future<String> adopt(String sourcePath);

  Future<void> delete(String path);

  Future<void> cleanupOrphans();
}

class MlKitDocumentOcrService implements DocumentOcrService {
  MlKitDocumentOcrService({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<List<OcrBlock>> recognize(String imagePath) async {
    final recognized = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return recognized.blocks
        .expand((block) => block.lines)
        .map(
          (line) => OcrBlock(
            text: line.text,
            bounds: OcrRect(
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              right: line.boundingBox.right,
              bottom: line.boundingBox.bottom,
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> close() => _recognizer.close();
}

class LocalVerificationTemporaryFileService
    implements VerificationTemporaryFileService {
  LocalVerificationTemporaryFileService({Directory? root})
    : _root = root ?? defaultVerificationTemporaryDirectory();

  final Directory _root;

  @override
  Future<String> adopt(String sourcePath) async {
    await _root.create(recursive: true);
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Die Kameraaufnahme ist nicht verfügbar.');
    }
    File? staged;
    try {
      var preparedSource = source;
      if (_isManagedPath(source.path) || _isSystemTemporaryPath(source.path)) {
        staged = File(
          '${_root.path}/staged_${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        try {
          preparedSource = await source.rename(staged.path);
        } on FileSystemException {
          preparedSource = await source.copy(staged.path);
          await _deleteFile(source);
        }
      }
      final target = File(
        '${_root.path}/capture_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      final prepared = await Isolate.run(
        () => _prepareOcrImage(preparedSource.readAsBytesSync()),
      );
      await target.writeAsBytes(prepared, flush: true);
      return target.path;
    } finally {
      if (staged != null) await _deleteFile(staged);
      if (_isManagedPath(source.path) || _isSystemTemporaryPath(source.path)) {
        await _deleteFile(source);
      }
    }
  }

  @override
  Future<void> cleanupOrphans() async {
    if (!await _root.exists()) return;
    await for (final entity in _root.list(followLinks: false)) {
      if (entity is File) await _deleteFile(entity);
    }
  }

  @override
  Future<void> delete(String path) async {
    if (!_isManagedPath(path)) return;
    await _deleteFile(File(path));
  }

  bool _isManagedPath(String path) {
    return _isWithinDirectory(path, _root);
  }

  bool _isSystemTemporaryPath(String path) =>
      _isWithinDirectory(path, Directory.systemTemp);

  static bool _isWithinDirectory(String path, Directory directory) {
    final normalizedRoot = _normalizePath(directory.absolute.path);
    final normalizedPath = _normalizePath(File(path).absolute.path);
    return normalizedPath.startsWith(
      '$normalizedRoot${Platform.pathSeparator}',
    );
  }

  static String _normalizePath(String value) =>
      value.replaceAll(RegExp(r'[\\/]'), Platform.pathSeparator).toLowerCase();

  static Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A later startup cleanup retries best-effort removal.
    }
  }
}

Uint8List _prepareOcrImage(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Die Kameraaufnahme ist beschädigt.');
  }
  var prepared = image.bakeOrientation(decoded);
  const maximumLongEdge = 2400;
  if (prepared.width > maximumLongEdge || prepared.height > maximumLongEdge) {
    prepared = prepared.width >= prepared.height
        ? image.copyResize(prepared, width: maximumLongEdge)
        : image.copyResize(prepared, height: maximumLongEdge);
  }
  return Uint8List.fromList(image.encodeJpg(prepared, quality: 92));
}
