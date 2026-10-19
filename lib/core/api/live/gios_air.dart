import 'dart:async';

import 'package:dio/dio.dart';

import '../../models/models.dart';
import '../../warsaw_time.dart';
import '../api_client.dart';
import 'live_http.dart';

/// Air-quality stations in Łódź with the current GIOŚ index, from the PJP
/// API v1 (the old paths without `/v1` answer 410 Gone since 2025).
class GiosAirClient {
  GiosAirClient(
    this._dio, {
    this.maxIndexCalls = 8,
    this.concurrency = 4,
    this.indexTimeout = const Duration(seconds: 3),
  });

  factory GiosAirClient.create() => GiosAirClient(createLiveDio());

  static const _base = 'https://api.gios.gov.pl/pjp-api/v1/rest';
  static const stationsUrl = '$_base/station/findAll?size=500';
  static String indexUrl(String stationId) =>
      '$_base/aqindex/getIndex/$stationId';

  final Dio _dio;

  /// Stations beyond this get `indexLevel: null` without a request.
  final int maxIndexCalls;

  /// Index requests in flight at once.
  final int concurrency;

  /// A slow station gets no index instead of holding up the others (the
  /// whole call has [apiTimeout]).
  final Duration indexTimeout;

  Future<List<GiosStation>>? _stations;

  /// Łódź stations with their index (null where GIOŚ has none or the index
  /// request failed). The station list is fetched once per client.
  /// Throws [ApiException] when the station list cannot be loaded.
  Future<List<AirStation>> lodzStations() async {
    final all = await (_stations ??= _loadStations());
    final stations = all.where((s) => isLodz(s.city)).toList();
    final indexes = <GiosIndex?>[];
    final withIndex = stations.take(maxIndexCalls).toList();
    for (var i = 0; i < withIndex.length; i += concurrency) {
      indexes.addAll(
        await Future.wait([
          for (final s in withIndex.skip(i).take(concurrency)) _index(s.id),
        ]),
      );
    }
    return [
      for (final (i, s) in stations.indexed)
        AirStation(
          id: 'gios-${s.id}',
          name: s.name,
          lat: s.lat,
          lon: s.lon,
          indexLevel: i < indexes.length ? indexes[i]?.level : null,
          updatedAt: i < indexes.length ? indexes[i]?.updatedAt : null,
        ),
    ];
  }

  Future<List<GiosStation>> _loadStations() async {
    try {
      return parseGiosStations(await getJson(_dio, stationsUrl));
    } catch (_) {
      _stations = null; // try again next time
      rethrow;
    }
  }

  Future<GiosIndex?> _index(String stationId) async {
    try {
      return parseGiosIndex(
        await getJson(_dio, indexUrl(stationId)).timeout(indexTimeout),
      );
    } on ApiException {
      return null;
    } on TimeoutException {
      return null;
    }
  }
}

/// One measuring station from `station/findAll`.
class GiosStation {
  const GiosStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.city,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String? city;
}

/// Overall index of a station from `aqindex/getIndex`.
class GiosIndex {
  const GiosIndex({this.level, this.updatedAt});

  /// 0 (bardzo dobry) … 5 (bardzo zły); null = no index.
  final int? level;
  final DateTime? updatedAt;
}

bool isLodz(String? city) => city != null && normalizeKey(city) == 'lodz';

/// Station list (`{"Lista stacji pomiarowych": [{"Identyfikator stacji": 295,
/// "WGS84 φ N": "51.758050", "Nazwa miasta": "Łódź", …}]}`); a bare list
/// is accepted too.
/// Entries without id, name or coordinates are skipped; throws
/// [ApiException] (server) when nothing usable is found.
List<GiosStation> parseGiosStations(Object? json) {
  final items = switch (json) {
    final List<Object?> list => list,
    final Map<Object?, Object?> map => switch (findValue(
      map,
      (k) => k.contains('lista stacji'),
    )) {
      final List<Object?> list => list,
      _ => map.values.whereType<List<Object?>>().firstOrNull,
    },
    _ => null,
  };
  final stations = [
    for (final item in items ?? const <Object?>[])
      if (item is Map<Object?, Object?>) ?_station(item),
  ];
  if (stations.isEmpty) {
    throw const ApiException(ApiErrorKind.server, 'bad GIOŚ station list');
  }
  return stations;
}

GiosStation? _station(Map<Object?, Object?> item) {
  final id = asText(
    item['Identyfikator stacji'] ??
        findValue(item, (k) => k.startsWith('identyfikator stacji')),
  );
  final name = asText(
    item['Nazwa stacji'] ?? findValue(item, (k) => k == 'nazwa stacji'),
  );
  final lat = parseNum(
    item['WGS84 φ N'] ??
        findValue(item, (k) => k.contains('wgs84') && _isLatKey(k)),
  );
  final lon = parseNum(
    item['WGS84 λ E'] ??
        findValue(item, (k) => k.contains('wgs84') && _isLonKey(k)),
  );
  final city = asText(
    item['Nazwa miasta'] ?? findValue(item, (k) => k.contains('miasta')),
  );
  if (id == null || name == null || lat == null || lon == null) return null;
  return GiosStation(
    id: id,
    name: name,
    lat: lat.toDouble(),
    lon: lon.toDouble(),
    city: city,
  );
}

bool _isLatKey(String k) => k.contains('φ') || RegExp(r'\bn\b').hasMatch(k);
bool _isLonKey(String k) => k.contains('λ') || RegExp(r'\be\b').hasMatch(k);

const _categories = {
  'bardzo dobry': 0,
  'dobry': 1,
  'umiarkowany': 2,
  'dostateczny': 3,
  'zly': 4,
  'bardzo zly': 5,
};

/// Overall station index (`{"AqIndex": {"Wartość indeksu": 1, …}}`; GIOŚ
/// sends every field as null for a station without an index). Missing or
/// `-1` index → `level: null`. Throws [ApiException] (server) when [json] is
/// not an object.
GiosIndex parseGiosIndex(Object? json) {
  if (json is! Map<Object?, Object?>) {
    throw ApiException(ApiErrorKind.server, 'bad GIOŚ index: $json');
  }
  final inner = findValue(json, (k) => k == 'aqindex');
  final map = inner is Map<Object?, Object?> ? inner : json;

  // There are also per-pollutant keys ("… dla wskaźnika PM10"): skip them.
  bool overall(String k) => !k.contains('wskaznik');
  final status = findValue(
    map,
    (k) => k.startsWith('status indeksu') && overall(k),
  );
  int? level = parseInt(
    findValue(map, (k) => k == 'wartosc indeksu') ??
        findValue(map, (k) => k.startsWith('wartosc indeksu') && overall(k)),
  );
  final category = asText(
    findValue(map, (k) => k.startsWith('nazwa kategorii') && overall(k)),
  );
  if (level == null && category != null) {
    level = _categories[normalizeKey(category)];
  }
  if (level != null && (level < 0 || level > 5)) level = null;
  if (status == false) level = null;

  final updatedAt = parseWarsawTime(
    findValue(
      map,
      (k) => k.startsWith('data wykonania obliczen') && overall(k),
    ),
  );
  return GiosIndex(level: level, updatedAt: updatedAt?.toLocal());
}
