import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/geo.dart';

/// Address search for S06 (decision Q-04, #41): Nominatim (OSM), only
/// inside Łódź, with the app's User-Agent and at most 1 request per second
/// (Nominatim usage policy). The UI also debounces typing.
abstract interface class AddressSearch {
  /// Up to 8 results; an empty list when nothing matches. Throws on network
  /// errors.
  Future<List<RoutePoint>> search(String query);
}

class NominatimAddressSearch implements AddressSearch {
  NominatimAddressSearch(this._dio, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  factory NominatimAddressSearch.create() => NominatimAddressSearch(
    Dio(
      BaseOptions(
        baseUrl: 'https://nominatim.openstreetmap.org',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'User-Agent': userAgent},
      ),
    ),
  );

  static const userAgent =
      'CoolLodz/1.0 (Android; pl.betterthannever.cool_lodz; '
      'Hackathon Future Smart City 2026)';

  /// Łódź city limits, `minLon,maxLat,maxLon,minLat` as Nominatim wants.
  static const viewbox = '19.32,51.86,19.64,51.68';
  static const minInterval = Duration(seconds: 1);

  final Dio _dio;
  final DateTime Function() _clock;
  DateTime? _last;

  @override
  Future<List<RoutePoint>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    // Reserve this request's slot before waiting, so two searches waiting
    // at the same time still go out at least 1 s apart.
    final now = _clock();
    final last = _last;
    var start = now;
    if (last != null && now.difference(last) < minInterval) {
      start = last.add(minInterval);
    }
    _last = start;
    final wait = start.difference(now);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    final response = await _dio.get<List<dynamic>>(
      '/search',
      queryParameters: {
        'q': q,
        'format': 'jsonv2',
        'viewbox': viewbox,
        'bounded': 1,
        'countrycodes': 'pl',
        'addressdetails': 1,
        'limit': 8,
        'accept-language': 'pl',
      },
    );
    return [for (final item in response.data ?? const []) ?_parse(item)];
  }

  static RoutePoint? _parse(Object? item) {
    if (item is! Map) return null;
    final lat = double.tryParse('${item['lat']}');
    final lon = double.tryParse('${item['lon']}');
    if (lat == null || lon == null) return null;
    return RoutePoint(lat: lat, lon: lon, label: label(item));
  }

  /// «Piotrkowska 104» or the place name, without country and postcode.
  @visibleForTesting
  static String label(Map<dynamic, dynamic> item) {
    final address = item['address'];
    if (address is Map) {
      final road = address['road'] ?? address['pedestrian'];
      final number = address['house_number'];
      final name = item['name'];
      if (name is String && name.isNotEmpty && name != road) {
        return road == null ? name : '$name, $road${_suffix(number)}';
      }
      if (road != null) return '$road${_suffix(number)}';
    }
    final display = '${item['display_name'] ?? ''}';
    return display.split(',').take(2).map((s) => s.trim()).join(', ');
  }

  static String _suffix(Object? number) => number == null ? '' : ' $number';
}

final addressSearchProvider = Provider<AddressSearch>(
  (ref) => NominatimAddressSearch.create(),
);
