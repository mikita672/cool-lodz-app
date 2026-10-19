import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/game/game_config.dart';
import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/empty_state.dart';
import '../game/data/game_config_repository.dart';

/// Government advice on heat (RCB), used when the alert has no link.
final officialAdviceUrl = Uri.parse(
  'https://www.gov.pl/web/rcb/jak-przetrwac-upal2',
);

/// S14 Alert upałowy: level, period, source, 3 tips, the official advice
/// and «Pokaż miejsca chłodu». In heat mode (level 3) it also explains what
/// changes in the app.
class AlertScreen extends ConsumerWidget {
  const AlertScreen({super.key, this.launch = _launch});

  /// Opens a link outside the app; injected in tests.
  final Future<bool> Function(Uri url) launch;

  static Future<bool> _launch(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final alert = ref.watch(currentAlertProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.alertTitle)),
      body: alert == null
          ? Center(
              child: EmptyState(
                icon: Icons.wb_sunny_outlined,
                title: l10n.alertNone,
                message: l10n.alertNoneBody,
              ),
            )
          : _AlertBody(alert: alert, launch: launch),
    );
  }
}

class _AlertBody extends StatelessWidget {
  const _AlertBody({required this.alert, required this.launch});

  final Alert alert;
  final Future<bool> Function(Uri url) launch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final level = alert.level.clamp(1, 3);
    final color = AppColors.heat(level);
    final onColor = level == 3 ? AppColors.onPrimary : AppColors.onSurface;
    final synthetic = isOverrideAlert(alert);
    final tips = alert.recommendations.isNotEmpty
        ? alert.recommendations
        : [l10n.alertTip1, l10n.alertTip2, l10n.alertTip3];
    String hm(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        Semantics(
          liveRegion: true,
          child: Container(
            key: const Key('alert-header'),
            padding: const EdgeInsets.all(AppSizes.s16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.thermostat_rounded, color: onColor, size: 32),
                const SizedBox(height: AppSizes.s8),
                Text(
                  l10n.alertHeading(level),
                  style: AppTextStyles.titleL.copyWith(color: onColor),
                ),
                const SizedBox(height: AppSizes.s4),
                Text(
                  synthetic
                      ? l10n.alertToday(alert.area)
                      : l10n.alertPeriod(
                          alert.area,
                          hm(alert.validFrom),
                          hm(alert.validTo),
                        ),
                  style: AppTextStyles.body.copyWith(color: onColor),
                ),
                if (alert.source.isNotEmpty)
                  Text(
                    l10n.alertSource(alert.source),
                    style: AppTextStyles.bodyS.copyWith(color: onColor),
                  ),
              ],
            ),
          ),
        ),
        if (level >= GameConfig.heatModeLevel) ...[
          const SizedBox(height: AppSizes.s16),
          Card(
            key: const Key('alert-heat-mode'),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.alertHeatModeTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSizes.s4),
                  Text(
                    l10n.alertHeatModeBody,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSizes.s24),
        Semantics(
          header: true,
          child: Text(l10n.alertWhatToDo, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSizes.s8),
        for (final (i, tip) in tips.take(3).indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.s8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text('${i + 1}', style: theme.textTheme.labelMedium),
                ),
                const SizedBox(width: AppSizes.s12),
                Expanded(child: Text(tip, style: theme.textTheme.bodyLarge)),
              ],
            ),
          ),
        const SizedBox(height: AppSizes.s8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('alert-official'),
            onPressed: () async {
              final url =
                  Uri.tryParse(alert.officialUrl ?? '') ?? officialAdviceUrl;
              final ok = await launch(url).catchError((Object _) => false);
              if (!ok && context.mounted) {
                showAppToast(
                  context,
                  l10n.alertOpenError,
                  kind: ToastKind.error,
                );
              }
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l10n.alertOfficial),
          ),
        ),
        const SizedBox(height: AppSizes.s16),
        AppButton(
          key: const Key('alert-show-cool'),
          label: l10n.alertShowCool,
          icon: Icons.ac_unit_rounded,
          expand: true,
          onPressed: () => context.go(Routes.coolPlaces),
        ),
      ],
    );
  }
}
