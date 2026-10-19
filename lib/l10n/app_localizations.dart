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
