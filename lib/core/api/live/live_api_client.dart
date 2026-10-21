import '../../models/models.dart';
import '../api_client.dart';
import '../demo_api_client.dart';
import 'gios_air.dart';
import 'imgw_alerts.dart';
import 'live_route_engine.dart';
import 'osrm_client.dart';
import 'shade_layer.dart';
import 'shade_model.dart';
import 'weather.dart';

/// Module D on the phone, while it has no server: routes from
/// [LiveRouteEngine] (OSRM + shade model), heat warnings from IMGW-PIB, air
/// quality from GIOŚ; the shade layer is drawn for the asked time
/// ([ShadeLayerBuilder]); places, the other layers and the quest come from
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
  Future<ShadeLayerBuilder>? _shadeLayer;
  final _shadeLayers = <String, GeoLayer>{};

  /// Built once from the bundled layers; a failed load is retried next time.
  Future<ShadeModel> _shadeModel() => _model ??= () async {
    try {
      final layers = await Future.wait([
        bundled.getLayer(LayerKind.shade, datetime: _clock()),
        bundled.getLayer(LayerKind.green, datetime: _clock()),
      ]);
      return ShadeModel.fromLayers(shade: layers[0], green: layers[1]);
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

  /// Shade for [datetime] (trees, building shadows and sunny street parts at
  /// that time and weather); green and noise are the bundled files.
  @override
  Future<GeoLayer> getLayer(
    LayerKind kind, {
    GeoBounds? bbox,
    required DateTime datetime,
  }) async {
    if (kind != LayerKind.shade) {
      return bundled.getLayer(kind, bbox: bbox, datetime: datetime);
    }
    final builder = await _shadeBuilder();
    WeatherForecast? forecast;
    try {
      forecast = await weather?.forecastOrNull().timeout(
        LiveRouteEngine.weatherTimeout,
      );
    } catch (_) {
      // Slow: a clear sky.
    }
    final strength = sunStrength(forecast, datetime);
    // One layer per minute and sun strength is plenty; keep the last few.
    final key =
        '${datetime.toUtc().millisecondsSinceEpoch ~/ 60000}:'
        '${(strength * 100).round()}';
    final cached = _shadeLayers[key];
    if (cached != null) return cached;
    if (_shadeLayers.length >= 8) _shadeLayers.remove(_shadeLayers.keys.first);
    return _shadeLayers[key] = builder.at(datetime, strength: strength);
  }

  Future<ShadeLayerBuilder> _shadeBuilder() => _shadeLayer ??= () async {
    try {
      final results = await Future.wait<Object?>([
        bundled.getLayer(LayerKind.shade, datetime: _clock()),
        bundled.readJson('streets_core.geojson'),
        _shadeModel(),
      ]);
      return ShadeLayerBuilder(
        bundledShade: results[0]! as GeoLayer,
        streets: parseStreets(results[1]),
        model: results[2]! as ShadeModel,
      );
    } catch (_) {
      _shadeLayer = null;
      rethrow;
    }
  }();

  @override
  Future<List<QuestPlace>> getQuestPlaces() => bundled.getQuestPlaces();
}
