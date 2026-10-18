import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_screen.dart';

/// S12 Odznaki i punkty. Placeholder from APP-01; the feature ticket replaces it.
class BadgesView extends StatelessWidget {
  const BadgesView({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
    code: 'S12',
    title: 'Odznaki i punkty',
    showAppBar: false,
  );
}
