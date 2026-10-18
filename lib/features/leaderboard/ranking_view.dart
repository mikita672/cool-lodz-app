import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_screen.dart';

/// S13 Ranking. Placeholder from APP-01; the feature ticket replaces it.
class RankingView extends StatelessWidget {
  const RankingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(code: 'S13', title: 'Ranking', showAppBar: false);
}
