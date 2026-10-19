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

  /// No description provided for @placeholderInProgress.
  ///
  /// In pl, this message translates to:
  /// **'Ekran w budowie'**
  String get placeholderInProgress;

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
