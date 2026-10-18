/// Game numbers from the spec ("Геймификация"). They are starting values:
/// change them here and only here.
abstract final class GameConfig {
  // Points.
  static const pointsQrScan = 50; // once a day per place
  static const pointsShadedRoute = 10; // route with shade share ≥ 60 %
  static const pointsPasswordSolved = 200; // once
  static const pointsBadge = 30; // once per badge
  static const pointsReportApproved = 20; // after manual approval (S)

  // Limits.
  static const shadedRouteMinShade = 0.60;
  static const shadedRoutesPerDay = 5;
  static const qrScansPerPlacePerDay = 1;
  static const maxPointsPerWrite = 200; // enforced again by Firestore rules
  static const scanMaxDistanceMeters = 150.0;

  // Heat mode (alert level 3): no route points for departures 11:00–17:00.
  static const heatModeLevel = 3;
  static const heatNoPointsFromHour = 11;
  static const heatNoPointsToHour = 17;

  // Badges.
  static const badgeShadedTenCount = 10; // Cienista dziesiątka
  static const badgeShadedTenMinShade = 0.60;
  static const badgeCoolGuardPlaces = 5; // Strażnik chłodu (lower for the demo)
  static const badgeEarlyBirdFromHour = 6; // Ranny ptaszek 6:00–10:00
  static const badgeEarlyBirdToHour = 10;
  static const badgeEveningFromHour = 19; // Wieczorny spacerowicz 19:00–22:00
  static const badgeEveningToHour = 22;
  static const badgeParkHunterRoutes = 5; // Łowca parków
  static const badgeCityHelperReports = 3; // Pomocnik miasta (S)

  // Quest «Chłodne hasło».
  static const questPlacesCount = 7;
  static const questLink =
      'coollodz://quest'; // coollodz://quest/{placeId}?c={kod}

  // Ranking.
  static const rankingUsersLimit = 50;
  static const districts = [
    'Bałuty',
    'Górna',
    'Polesie',
    'Śródmieście',
    'Widzew',
  ];
}
