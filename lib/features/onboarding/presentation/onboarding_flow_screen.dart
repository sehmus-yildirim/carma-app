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
      0 => 'So funktioniert Carma',
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
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              28 + keyboardInset,
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
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _OnboardingStepContent(
                    key: ValueKey(_currentStep),
                    step: _currentStep,
                  ),
                ),
                const SizedBox(height: 18),
                CarmaPrimaryButton(
                  label: _isLastStep ? 'Carma starten' : 'Weiter',
                  icon: _isLastStep
                      ? Icons.check_circle_outline_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: _goNext,
                ),
                const SizedBox(height: 12),
                if (_currentStep > 0)
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
            ),
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
          Text(
            'Schritt ${currentStep + 1} von $totalSteps',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
            ),
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
    return Column(
      children: const [
        _HeroInfoCard(
          icon: Icons.shield_rounded,
          title: 'Carma ist geschützt aufgebaut.',
          description:
          'Du kannst Kennzeichen suchen, Hinweise senden und Kontaktanfragen verwalten. Damit das sicher bleibt, arbeitet Carma mit Profil- und Fahrzeugverifizierung.',
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
      title: 'Dein Profil braucht echte Basisdaten.',
      description:
      'Vorname und Nachname werden für die Verifizierung vorbereitet. In der App wird später nur ein geschützter Anzeigename wie „Max M.“ sichtbar.',
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
      'Kennzeichen, Marke, Modell und Farbe müssen später mit dem Fahrzeugschein übereinstimmen. Dadurch wird Missbrauch deutlich reduziert.',
    );
  }
}

class _VerificationStep extends StatelessWidget {
  const _VerificationStep();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _HeroInfoCard(
          icon: Icons.verified_user_rounded,
          title: 'Volle Nutzung erst nach Verifizierung.',
          description:
          'Dokumente wie Ausweis, Führerschein und Fahrzeugschein werden später sicher hochgeladen und geprüft. Bis dahin bleibt dieser Ablauf lokal vorbereitet.',
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
  });

  final IconData icon;
  final String title;
  final String description;

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
        ],
      ),
    );
  }
}