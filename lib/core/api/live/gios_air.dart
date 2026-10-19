import 'package:dio/dio.dart';

import '../../models/models.dart';
import '../api_client.dart';
import 'live_http.dart';
import 'warsaw_time.dart';

/// Air-quality stations in Łódź with the current GIOŚ index, from the PJP
/// API (v1, falling back to the old v0 paths).
class GiosAirClient {
  GiosAirClient(this._dio, {this.maxIndexCalls = 8, this.concurrency = 4});

  factory GiosAirClient.create() => GiosAirClient(createLiveDio());

  static const _base = 'https://api.gios.gov.pl/pjp-api';
  static const stationsUrlV1 = '$_base/v1/rest/station/findAll?size=500';
  static const stationsUrlV0 = '$_base/rest/station/findAll';
  static String indexUrlV1(String stationId) =>
      '$_base/v1/rest/aqindex/getIndex/$stationId';
  static String indexUrlV0(String stationId) =>
      '$_base/rest/aqindex/getIndex/$stationId';

  final Dio _dio;

  /// Stations beyond this get `indexLevel: null` without a request.
  final int maxIndexCalls;

  /// Index requests in flight at once.
  final int concurrency;

  Future<_StationList>? _stations;

  /// Łódź stations with their index (null where GIOŚ has none or the index
  /// request failed). The station list is fetched once per client.
  /// Throws [ApiException] when the station list cannot be loaded.
  Future<List<AirStation>> lodzStations() async {
    final list = await (_stations ??= _loadStations());
    final stations = list.stations.where((s) => isLodz(s.city)).toList();
    final indexes = <GiosIndex?>[];
    final withIndex = stations.take(maxIndexCalls).toList();
    for (var i = 0; i < withIndex.length; i += concurrency) {
      indexes.addAll(
        await Future.wait([
          for (final s in withIndex.skip(i).take(concurrency))
            _index(s.id, list.v0),
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

  Future<_StationList> _loadStations() async {
    try {
      return _StationList(
        parseGiosStations(await getJson(_dio, stationsUrlV1)),
        v0: false,
      );
    } on ApiException catch (e) {
      // v0 would be just as unreachable.
      if (e.kind == ApiErrorKind.timeout || e.kind == ApiErrorKind.network) {
        _stations = null;
        rethrow;
      }
      try {
        return _StationList(
          parseGiosStations(await getJson(_dio, stationsUrlV0)),
          v0: true,
        );
      } on ApiException {
        _stations = null;
        throw e;
      }
    }
  }

  Future<GiosIndex?> _index(String stationId, bool v0) async {
    try {
      final url = v0 ? indexUrlV0(stationId) : indexUrlV1(stationId);
      return parseGiosIndex(await getJson(_dio, url));
    } on ApiException {
      return null;
    }
  }
}

class _StationList {
  const _StationList(this.stations, {required this.v0});

  final List<GiosStation> stations;
  final bool v0;
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

/// Station list, v1 (`{"Lista stacji pomiarowych": [{"Identyfikator stacji":
/// …}]}`) or v0 (`[{"id": …, "gegrLat": …, "city": {"name": …}}]`).
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
        findValue(item, (k) => k.startsWith('identyfikator stacji')) ??
        item['id'],
  );
  final name = asText(
    item['Nazwa stacji'] ??
        findValue(item, (k) => k == 'nazwa stacji') ??
        item['stationName'],
  );
  final lat = parseNum(
    item['WGS84 φ N'] ??
        findValue(item, (k) => k.contains('wgs84') && _isLatKey(k)) ??
        item['gegrLat'],
  );
  final lon = parseNum(
    item['WGS84 λ E'] ??
        findValue(item, (k) => k.contains('wgs84') && _isLonKey(k)) ??
        item['gegrLon'],
  );
  final cityV0 = item['city'];
  final city = asText(
    item['Nazwa miasta'] ??
        findValue(item, (k) => k.contains('miasta')) ??
        (cityV0 is Map ? cityV0['name'] : cityV0),
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

/// Overall station index, v1 (`{"AqIndex": {"Wartość indeksu": 1, …}}`) or
/// v0 (`{"stIndexLevel": {"id": 1}, "stCalcDate": …}`). Missing or `-1`
/// index → `level: null`. Throws [ApiException] (server) when [json] is
/// not an object.
GiosIndex parseGiosIndex(Object? json) {
  if (json is! Map<Object?, Object?>) {
    throw ApiException(ApiErrorKind.server, 'bad GIOŚ index: $json');
  }
  final inner = findValue(json, (k) => k == 'aqindex');
  final map = inner is Map<Object?, Object?> ? inner : json;

  // v1 also has per-pollutant keys ("… dla wskaźnika PM10"): skip them.
  bool overall(String k) => !k.contains('wskaznik');
  final status = findValue(
    map,
    (k) => k.startsWith('status indeksu') && overall(k),
  );
  final v0Level = map['stIndexLevel'];
  int? level =
      parseInt(
        findValue(map, (k) => k == 'wartosc indeksu') ??
            findValue(
              map,
              (k) => k.startsWith('wartosc indeksu') && overall(k),
            ),
      ) ??
      parseInt(v0Level is Map ? v0Level['id'] : null);
  final category = asText(
    findValue(map, (k) => k.startsWith('nazwa kategorii') && overall(k)) ??
        (v0Level is Map ? v0Level['indexLevelName'] : null),
  );
  if (level == null && category != null) {
    level = _categories[normalizeKey(category)];
  }
  if (level != null && (level < 0 || level > 5)) level = null;
  if (status == false || map['stIndexStatus'] == false) level = null;

  final updatedAt = parseWarsawTime(
    findValue(
          map,
          (k) => k.startsWith('data wykonania obliczen') && overall(k),
        ) ??
        map['stCalcDate'],
  );
  return GiosIndex(level: level, updatedAt: updatedAt?.toLocal());
}
