import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'preferences.dart';

/// The last route and the cool places list, kept for use without network
/// (НФТ «Офлайн»). Written after successful remote calls.
class OfflineCache {
  OfflineCache(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const lastRouteKey = 'cache.lastRoute';
  static const coolPlacesKey = 'cache.coolPlaces';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  Future<void> saveLastRoute(RouteRequest request, RouteResponse response) =>
      _prefs.setString(
        lastRouteKey,
        jsonEncode({
          'savedAt': formatOffsetDateTime(_clock()),
          'request': request.toJson(),
          'response': response.toJson(),
        }),
      );

  /// Null when nothing is saved or the saved data cannot be read.
  CachedRoute? lastRoute() => _read(lastRouteKey, (json) {
    return CachedRoute(
      request: RouteRequest.fromJson(json['request'] as Map<String, dynamic>),
      response: RouteResponse.fromJson(
        json['response'] as Map<String, dynamic>,
      ),
      savedAt: const OffsetDateTimeConverter().fromJson(
        json['savedAt'] as String,
      ),
    );
  });

  /// Merges [places] (cool ones only) into the saved list by id.
  Future<void> saveCoolPlaces(Iterable<Place> places) {
    final merged = {
      for (final p in coolPlaces() ?? const <Place>[]) p.id: p,
      for (final p in places)
        if (p.type == PlaceType.cool) p.id: p,
    };
    return _prefs.setString(
      coolPlacesKey,
      jsonEncode({
        'savedAt': formatOffsetDateTime(_clock()),
        'places': [for (final p in merged.values) p.toJson()],
      }),
    );
  }

  List<Place>? coolPlaces() =>
      _read(coolPlacesKey, (json) => PlacesResponse.fromJson(json).places);

  T? _read<T>(String key, T Function(Map<String, dynamic> json) parse) {
    final text = _prefs.getString(key);
    if (text == null) return null;
    try {
      return parse(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return null; // Old or broken format: behave as if empty.
    }
  }
}

class CachedRoute {
  const CachedRoute({
    required this.request,
    required this.response,
    required this.savedAt,
  });

  final RouteRequest request;
  final RouteResponse response;
  final DateTime savedAt;
}

final offlineCacheProvider = Provider<OfflineCache>(
  (ref) => OfflineCache(ref.watch(sharedPreferencesProvider)),
);
