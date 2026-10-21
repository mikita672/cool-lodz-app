import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/route/data/route_share.dart';
import 'package:cool_lodz/l10n/app_localizations_pl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pl'));

  final request = RouteRequest(
    from: const RoutePoint(lat: 51.78, lon: 19.45, label: 'Manufaktura'),
    to: const RoutePoint(lat: 51.76, lon: 19.46, label: 'Piotrkowska 104'),
    datetime: DateTime(2026, 7, 15, 18),
    profile: const RouteProfile(
      id: ProfileId.senior,
      weights: ProfileWeights(shade: 90, time: 20, quiet: 60, air: 60),
    ),
  );
  final variant = RouteVariant(
    variant: RouteVariantType.shaded,
    geometry: [
      const LatLng(51.78, 19.45),
      const LatLng(51.77, 19.455),
      const LatLng(51.76, 19.46),
    ],
    distanceM: 1800,
    durationS: 1320,
    sunShare: 0.28,
    extraTimeVsShortestS: 240,
  );

  test('a later departure: day, time, arrival, minutes and shade', () {
    final text = routeShareText(
      request: request,
      variant: variant,
      departure: DateTime(2026, 7, 15, 18),
      shadeShare: 0.72,
      now: DateTime(2026, 7, 15, 12),
      l10n: AppLocalizationsPl(),
    );
    expect(
      text,
      startsWith(
        'Idę pieszo: Manufaktura → Piotrkowska 104.\n'
        'Wyjście: Dziś, 18:00, na miejscu ok. 18:22 (22 min, 72% w cieniu).\n'
        'Trasa: https://www.google.com/maps/dir/?api=1',
      ),
    );
    expect(text, endsWith('Cool Łódź'));
  });

  test('«Moja lokalizacja» when the start has no name; now = «teraz»', () {
    final mine = RouteRequest(
      from: const RoutePoint(lat: 51.78, lon: 19.45),
      to: request.to,
      datetime: request.datetime,
      profile: request.profile,
    );
    final text = routeShareText(
      request: mine,
      variant: variant,
      departure: DateTime(2026, 7, 15, 12),
      shadeShare: 0.5,
      now: DateTime(2026, 7, 15, 12),
      l10n: AppLocalizationsPl(),
    );
    expect(text, startsWith('Idę pieszo: Moja lokalizacja → Piotrkowska 104.'));
    expect(text, contains('Wyjście: teraz, na miejscu ok. 12:22'));
  });
}
