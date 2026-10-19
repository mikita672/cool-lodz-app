import 'package:cool_lodz/features/route/data/address_search.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_dio.dart';

const _result = '''
[
  {"lat": "51.7581", "lon": "19.4573", "name": "", "display_name": "104, Piotrkowska, Śródmieście, Łódź, 90-001, Polska",
   "address": {"house_number": "104", "road": "Piotrkowska", "city": "Łódź"}},
  {"lat": "51.7794", "lon": "19.4466", "name": "Manufaktura", "display_name": "Manufaktura, Drewnowska, Łódź",
   "address": {"road": "Drewnowska", "house_number": "58"}},
  {"lat": "x", "lon": "19.4"}
]
''';

void main() {
  late FakeAdapter adapter;
  late NominatimAddressSearch search;
  var now = DateTime(2026, 7, 15, 12);

  setUp(() {
    adapter = FakeAdapter((_) => jsonBody(_result));
    now = DateTime(2026, 7, 15, 12);
    search = NominatimAddressSearch(
      Dio(
        BaseOptions(
          baseUrl: 'https://nominatim.test',
          headers: {'User-Agent': NominatimAddressSearch.userAgent},
        ),
      )..httpClientAdapter = adapter,
      clock: () => now,
    );
  });

  test('asks only inside Łódź, in Polish, with the app User-Agent', () async {
    await search.search('Piotrkowska 104');
    final request = adapter.requests.single;
    expect(request.path, '/search');
    expect(request.queryParameters['q'], 'Piotrkowska 104');
    expect(request.queryParameters['viewbox'], NominatimAddressSearch.viewbox);
    expect(request.queryParameters['bounded'], 1);
    expect(request.queryParameters['accept-language'], 'pl');
    expect(request.headers['User-Agent'], contains('CoolLodz'));
  });

  test('parses results into short labels and skips broken ones', () async {
    final results = await search.search('Piotrkowska');
    expect(results, hasLength(2));
    expect(results[0].label, 'Piotrkowska 104');
    expect(results[0].lat, 51.7581);
    expect(results[1].label, 'Manufaktura, Drewnowska 58');
  });

  test('short queries do not reach the network', () async {
    expect(await search.search('Pi'), isEmpty);
    expect(adapter.requests, isEmpty);
  });

  test('at most one request per second', () async {
    await search.search('Piotrkowska');
    final started = DateTime.now();
    now = now.add(const Duration(milliseconds: 700));
    await search.search('Piotrkowska 1');
    // Waited the remaining ~300 ms.
    expect(
      DateTime.now().difference(started),
      greaterThanOrEqualTo(const Duration(milliseconds: 250)),
    );
    expect(adapter.requests, hasLength(2));
  });

  test('label falls back to the first two parts of display_name', () {
    expect(
      NominatimAddressSearch.label({
        'display_name': 'Park Źródliska, Śródmieście, Łódź, Polska',
      }),
      'Park Źródliska, Śródmieście',
    );
  });
}
