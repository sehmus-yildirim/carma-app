import 'package:flutter/material.dart';

import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/theme/carisma_design_tokens.dart';

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({
    super.key,
    required this.onCompleted,
    this.onBack,
  });

  final Future<void> Function() onCompleted;
  final VoidCallback? onBack;

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  int _currentStep = 0;
  bool _isCompleting = false;
  String? _completionError;

  static const int _lastStep = 3;

  double get _progress {
    return (_currentStep + 1) / (_lastStep + 1);
  }

  bool get _isLastStep {
    return _currentStep == _lastStep;
  }

  Future<void> _goNext() async {
    if (_isLastStep) {
      if (_isCompleting) return;
      setState(() {
        _isCompleting = true;
        _completionError = null;
      });
      try {
        await widget.onCompleted();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _completionError =
              'Der Abschluss konnte gerade nicht gespeichert werden. Bitte versuche es erneut.';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isCompleting = false;
          });
        }
      }
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
      0 => 'Willkommen bei plaqa',
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
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 760;
              final horizontalPadding = constraints.maxWidth < 380
                  ? 14.0
                  : 20.0;
              final sectionGap = compact ? 6.0 : 14.0;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  compact ? 6 : 16,
                  horizontalPadding,
                  compact ? 7 : 20,
                ),
                child: Column(
                  children: [
                    CaRismaSubPageHeader(
                      icon: _icon,
                      title: _title,
                      titleFontSize: compact ? 19 : 21,
                      titleMaxLines: 2,
                      titleOverflow: TextOverflow.visible,
                      onBack: _goBack,
                    ),
                    SizedBox(height: sectionGap),
                    _ProgressCard(
                      currentStep: _currentStep,
                      totalSteps: _lastStep + 1,
                      progress: _progress,
                      compact: compact,
                    ),
                    SizedBox(height: sectionGap),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              fit: StackFit.expand,
                              alignment: Alignment.center,
                              children: <Widget>[
                                ...previousChildren,
                                ?currentChild,
                              ],
                            ),
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
                          compact: compact,
                        ),
                      ),
                    ),
                    if (_completionError != null) ...[
                      SizedBox(height: sectionGap),
                      CaRismaMessageCard(
                        icon: Icons.sync_problem_rounded,
                        message: _completionError!,
                      ),
                    ],
                    SizedBox(height: sectionGap),
                    CaRismaPrimaryButton(
                      label: _isLastStep ? 'Speichern und starten' : 'Weiter',
                      icon: _isLastStep
                          ? Icons.check_circle_outline_rounded
                          : Icons.arrow_forward_rounded,
                      isLoading: _isCompleting,
                      loadingLabel: 'Wird gespeichert',
                      surfaceOutlined: true,
                      borderRadius: 22,
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: compact ? 12 : 17,
                      ),
                      iconSize: compact ? 23 : 25,
                      fontSize: compact ? 17 : 18,
                      onPressed: _goNext,
                    ),
                  ],
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
    required this.compact,
  });

  final int currentStep;
  final int totalSteps;
  final double progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 7 : 13,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Schritt ${currentStep + 1} von $totalSteps',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CaRismaDesignTokens.textPrimary.withValues(
                      alpha: 0.72,
                    ),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${((currentStep + 1) / totalSteps * 100).round()}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CaRismaDesignTokens.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 5 : 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: compact ? 6 : 8,
              backgroundColor: CaRismaDesignTokens.textPrimary.withValues(
                alpha: 0.10,
              ),
              valueColor: const AlwaysStoppedAnimation<Color>(
                CaRismaDesignTokens.blueBright,
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
    required this.compact,
  });

  final int step;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      0 => _IntroStep(compact: compact),
      1 => _ProfileStep(compact: compact),
      2 => _VehicleStep(compact: compact),
      3 => _VerificationStep(compact: compact),
      _ => _IntroStep(compact: compact),
    };
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _HeroInfoCard(
      compact: compact,
      icon: Icons.shield_rounded,
      title: 'Sicher kommunizieren rund ums Fahrzeug.',
      description:
          'Finde Kennzeichen, verwalte Kontaktanfragen und sende wichtige Hinweise, ohne private Daten unnötig offenzulegen.',
      noteIcon: Icons.info_outline_rounded,
      note: 'plaqa bereitet diese Funktionen jetzt für dein Konto vor.',
      points: const [
        _HeroInfoPoint(
          icon: Icons.search_rounded,
          text: 'Kennzeichen suchen und Kontakt ermöglichen.',
        ),
        _HeroInfoPoint(
          icon: Icons.chat_bubble_outline_rounded,
          text: 'Geschützt kommunizieren statt Zettel am Auto.',
        ),
        _HeroInfoPoint(
          icon: Icons.verified_user_outlined,
          text: 'Mehr Vertrauen durch geprüfte Profile und Fahrzeuge.',
        ),
      ],
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _HeroInfoCard(
      compact: compact,
      icon: Icons.person_rounded,
      title: 'Dein Profil bleibt kontrolliert sichtbar.',
      description:
          'Für die spätere Verifizierung werden echte Basisdaten vorbereitet. Nach außen erscheint nur ein geschützter Anzeigename.',
      points: const [
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
  const _VehicleStep({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _HeroInfoCard(
      compact: compact,
      icon: Icons.directions_car_filled_rounded,
      title: 'Dein Fahrzeug wird eindeutig zugeordnet.',
      description:
          'Damit plaqa vertrauenswürdig bleibt, müssen Kennzeichen und Fahrzeugdaten später nachvollziehbar zum Fahrzeughalter passen.',
      points: const [
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
  const _VerificationStep({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _HeroInfoCard(
      compact: compact,
      icon: Icons.verified_user_rounded,
      title: 'Mehr Vertrauen durch Verifizierung.',
      description:
          'Ausweis und Fahrzeugschein werden nur auf deinem Gerät gelesen. Dokumentfotos werden nicht dauerhaft gespeichert.',
      noteIcon: Icons.lock_outline_rounded,
      note:
          'Name und Fahrzeugbezug werden bestätigt; Profilbild und Sichtbarkeit bleiben änderbar.',
      points: const [
        _HeroInfoPoint(
          icon: Icons.assignment_ind_outlined,
          text: 'Identität und Fahrzeugbezug werden abgeglichen.',
        ),
        _HeroInfoPoint(
          icon: Icons.phonelink_lock_rounded,
          text: 'Die Dokumenterkennung erfolgt direkt auf dem Gerät.',
        ),
        _HeroInfoPoint(
          icon: Icons.delete_outline_rounded,
          text: 'Temporäre Aufnahmen werden anschließend gelöscht.',
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
    required this.compact,
    this.note,
    this.noteIcon,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<_HeroInfoPoint> points;
  final bool compact;
  final String? note;
  final IconData? noteIcon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.all(compact ? 11 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CaRismaBlueIconBox(
                icon: icon,
                size: compact ? 36 : 48,
                iconSize: compact ? 19 : 25,
              ),
              SizedBox(width: compact ? 9 : 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 17 : 21,
                    letterSpacing: 0,
                    height: 1.12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 7 : 13),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11.5 : 14.4,
              height: compact ? 1.2 : 1.28,
            ),
          ),
          SizedBox(height: compact ? 7 : 14),
          Column(
            children: List.generate(points.length, (index) {
              final point = points[index];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == points.length - 1
                      ? 0
                      : compact
                      ? 6
                      : 10,
                ),
                child: _HeroPointRow(point: point, compact: compact),
              );
            }),
          ),
          if (note != null && note!.isNotEmpty) ...[
            SizedBox(height: compact ? 7 : 12),
            _InlineNote(
              icon: noteIcon ?? Icons.info_outline_rounded,
              text: note!,
              compact: compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroInfoPoint {
  const _HeroInfoPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class _HeroPointRow extends StatelessWidget {
  const _HeroPointRow({required this.point, required this.compact});

  final _HeroInfoPoint point;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            point.icon,
            color: CaRismaDesignTokens.blueBright,
            size: compact ? 16 : 20,
          ),
          SizedBox(width: compact ? 7 : 11),
          Expanded(
            child: Text(
              point.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.76),
                fontWeight: FontWeight.w700,
                fontSize: compact ? 10.8 : 13.5,
                height: compact ? 1.15 : 1.22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({
    required this.icon,
    required this.text,
    required this.compact,
  });

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: CaRismaDesignTokens.blueBright,
          size: compact ? 15 : 19,
        ),
        SizedBox(width: compact ? 7 : 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
              fontSize: compact ? 10.4 : 12.5,
              height: compact ? 1.16 : 1.23,
            ),
          ),
        ),
      ],
    );
  }
}
