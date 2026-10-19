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

  /// No description provided for @dsCoolStopsLabel.
  ///
  /// In pl, this message translates to:
  /// **'Miejsca chłodu: {count}'**
  String dsCoolStopsLabel(int count);

  /// No description provided for @dsWaterStopsLabel.
  ///
  /// In pl, this message translates to:
  /// **'Poidełka: {count}'**
  String dsWaterStopsLabel(int count);

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

  /// No description provided for @dsPinLabelCool.
  ///
  /// In pl, this message translates to:
  /// **'Chłód'**
  String get dsPinLabelCool;

  /// No description provided for @dsPinLabelWater.
  ///
  /// In pl, this message translates to:
  /// **'Woda'**
  String get dsPinLabelWater;

  /// No description provided for @dsPinLabelQuest.
  ///
  /// In pl, this message translates to:
  /// **'Litera {letter}'**
  String dsPinLabelQuest(String letter);

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
  /// **'Miejsce {rank}, {name}, {points, plural, =1{1 punkt} few{{points} punkty} many{{points} punktów} other{{points} punktu}}'**
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

  /// Banner when the remote API failed and cached or demo data is shown
  ///
  /// In pl, this message translates to:
  /// **'Brak połączenia z serwerem, pokazujemy ostatnie dane'**
  String get apiFallbackBanner;

  /// No description provided for @startLoading.
  ///
  /// In pl, this message translates to:
  /// **'Wczytywanie'**
  String get startLoading;

  /// No description provided for @onboardingSkip.
  ///
  /// In pl, this message translates to:
  /// **'Pomiń'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In pl, this message translates to:
  /// **'Dalej'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In pl, this message translates to:
  /// **'Zaczynamy'**
  String get onboardingStart;

  /// No description provided for @onboardingShadeTitle.
  ///
  /// In pl, this message translates to:
  /// **'Idź w cieniu'**
  String get onboardingShadeTitle;

  /// No description provided for @onboardingShadeBody.
  ///
  /// In pl, this message translates to:
  /// **'Trasy przez cień, zieleń i ciche ulice. Jak najmniej czasu na słońcu w upalny dzień.'**
  String get onboardingShadeBody;

  /// No description provided for @onboardingCoolTitle.
  ///
  /// In pl, this message translates to:
  /// **'Znajdź miejsce chłodu'**
  String get onboardingCoolTitle;

  /// No description provided for @onboardingCoolBody.
  ///
  /// In pl, this message translates to:
  /// **'Biblioteki, centra kultury i klimatyzowane miejsca w pobliżu, a do tego poidełka z wodą.'**
  String get onboardingCoolBody;

  /// No description provided for @onboardingQuestTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zbieraj litery'**
  String get onboardingQuestTitle;

  /// No description provided for @onboardingQuestBody.
  ///
  /// In pl, this message translates to:
  /// **'Odwiedzaj miejsca chłodu rano i wieczorem, skanuj kody QR, zdobywaj odznaki i punkty dla swojej dzielnicy.'**
  String get onboardingQuestBody;

  /// TalkBack label of the S01 page dots
  ///
  /// In pl, this message translates to:
  /// **'Slajd {current} z {total}'**
  String onboardingPageIndicator(int current, int total);

  /// No description provided for @authTagline.
  ///
  /// In pl, this message translates to:
  /// **'Idź w cieniu'**
  String get authTagline;

  /// No description provided for @authTabSignIn.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się'**
  String get authTabSignIn;

  /// No description provided for @authTabRegister.
  ///
  /// In pl, this message translates to:
  /// **'Załóż konto'**
  String get authTabRegister;

  /// No description provided for @authEmailLabel.
  ///
  /// In pl, this message translates to:
  /// **'E-mail'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In pl, this message translates to:
  /// **'Hasło'**
  String get authPasswordLabel;

  /// No description provided for @authNicknameLabel.
  ///
  /// In pl, this message translates to:
  /// **'Pseudonim'**
  String get authNicknameLabel;

  /// No description provided for @authNicknameHelper.
  ///
  /// In pl, this message translates to:
  /// **'Pseudonim widać w rankingu. Nie podawaj imienia i nazwiska.'**
  String get authNicknameHelper;

  /// No description provided for @authPasswordHelper.
  ///
  /// In pl, this message translates to:
  /// **'Minimum 8 znaków'**
  String get authPasswordHelper;

  /// No description provided for @authShowPassword.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż hasło'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In pl, this message translates to:
  /// **'Ukryj hasło'**
  String get authHidePassword;

  /// No description provided for @authSignInButton.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się'**
  String get authSignInButton;

  /// No description provided for @authRegisterButton.
  ///
  /// In pl, this message translates to:
  /// **'Załóż konto'**
  String get authRegisterButton;

  /// No description provided for @authForgotPassword.
  ///
  /// In pl, this message translates to:
  /// **'Nie pamiętam hasła'**
  String get authForgotPassword;

  /// No description provided for @authFooter.
  ///
  /// In pl, this message translates to:
  /// **'Logowanie tylko przez e-mail. Twoje dane są przechowywane w UE (Warszawa).'**
  String get authFooter;

  /// No description provided for @authLoading.
  ///
  /// In pl, this message translates to:
  /// **'Chwileczkę…'**
  String get authLoading;

  /// No description provided for @authEmailRequired.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz adres e-mail'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź adres e-mail'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordRequired.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz hasło'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In pl, this message translates to:
  /// **'Hasło musi mieć co najmniej 8 znaków'**
  String get authPasswordTooShort;

  /// No description provided for @authNicknameLength.
  ///
  /// In pl, this message translates to:
  /// **'Pseudonim musi mieć od 2 do 24 znaków'**
  String get authNicknameLength;

  /// No description provided for @authErrorWrongCredentials.
  ///
  /// In pl, this message translates to:
  /// **'Nieprawidłowy e-mail lub hasło.'**
  String get authErrorWrongCredentials;

  /// No description provided for @authErrorEmailInUse.
  ///
  /// In pl, this message translates to:
  /// **'Ten adres e-mail jest już zajęty. Zaloguj się albo użyj innego.'**
  String get authErrorEmailInUse;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In pl, this message translates to:
  /// **'To hasło jest za słabe. Wybierz dłuższe.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorNetwork.
  ///
  /// In pl, this message translates to:
  /// **'Brak połączenia z internetem. Spróbuj ponownie.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorUnknown.
  ///
  /// In pl, this message translates to:
  /// **'Coś poszło nie tak. Spróbuj ponownie za chwilę.'**
  String get authErrorUnknown;

  /// No description provided for @authResetTitle.
  ///
  /// In pl, this message translates to:
  /// **'Nie pamiętasz hasła?'**
  String get authResetTitle;

  /// No description provided for @authResetBody.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz e-mail, a wyślemy link do ustawienia nowego hasła.'**
  String get authResetBody;

  /// No description provided for @authResetSend.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij'**
  String get authResetSend;

  /// No description provided for @authResetCancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj'**
  String get authResetCancel;

  /// No description provided for @authResetSent.
  ///
  /// In pl, this message translates to:
  /// **'Jeśli konto istnieje, link do zmiany hasła jest już w drodze na {email}.'**
  String authResetSent(String email);

  /// No description provided for @consentsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zanim zaczniesz'**
  String get consentsTitle;

  /// No description provided for @consentsIntro.
  ///
  /// In pl, this message translates to:
  /// **'Zbieramy tylko to, co potrzebne. Zgody zmienisz w każdej chwili w Profilu.'**
  String get consentsIntro;

  /// No description provided for @consentsLocationTitle.
  ///
  /// In pl, this message translates to:
  /// **'Lokalizacja'**
  String get consentsLocationTitle;

  /// No description provided for @consentsLocationBody.
  ///
  /// In pl, this message translates to:
  /// **'Tylko podczas korzystania z aplikacji. Nie zapisujemy trasy spaceru.'**
  String get consentsLocationBody;

  /// No description provided for @consentsLocationRequired.
  ///
  /// In pl, this message translates to:
  /// **'Wymagana do questu'**
  String get consentsLocationRequired;

  /// No description provided for @consentsPushTitle.
  ///
  /// In pl, this message translates to:
  /// **'Powiadomienia'**
  String get consentsPushTitle;

  /// No description provided for @consentsPushBody.
  ///
  /// In pl, this message translates to:
  /// **'Alerty o upale z IMGW i przypomnienia o miejscach chłodu.'**
  String get consentsPushBody;

  /// No description provided for @consentsRankingTitle.
  ///
  /// In pl, this message translates to:
  /// **'Udział w rankingu'**
  String get consentsRankingTitle;

  /// No description provided for @consentsRankingBody.
  ///
  /// In pl, this message translates to:
  /// **'Twój pseudonim i punkty będą widoczne w rankingu dzielnic i użytkowników.'**
  String get consentsRankingBody;

  /// No description provided for @consentsPrivacyLink.
  ///
  /// In pl, this message translates to:
  /// **'Polityka prywatności'**
  String get consentsPrivacyLink;

  /// No description provided for @consentsSystemNote.
  ///
  /// In pl, this message translates to:
  /// **'Po kliknięciu Android zapyta o uprawnienia systemowe.'**
  String get consentsSystemNote;

  /// No description provided for @consentsAccept.
  ///
  /// In pl, this message translates to:
  /// **'Akceptuję i dalej'**
  String get consentsAccept;

  /// No description provided for @consentsSaveError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać zgód. Sprawdź połączenie i spróbuj ponownie.'**
  String get consentsSaveError;

  /// No description provided for @privacyTitle.
  ///
  /// In pl, this message translates to:
  /// **'Polityka prywatności'**
  String get privacyTitle;

  /// No description provided for @privacyDraftNote.
  ///
  /// In pl, this message translates to:
  /// **'Wersja robocza — do sprawdzenia przez zespół.'**
  String get privacyDraftNote;

  /// No description provided for @privacyIntro.
  ///
  /// In pl, this message translates to:
  /// **'Cool Łódź pomaga przejść przez miasto w upał: trasy w cieniu, miejsca chłodu i quest. Zbieramy tylko dane potrzebne do działania aplikacji.'**
  String get privacyIntro;

  /// No description provided for @privacyDataTitle.
  ///
  /// In pl, this message translates to:
  /// **'Jakie dane zbieramy'**
  String get privacyDataTitle;

  /// No description provided for @privacyDataBody.
  ///
  /// In pl, this message translates to:
  /// **'• Adres e-mail — do logowania i zmiany hasła.\n• Pseudonim — widoczny w rankingu, jeśli się na to zgodzisz. Nie podawaj imienia i nazwiska.\n• Dzielnica — do rankingu dzielnic.\n• Ustawienia profilu — preferencje trasy (np. więcej cienia, mniej schodów) i tryb Senior.\n• Punkty, odznaki i zgody z ekranu „Zanim zaczniesz”.\n• Token powiadomień — jeśli włączysz powiadomienia.\n\nNie zbieramy danych o zdrowiu. Profil to tylko preferencje trasy, nie informacja medyczna.'**
  String get privacyDataBody;

  /// No description provided for @privacyLocationTitle.
  ///
  /// In pl, this message translates to:
  /// **'Lokalizacja'**
  String get privacyLocationTitle;

  /// No description provided for @privacyLocationBody.
  ///
  /// In pl, this message translates to:
  /// **'Z lokalizacji korzystamy tylko wtedy, gdy używasz aplikacji: do pokazania Cię na mapie, planowania trasy i potwierdzenia wizyty w questie. Nie zapisujemy trasy spaceru. Przy wizycie w questie zapisujemy tylko miejsce i czas skanu kodu QR.'**
  String get privacyLocationBody;

  /// No description provided for @privacyStorageTitle.
  ///
  /// In pl, this message translates to:
  /// **'Gdzie przechowujemy dane'**
  String get privacyStorageTitle;

  /// No description provided for @privacyStorageBody.
  ///
  /// In pl, this message translates to:
  /// **'Dane konta trzymamy w usłudze Google Firebase (Authentication i Cloud Firestore). Baza danych znajduje się w regionie europe-central2 (Warszawa), czyli w Unii Europejskiej.'**
  String get privacyStorageBody;

  /// No description provided for @privacyRankingTitle.
  ///
  /// In pl, this message translates to:
  /// **'Ranking'**
  String get privacyRankingTitle;

  /// No description provided for @privacyRankingBody.
  ///
  /// In pl, this message translates to:
  /// **'Twój pseudonim i punkty widzą inni użytkownicy tylko wtedy, gdy włączysz udział w rankingu. Możesz to wyłączyć w Profilu.'**
  String get privacyRankingBody;

  /// No description provided for @privacyRightsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Twoje prawa i usunięcie konta'**
  String get privacyRightsTitle;

  /// No description provided for @privacyRightsBody.
  ///
  /// In pl, this message translates to:
  /// **'Zgodnie z RODO możesz poprosić o dostęp do swoich danych, ich poprawienie lub usunięcie oraz w każdej chwili wycofać zgody w Profilu. Usunięcie konta usuwa wszystkie Twoje dokumenty: profil, punkty, odznaki i historię.'**
  String get privacyRightsBody;

  /// No description provided for @privacyContactTitle.
  ///
  /// In pl, this message translates to:
  /// **'Kontakt'**
  String get privacyContactTitle;

  /// No description provided for @privacyContactBody.
  ///
  /// In pl, this message translates to:
  /// **'Administrator danych: zespół Cool Łódź, [nazwa i adres do uzupełnienia]. Pytania o dane: [adres e-mail zespołu do uzupełnienia].'**
  String get privacyContactBody;

  /// No description provided for @profileTitle.
  ///
  /// In pl, this message translates to:
  /// **'Profil komfortu'**
  String get profileTitle;

  /// No description provided for @profileIntro.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz, co jest dla Ciebie ważne na trasie. Zmienisz to w każdej chwili w Profilu.'**
  String get profileIntro;

  /// No description provided for @profileSeniorName.
  ///
  /// In pl, this message translates to:
  /// **'Senior'**
  String get profileSeniorName;

  /// No description provided for @profileSeniorBody.
  ///
  /// In pl, this message translates to:
  /// **'Najwięcej cienia, ławki po drodze i duży tekst'**
  String get profileSeniorBody;

  /// No description provided for @profileTouristName.
  ///
  /// In pl, this message translates to:
  /// **'Turysta'**
  String get profileTouristName;

  /// No description provided for @profileTouristBody.
  ///
  /// In pl, this message translates to:
  /// **'Zabytki w cieniu i chłodne miejsca w pobliżu'**
  String get profileTouristBody;

  /// No description provided for @profileStandardName.
  ///
  /// In pl, this message translates to:
  /// **'Domyślny'**
  String get profileStandardName;

  /// No description provided for @profileStandardBody.
  ///
  /// In pl, this message translates to:
  /// **'Kompromis między czasem a cieniem'**
  String get profileStandardBody;

  /// No description provided for @profileSelected.
  ///
  /// In pl, this message translates to:
  /// **'Wybrany'**
  String get profileSelected;

  /// No description provided for @profileAdjust.
  ///
  /// In pl, this message translates to:
  /// **'Dostosuj'**
  String get profileAdjust;

  /// No description provided for @profileAdjustHint.
  ///
  /// In pl, this message translates to:
  /// **'0 — nieważne, 100 — bardzo ważne'**
  String get profileAdjustHint;

  /// No description provided for @profileWeightShade.
  ///
  /// In pl, this message translates to:
  /// **'Cień'**
  String get profileWeightShade;

  /// No description provided for @profileWeightTime.
  ///
  /// In pl, this message translates to:
  /// **'Czas'**
  String get profileWeightTime;

  /// No description provided for @profileWeightQuiet.
  ///
  /// In pl, this message translates to:
  /// **'Cisza'**
  String get profileWeightQuiet;

  /// No description provided for @profileWeightAir.
  ///
  /// In pl, this message translates to:
  /// **'Powietrze'**
  String get profileWeightAir;

  /// No description provided for @profileSeniorModeTitle.
  ///
  /// In pl, this message translates to:
  /// **'Duży tekst i przyciski'**
  String get profileSeniorModeTitle;

  /// No description provided for @profileSeniorModeBody.
  ///
  /// In pl, this message translates to:
  /// **'Tryb Senior: tekst o 25% większy, większe przyciski i podpisy przy ikonach'**
  String get profileSeniorModeBody;

  /// No description provided for @profileSoonTitle.
  ///
  /// In pl, this message translates to:
  /// **'Wkrótce'**
  String get profileSoonTitle;

  /// No description provided for @profileSoon.
  ///
  /// In pl, this message translates to:
  /// **'Wkrótce'**
  String get profileSoon;

  /// No description provided for @profileDogName.
  ///
  /// In pl, this message translates to:
  /// **'Z psem'**
  String get profileDogName;

  /// No description provided for @profileDogBody.
  ///
  /// In pl, this message translates to:
  /// **'Cień, zieleń i woda dla psa'**
  String get profileDogBody;

  /// No description provided for @profileStrollerName.
  ///
  /// In pl, this message translates to:
  /// **'Z wózkiem'**
  String get profileStrollerName;

  /// No description provided for @profileStrollerBody.
  ///
  /// In pl, this message translates to:
  /// **'Bez schodów, z cieniem i ławkami'**
  String get profileStrollerBody;

  /// No description provided for @profileCommuteName.
  ///
  /// In pl, this message translates to:
  /// **'Do pracy'**
  String get profileCommuteName;

  /// No description provided for @profileCommuteBody.
  ///
  /// In pl, this message translates to:
  /// **'Szybko, ale nie w pełnym słońcu'**
  String get profileCommuteBody;

  /// No description provided for @profileActiveName.
  ///
  /// In pl, this message translates to:
  /// **'Aktywny'**
  String get profileActiveName;

  /// No description provided for @profileActiveBody.
  ///
  /// In pl, this message translates to:
  /// **'Dłuższe trasy przez zieleń'**
  String get profileActiveBody;

  /// No description provided for @profileSensitiveName.
  ///
  /// In pl, this message translates to:
  /// **'Wrażliwy na hałas i smog'**
  String get profileSensitiveName;

  /// No description provided for @profileSensitiveBody.
  ///
  /// In pl, this message translates to:
  /// **'Cisza i czyste powietrze'**
  String get profileSensitiveBody;

  /// No description provided for @profileSave.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz'**
  String get profileSave;

  /// No description provided for @profileContinue.
  ///
  /// In pl, this message translates to:
  /// **'Dalej'**
  String get profileContinue;

  /// No description provided for @profileSaved.
  ///
  /// In pl, this message translates to:
  /// **'Profil zapisany'**
  String get profileSaved;

  /// No description provided for @profileSaveError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać profilu. Sprawdź połączenie i spróbuj ponownie.'**
  String get profileSaveError;

  /// No description provided for @routePlanTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zaplanuj trasę'**
  String get routePlanTitle;

  /// No description provided for @routeFrom.
  ///
  /// In pl, this message translates to:
  /// **'Skąd'**
  String get routeFrom;

  /// No description provided for @routeTo.
  ///
  /// In pl, this message translates to:
  /// **'Dokąd'**
  String get routeTo;

  /// No description provided for @routeToHint.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz cel'**
  String get routeToHint;

  /// No description provided for @routeMyLocation.
  ///
  /// In pl, this message translates to:
  /// **'Moja lokalizacja'**
  String get routeMyLocation;

  /// No description provided for @routeSwap.
  ///
  /// In pl, this message translates to:
  /// **'Zamień start i cel'**
  String get routeSwap;

  /// No description provided for @routeDeparture.
  ///
  /// In pl, this message translates to:
  /// **'Wyjście'**
  String get routeDeparture;

  /// No description provided for @routeDepartNow.
  ///
  /// In pl, this message translates to:
  /// **'Teraz'**
  String get routeDepartNow;

  /// No description provided for @routeDepartPick.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz godzinę'**
  String get routeDepartPick;

  /// No description provided for @routeDepartToday.
  ///
  /// In pl, this message translates to:
  /// **'Dziś, {time}'**
  String routeDepartToday(String time);

  /// No description provided for @routeDepartTomorrow.
  ///
  /// In pl, this message translates to:
  /// **'Jutro, {time}'**
  String routeDepartTomorrow(String time);

  /// No description provided for @routeDepartOn.
  ///
  /// In pl, this message translates to:
  /// **'{date}, {time}'**
  String routeDepartOn(String date, String time);

  /// No description provided for @routeProfileChip.
  ///
  /// In pl, this message translates to:
  /// **'Profil: {name}'**
  String routeProfileChip(String name);

  /// No description provided for @routeProfileChipHint.
  ///
  /// In pl, this message translates to:
  /// **'Zmień profil komfortu'**
  String get routeProfileChipHint;

  /// No description provided for @routeQuickTitle.
  ///
  /// In pl, this message translates to:
  /// **'Szybkie trasy'**
  String get routeQuickTitle;

  /// No description provided for @routeQuickRoute.
  ///
  /// In pl, this message translates to:
  /// **'{from} → {to}'**
  String routeQuickRoute(String from, String to);

  /// No description provided for @routeShowRoutes.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż trasy'**
  String get routeShowRoutes;

  /// No description provided for @routeSearchHint.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj adresu lub miejsca'**
  String get routeSearchHint;

  /// No description provided for @routeSearchFromTitle.
  ///
  /// In pl, this message translates to:
  /// **'Skąd idziesz?'**
  String get routeSearchFromTitle;

  /// No description provided for @routeSearchToTitle.
  ///
  /// In pl, this message translates to:
  /// **'Dokąd idziesz?'**
  String get routeSearchToTitle;

  /// No description provided for @routeSearchPlaces.
  ///
  /// In pl, this message translates to:
  /// **'Miejsca chłodu'**
  String get routeSearchPlaces;

  /// No description provided for @routeSearchAddresses.
  ///
  /// In pl, this message translates to:
  /// **'Adresy w Łodzi'**
  String get routeSearchAddresses;

  /// No description provided for @routeSearchTypeMore.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz co najmniej 3 znaki, aby szukać adresów'**
  String get routeSearchTypeMore;

  /// No description provided for @routeSearchNoResults.
  ///
  /// In pl, this message translates to:
  /// **'Nic nie znaleźliśmy'**
  String get routeSearchNoResults;

  /// No description provided for @routeSearchError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wyszukać adresów. Sprawdź połączenie.'**
  String get routeSearchError;

  /// No description provided for @routeSearchClear.
  ///
  /// In pl, this message translates to:
  /// **'Wyczyść'**
  String get routeSearchClear;

  /// No description provided for @routeSearchAttribution.
  ///
  /// In pl, this message translates to:
  /// **'Wyszukiwanie: © OpenStreetMap (Nominatim)'**
  String get routeSearchAttribution;

  /// No description provided for @routeResultTitle.
  ///
  /// In pl, this message translates to:
  /// **'Trasy'**
  String get routeResultTitle;

  /// No description provided for @routeResultHeader.
  ///
  /// In pl, this message translates to:
  /// **'{from} → {to}'**
  String routeResultHeader(String from, String to);

  /// No description provided for @routeResultDeparture.
  ///
  /// In pl, this message translates to:
  /// **'Wyjście: {time}'**
  String routeResultDeparture(String time);

  /// No description provided for @routeApproximate.
  ///
  /// In pl, this message translates to:
  /// **'Dla tego obszaru cień jest przybliżony'**
  String get routeApproximate;

  /// No description provided for @routeGo.
  ///
  /// In pl, this message translates to:
  /// **'Prowadź'**
  String get routeGo;

  /// No description provided for @routeSave.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz'**
  String get routeSave;

  /// No description provided for @routeSaved.
  ///
  /// In pl, this message translates to:
  /// **'Trasa zapisana. Zobaczysz ją także bez internetu.'**
  String get routeSaved;

  /// No description provided for @routeSaveError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać trasy'**
  String get routeSaveError;

  /// No description provided for @routeMapsError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się otworzyć Map Google'**
  String get routeMapsError;

  /// No description provided for @routeNotFoundTitle.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleźliśmy trasy'**
  String get routeNotFoundTitle;

  /// No description provided for @routeNotFoundBody.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj wybrać inne miejsce startu lub celu.'**
  String get routeNotFoundBody;

  /// No description provided for @routeChangePoints.
  ///
  /// In pl, this message translates to:
  /// **'Zmień punkty'**
  String get routeChangePoints;

  /// No description provided for @routeNoLocationTitle.
  ///
  /// In pl, this message translates to:
  /// **'Nie znamy Twojej lokalizacji'**
  String get routeNoLocationTitle;

  /// No description provided for @routeNoLocationBody.
  ///
  /// In pl, this message translates to:
  /// **'Włącz lokalizację albo wybierz punkt startu ręcznie.'**
  String get routeNoLocationBody;

  /// No description provided for @routeEnableLocation.
  ///
  /// In pl, this message translates to:
  /// **'Włącz lokalizację'**
  String get routeEnableLocation;

  /// No description provided for @routeChooseStart.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz punkt startu'**
  String get routeChooseStart;

  /// No description provided for @routeVariantsPage.
  ///
  /// In pl, this message translates to:
  /// **'Wariant {index} z {count}'**
  String routeVariantsPage(int index, int count);

  /// No description provided for @routePrevVariant.
  ///
  /// In pl, this message translates to:
  /// **'Poprzedni wariant'**
  String get routePrevVariant;

  /// No description provided for @routeNextVariant.
  ///
  /// In pl, this message translates to:
  /// **'Następny wariant'**
  String get routeNextVariant;

  /// No description provided for @routeMapSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Mapa z trzema trasami. Wybrana: {name}, {percent} procent w cieniu.'**
  String routeMapSemantics(String name, int percent);

  /// No description provided for @routeLegendShade.
  ///
  /// In pl, this message translates to:
  /// **'w cieniu'**
  String get routeLegendShade;

  /// No description provided for @routeLegendSun.
  ///
  /// In pl, this message translates to:
  /// **'na słońcu'**
  String get routeLegendSun;

  /// No description provided for @placeCategoryLibrary.
  ///
  /// In pl, this message translates to:
  /// **'Biblioteka'**
  String get placeCategoryLibrary;

  /// No description provided for @placeCategoryMuseum.
  ///
  /// In pl, this message translates to:
  /// **'Muzeum'**
  String get placeCategoryMuseum;

  /// No description provided for @placeCategoryCulture.
  ///
  /// In pl, this message translates to:
  /// **'Kultura'**
  String get placeCategoryCulture;

  /// No description provided for @placeCategoryMall.
  ///
  /// In pl, this message translates to:
  /// **'Centrum handlowe'**
  String get placeCategoryMall;

  /// No description provided for @placeCategoryPark.
  ///
  /// In pl, this message translates to:
  /// **'Park'**
  String get placeCategoryPark;

  /// No description provided for @placeCategoryStation.
  ///
  /// In pl, this message translates to:
  /// **'Dworzec'**
  String get placeCategoryStation;

  /// No description provided for @placeCategoryChurch.
  ///
  /// In pl, this message translates to:
  /// **'Kościół'**
  String get placeCategoryChurch;

  /// No description provided for @placeCategoryOther.
  ///
  /// In pl, this message translates to:
  /// **'Miejsce chłodu'**
  String get placeCategoryOther;

  /// No description provided for @placeWaterName.
  ///
  /// In pl, this message translates to:
  /// **'Poidełko'**
  String get placeWaterName;

  /// No description provided for @placeBenchName.
  ///
  /// In pl, this message translates to:
  /// **'Ławka'**
  String get placeBenchName;

  /// No description provided for @placeOpenUntil.
  ///
  /// In pl, this message translates to:
  /// **'Otwarte teraz · do {time}'**
  String placeOpenUntil(String time);

  /// No description provided for @placeOpenAllDay.
  ///
  /// In pl, this message translates to:
  /// **'Otwarte całą dobę'**
  String get placeOpenAllDay;

  /// No description provided for @placeClosedOpensOn.
  ///
  /// In pl, this message translates to:
  /// **'Zamknięte, otwarcie {day} o {time}'**
  String placeClosedOpensOn(String day, String time);

  /// No description provided for @placeClosed.
  ///
  /// In pl, this message translates to:
  /// **'Zamknięte'**
  String get placeClosed;

  /// No description provided for @placeTomorrow.
  ///
  /// In pl, this message translates to:
  /// **'jutro'**
  String get placeTomorrow;

  /// No description provided for @placeTodayHours.
  ///
  /// In pl, this message translates to:
  /// **'Dziś {hours}'**
  String placeTodayHours(String hours);

  /// No description provided for @placeTodayClosed.
  ///
  /// In pl, this message translates to:
  /// **'Dziś nieczynne'**
  String get placeTodayClosed;

  /// No description provided for @placeDistanceM.
  ///
  /// In pl, this message translates to:
  /// **'{meters} m'**
  String placeDistanceM(int meters);

  /// No description provided for @placeDistanceKm.
  ///
  /// In pl, this message translates to:
  /// **'{km} km'**
  String placeDistanceKm(double km);

  /// No description provided for @placeSourceLink.
  ///
  /// In pl, this message translates to:
  /// **'Źródło godzin otwarcia'**
  String get placeSourceLink;

  /// No description provided for @placeNotFound.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleźliśmy tego miejsca'**
  String get placeNotFound;

  /// No description provided for @mapLayerShade.
  ///
  /// In pl, this message translates to:
  /// **'Cień'**
  String get mapLayerShade;

  /// No description provided for @mapLayerGreen.
  ///
  /// In pl, this message translates to:
  /// **'Zieleń'**
  String get mapLayerGreen;

  /// No description provided for @mapLayerQuiet.
  ///
  /// In pl, this message translates to:
  /// **'Cisza'**
  String get mapLayerQuiet;

  /// No description provided for @mapLayerAir.
  ///
  /// In pl, this message translates to:
  /// **'Powietrze'**
  String get mapLayerAir;

  /// No description provided for @mapLayerWater.
  ///
  /// In pl, this message translates to:
  /// **'Woda'**
  String get mapLayerWater;

  /// No description provided for @mapLayerCool.
  ///
  /// In pl, this message translates to:
  /// **'Miejsca chłodu'**
  String get mapLayerCool;

  /// No description provided for @mapFillLimit.
  ///
  /// In pl, this message translates to:
  /// **'Na mapie mogą być naraz 2 warstwy obszarów. Wyłączyliśmy: {layer}.'**
  String mapFillLimit(String layer);

  /// No description provided for @mapShadeAt.
  ///
  /// In pl, this message translates to:
  /// **'Cień o {time}'**
  String mapShadeAt(String time);

  /// No description provided for @mapShadeChangeTime.
  ///
  /// In pl, this message translates to:
  /// **'Zmień godzinę cienia'**
  String get mapShadeChangeTime;

  /// No description provided for @mapShadeTimeTitle.
  ///
  /// In pl, this message translates to:
  /// **'Cień o godzinie'**
  String get mapShadeTimeTitle;

  /// No description provided for @mapShadeDemoNote.
  ///
  /// In pl, this message translates to:
  /// **'W trybie demo cień jest policzony dla 14:30.'**
  String get mapShadeDemoNote;

  /// No description provided for @mapNoLocationTitle.
  ///
  /// In pl, this message translates to:
  /// **'Nie widzimy Twojej lokalizacji'**
  String get mapNoLocationTitle;

  /// No description provided for @mapNoLocationBody.
  ///
  /// In pl, this message translates to:
  /// **'Pokazujemy Śródmieście.'**
  String get mapNoLocationBody;

  /// No description provided for @mapEnableLocation.
  ///
  /// In pl, this message translates to:
  /// **'Włącz lokalizację'**
  String get mapEnableLocation;

  /// No description provided for @mapMyLocation.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż moją lokalizację'**
  String get mapMyLocation;

  /// No description provided for @mapAlertSubtitle.
  ///
  /// In pl, this message translates to:
  /// **'{source} · do {time}'**
  String mapAlertSubtitle(String source, String time);

  /// No description provided for @mapHeatModeHint.
  ///
  /// In pl, this message translates to:
  /// **'Tryb upału: w najgorętszych godzinach odpocznij w miejscu chłodu'**
  String get mapHeatModeHint;

  /// No description provided for @mapLegendQuiet.
  ///
  /// In pl, this message translates to:
  /// **'Ciemniej = głośniej'**
  String get mapLegendQuiet;

  /// No description provided for @mapLegendAir.
  ///
  /// In pl, this message translates to:
  /// **'Indeks jakości powietrza GIOŚ'**
  String get mapLegendAir;

  /// No description provided for @mapAirVeryGood.
  ///
  /// In pl, this message translates to:
  /// **'Bardzo dobry'**
  String get mapAirVeryGood;

  /// No description provided for @mapAirGood.
  ///
  /// In pl, this message translates to:
  /// **'Dobry'**
  String get mapAirGood;

  /// No description provided for @mapAirModerate.
  ///
  /// In pl, this message translates to:
  /// **'Umiarkowany'**
  String get mapAirModerate;

  /// No description provided for @mapAirSufficient.
  ///
  /// In pl, this message translates to:
  /// **'Dostateczny'**
  String get mapAirSufficient;

  /// No description provided for @mapAirBad.
  ///
  /// In pl, this message translates to:
  /// **'Zły'**
  String get mapAirBad;

  /// No description provided for @mapAirVeryBad.
  ///
  /// In pl, this message translates to:
  /// **'Bardzo zły'**
  String get mapAirVeryBad;

  /// No description provided for @mapAirNoData.
  ///
  /// In pl, this message translates to:
  /// **'Brak danych'**
  String get mapAirNoData;

  /// No description provided for @mapAirStation.
  ///
  /// In pl, this message translates to:
  /// **'{name}: {level}'**
  String mapAirStation(String name, String level);

  /// No description provided for @mapLayerError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać warstwy {layer}'**
  String mapLayerError(String layer);

  /// No description provided for @mapSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Mapa Łodzi. Warstwy: {layers}.'**
  String mapSemantics(String layers);

  /// No description provided for @mapBenchesZoomHint.
  ///
  /// In pl, this message translates to:
  /// **'Ławki widać po przybliżeniu mapy'**
  String get mapBenchesZoomHint;

  /// No description provided for @coolTitle.
  ///
  /// In pl, this message translates to:
  /// **'Miejsca chłodu'**
  String get coolTitle;

  /// No description provided for @coolViewList.
  ///
  /// In pl, this message translates to:
  /// **'Lista'**
  String get coolViewList;

  /// No description provided for @coolViewMap.
  ///
  /// In pl, this message translates to:
  /// **'Mapa'**
  String get coolViewMap;

  /// No description provided for @coolFilterOpen.
  ///
  /// In pl, this message translates to:
  /// **'Otwarte teraz'**
  String get coolFilterOpen;

  /// No description provided for @coolFilterWater.
  ///
  /// In pl, this message translates to:
  /// **'Z wodą'**
  String get coolFilterWater;

  /// No description provided for @coolFilterAccessible.
  ///
  /// In pl, this message translates to:
  /// **'Dostępne'**
  String get coolFilterAccessible;

  /// No description provided for @coolFilterQuest.
  ///
  /// In pl, this message translates to:
  /// **'W queście'**
  String get coolFilterQuest;

  /// No description provided for @coolEmptyTitle.
  ///
  /// In pl, this message translates to:
  /// **'Brak otwartych miejsc w pobliżu'**
  String get coolEmptyTitle;

  /// No description provided for @coolEmptyBody.
  ///
  /// In pl, this message translates to:
  /// **'Zmień filtry, aby zobaczyć więcej miejsc.'**
  String get coolEmptyBody;

  /// No description provided for @coolShowAll.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż wszystkie'**
  String get coolShowAll;

  /// No description provided for @coolNoLocationNote.
  ///
  /// In pl, this message translates to:
  /// **'Odległości od centrum Łodzi — włącz lokalizację, aby liczyć od Ciebie.'**
  String get coolNoLocationNote;

  /// No description provided for @coolLoadError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać miejsc chłodu'**
  String get coolLoadError;

  /// No description provided for @badgeFirstStepName.
  ///
  /// In pl, this message translates to:
  /// **'Pierwszy krok'**
  String get badgeFirstStepName;

  /// No description provided for @badgeFirstStepCondition.
  ///
  /// In pl, this message translates to:
  /// **'Ruszaj pierwszą trasą z «Prowadź»'**
  String get badgeFirstStepCondition;

  /// No description provided for @badgeFirstStepDescription.
  ///
  /// In pl, this message translates to:
  /// **'Pierwsza trasa za Tobą. Dobrze, że wybierasz cień.'**
  String get badgeFirstStepDescription;

  /// No description provided for @badgeShadedTenName.
  ///
  /// In pl, this message translates to:
  /// **'Cienista dziesiątka'**
  String get badgeShadedTenName;

  /// No description provided for @badgeShadedTenCondition.
  ///
  /// In pl, this message translates to:
  /// **'10 tras z co najmniej 60% cienia'**
  String get badgeShadedTenCondition;

  /// No description provided for @badgeShadedTenDescription.
  ///
  /// In pl, this message translates to:
  /// **'Dziesięć tras w cieniu. Twoje stopy i głowa dziękują.'**
  String get badgeShadedTenDescription;

  /// No description provided for @badgeCoolGuardName.
  ///
  /// In pl, this message translates to:
  /// **'Strażnik chłodu'**
  String get badgeCoolGuardName;

  /// No description provided for @badgeCoolGuardCondition.
  ///
  /// In pl, this message translates to:
  /// **'Zeskanuj kody w {count} różnych miejscach chłodu'**
  String badgeCoolGuardCondition(int count);

  /// No description provided for @badgeCoolGuardDescription.
  ///
  /// In pl, this message translates to:
  /// **'Znasz miejsca, w których można odpocząć od upału.'**
  String get badgeCoolGuardDescription;

  /// No description provided for @badgeEarlyBirdName.
  ///
  /// In pl, this message translates to:
  /// **'Ranny ptaszek'**
  String get badgeEarlyBirdName;

  /// No description provided for @badgeEarlyBirdCondition.
  ///
  /// In pl, this message translates to:
  /// **'Trasa z wyjściem 6:00–10:00 w dzień ostrzeżenia przed upałem'**
  String get badgeEarlyBirdCondition;

  /// No description provided for @badgeEarlyBirdDescription.
  ///
  /// In pl, this message translates to:
  /// **'Rano jest chłodniej. Świetny wybór w upalny dzień.'**
  String get badgeEarlyBirdDescription;

  /// No description provided for @badgeEveningName.
  ///
  /// In pl, this message translates to:
  /// **'Wieczorny spacerowicz'**
  String get badgeEveningName;

  /// No description provided for @badgeEveningCondition.
  ///
  /// In pl, this message translates to:
  /// **'Trasa z wyjściem 19:00–22:00 w dzień ostrzeżenia przed upałem'**
  String get badgeEveningCondition;

  /// No description provided for @badgeEveningDescription.
  ///
  /// In pl, this message translates to:
  /// **'Wieczorem upał odpuszcza. Miłego spaceru.'**
  String get badgeEveningDescription;

  /// No description provided for @badgeParkHunterName.
  ///
  /// In pl, this message translates to:
  /// **'Łowca parków'**
  String get badgeParkHunterName;

  /// No description provided for @badgeParkHunterCondition.
  ///
  /// In pl, this message translates to:
  /// **'5 tras kończących się w parku'**
  String get badgeParkHunterCondition;

  /// No description provided for @badgeParkHunterDescription.
  ///
  /// In pl, this message translates to:
  /// **'Pięć tras do parku. Zieleń to najlepszy cień.'**
  String get badgeParkHunterDescription;

  /// No description provided for @badgeCityHelperName.
  ///
  /// In pl, this message translates to:
  /// **'Pomocnik miasta'**
  String get badgeCityHelperName;

  /// No description provided for @badgeCityHelperCondition.
  ///
  /// In pl, this message translates to:
  /// **'3 zatwierdzone zgłoszenia'**
  String get badgeCityHelperCondition;

  /// No description provided for @badgeCityHelperDescription.
  ///
  /// In pl, this message translates to:
  /// **'Dzięki Twoim zgłoszeniom miasto wie, gdzie brakuje cienia i wody.'**
  String get badgeCityHelperDescription;

  /// No description provided for @badgesEarned.
  ///
  /// In pl, this message translates to:
  /// **'Zdobyta'**
  String get badgesEarned;

  /// No description provided for @badgesTotal.
  ///
  /// In pl, this message translates to:
  /// **'Twoje punkty'**
  String get badgesTotal;

  /// No description provided for @badgesTitle.
  ///
  /// In pl, this message translates to:
  /// **'Odznaki'**
  String get badgesTitle;

  /// No description provided for @badgesRecent.
  ///
  /// In pl, this message translates to:
  /// **'Ostatnie punkty'**
  String get badgesRecent;

  /// No description provided for @badgesNoPoints.
  ///
  /// In pl, this message translates to:
  /// **'Nie masz jeszcze punktów. Wybierz trasę w cieniu albo zeskanuj kod QR w miejscu chłodu.'**
  String get badgesNoPoints;

  /// No description provided for @badgesLogRoute.
  ///
  /// In pl, this message translates to:
  /// **'Trasa w cieniu'**
  String get badgesLogRoute;

  /// No description provided for @badgesLogScan.
  ///
  /// In pl, this message translates to:
  /// **'Kod QR w miejscu chłodu'**
  String get badgesLogScan;

  /// No description provided for @badgesLogPassword.
  ///
  /// In pl, this message translates to:
  /// **'Hasło questu'**
  String get badgesLogPassword;

  /// No description provided for @badgesLogBadge.
  ///
  /// In pl, this message translates to:
  /// **'Odznaka: {name}'**
  String badgesLogBadge(String name);

  /// No description provided for @badgesLogReport.
  ///
  /// In pl, this message translates to:
  /// **'Zatwierdzone zgłoszenie'**
  String get badgesLogReport;

  /// No description provided for @badgesLoadError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać punktów'**
  String get badgesLoadError;

  /// No description provided for @gamePointsToast.
  ///
  /// In pl, this message translates to:
  /// **'+{points} pkt'**
  String gamePointsToast(int points);

  /// No description provided for @gameRoutePointsToast.
  ///
  /// In pl, this message translates to:
  /// **'+{points} pkt za trasę w cieniu'**
  String gameRoutePointsToast(int points);

  /// No description provided for @gameHeatNoPoints.
  ///
  /// In pl, this message translates to:
  /// **'W trybie upału trasy z wyjściem 11:00–17:00 nie dają punktów. Wybierz poranek lub wieczór.'**
  String get gameHeatNoPoints;

  /// No description provided for @questTitle.
  ///
  /// In pl, this message translates to:
  /// **'Chłodne hasło'**
  String get questTitle;

  /// No description provided for @questIntro.
  ///
  /// In pl, this message translates to:
  /// **'Odwiedzaj miejsca chłodu, skanuj kody QR przy wejściu i zbieraj litery hasła.'**
  String get questIntro;

  /// No description provided for @questProgress.
  ///
  /// In pl, this message translates to:
  /// **'{found} z {total} liter'**
  String questProgress(int found, int total);

  /// No description provided for @questScan.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj kod QR'**
  String get questScan;

  /// No description provided for @questPlacesTitle.
  ///
  /// In pl, this message translates to:
  /// **'Miejsca questu'**
  String get questPlacesTitle;

  /// No description provided for @questVisited.
  ///
  /// In pl, this message translates to:
  /// **'Odwiedzone'**
  String get questVisited;

  /// No description provided for @questToVisit.
  ///
  /// In pl, this message translates to:
  /// **'Do odwiedzenia'**
  String get questToVisit;

  /// No description provided for @questLetterOf.
  ///
  /// In pl, this message translates to:
  /// **'Litera {letter}'**
  String questLetterOf(String letter);

  /// No description provided for @questHeatHint.
  ///
  /// In pl, this message translates to:
  /// **'Dziś odwiedzaj miejsca rano lub wieczorem'**
  String get questHeatHint;

  /// No description provided for @questHeatHidden.
  ///
  /// In pl, this message translates to:
  /// **'W trybie upału ukrywamy miejsca na słońcu: {count}'**
  String questHeatHidden(int count);

  /// No description provided for @questPasswordTitle.
  ///
  /// In pl, this message translates to:
  /// **'Masz wszystkie litery!'**
  String get questPasswordTitle;

  /// No description provided for @questPasswordHint.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz hasło'**
  String get questPasswordHint;

  /// No description provided for @questPasswordCheck.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź'**
  String get questPasswordCheck;

  /// No description provided for @questPasswordWrong.
  ///
  /// In pl, this message translates to:
  /// **'To nie to hasło. Ułóż litery w kolejności miejsc.'**
  String get questPasswordWrong;

  /// No description provided for @questRewardTitle.
  ///
  /// In pl, this message translates to:
  /// **'Hasło odgadnięte!'**
  String get questRewardTitle;

  /// No description provided for @questRewardBody.
  ///
  /// In pl, this message translates to:
  /// **'Twój kod zniżki na przejazd MPK Łódź:'**
  String get questRewardBody;

  /// No description provided for @questRewardNote.
  ///
  /// In pl, this message translates to:
  /// **'Zachowaj go — przyda się przy zakupie biletu.'**
  String get questRewardNote;

  /// No description provided for @questLoadError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać questu'**
  String get questLoadError;

  /// No description provided for @scanTitle.
  ///
  /// In pl, this message translates to:
  /// **'Skaner QR'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In pl, this message translates to:
  /// **'Zeskanuj kod przy wejściu'**
  String get scanHint;

  /// No description provided for @scanChecking.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdzamy kod…'**
  String get scanChecking;

  /// No description provided for @scanSuccess.
  ///
  /// In pl, this message translates to:
  /// **'Nowa litera: {letter}'**
  String scanSuccess(String letter);

  /// No description provided for @scanBackToQuest.
  ///
  /// In pl, this message translates to:
  /// **'Wróć do questu'**
  String get scanBackToQuest;

  /// No description provided for @scanAgain.
  ///
  /// In pl, this message translates to:
  /// **'Skanuj ponownie'**
  String get scanAgain;

  /// No description provided for @scanTooFar.
  ///
  /// In pl, this message translates to:
  /// **'Jesteś za daleko od miejsca'**
  String get scanTooFar;

  /// No description provided for @scanTooFarDetail.
  ///
  /// In pl, this message translates to:
  /// **'Podejdź bliżej wejścia (jesteś {meters} m od miejsca, potrzeba do 150 m).'**
  String scanTooFarDetail(int meters);

  /// No description provided for @scanAlreadyToday.
  ///
  /// In pl, this message translates to:
  /// **'Ten kod już dziś zeskanowałeś'**
  String get scanAlreadyToday;

  /// No description provided for @scanInvalid.
  ///
  /// In pl, this message translates to:
  /// **'Kod nieważny'**
  String get scanInvalid;

  /// No description provided for @scanNoLocation.
  ///
  /// In pl, this message translates to:
  /// **'Włącz lokalizację, aby potwierdzić wizytę w miejscu'**
  String get scanNoLocation;

  /// No description provided for @scanFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać wizyty. Sprawdź połączenie i spróbuj ponownie.'**
  String get scanFailed;

  /// No description provided for @scanNoCameraTitle.
  ///
  /// In pl, this message translates to:
  /// **'Potrzebujemy aparatu'**
  String get scanNoCameraTitle;

  /// No description provided for @scanNoCameraBody.
  ///
  /// In pl, this message translates to:
  /// **'Aparat służy tylko do odczytania kodu QR. Zdjęcia nie są zapisywane.'**
  String get scanNoCameraBody;

  /// No description provided for @scanOpenSettings.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz ustawienia'**
  String get scanOpenSettings;

  /// No description provided for @scanCameraError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się uruchomić aparatu'**
  String get scanCameraError;

  /// No description provided for @rankingDistricts.
  ///
  /// In pl, this message translates to:
  /// **'Dzielnice'**
  String get rankingDistricts;

  /// No description provided for @rankingUsers.
  ///
  /// In pl, this message translates to:
  /// **'Użytkownicy'**
  String get rankingUsers;

  /// No description provided for @rankingWeek.
  ///
  /// In pl, this message translates to:
  /// **'Ten tydzień'**
  String get rankingWeek;

  /// No description provided for @rankingSummer.
  ///
  /// In pl, this message translates to:
  /// **'Całe lato'**
  String get rankingSummer;

  /// No description provided for @rankingEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Na razie nikt nie ma tu punktów. Zacznij od trasy w cieniu!'**
  String get rankingEmpty;

  /// No description provided for @rankingNoConsent.
  ///
  /// In pl, this message translates to:
  /// **'Nie bierzesz udziału w rankingu. Możesz to zmienić w Profilu → Zgody i prywatność.'**
  String get rankingNoConsent;

  /// No description provided for @rankingNoDistrict.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz dzielnicę w Profilu, aby Twoje punkty liczyły się także dla niej.'**
  String get rankingNoDistrict;

  /// No description provided for @rankingLoadError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać rankingu'**
  String get rankingLoadError;

  /// No description provided for @alertTitle.
  ///
  /// In pl, this message translates to:
  /// **'Alert upałowy'**
  String get alertTitle;

  /// No description provided for @alertHeading.
  ///
  /// In pl, this message translates to:
  /// **'Ostrzeżenie przed upałem {level}. stopnia'**
  String alertHeading(int level);

  /// No description provided for @alertPeriod.
  ///
  /// In pl, this message translates to:
  /// **'{area} · {from}–{to}'**
  String alertPeriod(String area, String from, String to);

  /// No description provided for @alertToday.
  ///
  /// In pl, this message translates to:
  /// **'{area} · dziś'**
  String alertToday(String area);

  /// No description provided for @alertSource.
  ///
  /// In pl, this message translates to:
  /// **'Źródło: {source}'**
  String alertSource(String source);

  /// No description provided for @alertWhatToDo.
  ///
  /// In pl, this message translates to:
  /// **'Co robić'**
  String get alertWhatToDo;

  /// No description provided for @alertTip1.
  ///
  /// In pl, this message translates to:
  /// **'Pij wodę regularnie, nie czekaj, aż poczujesz pragnienie.'**
  String get alertTip1;

  /// No description provided for @alertTip2.
  ///
  /// In pl, this message translates to:
  /// **'W najcieplejszych godzinach wybieraj trasy w cieniu i rób przerwy w chłodnych miejscach.'**
  String get alertTip2;

  /// No description provided for @alertTip3.
  ///
  /// In pl, this message translates to:
  /// **'Zadzwoń do starszych bliskich lub sąsiadów i zapytaj, czy czegoś nie potrzebują.'**
  String get alertTip3;

  /// No description provided for @alertOfficial.
  ///
  /// In pl, this message translates to:
  /// **'Oficjalne zalecenia'**
  String get alertOfficial;

  /// No description provided for @alertShowCool.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż miejsca chłodu'**
  String get alertShowCool;

  /// No description provided for @alertHeatModeTitle.
  ///
  /// In pl, this message translates to:
  /// **'Tryb upału'**
  String get alertHeatModeTitle;

  /// No description provided for @alertHeatModeBody.
  ///
  /// In pl, this message translates to:
  /// **'Trasy z wyjściem 11:00–17:00 nie dają dziś punktów, a quest ukrywa miejsca na słońcu. Miejsca chłodu są otwarte jak zwykle.'**
  String get alertHeatModeBody;

  /// No description provided for @alertNone.
  ///
  /// In pl, this message translates to:
  /// **'Brak ostrzeżeń przed upałem'**
  String get alertNone;

  /// No description provided for @alertNoneBody.
  ///
  /// In pl, this message translates to:
  /// **'Gdy IMGW ogłosi ostrzeżenie dla Łodzi, zobaczysz je tutaj.'**
  String get alertNoneBody;

  /// No description provided for @alertPushFallback.
  ///
  /// In pl, this message translates to:
  /// **'Ostrzeżenie przed upałem w Łodzi. Zobacz trasy w cieniu.'**
  String get alertPushFallback;

  /// No description provided for @alertSee.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz'**
  String get alertSee;

  /// No description provided for @alertOpenError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się otworzyć strony'**
  String get alertOpenError;

  /// No description provided for @settingsTitle.
  ///
  /// In pl, this message translates to:
  /// **'Profil'**
  String get settingsTitle;

  /// No description provided for @settingsDistrict.
  ///
  /// In pl, this message translates to:
  /// **'Dzielnica'**
  String get settingsDistrict;

  /// No description provided for @settingsDistrictNone.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz dzielnicę'**
  String get settingsDistrictNone;

  /// No description provided for @settingsDistrictTitle.
  ///
  /// In pl, this message translates to:
  /// **'Twoja dzielnica'**
  String get settingsDistrictTitle;

  /// No description provided for @settingsDistrictHint.
  ///
  /// In pl, this message translates to:
  /// **'Twoje punkty liczą się też dla dzielnicy w rankingu.'**
  String get settingsDistrictHint;

  /// No description provided for @settingsPoints.
  ///
  /// In pl, this message translates to:
  /// **'Punkty'**
  String get settingsPoints;

  /// No description provided for @settingsComfort.
  ///
  /// In pl, this message translates to:
  /// **'Mój profil komfortu'**
  String get settingsComfort;

  /// No description provided for @settingsSenior.
  ///
  /// In pl, this message translates to:
  /// **'Duży tekst i przyciski (tryb Senior)'**
  String get settingsSenior;

  /// No description provided for @settingsNotifications.
  ///
  /// In pl, this message translates to:
  /// **'Powiadomienia o upale'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsBody.
  ///
  /// In pl, this message translates to:
  /// **'Ostrzeżenia IMGW dla Łodzi'**
  String get settingsNotificationsBody;

  /// No description provided for @settingsConsents.
  ///
  /// In pl, this message translates to:
  /// **'Zgody i prywatność'**
  String get settingsConsents;

  /// No description provided for @settingsPrivacy.
  ///
  /// In pl, this message translates to:
  /// **'Polityka prywatności'**
  String get settingsPrivacy;

  /// No description provided for @settingsAbout.
  ///
  /// In pl, this message translates to:
  /// **'O aplikacji i źródła danych'**
  String get settingsAbout;

  /// No description provided for @settingsSignOut.
  ///
  /// In pl, this message translates to:
  /// **'Wyloguj'**
  String get settingsSignOut;

  /// No description provided for @settingsDelete.
  ///
  /// In pl, this message translates to:
  /// **'Usuń konto'**
  String get settingsDelete;

  /// No description provided for @settingsSaveError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać zmian. Sprawdź połączenie.'**
  String get settingsSaveError;

  /// No description provided for @settingsDeleteTitle.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć konto?'**
  String get settingsDeleteTitle;

  /// No description provided for @settingsDeleteBody.
  ///
  /// In pl, this message translates to:
  /// **'Usuniemy Twój profil, punkty, odznaki, historię tras, wizyt i zgłoszeń. Tego nie da się cofnąć. Wpisz hasło, aby potwierdzić.'**
  String get settingsDeleteBody;

  /// No description provided for @settingsDeletePassword.
  ///
  /// In pl, this message translates to:
  /// **'Hasło'**
  String get settingsDeletePassword;

  /// No description provided for @settingsDeleteConfirm.
  ///
  /// In pl, this message translates to:
  /// **'Usuń na zawsze'**
  String get settingsDeleteConfirm;

  /// No description provided for @settingsDeleteCancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj'**
  String get settingsDeleteCancel;

  /// No description provided for @settingsDeleteWrongPassword.
  ///
  /// In pl, this message translates to:
  /// **'Nieprawidłowe hasło'**
  String get settingsDeleteWrongPassword;

  /// No description provided for @settingsDeleteError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się usunąć konta. Sprawdź połączenie i spróbuj ponownie.'**
  String get settingsDeleteError;

  /// No description provided for @settingsDeleted.
  ///
  /// In pl, this message translates to:
  /// **'Konto zostało usunięte'**
  String get settingsDeleted;

  /// No description provided for @settingsConsentsSave.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz'**
  String get settingsConsentsSave;

  /// No description provided for @settingsConsentsSaved.
  ///
  /// In pl, this message translates to:
  /// **'Zapisano'**
  String get settingsConsentsSaved;

  /// No description provided for @aboutTitle.
  ///
  /// In pl, this message translates to:
  /// **'O aplikacji'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In pl, this message translates to:
  /// **'Wersja {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutDescription.
  ///
  /// In pl, this message translates to:
  /// **'Cool Łódź prowadzi przez cień, zieleń i ciche ulice, pokazuje miejsca chłodu i wodę. Projekt zespołu Better Than Never na Hackathon Future Smart City 2026.'**
  String get aboutDescription;

  /// No description provided for @aboutMedical.
  ///
  /// In pl, this message translates to:
  /// **'Aplikacja nie jest wyrobem medycznym. W razie złego samopoczucia dzwoń 112.'**
  String get aboutMedical;

  /// No description provided for @aboutSources.
  ///
  /// In pl, this message translates to:
  /// **'Źródła danych'**
  String get aboutSources;

  /// No description provided for @aboutSourceMap.
  ///
  /// In pl, this message translates to:
  /// **'Mapa: © OpenStreetMap contributors, © CARTO'**
  String get aboutSourceMap;

  /// No description provided for @aboutSourceSearch.
  ///
  /// In pl, this message translates to:
  /// **'Wyszukiwanie adresów: OpenStreetMap Nominatim'**
  String get aboutSourceSearch;

  /// No description provided for @aboutSourceAlerts.
  ///
  /// In pl, this message translates to:
  /// **'Ostrzeżenia przed upałem: IMGW-PIB'**
  String get aboutSourceAlerts;

  /// No description provided for @aboutSourceAir.
  ///
  /// In pl, this message translates to:
  /// **'Jakość powietrza: GIOŚ'**
  String get aboutSourceAir;

  /// No description provided for @aboutSourceShade.
  ///
  /// In pl, this message translates to:
  /// **'Cień, zieleń i hałas: obliczenia Cool Łódź na danych OpenStreetMap i miejskich'**
  String get aboutSourceShade;

  /// No description provided for @aboutSourcePlaces.
  ///
  /// In pl, this message translates to:
  /// **'Miejsca chłodu: zebrane przez zespół, godziny ze stron miejsc'**
  String get aboutSourcePlaces;

  /// No description provided for @aboutLicenses.
  ///
  /// In pl, this message translates to:
  /// **'Licencje'**
  String get aboutLicenses;

  /// No description provided for @aboutDemoTapsLeft.
  ///
  /// In pl, this message translates to:
  /// **'Jeszcze {count} — tryb demo'**
  String aboutDemoTapsLeft(int count);

  /// No description provided for @aboutDemoMode.
  ///
  /// In pl, this message translates to:
  /// **'Tryb demo'**
  String get aboutDemoMode;

  /// No description provided for @aboutDemoModeBody.
  ///
  /// In pl, this message translates to:
  /// **'Trasy, miejsca i alerty z danych zapisanych w aplikacji, bez serwera.'**
  String get aboutDemoModeBody;

  /// No description provided for @aboutDemoAlert.
  ///
  /// In pl, this message translates to:
  /// **'Alert w trybie demo'**
  String get aboutDemoAlert;

  /// No description provided for @aboutDemoAlertNone.
  ///
  /// In pl, this message translates to:
  /// **'Brak'**
  String get aboutDemoAlertNone;

  /// No description provided for @aboutDemoAlertLevel.
  ///
  /// In pl, this message translates to:
  /// **'Stopień {level}'**
  String aboutDemoAlertLevel(int level);

  /// No description provided for @routeBestTimeTitle.
  ///
  /// In pl, this message translates to:
  /// **'Najlepsza pora wyjścia'**
  String get routeBestTimeTitle;

  /// No description provided for @routeBestTimeHint.
  ///
  /// In pl, this message translates to:
  /// **'Najwięcej cienia o {time}: {percent}%'**
  String routeBestTimeHint(String time, int percent);

  /// No description provided for @routeBestTimeSlider.
  ///
  /// In pl, this message translates to:
  /// **'Wyjście o {time}, {percent} procent trasy w cieniu'**
  String routeBestTimeSlider(String time, int percent);

  /// No description provided for @routeBestTimeChart.
  ///
  /// In pl, this message translates to:
  /// **'Udział cienia w ciągu dnia dla wybranej trasy'**
  String get routeBestTimeChart;

  /// No description provided for @reportTitle.
  ///
  /// In pl, this message translates to:
  /// **'Zgłoś problem'**
  String get reportTitle;

  /// No description provided for @reportTypeTitle.
  ///
  /// In pl, this message translates to:
  /// **'Czego brakuje?'**
  String get reportTypeTitle;

  /// No description provided for @reportNoBench.
  ///
  /// In pl, this message translates to:
  /// **'Brak ławki'**
  String get reportNoBench;

  /// No description provided for @reportNoWater.
  ///
  /// In pl, this message translates to:
  /// **'Brak poidełka'**
  String get reportNoWater;

  /// No description provided for @reportNoShade.
  ///
  /// In pl, this message translates to:
  /// **'Brak cienia'**
  String get reportNoShade;

  /// No description provided for @reportOther.
  ///
  /// In pl, this message translates to:
  /// **'Inne'**
  String get reportOther;

  /// No description provided for @reportWhere.
  ///
  /// In pl, this message translates to:
  /// **'Gdzie?'**
  String get reportWhere;

  /// No description provided for @reportWhereHint.
  ///
  /// In pl, this message translates to:
  /// **'Przesuń mapę, aby ustawić pinezkę dokładnie w miejscu problemu.'**
  String get reportWhereHint;

  /// No description provided for @reportComment.
  ///
  /// In pl, this message translates to:
  /// **'Komentarz (opcjonalnie)'**
  String get reportComment;

  /// No description provided for @reportSend.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij zgłoszenie'**
  String get reportSend;

  /// No description provided for @reportChooseType.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz rodzaj problemu'**
  String get reportChooseType;

  /// No description provided for @reportThanksTitle.
  ///
  /// In pl, this message translates to:
  /// **'Dziękujemy!'**
  String get reportThanksTitle;

  /// No description provided for @reportThanksBody.
  ///
  /// In pl, this message translates to:
  /// **'+20 pkt po zatwierdzeniu'**
  String get reportThanksBody;

  /// No description provided for @reportBack.
  ///
  /// In pl, this message translates to:
  /// **'Wróć'**
  String get reportBack;

  /// No description provided for @reportError.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wysłać zgłoszenia. Sprawdź połączenie i spróbuj ponownie.'**
  String get reportError;

  /// No description provided for @reportMapSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Mapa z pinezką zgłoszenia'**
  String get reportMapSemantics;
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
