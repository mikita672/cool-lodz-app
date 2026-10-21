import '../../models/models.dart';
import '../api_client.dart';
import '../demo_api_client.dart';
import 'gios_air.dart';
import 'imgw_alerts.dart';
import 'live_route_engine.dart';
import 'osrm_client.dart';
import 'shade_model.dart';
import 'shadows.dart';
import 'sun.dart';
import 'weather.dart';

/// Module D on the phone, while it has no server: routes from
/// [LiveRouteEngine] (OSRM + shade model), heat warnings from IMGW-PIB, air
/// quality from GIOŚ; the shade layer is the real shadows of buildings and
/// trees at the asked time ([shadeLayerAt]); places, the other layers and
/// the quest come from
/// the bundled files, as in [DemoApiClient].
class LiveApiClient implements ApiClient {
  LiveApiClient({
    required this.bundled,
    required this.imgw,
    required this.gios,
    required OsrmClient osrm,
    this.weather,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    routes = LiveRouteEngine(
      osrm: osrm,
      shadeModel: _shadeModel,
      places: () => bundled.getPlaces(types: {PlaceType.cool, PlaceType.water}),
      weather: weather?.forecastOrNull,
    );
  }

  factory LiveApiClient.create(
    DemoApiClient bundled, {
    OpenMeteoClient? weather,
  }) => LiveApiClient(
    bundled: bundled,
    imgw: ImgwAlertsClient.create(),
    gios: GiosAirClient.create(),
    osrm: OsrmClient.create(),
    weather: weather ?? OpenMeteoClient.create(),
  );

  final DemoApiClient bundled;
  final ImgwAlertsClient imgw;
  final GiosAirClient gios;

  /// Clouds for the sun strength; null = always a clear sky.
  final OpenMeteoClient? weather;
  late final LiveRouteEngine routes;
  final DateTime Function() _clock;

  Future<ShadeModel>? _model;
  final _shadeLayers = <String, GeoLayer>{};

  /// Built once from the bundled files (shade, green, the buildings and
  /// trees); a failed load is retried next time.
  Future<ShadeModel> _shadeModel() => _model ??= () async {
    try {
      final results = await Future.wait<Object?>([
        bundled.getLayer(LayerKind.shade, datetime: _clock()),
        bundled.getLayer(LayerKind.green, datetime: _clock()),
        bundled.readJson('shadow_casters.json'),
      ]);
      return ShadeModel.fromLayers(
        shade: results[0]! as GeoLayer,
        green: results[1]! as GeoLayer,
        casters: ShadowCasters.fromJson(results[2]),
      );
    } catch (_) {
      _model = null;
      rethrow;
    }
  }();

  @override
  Future<RouteResponse> getRoutes(RouteRequest request) =>
      routes.route(request);

  @override
  Future<List<Place>> getPlaces({
    required Set<PlaceType> types,
    GeoBounds? bbox,
  }) => bundled.getPlaces(types: types, bbox: bbox);

  /// Heat warnings for Łódź (the app's only city): [lat]/[lon] are ignored.
  @override
  Future<List<Alert>> getAlerts({required double lat, required double lon}) =>
      imgw.heatAlerts(now: _clock());

  @override
  Future<List<AirStation>> getAir({GeoBounds? bbox}) async => [
    for (final s in await gios.lodzStations())
      if (bbox == null || bbox.contains(s.lat, s.lon)) s,
  ];

  /// Shade for [datetime] inside [bbox]: the shadows the buildings and
  /// trees cast at that moment (paler under clouds, none at night) and the
  /// parks; green and noise are the bundled files.
  @override
  Future<GeoLayer> getLayer(
    LayerKind kind, {
    GeoBounds? bbox,
    required DateTime datetime,
  }) async {
    if (kind != LayerKind.shade) {
      return bundled.getLayer(kind, bbox: bbox, datetime: datetime);
    }
    final model = await _shadeModel();
    WeatherForecast? forecast;
    try {
      forecast = await weather?.forecastOrNull().timeout(
        LiveRouteEngine.weatherTimeout,
      );
    } catch (_) {
      // Slow: a clear sky.
    }
    final strength = sunStrength(forecast, datetime);
    final key =
        '${datetime.toUtc().millisecondsSinceEpoch ~/ 60000}:'
        '${(strength * 100).round()}:${bbox?.toQuery()}';
    final cached = _shadeLayers[key];
    if (cached != null) return cached;
    if (_shadeLayers.length >= 6) _shadeLayers.remove(_shadeLayers.keys.first);
    return _shadeLayers[key] = shadeLayerAt(
      model,
      datetime,
      bbox: bbox,
      strength: strength,
    );
  }

  @override
  Future<List<QuestPlace>> getQuestPlaces() => bundled.getQuestPlaces();
}

/// The map's shade at [time]: the parks (light, they are shady all day) and,
/// while the sun is up and strong enough, the shadows of buildings and tree
/// crowns inside [bbox] (`{"source": "shadow"}`), as dark as the sun is
/// strong.
GeoLayer shadeLayerAt(
  ShadeModel model,
  DateTime time, {
  GeoBounds? bbox,
  double strength = 1,
}) {
  final casters = model.casters;
  final sun = sunPosition(51.77, 19.46, time);
  final shade = 0.9 * strength.clamp(0.0, 1.0);
  return GeoLayer(
    features: [
      for (final f in model.parkFeatures)
        GeoFeature(
          geometry: f.geometry,
          properties: const {'shade': 0.45, 'source': 'park'},
        ),
      if (casters != null && sun.elevation > 0 && shade >= 0.05)
        ...casters.shadows(sun, bounds: bbox, shade: shade),
    ],
  );
}
