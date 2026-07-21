import 'dart:io';

import 'package:carisma/shared/plate/dach_plate_presentation.dart';
import 'package:carisma/shared/plate/dach_registration_region_data.g.dart';
import 'package:carisma/shared/widgets/carisma_license_plate_preview.dart';
import 'package:carisma/shared/widgets/carisma_premium_license_plate_card.dart';
import 'package:carisma/shared/widgets/carisma_region_identity_card.dart';
import 'package:carisma/shared/widgets/fe_plate_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(FePlateText.preload);

  group('DACH presentation data', () {
    test('contains every supported registration region', () {
      expect(deRegistrationRegionData, hasLength(674));
      expect(atRegistrationRegionData, hasLength(98));
      expect(chRegistrationRegionData, hasLength(26));

      expect(
        deRegistrationRegionData.values.where((data) => data[5] == 'true'),
        isEmpty,
      );
      expect(
        atRegistrationRegionData.values.where((data) => data[5] == 'true'),
        isEmpty,
      );
      expect(
        chRegistrationRegionData.values.where((data) => data[5] == 'true'),
        isEmpty,
      );
    });

    test('contains every parent state and canton', () {
      expect(
        deRegistrationRegionData.values.map((data) => data[2]).toSet(),
        containsAll(<String>{
          'BW',
          'BY',
          'BE',
          'BB',
          'HB',
          'HH',
          'HE',
          'MV',
          'NI',
          'NW',
          'RP',
          'SL',
          'SN',
          'ST',
          'SH',
          'TH',
        }),
      );
      expect(
        atRegistrationRegionData.values.map((data) => data[2]).toSet(),
        hasLength(9),
      );
      expect(
        chRegistrationRegionData.values.map((data) => data[2]).toSet(),
        hasLength(26),
      );
    });

    test('every referenced local asset exists', () {
      final assetPaths = <String>{
        for (final country in countryPresentationData.values) country.flagAsset,
        for (final data in deRegistrationRegionData.values)
          ...data.sublist(3, 5),
        for (final data in atRegistrationRegionData.values)
          ...data.sublist(3, 5),
        for (final data in chRegistrationRegionData.values)
          ...data.sublist(3, 5),
        'assets/coats/ch/swiss_confederation.png',
      };

      for (final assetPath in assetPaths) {
        expect(
          File(assetPath).existsSync(),
          isTrue,
          reason: 'Asset fehlt: $assetPath',
        );
      }
    });

    test('Hamburg reference state is exact', () {
      final hamburg = registrationRegionPresentationFor(
        countryCode: 'DE',
        plateCode: 'HH',
      );

      expect(hamburg.displayName, 'Hansestadt Hamburg');
      expect(hamburg.parentRegionName, 'Hamburg');
      expect(hamburg.parentRegionCode, 'HH');
      expect(hamburg.usesFallback, isFalse);
    });

    test('unknown input returns a neutral country fallback', () {
      final unknown = registrationRegionPresentationFor(
        countryCode: 'AT',
        plateCode: 'ZZZ',
      );

      expect(unknown.countryCode, 'AT');
      expect(unknown.parentRegionName, 'Österreich');
      expect(unknown.usesFallback, isTrue);
      expect(unknown.regionCoatAsset, 'assets/coats/at/states/at.png');
    });
  });

  final goldenCases = <_GoldenCase>[
    const _GoldenCase('empty_de', 'DE', '', '', ''),
    const _GoldenCase('hamburg', 'DE', 'HH', 'SY', '2026'),
    const _GoldenCase('berlin', 'DE', 'B', 'CR', '1234'),
    const _GoldenCase('muenchen', 'DE', 'M', 'AB', '1234'),
    const _GoldenCase('koeln', 'DE', 'K', 'XY', '987'),
    const _GoldenCase('wien', 'AT', 'W', 'A', '12345'),
    const _GoldenCase('salzburg', 'AT', 'S', 'AB', '123'),
    const _GoldenCase('zuerich', 'CH', 'ZH', '', '123456'),
    const _GoldenCase('genf', 'CH', 'GE', '', '98765'),
  ];

  for (final goldenCase in goldenCases) {
    testWidgets('${goldenCase.name} plate preview', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 220));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final region = registrationRegionPresentationFor(
        countryCode: goldenCase.country,
        plateCode: goldenCase.region,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ColoredBox(
            color: const Color(0xFF05070D),
            child: Center(
              child: SizedBox(
                width: 390,
                child: CaRismaLicensePlatePreview(
                  countryCode: goldenCase.country,
                  region: goldenCase.region,
                  letters: goldenCase.letters,
                  numbers: goldenCase.numbers,
                  regionPresentation: region,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (!region.usesFallback) {
        final previewContext = tester.element(
          find.byType(CaRismaLicensePlatePreview),
        );
        await tester.runAsync(
          () =>
              precacheImage(AssetImage(region.plateSealAsset), previewContext),
        );
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(CaRismaLicensePlatePreview),
        matchesGoldenFile('goldens/dach_plate_${goldenCase.name}.png'),
      );
    });
  }

  testWidgets('region card keeps its existing tap handler', (tester) async {
    var taps = 0;
    final region = registrationRegionPresentationFor(
      countryCode: 'DE',
      plateCode: 'HH',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CaRismaRegionIdentityCard(
              region: region,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Hansestadt Hamburg'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester.getSize(find.byType(CaRismaRegionIdentityCard)).height,
      lessThanOrEqualTo(96),
    );
    await tester.tap(find.byType(CaRismaRegionIdentityCard));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('premium card keeps controllers and callbacks connected', (
    tester,
  ) async {
    final regionController = TextEditingController();
    final lettersController = TextEditingController();
    final numbersController = TextEditingController();
    final regionFocus = FocusNode();
    final lettersFocus = FocusNode();
    final numbersFocus = FocusNode();
    addTearDown(() {
      regionController.dispose();
      lettersController.dispose();
      numbersController.dispose();
      regionFocus.dispose();
      lettersFocus.dispose();
      numbersFocus.dispose();
    });

    var submitTaps = 0;
    var submitEnabled = false;

    Widget buildCard() {
      return MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CaRismaPremiumLicensePlateCard(
                countryCode: 'DE',
                regionPresentation: registrationRegionPresentationFor(
                  countryCode: 'DE',
                  plateCode: regionController.text,
                ),
                regionController: regionController,
                lettersController: lettersController,
                numbersController: numbersController,
                regionFocusNode: regionFocus,
                lettersFocusNode: lettersFocus,
                numbersFocusNode: numbersFocus,
                onRegionChanged: (_) => setState(() {}),
                onLettersChanged: (_) => setState(() {}),
                onNumbersChanged: (_) => setState(() {}),
                isSubmitEnabled: submitEnabled,
                isSubmitting: false,
                onSubmit: () => submitTaps++,
              );
            },
          ),
        ),
      );
    }

    await tester.binding.setSurfaceSize(const Size(430, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildCard());

    await tester.enterText(find.byType(TextField).at(0), 'HH');
    await tester.enterText(find.byType(TextField).at(1), 'SY');
    await tester.enterText(find.byType(TextField).at(2), '4700');
    expect(regionController.text, 'HH');
    expect(lettersController.text, 'SY');
    expect(numbersController.text, '4700');

    await tester.tap(find.text('Anfrage prüfen'));
    expect(submitTaps, 0);

    submitEnabled = true;
    await tester.pumpWidget(buildCard());
    await tester.tap(find.text('Anfrage prüfen'));
    expect(submitTaps, 1);
    expect(tester.takeException(), isNull);
  });

  for (final testCase in <(String, Size, double)>[
    ('small width', const Size(320, 760), 1),
    ('large width', const Size(700, 900), 1),
    ('large text', const Size(390, 820), 1.4),
  ]) {
    testWidgets('premium card has no overflow at ${testCase.$1}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(testCase.$2);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final regionController = TextEditingController(text: 'HH');
      final lettersController = TextEditingController(text: 'SY');
      final numbersController = TextEditingController(text: '4700');
      final regionFocus = FocusNode();
      final lettersFocus = FocusNode();
      final numbersFocus = FocusNode();
      addTearDown(() {
        regionController.dispose();
        lettersController.dispose();
        numbersController.dispose();
        regionFocus.dispose();
        lettersFocus.dispose();
        numbersFocus.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: testCase.$2,
              textScaler: TextScaler.linear(testCase.$3),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: CaRismaPremiumLicensePlateCard(
                  countryCode: 'DE',
                  regionPresentation: registrationRegionPresentationFor(
                    countryCode: 'DE',
                    plateCode: 'HH',
                  ),
                  regionController: regionController,
                  lettersController: lettersController,
                  numbersController: numbersController,
                  regionFocusNode: regionFocus,
                  lettersFocusNode: lettersFocus,
                  numbersFocusNode: numbersFocus,
                  onRegionChanged: (_) {},
                  onLettersChanged: (_) {},
                  onNumbersChanged: (_) {},
                  isSubmitEnabled: true,
                  isSubmitting: false,
                  onSubmit: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      if (exception != null) {
        fail(
          exception is FlutterError
              ? exception.toStringDeep()
              : exception.toString(),
        );
      }
    });
  }
}

class _GoldenCase {
  const _GoldenCase(
    this.name,
    this.country,
    this.region,
    this.letters,
    this.numbers,
  );

  final String name;
  final String country;
  final String region;
  final String letters;
  final String numbers;
}
