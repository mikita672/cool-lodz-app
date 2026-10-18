import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_screen.dart';

/// S10 Quest. Placeholder from APP-01; the feature ticket replaces it.
class QuestView extends StatelessWidget {
  const QuestView({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(code: 'S10', title: 'Quest', showAppBar: false);
}
