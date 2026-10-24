/// Route paths for every screen in the spec (S01–S16).
/// Tabs (bottom bar): Mapa, Chłód, Quest, Profil.
abstract final class Routes {
  static const start = '/start'; // loading while the start flow is checked
  static const onboarding = '/onboarding'; // S01
  static const login = '/login'; // S02
  static const consents = '/consents'; // S03
  static const profileSelect = '/profile-select'; // S04 (also from Profil)

  static const map = '/map'; // S05, tab
  static const routePlan = '/route'; // S06
  static const routeResult = '/route/result'; // S07 (child of S06)
  static const coolPlaces = '/cool'; // S09, tab
  static const quest = '/quest'; // S10 + segments S12, S13, tab
  static const questScan = '/quest/scan'; // S11 (child of the Quest tab)
  static const alert = '/map/alert'; // S14 (child of the Mapa tab)
  static const report = '/report'; // S15
  static const profile = '/profile'; // S16, tab
  static const about = '/profile/about'; // S16 «O aplikacji» (child of Profil)
  static const consentsSettings = '/profile/consents'; // S16 «Zgody»
  static const heatGuard = '/profile/heat-guard'; // «Alarm upałowy»
  static const heatCheck = '/heat-check'; // «Wszystko w porządku?»
  static const heatSymptoms = '/heat-symptoms'; // «Objawy upału» (information)
  static const shop = '/shop'; // «Sklep z nagrodami»
  static const coolWalk = '/cool-walk'; // «Chłodny spacer»
  static const dayPlan = '/day-plan'; // «Dzień w upale»
  static const guide = '/guide'; // the onboarding again, from Profil
  static const privacy = '/privacy'; // Polityka prywatności (S03, S16)
  static const debugComponents = '/debug/components'; // APP-06 showcase

  /// S08 is a bottom sheet, opened with `showPlaceSheet`; this route is the
  /// full-screen fallback for links to one place.
  static String place(String placeId) => '/place/$placeId';
  static const placePattern = '/place/:placeId';
}
