import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_screen.dart';

/// S09 Miejsca chłodu. Placeholder from APP-01; the feature ticket replaces it.
class CoolPlacesScreen extends StatelessWidget {
  const CoolPlacesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(code: 'S09', title: 'Miejsca chłodu');
}
