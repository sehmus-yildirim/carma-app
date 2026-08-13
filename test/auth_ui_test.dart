import 'package:plaqa/shared/widgets/carisma_auth_brand_header.dart';
import 'package:plaqa/shared/widgets/carisma_social_auth_button.dart';
import 'package:plaqa/features/legal/presentation/privacy_policy_screen.dart';
import 'package:plaqa/features/legal/presentation/terms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the plaqa auth brand and social providers', (
    tester,
  ) async {
    var googlePressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const CaRismaAuthBrandHeader(),
              CaRismaSocialAuthButton(
                provider: CaRismaSocialAuthProvider.google,
                onPressed: () => googlePressed = true,
              ),
              const CaRismaSocialAuthButton(
                provider: CaRismaSocialAuthProvider.apple,
                isEnabled: false,
              ),
              CaRismaAuthNavigationButton(
                label: 'Noch kein Konto? Registrieren',
                icon: Icons.person_add_alt_1_rounded,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('plaqa'), findsNothing);
    expect(find.text('Mit Google fortfahren'), findsOneWidget);
    expect(find.text('Mit Apple fortfahren'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/google_g_logo.png',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/plaqa_logo_transparent.png',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Mit Google fortfahren'));
    expect(googlePressed, isTrue);

    await tester.tap(find.text('Mit Apple fortfahren'));
    expect(googlePressed, isTrue);
  });

  testWidgets('auth legal links use the complete settings documents', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TermsScreen()));

    expect(find.byType(CaRismaAuthBrandHeader), findsOneWidget);
    expect(find.text('1. Anbieter und Geltungsbereich'), findsOneWidget);
    expect(
      find.textContaining(
        'Allgemeine Geschäftsbedingungen und Nutzungsbedingungen',
      ),
      findsWidgets,
    );
    expect(find.textContaining('Aktuelle AGB-Version:'), findsOneWidget);
    expect(find.text('Diese Seite ist ein Entwurf.'), findsNothing);
    expect(find.text('Text kopieren'), findsNothing);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
    await tester.pump();

    expect(find.byType(CaRismaAuthBrandHeader), findsOneWidget);
    expect(
      find.text('1. Geltungsbereich und Zweck dieser Datenschutzerklärung'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Datenschutzerklärung für die mobile App'),
      findsWidgets,
    );
    expect(
      find.textContaining('Aktuelle Datenschutz-Version:'),
      findsOneWidget,
    );
    expect(find.text('Text kopieren'), findsNothing);
  });
}
