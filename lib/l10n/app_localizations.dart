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

  /// No description provided for @tabPlanet.
  ///
  /// In en, this message translates to:
  /// **'planet'**
  String get tabPlanet;

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

  /// No description provided for @authQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with QR'**
  String get authQrTitle;

  /// No description provided for @authQrHint.
  ///
  /// In en, this message translates to:
  /// **'Open Sync on your phone and scan this code from My Profile.'**
  String get authQrHint;

  /// No description provided for @authQrWaitingForScan.
  ///
  /// In en, this message translates to:
  /// **'waiting for phone approval…'**
  String get authQrWaitingForScan;

  /// No description provided for @authQrExpired.
  ///
  /// In en, this message translates to:
  /// **'QR expired. refresh to continue.'**
  String get authQrExpired;

  /// No description provided for @authQrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'QR login unavailable. try refresh.'**
  String get authQrUnavailable;

  /// No description provided for @authQrPressRefresh.
  ///
  /// In en, this message translates to:
  /// **'please press refresh'**
  String get authQrPressRefresh;

  /// No description provided for @authQrRefresh.
  ///
  /// In en, this message translates to:
  /// **'refresh qr'**
  String get authQrRefresh;

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

  /// No description provided for @homeConnectedPlanetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected Planets'**
  String get homeConnectedPlanetsTitle;

  /// No description provided for @planetOtherPlanetsTitle.
  ///
  /// In en, this message translates to:
  /// **'OTHER PLANETS'**
  String get planetOtherPlanetsTitle;

  /// No description provided for @homeConnectedPlanetsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No connected planets yet'**
  String get homeConnectedPlanetsEmpty;

  /// No description provided for @homeConnectedPlanetsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading connected planets…'**
  String get homeConnectedPlanetsLoading;

  /// No description provided for @homeConnectedPlanetsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load connected planets'**
  String get homeConnectedPlanetsLoadFailed;

  /// No description provided for @homePlanetMembers.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String homePlanetMembers(int count);

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

  /// No description provided for @planetLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading planet data…'**
  String get planetLoading;

  /// No description provided for @planetLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load planet data.'**
  String get planetLoadFailed;

  /// No description provided for @planetNewsTitle.
  ///
  /// In en, this message translates to:
  /// **'MY PLAENT'**
  String get planetNewsTitle;

  /// No description provided for @planetNewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No server news yet'**
  String get planetNewsEmpty;

  /// No description provided for @planetNewsDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get planetNewsDetailTitle;

  /// No description provided for @planetStickersTitle.
  ///
  /// In en, this message translates to:
  /// **'PLANET STICKERS'**
  String get planetStickersTitle;

  /// No description provided for @planetStickerDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get planetStickerDownload;

  /// No description provided for @planetStickerDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get planetStickerDownloaded;

  /// No description provided for @planetStickerDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get planetStickerDownloading;

  /// No description provided for @planetStickerDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download sticker.'**
  String get planetStickerDownloadFailed;

  /// No description provided for @planetStickerDownloadedToast.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {name} to local stickers.'**
  String planetStickerDownloadedToast(String name);

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

  /// No description provided for @settingsTypingStyleMode.
  ///
  /// In en, this message translates to:
  /// **'Typing style mode'**
  String get settingsTypingStyleMode;

  /// No description provided for @settingsTypingStyleModeHint.
  ///
  /// In en, this message translates to:
  /// **'Show messages with a typing animation'**
  String get settingsTypingStyleModeHint;

  /// No description provided for @settingsTypingStyleSpeed.
  ///
  /// In en, this message translates to:
  /// **'Typing speed'**
  String get settingsTypingStyleSpeed;

  /// No description provided for @settingsTypingStyleSpeedHint.
  ///
  /// In en, this message translates to:
  /// **'Lower is faster'**
  String get settingsTypingStyleSpeedHint;

  /// No description provided for @settingsTypingStyleSpeedValue.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms / char'**
  String settingsTypingStyleSpeedValue(int ms);

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

  /// No description provided for @chatMarkReadPartial.
  ///
  /// In en, this message translates to:
  /// **'Marked as read for {success}/{total} conversations'**
  String chatMarkReadPartial(int success, int total);

  /// No description provided for @chatSelectedMediaFallback.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get chatSelectedMediaFallback;

  /// No description provided for @chatMessageDetailTitleMine.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get chatMessageDetailTitleMine;

  /// No description provided for @chatMessageDetailTitleOther.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatMessageDetailTitleOther;

  /// No description provided for @chatCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get chatCopiedToClipboard;

  /// No description provided for @chatQuickNewHeader.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get chatQuickNewHeader;

  /// No description provided for @chatQuickFriendOrStart.
  ///
  /// In en, this message translates to:
  /// **'friend / start chat'**
  String get chatQuickFriendOrStart;

  /// No description provided for @chatQuickScanFriendQr.
  ///
  /// In en, this message translates to:
  /// **'scan friend qr'**
  String get chatQuickScanFriendQr;

  /// No description provided for @chatScanFriendQrInstruction.
  ///
  /// In en, this message translates to:
  /// **'point camera at a friend\'s qr code'**
  String get chatScanFriendQrInstruction;

  /// No description provided for @chatTargetCancelFriend.
  ///
  /// In en, this message translates to:
  /// **'cancel friend'**
  String get chatTargetCancelFriend;

  /// No description provided for @chatTargetAddFriend.
  ///
  /// In en, this message translates to:
  /// **'A D D   F R I E N D'**
  String get chatTargetAddFriend;

  /// No description provided for @chatTargetFriend.
  ///
  /// In en, this message translates to:
  /// **'friend'**
  String get chatTargetFriend;

  /// No description provided for @chatTargetStartChat.
  ///
  /// In en, this message translates to:
  /// **'S T A R T   C H A T'**
  String get chatTargetStartChat;

  /// No description provided for @chatTargetFriendSince.
  ///
  /// In en, this message translates to:
  /// **'FRIEND SINCE'**
  String get chatTargetFriendSince;

  /// No description provided for @chatTargetMessagesSent.
  ///
  /// In en, this message translates to:
  /// **'MESSAGES SENT'**
  String get chatTargetMessagesSent;

  /// No description provided for @chatTargetAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get chatTargetAbout;

  /// No description provided for @settingsMissingAccessTokenBackup.
  ///
  /// In en, this message translates to:
  /// **'Missing access token for backup.'**
  String get settingsMissingAccessTokenBackup;

  /// No description provided for @settingsMissingAccessTokenRestore.
  ///
  /// In en, this message translates to:
  /// **'Missing access token for restore.'**
  String get settingsMissingAccessTokenRestore;

  /// No description provided for @settingsDeleteBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete backup data'**
  String get settingsDeleteBackupTitle;

  /// No description provided for @settingsDeleteBackupMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the encrypted backup file from this device.\nThis cannot be undone.'**
  String get settingsDeleteBackupMessage;

  /// No description provided for @settingsDeleteBackupConfirm.
  ///
  /// In en, this message translates to:
  /// **'D E L E T E   B A C K U P'**
  String get settingsDeleteBackupConfirm;

  /// No description provided for @settingsMissingAccessTokenBackupDelete.
  ///
  /// In en, this message translates to:
  /// **'Missing access token for backup delete.'**
  String get settingsMissingAccessTokenBackupDelete;

  /// No description provided for @settingsAutoBackupSchedule.
  ///
  /// In en, this message translates to:
  /// **'Auto backup runs every 24h or after {threshold} new messages (whichever comes first).'**
  String settingsAutoBackupSchedule(int threshold);

  /// No description provided for @settingsAutoBackupThreshold.
  ///
  /// In en, this message translates to:
  /// **'Auto backup threshold'**
  String get settingsAutoBackupThreshold;

  /// No description provided for @settingsAutoBackupDecreaseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Decrease threshold'**
  String get settingsAutoBackupDecreaseTooltip;

  /// No description provided for @settingsAutoBackupIncreaseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Increase threshold'**
  String get settingsAutoBackupIncreaseTooltip;

  /// No description provided for @settingsMessagesUnit.
  ///
  /// In en, this message translates to:
  /// **'messages'**
  String get settingsMessagesUnit;

  /// No description provided for @settingsDeleteLocalChatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete local chat data'**
  String get settingsDeleteLocalChatsTitle;

  /// No description provided for @settingsDeleteLocalChatsMessage.
  ///
  /// In en, this message translates to:
  /// **'This deletes all chat history stored on this device.\nServer-side data is not changed.'**
  String get settingsDeleteLocalChatsMessage;

  /// No description provided for @settingsDeleteLocalChatsConfirm.
  ///
  /// In en, this message translates to:
  /// **'D E L E T E   L O C A L   C H A T S'**
  String get settingsDeleteLocalChatsConfirm;

  /// No description provided for @settingsSignOutMessage.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out of this account.\nLocal messages remain on device.'**
  String get settingsSignOutMessage;

  /// No description provided for @settingsSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'S I G N   O U T'**
  String get settingsSignOutConfirm;

  /// No description provided for @settingsPlanetUnknownName.
  ///
  /// In en, this message translates to:
  /// **'Unknown planet'**
  String get settingsPlanetUnknownName;

  /// No description provided for @settingsPlanetNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No planet description available yet.'**
  String get settingsPlanetNoDescription;

  /// No description provided for @settingsOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get settingsOnline;

  /// No description provided for @settingsOffline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get settingsOffline;

  /// No description provided for @settingsNotificationsOn.
  ///
  /// In en, this message translates to:
  /// **'notifications on'**
  String get settingsNotificationsOn;

  /// No description provided for @settingsNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'notifications off'**
  String get settingsNotificationsOff;

  /// No description provided for @settingsResidents.
  ///
  /// In en, this message translates to:
  /// **'residents'**
  String get settingsResidents;

  /// No description provided for @settingsStickers.
  ///
  /// In en, this message translates to:
  /// **'stickers'**
  String get settingsStickers;

  /// No description provided for @settingsEncrypted.
  ///
  /// In en, this message translates to:
  /// **'encrypted'**
  String get settingsEncrypted;

  /// No description provided for @settingsCreated.
  ///
  /// In en, this message translates to:
  /// **'created'**
  String get settingsCreated;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'profile'**
  String get profileTitle;

  /// No description provided for @profileNoDescriptionYet.
  ///
  /// In en, this message translates to:
  /// **'no description yet'**
  String get profileNoDescriptionYet;

  /// No description provided for @profileFriendLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Friend link copied'**
  String get profileFriendLinkCopied;

  /// No description provided for @profileCopyFriendLink.
  ///
  /// In en, this message translates to:
  /// **'copy friend link'**
  String get profileCopyFriendLink;

  /// No description provided for @profileFriendQrTitle.
  ///
  /// In en, this message translates to:
  /// **'FRIEND QR'**
  String get profileFriendQrTitle;

  /// No description provided for @profileFriendQrHint.
  ///
  /// In en, this message translates to:
  /// **'contains your server url and id'**
  String get profileFriendQrHint;

  /// No description provided for @profileQrPayloadCopied.
  ///
  /// In en, this message translates to:
  /// **'QR payload copied'**
  String get profileQrPayloadCopied;

  /// No description provided for @profileCopyQrPayload.
  ///
  /// In en, this message translates to:
  /// **'copy qr payload'**
  String get profileCopyQrPayload;

  /// No description provided for @profileDeviceLoginSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'DEVICE LOGIN'**
  String get profileDeviceLoginSectionTitle;

  /// No description provided for @profileDeviceLoginPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan to Approve Login'**
  String get profileDeviceLoginPageTitle;

  /// No description provided for @profileDeviceLoginAction.
  ///
  /// In en, this message translates to:
  /// **'Approve Login on Another Device'**
  String get profileDeviceLoginAction;

  /// No description provided for @profileDeviceLoginHint.
  ///
  /// In en, this message translates to:
  /// **'use your phone to approve a desktop or browser login'**
  String get profileDeviceLoginHint;

  /// No description provided for @profileDeviceLoginScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point camera at the QR code shown on your desktop or browser'**
  String get profileDeviceLoginScanHint;

  /// No description provided for @profileDeviceLoginApproved.
  ///
  /// In en, this message translates to:
  /// **'Login approved'**
  String get profileDeviceLoginApproved;

  /// No description provided for @profileDeviceLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to approve login'**
  String get profileDeviceLoginFailed;

  /// No description provided for @profileAboutYouLabel.
  ///
  /// In en, this message translates to:
  /// **'ABOUT YOU'**
  String get profileAboutYouLabel;

  /// No description provided for @profileAboutYouTitle.
  ///
  /// In en, this message translates to:
  /// **'A few words about yourself'**
  String get profileAboutYouTitle;

  /// No description provided for @profileDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What would you like others to know…'**
  String get profileDescriptionHint;

  /// No description provided for @profileDescriptionExceeded.
  ///
  /// In en, this message translates to:
  /// **'exceeded 100-word limit'**
  String get profileDescriptionExceeded;

  /// No description provided for @profileWordCount.
  ///
  /// In en, this message translates to:
  /// **'{words} / 100'**
  String profileWordCount(int words);

  /// No description provided for @profileUsernameValidationError.
  ///
  /// In en, this message translates to:
  /// **'Username must be 3-32 chars: a-zA-Z0-9._- and spaces'**
  String get profileUsernameValidationError;

  /// No description provided for @profileUsernameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Username updated'**
  String get profileUsernameUpdated;

  /// No description provided for @profileUsernameUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update username'**
  String get profileUsernameUpdateFailed;

  /// No description provided for @profileDescriptionWordLimitError.
  ///
  /// In en, this message translates to:
  /// **'Description must be 100 words or less'**
  String get profileDescriptionWordLimitError;

  /// No description provided for @profileDescriptionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Description updated'**
  String get profileDescriptionUpdated;

  /// No description provided for @profileAvatarTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Avatar too large (max 256KB). Choose a smaller image.'**
  String get profileAvatarTooLarge;

  /// No description provided for @profileAvatarUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload avatar'**
  String get profileAvatarUploadFailed;

  /// No description provided for @profileAvatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get profileAvatarUpdated;

  /// No description provided for @profileUsernameDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'USERNAME'**
  String get profileUsernameDialogTitle;

  /// No description provided for @profileUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'3–32 chars, a-zA-Z0-9._- and spaces'**
  String get profileUsernameHint;

  /// No description provided for @homeUnreadSummary.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{{count} unread message} other{{count} unread messages}}'**
  String homeUnreadSummary(int count);

  /// No description provided for @homeViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get homeViewProfile;

  /// No description provided for @homeUsernameDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'USERNAME'**
  String get homeUsernameDialogTitle;

  /// No description provided for @homeUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'3–32 characters, a-z A-Z 0-9 . _ -'**
  String get homeUsernameHint;

  /// No description provided for @chatHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Chats'**
  String get chatHomeTitle;

  /// No description provided for @chatHomeServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Server: {server}'**
  String chatHomeServerLabel(String server);

  /// No description provided for @chatHomeRealtimeStatus.
  ///
  /// In en, this message translates to:
  /// **'Realtime: {status}'**
  String chatHomeRealtimeStatus(String status);

  /// No description provided for @chatHomeDisconnected.
  ///
  /// In en, this message translates to:
  /// **'disconnected'**
  String get chatHomeDisconnected;

  /// No description provided for @chatHomePushInitialized.
  ///
  /// In en, this message translates to:
  /// **'Push: initialized'**
  String get chatHomePushInitialized;

  /// No description provided for @chatHomePushPending.
  ///
  /// In en, this message translates to:
  /// **'Push: pending'**
  String get chatHomePushPending;

  /// No description provided for @chatHomePartnerHint.
  ///
  /// In en, this message translates to:
  /// **'Partner user UUID'**
  String get chatHomePartnerHint;

  /// No description provided for @chatHomeOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get chatHomeOpenAction;

  /// No description provided for @chatHomeRefreshUnread.
  ///
  /// In en, this message translates to:
  /// **'Refresh unread'**
  String get chatHomeRefreshUnread;

  /// No description provided for @chatHomeActiveUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread from active partner: {count}'**
  String chatHomeActiveUnread(int count);

  /// No description provided for @chatHomeEnterPartnerPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter a partner UUID to load conversation.'**
  String get chatHomeEnterPartnerPrompt;

  /// No description provided for @chatHomeFailedToLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Failed to load messages: {error}'**
  String chatHomeFailedToLoadMessages(String error);

  /// No description provided for @chatHomeLoadOlder.
  ///
  /// In en, this message translates to:
  /// **'Load older'**
  String get chatHomeLoadOlder;

  /// No description provided for @chatHomeSelectedImage.
  ///
  /// In en, this message translates to:
  /// **'Selected image'**
  String get chatHomeSelectedImage;

  /// No description provided for @chatHomeRemoveMediaTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove media'**
  String get chatHomeRemoveMediaTooltip;

  /// No description provided for @chatHomeTyping.
  ///
  /// In en, this message translates to:
  /// **'Typing…'**
  String get chatHomeTyping;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'back'**
  String get actionBack;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'copy'**
  String get actionCopy;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'edit'**
  String get actionEdit;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'S A V E'**
  String get actionSave;

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
