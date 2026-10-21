import 'dart:async';
import 'dart:io';

import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/api_providers.dart';
import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/firestore/collections.dart';
import 'package:cool_lodz/core/game/game_config.dart';
import 'package:cool_lodz/core/game/game_rules.dart';
import 'package:cool_lodz/core/location/location_service.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/core/storage/preferences.dart';
import 'package:cool_lodz/features/alerts/data/push_service.dart';
import 'package:cool_lodz/features/auth/data/auth_repository.dart';
import 'package:cool_lodz/features/auth/data/user_profile_repository.dart';
import 'package:cool_lodz/features/game/data/game_config_repository.dart';
import 'package:cool_lodz/features/game/data/game_repository.dart';
import 'package:cool_lodz/features/leaderboard/data/ranking_repository.dart';
import 'package:cool_lodz/features/quest/data/quest_repository.dart';
import 'package:cool_lodz/features/quest/quest_scan_screen.dart';
import 'package:cool_lodz/features/reports/data/report_repository.dart';
import 'package:cool_lodz/features/route/data/address_search.dart';
import 'package:cool_lodz/features/route/data/route_history_repository.dart';
import 'package:cool_lodz/features/settings/data/account_repository.dart';
import 'package:cool_lodz/shared/map/base_map.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/fakes.dart';

/// Reads `assets/demo/…` from disk synchronously. `rootBundle` decodes big
/// files in an isolate that widget tests do not wait for.
Future<String> readAssetFile(String path) async =>
    File(path).readAsStringSync();

/// Location with a fixed answer; [problem] makes it unavailable.
class FakeLocationService implements LocationService {
  FakeLocationService({this.position = const LatLng(51.7700, 19.4570)});

  LatLng position;
  LocationProblem? problem;
  var enableCalls = 0;
  var currentCalls = 0;

  @override
  Future<LocationProblem?> check() async => problem;

  @override
  Future<LatLng> current() async {
    currentCalls++;
    final p = problem;
    if (p != null) throw LocationUnavailable(p);
    return position;
  }

  @override
  Future<void> enable() async {
    enableCalls++;
    problem = null;
  }
}

/// The demo client (real `assets/demo/` files) that records route requests.
/// [routeError] makes `getRoutes` throw.
class RecordingApiClient implements ApiClient {
  RecordingApiClient({DemoApiClient? demo})
    : _demo = demo ?? DemoApiClient(loadAsset: readAssetFile);

  final DemoApiClient _demo;
  final routeRequests = <RouteRequest>[];
  final placeRequests = <Set<PlaceType>>[];
  Object? routeError;

  @override
  Future<RouteResponse> getRoutes(RouteRequest request) async {
    routeRequests.add(request);
    final e = routeError;
    if (e != null) throw e;
    return _demo.getRoutes(request);
  }

  @override
  Future<List<Place>> getPlaces({
    required Set<PlaceType> types,
    GeoBounds? bbox,
  }) {
    placeRequests.add(types);
    return _demo.getPlaces(types: types, bbox: bbox);
  }

  @override
  Future<List<Alert>> getAlerts({required double lat, required double lon}) =>
      _demo.getAlerts(lat: lat, lon: lon);

  @override
  Future<List<AirStation>> getAir({GeoBounds? bbox}) =>
      _demo.getAir(bbox: bbox);

  @override
  Future<GeoLayer> getLayer(
    LayerKind kind, {
    GeoBounds? bbox,
    required DateTime datetime,
  }) => _demo.getLayer(kind, bbox: bbox, datetime: datetime);

  @override
  Future<List<QuestPlace>> getQuestPlaces() => _demo.getQuestPlaces();
}

class FakeAddressSearch implements AddressSearch {
  final queries = <String>[];
  List<RoutePoint> results = const [];
  Object? error;

  @override
  Future<List<RoutePoint>> search(String query) async {
    queries.add(query);
    final e = error;
    if (e != null) throw e;
    return results;
  }
}

/// Overrides every app-level dependency that would reach the network or a
/// platform plugin: preferences, module D (demo files), location, tiles.
List<Override> appTestOverrides({
  required SharedPreferences prefs,
  ApiClient? api,
  LocationService? location,
  GameSettings? settings,
  GameRepository? game,
  AuthRepository? auth,
  QuestRepository? quest,
  FakeQrScanner? scanner,
  RankingRepository? ranking,
  UserProfileRepository? profiles,
  PushService? push,
  AccountRepository? account,
  ReportRepository? reports,
}) => [
  reportRepositoryProvider.overrideWithValue(reports ?? FakeReportRepository()),
  accountRepositoryProvider.overrideWithValue(
    account ?? FakeAccountRepository(),
  ),
  userProfileRepositoryProvider.overrideWithValue(
    profiles ?? FakeUserProfileRepository(),
  ),
  pushServiceProvider.overrideWithValue(push ?? FakePushService()),
  rankingRepositoryProvider.overrideWithValue(
    ranking ?? FakeRankingRepository(),
  ),
  questRepositoryProvider.overrideWithValue(quest ?? FakeQuestRepository()),
  qrScannerBuilderProvider.overrideWithValue(
    (scanner ?? FakeQrScanner()).build,
  ),
  assetLoaderProvider.overrideWithValue(readAssetFile),
  authRepositoryProvider.overrideWithValue(
    auth ?? FakeAuthRepository(user: const AppUser(uid: 'u1')),
  ),
  sharedPreferencesProvider.overrideWithValue(prefs),
  apiClientProvider.overrideWithValue(api ?? RecordingApiClient()),
  locationServiceProvider.overrideWithValue(location ?? FakeLocationService()),
  mapTilesEnabledProvider.overrideWithValue(false),
  gameSettingsProvider.overrideWith(
    (ref) => Stream.value(settings ?? const GameSettings()),
  ),
  gameRepositoryProvider.overrideWithValue(game ?? FakeGameRepository()),
];

/// In-memory game storage with the same limits as the rules (≤ 200 per
/// write). [writes] records the point sum of every batch.
class FakeGameRepository implements GameRepository {
  FakeGameRepository({PlayerState? player})
    : state = player ?? const PlayerState(nickname: 'Ala');

  PlayerState state;
  final routes = <(String, StartedRoute)>[];
  final log = <PointsEntry>[];
  final writes = <int>[];
  int approvedReports = 0;
  final approvedReportIds = <String>{};
  final _players = StreamController<PlayerState>.broadcast();
  final _logs = StreamController<List<PointsEntry>>.broadcast();

  @override
  Future<PlayerState> player(String uid) async => state;

  @override
  Future<GameHistory> history(String uid) async => GameHistory(
    routes: [
      for (final (_, r) in routes)
        RouteRecord(
          departAt: r.departAt,
          shadeShare: r.shadeShare,
          endPlaceType: r.endPlaceType,
          distanceM: r.distanceM,
          durationS: r.durationS,
          shortestSunShare: r.shortestSunShare,
          waterStops: r.waterStops ?? 0,
        ),
    ],
    log: List.of(log),
    badges: state.badges,
    approvedReports: approvedReports + approvedReportIds.length,
    approvedReportIds: Set.of(approvedReportIds),
  );

  @override
  Future<void> addRoute(String uid, StartedRoute route) async =>
      routes.add((uid, route));

  @override
  Future<void> award(
    String uid,
    List<PointsEntry> entries, {
    required DateTime now,
  }) async {
    for (final chunk in GameRules.chunk(entries)) {
      final sum = chunk.fold(0, (a, e) => a + e.points);
      if (sum > GameConfig.maxPointsPerWrite) throw StateError('rules: > 200');
      writes.add(sum);
      final week = weekId(now);
      state = PlayerState(
        nickname: state.nickname,
        district: state.district,
        rankingConsent: state.rankingConsent,
        points: state.points + sum,
        weekId: week,
        weekPoints: state.weekPointsIn(week) + sum,
        badges: {...state.badges, ...badgesIn(chunk)},
      );
      log.addAll([
        for (final e in chunk)
          PointsEntry(type: e.type, points: e.points, refId: e.refId, at: now),
      ]);
    }
    _players.add(state);
    _logs.add(log.reversed.take(10).toList());
  }

  @override
  Stream<PlayerState> watchPlayer(String uid) async* {
    yield state;
    yield* _players.stream;
  }

  @override
  Stream<List<PointsEntry>> watchLog(String uid, {int limit = 10}) async* {
    yield log.reversed.take(limit).toList();
    yield* _logs.stream;
  }
}

/// Visits like the rules: right code, one per place and day.
class FakeQuestRepository implements QuestRepository {
  FakeQuestRepository({Map<String, String>? codes})
    : codes = codes ?? {'cool-002': 'K7M2QX', 'cool-007': 'H4P9TA'};

  /// placeId → valid code (`questCodes`).
  final Map<String, String> codes;
  final visits = <String>{};
  final _changes = StreamController<Set<String>>.broadcast();

  @override
  Stream<Set<String>> watchVisits(String uid) async* {
    yield Set.of(visits);
    yield* _changes.stream;
  }

  @override
  Future<void> addVisit({
    required String uid,
    required String placeId,
    required String code,
    required double lat,
    required double lon,
    required DateTime now,
  }) async {
    final id = visitId(uid, placeId, now);
    if (codes[placeId] != code || visits.contains(id)) {
      throw const VisitRejected();
    }
    visits.add(id);
    _changes.add(Set.of(visits));
  }
}

/// Stand-in for the camera: tests call [scan] with a QR text.
class FakeQrScanner {
  ValueChanged<String>? _onCode;
  bool permissionDenied = false;

  void scan(String raw) => _onCode?.call(raw);

  Widget build(
    BuildContext context,
    ValueChanged<String> onCode,
    WidgetBuilder noPermission,
  ) {
    _onCode = onCode;
    if (permissionDenied) return noPermission(context);
    return const ColoredBox(key: Key('fake-camera'), color: Color(0xFF000000));
  }
}

/// Rankings from fixed lists.
class FakeRankingRepository implements RankingRepository {
  List<RankingEntry> summerUsers = const [];
  List<RankingEntry> weekUsers = const [];
  Map<String, int> summerDistricts = const {};
  Map<String, int> weekDistricts = const {};

  @override
  Future<List<RankingEntry>> users(RankingPeriod period, String weekId) async =>
      period == RankingPeriod.week ? weekUsers : summerUsers;

  @override
  Future<int> userRank(RankingPeriod period, String weekId, int points) async =>
      (period == RankingPeriod.week ? weekUsers : summerUsers)
          .where((e) => e.points > points)
          .length +
      1;

  @override
  Future<List<RankingEntry>> districts(
    RankingPeriod period,
    String weekId,
  ) async {
    final source = period == RankingPeriod.week
        ? weekDistricts
        : summerDistricts;
    return [
      for (final id in FirestoreDistricts.ids)
        RankingEntry(id: id, name: districtName(id), points: source[id] ?? 0),
    ]..sort((a, b) => b.points.compareTo(a.points));
  }
}

/// Push with controllable streams.
class FakePushService implements PushService {
  String? tokenValue = 'fcm-token-1';
  PushMessage? initialMessage;
  final refresh = StreamController<String>.broadcast();
  final foregroundMessages = StreamController<PushMessage>.broadcast();
  final openedMessages = StreamController<PushMessage>.broadcast();

  @override
  Future<String?> token() async => tokenValue;

  @override
  Stream<String> get tokenRefresh => refresh.stream;

  @override
  Stream<PushMessage> get foreground => foregroundMessages.stream;

  @override
  Stream<PushMessage> get opened => openedMessages.stream;

  @override
  Future<PushMessage?> initial() async => initialMessage;

  int deletedTokens = 0;

  @override
  Future<void> deleteToken() async {
    deletedTokens++;
    tokenValue = null;
  }
}

/// Records S16 account changes.
class FakeAccountRepository implements AccountRepository {
  final districts = <(String, String)>[];
  final consents = <(String, Consents)>[];
  final deletedData = <String>[];
  Object? error;

  @override
  Future<void> setDistrict(String uid, String district) async {
    if (error != null) throw error!;
    districts.add((uid, district));
  }

  @override
  Future<void> setConsents(String uid, Consents value) async {
    if (error != null) throw error!;
    consents.add((uid, value));
  }

  @override
  Future<void> deleteUserData(String uid) async => deletedData.add(uid);
}

/// Records reports instead of writing to Firestore.
class FakeReportRepository implements ReportRepository {
  final created =
      <({ReportType type, double lat, double lon, String? comment})>[];
  Object? error;

  var _ids = 0;

  @override
  String newId() => 'report-${++_ids}';

  @override
  Future<void> create({
    required String id,
    required String uid,
    required ReportType type,
    required double lat,
    required double lon,
    String? comment,
  }) async {
    if (error != null) throw error!;
    created.add((type: type, lat: lat, lon: lon, comment: comment));
  }
}
