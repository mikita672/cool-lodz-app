import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/cool_places/place_format.dart';
import 'package:cool_lodz/l10n/app_localizations_pl.dart';
import 'package:cool_lodz/shared/widgets/place_parts.dart';
import 'package:flutter_test/flutter_test.dart';

/// Closed on Monday, Tue–Sun 10:00–18:00 (like EC1).
final _museum = Place(
  id: 'cool-001',
  type: PlaceType.cool,
  name: 'EC1',
  category: PlaceCategory.culture,
  address: 'ul. Targowa 1/3',
  lat: 51.7675,
  lon: 19.4686,
  hours: OpeningHours.fromJson({
    'mon': <dynamic>[],
    for (final d in ['tue', 'wed', 'thu', 'fri', 'sat', 'sun'])
      d: [
        ['10:00', '18:00'],
      ],
  }),
  amenities: const [Amenity.toilet, Amenity.wheelchair],
);

void main() {
  final l10n = AppLocalizationsPl();
  // 2026-07-13 is a Monday.
  final monday9 = DateTime(2026, 7, 13, 9);
  final tuesday9 = DateTime(2026, 7, 14, 9);
  final tuesday12 = DateTime(2026, 7, 14, 12);
  final tuesday19 = DateTime(2026, 7, 14, 19);
  final saturday19 = DateTime(2026, 7, 18, 19);

  group('status from hours (Europe/Warsaw local time)', () {
    test('open now shows the closing time', () {
      expect(_museum.statusAt(tuesday12), PlaceOpenStatus.open);
      expect(_museum.statusText(l10n, tuesday12), 'Otwarte teraz · do 18:00');
    });

    test('before opening: opens today', () {
      expect(_museum.statusAt(tuesday9), PlaceOpenStatus.closed);
      expect(_museum.statusText(l10n, tuesday9), 'Zamknięte, otwarcie o 10:00');
    });

    test('after closing: opens tomorrow', () {
      expect(_museum.statusAt(tuesday19), PlaceOpenStatus.closed);
      expect(
        _museum.statusText(l10n, tuesday19),
        'Zamknięte, otwarcie jutro o 10:00',
      );
    });

    test('day off: Monday closed, opens Tuesday', () {
      expect(_museum.statusAt(monday9), PlaceOpenStatus.closed);
      expect(_museum.todayHours(l10n, monday9), 'Dziś nieczynne');
      expect(
        _museum.statusText(l10n, monday9),
        'Zamknięte, otwarcie jutro o 10:00',
      );
    });

    test('Saturday evening → opens on Sunday (named weekday after 2 days)', () {
      final closedSunday = Place(
        id: 'x',
        type: PlaceType.cool,
        lat: 0,
        lon: 0,
        hours: OpeningHours.fromJson({
          'mon': [
            ['9:00', '17:00'],
          ],
        }),
      );
      expect(
        closedSunday.statusText(l10n, saturday19),
        'Zamknięte, otwarcie pon. o 9:00',
      );
    });

    test('no hours = always open', () {
      const park = Place(
        id: 'p',
        type: PlaceType.cool,
        category: PlaceCategory.park,
        lat: 0,
        lon: 0,
      );
      expect(park.statusAt(monday9), PlaceOpenStatus.open);
      expect(park.statusText(l10n, monday9), 'Otwarte całą dobę');
      expect(park.todayHours(l10n, monday9), isNull);
    });

    test('never opens', () {
      final closed = Place(
        id: 'c',
        type: PlaceType.cool,
        lat: 0,
        lon: 0,
        hours: OpeningHours.fromJson(const {}),
      );
      expect(closed.statusText(l10n, tuesday12), 'Zamknięte');
    });
  });

  test('today hours, subtitle and amenities', () {
    expect(_museum.todayHours(l10n, tuesday12), 'Dziś 10:00–18:00');
    expect(_museum.subtitle(l10n), 'Kultura · ul. Targowa 1/3');
    expect(_museum.uiAmenities, [PlaceAmenity.toilet, PlaceAmenity.accessible]);
  });

  test('water and bench names', () {
    const water = Place(id: 'w', type: PlaceType.water, lat: 0, lon: 0);
    expect(water.title(l10n), 'Poidełko');
    const bench = Place(id: 'b', type: PlaceType.bench, lat: 0, lon: 0);
    expect(bench.title(l10n), 'Ławka');
  });

  test('distances', () {
    expect(formatDistance(347, l10n), '350 m');
    expect(formatDistance(2140, l10n), '2,1 km');
  });
}
