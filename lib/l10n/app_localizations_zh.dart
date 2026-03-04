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
  String get settingsLocalData => '本機資料';

  @override
  String get settingsDeleteAllLocalChats => '刪除本機所有聊天資料';

  @override
  String get settingsSignOut => '登出';

  @override
  String get chatToday => '今天';

  @override
  String get chatUnreadHeader => '未讀';

  @override
  String get chatChatsHeader => '聊天';

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
  String get chatMessageDetailTitleMine => '你的訊息';

  @override
  String get chatMessageDetailTitleOther => '訊息';

  @override
  String get chatCopiedToClipboard => '已複製到剪貼簿';

  @override
  String get chatQuickNewHeader => '新增';

  @override
  String get chatQuickFriendOrStart => '好友 / 開始聊天';

  @override
  String get chatQuickScanFriendQr => '掃描好友 QR';

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
  String get settingsSignOutMessage => '你將從此帳號登出。\n本機訊息會保留在裝置上。';

  @override
  String get settingsSignOutConfirm => '登 出';

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
  String get profileFriendQrTitle => '好友 QR';

  @override
  String get profileFriendQrHint => '包含你的伺服器網址與 ID';

  @override
  String get profileQrPayloadCopied => '已複製 QR 內容';

  @override
  String get profileCopyQrPayload => '複製 QR 內容';

  @override
  String get profileDeviceLoginAction => '掃描 QR 以登入其他裝置';

  @override
  String get profileDeviceLoginHint => '用手機相機核准桌面/網頁登入';

  @override
  String get profileDeviceLoginScanHint => '掃描桌面/網頁顯示的登入 QR';

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
  String get profileUsernameValidationError => '使用者名稱需為 3-32 字元：a-zA-Z0-9._-';

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
  String get profileUsernameHint => '3–32 字元，a-zA-Z0-9._-';

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
  String get settingsLocalData => '本機資料';

  @override
  String get settingsDeleteAllLocalChats => '刪除本機所有聊天資料';

  @override
  String get settingsSignOut => '登出';

  @override
  String get chatToday => '今天';

  @override
  String get chatUnreadHeader => '未讀';

  @override
  String get chatChatsHeader => '聊天';

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
  String get chatMessageDetailTitleMine => '你的訊息';

  @override
  String get chatMessageDetailTitleOther => '訊息';

  @override
  String get chatCopiedToClipboard => '已複製到剪貼簿';

  @override
  String get chatQuickNewHeader => '新增';

  @override
  String get chatQuickFriendOrStart => '好友 / 開始聊天';

  @override
  String get chatQuickScanFriendQr => '掃描好友 QR';

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
  String get settingsSignOutMessage => '你將從此帳號登出。\n本機訊息會保留在裝置上。';

  @override
  String get settingsSignOutConfirm => '登 出';

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
  String get profileFriendQrTitle => '好友 QR';

  @override
  String get profileFriendQrHint => '包含你的伺服器網址與 ID';

  @override
  String get profileQrPayloadCopied => '已複製 QR 內容';

  @override
  String get profileCopyQrPayload => '複製 QR 內容';

  @override
  String get profileDeviceLoginAction => '掃描 QR 以登入其他裝置';

  @override
  String get profileDeviceLoginHint => '用手機相機核准桌面/網頁登入';

  @override
  String get profileDeviceLoginScanHint => '掃描桌面/網頁顯示的登入 QR';

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
  String get profileUsernameValidationError => '使用者名稱需為 3-32 字元：a-zA-Z0-9._-';

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
  String get profileUsernameHint => '3–32 字元，a-zA-Z0-9._-';

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
}
