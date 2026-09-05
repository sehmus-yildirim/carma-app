import 'dart:io';

import '../domain/verification_models.dart';
import 'document_services.dart';

class VerificationDocumentProcessingException implements Exception {
  const VerificationDocumentProcessingException(this.message);

  final String message;
}

class ProcessedVerificationDocument<T> {
  const ProcessedVerificationDocument({
    required this.data,
    required this.quality,
    required this.fieldConfidence,
  });

  final T data;
  final ImageQualityResult quality;
  final Map<VerificationField, FieldConfidence> fieldConfidence;
}

class VerificationDocumentProcessor {
  const VerificationDocumentProcessor({
    required this.ocrService,
    required this.qualityService,
    required this.temporaryFiles,
  });

  final DocumentOcrService ocrService;
  final ImageQualityService qualityService;
  final VerificationTemporaryFileService temporaryFiles;

  Future<ProcessedVerificationDocument<T>> process<T>({
    required CapturedVerificationDocument capture,
    required VerificationParseResult<T> Function(List<OcrBlock>) parser,
  }) async {
    String? managedPath;
    try {
      managedPath = capture.isManagedTemporaryFile
          ? capture.path
          : await temporaryFiles.adopt(capture.path);
      final quality = await qualityService.inspect(managedPath);
      if (!quality.isAcceptable) {
        throw VerificationDocumentProcessingException(quality.userMessage);
      }
      final blocks = await ocrService.recognize(managedPath);
      var parsed = parser(blocks);
      final recovery = ocrService;
      bool mayRetry(VerificationParseResult<T> result) =>
          result.data == null &&
          result.failure != VerificationParseFailure.ambiguousField &&
          result.failure != VerificationParseFailure.conflictingMrz;
      if (mayRetry(parsed) && recovery is RecoverableDocumentOcrService) {
        for (var attempt = 0; attempt < 4; attempt += 1) {
          final alternative = await recovery.recognizeRecovery(
            managedPath,
            attempt,
          );
          final retried = parser(alternative);
          if (retried.data != null) {
            parsed = retried;
            break;
          }
          if (!mayRetry(retried)) {
            parsed = retried;
            break;
          }
        }
      }
      final data = parsed.data;
      if (data == null) {
        throw VerificationDocumentProcessingException(
          parsed.message ??
              'Wir konnten die Angaben nicht eindeutig erkennen. Bitte fotografiere das Dokument erneut.',
        );
      }
      return ProcessedVerificationDocument<T>(
        data: data,
        quality: quality,
        fieldConfidence: parsed.fieldConfidence,
      );
    } finally {
      if (managedPath != null) await temporaryFiles.delete(managedPath);
      if (!capture.isManagedTemporaryFile &&
          capture.deleteSourceAfterAdoption) {
        await _deleteSource(capture.path);
      }
    }
  }

  static Future<void> _deleteSource(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Startup cleanup performs another best-effort pass for managed files.
    }
  }
}
