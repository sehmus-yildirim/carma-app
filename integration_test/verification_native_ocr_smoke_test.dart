import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:integration_test/integration_test.dart';
import 'package:plaqa/features/profile/verification_v1/data/document_services.dart';
import 'package:plaqa/features/profile/verification_v1/data/local_image_quality_service.dart';
import 'package:plaqa/features/profile/verification_v1/data/verification_document_processor.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_models.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_normalization.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_parsers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native OCR, quality, parsing and cleanup on synthetic documents',
    (tester) async {
      final root = await Directory.systemTemp.createTemp(
        'plaqa_native_ocr_test_',
      );
      final recognizer = MlKitDocumentOcrService();
      final receipt = File(
        '${Directory.systemTemp.path}/plaqa_native_ocr_receipt.json',
      );
      final passed = <String>[];
      final startedAt = DateTime.now().toUtc().toIso8601String();
      Future<void> record(String status) async {
        await receipt.writeAsString(
          jsonEncode({
            'startedAt': startedAt,
            'status': status,
            'passed': passed,
            'fixtures': 'synthetic-test-not-valid',
          }),
          flush: true,
        );
      }

      await record('running');
      final temporary = LocalVerificationTemporaryFileService(
        root: Directory('${root.path}/managed'),
      );
      final processor = VerificationDocumentProcessor(
        ocrService: recognizer,
        qualityService: const LocalImageQualityService(),
        temporaryFiles: temporary,
      );
      try {
        for (final angle in const [0, 90, 180, 270]) {
          final path = await _fixture(root, 'id_$angle', const [
            ('Name/Surname/Nom', '[a] MUSTERFRAU'),
            ('Vornamen/Given names', 'ERIKA MARIA'),
            ('Geburtsdatum', '12.08.1990'),
            ('Gultig bis', '31.12.2035'),
          ], rotation: angle);
          final result = await processor.process(
            capture: CapturedVerificationDocument(
              path: path,
              kind: VerificationDocumentKind.identityCard,
            ),
            parser: const GermanIdCardFrontParser().parse,
          );
          expect(result.data.lastName, 'MUSTERFRAU');
          expect(result.data.firstNames, 'ERIKA MARIA');
          expect(result.data.dateOfBirth, DateTime(1990, 8, 12));
          expect(
            await Directory('${root.path}/managed').list().isEmpty,
            isTrue,
          );
          // Only synthetic fixture status, never document text, goes into logs.
          // ignore: avoid_print
          print('PLAQA_NATIVE_OCR_PASS identity_rotation_$angle');
          passed.add('identity_rotation_$angle');
          await record('running');
        }

        final registration = await _fixture(root, 'registration', const [
          ('', 'A HH-XY 1234'),
          ('', 'C.1.1 MUSTERFRAU'),
          ('', 'C.1.2 ERIKA MARIA'),
        ]);
        final vehicle = await processor.process(
          capture: CapturedVerificationDocument(
            path: registration,
            kind: VerificationDocumentKind.vehicleRegistration,
          ),
          parser: const GermanVehicleRegistrationFrontParser().parse,
        );
        expect(vehicle.data.plate.replaceAll(' ', ''), 'HH-XY1234');
        expect(vehicle.data.holderNameOrCompany, 'MUSTERFRAU');
        // ignore: avoid_print
        print('PLAQA_NATIVE_OCR_PASS registration');
        passed.add('registration');
        await record('running');

        final permit = await _fixture(root, 'residence', const [
          ('NAMEN Vornamen/SURNAMES Forenames', 'MUSTERFRAU Erika Maria'),
          ('GEBURTSDATUM/DATE OF BIRTH', '12 08 1990'),
          ('KARTE GULTIG BIS/CARD EXPIRY', '31 12 2035'),
        ]);
        final residence = await processor.process(
          capture: CapturedVerificationDocument(
            path: permit,
            kind: VerificationDocumentKind.residencePermit,
          ),
          parser: const GermanResidencePermitFrontParser().parse,
        );
        expect(residence.data.lastName, 'MUSTERFRAU');
        expect(residence.data.firstNames, 'Erika Maria');
        // ignore: avoid_print
        print('PLAQA_NATIVE_OCR_PASS residence');
        passed.add('residence');
        await record('running');

        String digit(String value) => List.generate(
          10,
          (n) => '$n',
        ).singleWhere((candidate) => mrzCheckDigitIsValid(value, candidate));
        final passport = await _mrzFixture(root, [
          'P<D<<MUSTERFRAU<<ERIKA<MARIA'.padRight(44, '<'),
          'C01X00T478D<<900812${digit('900812')}F351231${digit('351231')}'
              .padRight(44, '<'),
        ]);
        final passportBlocks = await recognizer.recognize(passport);
        // Test-only diagnostics contain geometry/counts, never OCR text.
        // ignore: avoid_print
        print(
          'PLAQA_SYNTHETIC_MRZ_SHAPES ${passportBlocks.map((block) => (characters: block.text.replaceAll(' ', '').length, fillers: '<'.allMatches(block.text).length, top: block.bounds.top.round(), left: block.bounds.left.round(), width: block.bounds.width.round())).toList()}',
        );
        final pass = await processor.process(
          capture: CapturedVerificationDocument(
            path: passport,
            kind: VerificationDocumentKind.passport,
          ),
          parser: PassportDataPageParser(now: DateTime(2026, 9, 5)).parse,
        );
        expect(pass.data.lastName, 'MUSTERFRAU');
        expect(pass.data.firstNames, 'ERIKA MARIA');
        // ignore: avoid_print
        print('PLAQA_NATIVE_OCR_PASS passport');
        passed.add('passport');
        expect(await Directory('${root.path}/managed').list().isEmpty, isTrue);
        await record('passed');
      } catch (_) {
        await record('failed');
        rethrow;
      } finally {
        await recognizer.close();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<String> _mrzFixture(Directory root, List<String> lines) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawPaint(ui.Paint()..color = const ui.Color(0xffeeeeea));
  canvas.drawRect(
    const ui.Rect.fromLTWH(80, 160, 330, 360),
    ui.Paint()..color = const ui.Color(0xff999999),
  );
  void text(String value, double y, double size) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(fontFamily: 'monospace', fontSize: size),
          )
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xff111111)))
          ..addText(value);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 1440));
    expect(
      paragraph.height,
      lessThan(size * 2),
      reason: 'MRZ fixture must stay on one line',
    );
    canvas.drawParagraph(paragraph, ui.Offset(80, y));
    paragraph.dispose();
  }

  text('PLAQA TEST - SAMPLE - NOT VALID', 40, 28);
  for (final line in lines.indexed) {
    text(line.$2, 650 + line.$1 * 70, 48);
  }
  final picture = recorder.endRecording();
  final raster = await picture.toImage(1600, 1000);
  picture.dispose();
  final bytes = await raster.toByteData(format: ui.ImageByteFormat.png);
  raster.dispose();
  final file = File('${root.path}/passport_TEST_NOT_VALID.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  return file.path;
}

Future<String> _fixture(
  Directory root,
  String name,
  List<(String, String)> fields, {
  int rotation = 0,
}) async {
  final bitmap = image.Image(width: 1600, height: 1000);
  image.fill(bitmap, color: image.ColorRgb8(238, 238, 228));
  image.drawString(
    bitmap,
    'PLAQA TEST - SAMPLE - NOT VALID',
    font: image.arial24,
    x: 70,
    y: 35,
    color: image.ColorRgb8(90, 20, 20),
  );
  for (final entry in fields.indexed) {
    final textWidth = entry.$2.$2
        .split('')
        .fold<int>(
          0,
          (width, character) =>
              width + image.arial48.characterXAdvance(character),
        );
    expect(
      textWidth,
      lessThanOrEqualTo(1440),
      reason: 'Synthetic fixture must not crop its text',
    );
    final y = 140 + entry.$1 * 195;
    image.drawString(
      bitmap,
      entry.$2.$1,
      font: image.arial24,
      x: 80,
      y: y,
      color: image.ColorRgb8(35, 35, 35),
    );
    image.drawString(
      bitmap,
      entry.$2.$2,
      font: image.arial48,
      x: 80,
      y: y + 42,
      color: image.ColorRgb8(15, 15, 15),
    );
  }
  final file = File('${root.path}/${name}_TEST_NOT_VALID.png');
  await file.writeAsBytes(
    image.encodePng(
      rotation == 0 ? bitmap : image.copyRotate(bitmap, angle: rotation),
    ),
    flush: true,
  );
  return file.path;
}
