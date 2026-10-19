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
  String get placeholderInProgress => 'Ekran w budowie';

  @override
  String get apiFallbackBanner =>
      'Brak połączenia z serwerem, pokazujemy ostatnie dane';
}
