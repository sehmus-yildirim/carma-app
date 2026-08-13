import 'package:plaqa/shared/plate/plate_speech_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSpokenPlateInput', () {
    PlateSpeechParseResult parse(String transcript) {
      return parseSpokenPlateInput(
        countryCode: 'DE',
        transcript: transcript,
        currentRegion: '',
        currentLetters: '',
        currentNumbers: '',
      );
    }

    test('keeps explicit two letter region and letter group', () {
      final result = parse('HH SY 4700');

      expect(result.region, 'HH');
      expect(result.letters, 'SY');
      expect(result.numbers, '4700');
    });

    test('groups individually spoken repeated city code letters', () {
      final result = parse('H H S Y 4700');

      expect(result.region, 'HH');
      expect(result.letters, 'SY');
      expect(result.numbers, '4700');
    });

    test('keeps one letter city with two plate letters', () {
      final result = parse('M AB 1234');

      expect(result.region, 'M');
      expect(result.letters, 'AB');
      expect(result.numbers, '1234');
    });

    test('keeps two letter city with one plate letter', () {
      final result = parse('MA B 1234');

      expect(result.region, 'MA');
      expect(result.letters, 'B');
      expect(result.numbers, '1234');
    });

    test('keeps explicit three letter city with one plate letter', () {
      final result = parse('KLE A 123');

      expect(result.region, 'KLE');
      expect(result.letters, 'A');
      expect(result.numbers, '123');
    });

    test('groups individually spoken three letter city with two letters', () {
      final result = parse('K L E X Y 123');

      expect(result.region, 'KLE');
      expect(result.letters, 'XY');
      expect(result.numbers, '123');
    });

    test('uses a known two letter region for an ungrouped letter run', () {
      final result = parse('H H S Y 4700');

      expect(result.region, 'HH');
      expect(result.letters, 'SY');
      expect(result.numbers, '4700');
    });

    test('uses a known three letter region for an ungrouped letter run', () {
      final result = parse('K L E A B 123');

      expect(result.region, 'KLE');
      expect(result.letters, 'AB');
      expect(result.numbers, '123');
    });

    test('keeps an explicit one letter region boundary', () {
      final result = parse('M AB 1234');

      expect(result.region, 'M');
      expect(result.letters, 'AB');
      expect(result.numbers, '1234');
    });

    test('resolves spoken umlaut region code to its plate spelling', () {
      final result = parse('A Ö B 123');

      expect(result.region, 'AÖ');
      expect(result.letters, 'B');
      expect(result.numbers, '123');
    });
  });
}
