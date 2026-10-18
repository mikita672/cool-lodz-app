import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

/// Debug-only page with every design-system component (filled in by APP-06).
class ComponentsShowcase extends StatelessWidget {
  const ComponentsShowcase({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(code: 'APP-06', title: 'Komponenty');
}
