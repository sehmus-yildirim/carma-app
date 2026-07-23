import 'package:flutter/material.dart';

import '../../settings/presentation/settings_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CaRismaLegalContentScreen.forTitle(title: 'AGB');
  }
}
