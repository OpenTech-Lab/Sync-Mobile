import 'package:mobile/l10n/app_localizations.dart';

import '../../services/remote_chat_service.dart';

class ChatSendErrorFeedback {
  const ChatSendErrorFeedback({
    required this.toastMessage,
    this.inlineMessage,
    this.allowsRetry = true,
  });

  final String toastMessage;
  final String? inlineMessage;
  final bool allowsRetry;
}

ChatSendErrorFeedback? buildChatSendErrorFeedback(
  Object error,
  AppLocalizations l10n,
) {
  if (error is! RemoteChatApiException) {
    return null;
  }

  if (error.code == 'daily_message_limit_reached') {
    final retryWindow = _formatRetryWindow(l10n, error.retryAfterSeconds);
    final guild = error.guild;
    final limit = guild?.dailyOutboundMessagesLimit;

    return ChatSendErrorFeedback(
      toastMessage: limit == null
          ? l10n.chatTrustDailyLimitToastGeneric(retryWindow)
          : l10n.chatTrustDailyLimitToast(
              guild!.dailyOutboundMessagesSent,
              limit,
              retryWindow,
            ),
      inlineMessage: l10n.chatTrustDailyLimitInline(retryWindow),
      allowsRetry: false,
    );
  }

  return null;
}

String _formatRetryWindow(AppLocalizations l10n, int? retryAfterSeconds) {
  if (retryAfterSeconds == null || retryAfterSeconds <= 0) {
    return l10n.chatTrustRetryWindowReset;
  }
  if (retryAfterSeconds >= 3600) {
    final hours = (retryAfterSeconds + 3599) ~/ 3600;
    return l10n.chatTrustRetryWindowHours(hours);
  }
  final minutes = (retryAfterSeconds + 59) ~/ 60;
  return l10n.chatTrustRetryWindowMinutes(minutes);
}
