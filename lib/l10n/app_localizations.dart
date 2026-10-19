import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('pl')];

  /// App name
  ///
  /// In pl, this message translates to:
  /// **'Cool Łódź'**
  String get appTitle;

  /// No description provided for @navMap.
  ///
  /// In pl, this message translates to:
  /// **'Mapa'**
  String get navMap;

  /// No description provided for @navCool.
  ///
  /// In pl, this message translates to:
  /// **'Chłód'**
  String get navCool;

  /// No description provided for @navQuest.
  ///
  /// In pl, this message translates to:
  /// **'Quest'**
  String get navQuest;

  /// No description provided for @navProfile.
  ///
  /// In pl, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @questSegmentQuest.
  ///
  /// In pl, this message translates to:
  /// **'Quest'**
  String get questSegmentQuest;

  /// No description provided for @questSegmentBadges.
  ///
  /// In pl, this message translates to:
  /// **'Odznaki'**
  String get questSegmentBadges;

  /// No description provided for @questSegmentRanking.
  ///
  /// In pl, this message translates to:
  /// **'Ranking'**
  String get questSegmentRanking;

  /// No description provided for @dsShowcaseTitle.
  ///
  /// In pl, this message translates to:
  /// **'Komponenty'**
  String get dsShowcaseTitle;

  /// No description provided for @dsShowcaseSenior.
  ///
  /// In pl, this message translates to:
  /// **'Podgląd trybu Senior'**
  String get dsShowcaseSenior;

  /// No description provided for @dsLoading.
  ///
  /// In pl, this message translates to:
  /// **'Ładowanie'**
  String get dsLoading;

  /// No description provided for @dsRouteShortest.
  ///
  /// In pl, this message translates to:
  /// **'Najkrótsza'**
  String get dsRouteShortest;

  /// No description provided for @dsRouteShaded.
  ///
  /// In pl, this message translates to:
  /// **'Zacieniona'**
  String get dsRouteShaded;

  /// No description provided for @dsRouteCompromise.
  ///
  /// In pl, this message translates to:
  /// **'Kompromis'**
  String get dsRouteCompromise;

  /// Route duration and length on the route card
  ///
  /// In pl, this message translates to:
  /// **'{minutes} min · {distance} km'**
  String dsRouteMeta(int minutes, double distance);

  /// No description provided for @dsInShade.
  ///
  /// In pl, this message translates to:
  /// **'w cieniu'**
  String get dsInShade;

  /// No description provided for @dsFastestRoute.
  ///
  /// In pl, this message translates to:
  /// **'Najszybsza trasa'**
  String get dsFastestRoute;

  /// No description provided for @dsExtraMinutes.
  ///
  /// In pl, this message translates to:
  /// **'+{minutes} min względem najkrótszej'**
  String dsExtraMinutes(int minutes);

  /// No description provided for @dsPercentValue.
  ///
  /// In pl, this message translates to:
  /// **'{percent}%'**
  String dsPercentValue(int percent);

  /// No description provided for @dsShadePercent.
  ///
  /// In pl, this message translates to:
  /// **'{percent}% w cieniu'**
  String dsShadePercent(int percent);

  /// No description provided for @dsShadeBarSemantics.
  ///
  /// In pl, this message translates to:
  /// **'{percent} procent trasy w cieniu'**
  String dsShadeBarSemantics(int percent);

  /// No description provided for @dsCoolStopsSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Miejsca chłodu na trasie: {count}'**
  String dsCoolStopsSemantics(int count);

  /// No description provided for @dsWaterStopsSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Poidełka na trasie: {count}'**
  String dsWaterStopsSemantics(int count);

  /// No description provided for @dsSearchHint.
  ///
  /// In pl, this message translates to:
  /// **'Dokąd idziesz?'**
  String get dsSearchHint;

  /// No description provided for @dsHeatTitle.
  ///
  /// In pl, this message translates to:
  /// **'Ostrzeżenie przed upałem, stopień {level}'**
  String dsHeatTitle(int level);

  /// No description provided for @dsOpenNow.
  ///
  /// In pl, this message translates to:
  /// **'Otwarte teraz'**
  String get dsOpenNow;

  /// No description provided for @dsClosedOpensAt.
  ///
  /// In pl, this message translates to:
  /// **'Zamknięte, otwarcie o {time}'**
  String dsClosedOpensAt(String time);

  /// No description provided for @dsLetterToCollect.
  ///
  /// In pl, this message translates to:
  /// **'Litera do zdobycia'**
  String get dsLetterToCollect;

  /// No description provided for @dsNavigateThere.
  ///
  /// In pl, this message translates to:
  /// **'Prowadź tam'**
  String get dsNavigateThere;

  /// No description provided for @dsReportProblem.
  ///
  /// In pl, this message translates to:
  /// **'Zgłoś problem'**
  String get dsReportProblem;

  /// No description provided for @dsAmenityAirConditioning.
  ///
  /// In pl, this message translates to:
  /// **'Klimatyzacja'**
  String get dsAmenityAirConditioning;

  /// No description provided for @dsAmenityWater.
  ///
  /// In pl, this message translates to:
  /// **'Woda'**
  String get dsAmenityWater;

  /// No description provided for @dsAmenityToilet.
  ///
  /// In pl, this message translates to:
  /// **'Toaleta'**
  String get dsAmenityToilet;

  /// No description provided for @dsAmenityAccessible.
  ///
  /// In pl, this message translates to:
  /// **'Dostępne'**
  String get dsAmenityAccessible;

  /// No description provided for @dsIconCoolPlace.
  ///
  /// In pl, this message translates to:
  /// **'Miejsce chłodu'**
  String get dsIconCoolPlace;

  /// No description provided for @dsIconWaterTap.
  ///
  /// In pl, this message translates to:
  /// **'Poidełko'**
  String get dsIconWaterTap;

  /// No description provided for @dsIconQuestLetter.
  ///
  /// In pl, this message translates to:
  /// **'Litera questu'**
  String get dsIconQuestLetter;

  /// No description provided for @dsPinBench.
  ///
  /// In pl, this message translates to:
  /// **'Ławka'**
  String get dsPinBench;

  /// No description provided for @dsPinQuestLetter.
  ///
  /// In pl, this message translates to:
  /// **'Litera questu {letter}'**
  String dsPinQuestLetter(String letter);

  /// No description provided for @dsLetterFound.
  ///
  /// In pl, this message translates to:
  /// **'Litera {letter}, znaleziona'**
  String dsLetterFound(String letter);

  /// No description provided for @dsLetterEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Litera jeszcze nieodkryta'**
  String get dsLetterEmpty;

  /// No description provided for @dsBadgeEarnedSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Odznaka {name}, zdobyta'**
  String dsBadgeEarnedSemantics(String name);

  /// No description provided for @dsBadgeLockedSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Odznaka {name}, zablokowana'**
  String dsBadgeLockedSemantics(String name);

  /// No description provided for @dsLeaderboardOwn.
  ///
  /// In pl, this message translates to:
  /// **'Ty · {name}'**
  String dsLeaderboardOwn(String name);

  /// No description provided for @dsPoints.
  ///
  /// In pl, this message translates to:
  /// **'{points} pkt'**
  String dsPoints(int points);

  /// No description provided for @dsPointsGained.
  ///
  /// In pl, this message translates to:
  /// **'+{points} pkt'**
  String dsPointsGained(int points);

  /// No description provided for @dsLeaderboardRowSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Miejsce {rank}, {name}, {points} pkt'**
  String dsLeaderboardRowSemantics(int rank, String name, int points);

  /// No description provided for @dsErrorTitle.
  ///
  /// In pl, this message translates to:
  /// **'Coś poszło nie tak'**
  String get dsErrorTitle;

  /// No description provided for @dsErrorMessage.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie za chwilę.'**
  String get dsErrorMessage;

  /// No description provided for @dsRetry.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie'**
  String get dsRetry;

  /// No description provided for @dsOfflineBanner.
  ///
  /// In pl, this message translates to:
  /// **'Brak połączenia z serwerem, pokazujemy ostatnie dane'**
  String get dsOfflineBanner;

  /// No description provided for @dsBadgeNew.
  ///
  /// In pl, this message translates to:
  /// **'Nowa odznaka!'**
  String get dsBadgeNew;

  /// No description provided for @dsBadgeDialogOk.
  ///
  /// In pl, this message translates to:
  /// **'Super!'**
  String get dsBadgeDialogOk;

  /// No description provided for @placeholderInProgress.
  ///
  /// In pl, this message translates to:
  /// **'Ekran w budowie'**
  String get placeholderInProgress;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
