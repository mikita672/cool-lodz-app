/// Route paths for every screen in the spec (S01–S16).
/// Tabs (bottom bar): Mapa, Chłód, Quest, Profil.
abstract final class Routes {
  static const onboarding = '/onboarding'; // S01
  static const login = '/login'; // S02
  static const consents = '/consents'; // S03
  static const profileSelect = '/profile-select'; // S04 (also from Profil)

  static const map = '/map'; // S05, tab
  static const routePlan = '/route'; // S06
  static const routeResult = '/route/result'; // S07
  static const coolPlaces = '/cool'; // S09, tab
  static const quest = '/quest'; // S10 + segments S12, S13, tab
  static const questScan = '/quest/scan'; // S11
  static const alert = '/alert'; // S14
  static const report = '/report'; // S15
  static const profile = '/profile'; // S16, tab
  static const about = '/profile/about'; // S16 «O aplikacji»
  static const privacy = '/privacy'; // Polityka prywatności (S03, S16)
  static const debugComponents = '/debug/components'; // APP-06 showcase

  /// S08 is a bottom sheet, opened with `showPlaceSheet`; this route is the
  /// full-screen fallback for links to one place.
  static String place(String placeId) => '/place/$placeId';
  static const placePattern = '/place/:placeId';
}
