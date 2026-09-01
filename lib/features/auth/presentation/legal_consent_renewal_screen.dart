import 'package:flutter/material.dart';

import '../../../shared/legal/legal_versions.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../legal/presentation/privacy_policy_screen.dart';
import '../../legal/presentation/terms_screen.dart';

class LegalConsentRenewalScreen extends StatefulWidget {
  const LegalConsentRenewalScreen({
    super.key,
    required this.onAccept,
    required this.onLogout,
  });

  final Future<void> Function() onAccept;
  final Future<void> Function() onLogout;

  @override
  State<LegalConsentRenewalScreen> createState() =>
      _LegalConsentRenewalScreenState();
}

class _LegalConsentRenewalScreenState extends State<LegalConsentRenewalScreen> {
  bool _acceptedTerms = false;
  bool _acknowledgedPrivacy = false;
  bool _confirmedResponsibleUse = false;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _canAccept =>
      _acceptedTerms &&
      _acknowledgedPrivacy &&
      _confirmedResponsibleUse &&
      !_isSaving;

  Future<void> _accept() async {
    if (!_canAccept) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.onAccept();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Die Bestätigung konnte nicht gespeichert werden. Bitte prüfe deine Verbindung.';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: DecoratedBox(
                  decoration: CaRismaDesignTokens.surfaceDecoration(
                    radius: CaRismaDesignTokens.radiusPanel,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.gavel_rounded,
                          color: CaRismaDesignTokens.bluePrimary,
                          size: 38,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Rechtliche Hinweise aktualisiert',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CaRismaDesignTokens.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Bitte lies die aktuellen Fassungen. Ohne deine ausdrückliche Bestätigung wird die App nicht freigeschaltet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CaRismaDesignTokens.textSecondary,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _ConsentCheckbox(
                          value: _acceptedTerms,
                          onChanged: (value) =>
                              setState(() => _acceptedTerms = value),
                          title: 'AGB v${LegalVersions.terms} akzeptieren',
                          linkLabel: 'AGB öffnen',
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TermsScreen(),
                            ),
                          ),
                        ),
                        _ConsentCheckbox(
                          value: _acknowledgedPrivacy,
                          onChanged: (value) =>
                              setState(() => _acknowledgedPrivacy = value),
                          title:
                              'Datenschutzerklärung v${LegalVersions.privacy} zur Kenntnis genommen',
                          linkLabel: 'Datenschutz öffnen',
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          ),
                        ),
                        _ConsentCheckbox(
                          value: _confirmedResponsibleUse,
                          onChanged: (value) =>
                              setState(() => _confirmedResponsibleUse = value),
                          title:
                              'Ich bin mindestens 16 Jahre alt und bestätige die verantwortungsvolle Nutzung. plaqa ist kein Notruf- oder Sicherheitsdienst.',
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: CaRismaDesignTokens.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        CaRismaPrimaryButton(
                          label: _isSaving
                              ? 'Wird gespeichert ...'
                              : 'Bestätigen und fortfahren',
                          icon: Icons.check_rounded,
                          onPressed: _accept,
                          isEnabled: _canAccept,
                          surfaceOutlined: true,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isSaving ? null : widget.onLogout,
                          child: const Text('Abmelden'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.title,
    this.linkLabel,
    this.onOpen,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String? linkLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (next) => onChanged(next ?? false),
            side: const BorderSide(color: CaRismaDesignTokens.bluePrimary),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: CaRismaDesignTokens.textPrimary,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (linkLabel != null && onOpen != null)
                    TextButton(
                      onPressed: onOpen,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                      ),
                      child: Text(linkLabel!),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
