import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_info.dart';
import '../../app/theme.dart';
import '../../core/api/api_providers.dart';
import '../../core/api/demo_api_client.dart';
import '../../l10n/app_localizations.dart';

/// S16 «O aplikacji i źródła danych»: version (5 taps reveal the demo
/// switch), data sources with the OSM attribution, the medical note and
/// licences.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  /// Taps on the version that reveal the demo switch (spec S16).
  static const demoTaps = 5;

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  int _taps = 0;

  void _tapVersion() {
    if (_taps >= AboutScreen.demoTaps) return;
    setState(() => _taps++);
    final left = AboutScreen.demoTaps - _taps;
    if (left > 0 && left < 3) {
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 800),
            content: Text(AppLocalizations.of(context).aboutDemoTapsLeft(left)),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final demo = ref.watch(demoModeProvider);
    final showDemo = demo || _taps >= AboutScreen.demoTaps;
    final scenario = ref.watch(demoAlertScenarioProvider);

    final sources = [
      l10n.aboutSourceMap,
      l10n.aboutSourceSearch,
      l10n.aboutSourceRoutes,
      l10n.aboutSourceAlerts,
      l10n.aboutSourceAir,
      l10n.aboutSourceWeather,
      l10n.aboutSourceShade,
      l10n.aboutSourcePlaces,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Text(l10n.appTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSizes.s8),
          Text(l10n.aboutDescription, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSizes.s16),
          Card(
            color: AppColors.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.s16),
              child: Row(
                children: [
                  const Icon(
                    Icons.medical_information_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSizes.s12),
                  Expanded(
                    child: Text(
                      l10n.aboutMedical,
                      key: const Key('about-medical'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s24),
          Semantics(
            header: true,
            child: Text(l10n.aboutSources, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AppSizes.s8),
          for (final s in sources)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.s8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Icon(Icons.circle, size: 6),
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Expanded(child: Text(s, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: AppSizes.s8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_rounded),
            title: Text(l10n.aboutLicenses),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: appVersion,
            ),
          ),
          ListTile(
            key: const Key('about-version'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.aboutVersion(appVersion)),
            onTap: _tapVersion,
          ),
          if (showDemo) ...[
            const Divider(),
            SwitchListTile(
              key: const Key('about-demo'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.aboutDemoMode),
              subtitle: Text(l10n.aboutDemoModeBody),
              value: demo,
              onChanged: (v) => ref.read(demoModeProvider.notifier).set(v),
            ),
            const SizedBox(height: AppSizes.s8),
            Text(l10n.aboutDemoAlert, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSizes.s8),
            Wrap(
              spacing: AppSizes.s8,
              children: [
                for (final s in DemoAlertScenario.values)
                  ChoiceChip(
                    key: Key('about-demo-alert-${s.name}'),
                    label: Text(switch (s) {
                      DemoAlertScenario.none => l10n.aboutDemoAlertNone,
                      DemoAlertScenario.level2 => l10n.aboutDemoAlertLevel(2),
                      DemoAlertScenario.level3 => l10n.aboutDemoAlertLevel(3),
                    }),
                    selected: scenario == s,
                    onSelected: (_) =>
                        ref.read(demoAlertScenarioProvider.notifier).set(s),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
