// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Cool Łódź';

  @override
  String get navMap => 'Mapa';

  @override
  String get navCool => 'Chłód';

  @override
  String get navQuest => 'Quest';

  @override
  String get navProfile => 'Profil';

  @override
  String get questSegmentQuest => 'Quest';

  @override
  String get questSegmentBadges => 'Odznaki';

  @override
  String get questSegmentRanking => 'Ranking';

  @override
  String get dsShowcaseTitle => 'Komponenty';

  @override
  String get dsShowcaseSenior => 'Podgląd trybu Senior';

  @override
  String get dsLoading => 'Ładowanie';

  @override
  String get dsRouteShortest => 'Najkrótsza';

  @override
  String get dsRouteShaded => 'Zacieniona';

  @override
  String get dsRouteCompromise => 'Kompromis';

  @override
  String dsRouteAlternative(int number) {
    return 'Inna trasa $number';
  }

  @override
  String dsRouteMeta(int minutes, double distance) {
    final intl.NumberFormat distanceNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String distanceString = distanceNumberFormat.format(distance);

    return '$minutes min · $distanceString km';
  }

  @override
  String get dsInShade => 'w cieniu';

  @override
  String get dsFastestRoute => 'Najszybsza trasa';

  @override
  String dsExtraMinutes(int minutes) {
    return '+$minutes min względem najkrótszej';
  }

  @override
  String dsPercentValue(int percent) {
    return '$percent%';
  }

  @override
  String dsShadePercent(int percent) {
    return '$percent% w cieniu';
  }

  @override
  String dsShadeBarSemantics(int percent) {
    return '$percent procent trasy w cieniu';
  }

  @override
  String dsCoolStopsSemantics(int count) {
    return 'Miejsca chłodu na trasie: $count';
  }

  @override
  String dsWaterStopsSemantics(int count) {
    return 'Poidełka na trasie: $count';
  }

  @override
  String dsCoolStopsLabel(int count) {
    return 'Miejsca chłodu: $count';
  }

  @override
  String dsWaterStopsLabel(int count) {
    return 'Poidełka: $count';
  }

  @override
  String get dsSearchHint => 'Dokąd idziesz?';

  @override
  String dsHeatTitle(int level) {
    return 'Ostrzeżenie przed upałem, stopień $level';
  }

  @override
  String get dsOpenNow => 'Otwarte teraz';

  @override
  String dsClosedOpensAt(String time) {
    return 'Zamknięte, otwarcie o $time';
  }

  @override
  String get dsLetterToCollect => 'Litera do zdobycia';

  @override
  String get dsNavigateThere => 'Prowadź tam';

  @override
  String get dsReportProblem => 'Zgłoś problem';

  @override
  String get dsAmenityAirConditioning => 'Klimatyzacja';

  @override
  String get dsAmenityWater => 'Woda';

  @override
  String get dsAmenityToilet => 'Toaleta';

  @override
  String get dsAmenityAccessible => 'Dostępne';

  @override
  String get dsIconCoolPlace => 'Miejsce chłodu';

  @override
  String get dsIconWaterTap => 'Poidełko';

  @override
  String get dsIconQuestLetter => 'Litera questu';

  @override
  String get dsPinBench => 'Ławka';

  @override
  String get dsPinLabelCool => 'Chłód';

  @override
  String get dsPinLabelWater => 'Woda';

  @override
  String dsPinLabelQuest(String letter) {
    return 'Litera $letter';
  }

  @override
  String dsPinQuestLetter(String letter) {
    return 'Litera questu $letter';
  }

  @override
  String dsLetterFound(String letter) {
    return 'Litera $letter, znaleziona';
  }

  @override
  String get dsLetterEmpty => 'Litera jeszcze nieodkryta';

  @override
  String dsBadgeEarnedSemantics(String name) {
    return 'Odznaka $name, zdobyta';
  }

  @override
  String dsBadgeLockedSemantics(String name) {
    return 'Odznaka $name, zablokowana';
  }

  @override
  String dsLeaderboardOwn(String name) {
    return 'Ty · $name';
  }

  @override
  String dsPoints(int points) {
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    return '$pointsString pkt';
  }

  @override
  String dsPointsGained(int points) {
    return '+$points pkt';
  }

  @override
  String dsLeaderboardRowSemantics(int rank, String name, int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points punktu',
      many: '$points punktów',
      few: '$points punkty',
      one: '1 punkt',
    );
    return 'Miejsce $rank, $name, $_temp0';
  }

  @override
  String get dsErrorTitle => 'Coś poszło nie tak';

  @override
  String get dsErrorMessage => 'Spróbuj ponownie za chwilę.';

  @override
  String get dsRetry => 'Spróbuj ponownie';

  @override
  String get dsOfflineBanner =>
      'Brak połączenia z serwerem, pokazujemy ostatnie dane';

  @override
  String get dsBadgeNew => 'Nowa odznaka!';

  @override
  String get dsBadgeDialogOk => 'Super!';

  @override
  String get placeholderInProgress => 'Ekran w budowie';

  @override
  String get apiFallbackBanner =>
      'Brak połączenia z serwerem, pokazujemy ostatnie dane';

  @override
  String get startLoading => 'Wczytywanie';

  @override
  String get onboardingSkip => 'Pomiń';

  @override
  String get onboardingNext => 'Dalej';

  @override
  String get onboardingStart => 'Zaczynamy';

  @override
  String get onboardingShadeTitle => 'Idź w cieniu';

  @override
  String get onboardingShadeBody =>
      'Trasy przez cień, zieleń i ciche ulice. Jak najmniej czasu na słońcu w upalny dzień.';

  @override
  String get onboardingCoolTitle => 'Znajdź miejsce chłodu';

  @override
  String get onboardingCoolBody =>
      'Biblioteki, centra kultury i klimatyzowane miejsca w pobliżu, a do tego poidełka z wodą.';

  @override
  String get onboardingQuestTitle => 'Zbieraj litery';

  @override
  String get onboardingQuestBody =>
      'Odwiedzaj miejsca chłodu rano i wieczorem, skanuj kody QR, zdobywaj odznaki i punkty dla swojej dzielnicy.';

  @override
  String onboardingPageIndicator(int current, int total) {
    return 'Slajd $current z $total';
  }

  @override
  String get authTagline => 'Idź w cieniu';

  @override
  String get authTabSignIn => 'Zaloguj się';

  @override
  String get authTabRegister => 'Załóż konto';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Hasło';

  @override
  String get authNicknameLabel => 'Pseudonim';

  @override
  String get authNicknameHelper =>
      'Pseudonim widać w rankingu. Nie podawaj imienia i nazwiska.';

  @override
  String get authPasswordHelper => 'Minimum 8 znaków';

  @override
  String get authShowPassword => 'Pokaż hasło';

  @override
  String get authHidePassword => 'Ukryj hasło';

  @override
  String get authSignInButton => 'Zaloguj się';

  @override
  String get authRegisterButton => 'Załóż konto';

  @override
  String get authForgotPassword => 'Nie pamiętam hasła';

  @override
  String get authFooter =>
      'Logowanie tylko przez e-mail. Twoje dane są przechowywane w UE (Warszawa).';

  @override
  String get authLoading => 'Chwileczkę…';

  @override
  String get authEmailRequired => 'Wpisz adres e-mail';

  @override
  String get authEmailInvalid => 'Sprawdź adres e-mail';

  @override
  String get authPasswordRequired => 'Wpisz hasło';

  @override
  String get authPasswordTooShort => 'Hasło musi mieć co najmniej 8 znaków';

  @override
  String get authNicknameLength => 'Pseudonim musi mieć od 2 do 24 znaków';

  @override
  String get authErrorWrongCredentials => 'Nieprawidłowy e-mail lub hasło.';

  @override
  String get authErrorEmailInUse =>
      'Ten adres e-mail jest już zajęty. Zaloguj się albo użyj innego.';

  @override
  String get authErrorWeakPassword =>
      'To hasło jest za słabe. Wybierz dłuższe.';

  @override
  String get authErrorNetwork =>
      'Brak połączenia z internetem. Spróbuj ponownie.';

  @override
  String get authErrorUnknown =>
      'Coś poszło nie tak. Spróbuj ponownie za chwilę.';

  @override
  String get authResetTitle => 'Nie pamiętasz hasła?';

  @override
  String get authResetBody =>
      'Wpisz e-mail, a wyślemy link do ustawienia nowego hasła.';

  @override
  String get authResetSend => 'Wyślij';

  @override
  String get authResetCancel => 'Anuluj';

  @override
  String authResetSent(String email) {
    return 'Jeśli konto istnieje, link do zmiany hasła jest już w drodze na $email.';
  }

  @override
  String get consentsTitle => 'Zanim zaczniesz';

  @override
  String get consentsIntro =>
      'Zbieramy tylko to, co potrzebne. Zgody zmienisz w każdej chwili w Profilu.';

  @override
  String get consentsLocationTitle => 'Lokalizacja';

  @override
  String get consentsLocationBody =>
      'Tylko podczas korzystania z aplikacji. Nie zapisujemy trasy spaceru.';

  @override
  String get consentsLocationRequired => 'Wymagana do questu';

  @override
  String get consentsPushTitle => 'Powiadomienia';

  @override
  String get consentsPushBody =>
      'Alerty o upale z IMGW i przypomnienia o miejscach chłodu.';

  @override
  String get consentsRankingTitle => 'Udział w rankingu';

  @override
  String get consentsRankingBody =>
      'Twój pseudonim i punkty będą widoczne w rankingu dzielnic i użytkowników.';

  @override
  String get consentsPrivacyLink => 'Polityka prywatności';

  @override
  String get consentsSystemNote =>
      'Po kliknięciu Android zapyta o uprawnienia systemowe.';

  @override
  String get consentsAccept => 'Akceptuję i dalej';

  @override
  String get consentsSaveError =>
      'Nie udało się zapisać zgód. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get privacyTitle => 'Polityka prywatności';

  @override
  String get privacyDraftNote =>
      'Wersja robocza — do sprawdzenia przez zespół.';

  @override
  String get privacyIntro =>
      'Cool Łódź pomaga przejść przez miasto w upał: trasy w cieniu, miejsca chłodu i quest. Zbieramy tylko dane potrzebne do działania aplikacji.';

  @override
  String get privacyDataTitle => 'Jakie dane zbieramy';

  @override
  String get privacyDataBody =>
      '• Adres e-mail — do logowania i zmiany hasła.\n• Pseudonim — widoczny w rankingu, jeśli się na to zgodzisz. Nie podawaj imienia i nazwiska.\n• Dzielnica — do rankingu dzielnic.\n• Ustawienia profilu — preferencje trasy (np. więcej cienia, mniej schodów) i tryb Senior.\n• Punkty, odznaki i zgody z ekranu „Zanim zaczniesz”.\n• Token powiadomień — jeśli włączysz powiadomienia.\n\nNie zbieramy danych o zdrowiu. Profil to tylko preferencje trasy, nie informacja medyczna.';

  @override
  String get privacyLocationTitle => 'Lokalizacja';

  @override
  String get privacyLocationBody =>
      'Z lokalizacji korzystamy tylko wtedy, gdy używasz aplikacji: do pokazania Cię na mapie, planowania trasy i potwierdzenia wizyty w questie. Nie zapisujemy trasy spaceru. Przy wizycie w questie zapisujemy tylko miejsce i czas skanu kodu QR.';

  @override
  String get privacyStorageTitle => 'Gdzie przechowujemy dane';

  @override
  String get privacyStorageBody =>
      'Dane konta trzymamy w usłudze Google Firebase (Authentication i Cloud Firestore). Baza danych znajduje się w regionie europe-central2 (Warszawa), czyli w Unii Europejskiej.';

  @override
  String get privacyRankingTitle => 'Ranking';

  @override
  String get privacyRankingBody =>
      'Twój pseudonim i punkty widzą inni użytkownicy tylko wtedy, gdy włączysz udział w rankingu. Możesz to wyłączyć w Profilu.';

  @override
  String get privacyRightsTitle => 'Twoje prawa i usunięcie konta';

  @override
  String get privacyRightsBody =>
      'Zgodnie z RODO możesz poprosić o dostęp do swoich danych, ich poprawienie lub usunięcie oraz w każdej chwili wycofać zgody w Profilu. Usunięcie konta usuwa wszystkie Twoje dokumenty: profil, punkty, odznaki i historię.';

  @override
  String get privacyContactTitle => 'Kontakt';

  @override
  String get privacyContactBody =>
      'Administrator danych: zespół Cool Łódź, [nazwa i adres do uzupełnienia]. Pytania o dane: [adres e-mail zespołu do uzupełnienia].';

  @override
  String get profileTitle => 'Profil komfortu';

  @override
  String get profileIntro =>
      'Wybierz, co jest dla Ciebie ważne na trasie. Zmienisz to w każdej chwili w Profilu.';

  @override
  String get profileSeniorName => 'Senior';

  @override
  String get profileSeniorBody =>
      'Najwięcej cienia, ławki po drodze i duży tekst';

  @override
  String get profileTouristName => 'Turysta';

  @override
  String get profileTouristBody =>
      'Zabytki w cieniu i chłodne miejsca w pobliżu';

  @override
  String get profileStandardName => 'Domyślny';

  @override
  String get profileStandardBody => 'Kompromis między czasem a cieniem';

  @override
  String get profileSelected => 'Wybrany';

  @override
  String get profileAdjust => 'Dostosuj';

  @override
  String get profileAdjustHint => '0 — nieważne, 100 — bardzo ważne';

  @override
  String get profileWeightShade => 'Cień';

  @override
  String get profileWeightTime => 'Czas';

  @override
  String get profileWeightQuiet => 'Cisza';

  @override
  String get profileWeightAir => 'Powietrze';

  @override
  String get profileSeniorModeTitle => 'Duży tekst i przyciski';

  @override
  String get profileSeniorModeBody =>
      'Tryb Senior: tekst o 25% większy, większe przyciski i podpisy przy ikonach';

  @override
  String get profileSoonTitle => 'Wkrótce';

  @override
  String get profileSoon => 'Wkrótce';

  @override
  String get profileDogName => 'Z psem';

  @override
  String get profileDogBody => 'Cień, zieleń i woda dla psa';

  @override
  String get profileStrollerName => 'Z wózkiem';

  @override
  String get profileStrollerBody => 'Bez schodów, z cieniem i ławkami';

  @override
  String get profileCommuteName => 'Do pracy';

  @override
  String get profileCommuteBody => 'Szybko, ale nie w pełnym słońcu';

  @override
  String get profileActiveName => 'Aktywny';

  @override
  String get profileActiveBody => 'Dłuższe trasy przez zieleń';

  @override
  String get profileSensitiveName => 'Wrażliwy na hałas i smog';

  @override
  String get profileSensitiveBody => 'Cisza i czyste powietrze';

  @override
  String get profileSave => 'Zapisz';

  @override
  String get profileContinue => 'Dalej';

  @override
  String get profileSaved => 'Profil zapisany';

  @override
  String get profileSaveError =>
      'Nie udało się zapisać profilu. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get routePlanTitle => 'Zaplanuj trasę';

  @override
  String get routeFrom => 'Skąd';

  @override
  String get routeTo => 'Dokąd';

  @override
  String get routeToHint => 'Wybierz cel';

  @override
  String get routeMyLocation => 'Moja lokalizacja';

  @override
  String get routeSwap => 'Zamień start i cel';

  @override
  String get routeDeparture => 'Wyjście';

  @override
  String get routeDepartNow => 'Teraz';

  @override
  String get routeDepartPick => 'Wybierz godzinę';

  @override
  String routeDepartToday(String time) {
    return 'Dziś, $time';
  }

  @override
  String routeDepartTomorrow(String time) {
    return 'Jutro, $time';
  }

  @override
  String routeDepartOn(String date, String time) {
    return '$date, $time';
  }

  @override
  String routeProfileChip(String name) {
    return 'Profil: $name';
  }

  @override
  String get routeProfileChipHint => 'Zmień profil komfortu';

  @override
  String get routeQuickTitle => 'Szybkie trasy';

  @override
  String routeQuickRoute(String from, String to) {
    return '$from → $to';
  }

  @override
  String get routeShowRoutes => 'Pokaż trasy';

  @override
  String get routeSearchHint => 'Szukaj adresu lub miejsca';

  @override
  String get routeSearchFromTitle => 'Skąd idziesz?';

  @override
  String get routeSearchToTitle => 'Dokąd idziesz?';

  @override
  String get routeSearchPlaces => 'Miejsca chłodu';

  @override
  String get routeSearchAddresses => 'Adresy w Łodzi';

  @override
  String get routeSearchTypeMore =>
      'Wpisz co najmniej 3 znaki, aby szukać adresów';

  @override
  String get routeSearchNoResults => 'Nic nie znaleźliśmy';

  @override
  String get routeSearchError =>
      'Nie udało się wyszukać adresów. Sprawdź połączenie.';

  @override
  String get routeSearchClear => 'Wyczyść';

  @override
  String get routeSearchAttribution =>
      'Wyszukiwanie: © OpenStreetMap (Nominatim)';

  @override
  String get routeResultTitle => 'Trasy';

  @override
  String routeResultHeader(String from, String to) {
    return '$from → $to';
  }

  @override
  String routeResultDeparture(String time) {
    return 'Wyjście: $time';
  }

  @override
  String get routeApproximate => 'Dla tego obszaru cień jest przybliżony';

  @override
  String get routeGo => 'Prowadź';

  @override
  String get routeNoSun =>
      'O tej porze nie ma słońca, więc trasy różnią się tylko długością.';

  @override
  String get routeCloudy =>
      'Pochmurno: słońca będzie niewiele, więc trasy mało się różnią.';

  @override
  String get routeSave => 'Zapisz';

  @override
  String get routeSaved => 'Trasa zapisana. Zobaczysz ją także bez internetu.';

  @override
  String get routeSaveError => 'Nie udało się zapisać trasy';

  @override
  String get routeMapsError => 'Nie udało się otworzyć Map Google';

  @override
  String get routeNotFoundTitle => 'Nie znaleźliśmy trasy';

  @override
  String get routeNotFoundBody =>
      'Spróbuj wybrać inne miejsce startu lub celu.';

  @override
  String get routeChangePoints => 'Zmień punkty';

  @override
  String get routeNoLocationTitle => 'Nie znamy Twojej lokalizacji';

  @override
  String get routeNoLocationBody =>
      'Włącz lokalizację albo wybierz punkt startu ręcznie.';

  @override
  String get routeEnableLocation => 'Włącz lokalizację';

  @override
  String get routeChooseStart => 'Wybierz punkt startu';

  @override
  String routeVariantsPage(int index, int count) {
    return 'Wariant $index z $count';
  }

  @override
  String get routePrevVariant => 'Poprzedni wariant';

  @override
  String get routeNextVariant => 'Następny wariant';

  @override
  String routeMapSemantics(String name, int percent) {
    return 'Mapa z trzema trasami. Wybrana: $name, $percent procent w cieniu.';
  }

  @override
  String get routeLegendShade => 'w cieniu';

  @override
  String get routeLegendSun => 'na słońcu';

  @override
  String get placeCategoryLibrary => 'Biblioteka';

  @override
  String get placeCategoryMuseum => 'Muzeum';

  @override
  String get placeCategoryCulture => 'Kultura';

  @override
  String get placeCategoryMall => 'Centrum handlowe';

  @override
  String get placeCategoryPark => 'Park';

  @override
  String get placeCategoryStation => 'Dworzec';

  @override
  String get placeCategoryChurch => 'Kościół';

  @override
  String get placeCategoryOther => 'Miejsce chłodu';

  @override
  String get placeWaterName => 'Poidełko';

  @override
  String get placeBenchName => 'Ławka';

  @override
  String placeOpenUntil(String time) {
    return 'Otwarte teraz · do $time';
  }

  @override
  String get placeOpenAllDay => 'Otwarte całą dobę';

  @override
  String placeClosedOpensOn(String day, String time) {
    return 'Zamknięte, otwarcie $day o $time';
  }

  @override
  String get placeClosed => 'Zamknięte';

  @override
  String get placeTomorrow => 'jutro';

  @override
  String placeTodayHours(String hours) {
    return 'Dziś $hours';
  }

  @override
  String get placeTodayClosed => 'Dziś nieczynne';

  @override
  String placeDistanceM(int meters) {
    return '$meters m';
  }

  @override
  String placeDistanceKm(double km) {
    final intl.NumberFormat kmNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String kmString = kmNumberFormat.format(km);

    return '$kmString km';
  }

  @override
  String get placeSourceLink => 'Źródło godzin otwarcia';

  @override
  String get placeNotFound => 'Nie znaleźliśmy tego miejsca';

  @override
  String get mapLayerShade => 'Cień';

  @override
  String get mapLayerGreen => 'Zieleń';

  @override
  String get mapLayerQuiet => 'Cisza';

  @override
  String get mapLayerAir => 'Powietrze';

  @override
  String get mapLayerWater => 'Woda';

  @override
  String get mapLayerCool => 'Miejsca chłodu';

  @override
  String mapFillLimit(String layer) {
    return 'Na mapie mogą być naraz 2 warstwy obszarów. Wyłączyliśmy: $layer.';
  }

  @override
  String mapShadeAt(String time) {
    return 'Cień o $time';
  }

  @override
  String get mapShadeChangeTime => 'Zmień godzinę cienia';

  @override
  String get mapShadeTimeTitle => 'Cień o godzinie';

  @override
  String get mapShadeDemoNote => 'Mapa cienia jest policzona dla 14:30.';

  @override
  String get mapNoLocationTitle => 'Nie widzimy Twojej lokalizacji';

  @override
  String get mapNoLocationBody => 'Pokazujemy Śródmieście.';

  @override
  String get mapEnableLocation => 'Włącz lokalizację';

  @override
  String get mapMyLocation => 'Pokaż moją lokalizację';

  @override
  String get mapCompass => 'Obróć mapę na północ';

  @override
  String mapAlertSubtitle(String source, String time) {
    return '$source · do $time';
  }

  @override
  String get mapHeatModeHint =>
      'Tryb upału: w najgorętszych godzinach odpocznij w miejscu chłodu';

  @override
  String get mapLegendQuiet => 'Ciemniej = ciszej';

  @override
  String get mapLegendShade => 'Cień';

  @override
  String get mapLegendSun => 'Słońce (blednie, gdy pochmurno)';

  @override
  String get mapWeatherNight => 'po zachodzie słońca';

  @override
  String mapWeatherSunny(int temp) {
    return '$temp°C, słonecznie';
  }

  @override
  String mapWeatherPartly(int temp) {
    return '$temp°C, częściowo słonecznie';
  }

  @override
  String mapWeatherCloudy(int temp) {
    return '$temp°C, pochmurno';
  }

  @override
  String get mapLegendAir => 'Indeks jakości powietrza GIOŚ';

  @override
  String get mapAirVeryGood => 'Bardzo dobry';

  @override
  String get mapAirGood => 'Dobry';

  @override
  String get mapAirModerate => 'Umiarkowany';

  @override
  String get mapAirSufficient => 'Dostateczny';

  @override
  String get mapAirBad => 'Zły';

  @override
  String get mapAirVeryBad => 'Bardzo zły';

  @override
  String get mapAirNoData => 'Brak danych';

  @override
  String mapAirStation(String name, String level) {
    return '$name: $level';
  }

  @override
  String mapLayerError(String layer) {
    return 'Nie udało się wczytać warstwy $layer';
  }

  @override
  String mapSemantics(String layers) {
    return 'Mapa Łodzi. Warstwy: $layers.';
  }

  @override
  String get mapBenchesZoomHint => 'Ławki widać po przybliżeniu mapy';

  @override
  String get coolTitle => 'Miejsca chłodu';

  @override
  String get coolViewList => 'Lista';

  @override
  String get coolViewMap => 'Mapa';

  @override
  String get coolFilterOpen => 'Otwarte teraz';

  @override
  String get coolFilterWater => 'Z wodą';

  @override
  String get coolFilterAccessible => 'Dostępne';

  @override
  String get coolFilterQuest => 'W queście';

  @override
  String get coolEmptyTitle => 'Brak otwartych miejsc w pobliżu';

  @override
  String get coolEmptyBody => 'Zmień filtry, aby zobaczyć więcej miejsc.';

  @override
  String get coolShowAll => 'Pokaż wszystkie';

  @override
  String get coolNoLocationNote =>
      'Odległości od centrum Łodzi — włącz lokalizację, aby liczyć od Ciebie.';

  @override
  String get coolLoadError => 'Nie udało się wczytać miejsc chłodu';

  @override
  String get badgeFirstStepName => 'Pierwszy krok';

  @override
  String get badgeFirstStepCondition => 'Ruszaj pierwszą trasą z «Prowadź»';

  @override
  String get badgeFirstStepDescription =>
      'Pierwsza trasa za Tobą. Dobrze, że wybierasz cień.';

  @override
  String get badgeShadedTenName => 'Cienista dziesiątka';

  @override
  String get badgeShadedTenCondition => '10 tras z co najmniej 60% cienia';

  @override
  String get badgeShadedTenDescription =>
      'Dziesięć tras w cieniu. Twoje stopy i głowa dziękują.';

  @override
  String get badgeCoolGuardName => 'Strażnik chłodu';

  @override
  String badgeCoolGuardCondition(int count) {
    return 'Zeskanuj kody w $count różnych miejscach chłodu';
  }

  @override
  String get badgeCoolGuardDescription =>
      'Znasz miejsca, w których można odpocząć od upału.';

  @override
  String get badgeEarlyBirdName => 'Ranny ptaszek';

  @override
  String get badgeEarlyBirdCondition =>
      'Trasa z wyjściem 6:00–10:00 w dzień ostrzeżenia przed upałem';

  @override
  String get badgeEarlyBirdDescription =>
      'Rano jest chłodniej. Świetny wybór w upalny dzień.';

  @override
  String get badgeEveningName => 'Wieczorny spacerowicz';

  @override
  String get badgeEveningCondition =>
      'Trasa z wyjściem 19:00–22:00 w dzień ostrzeżenia przed upałem';

  @override
  String get badgeEveningDescription =>
      'Wieczorem upał odpuszcza. Miłego spaceru.';

  @override
  String get badgeParkHunterName => 'Łowca parków';

  @override
  String get badgeParkHunterCondition => '5 tras kończących się w parku';

  @override
  String get badgeParkHunterDescription =>
      'Pięć tras do parku. Zieleń to najlepszy cień.';

  @override
  String get badgeCityHelperName => 'Pomocnik miasta';

  @override
  String get badgeCityHelperCondition => '3 zatwierdzone zgłoszenia';

  @override
  String get badgeCityHelperDescription =>
      'Dzięki Twoim zgłoszeniom miasto wie, gdzie brakuje cienia i wody.';

  @override
  String get badgesEarned => 'Zdobyta';

  @override
  String get badgesTotal => 'Twoje punkty';

  @override
  String get badgesTitle => 'Odznaki';

  @override
  String get badgesRecent => 'Ostatnie punkty';

  @override
  String get badgesNoPoints =>
      'Nie masz jeszcze punktów. Wybierz trasę w cieniu albo zeskanuj kod QR w miejscu chłodu.';

  @override
  String get badgesLogRoute => 'Trasa w cieniu';

  @override
  String get badgesLogScan => 'Kod QR w miejscu chłodu';

  @override
  String get badgesLogPassword => 'Hasło questu';

  @override
  String badgesLogBadge(String name) {
    return 'Odznaka: $name';
  }

  @override
  String get badgesLogReport => 'Zatwierdzone zgłoszenie';

  @override
  String get badgesLoadError => 'Nie udało się wczytać punktów';

  @override
  String gamePointsToast(int points) {
    return '+$points pkt';
  }

  @override
  String gameRoutePointsToast(int points) {
    return '+$points pkt za trasę w cieniu';
  }

  @override
  String get gameHeatNoPoints =>
      'W trybie upału trasy z wyjściem 11:00–17:00 nie dają punktów. Wybierz poranek lub wieczór.';

  @override
  String get questTitle => 'Chłodne hasło';

  @override
  String get questIntro =>
      'Odwiedzaj miejsca chłodu, skanuj kody QR przy wejściu i zbieraj litery hasła.';

  @override
  String questProgress(int found, int total) {
    return '$found z $total liter';
  }

  @override
  String get questScan => 'Skanuj kod QR';

  @override
  String get questPlacesTitle => 'Miejsca questu';

  @override
  String get questVisited => 'Odwiedzone';

  @override
  String get questToVisit => 'Do odwiedzenia';

  @override
  String questLetterOf(String letter) {
    return 'Litera $letter';
  }

  @override
  String get questHeatHint => 'Dziś odwiedzaj miejsca rano lub wieczorem';

  @override
  String questHeatHidden(int count) {
    return 'W trybie upału ukrywamy miejsca na słońcu: $count';
  }

  @override
  String get questPasswordTitle => 'Masz wszystkie litery!';

  @override
  String get questPasswordHint => 'Wpisz hasło';

  @override
  String get questPasswordCheck => 'Sprawdź';

  @override
  String get questPasswordWrong =>
      'To nie to hasło. Ułóż litery w kolejności miejsc.';

  @override
  String get questRewardTitle => 'Hasło odgadnięte!';

  @override
  String get questRewardBody => 'Twój kod zniżki na przejazd MPK Łódź:';

  @override
  String get questRewardNote => 'Zachowaj go — przyda się przy zakupie biletu.';

  @override
  String get questLoadError => 'Nie udało się wczytać questu';

  @override
  String get scanTitle => 'Skaner QR';

  @override
  String get scanHint => 'Zeskanuj kod przy wejściu';

  @override
  String get scanChecking => 'Sprawdzamy kod…';

  @override
  String scanSuccess(String letter) {
    return 'Nowa litera: $letter';
  }

  @override
  String get scanBackToQuest => 'Wróć do questu';

  @override
  String get scanAgain => 'Skanuj ponownie';

  @override
  String get scanTooFar => 'Jesteś za daleko od miejsca';

  @override
  String scanTooFarDetail(int meters) {
    return 'Podejdź bliżej wejścia (jesteś $meters m od miejsca, potrzeba do 150 m).';
  }

  @override
  String get scanAlreadyToday => 'Ten kod już dziś zeskanowałeś';

  @override
  String get scanInvalid => 'Kod nieważny';

  @override
  String get scanNoLocation =>
      'Włącz lokalizację, aby potwierdzić wizytę w miejscu';

  @override
  String get scanFailed =>
      'Nie udało się zapisać wizyty. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get scanNoCameraTitle => 'Potrzebujemy aparatu';

  @override
  String get scanNoCameraBody =>
      'Aparat służy tylko do odczytania kodu QR. Zdjęcia nie są zapisywane.';

  @override
  String get scanOpenSettings => 'Otwórz ustawienia';

  @override
  String get scanCameraError => 'Nie udało się uruchomić aparatu';

  @override
  String get rankingDistricts => 'Dzielnice';

  @override
  String get rankingUsers => 'Użytkownicy';

  @override
  String get rankingWeek => 'Ten tydzień';

  @override
  String get rankingSummer => 'Całe lato';

  @override
  String get rankingEmpty =>
      'Na razie nikt nie ma tu punktów. Zacznij od trasy w cieniu!';

  @override
  String get rankingNoConsent =>
      'Nie bierzesz udziału w rankingu. Możesz to zmienić w Profilu → Zgody i prywatność.';

  @override
  String get rankingNoDistrict =>
      'Wybierz dzielnicę w Profilu, aby Twoje punkty liczyły się także dla niej.';

  @override
  String get rankingLoadError => 'Nie udało się wczytać rankingu';

  @override
  String get alertTitle => 'Alert upałowy';

  @override
  String alertHeading(int level) {
    return 'Ostrzeżenie przed upałem $level. stopnia';
  }

  @override
  String alertPeriod(String area, String from, String to) {
    return '$area · $from–$to';
  }

  @override
  String alertToday(String area) {
    return '$area · dziś';
  }

  @override
  String alertSource(String source) {
    return 'Źródło: $source';
  }

  @override
  String get alertWhatToDo => 'Co robić';

  @override
  String get alertTip1 =>
      'Pij wodę regularnie, nie czekaj, aż poczujesz pragnienie.';

  @override
  String get alertTip2 =>
      'W najcieplejszych godzinach wybieraj trasy w cieniu i rób przerwy w chłodnych miejscach.';

  @override
  String get alertTip3 =>
      'Zadzwoń do starszych bliskich lub sąsiadów i zapytaj, czy czegoś nie potrzebują.';

  @override
  String get alertOfficial => 'Oficjalne zalecenia';

  @override
  String get alertShowCool => 'Pokaż miejsca chłodu';

  @override
  String get alertHeatModeTitle => 'Tryb upału';

  @override
  String get alertHeatModeBody =>
      'Trasy z wyjściem 11:00–17:00 nie dają dziś punktów, a quest ukrywa miejsca na słońcu. Miejsca chłodu są otwarte jak zwykle.';

  @override
  String get alertNone => 'Brak ostrzeżeń przed upałem';

  @override
  String get alertNoneBody =>
      'Gdy IMGW ogłosi ostrzeżenie dla Łodzi, zobaczysz je tutaj.';

  @override
  String get alertPushFallback =>
      'Ostrzeżenie przed upałem w Łodzi. Zobacz trasy w cieniu.';

  @override
  String get alertSee => 'Zobacz';

  @override
  String get alertOpenError => 'Nie udało się otworzyć strony';

  @override
  String get settingsTitle => 'Profil';

  @override
  String get settingsDistrict => 'Dzielnica';

  @override
  String get settingsDistrictNone => 'Wybierz dzielnicę';

  @override
  String get settingsDistrictTitle => 'Twoja dzielnica';

  @override
  String get settingsDistrictHint =>
      'Twoje punkty liczą się też dla dzielnicy w rankingu.';

  @override
  String get settingsPoints => 'Punkty';

  @override
  String get settingsComfort => 'Mój profil komfortu';

  @override
  String get settingsSenior => 'Duży tekst i przyciski (tryb Senior)';

  @override
  String get settingsNotifications => 'Powiadomienia o upale';

  @override
  String get settingsNotificationsBody => 'Ostrzeżenia IMGW dla Łodzi';

  @override
  String get settingsConsents => 'Zgody i prywatność';

  @override
  String get settingsPrivacy => 'Polityka prywatności';

  @override
  String get settingsAbout => 'O aplikacji i źródła danych';

  @override
  String get settingsSignOut => 'Wyloguj';

  @override
  String get settingsDelete => 'Usuń konto';

  @override
  String get settingsSaveError =>
      'Nie udało się zapisać zmian. Sprawdź połączenie.';

  @override
  String get settingsDeleteTitle => 'Usunąć konto?';

  @override
  String get settingsDeleteBody =>
      'Usuniemy Twój profil, punkty, odznaki, historię tras, wizyt i zgłoszeń. Tego nie da się cofnąć. Wpisz hasło, aby potwierdzić.';

  @override
  String get settingsDeletePassword => 'Hasło';

  @override
  String get settingsDeleteConfirm => 'Usuń na zawsze';

  @override
  String get settingsDeleteCancel => 'Anuluj';

  @override
  String get settingsDeleteWrongPassword => 'Nieprawidłowe hasło';

  @override
  String get settingsDeleteError =>
      'Nie udało się usunąć konta. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get settingsDeleted => 'Konto zostało usunięte';

  @override
  String get settingsConsentsSave => 'Zapisz';

  @override
  String get settingsConsentsSaved => 'Zapisano';

  @override
  String get aboutTitle => 'O aplikacji';

  @override
  String aboutVersion(String version) {
    return 'Wersja $version';
  }

  @override
  String get aboutDescription =>
      'Cool Łódź prowadzi przez cień, zieleń i ciche ulice, pokazuje miejsca chłodu i wodę. Projekt zespołu Better Than Never na Hackathon Future Smart City 2026.';

  @override
  String get aboutMedical =>
      'Aplikacja nie jest wyrobem medycznym. W razie złego samopoczucia dzwoń 112.';

  @override
  String get aboutSources => 'Źródła danych';

  @override
  String get aboutSourceMap => 'Mapa: © OpenStreetMap contributors, © CARTO';

  @override
  String get aboutSourceSearch =>
      'Wyszukiwanie adresów: OpenStreetMap Nominatim';

  @override
  String get aboutSourceRoutes =>
      'Trasy piesze: OSRM (FOSSGIS) na danych OpenStreetMap';

  @override
  String get aboutSourceAlerts => 'Ostrzeżenia przed upałem: IMGW-PIB';

  @override
  String get aboutSourceAir => 'Jakość powietrza: GIOŚ';

  @override
  String get aboutSourceWeather => 'Pogoda: Open-Meteo.com (CC BY 4.0)';

  @override
  String get aboutSourceShade =>
      'Cień, zieleń i hałas: obliczenia Cool Łódź na danych OpenStreetMap i miejskich';

  @override
  String get aboutSourcePlaces =>
      'Miejsca chłodu: zebrane przez zespół, godziny ze stron miejsc';

  @override
  String get aboutLicenses => 'Licencje';

  @override
  String aboutDemoTapsLeft(int count) {
    return 'Jeszcze $count — tryb demo';
  }

  @override
  String get aboutDemoMode => 'Tryb demo';

  @override
  String get aboutDemoModeBody =>
      'Trasy, miejsca i alerty z danych zapisanych w aplikacji, bez serwera.';

  @override
  String get aboutDemoAlert => 'Alert w trybie demo';

  @override
  String get aboutDemoAlertNone => 'Brak';

  @override
  String aboutDemoAlertLevel(int level) {
    return 'Stopień $level';
  }

  @override
  String get routeBestTimeTitle => 'Najlepsza pora wyjścia';

  @override
  String routeBestTimeHint(String time, int percent) {
    return 'Najwięcej cienia o $time: $percent%';
  }

  @override
  String routeBestTimeSlider(String time, int percent) {
    return 'Wyjście o $time, $percent procent trasy w cieniu';
  }

  @override
  String get routeBestTimeChart =>
      'Udział cienia w ciągu dnia dla wybranej trasy';

  @override
  String get reportTitle => 'Zgłoś problem';

  @override
  String get reportTypeTitle => 'Czego brakuje?';

  @override
  String get reportNoBench => 'Brak ławki';

  @override
  String get reportNoWater => 'Brak poidełka';

  @override
  String get reportNoShade => 'Brak cienia';

  @override
  String get reportOther => 'Inne';

  @override
  String get reportWhere => 'Gdzie?';

  @override
  String get reportWhereHint =>
      'Przesuń mapę, aby ustawić pinezkę dokładnie w miejscu problemu.';

  @override
  String get reportComment => 'Komentarz (opcjonalnie)';

  @override
  String get reportSend => 'Wyślij zgłoszenie';

  @override
  String get reportChooseType => 'Wybierz rodzaj problemu';

  @override
  String get reportThanksTitle => 'Dziękujemy!';

  @override
  String get reportThanksBody => '+20 pkt po zatwierdzeniu';

  @override
  String get reportBack => 'Wróć';

  @override
  String get reportError =>
      'Nie udało się wysłać zgłoszenia. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get reportMapSemantics => 'Mapa z pinezką zgłoszenia';

  @override
  String get placeMon => 'pon.';

  @override
  String get placeTue => 'wt.';

  @override
  String get placeWed => 'śr.';

  @override
  String get placeThu => 'czw.';

  @override
  String get placeFri => 'pt.';

  @override
  String get placeSat => 'sob.';

  @override
  String get placeSun => 'niedz.';
}
