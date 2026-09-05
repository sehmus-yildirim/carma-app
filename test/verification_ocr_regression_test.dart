import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_models.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_normalization.dart';
import 'package:plaqa/features/profile/verification_v1/domain/verification_parsers.dart';

// Fictional OCR output only; no real identity document or personal test data.
OcrBlock line(String text, double y, {double x = 20, double width = 250}) =>
    OcrBlock(
      text: text,
      bounds: OcrRect(left: x, top: y, right: x + width, bottom: y + 20),
    );

List<OcrBlock> identity() => [
  line('Name/Surname/Nom', 20),
  line('[a] MUSTERFRAU', 45),
  line('Vornamen/Given names/Prénoms', 85),
  line('ERIKA', 110),
  line('Geburtsdatum', 150),
  line('12.08.1990', 175),
  line('Gültig bis', 215),
  line('31.12.2035', 240),
];

void main() {
  test(
    'passport tolerates omitted terminal fillers but not truncated names',
    () {
      String digit(String value) => List.generate(
        10,
        (n) => '$n',
      ).singleWhere((candidate) => mrzCheckDigitIsValid(value, candidate));
      final dataLine =
          'C01X00T478D<<900812${digit('900812')}F351231${digit('351231')}';
      final parser = PassportDataPageParser(now: DateTime(2026, 9, 5));
      expect(
        parser
            .parse([
              line('P<D<<MUSTERFRAU<<ERIKA<MARIA<<<', 300),
              line(dataLine, 330),
            ])
            .data
            ?.firstNames,
        'ERIKA MARIA',
      );
      expect(
        parser.parse([
          line('P<D<<MUSTERFRAU<<ERIKA<MAR', 300),
          line(dataLine, 330),
        ]).isSuccess,
        isFalse,
      );
      expect(
        parser.parse([
          line('P<D<<MUSTERFRAU<<ERIKA<MARIA<<<', 300),
          line(dataLine.substring(0, 27), 330),
        ]).isSuccess,
        isFalse,
      );
    },
  );
  test('eAT combined name field preserves the surname and given names', () {
    final result = const GermanResidencePermitFrontParser().parse([
      line('NAMEN Vornamen/SURNAMES Forenames', 20, width: 500),
      line('MUSTERFRAU Erika Maria', 45),
      line('GEBURTSDATUM/DATE OF BIRTH', 130),
      line('12 08 1990', 155),
      line('KARTE GULTIG BIS/CARD EXPIRY', 230),
      line('31 12 2035', 255),
    ]);
    expect(result.data?.lastName, 'MUSTERFRAU');
    expect(result.data?.firstNames, 'Erika Maria');
    expect(result.data?.expiresAt, DateTime(2035, 12, 31));
  });

  test('eAT does not guess the split of an all-capitals combined name', () {
    final result = const GermanResidencePermitFrontParser().parse([
      line('NAMEN Vornamen/SURNAMES Forenames', 20, width: 500),
      line('MUSTERFRAU ERIKA MARIA', 45),
      line('GEBURTSDATUM 12 08 1990', 130),
      line('KARTE GULTIG BIS 31 12 2035', 230),
    ]);
    expect(result.isSuccess, isFalse);
    expect(result.message, contains('Rückseite'));
  });

  test('eAT back uses TD1 code lines without guessing a front name split', () {
    String digit(String value) => List.generate(
      10,
      (n) => '$n',
    ).singleWhere((candidate) => mrzCheckDigitIsValid(value, candidate));
    final result = const GermanResidencePermitFrontParser().parse([
      line('ARD<<Y700000001'.padRight(30, '<'), 200),
      line(
        '900812${digit('900812')}F351231${digit('351231')}UTO'.padRight(
          30,
          '<',
        ),
        225,
      ),
      line('MUSTERFRAU<<ERIKA<MARIA'.padRight(30, '<'), 250),
    ]);
    expect(result.data?.lastName, 'MUSTERFRAU');
    expect(result.data?.firstNames, 'ERIKA MARIA');
  });

  test(
    'registration reads exact field A with its value in the same OCR line',
    () {
      final result = const GermanVehicleRegistrationFrontParser().parse([
        line('A HH-XY 1234', 20),
        line('C.1.1 MUSTERFRAU', 60),
        line('C.1.2 ERIKA', 100),
      ]);
      expect(result.data?.plate, 'HH-XY 1234');
      expect(result.data?.holderNameOrCompany, 'MUSTERFRAU');
      expect(result.data?.holderFirstNames, 'ERIKA');
    },
  );

  test('registration tolerates OCR spacing in harmonised field codes', () {
    final result = const GermanVehicleRegistrationFrontParser().parse([
      line('(A) HH XY 1234', 20),
      line('C . 1 . 1 MUSTERFRAU', 60),
      line('C1.2 ERIKA', 100),
    ]);
    expect(result.data?.plate, 'HH XY 1234');
    expect(result.data?.holderNameOrCompany, 'MUSTERFRAU');
    expect(result.data?.holderFirstNames, 'ERIKA');
  });

  test('registration never uses a following field code as the holder name', () {
    final result = const GermanVehicleRegistrationFrontParser().parse([
      line('A', 20, width: 25),
      line('HH-XY 1234', 20, x: 100),
      line('C.1.1', 60, width: 60),
      line('C.1.2', 100, width: 60),
      line('ERIKA', 100, x: 100),
    ]);
    expect(result.isSuccess, isFalse);
  });

  test('missing forename is not replaced by the following date label', () {
    final blocks = identity()..removeWhere((block) => block.text == 'ERIKA');
    expect(const GermanIdCardFrontParser().parse(blocks).isSuccess, isFalse);
  });

  test('stacked names and dates remain readable', () {
    final result = const GermanIdCardFrontParser().parse(identity());
    expect(result.data?.firstNames, 'ERIKA');
    expect(result.data?.lastName, 'MUSTERFRAU');
    expect(result.data?.dateOfBirth, DateTime(1990, 8, 12));
    expect(result.data?.expiresAt, DateTime(2035, 12, 31));
  });

  test('an unrelated distant value is not borrowed for a missing name', () {
    final blocks = identity()..removeWhere((block) => block.text == 'ERIKA');
    blocks.add(line('SOMEONE ELSE', 900));
    expect(const GermanIdCardFrontParser().parse(blocks).isSuccess, isFalse);
  });

  test('passport accepts the actual German ICAO issuing code D<<', () {
    const birth = '900812';
    const expiry = '351231';
    String digit(String value) => List.generate(
      10,
      (n) => '$n',
    ).singleWhere((candidate) => mrzCheckDigitIsValid(value, candidate));
    final first = 'P<D<<MUSTERFRAU<<ERIKA'.padRight(44, '<');
    final second = 'C01X00T478D<<$birth${digit(birth)}F$expiry${digit(expiry)}'
        .padRight(44, '<');
    final result = PassportDataPageParser(
      now: DateTime(2026, 9, 5),
    ).parse([line(first, 300, width: 700), line(second, 330, width: 700)]);
    expect(result.data?.firstNames, 'ERIKA');
    expect(result.data?.issuingCountryCode, 'DE');
  });
}
