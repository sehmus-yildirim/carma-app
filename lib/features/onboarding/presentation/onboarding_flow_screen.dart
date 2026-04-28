import 'package:flutter/material.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_blue_icon_box.dart';
import '../../../shared/widgets/carma_message_card.dart';
import '../../../shared/widgets/carma_primary_button.dart';
import '../../../shared/widgets/carma_secondary_button.dart';
import '../../../shared/widgets/carma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({
    super.key,
    required this.onCompleted,
    this.onBack,
  });

  final VoidCallback onCompleted;
  final VoidCallback? onBack;

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  int _currentStep = 0;

  static const int _lastStep = 3;

  double get _progress {
    return (_currentStep + 1) / (_lastStep + 1);
  }

  bool get _isLastStep {
    return _currentStep == _lastStep;
  }

  void _goNext() {
    if (_isLastStep) {
      widget.onCompleted();
      return;
    }

    setState(() {
      _currentStep++;
    });
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      return;
    }

    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }

    Navigator.of(context).maybePop();
  }

  String get _title {
    return switch (_currentStep) {
      0 => 'Willkommen bei Carma',
      1 => 'Profil vorbereiten',
      2 => 'Fahrzeug hinzufügen',
      3 => 'Verifizierung verstehen',
      _ => 'Onboarding',
    };
  }

  IconData get _icon {
    return switch (_currentStep) {
      0 => Icons.route_rounded,
      1 => Icons.person_rounded,
      2 => Icons.directions_car_filled_rounded,
      3 => Icons.verified_user_rounded,
      _ => Icons.route_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  28 + keyboardInset,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 46,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CarmaSubPageHeader(
                        icon: _icon,
                        title: _title,
                        onBack: _goBack,
                      ),
                      const SizedBox(height: 18),
                      _ProgressCard(
                        currentStep: _currentStep,
                        totalSteps: _lastStep + 1,
                        progress: _progress,
                      ),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          final offsetAnimation = Tween<Offset>(
                            begin: const Offset(0.035, 0),
                            end: Offset.zero,
                          ).animate(animation);

                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: offsetAnimation,
                              child: child,
                            ),
                          );
                        },
                        child: _OnboardingStepContent(
                          key: ValueKey(_currentStep),
                          step: _currentStep,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Spacer(),
                      CarmaPrimaryButton(
                        label: _isLastStep ? 'Carma starten' : 'Weiter',
                        icon: _isLastStep
                            ? Icons.check_circle_outline_rounded
                            : Icons.arrow_forward_rounded,
                        onPressed: _goNext,
                      ),
                      if (_currentStep > 0) ...[
                        const SizedBox(height: 12),
                        CarmaSecondaryButton(
                          label: 'Zurück',
                          icon: Icons.arrow_back_rounded,
                          borderRadius: 24,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          onPressed: _goBack,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.currentStep,
    required this.totalSteps,
    required this.progress,
  });

  final int currentStep;
  final int totalSteps;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Schritt ${currentStep + 1} von $totalSteps',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${((currentStep + 1) / totalSteps * 100).round()}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF63D5FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStepContent extends StatelessWidget {
  const _OnboardingStepContent({
    super.key,
    required this.step,
  });

  final int step;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      0 => const _IntroStep(),
      1 => const _ProfileStep(),
      2 => const _VehicleStep(),
      3 => const _VerificationStep(),
      _ => const _IntroStep(),
    };
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _HeroInfoCard(
          icon: Icons.shield_rounded,
          title: 'Sicher kommunizieren rund ums Fahrzeug.',
          description:
          'Carma hilft dir, Kennzeichen zu suchen, Kontaktanfragen zu verwalten und sachliche Hinweise zu senden — ohne deine privaten Daten unnötig offenzulegen.',
          points: [
            _HeroInfoPoint(
              icon: Icons.search_rounded,
              text: 'Kennzeichen suchen und Kontakt ermöglichen.',
            ),
            _HeroInfoPoint(
              icon: Icons.chat_bubble_outline_rounded,
              text: 'Geschützte Kommunikation statt Zettel am Auto.',
            ),
            _HeroInfoPoint(
              icon: Icons.verified_user_outlined,
              text: 'Mehr Vertrauen durch Profil- und Fahrzeugprüfung.',
            ),
          ],
        ),
        SizedBox(height: 12),
        CarmaMessageCard(
          icon: Icons.info_outline_rounded,
          message:
          'Aktuell ist dieser Flow lokal. Firebase, echte Konten und Speicherung verbinden wir später.',
        ),
      ],
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep();

  @override
  Widget build(BuildContext context) {
    return const _HeroInfoCard(
      icon: Icons.person_rounded,
      title: 'Dein Profil bleibt kontrolliert sichtbar.',
      description:
      'Für die spätere Verifizierung werden echte Basisdaten vorbereitet. Nach außen erscheint nur ein geschützter Anzeigename.',
      points: [
        _HeroInfoPoint(
          icon: Icons.badge_outlined,
          text: 'Vorname und Nachname werden für die Prüfung vorbereitet.',
        ),
        _HeroInfoPoint(
          icon: Icons.visibility_outlined,
          text: 'Deine Sichtbarkeit kannst du später selbst steuern.',
        ),
        _HeroInfoPoint(
          icon: Icons.lock_outline_rounded,
          text: 'Sensible Daten werden nicht öffentlich angezeigt.',
        ),
      ],
    );
  }
}

class _VehicleStep extends StatelessWidget {
  const _VehicleStep();

  @override
  Widget build(BuildContext context) {
    return const _HeroInfoCard(
      icon: Icons.directions_car_filled_rounded,
      title: 'Dein Fahrzeug wird eindeutig zugeordnet.',
      description:
      'Damit Carma vertrauenswürdig bleibt, müssen Kennzeichen und Fahrzeugdaten später nachvollziehbar zum Fahrzeughalter passen.',
      points: [
        _HeroInfoPoint(
          icon: Icons.pin_outlined,
          text: 'Kennzeichen wird je Land passend erfasst.',
        ),
        _HeroInfoPoint(
          icon: Icons.directions_car_outlined,
          text: 'Marke, Modell und Farbe helfen bei klarer Zuordnung.',
        ),
        _HeroInfoPoint(
          icon: Icons.gpp_good_outlined,
          text: 'Das reduziert Missbrauch und falsche Kontaktversuche.',
        ),
      ],
    );
  }
}

class _VerificationStep extends StatelessWidget {
  const _VerificationStep();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _HeroInfoCard(
          icon: Icons.verified_user_rounded,
          title: 'Volle Nutzung nach Verifizierung.',
          description:
          'Dokumente wie Ausweis, Führerschein und Fahrzeugschein werden später sicher hochgeladen und geprüft.',
          points: [
            _HeroInfoPoint(
              icon: Icons.assignment_ind_outlined,
              text: 'Identität und Fahrzeugbezug werden geprüft.',
            ),
            _HeroInfoPoint(
              icon: Icons.lock_outline_rounded,
              text: 'Geprüfte Daten werden danach lokal gesperrt.',
            ),
            _HeroInfoPoint(
              icon: Icons.photo_camera_outlined,
              text: 'Profilbild und Sichtbarkeit bleiben änderbar.',
            ),
          ],
        ),
        SizedBox(height: 12),
        CarmaMessageCard(
          icon: Icons.lock_outline_rounded,
          message:
          'Nach der Verifizierung werden Name, Fahrzeugdaten und Dokumente gesperrt. Sichtbarkeit und Profilbild bleiben weiterhin änderbar.',
        ),
      ],
    );
  }
}

class _HeroInfoCard extends StatelessWidget {
  const _HeroInfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.points,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<_HeroInfoPoint> points;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CarmaBlueIconBox(
            icon: icon,
            size: 58,
            iconSize: 30,
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.45,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
              fontSize: 16.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Column(
            children: List.generate(points.length, (index) {
              final point = points[index];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == points.length - 1 ? 0 : 10,
                ),
                child: _HeroPointRow(point: point),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _HeroInfoPoint {
  const _HeroInfoPoint({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;
}

class _HeroPointRow extends StatelessWidget {
  const _HeroPointRow({
    required this.point,
  });

  final _HeroInfoPoint point;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.055),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            point.icon,
            color: const Color(0xFF63D5FF),
            size: 21,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              point.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.76),
                fontWeight: FontWeight.w700,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}