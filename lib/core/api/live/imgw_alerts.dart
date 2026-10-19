import 'package:dio/dio.dart';

import '../../models/models.dart';
import '../api_client.dart';
import 'live_http.dart';
import 'warsaw_time.dart';

/// Heat warnings for Łódź from the IMGW-PIB public data API.
class ImgwAlertsClient {
  ImgwAlertsClient(this._dio);

  factory ImgwAlertsClient.create() => ImgwAlertsClient(createLiveDio());

  static const warningsUrl =
      'https://danepubliczne.imgw.pl/api/data/warningsmeteo';

  final Dio _dio;

  /// Heat warnings for Łódź not yet over at [now], highest level first;
  /// empty = no alert. Throws [ApiException].
  Future<List<Alert>> heatAlerts({required DateTime now}) async {
    final json = await getJson(_dio, warningsUrl);
    return parseImgwWarnings(json, now: now);
  }
}

/// TERYT code of the city county (miasto na prawach powiatu) Łódź.
const lodzTeryt = '1061';

const imgwSource = 'IMGW-PIB';
const imgwWarningsPage = 'https://meteo.imgw.pl/dyn/?osmet=true';

/// Three tips per level (1..3), in the wording of the demo alerts.
const heatRecommendations = <int, List<String>>{
  1: [
    'Miej przy sobie wodę i pij ją małymi łykami przez cały dzień.',
    'W południe wybieraj trasy w cieniu i nie przesadzaj z wysiłkiem.',
    'Noś lekkie, jasne ubranie i nakrycie głowy.',
  ],
  2: [
    'Pij wodę regularnie, nie czekaj, aż poczujesz pragnienie.',
    'W najcieplejszych godzinach wybieraj trasy w cieniu i rób przerwy '
        'w chłodnych miejscach.',
    'Zadzwoń do starszych bliskich lub sąsiadów i zapytaj, czy czegoś '
        'nie potrzebują.',
  ],
  3: [
    'Jeśli możesz, przenieś dłuższe wyjścia i wysiłek na rano albo '
        'na wieczór.',
    'Odpoczywaj w chłodnych miejscach: w bibliotekach, muzeach i galeriach '
        'handlowych.',
    'Nie zostawiaj dzieci ani zwierząt w zaparkowanym samochodzie.',
  ],
};

/// `warningsmeteo` JSON → heat [Alert]s for Łódź still valid at [now],
/// sorted by level (highest first), then start time.
///
/// Unknown entries are skipped; throws [ApiException] (server) only when
/// [json] is not a list of warnings at all.
List<Alert> parseImgwWarnings(Object? json, {required DateTime now}) {
  final items = switch (json) {
    final List<Object?> list => list,
    // Tolerate a wrapper object around the array.
    final Map<Object?, Object?> map =>
      map.values.whereType<List<Object?>>().firstOrNull,
    _ => null,
  };
  if (items == null) {
    throw ApiException(
      ApiErrorKind.server,
      'bad IMGW warnings: ${json.runtimeType}',
    );
  }
  final byId = <String, Alert>{};
  for (final item in items) {
    if (item is! Map<Object?, Object?>) continue;
    final alert = _heatAlert(item);
    if (alert == null || !alert.validTo.isAfter(now)) continue;
    byId.putIfAbsent(alert.id, () => alert);
  }
  return byId.values.toList()..sort((a, b) {
    final level = b.level.compareTo(a.level);
    return level != 0 ? level : a.validFrom.compareTo(b.validFrom);
  });
}

Alert? _heatAlert(Map<Object?, Object?> item) {
  final event = asText(
    item['nazwa_zdarzenia'] ??
        findValue(item, (k) => k.contains('zdarzeni') || k == 'nazwa'),
  );
  if (event == null || !normalizeKey(event).contains('upal')) return null;
  if (!_coversLodz(item['teryt'] ?? findValue(item, (k) => k == 'teryt'))) {
    return null;
  }
  final validTo = parseWarsawTime(
    item['obowiazuje_do'] ??
        findValue(item, (k) => k.startsWith('obowiazuje') && k.endsWith('do')),
  );
  if (validTo == null) return null;
  final validFrom =
      parseWarsawTime(
        item['obowiazuje_od'] ??
            findValue(
              item,
              (k) => k.startsWith('obowiazuje') && k.endsWith('od'),
            ),
      ) ??
      parseWarsawTime(item['opublikowano']) ??
      validTo;
  final level =
      (parseInt(item['stopien'] ?? findValue(item, (k) => k == 'stopien')) ?? 1)
          .clamp(1, 3);
  final rawId = asText(item['id']);
  final id = rawId != null
      ? 'imgw-$rawId'
      : 'imgw-${validFrom.toIso8601String().substring(0, 13)}-lodz-$level';
  return Alert(
    id: id,
    level: level,
    title: 'Ostrzeżenie przed upałem $level. stopnia',
    area: 'Łódź',
    validFrom: validFrom.toLocal(),
    validTo: validTo.toLocal(),
    source: imgwSource,
    recommendations: heatRecommendations[level]!,
    officialUrl: imgwWarningsPage,
  );
}

/// `teryt` as a list of codes or one comma-separated string. Matches the
/// county code and longer codes inside it (gminy `106101…`).
bool _coversLodz(Object? teryt) {
  final codes = switch (teryt) {
    final List<Object?> list => list.map(asText),
    final Object value => (asText(value) ?? '').split(RegExp(r'[,;\s]+')),
    null => const <String?>[],
  };
  return codes.any((c) => c != null && c.trim().startsWith(lodzTeryt));
}
