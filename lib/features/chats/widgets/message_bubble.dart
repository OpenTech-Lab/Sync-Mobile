import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../models/local_chat_message.dart';
import '../../../models/sticker.dart';
import '../../../state/sticker_controller.dart';
import '../../../state/user_profile_controller.dart';
import '../../../ui/components/atoms/app_toast.dart';
import '../../../ui/tokens/colors/app_palette.dart';
import '../../../services/chat_ui_preferences.dart';
import '../models/outgoing_draft.dart';
import 'quick_action_sheet.dart';
import 'chat_attachment_viewer_page.dart';
import '../utils/chat_media_cache.dart';
import '../utils/chat_helpers.dart';

class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.currentUserId,
    required this.partnerId,
    required this.isRoomConversation,
    this.onAvatarTap,
    required this.stickers,
    required this.serverUrl,
    required this.accessToken,
    this.deliveryState,
    this.statusLabel,
    this.onRetryTap,
    this.onReportMessage,
    this.typingStyleModeEnabled = false,
    this.typingStyleSpeedMs = ChatUiPreferences.defaultTypingStyleSpeedMs,
    this.animateAsDraft = false,
  });

  final LocalChatMessage message;
  final bool isMine;
  final String currentUserId;
  final String partnerId;
  final bool isRoomConversation;
  final VoidCallback? onAvatarTap;
  final List<Sticker> stickers;
  final String serverUrl;
  final String accessToken;
  final OutgoingDeliveryState? deliveryState;
  final String? statusLabel;
  final VoidCallback? onRetryTap;
  final Future<void> Function(LocalChatMessage message)? onReportMessage;
  final bool typingStyleModeEnabled;
  final int typingStyleSpeedMs;
  final bool animateAsDraft;

  static const double _kMaxBubbleHeight = 180;

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MessageDetailScreen(message: message, isMine: isMine),
      ),
    );
  }

  void _openAttachmentDetail(BuildContext context, ParsedInlineMedia media) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatAttachmentViewerPage(
          bytes: media.bytes,
          suggestedFileName: media.suggestedFileName,
        ),
      ),
    );
  }

  Future<void> _showMessageActions(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? AppPalette.neutral900
              : AppPalette.neutral50,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final inkColor =
            isDark ? AppPalette.neutral100 : AppPalette.neutral800;
        final mutedColor = AppPalette.neutral500;
        final ruleColor =
            isDark ? AppPalette.neutral700 : AppPalette.neutral300;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'MESSAGE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.8,
                    color: mutedColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: ruleColor),
                SheetItem(
                  label: 'Copy message',
                  inkColor: inkColor,
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Clipboard.setData(
                      ClipboardData(text: message.body),
                    );
                    if (context.mounted) {
                      showAppToast(context, l10n.chatExportCopied);
                    }
                  },
                ),
                if (!isMine && onReportMessage != null) ...[
                  Divider(height: 1, color: ruleColor),
                  SheetItem(
                    label: 'Report message',
                    inkColor: AppPalette.danger700,
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await onReportMessage!(message);
                    },
                  ),
                ],
                Divider(height: 1, color: ruleColor),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => Navigator.of(sheetContext).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 12,
                        color: mutedColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget? _buildDeliveryStatusControl(Color statusColor) {
    if (!isMine || deliveryState == null) {
      return null;
    }

    switch (deliveryState!) {
      case OutgoingDeliveryState.sending:
        return const SizedBox(
          key: ValueKey('message_delivery_status'),
          width: 28,
          height: 28,
          child: Center(
            child: Icon(Icons.schedule, size: 11, color: AppPalette.neutral500),
          ),
        );
      case OutgoingDeliveryState.failed:
        return Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onRetryTap,
            radius: 18,
            child: SizedBox(
              key: const ValueKey('message_delivery_status'),
              width: 28,
              height: 28,
              child: Center(
                child: Icon(Icons.refresh, size: 14, color: statusColor),
              ),
            ),
          ),
        );
      case OutgoingDeliveryState.blocked:
        return SizedBox(
          key: const ValueKey('message_delivery_status'),
          width: 28,
          height: 28,
          child: Center(
            child: Icon(Icons.block_rounded, size: 12, color: statusColor),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;

    final myBubble = isDark
        ? AppPalette.chatBubbleSelfDark
        : AppPalette.chatBubbleSelfLight;
    final theirBubble = isDark
        ? AppPalette.chatBubblePeerDark
        : AppPalette.chatBubblePeerLight;

    final bubbleColor = isMine ? myBubble : theirBubble;
    final onBubble = inkColor;
    final statusColor = deliveryState == OutgoingDeliveryState.failed
        ? AppPalette.danger700
        : AppPalette.neutral500;
    final blockedStatusLabel =
        isMine &&
            deliveryState == OutgoingDeliveryState.blocked &&
            statusLabel != null &&
            statusLabel!.trim().isNotEmpty
        ? statusLabel!.trim()
        : null;
    const textMaxLines = 7;
    final messageTextStyle = TextStyle(
      color: onBubble,
      fontSize: 14,
      fontWeight: FontWeight.w300,
      height: 1.5,
    );
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.68;
    final deliveryStatusControl = _buildDeliveryStatusControl(statusColor);
    final overflowProbe = TextPainter(
      text: TextSpan(text: message.body, style: messageTextStyle),
      textDirection: Directionality.of(context),
      maxLines: textMaxLines,
    )..layout(maxWidth: maxBubbleWidth - 24);
    final isTruncated = overflowProbe.didExceedMaxLines;

    final avatarId = isMine ? currentUserId : message.senderId;
    final senderDisplayName = !isMine && isRoomConversation
        ? displayNameOrFallback(
            message.senderId,
            ref.watch(userDisplayNameProvider(message.senderId)).value,
          )
        : null;
    final avatarBase64 = ref.watch(userAvatarBase64Provider(avatarId)).value;

    const palette = [
      AppPalette.avatarTone1,
      AppPalette.avatarTone2,
      AppPalette.avatarTone3,
      AppPalette.avatarTone4,
      AppPalette.avatarTone5,
      AppPalette.avatarTone6,
    ];
    final hash = avatarId.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarBg = palette[hash.abs() % palette.length];

    // ── Image/media message ──────────────────────────────────────────────────
    final media = ChatMediaCache.parseInlineMedia(message);
    if (media != null) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              GestureDetector(
                onTap: onAvatarTap,
                child: MessageAvatar(
                  userId: avatarId,
                  avatarBase64: avatarBase64,
                  avatarBg: avatarBg,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (senderDisplayName != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 4),
                    child: Text(
                      senderDisplayName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppPalette.neutral500,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
                GestureDetector(
                  onTap: () => _openAttachmentDetail(context, media),
                  onLongPress: () => _showMessageActions(context, l10n),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image(
                          image: media.imageProvider,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          width: maxBubbleWidth,
                        ),
                        if (media.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                            child: Text(media.text, style: messageTextStyle),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeLabel(message.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppPalette.neutral500,
                  ),
                ),
                if (blockedStatusLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    blockedStatusLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppPalette.neutral500,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ],
            ),
            if (isMine) ...[
              const SizedBox(width: 6),
              MessageAvatar(
                userId: avatarId,
                avatarBase64: avatarBase64,
                avatarBg: avatarBg,
              ),
            ],
          ],
        ),
      );
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Sticker message ─────────────────────────────────────────────────────
    final stickerId = ChatMediaCache.parseStickerId(message.body);
    if (stickerId != null) {
      Sticker? found;
      for (final s in stickers) {
        if (s.id == stickerId) {
          found = s;
          break;
        }
      }
      AsyncValue<Sticker?>? remoteSticker;
      if (found == null) {
        remoteSticker = ref.watch(
          stickerByIdProvider((
            id: stickerId,
            baseUrl: serverUrl,
            accessToken: accessToken,
          )),
        );
        found = remoteSticker?.valueOrNull;
      }
      if (found != null) {
        final stickerImage = ChatMediaCache.resolveStickerImage(found);
        if (stickerImage != null) {
          return Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMine) ...[
                  GestureDetector(
                    onTap: onAvatarTap,
                    child: MessageAvatar(
                      userId: avatarId,
                      avatarBase64: avatarBase64,
                      avatarBg: avatarBg,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isMine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (senderDisplayName != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 4),
                        child: Text(
                          senderDisplayName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppPalette.neutral500,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ],
                    GestureDetector(
                      onLongPress: () => _showMessageActions(context, l10n),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image(
                          image: stickerImage,
                          width: 128,
                          height: 128,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeLabel(message.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppPalette.neutral500,
                      ),
                    ),
                    if (blockedStatusLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        blockedStatusLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppPalette.neutral500,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ],
                ),
                if (isMine) ...[
                  const SizedBox(width: 6),
                  MessageAvatar(
                    userId: avatarId,
                    avatarBase64: avatarBase64,
                    avatarBg: avatarBg,
                  ),
                ],
              ],
            ),
          );
        }
      }
      if (remoteSticker?.isLoading ?? false) {
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) ...[
                GestureDetector(
                  onTap: onAvatarTap,
                  child: MessageAvatar(
                    userId: avatarId,
                    avatarBase64: avatarBase64,
                    avatarBg: avatarBg,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (senderDisplayName != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 4),
                      child: Text(
                        senderDisplayName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppPalette.neutral500,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ],
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel(message.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppPalette.neutral500,
                    ),
                  ),
                ],
              ),
              if (isMine) ...[
                const SizedBox(width: 6),
                MessageAvatar(
                  userId: avatarId,
                  avatarBase64: avatarBase64,
                  avatarBg: avatarBg,
                ),
              ],
            ],
          ),
        );
      }
    }
    // ────────────────────────────────────────────────────────────────────────

    Widget bubble = Container(
      key: const ValueKey('message_bubble_surface'),
      constraints: BoxConstraints(
        minWidth: 84,
        maxWidth: maxBubbleWidth,
        maxHeight: _kMaxBubbleHeight,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
          bottomLeft: Radius.circular(isMine ? 6 : 2),
          bottomRight: Radius.circular(isMine ? 2 : 6),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 26),
            child: TypingStyleMessageText(
              messageId: message.id,
              body: message.body,
              createdAt: message.createdAt,
              enabled: typingStyleModeEnabled && (!isMine || animateAsDraft),
              typingFrameMs: typingStyleSpeedMs,
              maxLines: textMaxLines,
              textAlign: TextAlign.left,
              style: messageTextStyle,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bubbleColor.withValues(alpha: 0), bubbleColor],
                  stops: const [0.0, 0.55],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Row(
                children: isMine
                    ? [
                        if (isTruncated)
                          Text(
                            l10n.chatMore,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppPalette.neutral500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const Spacer(),
                        Text(
                          timeLabel(message.createdAt),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppPalette.neutral500,
                          ),
                        ),
                      ]
                    : [
                        Text(
                          timeLabel(message.createdAt),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppPalette.neutral500,
                          ),
                        ),
                        const Spacer(),
                        if (isTruncated)
                          Text(
                            l10n.chatMore,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppPalette.neutral500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
              ),
            ),
          ),
        ],
      ),
    );

    bubble = GestureDetector(
      onTap: () => _openDetail(context),
      onLongPress: () => _showMessageActions(context, l10n),
      child: bubble,
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            GestureDetector(
              onTap: onAvatarTap,
              child: MessageAvatar(
                userId: avatarId,
                avatarBase64: avatarBase64,
                avatarBg: avatarBg,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (isMine && deliveryStatusControl != null)
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              child: deliveryStatusControl,
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (senderDisplayName != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 4),
                  child: Text(
                    senderDisplayName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppPalette.neutral500,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
              bubble,
              if (blockedStatusLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  blockedStatusLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppPalette.neutral500,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ],
          ),
          if (isMine) ...[
            const SizedBox(width: 6),
            MessageAvatar(
              userId: avatarId,
              avatarBase64: avatarBase64,
              avatarBg: avatarBg,
            ),
          ],
        ],
      ),
    );
  }
}

class TypingStyleMessageText extends StatefulWidget {
  const TypingStyleMessageText({
    super.key,
    required this.messageId,
    required this.body,
    required this.createdAt,
    required this.enabled,
    required this.typingFrameMs,
    required this.maxLines,
    required this.textAlign,
    required this.style,
  });

  final String messageId;
  final String body;
  final DateTime createdAt;
  final bool enabled;
  final int typingFrameMs;
  final int maxLines;
  final TextAlign textAlign;
  final TextStyle style;

  @override
  State<TypingStyleMessageText> createState() => _TypingStyleMessageTextState();
}

class _TypingStyleMessageTextState extends State<TypingStyleMessageText> {
  static const _typingWindow = Duration(seconds: 20);

  Timer? _timer;
  List<String> _chars = const <String>[];
  int _index = 0;
  String _display = '';
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(covariant TypingStyleMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId ||
        oldWidget.body != widget.body ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.typingFrameMs != widget.typingFrameMs) {
      _configure();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _configure() {
    _timer?.cancel();
    final shouldAnimate =
        widget.enabled &&
        DateTime.now().toUtc().difference(widget.createdAt.toUtc()) <=
            _typingWindow &&
        widget.body.trim().isNotEmpty;
    if (!shouldAnimate) {
      setState(() {
        _chars = const <String>[];
        _index = 0;
        _display = widget.body;
        _animating = false;
      });
      return;
    }

    _chars = widget.body.characters.toList(growable: false);
    _index = 0;
    setState(() {
      _display = '';
      _animating = true;
    });
    _timer = Timer.periodic(Duration(milliseconds: widget.typingFrameMs), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_index >= _chars.length) {
        timer.cancel();
        setState(() {
          _animating = false;
          _display = widget.body;
        });
        return;
      }
      _index += 1;
      setState(() {
        _display = _chars.take(_index).join();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = _animating ? '$_display▌' : _display;
    return Text(
      text,
      maxLines: widget.maxLines,
      overflow: TextOverflow.fade,
      softWrap: true,
      textAlign: widget.textAlign,
      style: widget.style,
    );
  }
}

class MessageDetailScreen extends StatelessWidget {
  const MessageDetailScreen({
    super.key,
    required this.message,
    required this.isMine,
  });

  final LocalChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    final local = message.createdAt.toLocal();
    final dateStr =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          isMine
              ? AppLocalizations.of(context)!.chatMessageDetailTitleMine
              : AppLocalizations.of(context)!.chatMessageDetailTitleOther,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: inkColor,
          ),
        ),
        iconTheme: const IconThemeData(color: AppPalette.neutral500),
        actions: [
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.body));
              showAppToast(
                context,
                AppLocalizations.of(context)!.chatCopiedToClipboard,
                duration: const Duration(milliseconds: 900),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                AppLocalizations.of(context)!.actionCopy,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppPalette.neutral500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.body,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w300,
                color: inkColor,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 28),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 16),
            Text(
              dateStr,
              style: const TextStyle(
                fontSize: 11,
                color: AppPalette.neutral500,
                letterSpacing: 0.2,
              ),
            ),
            if (!isMine) ...[
              const SizedBox(height: 6),
              Text(
                message.senderId,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppPalette.neutral500,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MessageAvatar extends StatefulWidget {
  const MessageAvatar({
    super.key,
    required this.userId,
    required this.avatarBase64,
    required this.avatarBg,
  });

  final String userId;
  final String? avatarBase64;
  final Color avatarBg;

  @override
  State<MessageAvatar> createState() => _MessageAvatarState();
}

class _MessageAvatarState extends State<MessageAvatar> {
  String? _cachedBase64;
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _tryUpdateCache(widget.avatarBase64);
  }

  @override
  void didUpdateWidget(MessageAvatar old) {
    super.didUpdateWidget(old);
    _tryUpdateCache(widget.avatarBase64);
  }

  void _tryUpdateCache(String? base64) {
    if (base64 != null && base64 != _cachedBase64) {
      _cachedBase64 = base64;
      _cachedBytes = base64Decode(base64);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _cachedBytes;
    final initials = widget.userId.length >= 2
        ? widget.userId.substring(0, 2).toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 12,
      backgroundColor: bytes != null ? Colors.transparent : widget.avatarBg,
      child: bytes == null
          ? Text(
              initials,
              style: const TextStyle(
                color: AppPalette.white,
                fontSize: 8,
                fontWeight: FontWeight.w300,
              ),
            )
          : ClipOval(
              child: SizedBox.expand(
                child: Image.memory(bytes, fit: BoxFit.cover),
              ),
            ),
    );
  }
}
