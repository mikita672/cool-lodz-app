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
    return 'Miejsce $rank, $name, $points pkt';
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
}
