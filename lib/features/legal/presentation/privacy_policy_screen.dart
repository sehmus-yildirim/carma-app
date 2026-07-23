import 'package:flutter/material.dart';

import '../../settings/presentation/settings_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CaRismaLegalContentScreen.forTitle(title: 'Datenschutzerklärung');
  }
}
