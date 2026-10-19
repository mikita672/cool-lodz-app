import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

/// Bottom bar with the 4 tabs: Mapa, Chłód, Quest, Profil.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the active tab returns to its first screen.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

/// The bottom navigation bar itself (also shown on the debug showcase).
/// Labels are always visible; the active tab gets the indicator pill.
class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.map_rounded),
          label: l10n.navMap,
        ),
        NavigationDestination(
          icon: const Icon(Icons.ac_unit_rounded),
          label: l10n.navCool,
        ),
        NavigationDestination(
          icon: const Icon(Icons.extension_rounded),
          label: l10n.navQuest,
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_rounded),
          label: l10n.navProfile,
        ),
      ],
    );
  }
}
