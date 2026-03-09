// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

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
  String get planetRegistrationLabel => 'REGISTRATION';

  @override
  String get planetRegistrationApprovalRequired => 'approval required';

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
  String get planetOtherPlanetsTitle => 'OTHER PLANETS';

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
  String get planetNewsTitle => 'MY PLAENT';

  @override
  String get planetNewsEmpty => 'No server news yet';

  @override
  String get planetNewsDetailTitle => 'News';

  @override
  String get planetStickersTitle => 'PLANET STICKERS';

  @override
  String get planetStickerDownload => 'Download';

  @override
  String get planetStickerDownloaded => 'Downloaded';

  @override
  String get planetStickerDownloading => 'Downloading…';

  @override
  String get planetStickerDownloadFailed => 'Failed to download sticker.';

  @override
  String planetStickerDownloadedToast(String name) {
    return 'Downloaded $name to local stickers.';
  }

  @override
  String planetStickerGroupCount(int count) {
    return '$count stickers';
  }

  @override
  String planetStickerGroupDownloadedToast(String group) {
    return 'Downloaded $group sticker pack.';
  }

  @override
  String get settingsMyPlanet => 'My Planet';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsTypingStyleMode => 'Typing style mode';

  @override
  String get settingsTypingStyleModeHint => 'Show messages with a typing animation';

  @override
  String get settingsTypingStyleSpeed => 'Typing speed';

  @override
  String get settingsTypingStyleSpeedHint => 'Lower is faster';

  @override
  String settingsTypingStyleSpeedValue(int ms) {
    return '$ms ms / char';
  }

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
  String get settingsLocalData => 'Delete';

  @override
  String get settingsDeleteAllPlanetData => 'Delete all data from this planet';

  @override
  String get settingsDeleteAllPlanetDataMessage => 'This permanently deletes all local data (chats, friends, preferences) and any encrypted backup on the server. This cannot be undone.';

  @override
  String get settingsDeleteAllPlanetDataConfirm => 'D E L E T E   A L L   D A T A';

  @override
  String get settingsDeleteAllLocalChats => 'Delete all local chat data';

  @override
  String get settingsDeleteAllAppData => 'Delete all app data';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get chatToday => 'Today';

  @override
  String get chatUnreadHeader => 'UNREAD';

  @override
  String get chatChatsHeader => 'CHATS';

  @override
  String get chatRowDelete => 'delete';

  @override
  String get chatRowHide => 'hide';

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
  String get chatTrustRetryWindowReset => 'after the daily reset';

  @override
  String chatTrustRetryWindowHours(int hours) {
    return 'in ${hours}h';
  }

  @override
  String chatTrustRetryWindowMinutes(int minutes) {
    return 'in ${minutes}m';
  }

  @override
  String chatTrustDailyLimitToast(int used, int limit, String retryWindow) {
    return 'Daily message cap reached ($used/$limit). You can send again $retryWindow, or level up for a higher cap.';
  }

  @override
  String chatTrustDailyLimitToastGeneric(String retryWindow) {
    return 'Daily message cap reached. You can send again $retryWindow, or level up for a higher cap.';
  }

  @override
  String chatTrustDailyLimitInline(String retryWindow) {
    return 'cap reached · retry $retryWindow or level up';
  }

  @override
  String get chatMessageDetailTitleMine => 'Your message';

  @override
  String get chatMessageDetailTitleOther => 'Message';

  @override
  String get chatCopiedToClipboard => 'Copied to clipboard';

  @override
  String get chatQuickNewHeader => 'NEW';

  @override
  String get chatQuickNewRoom => 'new room';

  @override
  String get chatQuickFriendOrStart => 'friend / start chat';

  @override
  String get chatQuickScanFriendQr => 'scan friend qr';

  @override
  String get chatCreateRoomHeader => 'ROOM';

  @override
  String get chatCreateRoomTitle => 'Create a private room';

  @override
  String get chatCreateRoomNameLabel => 'Room name';

  @override
  String get chatCreateRoomNameHint => 'Weekend plans';

  @override
  String get chatCreateRoomMembersLabel => 'Members';

  @override
  String get chatCreateRoomNoFriends => 'Add friends first, or create a room and invite them later.';

  @override
  String get chatCreateRoomAction => 'C R E A T E';

  @override
  String get chatRoomCreated => 'Room created';

  @override
  String get chatClearHistory => 'Clear';

  @override
  String get chatDefaultRoom => 'Room';

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
  String get settingsDeleteAllAppDataTitle => 'Delete all app data';

  @override
  String get settingsDeleteAllAppDataMessage => 'This permanently deletes all local data including chat history, preferences, and cached data.\nServer-side data is not changed.';

  @override
  String get settingsDeleteAllAppDataConfirm => 'D E L E T E   A L L   D A T A';

  @override
  String get settingsSignOutMessage => 'You will be signed out of this account.\nLocal messages remain on device.';

  @override
  String get settingsSignOutConfirm => 'S I G N   O U T';

  @override
  String get settingsDeleteAccount => 'Delete this account from this planet';

  @override
  String get settingsDeleteAccountMessage => 'Your account will be permanently deleted from this planet. All local data and any server backup will be removed. This cannot be undone.';

  @override
  String get settingsDeleteAccountConfirm => 'D E L E T E   A C C O U N T';

  @override
  String get settingsDangerousActions => 'Dangerous actions';

  @override
  String get settingsDangerousActionsHint => 'delete local chats, clear app data, or sign out';

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
  String get settingsCreated => 'created';

  @override
  String get profileTitle => 'profile';

  @override
  String get profileNoDescriptionYet => 'no description yet';

  @override
  String get profileFriendLinkCopied => 'Friend link copied';

  @override
  String get profileCopyFriendLink => 'copy friend link';

  @override
  String get profileTrustSectionTitle => 'GUILD';

  @override
  String profileGuildLevel(int level) {
    return 'Level $level';
  }

  @override
  String profileGuildRank(String rank) {
    return 'Rank $rank';
  }

  @override
  String profileTrustProgressLabel(int activeDays) {
    return '$activeDays active days';
  }

  @override
  String profileTrustNextLevel(int days, int level) {
    return '$days days to level $level';
  }

  @override
  String get profileTrustMaxLevel => 'Highest level unlocked';

  @override
  String get profileTrustMessagesLabel => 'messages today';

  @override
  String get profileTrustAttachmentsLabel => 'attachments today';

  @override
  String get profileTrustUnlimited => 'Unlimited';

  @override
  String profileTrustUsage(int used, int limit) {
    return '$used / $limit';
  }

  @override
  String get profileFriendQrTitle => 'FRIEND QR';

  @override
  String get profileFriendQrHint => 'contains your server url and id';

  @override
  String get profileQrPayloadCopied => 'QR payload copied';

  @override
  String get profileCopyQrPayload => 'copy qr payload';

  @override
  String get profileDeviceLoginSectionTitle => 'DEVICE LOGIN';

  @override
  String get profileDeviceLoginPageTitle => 'Scan to Approve Login';

  @override
  String get profileDeviceLoginAction => 'Approve Login on Another Device';

  @override
  String get profileDeviceLoginHint => 'use your phone to approve a desktop or browser login';

  @override
  String get profileDeviceLoginScanHint => 'Point camera at the QR code shown on your desktop or browser';

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
  String get profileUsernameValidationError => 'Username must be 3–32 characters and may use any language, symbols, and spaces';

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
  String get profileUsernameHint => '3–32 chars, supports any language, symbols, and spaces';

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

  @override
  String get chatSentASticker => 'Sent a sticker';

  @override
  String get chatSentAnAttachment => 'Sent an attachment';

  @override
  String get profileTrustFriendAddsLabel => 'friend adds today';

  @override
  String get profileTrustChallengeStateFrozen => 'Your account is frozen. Contact support to restore access.';

  @override
  String get profileTrustChallengeStateChallenged => 'Your account is under review. Some actions may be limited.';

  @override
  String get profileTrustMilestoneRankUp => 'Rank up!';

  @override
  String get profileTrustMilestoneUnlockAttachmentType => 'New attachment type unlocked!';

  @override
  String get profileTrustMilestoneLevelUp => 'Level up!';

  @override
  String profileTrustMilestoneRankDetail(String rank) {
    return 'You reached rank $rank.';
  }

  @override
  String profileTrustMilestoneUnlockDetail(String type) {
    return 'You can now send $type attachments.';
  }

  @override
  String profileTrustMilestoneLevelDetail(String level) {
    return 'You reached level $level.';
  }
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw(): super('zh_TW');

  @override
  String get appTitle => 'Sync';

  @override
  String get loadingSync => '同步中';

  @override
  String get errorTitle => '錯誤';

  @override
  String get restartAppHint => '請重新啟動應用程式';

  @override
  String get tabHome => '首頁';

  @override
  String get tabPlanet => '星球';

  @override
  String get tabChats => '聊天';

  @override
  String get tabSettings => '設定';

  @override
  String get languageLabel => '語言';

  @override
  String get languageSystem => '系統';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get welcomeTitle => '歡迎使用 Sync';

  @override
  String get welcomeSubtitle => '連線到你的 Planet 伺服器以開始使用。';

  @override
  String get serverUrlLabel => '伺服器網址';

  @override
  String get serverUrlHint => 'https://my-planet.example.com';

  @override
  String get quickConnectLabel => '快速連線';

  @override
  String get checkingConnection => '檢查中…';

  @override
  String get checkConnectionAction => '檢 查 連 線';

  @override
  String get continueAction => '繼 續';

  @override
  String get connectionFailed => '連線失敗。';

  @override
  String get connectedStatus => '已連線';

  @override
  String get secureStatus => '安全';

  @override
  String get publicStatus => '公開';

  @override
  String latencyValue(String ms) {
    return '$ms 毫秒';
  }

  @override
  String get planetCardHost => '主機';

  @override
  String get planetCardCountry => '國家';

  @override
  String get planetCardProtocol => '通訊協定';

  @override
  String get planetCardLatency => '延遲';

  @override
  String get planetRegistrationLabel => 'REGISTRATION';

  @override
  String get planetRegistrationApprovalRequired => '需審核';

  @override
  String get authTagline => '你的私人通訊工具';

  @override
  String get signInTab => '登入';

  @override
  String get signUpTab => '註冊';

  @override
  String get accountFoundForServer => '此伺服器已找到帳號';

  @override
  String get resetPasswordTitle => '重設密碼';

  @override
  String get resetPasswordSentHint => '若此 Email 已註冊，重設連結已送出。';

  @override
  String get resetPasswordEnterEmailHint => '輸入你的 Email，我們會寄送重設連結。';

  @override
  String get emailLabel => '電子郵件';

  @override
  String get passwordLabel => '密碼';

  @override
  String get usernameLabel => '使用者名稱';

  @override
  String get passwordMin8Label => '密碼 · 至少 8 個字元';

  @override
  String get actionClose => '關閉';

  @override
  String get actionSend => '送 出';

  @override
  String get forgotPassword => '忘記密碼？';

  @override
  String get signingInProgress => '登入中…';

  @override
  String get signInAction => '登 入';

  @override
  String get authQrTitle => '使用 QR 登入';

  @override
  String get authQrHint => '在手機上開啟 Sync，前往我的檔案並掃描此 QR。';

  @override
  String get authQrWaitingForScan => '等待手機確認…';

  @override
  String get authQrExpired => 'QR 已過期，請重新整理。';

  @override
  String get authQrUnavailable => 'QR 登入暫時不可用，請重試。';

  @override
  String get authQrPressRefresh => '請按重新整理';

  @override
  String get authQrRefresh => '重新整理 QR';

  @override
  String get creatingAccountProgress => '建立帳號中…';

  @override
  String get createAccountAction => '建 立 帳 號';

  @override
  String get myProfileTitle => '我的檔案';

  @override
  String friendsTitle(int count) {
    return '好友（$count）';
  }

  @override
  String get noFriendsYet => '尚無好友';

  @override
  String get openChatsHint => '開啟聊天並開始對話';

  @override
  String get homeConnectedPlanetsTitle => '已連線 Planet';

  @override
  String get planetOtherPlanetsTitle => '其他星球';

  @override
  String get homeConnectedPlanetsEmpty => '尚未設定已連線 Planet';

  @override
  String get homeConnectedPlanetsLoading => '正在載入已連線 Planet…';

  @override
  String get homeConnectedPlanetsLoadFailed => '載入已連線 Planet 失敗';

  @override
  String homePlanetMembers(int count) {
    return '$count 位成員';
  }

  @override
  String get friendRemoved => '已移除好友';

  @override
  String get friendAdded => '已新增好友';

  @override
  String get planetLoading => '正在載入星球資料…';

  @override
  String get planetLoadFailed => '載入星球資料失敗。';

  @override
  String get planetNewsTitle => '伺服器公告';

  @override
  String get planetNewsEmpty => '目前尚無公告';

  @override
  String get planetNewsDetailTitle => '公告內容';

  @override
  String get planetStickersTitle => '本星球貼圖';

  @override
  String get planetStickerDownload => '下載';

  @override
  String get planetStickerDownloaded => '已下載';

  @override
  String get planetStickerDownloading => '下載中…';

  @override
  String get planetStickerDownloadFailed => '下載貼圖失敗。';

  @override
  String planetStickerDownloadedToast(String name) {
    return '已將 $name 下載到本機貼圖。';
  }

  @override
  String planetStickerGroupCount(int count) {
    return '$count 個貼圖';
  }

  @override
  String planetStickerGroupDownloadedToast(String group) {
    return '已下載 $group 貼圖包。';
  }

  @override
  String get settingsMyPlanet => '我的 Planet';

  @override
  String get settingsAppearance => '外觀';

  @override
  String get settingsTheme => '主題';

  @override
  String get settingsTypingStyleMode => '打字樣式模式';

  @override
  String get settingsTypingStyleModeHint => '以打字動畫顯示訊息';

  @override
  String get settingsTypingStyleSpeed => '打字速度';

  @override
  String get settingsTypingStyleSpeedHint => '數值越小越快';

  @override
  String settingsTypingStyleSpeedValue(int ms) {
    return '$ms 毫秒 / 字元';
  }

  @override
  String get themeLight => '淺色';

  @override
  String get themeSystem => '系統';

  @override
  String get themeDark => '深色';

  @override
  String get settingsEncryptedBackups => '加密備份';

  @override
  String get settingsEnableBackups => '啟用備份';

  @override
  String get settingsBackupSubtitle => '於 Planet 伺服器端到端加密';

  @override
  String get settingsCreateBackup => '建立備份';

  @override
  String get settingsRestore => '還原';

  @override
  String get settingsDeleteBackupData => '刪除備份資料';

  @override
  String get settingsLocalData => '刪除';

  @override
  String get settingsDeleteAllPlanetData => '刪除此星球的所有資料';

  @override
  String get settingsDeleteAllPlanetDataMessage => '這將永久刪除所有本機資料（聊天、好友、偏好設定）以及伺服器上的加密備份。此操作無法復原。';

  @override
  String get settingsDeleteAllPlanetDataConfirm => '刪 除 所 有 資 料';

  @override
  String get settingsDeleteAllLocalChats => '刪除本機所有聊天資料';

  @override
  String get settingsDeleteAllAppData => '刪除所有應用程式資料';

  @override
  String get settingsSignOut => '登出';

  @override
  String get chatToday => '今天';

  @override
  String get chatUnreadHeader => '未讀';

  @override
  String get chatChatsHeader => '聊天';

  @override
  String get chatRowDelete => '刪除';

  @override
  String get chatRowHide => '隱藏';

  @override
  String get chatNoChatsYet => '還沒有聊天紀錄。';

  @override
  String get chatNoMessagesYet => '尚無訊息。\n打個招呼吧！';

  @override
  String get chatSearchHint => '搜尋…';

  @override
  String get chatMessageHint => '訊息…';

  @override
  String get chatAttachImageTooltip => '附加圖片';

  @override
  String get chatStickersTooltip => '貼圖';

  @override
  String get chatNoStickersYet => '目前沒有貼圖。';

  @override
  String get chatStickersHeader => '貼圖';

  @override
  String get chatMore => '更多';

  @override
  String get chatMarkAllRead => '全部標為已讀';

  @override
  String get chatMarkedAllAsRead => '已全部標為已讀';

  @override
  String chatTypingIndicator(String name) {
    return '$name 正在輸入…';
  }

  @override
  String get chatDefaultPartner => '對方';

  @override
  String get chatDefaultTitle => '聊天';

  @override
  String get chatAddFriendHeader => '新增好友';

  @override
  String get chatAddFriendTitle => '貼上好友連結或使用者 ID';

  @override
  String get chatAddFriendFormatHint => '支援格式：https://server.tld/<user-id>';

  @override
  String get chatAddFriendInputHint => '好友連結或使用者 ID';

  @override
  String chatMarkReadPartial(int success, int total) {
    return '已標記 $success/$total 個對話為已讀';
  }

  @override
  String get chatSelectedMediaFallback => '圖片';

  @override
  String get chatTrustRetryWindowReset => '每日重置後';

  @override
  String chatTrustRetryWindowHours(int hours) {
    return '$hours 小時後';
  }

  @override
  String chatTrustRetryWindowMinutes(int minutes) {
    return '$minutes 分鐘後';
  }

  @override
  String chatTrustDailyLimitToast(int used, int limit, String retryWindow) {
    return '已達每日訊息上限（$used/$limit）。你可以於$retryWindow再次發送，或提升等級以獲得更高上限。';
  }

  @override
  String chatTrustDailyLimitToastGeneric(String retryWindow) {
    return '已達每日訊息上限。你可以於$retryWindow再次發送，或提升等級以獲得更高上限。';
  }

  @override
  String chatTrustDailyLimitInline(String retryWindow) {
    return '已達上限 · $retryWindow可再試 · 或先提升等級';
  }

  @override
  String get chatMessageDetailTitleMine => '你的訊息';

  @override
  String get chatMessageDetailTitleOther => '訊息';

  @override
  String get chatCopiedToClipboard => '已複製到剪貼簿';

  @override
  String get chatQuickNewHeader => '新增';

  @override
  String get chatQuickNewRoom => '新增群組';

  @override
  String get chatQuickFriendOrStart => '好友 / 開始聊天';

  @override
  String get chatQuickScanFriendQr => '掃描好友 QR';

  @override
  String get chatCreateRoomHeader => '群組';

  @override
  String get chatCreateRoomTitle => '建立私人群組';

  @override
  String get chatCreateRoomNameLabel => '群組名稱';

  @override
  String get chatCreateRoomNameHint => '週末計畫';

  @override
  String get chatCreateRoomMembersLabel => '成員';

  @override
  String get chatCreateRoomNoFriends => '先加入好友，或先建立群組後再邀請。';

  @override
  String get chatCreateRoomAction => '建 立 群 組';

  @override
  String get chatRoomCreated => '已建立群組';

  @override
  String get chatClearHistory => '清除';

  @override
  String get chatDefaultRoom => '群組';

  @override
  String get chatScanFriendQrInstruction => '將鏡頭對準好友的 QR 碼';

  @override
  String get chatTargetCancelFriend => '取消好友';

  @override
  String get chatTargetAddFriend => '新 增 好 友';

  @override
  String get chatTargetFriend => '好友';

  @override
  String get chatTargetStartChat => '開 始 聊 天';

  @override
  String get chatTargetFriendSince => '成為好友時間';

  @override
  String get chatTargetMessagesSent => '已傳送訊息';

  @override
  String get chatTargetAbout => '關於';

  @override
  String get settingsMissingAccessTokenBackup => '建立備份缺少存取權杖。';

  @override
  String get settingsMissingAccessTokenRestore => '還原備份缺少存取權杖。';

  @override
  String get settingsDeleteBackupTitle => '刪除備份資料';

  @override
  String get settingsDeleteBackupMessage => '這會移除此裝置上的加密備份檔案。\n此操作無法復原。';

  @override
  String get settingsDeleteBackupConfirm => '刪 除 備 份';

  @override
  String get settingsMissingAccessTokenBackupDelete => '刪除備份缺少存取權杖。';

  @override
  String settingsAutoBackupSchedule(int threshold) {
    return '自動備份每 24 小時執行一次，或在新增 $threshold 則訊息後執行（以先到者為準）。';
  }

  @override
  String get settingsAutoBackupThreshold => '自動備份門檻';

  @override
  String get settingsAutoBackupDecreaseTooltip => '降低門檻';

  @override
  String get settingsAutoBackupIncreaseTooltip => '提高門檻';

  @override
  String get settingsMessagesUnit => '則訊息';

  @override
  String get settingsDeleteLocalChatsTitle => '刪除本機聊天資料';

  @override
  String get settingsDeleteLocalChatsMessage => '這會刪除此裝置上儲存的所有聊天紀錄。\n不會影響伺服器端資料。';

  @override
  String get settingsDeleteLocalChatsConfirm => '刪 除 本 機 聊 天';

  @override
  String get settingsDeleteAllAppDataTitle => '刪除所有應用程式資料';

  @override
  String get settingsDeleteAllAppDataMessage => '這將永久刪除包括聊天紀錄、偏好設定及快取資料在內的所有本機資料。\n不會影響伺服器端資料。';

  @override
  String get settingsDeleteAllAppDataConfirm => '刪 除 所 有 資 料';

  @override
  String get settingsSignOutMessage => '你將從此帳號登出。\n本機訊息會保留在裝置上。';

  @override
  String get settingsSignOutConfirm => '登 出';

  @override
  String get settingsDeleteAccount => '從此星球刪除此帳號';

  @override
  String get settingsDeleteAccountMessage => '你的帳號將從此星球永久刪除。本機所有資料及伺服器備份都將一併移除，此操作無法復原。';

  @override
  String get settingsDeleteAccountConfirm => '刪 除 帳 號';

  @override
  String get settingsDangerousActions => '危険操作';

  @override
  String get settingsDangerousActionsHint => '刪除本機聊天、清除應用程式資料或登出';

  @override
  String get settingsPlanetUnknownName => '未知 Planet';

  @override
  String get settingsPlanetNoDescription => '目前尚無 Planet 描述。';

  @override
  String get settingsOnline => '在線';

  @override
  String get settingsOffline => '離線';

  @override
  String get settingsNotificationsOn => '通知已開啟';

  @override
  String get settingsNotificationsOff => '通知已關閉';

  @override
  String get settingsResidents => '居民';

  @override
  String get settingsStickers => '貼圖';

  @override
  String get settingsEncrypted => '已加密';

  @override
  String get settingsCreated => '建立日期';

  @override
  String get profileTitle => '個人檔案';

  @override
  String get profileNoDescriptionYet => '尚無描述';

  @override
  String get profileFriendLinkCopied => '已複製好友連結';

  @override
  String get profileCopyFriendLink => '複製好友連結';

  @override
  String get profileTrustSectionTitle => 'GUILD';

  @override
  String profileGuildLevel(int level) {
    return '等級 $level';
  }

  @override
  String profileGuildRank(String rank) {
    return '階級 $rank';
  }

  @override
  String profileTrustProgressLabel(int activeDays) {
    return '活躍天數 $activeDays';
  }

  @override
  String profileTrustNextLevel(int days, int level) {
    return '再 $days 天可升至等級 $level';
  }

  @override
  String get profileTrustMaxLevel => '已解鎖最高等級';

  @override
  String get profileTrustMessagesLabel => '今日訊息';

  @override
  String get profileTrustAttachmentsLabel => '今日附件';

  @override
  String get profileTrustUnlimited => '無限制';

  @override
  String profileTrustUsage(int used, int limit) {
    return '$used / $limit';
  }

  @override
  String get profileFriendQrTitle => '好友 QR';

  @override
  String get profileFriendQrHint => '包含你的伺服器網址與 ID';

  @override
  String get profileQrPayloadCopied => '已複製 QR 內容';

  @override
  String get profileCopyQrPayload => '複製 QR 內容';

  @override
  String get profileDeviceLoginSectionTitle => '裝置登入';

  @override
  String get profileDeviceLoginPageTitle => '掃描以核准登入';

  @override
  String get profileDeviceLoginAction => '核准其他裝置登入';

  @override
  String get profileDeviceLoginHint => '使用手機核准桌面或瀏覽器登入';

  @override
  String get profileDeviceLoginScanHint => '將相機對準桌面或瀏覽器顯示的 QR 碼';

  @override
  String get profileDeviceLoginApproved => '已核准登入';

  @override
  String get profileDeviceLoginFailed => '核准登入失敗';

  @override
  String get profileAboutYouLabel => '關於你';

  @override
  String get profileAboutYouTitle => '寫幾句關於你自己的介紹';

  @override
  String get profileDescriptionHint => '你希望別人認識你哪些事…';

  @override
  String get profileDescriptionExceeded => '已超過 100 字上限';

  @override
  String profileWordCount(int words) {
    return '$words / 100';
  }

  @override
  String get profileUsernameValidationError => '使用者名稱需為 3–32 字元，可使用任何語言、符號與空白';

  @override
  String get profileUsernameUpdated => '已更新使用者名稱';

  @override
  String get profileUsernameUpdateFailed => '更新使用者名稱失敗';

  @override
  String get profileDescriptionWordLimitError => '描述不可超過 100 個單字';

  @override
  String get profileDescriptionUpdated => '已更新描述';

  @override
  String get profileAvatarTooLarge => '頭像過大（上限 256KB），請選擇較小圖片。';

  @override
  String get profileAvatarUploadFailed => '上傳頭像失敗';

  @override
  String get profileAvatarUpdated => '已更新頭像';

  @override
  String get profileUsernameDialogTitle => '使用者名稱';

  @override
  String get profileUsernameHint => '3–32 字元，支援任何語言、符號與空白';

  @override
  String homeUnreadSummary(int count) {
    return '$count 則未讀訊息';
  }

  @override
  String get homeViewProfile => '查看個人檔案';

  @override
  String get homeUsernameDialogTitle => '使用者名稱';

  @override
  String get homeUsernameHint => '3–32 字元，a-z A-Z 0-9 . _ -';

  @override
  String get chatHomeTitle => 'Sync 聊天';

  @override
  String chatHomeServerLabel(String server) {
    return '伺服器：$server';
  }

  @override
  String chatHomeRealtimeStatus(String status) {
    return '即時連線：$status';
  }

  @override
  String get chatHomeDisconnected => '未連線';

  @override
  String get chatHomePushInitialized => '推播：已初始化';

  @override
  String get chatHomePushPending => '推播：初始化中';

  @override
  String get chatHomePartnerHint => '對方使用者 UUID';

  @override
  String get chatHomeOpenAction => '開啟';

  @override
  String get chatHomeRefreshUnread => '重新整理未讀';

  @override
  String chatHomeActiveUnread(int count) {
    return '目前對話未讀：$count';
  }

  @override
  String get chatHomeEnterPartnerPrompt => '輸入對方 UUID 以載入對話。';

  @override
  String chatHomeFailedToLoadMessages(String error) {
    return '載入訊息失敗：$error';
  }

  @override
  String get chatHomeLoadOlder => '載入較舊訊息';

  @override
  String get chatHomeSelectedImage => '已選取圖片';

  @override
  String get chatHomeRemoveMediaTooltip => '移除媒體';

  @override
  String get chatHomeTyping => '輸入中…';

  @override
  String get actionBack => '返回';

  @override
  String get actionCopy => '複製';

  @override
  String get actionEdit => '編輯';

  @override
  String get actionSave => '儲 存';

  @override
  String get actionCancel => '取消';

  @override
  String get actionNext => '下 一 步';

  @override
  String get chatSentASticker => '傳送了一個貼圖';

  @override
  String get chatSentAnAttachment => '傳送了一個附件';

  @override
  String get profileTrustFriendAddsLabel => '今日加好友次數';

  @override
  String get profileTrustChallengeStateFrozen => '您的帳號已被凍結，請聯繫客服以恢復存取權限。';

  @override
  String get profileTrustChallengeStateChallenged => '您的帳號正在審查中，部分功能可能受限。';

  @override
  String get profileTrustMilestoneRankUp => '段位提升！';

  @override
  String get profileTrustMilestoneUnlockAttachmentType => '已解鎖新的附件類型！';

  @override
  String get profileTrustMilestoneLevelUp => '等級提升！';

  @override
  String profileTrustMilestoneRankDetail(String rank) {
    return '您已達到 $rank 段位。';
  }

  @override
  String profileTrustMilestoneUnlockDetail(String type) {
    return '您現在可以傳送 $type 附件。';
  }

  @override
  String profileTrustMilestoneLevelDetail(String level) {
    return '您已達到第 $level 級。';
  }
}
