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
  String get tabPlanet => 'planet';

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
  String get authQrTitle => 'Sign in with QR';

  @override
  String get authQrHint => 'Open Sync on your phone and scan this code from My Profile.';

  @override
  String get authQrWaitingForScan => 'waiting for phone approval…';

  @override
  String get authQrExpired => 'QR expired. refresh to continue.';

  @override
  String get authQrUnavailable => 'QR login unavailable. try refresh.';

  @override
  String get authQrPressRefresh => 'please press refresh';

  @override
  String get authQrRefresh => 'refresh qr';

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
  String get homeConnectedPlanetsTitle => 'Connected Planets';

  @override
  String get homeConnectedPlanetsEmpty => 'No connected planets yet';

  @override
  String get homeConnectedPlanetsLoading => 'Loading connected planets…';

  @override
  String get homeConnectedPlanetsLoadFailed => 'Failed to load connected planets';

  @override
  String homePlanetMembers(int count) {
    return '$count members';
  }

  @override
  String get friendRemoved => 'Friend removed';

  @override
  String get friendAdded => 'Friend added';

  @override
  String get planetLoading => 'Loading planet data…';

  @override
  String get planetLoadFailed => 'Failed to load planet data.';

  @override
  String get planetNewsTitle => 'Server News';

  @override
  String get planetNewsEmpty => 'No server news yet';

  @override
  String get planetNewsDetailTitle => 'News';

  @override
  String get settingsMyPlanet => 'My Planet';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'THEME';

  @override
  String get settingsTypingStyleMode => 'Typing style mode';

  @override
  String get settingsTypingStyleModeHint => 'Show messages with a typing animation';

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
  String chatMarkReadPartial(int success, int total) {
    return 'Marked as read for $success/$total conversations';
  }

  @override
  String get chatSelectedMediaFallback => 'Image';

  @override
  String get chatMessageDetailTitleMine => 'Your message';

  @override
  String get chatMessageDetailTitleOther => 'Message';

  @override
  String get chatCopiedToClipboard => 'Copied to clipboard';

  @override
  String get chatQuickNewHeader => 'NEW';

  @override
  String get chatQuickFriendOrStart => 'friend / start chat';

  @override
  String get chatQuickScanFriendQr => 'scan friend qr';

  @override
  String get chatScanFriendQrInstruction => 'point camera at a friend\'s qr code';

  @override
  String get chatTargetCancelFriend => 'cancel friend';

  @override
  String get chatTargetAddFriend => 'A D D   F R I E N D';

  @override
  String get chatTargetFriend => 'friend';

  @override
  String get chatTargetStartChat => 'S T A R T   C H A T';

  @override
  String get chatTargetFriendSince => 'FRIEND SINCE';

  @override
  String get chatTargetMessagesSent => 'MESSAGES SENT';

  @override
  String get chatTargetAbout => 'ABOUT';

  @override
  String get settingsMissingAccessTokenBackup => 'Missing access token for backup.';

  @override
  String get settingsMissingAccessTokenRestore => 'Missing access token for restore.';

  @override
  String get settingsDeleteBackupTitle => 'Delete backup data';

  @override
  String get settingsDeleteBackupMessage => 'This removes the encrypted backup file from this device.\nThis cannot be undone.';

  @override
  String get settingsDeleteBackupConfirm => 'D E L E T E   B A C K U P';

  @override
  String get settingsMissingAccessTokenBackupDelete => 'Missing access token for backup delete.';

  @override
  String settingsAutoBackupSchedule(int threshold) {
    return 'Auto backup runs every 24h or after $threshold new messages (whichever comes first).';
  }

  @override
  String get settingsAutoBackupThreshold => 'Auto backup threshold';

  @override
  String get settingsAutoBackupDecreaseTooltip => 'Decrease threshold';

  @override
  String get settingsAutoBackupIncreaseTooltip => 'Increase threshold';

  @override
  String get settingsMessagesUnit => 'messages';

  @override
  String get settingsDeleteLocalChatsTitle => 'Delete local chat data';

  @override
  String get settingsDeleteLocalChatsMessage => 'This deletes all chat history stored on this device.\nServer-side data is not changed.';

  @override
  String get settingsDeleteLocalChatsConfirm => 'D E L E T E   L O C A L   C H A T S';

  @override
  String get settingsSignOutMessage => 'You will be signed out of this account.\nLocal messages remain on device.';

  @override
  String get settingsSignOutConfirm => 'S I G N   O U T';

  @override
  String get settingsPlanetUnknownName => 'Unknown planet';

  @override
  String get settingsPlanetNoDescription => 'No planet description available yet.';

  @override
  String get settingsOnline => 'online';

  @override
  String get settingsOffline => 'offline';

  @override
  String get settingsNotificationsOn => 'notifications on';

  @override
  String get settingsNotificationsOff => 'notifications off';

  @override
  String get settingsResidents => 'residents';

  @override
  String get settingsStickers => 'stickers';

  @override
  String get settingsEncrypted => 'encrypted';

  @override
  String get profileTitle => 'profile';

  @override
  String get profileNoDescriptionYet => 'no description yet';

  @override
  String get profileFriendLinkCopied => 'Friend link copied';

  @override
  String get profileCopyFriendLink => 'copy friend link';

  @override
  String get profileFriendQrTitle => 'FRIEND QR';

  @override
  String get profileFriendQrHint => 'contains your server url and id';

  @override
  String get profileQrPayloadCopied => 'QR payload copied';

  @override
  String get profileCopyQrPayload => 'copy qr payload';

  @override
  String get profileDeviceLoginAction => 'scan qr to login other device';

  @override
  String get profileDeviceLoginHint => 'use your phone camera to approve desktop/web login';

  @override
  String get profileDeviceLoginScanHint => 'scan login qr shown on desktop/web';

  @override
  String get profileDeviceLoginApproved => 'Login approved';

  @override
  String get profileDeviceLoginFailed => 'Failed to approve login';

  @override
  String get profileAboutYouLabel => 'ABOUT YOU';

  @override
  String get profileAboutYouTitle => 'A few words about yourself';

  @override
  String get profileDescriptionHint => 'What would you like others to know…';

  @override
  String get profileDescriptionExceeded => 'exceeded 100-word limit';

  @override
  String profileWordCount(int words) {
    return '$words / 100';
  }

  @override
  String get profileUsernameValidationError => 'Username must be 3-32 chars: a-zA-Z0-9._-';

  @override
  String get profileUsernameUpdated => 'Username updated';

  @override
  String get profileUsernameUpdateFailed => 'Failed to update username';

  @override
  String get profileDescriptionWordLimitError => 'Description must be 100 words or less';

  @override
  String get profileDescriptionUpdated => 'Description updated';

  @override
  String get profileAvatarTooLarge => 'Avatar too large (max 256KB). Choose a smaller image.';

  @override
  String get profileAvatarUploadFailed => 'Failed to upload avatar';

  @override
  String get profileAvatarUpdated => 'Avatar updated';

  @override
  String get profileUsernameDialogTitle => 'USERNAME';

  @override
  String get profileUsernameHint => '3–32 chars, a-zA-Z0-9._-';

  @override
  String homeUnreadSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '$count unread message',
    );
    return '$_temp0';
  }

  @override
  String get homeViewProfile => 'View profile';

  @override
  String get homeUsernameDialogTitle => 'USERNAME';

  @override
  String get homeUsernameHint => '3–32 characters, a-z A-Z 0-9 . _ -';

  @override
  String get chatHomeTitle => 'Sync Chats';

  @override
  String chatHomeServerLabel(String server) {
    return 'Server: $server';
  }

  @override
  String chatHomeRealtimeStatus(String status) {
    return 'Realtime: $status';
  }

  @override
  String get chatHomeDisconnected => 'disconnected';

  @override
  String get chatHomePushInitialized => 'Push: initialized';

  @override
  String get chatHomePushPending => 'Push: pending';

  @override
  String get chatHomePartnerHint => 'Partner user UUID';

  @override
  String get chatHomeOpenAction => 'Open';

  @override
  String get chatHomeRefreshUnread => 'Refresh unread';

  @override
  String chatHomeActiveUnread(int count) {
    return 'Unread from active partner: $count';
  }

  @override
  String get chatHomeEnterPartnerPrompt => 'Enter a partner UUID to load conversation.';

  @override
  String chatHomeFailedToLoadMessages(String error) {
    return 'Failed to load messages: $error';
  }

  @override
  String get chatHomeLoadOlder => 'Load older';

  @override
  String get chatHomeSelectedImage => 'Selected image';

  @override
  String get chatHomeRemoveMediaTooltip => 'Remove media';

  @override
  String get chatHomeTyping => 'Typing…';

  @override
  String get actionBack => 'back';

  @override
  String get actionCopy => 'copy';

  @override
  String get actionEdit => 'edit';

  @override
  String get actionSave => 'S A V E';

  @override
  String get actionCancel => 'cancel';

  @override
  String get actionNext => 'N E X T';
}
