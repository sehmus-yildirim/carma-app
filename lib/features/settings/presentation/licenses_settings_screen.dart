import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/config/carisma_app_config.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';

class CaRismaLicensesScreen extends StatelessWidget {
  const CaRismaLicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              CaRismaSubPageHeader(
                icon: Icons.workspace_premium_outlined,
                title: 'Lizenzen',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CaRismaBlueIconBox(
                          icon: Icons.directions_car_filled_rounded,
                          size: 48,
                          iconSize: 24,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'plaqa',
                                style: TextStyle(
                                  color: CaRismaDesignTokens.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Version ${CaRismaAppConfig.appVersion}',
                                style: const TextStyle(
                                  color: CaRismaDesignTokens.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Die plaqa-Anwendung, ihr Markenauftritt, ihre eigenen Inhalte und ihr individuelles Design sind urheberrechtlich geschützt. Eine Nutzung außerhalb der vorgesehenen App-Funktionen bedarf der vorherigen Erlaubnis des Rechteinhabers.',
                      style: TextStyle(
                        color: CaRismaDesignTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.42,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _OpenSourceLicensesScreen(),
                  ),
                ),
                child: GlassCard(
                  padding: const EdgeInsets.all(15),
                  child: const Row(
                    children: [
                      CaRismaBlueIconBox(
                        icon: Icons.code_rounded,
                        size: 46,
                        iconSize: 23,
                      ),
                      SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Open-Source-Hinweise',
                              style: TextStyle(
                                color: CaRismaDesignTokens.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Alle verwendeten Drittanbieter-Lizenzen anzeigen',
                              style: TextStyle(
                                color: CaRismaDesignTokens.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: CaRismaDesignTokens.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenSourceLicensesScreen extends StatefulWidget {
  const _OpenSourceLicensesScreen();

  @override
  State<_OpenSourceLicensesScreen> createState() =>
      _OpenSourceLicensesScreenState();
}

class _OpenSourceLicensesScreenState extends State<_OpenSourceLicensesScreen> {
  late final Future<List<_PackageLicense>> _licenses = _loadLicenses();

  static Future<List<_PackageLicense>> _loadLicenses() async {
    final byPackage = <String, List<String>>{};
    await for (final entry in LicenseRegistry.licenses) {
      final text = entry.paragraphs
          .map((paragraph) => paragraph.text)
          .join('\n\n');
      for (final package in entry.packages) {
        byPackage.putIfAbsent(package, () => <String>[]).add(text);
      }
    }
    final result =
        byPackage.entries
            .map(
              (entry) => _PackageLicense(
                package: entry.key,
                text: entry.value.toSet().join('\n\n---\n\n'),
              ),
            )
            .toList(growable: false)
          ..sort((first, second) => first.package.compareTo(second.package));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: FutureBuilder<List<_PackageLicense>>(
            future: _licenses,
            builder: (context, snapshot) {
              return ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  CaRismaSubPageHeader(
                    icon: Icons.code_rounded,
                    title: 'Open Source',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 18),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          color: CaRismaDesignTokens.bluePrimary,
                        ),
                      ),
                    )
                  else if (snapshot.hasError)
                    const GlassCard(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Die Lizenzhinweise konnten gerade nicht geladen werden.',
                        style: TextStyle(
                          color: CaRismaDesignTokens.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    ...?snapshot.data?.map(
                      (license) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          padding: EdgeInsets.zero,
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              splashFactory: NoSplash.splashFactory,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              title: Text(
                                license.package,
                                style: const TextStyle(
                                  color: CaRismaDesignTokens.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              iconColor: CaRismaDesignTokens.bluePrimary,
                              collapsedIconColor:
                                  CaRismaDesignTokens.textSecondary,
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              children: [
                                SelectableText(
                                  license.text,
                                  style: const TextStyle(
                                    color: CaRismaDesignTokens.textSecondary,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PackageLicense {
  const _PackageLicense({required this.package, required this.text});

  final String package;
  final String text;
}
