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
  String get friendRemoved => '已移除好友';

  @override
  String get friendAdded => '已新增好友';

  @override
  String get settingsMyPlanet => '我的 Planet';

  @override
  String get settingsAppearance => '外觀';

  @override
  String get settingsTheme => '主題';

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
  String get friendRemoved => '已移除好友';

  @override
  String get friendAdded => '已新增好友';

  @override
  String get settingsMyPlanet => '我的 Planet';

  @override
  String get settingsAppearance => '外觀';

  @override
  String get settingsTheme => '主題';

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
  String get actionCancel => '取消';

  @override
  String get actionNext => '下 一 步';
}
