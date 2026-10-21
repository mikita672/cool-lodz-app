import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/weather_icon.dart';
import 'data/departure_advice.dart';
import 'data/route_plan.dart';
import 'route_plan_screen.dart';

/// «Kiedy najlepiej iść?»: the best departures for the planned walk; a tap
/// sets the departure time.
class DepartureAdviceSheet extends ConsumerWidget {
  const DepartureAdviceSheet({super.key, this.clock = DateTime.now});

  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final advice = ref.watch(departureAdviceProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          0,
          AppSizes.screenPadding,
          AppSizes.screenPadding,
        ),
        child: Column(
          key: const Key('route-advice-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.routeAdviceTitle, style: AppTextStyles.titleM),
            const SizedBox(height: AppSizes.s4),
            Text(l10n.routeAdviceIntro, style: AppTextStyles.bodyS),
            const SizedBox(height: AppSizes.s12),
            ...switch (advice) {
              AsyncData(:final value) when value.isNotEmpty => [
                for (final (i, o) in value.indexed) ...[
                  _OptionCard(
                    option: o,
                    best: i == 0,
                    now: clock(),
                    onPick: () {
                      ref
                          .read(routePlanProvider.notifier)
                          .setDeparture(o.departAt);
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: AppSizes.s8),
                ],
              ],
              AsyncData() || AsyncError() => [
                Text(
                  l10n.routeAdviceEmpty,
                  key: const Key('route-advice-empty'),
                ),
              ],
              _ => [
                const Padding(
                  padding: EdgeInsets.all(AppSizes.s24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.best,
    required this.now,
    required this.onPick,
  });

  final DepartureOption option;
  final bool best;
  final DateTime now;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final when = formatDeparture(option.departAt, now, l10n);
    final hm = DateFormat('H:mm', 'pl');
    final weather = option.weather;
    final lines = <(IconData, String, Color?)>[
      (
        Icons.park_rounded,
        l10n.routeAdviceShade((option.shadeShare * 100).round()),
        AppColors.primary,
      ),
      (
        Icons.flag_rounded,
        l10n.routeAdviceArrive(hm.format(option.arriveAt)),
        null,
      ),
      if (option.destination case final d?)
        option.destinationOpen == true
            ? (
                Icons.storefront_rounded,
                l10n.routeAdviceDestOpen(
                  d.name ?? '',
                  option.destinationClosesAt == null
                      ? '–'
                      : hm.format(option.destinationClosesAt!),
                ),
                AppColors.successText,
              )
            : (
                Icons.do_not_disturb_on_rounded,
                l10n.routeAdviceDestClosed(d.name ?? ''),
                AppColors.error,
              ),
      if (option.coolOpen > 0)
        (
          Icons.ac_unit_rounded,
          l10n.routeAdviceCoolOpen(option.coolOpen),
          AppColors.cool,
        ),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: best
          ? RoundedRectangleBorder(
              side: const BorderSide(color: AppColors.primary, width: 2),
              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
            )
          : null,
      child: Semantics(
        button: true,
        label: l10n.routeAdvicePick(when),
        child: InkWell(
          key: Key(
            'route-advice-${option.departAt.hour}:${option.departAt.minute}',
          ),
          onTap: onPick,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(when, style: theme.textTheme.titleMedium),
                    ),
                    if (best)
                      Chip(
                        label: Text(l10n.routeAdviceBest),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.primaryContainer,
                      ),
                    if (weather != null) ...[
                      const SizedBox(width: AppSizes.s8),
                      WeatherIcon(hour: weather, instant: option.departAt),
                      if (weather.temperature case final t?) ...[
                        const SizedBox(width: AppSizes.s4),
                        Text(
                          '${t.round()}°C',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                      for (final tag in weatherTags(weather)) ...[
                        const SizedBox(width: AppSizes.s4),
                        Icon(
                          weatherTagIcon(tag),
                          size: 18,
                          color: AppColors.onSurfaceVariant,
                          semanticLabel: weatherTagLabel(tag, weather, l10n),
                        ),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: AppSizes.s4),
                for (final (icon, text, color) in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(icon, size: 16, color: color ?? AppColors.muted),
                        const SizedBox(width: AppSizes.s8),
                        Expanded(
                          child: Text(text, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
