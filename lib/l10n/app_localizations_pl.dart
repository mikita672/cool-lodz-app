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
}
