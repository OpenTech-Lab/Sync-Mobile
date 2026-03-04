import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get appTitle;

  /// No description provided for @loadingSync.
  ///
  /// In en, this message translates to:
  /// **'sync'**
  String get loadingSync;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'ERROR'**
  String get errorTitle;

  /// No description provided for @restartAppHint.
  ///
  /// In en, this message translates to:
  /// **'please restart the app'**
  String get restartAppHint;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'home'**
  String get tabHome;

  /// No description provided for @tabChats.
  ///
  /// In en, this message translates to:
  /// **'chats'**
  String get tabChats;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'settings'**
  String get tabSettings;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageTraditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'Traditional Chinese'**
  String get languageTraditionalChinese;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Sync'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to your planet server to get started.'**
  String get welcomeSubtitle;

  /// No description provided for @serverUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'SERVER URL'**
  String get serverUrlLabel;

  /// No description provided for @serverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://my-planet.example.com'**
  String get serverUrlHint;

  /// No description provided for @quickConnectLabel.
  ///
  /// In en, this message translates to:
  /// **'QUICK CONNECT'**
  String get quickConnectLabel;

  /// No description provided for @checkingConnection.
  ///
  /// In en, this message translates to:
  /// **'checking…'**
  String get checkingConnection;

  /// No description provided for @checkConnectionAction.
  ///
  /// In en, this message translates to:
  /// **'C H E C K   C O N N E C T I O N'**
  String get checkConnectionAction;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'C O N T I N U E'**
  String get continueAction;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed.'**
  String get connectionFailed;

  /// No description provided for @connectedStatus.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get connectedStatus;

  /// No description provided for @secureStatus.
  ///
  /// In en, this message translates to:
  /// **'secure'**
  String get secureStatus;

  /// No description provided for @publicStatus.
  ///
  /// In en, this message translates to:
  /// **'public'**
  String get publicStatus;

  /// No description provided for @latencyValue.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String latencyValue(String ms);

  /// No description provided for @planetCardHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get planetCardHost;

  /// No description provided for @planetCardCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get planetCardCountry;

  /// No description provided for @planetCardProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get planetCardProtocol;

  /// No description provided for @planetCardLatency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get planetCardLatency;

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'Your private messenger'**
  String get authTagline;

  /// No description provided for @signInTab.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTab;

  /// No description provided for @signUpTab.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUpTab;

  /// No description provided for @accountFoundForServer.
  ///
  /// In en, this message translates to:
  /// **'Account found for this server'**
  String get accountFoundForServer;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSentHint.
  ///
  /// In en, this message translates to:
  /// **'If that email is registered, a reset link was sent.'**
  String get resetPasswordSentHint;

  /// No description provided for @resetPasswordEnterEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send a reset link.'**
  String get resetPasswordEnterEmailHint;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @passwordMin8Label.
  ///
  /// In en, this message translates to:
  /// **'Password · min 8 characters'**
  String get passwordMin8Label;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'close'**
  String get actionClose;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'S E N D'**
  String get actionSend;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @signingInProgress.
  ///
  /// In en, this message translates to:
  /// **'signing in…'**
  String get signingInProgress;

  /// No description provided for @signInAction.
  ///
  /// In en, this message translates to:
  /// **'S I G N   I N'**
  String get signInAction;

  /// No description provided for @creatingAccountProgress.
  ///
  /// In en, this message translates to:
  /// **'creating account…'**
  String get creatingAccountProgress;

  /// No description provided for @createAccountAction.
  ///
  /// In en, this message translates to:
  /// **'C R E A T E   A C C O U N T'**
  String get createAccountAction;

  /// No description provided for @myProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfileTitle;

  /// No description provided for @friendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends ({count})'**
  String friendsTitle(int count);

  /// No description provided for @noFriendsYet.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get noFriendsYet;

  /// No description provided for @openChatsHint.
  ///
  /// In en, this message translates to:
  /// **'Open Chats and start a conversation'**
  String get openChatsHint;

  /// No description provided for @friendRemoved.
  ///
  /// In en, this message translates to:
  /// **'Friend removed'**
  String get friendRemoved;

  /// No description provided for @friendAdded.
  ///
  /// In en, this message translates to:
  /// **'Friend added'**
  String get friendAdded;

  /// No description provided for @settingsMyPlanet.
  ///
  /// In en, this message translates to:
  /// **'My Planet'**
  String get settingsMyPlanet;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'THEME'**
  String get settingsTheme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsEncryptedBackups.
  ///
  /// In en, this message translates to:
  /// **'Encrypted Backups'**
  String get settingsEncryptedBackups;

  /// No description provided for @settingsEnableBackups.
  ///
  /// In en, this message translates to:
  /// **'Enable backups'**
  String get settingsEnableBackups;

  /// No description provided for @settingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted on planet server'**
  String get settingsBackupSubtitle;

  /// No description provided for @settingsCreateBackup.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get settingsCreateBackup;

  /// No description provided for @settingsRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get settingsRestore;

  /// No description provided for @settingsDeleteBackupData.
  ///
  /// In en, this message translates to:
  /// **'Delete backup data'**
  String get settingsDeleteBackupData;

  /// No description provided for @settingsLocalData.
  ///
  /// In en, this message translates to:
  /// **'Local Data'**
  String get settingsLocalData;

  /// No description provided for @settingsDeleteAllLocalChats.
  ///
  /// In en, this message translates to:
  /// **'Delete all local chat data'**
  String get settingsDeleteAllLocalChats;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatToday;

  /// No description provided for @chatUnreadHeader.
  ///
  /// In en, this message translates to:
  /// **'UNREAD'**
  String get chatUnreadHeader;

  /// No description provided for @chatChatsHeader.
  ///
  /// In en, this message translates to:
  /// **'CHATS'**
  String get chatChatsHeader;

  /// No description provided for @chatNoChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet.'**
  String get chatNoChatsYet;

  /// No description provided for @chatNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.\nSay hello!'**
  String get chatNoMessagesYet;

  /// No description provided for @chatSearchHint.
  ///
  /// In en, this message translates to:
  /// **'search…'**
  String get chatSearchHint;

  /// No description provided for @chatMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get chatMessageHint;

  /// No description provided for @chatAttachImageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attach image'**
  String get chatAttachImageTooltip;

  /// No description provided for @chatStickersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get chatStickersTooltip;

  /// No description provided for @chatNoStickersYet.
  ///
  /// In en, this message translates to:
  /// **'No stickers yet.'**
  String get chatNoStickersYet;

  /// No description provided for @chatStickersHeader.
  ///
  /// In en, this message translates to:
  /// **'STICKERS'**
  String get chatStickersHeader;

  /// No description provided for @chatMore.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get chatMore;

  /// No description provided for @chatMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'mark all read'**
  String get chatMarkAllRead;

  /// No description provided for @chatMarkedAllAsRead.
  ///
  /// In en, this message translates to:
  /// **'Marked all as read'**
  String get chatMarkedAllAsRead;

  /// No description provided for @chatTypingIndicator.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing…'**
  String chatTypingIndicator(String name);

  /// No description provided for @chatDefaultPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get chatDefaultPartner;

  /// No description provided for @chatDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatDefaultTitle;

  /// No description provided for @chatAddFriendHeader.
  ///
  /// In en, this message translates to:
  /// **'ADD FRIEND'**
  String get chatAddFriendHeader;

  /// No description provided for @chatAddFriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a friend link or user ID'**
  String get chatAddFriendTitle;

  /// No description provided for @chatAddFriendFormatHint.
  ///
  /// In en, this message translates to:
  /// **'Supported format: https://server.tld/<user-id>'**
  String get chatAddFriendFormatHint;

  /// No description provided for @chatAddFriendInputHint.
  ///
  /// In en, this message translates to:
  /// **'friend link or user ID'**
  String get chatAddFriendInputHint;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get actionCancel;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'N E X T'**
  String get actionNext;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh': {
  switch (locale.countryCode) {
    case 'TW': return AppLocalizationsZhTw();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
