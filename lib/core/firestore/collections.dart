/// Firestore collection and field names (spec "Data"). The access rules
/// live in `firestore.rules`; keep both in sync.
library;

abstract final class FirestoreCollections {
  static const users = 'users';
  static const pointsLog = 'pointsLog'; // users/{uid}/pointsLog
  static const routes = 'routes'; // users/{uid}/routes
  static const visits = 'visits';
  static const questPlaces = 'questPlaces';
  static const questCodes = 'questCodes'; // read only by the rules
  static const districts = 'districts';
  static const weeks = 'weeks'; // districts/{id}/weeks/{yyyy-Www}
  static const reports = 'reports';
  static const config = 'config';
  static const rankings = 'rankings'; // public copy for S13, see RankingFields

  /// Document id of the game config: `config/game`.
  static const gameConfigDoc = 'game';
}

/// Fields of `users/{uid}`.
abstract final class UserFields {
  static const nickname = 'nickname'; // 2–24 characters
  static const district = 'district'; // a FirestoreDistricts id
  static const profile = 'profile'; // {id, weights, seniorMode}
  static const profileId = 'id';
  static const profileWeights = 'weights';
  static const profileSeniorMode = 'seniorMode';
  static const consents = 'consents'; // {location, push, ranking, acceptedAt}
  static const consentLocation = 'location';
  static const consentPush = 'push';
  static const consentRanking = 'ranking';
  static const consentAcceptedAt = 'acceptedAt';
  static const points = 'points'; // never down, ≤ +200 per write
  static const weekId = 'weekId'; // see weekId()
  static const weekPoints = 'weekPoints'; // reset when weekId changes
  static const badges = 'badges'; // only grows
  static const fcmToken = 'fcmToken';
  static const createdAt = 'createdAt';
}

/// Fields of `rankings/{uid}`: the public part of `users/{uid}` for the user
/// ranking (S13). Exactly these fields. The owner writes it in the same
/// batch as the user document and only while `consents.ranking` is true;
/// the values must equal the user document after the batch. Withdrawing the
/// consent must delete it in the same batch. `users/{uid}` stays private.
/// All-time: `orderBy(points, desc).limit(50)`; this week:
/// `where(weekId == weekId(now)).orderBy(weekPoints, desc).limit(50)`.
abstract final class RankingFields {
  static const nickname = 'nickname';
  static const district = 'district';
  static const points = 'points';
  static const weekId = 'weekId';
  static const weekPoints = 'weekPoints';
  static const updatedAt = 'updatedAt'; // FieldValue.serverTimestamp()
}

/// Fields of `users/{uid}/pointsLog/{id}` (create only, points 1..200,
/// `createdAt` must be the server timestamp).
abstract final class PointsLogFields {
  static const type = 'type';
  static const points = 'points';
  static const refId = 'refId';
  static const createdAt = 'createdAt';
}

/// Fields of `users/{uid}/routes/{id}`.
abstract final class RouteFields {
  static const from = 'from';
  static const to = 'to';
  static const departAt = 'departAt';
  static const variant = 'variant';
  static const sunShare = 'sunShare';
  static const distanceM = 'distance_m';
  static const endPlaceType = 'endPlaceType';
  static const createdAt = 'createdAt';

  // «Twój wpływ» (optional, routes saved before 22.10.2026 lack them).
  static const durationS = 'duration_s';
  static const shortestSunShare = 'shortestSunShare';
  static const waterStops = 'waterStops';
}

/// Fields of `visits/{visitId}` (see visitId()). `createdAt` must be the
/// server timestamp.
abstract final class VisitFields {
  static const uid = 'uid';
  static const placeId = 'placeId';
  static const code = 'code';
  static const lat = 'lat';
  static const lon = 'lon';
  static const createdAt = 'createdAt';
}

/// Fields of `questPlaces/{placeId}`.
abstract final class QuestPlaceFields {
  static const name = 'name';
  static const letter = 'letter';
  static const order = 'order';
  static const lat = 'lat';
  static const lon = 'lon';
}

/// Fields of `districts/{id}` and `districts/{id}/weeks/{weekId}`.
abstract final class DistrictFields {
  static const name = 'name';
  static const points = 'points'; // clients may only add 1..200
}

/// District document ids. Names (for display) are `GameConfig.districts`,
/// in the same order.
abstract final class FirestoreDistricts {
  static const ids = ['baluty', 'gorna', 'polesie', 'srodmiescie', 'widzew'];
}

/// Fields and values of `reports/{id}`.
abstract final class ReportFields {
  static const uid = 'uid';
  static const type = 'type';
  static const lat = 'lat';
  static const lon = 'lon';
  static const comment = 'comment'; // ≤ 200 characters
  static const status = 'status';
  static const createdAt = 'createdAt';
}

abstract final class FirestoreReports {
  /// brak ławki, brak poidełka, brak cienia, inne (S15).
  static const types = ['noBench', 'noWater', 'noShade', 'other'];
  static const statusNew = 'new';
  static const statusApproved = 'approved';
  static const statusRejected = 'rejected';
  static const commentMaxLength = 200;
}

/// Fields of `config/game`.
abstract final class GameConfigFields {
  static const heatOverride = 'heatOverride'; // 0–3
  static const activeQuestId = 'activeQuestId';
}

/// ISO 8601 week id of [date]'s calendar day, e.g. `2026-W43`. Used for
/// `users.weekId` and `districts/{id}/weeks/{weekId}`. Pass local (Polish)
/// time. The year is the ISO week-numbering year, so 2027-01-03 is
/// `2026-W53`.
String weekId(DateTime date) {
  // Work on the calendar day in UTC so DST changes do not shift days.
  final day = DateTime.utc(date.year, date.month, date.day);
  // The Thursday of the same ISO week decides the year.
  final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final firstOfYear = DateTime.utc(thursday.year);
  final week = thursday.difference(firstOfYear).inDays ~/ 7 + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

/// Id of a quest visit: `{uid}_{placeId}_{yyyyMMdd}`, with [date]'s calendar
/// day (local Polish time). One document per place and day; the rules reject
/// a second create and check the date against the server clock.
String visitId(String uid, String placeId, DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${uid}_${placeId}_$y$m$d';
}
