import 'package:intl/intl.dart';

import '../../../core/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../route_plan_screen.dart';
import 'google_maps.dart';

/// The message «Udostępnij trasę» sends, e.g. to family:
/// «Idę pieszo: Manufaktura → Piotrkowska 104. Wyjście: Dziś, 14:30, na
/// miejscu ok. 14:52 (22 min, 72% w cieniu). Trasa: https://…».
String routeShareText({
  required RouteRequest request,
  required RouteVariant variant,
  required DateTime departure,
  required double shadeShare,
  required DateTime now,
  required AppLocalizations l10n,
}) {
  final leavingNow = departure.difference(now).inMinutes.abs() <= 1;
  final when = leavingNow
      ? l10n.routeShareNow
      : formatDeparture(departure, now, l10n);
  final eta = DateFormat('H:mm', 'pl').format(departure.add(variant.duration));
  return l10n.routeShareText(
    request.from.label ?? l10n.routeMyLocation,
    request.to.label ?? l10n.routeShareDestination,
    when,
    eta,
    (variant.durationS / 60).round(),
    (shadeShare * 100).round(),
    GoogleMapsLink.walking(variant.geometry).toString(),
  );
}
