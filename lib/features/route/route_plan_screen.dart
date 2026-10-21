import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/api/api_providers.dart';
import '../../core/api/live/weather.dart';
import '../../core/api/reference_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/time_wheel_sheet.dart';
import '../profile/data/comfort_profile_provider.dart';
import '../profile/profile_select_screen.dart';
import 'data/route_plan.dart';
import 'departure_advice_sheet.dart';
import 'endpoint_search_screen.dart';

/// S06 Planowanie trasy: from, to, departure time, comfort profile chip,
/// the two demo quick routes and «Pokaż trasy» (→ S07).
class RoutePlanScreen extends ConsumerWidget {
  const RoutePlanScreen({super.key, this.clock = DateTime.now});

  /// Injected in tests.
  final DateTime Function() clock;

  /// Departures can be planned up to a week ahead.
  static const maxDaysAhead = 7;

  Future<void> _pickFrom(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final picked = await EndpointSearchScreen.open(
      context,
      title: l10n.routeSearchFromTitle,
      // Not both ends at the user's position.
      allowMyLocation: ref.read(routePlanProvider).to is! MyLocation,
    );
    if (picked != null) ref.read(routePlanProvider.notifier).setFrom(picked);
  }

  Future<void> _pickTo(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final picked = await EndpointSearchScreen.open(
      context,
      title: l10n.routeSearchToTitle,
      allowMyLocation: ref.read(routePlanProvider).from is! MyLocation,
    );
    if (picked != null) ref.read(routePlanProvider.notifier).setTo(picked);
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final now = clock();
    WeatherForecast? forecast;
    try {
      forecast = await ref
          .read(forecastProvider.future)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // The picker works without weather.
    }
    if (!context.mounted) return;
    final picked = await showTimeWheelSheet(
      context,
      title: l10n.routeDepartTitle,
      initial: ref.read(routePlanProvider).departAt ?? now,
      now: now,
      days: maxDaysAhead + 1,
      forecast: forecast,
    );
    if (picked == null) return;
    // A time earlier today means "now".
    ref
        .read(routePlanProvider.notifier)
        .setDeparture(picked.isBefore(now) ? now : picked);
  }

  Future<void> _advise(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DepartureAdviceSheet(clock: clock),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final plan = ref.watch(routePlanProvider);
    final profile = ref.watch(comfortProfileProvider);
    final notifier = ref.read(routePlanProvider.notifier);
    final (profileIcon, profileName, _) = profileLabels(profile.id, l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routePlanTitle)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  0,
                  AppSizes.screenPadding,
                  AppSizes.screenPadding,
                ),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.s4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _EndpointField(
                                  key: const Key('route-from'),
                                  label: l10n.routeFrom,
                                  value: _label(plan.from, l10n),
                                  icon: Icons.trip_origin_rounded,
                                  onTap: () => _pickFrom(context, ref),
                                ),
                                const Divider(indent: 56),
                                _EndpointField(
                                  key: const Key('route-to'),
                                  label: l10n.routeTo,
                                  value: plan.to == null
                                      ? null
                                      : _label(plan.to!, l10n),
                                  placeholder: l10n.routeToHint,
                                  icon: Icons.place_rounded,
                                  onTap: () => _pickTo(context, ref),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const Key('route-swap'),
                            tooltip: l10n.routeSwap,
                            onPressed: plan.to == null ? null : notifier.swap,
                            icon: const Icon(Icons.swap_vert_rounded),
                          ),
                          const SizedBox(width: AppSizes.s4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.s24),
                  _SectionTitle(l10n.routeDeparture),
                  const SizedBox(height: AppSizes.s8),
                  Wrap(
                    spacing: AppSizes.s8,
                    runSpacing: AppSizes.s8,
                    children: [
                      ChoiceChip(
                        key: const Key('route-depart-now'),
                        label: Text(l10n.routeDepartNow),
                        selected: plan.departAt == null,
                        onSelected: (_) => notifier.setDeparture(null),
                      ),
                      ChoiceChip(
                        key: const Key('route-depart-pick'),
                        avatar: Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: plan.departAt == null
                              ? AppColors.onSurface
                              : AppColors.onPrimary,
                        ),
                        label: Text(
                          plan.departAt == null
                              ? l10n.routeDepartPick
                              : formatDeparture(plan.departAt!, clock(), l10n),
                        ),
                        selected: plan.departAt != null,
                        onSelected: (_) => _pickTime(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.s8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('route-advice'),
                      onPressed: plan.isComplete
                          ? () => _advise(context)
                          : null,
                      icon: const Icon(Icons.tips_and_updates_rounded),
                      label: Text(l10n.routeAdviceButton),
                    ),
                  ),
                  const SizedBox(height: AppSizes.s24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Tooltip(
                      message: l10n.routeProfileChipHint,
                      child: ActionChip(
                        key: const Key('route-profile'),
                        avatar: Icon(profileIcon, color: AppColors.primary),
                        label: Text(l10n.routeProfileChip(profileName)),
                        onPressed: () => context.push(Routes.profileSelect),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.s24),
                  _SectionTitle(l10n.routeQuickTitle),
                  const SizedBox(height: AppSizes.s8),
                  for (final route in ReferenceRoutes.all) ...[
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        key: Key('route-quick-${route.id}'),
                        leading: const Icon(
                          Icons.alt_route_rounded,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          l10n.routeQuickRoute(
                            route.from.label ?? '',
                            route.to.label ?? '',
                          ),
                          style: theme.textTheme.bodyLarge,
                        ),
                        onTap: () => notifier.useReference(route),
                      ),
                    ),
                    const SizedBox(height: AppSizes.s8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.s8,
                AppSizes.screenPadding,
                AppSizes.screenPadding,
              ),
              child: AppButton(
                key: const Key('route-show'),
                label: l10n.routeShowRoutes,
                icon: Icons.directions_walk_rounded,
                expand: true,
                onPressed: plan.isComplete
                    ? () {
                        // A fresh calculation for the current plan.
                        ref.invalidate(routeRequestProvider);
                        context.push(Routes.routeResult);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _label(RouteEndpoint endpoint, AppLocalizations l10n) =>
      switch (endpoint) {
        MyLocation() => l10n.routeMyLocation,
        PointEndpoint() => endpoint.label,
      };
}

/// «Dziś, 14:30», «Jutro, 9:00» or «pt 24.10, 18:00».
String formatDeparture(DateTime at, DateTime now, AppLocalizations l10n) {
  final time = DateFormat('H:mm', 'pl').format(at);
  final days = DateUtils.dateOnly(
    at,
  ).difference(DateUtils.dateOnly(now)).inDays;
  if (days == 0) return l10n.routeDepartToday(time);
  if (days == 1) return l10n.routeDepartTomorrow(time);
  return l10n.routeDepartOn(DateFormat('EEE d.MM', 'pl').format(at), time);
}

class _EndpointField extends StatelessWidget {
  const _EndpointField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.placeholder,
  });

  final String label;
  final String? value;
  final String? placeholder;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = value == null;
    return Semantics(
      button: true,
      label: '$label: ${value ?? placeholder ?? ''}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.minTouchTarget + 8,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.s16,
              vertical: AppSizes.s8,
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: AppSizes.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.labelMedium),
                      Text(
                        value ?? placeholder ?? '',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: empty
                              ? AppColors.onSurfaceVariant
                              : AppColors.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
