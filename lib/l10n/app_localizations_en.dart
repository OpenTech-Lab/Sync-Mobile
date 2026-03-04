// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sync';

  @override
  String get loadingSync => 'sync';

  @override
  String get errorTitle => 'ERROR';

  @override
  String get restartAppHint => 'please restart the app';

  @override
  String get tabHome => 'home';

  @override
  String get tabChats => 'chats';

  @override
  String get tabSettings => 'settings';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => 'Traditional Chinese';

  @override
  String get welcomeTitle => 'Welcome to Sync';

  @override
  String get welcomeSubtitle => 'Connect to your planet server to get started.';

  @override
  String get serverUrlLabel => 'SERVER URL';

  @override
  String get serverUrlHint => 'https://my-planet.example.com';

  @override
  String get quickConnectLabel => 'QUICK CONNECT';

  @override
  String get checkingConnection => 'checking…';

  @override
  String get checkConnectionAction => 'C H E C K   C O N N E C T I O N';

  @override
  String get continueAction => 'C O N T I N U E';

  @override
  String get connectionFailed => 'Connection failed.';

  @override
  String get connectedStatus => 'connected';

  @override
  String get secureStatus => 'secure';

  @override
  String get publicStatus => 'public';

  @override
  String latencyValue(String ms) {
    return '$ms ms';
  }

  @override
  String get planetCardHost => 'Host';

  @override
  String get planetCardCountry => 'Country';

  @override
  String get planetCardProtocol => 'Protocol';

  @override
  String get planetCardLatency => 'Latency';

  @override
  String get authTagline => 'Your private messenger';

  @override
  String get signInTab => 'Sign in';

  @override
  String get signUpTab => 'Sign up';

  @override
  String get accountFoundForServer => 'Account found for this server';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordSentHint => 'If that email is registered, a reset link was sent.';

  @override
  String get resetPasswordEnterEmailHint => 'Enter your email and we\'ll send a reset link.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordMin8Label => 'Password · min 8 characters';

  @override
  String get actionClose => 'close';

  @override
  String get actionSend => 'S E N D';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get signingInProgress => 'signing in…';

  @override
  String get signInAction => 'S I G N   I N';

  @override
  String get creatingAccountProgress => 'creating account…';

  @override
  String get createAccountAction => 'C R E A T E   A C C O U N T';

  @override
  String get myProfileTitle => 'My Profile';

  @override
  String friendsTitle(int count) {
    return 'Friends ($count)';
  }

  @override
  String get noFriendsYet => 'No friends yet';

  @override
  String get openChatsHint => 'Open Chats and start a conversation';

  @override
  String get friendRemoved => 'Friend removed';

  @override
  String get friendAdded => 'Friend added';

  @override
  String get settingsMyPlanet => 'My Planet';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'THEME';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsEncryptedBackups => 'Encrypted Backups';

  @override
  String get settingsEnableBackups => 'Enable backups';

  @override
  String get settingsBackupSubtitle => 'End-to-end encrypted on planet server';

  @override
  String get settingsCreateBackup => 'Create backup';

  @override
  String get settingsRestore => 'Restore';

  @override
  String get settingsDeleteBackupData => 'Delete backup data';

  @override
  String get settingsLocalData => 'Local Data';

  @override
  String get settingsDeleteAllLocalChats => 'Delete all local chat data';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get chatToday => 'Today';

  @override
  String get chatUnreadHeader => 'UNREAD';

  @override
  String get chatChatsHeader => 'CHATS';

  @override
  String get chatNoChatsYet => 'No chats yet.';

  @override
  String get chatNoMessagesYet => 'No messages yet.\nSay hello!';

  @override
  String get chatSearchHint => 'search…';

  @override
  String get chatMessageHint => 'Message…';

  @override
  String get chatAttachImageTooltip => 'Attach image';

  @override
  String get chatStickersTooltip => 'Stickers';

  @override
  String get chatNoStickersYet => 'No stickers yet.';

  @override
  String get chatStickersHeader => 'STICKERS';

  @override
  String get chatMore => 'more';

  @override
  String get chatMarkAllRead => 'mark all read';

  @override
  String get chatMarkedAllAsRead => 'Marked all as read';

  @override
  String chatTypingIndicator(String name) {
    return '$name is typing…';
  }

  @override
  String get chatDefaultPartner => 'Partner';

  @override
  String get chatDefaultTitle => 'Chat';

  @override
  String get chatAddFriendHeader => 'ADD FRIEND';

  @override
  String get chatAddFriendTitle => 'Paste a friend link or user ID';

  @override
  String get chatAddFriendFormatHint => 'Supported format: https://server.tld/<user-id>';

  @override
  String get chatAddFriendInputHint => 'friend link or user ID';

  @override
  String get actionCancel => 'cancel';

  @override
  String get actionNext => 'N E X T';
}
