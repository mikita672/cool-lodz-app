import 'package:latlong2/latlong.dart';

import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/place_parts.dart';

/// How a place is described on S08, S09 and the map. All times are local.
extension PlaceText on Place {
  String title(AppLocalizations l10n) =>
      name ??
      switch (type) {
        PlaceType.cool => l10n.placeCategoryOther,
        PlaceType.water => l10n.placeWaterName,
        PlaceType.bench => l10n.placeBenchName,
      };

  String typeLabel(AppLocalizations l10n) => switch (type) {
    PlaceType.water => l10n.placeWaterName,
    PlaceType.bench => l10n.placeBenchName,
    PlaceType.cool => switch (category) {
      PlaceCategory.library => l10n.placeCategoryLibrary,
      PlaceCategory.museum => l10n.placeCategoryMuseum,
      PlaceCategory.culture => l10n.placeCategoryCulture,
      PlaceCategory.mall => l10n.placeCategoryMall,
      PlaceCategory.park => l10n.placeCategoryPark,
      PlaceCategory.station => l10n.placeCategoryStation,
      PlaceCategory.church => l10n.placeCategoryChurch,
      PlaceCategory.other || null => l10n.placeCategoryOther,
    },
  };

  PlaceOpenStatus statusAt(DateTime now) =>
      isOpenAt(now) ? PlaceOpenStatus.open : PlaceOpenStatus.closed;

  /// «Otwarte teraz · do 19:00», «Otwarte całą dobę», «Zamknięte, otwarcie
  /// o 10:00» (today), «… jutro o 10:00» or «… w pon. o 10:00».
  String statusText(AppLocalizations l10n, DateTime now) {
    final h = hours;
    if (h == null) return l10n.placeOpenAllDay;
    final closes = h.closingTime(now);
    if (closes != null) {
      // Open past midnight into a closed day counts as "until" that time.
      return l10n.placeOpenUntil(_hm(closes));
    }
    final opens = h.nextOpening(now);
    if (opens == null) return l10n.placeClosed;
    final days = _dayDiff(now, opens);
    if (days == 0) return l10n.dsClosedOpensAt(_hm(opens));
    final day = days == 1 ? l10n.placeTomorrow : _weekdayShort(opens.weekday);
    return l10n.placeClosedOpensOn(day, _hm(opens));
  }

  /// «Dziś 10:00–18:00» (several intervals joined), «Dziś nieczynne», or
  /// null when always open.
  String? todayHours(AppLocalizations l10n, DateTime now) {
    final h = hours;
    if (h == null) return null;
    final today = h.on(now.weekday);
    if (today.isEmpty) return l10n.placeTodayClosed;
    return l10n.placeTodayHours(
      today
          .map((i) => '${formatHhMm(i.start)}–${formatHhMm(i.end % 1440)}')
          .join(', '),
    );
  }

  List<PlaceAmenity> get uiAmenities => [
    if (has(Amenity.airConditioning)) PlaceAmenity.airConditioning,
    if (has(Amenity.water)) PlaceAmenity.water,
    if (has(Amenity.toilet)) PlaceAmenity.toilet,
    if (has(Amenity.wheelchair) || accessible == true) PlaceAmenity.accessible,
  ];

  /// «Muzeum · ul. Ogrodowa 15».
  String subtitle(AppLocalizations l10n) =>
      [typeLabel(l10n), ?address].join(' · ');
}

/// «350 m» below 1 km, else «2,1 km».
String formatDistance(double meters, AppLocalizations l10n) {
  if (meters < 1000) return l10n.placeDistanceM((meters / 10).round() * 10);
  return l10n.placeDistanceKm(meters / 1000);
}

double distanceTo(Place place, LatLng from) =>
    distanceMeters(from, place.latLng);

String _hm(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

int _dayDiff(DateTime a, DateTime b) => DateTime(
  b.year,
  b.month,
  b.day,
).difference(DateTime(a.year, a.month, a.day)).inDays;

String _weekdayShort(int weekday) =>
    const ['pon.', 'wt.', 'śr.', 'czw.', 'pt.', 'sob.', 'niedz.'][weekday - 1];
