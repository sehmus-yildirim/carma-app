import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/verification_v1/data/document_services.dart';
import 'package:plaqa/features/profile/verification_v1/data/verification_document_processor.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_models.dart';

void main() {
  test(
    'conflicting readings are not resolved by dropping evidence in a retry',
    () async {
      final ocr = _Ocr(0);
      final files = _Files();
      await expectLater(
        VerificationDocumentProcessor(
          ocrService: ocr,
          qualityService: _Quality(),
          temporaryFiles: files,
        ).process(
          capture: _capture,
          parser: (_) => const VerificationParseResult<String>.failure(
            VerificationParseFailure.ambiguousField,
            'Mehrdeutig',
          ),
        ),
        throwsA(isA<VerificationDocumentProcessingException>()),
      );
      expect(ocr.attempts, isEmpty);
      expect(files.deleted, [_capture.path]);
    },
  );
  for (final successAt in [-1, 0, 1, 2, 3, 4]) {
    test('bounded OCR recovery and cleanup, success at $successAt', () async {
      final ocr = _Ocr(successAt);
      final files = _Files();
      final processor = VerificationDocumentProcessor(
        ocrService: ocr,
        qualityService: _Quality(),
        temporaryFiles: files,
      );
      final future = processor.process(
        capture: _capture,
        parser: (blocks) => blocks.isEmpty
            ? const VerificationParseResult<String>.failure(
                VerificationParseFailure.missingRequiredField,
                'Unlesbar',
              )
            : const VerificationParseResult<String>.success('synthetic'),
      );
      if (successAt <= 3) {
        expect((await future).data, 'synthetic');
        expect(
          ocr.attempts,
          successAt < 0 ? isEmpty : List.generate(successAt + 1, (i) => i),
        );
      } else {
        await expectLater(
          future,
          throwsA(isA<VerificationDocumentProcessingException>()),
        );
        expect(ocr.attempts, [0, 1, 2, 3]);
      }
      expect(files.deleted, [_capture.path]);
    });
  }

  test('hard image failures stop before native OCR', () async {
    final ocr = _Ocr(0);
    final files = _Files();
    await expectLater(
      VerificationDocumentProcessor(
        ocrService: ocr,
        qualityService: _Quality(blurry: true),
        temporaryFiles: files,
      ).process(
        capture: _capture,
        parser: (_) =>
            const VerificationParseResult<String>.success('must not happen'),
      ),
      throwsA(isA<VerificationDocumentProcessingException>()),
    );
    expect(ocr.reads, 0);
    expect(files.deleted, [_capture.path]);
  });

  test('temporary original is cleaned when native recovery throws', () async {
    final files = _Files();
    await expectLater(
      VerificationDocumentProcessor(
        ocrService: _Ocr(0, throwOnRecovery: true),
        qualityService: _Quality(),
        temporaryFiles: files,
      ).process(
        capture: _capture,
        parser: (_) => const VerificationParseResult<String>.failure(
          VerificationParseFailure.missingRequiredField,
          'Unlesbar',
        ),
      ),
      throwsStateError,
    );
    expect(files.deleted, [_capture.path]);
  });
}

const _capture = CapturedVerificationDocument(
  path: 'SYNTHETIC_TEST_NOT_VALID.jpg',
  kind: VerificationDocumentKind.identityCard,
  isManagedTemporaryFile: true,
);

class _Ocr implements RecoverableDocumentOcrService {
  _Ocr(this.successAt, {this.throwOnRecovery = false});
  final int successAt;
  final bool throwOnRecovery;
  final attempts = <int>[];
  int reads = 0;
  List<OcrBlock> blocks(int attempt) => attempt == successAt
      ? const [
          OcrBlock(
            text: 'SYNTHETIC',
            bounds: OcrRect(left: 0, top: 0, right: 10, bottom: 10),
          ),
        ]
      : [];
  @override
  Future<List<OcrBlock>> recognize(String imagePath) async {
    reads++;
    return blocks(-1);
  }

  @override
  Future<List<OcrBlock>> recognizeRecovery(
    String imagePath,
    int attempt,
  ) async {
    attempts.add(attempt);
    if (throwOnRecovery) throw StateError('Synthetic native failure');
    return blocks(attempt);
  }

  @override
  Future<void> close() async {}
}

class _Quality implements ImageQualityService {
  _Quality({this.blurry = false});
  final bool blurry;
  @override
  Future<ImageQualityResult> inspect(String imagePath) async =>
      ImageQualityResult(
        width: 1600,
        height: 1000,
        averageLuminance: 180,
        contrast: 50,
        sharpness: 10,
        failures: blurry ? [ImageQualityFailure.blurry] : [],
        framingHints: const [ImageQualityFailure.documentCropped],
      );
}

class _Files implements VerificationTemporaryFileService {
  final deleted = <String>[];
  @override
  Future<String> adopt(String sourcePath) async => sourcePath;
  @override
  Future<void> delete(String path) async {
    deleted.add(path);
  }

  @override
  Future<void> cleanupOrphans() async {}
}
