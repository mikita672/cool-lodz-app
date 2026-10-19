import '../../models/models.dart';
import '../api_client.dart';
import '../demo_api_client.dart';
import 'gios_air.dart';
import 'imgw_alerts.dart';
import 'live_route_engine.dart';
import 'osrm_client.dart';
import 'shade_model.dart';

/// Module D on the phone, while it has no server: routes from
/// [LiveRouteEngine] (OSRM + shade model), heat warnings from IMGW-PIB, air
/// quality from GIOŚ; places, map layers and the quest come from the bundled
/// files, as in [DemoApiClient].
class LiveApiClient implements ApiClient {
  LiveApiClient({
    required this.bundled,
    required this.imgw,
    required this.gios,
    required OsrmClient osrm,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    routes = LiveRouteEngine(
      osrm: osrm,
      shadeModel: _shadeModel,
      places: () => bundled.getPlaces(types: {PlaceType.cool, PlaceType.water}),
    );
  }

  factory LiveApiClient.create(DemoApiClient bundled) => LiveApiClient(
    bundled: bundled,
    imgw: ImgwAlertsClient.create(),
    gios: GiosAirClient.create(),
    osrm: OsrmClient.create(),
  );

  final DemoApiClient bundled;
  final ImgwAlertsClient imgw;
  final GiosAirClient gios;
  late final LiveRouteEngine routes;
  final DateTime Function() _clock;

  Future<ShadeModel>? _model;

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

  /// The bundled layers (the shade one is for 14:30).
  @override
  Future<GeoLayer> getLayer(
    LayerKind kind, {
    GeoBounds? bbox,
    required DateTime datetime,
  }) => bundled.getLayer(kind, bbox: bbox, datetime: datetime);

  @override
  Future<List<QuestPlace>> getQuestPlaces() => bundled.getQuestPlaces();
}
