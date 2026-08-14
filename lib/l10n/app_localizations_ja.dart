// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Sync';

  @override
  String get loadingSync => '同期中';

  @override
  String get errorTitle => 'エラー';

  @override
  String get errorNetwork => 'インターネット接続を確認して、もう一度お試しください。';

  @override
  String get errorServer => 'サーバーに問題が発生しています。しばらくしてからもう一度お試しください。';

  @override
  String get errorPermission => 'この操作を行う権限がありません。問題が続く場合は管理者にお問い合わせください。';

  @override
  String get errorGeneric => 'エラーが発生しました。もう一度お試しください。';

  @override
  String get errorCallPermission => '通話にはマイクとカメラへのアクセスが必要です。設定でアクセスを許可してからもう一度お試しください。';

  @override
  String get restartAppHint => 'アプリを再起動してください';

  @override
  String get tabHome => 'ホーム';

  @override
  String get tabPlanet => 'プラネット';

  @override
  String get tabChats => 'チャット';

  @override
  String get tabSettings => '設定';

  @override
  String get languageLabel => '言語';

  @override
  String get languageSystem => 'システム';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => '繁体字中国語';

  @override
  String get languageJapanese => '日本語';

  @override
  String get welcomeTitle => 'Syncへようこそ';

  @override
  String get welcomeSubtitle => 'プラネットサーバーに接続して始めましょう。';

  @override
  String get serverUrlLabel => 'サーバーURL';

  @override
  String get serverUrlHint => 'https://my-planet.example.com';

  @override
  String get quickConnectLabel => 'クイック接続';

  @override
  String get checkingConnection => '確認中…';

  @override
  String get checkConnectionAction => '接 続 確 認';

  @override
  String get continueAction => '続 け る';

  @override
  String get connectionFailed => '接続に失敗しました。';

  @override
  String get connectedStatus => '接続済み';

  @override
  String get secureStatus => 'セキュア';

  @override
  String get publicStatus => '公開';

  @override
  String latencyValue(String ms) {
    return '$ms ms';
  }

  @override
  String get planetCardHost => 'ホスト';

  @override
  String get planetCardCountry => '国';

  @override
  String get planetCardProtocol => 'プロトコル';

  @override
  String get planetCardLatency => '遅延';

  @override
  String get planetRegistrationLabel => 'REGISTRATION';

  @override
  String get planetRegistrationApprovalRequired => '承認が必要';

  @override
  String get authTagline => 'あなたのプライベートメッセンジャー';

  @override
  String get signInTab => 'サインイン';

  @override
  String get signUpTab => 'サインアップ';

  @override
  String get accountFoundForServer => 'このサーバーのアカウントが見つかりました';

  @override
  String get resetPasswordTitle => 'パスワードをリセット';

  @override
  String get resetPasswordSentHint => 'そのメールが登録されていれば、リセットリンクが送信されました。';

  @override
  String get resetPasswordEnterEmailHint => 'メールアドレスを入力してください。リセットリンクをお送りします。';

  @override
  String get emailLabel => 'メール';

  @override
  String get passwordLabel => 'パスワード';

  @override
  String get usernameLabel => 'ユーザー名';

  @override
  String get passwordMin8Label => 'パスワード・8文字以上';

  @override
  String get actionClose => '閉じる';

  @override
  String get actionSend => '送 信';

  @override
  String get forgotPassword => 'パスワードを忘れた方';

  @override
  String get signingInProgress => 'サインイン中…';

  @override
  String get signInAction => 'サ イ ン イ ン';

  @override
  String get authQrTitle => 'QRでサインイン';

  @override
  String get authQrHint => 'スマートフォンでSyncを開き、マイプロフィールからこのコードをスキャンしてください。';

  @override
  String get authQrWaitingForScan => 'スマートフォンの承認待ち…';

  @override
  String get authQrExpired => 'QRの有効期限が切れました。更新してください。';

  @override
  String get authQrUnavailable => 'QRログインを利用できません。更新してください。';

  @override
  String get authQrPressRefresh => '更新ボタンを押してください';

  @override
  String get authQrRefresh => 'QRを更新';

  @override
  String get creatingAccountProgress => 'アカウント作成中…';

  @override
  String get createAccountAction => 'ア カ ウ ン ト 作 成';

  @override
  String get myProfileTitle => 'マイプロフィール';

  @override
  String friendsTitle(int count) {
    return '友達（$count）';
  }

  @override
  String get noFriendsYet => 'まだ友達がいません';

  @override
  String get openChatsHint => 'チャットを開いて会話を始めましょう';

  @override
  String get homeConnectedPlanetsTitle => '接続済みプラネット';

  @override
  String get planetOtherPlanetsTitle => '他のプラネット';

  @override
  String get homeConnectedPlanetsEmpty => '接続済みプラネットがありません';

  @override
  String get homeConnectedPlanetsLoading => '接続済みプラネットを読み込み中…';

  @override
  String get homeConnectedPlanetsLoadFailed => '接続済みプラネットの読み込みに失敗しました';

  @override
  String homePlanetMembers(int count) {
    return '$count人のメンバー';
  }

  @override
  String get friendRemoved => '友達を削除しました';

  @override
  String get friendAdded => '友達を追加しました';

  @override
  String get planetLoading => 'プラネットデータを読み込み中…';

  @override
  String get planetLoadFailed => 'プラネットデータの読み込みに失敗しました。';

  @override
  String get planetReconnectAction => '再接続';

  @override
  String get planetReconnectInProgress => '再接続中';

  @override
  String get planetReconnectSuccess => 'プラネットに再接続しました。';

  @override
  String get planetReconnectFailed => 'プラネットへの再接続に失敗しました。';

  @override
  String get planetNewsTitle => 'ニュース';

  @override
  String get planetNewsEmpty => 'まだニュースはありません';

  @override
  String get planetNewsDetailTitle => 'ニュース';

  @override
  String get planetStickersTitle => 'プラネットスタンプ';

  @override
  String get planetStickerDownload => 'ダウンロード';

  @override
  String get planetStickerDownloaded => 'ダウンロード済み';

  @override
  String get planetStickerDownloading => 'ダウンロード中…';

  @override
  String get planetStickerDownloadFailed => 'スタンプのダウンロードに失敗しました。';

  @override
  String planetStickerDownloadedToast(String name) {
    return '$nameをローカルスタンプにダウンロードしました。';
  }

  @override
  String planetStickerGroupCount(int count) {
    return '$count個のスタンプ';
  }

  @override
  String planetStickerGroupDownloadedToast(String group) {
    return '$groupスタンプパックをダウンロードしました。';
  }

  @override
  String get settingsMyPlanet => 'マイプラネット';

  @override
  String get settingsAppearance => '外観';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get settingsTypingStyleMode => 'タイピングスタイルモード';

  @override
  String get settingsTypingStyleModeHint => 'タイピングアニメーションでメッセージを表示';

  @override
  String get settingsTypingStyleSpeed => 'タイピング速度';

  @override
  String get settingsTypingStyleSpeedHint => '小さいほど速い';

  @override
  String settingsTypingStyleSpeedValue(int ms) {
    return '${ms}ms / 文字';
  }

  @override
  String get themeLight => 'ライト';

  @override
  String get themeSystem => 'システム';

  @override
  String get themeDark => 'ダーク';

  @override
  String get settingsEncryptedBackups => '暗号化バックアップ';

  @override
  String get settingsEnableBackups => 'バックアップを有効にする';

  @override
  String get settingsBackupSubtitle => 'プラネットサーバーでエンドツーエンド暗号化';

  @override
  String get settingsCreateBackup => 'バックアップを作成';

  @override
  String get settingsRestore => '復元';

  @override
  String get settingsDeleteBackupData => 'バックアップデータを削除';

  @override
  String get settingsLocalData => '削除';

  @override
  String get settingsDeleteAllPlanetData => 'このプラネットのすべてのデータを削除';

  @override
  String get settingsDeleteAllPlanetDataMessage => 'ローカルデータ（チャット、友達、設定）とサーバー上の暗号化バックアップを永久に削除します。この操作は取り消せません。';

  @override
  String get settingsDeleteAllPlanetDataConfirm => 'す べ て 削 除';

  @override
  String get settingsDeleteAllLocalChats => 'すべてのローカルチャットデータを削除';

  @override
  String get settingsDeleteAllAppData => 'すべてのアプリデータを削除';

  @override
  String get settingsSignOut => 'サインアウト';

  @override
  String get chatToday => '今日';

  @override
  String get chatUnreadHeader => '未読';

  @override
  String get chatChatsHeader => 'チャット';

  @override
  String get chatRowDelete => '削除';

  @override
  String get chatRowHide => '非表示';

  @override
  String get chatNoChatsYet => 'チャットがまだありません。';

  @override
  String get chatNoMessagesYet => 'メッセージがまだありません。\nこんにちはと言いましょう！';

  @override
  String get chatSearchHint => '検索…';

  @override
  String get chatMessageHint => 'メッセージ…';

  @override
  String get chatAttachImageTooltip => '画像を添付';

  @override
  String get chatStickersTooltip => 'スタンプ';

  @override
  String get chatNoStickersYet => 'スタンプがまだありません。';

  @override
  String get chatStickersHeader => 'スタンプ';

  @override
  String get chatMore => 'もっと見る';

  @override
  String get chatMarkAllRead => 'すべて既読にする';

  @override
  String get chatMarkedAllAsRead => 'すべて既読にしました';

  @override
  String chatTypingIndicator(String name) {
    return '$nameが入力中…';
  }

  @override
  String get chatDefaultPartner => '相手';

  @override
  String get chatDefaultTitle => 'チャット';

  @override
  String get chatAddFriendHeader => '友達を追加';

  @override
  String get chatAddFriendTitle => '友達リンクまたはユーザーIDを貼り付け';

  @override
  String get chatAddFriendFormatHint => '対応形式：https://server.tld/<user-id>';

  @override
  String get chatAddFriendInputHint => '友達リンクまたはユーザーID';

  @override
  String chatMarkReadPartial(int success, int total) {
    return '$success/$totalの会話を既読にしました';
  }

  @override
  String get chatSelectedMediaFallback => '画像';

  @override
  String get chatPasteImageAction => '画像を貼り付け';

  @override
  String get chatTrustRetryWindowReset => '毎日のリセット後';

  @override
  String chatTrustRetryWindowHours(int hours) {
    return '$hours時間後';
  }

  @override
  String chatTrustRetryWindowMinutes(int minutes) {
    return '$minutes分後';
  }

  @override
  String chatTrustDailyLimitToast(int used, int limit, String retryWindow) {
    return '1日のメッセージ上限に達しました（$used/$limit）。$retryWindowに再送信できます。またはレベルアップして上限を上げてください。';
  }

  @override
  String chatTrustDailyLimitToastGeneric(String retryWindow) {
    return '1日のメッセージ上限に達しました。$retryWindowに再送信できます。またはレベルアップして上限を上げてください。';
  }

  @override
  String chatTrustDailyLimitInline(String retryWindow) {
    return '上限到達・$retryWindowに再試行・またはレベルアップ';
  }

  @override
  String get chatMessageDetailTitleMine => 'あなたのメッセージ';

  @override
  String get chatMessageDetailTitleOther => 'メッセージ';

  @override
  String get chatCopiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get chatAttachmentViewerTitle => '添付ファイル';

  @override
  String get chatDownloadAttachmentTooltip => '添付ファイルをダウンロード';

  @override
  String get chatAttachmentDownloaded => '添付ファイルをダウンロードしました';

  @override
  String get chatAttachmentDownloadFailed => '添付ファイルのダウンロードに失敗しました';

  @override
  String get chatQuickNewHeader => '新規';

  @override
  String get chatQuickNewRoom => '新しいルーム';

  @override
  String get chatQuickFriendOrStart => '友達 / チャット開始';

  @override
  String get chatQuickScanFriendQr => '友達のQRをスキャン';

  @override
  String get chatCreateRoomHeader => 'ルーム';

  @override
  String get chatCreateRoomTitle => 'プライベートルームを作成';

  @override
  String get chatCreateRoomNameLabel => 'ルーム名';

  @override
  String get chatCreateRoomNameHint => '週末の計画';

  @override
  String get chatCreateRoomMembersLabel => 'メンバー';

  @override
  String get chatCreateRoomNoFriends => '先に友達を追加するか、ルームを作成してから招待してください。';

  @override
  String get chatCreateRoomAction => '作 成';

  @override
  String get chatRoomCreated => 'ルームを作成しました';

  @override
  String get chatClearHistory => '削除';

  @override
  String get chatDefaultRoom => 'ルーム';

  @override
  String get chatScanFriendQrInstruction => '友達のQRコードにカメラを向けてください';

  @override
  String get chatTargetCancelFriend => '友達をキャンセル';

  @override
  String get chatTargetAddFriend => '友 達 追 加';

  @override
  String get chatTargetFriend => '友達';

  @override
  String get chatTargetStartChat => 'チ ャ ッ ト 開 始';

  @override
  String get chatTargetFriendSince => '友達になった日';

  @override
  String get chatTargetMessagesSent => '送信したメッセージ';

  @override
  String get chatTargetAbout => 'プロフィール';

  @override
  String get chatExportHistory => 'チャット履歴をエクスポート';

  @override
  String get chatExportCopyAction => 'クリップボードにコピー';

  @override
  String get chatExportSaveAction => '.txtとして保存';

  @override
  String get chatExportCopied => 'チャット履歴をコピーしました';

  @override
  String get chatExportSaved => 'チャット履歴を保存しました';

  @override
  String get chatExportFailed => 'チャット履歴のエクスポートに失敗しました';

  @override
  String get chatNotes => 'メモ';

  @override
  String get chatNotesHint => 'メモを書く…';

  @override
  String get chatTodos => 'ToDo';

  @override
  String get chatTodosHint => 'ToDoを追加…';

  @override
  String get chatTodosAddAction => '追加';

  @override
  String get chatTodosEmptyHint => 'ToDoがまだありません';

  @override
  String get settingsMissingAccessTokenBackup => 'バックアップのアクセストークンがありません。';

  @override
  String get settingsMissingAccessTokenRestore => '復元のアクセストークンがありません。';

  @override
  String get settingsDeleteBackupTitle => 'バックアップデータを削除';

  @override
  String get settingsDeleteBackupMessage => 'このデバイスの暗号化バックアップファイルを削除します。\nこの操作は取り消せません。';

  @override
  String get settingsDeleteBackupConfirm => 'バ ッ ク ア ッ プ 削 除';

  @override
  String get settingsMissingAccessTokenBackupDelete => 'バックアップ削除のアクセストークンがありません。';

  @override
  String settingsAutoBackupSchedule(int threshold) {
    return '自動バックアップは24時間ごと、または$threshold件の新しいメッセージの後に実行されます（どちらか早い方）。';
  }

  @override
  String get settingsAutoBackupThreshold => '自動バックアップのしきい値';

  @override
  String get settingsAutoBackupDecreaseTooltip => 'しきい値を下げる';

  @override
  String get settingsAutoBackupIncreaseTooltip => 'しきい値を上げる';

  @override
  String get settingsMessagesUnit => '件';

  @override
  String get settingsDeleteLocalChatsTitle => 'ローカルチャットデータを削除';

  @override
  String get settingsDeleteLocalChatsMessage => 'このデバイスに保存されているすべてのチャット履歴を削除します。\nサーバー側のデータは変更されません。';

  @override
  String get settingsDeleteLocalChatsConfirm => 'ロ ー カ ル チ ャ ッ ト 削 除';

  @override
  String get settingsDeleteAllAppDataTitle => 'すべてのアプリデータを削除';

  @override
  String get settingsDeleteAllAppDataMessage => 'チャット履歴、設定、キャッシュデータを含むすべてのローカルデータを永久に削除します。\nサーバー側のデータは変更されません。';

  @override
  String get settingsDeleteAllAppDataConfirm => 'す べ て 削 除';

  @override
  String get settingsSignOutMessage => 'このアカウントからサインアウトします。\nローカルメッセージはデバイスに残ります。';

  @override
  String get settingsSignOutConfirm => 'サ イ ン ア ウ ト';

  @override
  String get settingsDeleteAccount => 'このプラネットからアカウントを削除';

  @override
  String get settingsDeleteAccountMessage => 'このプラネットからアカウントが永久に削除されます。すべてのローカルデータとサーバーバックアップも削除されます。この操作は取り消せません。';

  @override
  String get settingsDeleteAccountConfirm => 'ア カ ウ ン ト 削 除';

  @override
  String get settingsDangerousActions => '危険な操作';

  @override
  String get settingsDangerousActionsHint => 'ローカルチャットの削除、アプリデータのクリア、またはサインアウト';

  @override
  String settingsDeletionCountdown(String countdown) {
    return '削除は$countdown後に実行されます。';
  }

  @override
  String get settingsDeletionExecuting => '削除を実行しています。';

  @override
  String get settingsPlanetUnknownName => '不明なプラネット';

  @override
  String get settingsPlanetNoDescription => 'まだプラネットの説明がありません。';

  @override
  String get settingsOnline => 'オンライン';

  @override
  String get settingsOffline => 'オフライン';

  @override
  String get settingsNotificationsOn => '通知オン';

  @override
  String get settingsNotificationsOff => '通知オフ';

  @override
  String get settingsResidents => '住人';

  @override
  String get settingsStickers => 'スタンプ';

  @override
  String get settingsEncrypted => '暗号化済み';

  @override
  String get settingsCreated => '作成日';

  @override
  String get profileTitle => 'プロフィール';

  @override
  String get profileNoDescriptionYet => 'まだ説明がありません';

  @override
  String get profileFriendLinkCopied => '友達リンクをコピーしました';

  @override
  String get profileCopyFriendLink => '友達リンクをコピー';

  @override
  String get profileTrustSectionTitle => 'GUILD';

  @override
  String profileGuildLevel(int level) {
    return 'レベル $level';
  }

  @override
  String profileGuildRank(String rank) {
    return 'ランク $rank';
  }

  @override
  String profileTrustProgressLabel(int activeDays) {
    return 'アクティブ日数 $activeDays';
  }

  @override
  String profileTrustNextLevel(int days, int level) {
    return 'レベル$levelまであと$days日';
  }

  @override
  String get profileTrustMaxLevel => '最高レベルを解除済み';

  @override
  String get profileTrustMessagesLabel => '今日のメッセージ';

  @override
  String get profileTrustAttachmentsLabel => '今日の添付ファイル';

  @override
  String get profileTrustUnlimited => '無制限';

  @override
  String profileTrustUsage(int used, int limit) {
    return '$used / $limit';
  }

  @override
  String get profileFriendQrTitle => '友達QR';

  @override
  String get profileFriendQrHint => 'サーバーURLとIDが含まれています';

  @override
  String get profileQrPayloadCopied => 'QRペイロードをコピーしました';

  @override
  String get profileCopyQrPayload => 'QRペイロードをコピー';

  @override
  String get profileDeviceLoginSectionTitle => 'デバイスログイン';

  @override
  String get profileDeviceLoginPageTitle => 'スキャンしてログインを承認';

  @override
  String get profileDeviceLoginAction => '別のデバイスのログインを承認';

  @override
  String get profileDeviceLoginHint => 'スマートフォンでデスクトップまたはブラウザのログインを承認';

  @override
  String get profileDeviceLoginScanHint => 'デスクトップまたはブラウザに表示されたQRコードにカメラを向けてください';

  @override
  String get profileDeviceLoginApproved => 'ログインを承認しました';

  @override
  String get profileDeviceLoginFailed => 'ログインの承認に失敗しました';

  @override
  String get profileAboutYouLabel => 'あなたについて';

  @override
  String get profileAboutYouTitle => '自己紹介を書いてください';

  @override
  String get profileDescriptionHint => '他の人に知ってほしいことを書いてください…';

  @override
  String get profileDescriptionExceeded => '100語の制限を超えました';

  @override
  String profileWordCount(int words) {
    return '$words / 100';
  }

  @override
  String get profileUsernameValidationError => 'ユーザー名は2〜32文字で、任意の言語、記号、スペースを使用できます';

  @override
  String get profileUsernameUpdated => 'ユーザー名を更新しました';

  @override
  String get profileUsernameUpdateFailed => 'ユーザー名の更新に失敗しました';

  @override
  String get profileDescriptionWordLimitError => '説明は100語以内にしてください';

  @override
  String get profileDescriptionUpdated => '説明を更新しました';

  @override
  String get profileDescriptionUpdateFailed => '説明の更新に失敗しました';

  @override
  String get profileAvatarTooLarge => 'アバターが大きすぎます（最大256KB）。より小さい画像を選択してください。';

  @override
  String get profileAvatarUploadFailed => 'アバターのアップロードに失敗しました';

  @override
  String get profileAvatarUpdated => 'アバターを更新しました';

  @override
  String get profileUsernameDialogTitle => 'ユーザー名';

  @override
  String get profileUsernameHint => '2〜32文字、任意の言語・記号・スペース対応';

  @override
  String homeUnreadSummary(int count) {
    return '$count件の未読メッセージ';
  }

  @override
  String get homeViewProfile => 'プロフィールを見る';

  @override
  String get homeUsernameDialogTitle => 'ユーザー名';

  @override
  String get homeUsernameHint => '2〜32文字、a-z A-Z 0-9 . _ -';

  @override
  String get chatHomeTitle => 'Syncチャット';

  @override
  String chatHomeServerLabel(String server) {
    return 'サーバー：$server';
  }

  @override
  String chatHomeRealtimeStatus(String status) {
    return 'リアルタイム：$status';
  }

  @override
  String get chatHomeDisconnected => '切断';

  @override
  String get chatHomePushInitialized => 'プッシュ：初期化済み';

  @override
  String get chatHomePushPending => 'プッシュ：保留中';

  @override
  String get chatHomePartnerHint => '相手のユーザーUUID';

  @override
  String get chatHomeOpenAction => '開く';

  @override
  String get chatHomeRefreshUnread => '未読を更新';

  @override
  String chatHomeActiveUnread(int count) {
    return 'アクティブな相手の未読：$count';
  }

  @override
  String get chatHomeEnterPartnerPrompt => '会話を読み込むには相手のUUIDを入力してください。';

  @override
  String get chatHomeFailedToLoadMessages => 'メッセージの読み込みに失敗しました。';

  @override
  String get chatHomeLoadOlder => '古いメッセージを読み込む';

  @override
  String get chatHomeSelectedImage => '選択した画像';

  @override
  String get chatHomeRemoveMediaTooltip => 'メディアを削除';

  @override
  String get chatHomeTyping => '入力中…';

  @override
  String get actionBack => '戻る';

  @override
  String get actionCopy => 'コピー';

  @override
  String get actionEdit => '編集';

  @override
  String get actionSave => '保 存';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionNext => '次 へ';

  @override
  String get chatSentASticker => 'スタンプを送信しました';

  @override
  String get chatSentAnAttachment => '添付ファイルを送信しました';

  @override
  String get profileTrustFriendAddsLabel => '今日の友達追加';

  @override
  String get profileTrustChallengeStateFrozen => 'アカウントが凍結されています。アクセスを復元するにはサポートにお問い合わせください。';

  @override
  String get profileTrustChallengeStateChallenged => 'アカウントは審査中です。一部の操作が制限される場合があります。';

  @override
  String get profileTrustMilestoneRankUp => 'ランクアップ！';

  @override
  String get profileTrustMilestoneUnlockAttachmentType => '新しい添付ファイルタイプが解除されました！';

  @override
  String get profileTrustMilestoneLevelUp => 'レベルアップ！';

  @override
  String profileTrustMilestoneRankDetail(String rank) {
    return '$rankランクに到達しました。';
  }

  @override
  String profileTrustMilestoneUnlockDetail(String type) {
    return '$typeの添付ファイルを送信できるようになりました。';
  }

  @override
  String profileTrustMilestoneLevelDetail(String level) {
    return 'レベル$levelに到達しました。';
  }

  @override
  String get settingsAdminPanel => '管理パネル';

  @override
  String get settingsAdminPanelHint => 'ユーザー管理とモデレーション。';

  @override
  String get adminUsersTitle => '管理パネル';

  @override
  String get adminUsersEmpty => 'ユーザーが見つかりませんでした。';

  @override
  String get adminUsersErrorLoad => 'ユーザーの読み込みに失敗しました。';

  @override
  String get adminActionYellowCard => 'イエローカード';

  @override
  String get adminActionClearCard => '制限解除';

  @override
  String get adminActionSuspend => '停止';

  @override
  String get adminActionActivate => '有効化';

  @override
  String get adminYellowCardConfirmTitle => 'イエローカードを発行しますか？';

  @override
  String get adminYellowCardConfirmMessage => 'このユーザーは3日間、メッセージの送信と連絡先の追加ができなくなります。';

  @override
  String get adminSuspendConfirmTitle => 'ユーザーを停止しますか？';

  @override
  String get adminSuspendConfirmMessage => '手動で再有効化するまで、このユーザーは永久に停止されます。';

  @override
  String get adminYellowCardIssued => 'イエローカードを発行しました。';

  @override
  String get adminYellowCardCleared => '制限を解除しました。';

  @override
  String get adminUserSuspended => 'ユーザーを停止しました。';

  @override
  String get adminUserActivated => 'ユーザーを有効化しました。';

  @override
  String get adminStatusYellowCard => 'イエローカード';

  @override
  String get adminStatusSuspended => '停止中';
}
