import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';
import '../../ui/tokens/colors/app_palette.dart';
import '../../ui/components/atoms/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';

import '../../models/local_chat_message.dart';
import '../../models/sticker.dart';
import '../../models/friend_qr_payload.dart';
import 'friend_qr_scanner_page.dart';
import 'chat_target_profile_page.dart';
import '../../services/local_chat_repository.dart';
import '../../services/chat_ui_preferences.dart';
import '../../state/app_controller.dart';
import '../../state/backup_controller.dart';
import '../../state/conversation_messages_controller.dart';
import '../../state/realtime_sync_controller.dart';
import '../../state/sticker_controller.dart';
import '../../state/typing_style_mode_controller.dart';
import '../../state/unread_counts_controller.dart';
import '../../state/user_profile_controller.dart';

class ChatsTab extends ConsumerStatefulWidget {
  const ChatsTab({
    super.key,
    required this.serverUrl,
    required this.accessToken,
    required this.currentUserId,
    required this.initialPartnerId,
    required this.onPartnerChanged,
  });

  final String serverUrl;
  final String accessToken;
  final String currentUserId;
  final String? initialPartnerId;
  final ValueChanged<String?> onPartnerChanged;

  @override
  ConsumerState<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends ConsumerState<ChatsTab> {
  final _imagePicker = ImagePicker();
  final _partnerController = TextEditingController();
  final _partnerFocusNode = FocusNode();
  final _messageController = TextEditingController();
  final _messageScrollController = ScrollController();
  String? _activePartnerId;
  bool _typingSignalSent = false;
  Timer? _typingIdleTimer;
  Uint8List? _selectedMediaBytes;
  String? _selectedMediaName;
  final Set<String> _profileSyncInFlight = <String>{};
  final Set<String> _profileSyncedOnce = <String>{};
  final Map<String, String> _partnerServerUrlOverrides = <String, String>{};
  final Map<String, List<_OutgoingMessageDraft>> _outgoingDraftsByPartner =
      <String, List<_OutgoingMessageDraft>>{};
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _partnerController.addListener(_onSearchChanged);
    if (widget.initialPartnerId != null &&
        widget.initialPartnerId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPartner(widget.initialPartnerId!);
      });
    }
  }

  void _onSearchChanged() {
    if (!mounted || _activePartnerId != null) {
      return;
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant ChatsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPartnerId = widget.initialPartnerId;
    if (nextPartnerId != null &&
        nextPartnerId.isNotEmpty &&
        nextPartnerId != oldWidget.initialPartnerId &&
        nextPartnerId != _activePartnerId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPartner(nextPartnerId);
      });
    }
  }

  @override
  void dispose() {
    if (_typingSignalSent) {
      _sendTypingSignal(false);
      _typingSignalSent = false;
    }
    _typingIdleTimer?.cancel();
    _partnerController.removeListener(_onSearchChanged);
    _partnerController.dispose();
    _partnerFocusNode.dispose();
    _messageController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  void _sendTypingSignal(bool isTyping) {
    final partnerId = _activePartnerId;
    if (partnerId == null || partnerId.isEmpty) {
      return;
    }
    ref
        .read(realtimeSyncControllerProvider.notifier)
        .sendTyping(partnerId: partnerId, isTyping: isTyping);
  }

  void _onComposerChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    _typingIdleTimer?.cancel();

    if (hasText) {
      if (!_typingSignalSent) {
        _sendTypingSignal(true);
        _typingSignalSent = true;
      }
      _typingIdleTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!_typingSignalSent) {
          return;
        }
        _sendTypingSignal(false);
        _typingSignalSent = false;
      });
      return;
    }

    if (_typingSignalSent) {
      _sendTypingSignal(false);
      _typingSignalSent = false;
    }
  }

  Future<void> _pickMedia() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 75,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _selectedMediaBytes = bytes;
      _selectedMediaName = image.name;
    });
  }

  void _clearMedia() => setState(() {
    _selectedMediaBytes = null;
    _selectedMediaName = null;
  });

  Future<String> _effectiveAccessToken() async {
    final fresh = await ref
        .read(appControllerProvider.notifier)
        .ensureFreshAccessToken();
    return (fresh == null || fresh.isEmpty) ? widget.accessToken : fresh;
  }

  Future<void> _syncUserProfile(String userId, {bool force = false}) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) return;
    if (!force && _profileSyncedOnce.contains(normalized)) return;
    if (_profileSyncInFlight.contains(normalized)) return;

    _profileSyncInFlight.add(normalized);
    try {
      final accessToken = await _effectiveAccessToken();
      final remote = ref.read(remoteUserProfileServiceProvider);
      final profile = await remote.getUserProfile(
        baseUrl: widget.serverUrl,
        accessToken: accessToken,
        userId: normalized,
      );
      final prefs = ref.read(userProfilePreferencesProvider);
      await prefs.writeDisplayName(normalized, profile.username);
      await prefs.writeAvatarBase64(normalized, profile.avatarBase64);
      ref.invalidate(userDisplayNameProvider(normalized));
      ref.invalidate(userAvatarBase64Provider(normalized));
      _profileSyncedOnce.add(normalized);
    } catch (_) {
      // keep retry possible on later attempts
    } finally {
      _profileSyncInFlight.remove(normalized);
    }
  }

  void _prefetchVisibleProfiles(Iterable<String> userIds) {
    for (final userId in userIds) {
      final trimmed = userId.trim();
      if (trimmed.isEmpty || trimmed == widget.currentUserId) {
        continue;
      }
      if (_profileSyncedOnce.contains(trimmed)) continue;
      unawaited(_syncUserProfile(trimmed));
    }
  }

  void _closeActiveConversation() {
    if (_typingSignalSent) {
      _sendTypingSignal(false);
      _typingSignalSent = false;
    }
    setState(() => _activePartnerId = null);
    widget.onPartnerChanged(null);
  }

  Future<void> _openPartner(String partnerId) async {
    if (_typingSignalSent) {
      _sendTypingSignal(false);
      _typingSignalSent = false;
    }
    setState(() => _activePartnerId = partnerId);
    widget.onPartnerChanged(partnerId);
    await _syncUserProfile(partnerId, force: true);
    final accessToken = await _effectiveAccessToken();
    await ref
        .read(conversationMessagesProvider(partnerId).notifier)
        .syncLatest(
          baseUrl: widget.serverUrl,
          accessToken: accessToken,
          currentUserId: widget.currentUserId,
        );
    await ref
        .read(conversationMessagesProvider(partnerId).notifier)
        .markRead(baseUrl: widget.serverUrl, accessToken: accessToken);
    ref.read(unreadCountsProvider.notifier).clearForPartner(partnerId);
    ref.invalidate(conversationSummariesProvider);
  }

  Future<_ChatTargetInput?> _promptForChatTarget() async {
    final targetController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    final result = await showDialog<_ChatTargetInput>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final hasValue = targetController.text.trim().isNotEmpty;
            return Dialog(
              backgroundColor: bgColor,
              surfaceTintColor: AppPalette.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 44,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _l10n.chatAddFriendHeader,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.6,
                        color: AppPalette.neutral500,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _l10n.chatAddFriendTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: inkColor,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _l10n.chatAddFriendFormatHint,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        color: AppPalette.neutral500,
                        letterSpacing: 0.15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: targetController,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        color: inkColor,
                      ),
                      decoration: InputDecoration(
                        hintText: _l10n.chatAddFriendInputHint,
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppPalette.neutral500.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w300,
                        ),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: ruleColor),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: ruleColor),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppPalette.neutral500),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Text(
                              _l10n.actionCancel,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppPalette.neutral500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: hasValue
                              ? () => Navigator.of(context).pop(
                                  _parseChatTargetInput(
                                    targetController.text.trim(),
                                    defaultServerUrl: widget.serverUrl,
                                  ),
                                )
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Text(
                              _l10n.actionNext,
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 2.4,
                                fontWeight: FontWeight.w500,
                                color: hasValue
                                    ? inkColor
                                    : AppPalette.neutral500.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    // Dispose on the next frame to avoid a race with dialog-route transition
    // rebuilds that can still touch the controller right after pop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      targetController.dispose();
    });
    return result;
  }

  _ChatTargetInput _parseChatTargetInput(
    String raw, {
    required String defaultServerUrl,
  }) {
    final value = raw.trim();
    final parsed = Uri.tryParse(value);

    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      String id = '';
      for (final segment in parsed.pathSegments) {
        final normalized = segment.trim();
        if (normalized.isNotEmpty) {
          id = normalized;
          break;
        }
      }
      final host = parsed.host.trim();
      final origin = host.isEmpty
          ? ''
          : '${parsed.scheme}://$host${parsed.hasPort ? ':${parsed.port}' : ''}';
      return _ChatTargetInput(
        friendId: id,
        serverUrl: origin.isEmpty ? defaultServerUrl : origin,
      );
    }

    return _ChatTargetInput(friendId: value, serverUrl: defaultServerUrl);
  }

  Future<_ResolvedTargetProfile?> _resolveTarget(
    _ChatTargetInput target,
  ) async {
    final friendId = target.friendId.trim();
    final serverUrl = target.serverUrl.trim();

    if (friendId.isEmpty || serverUrl.isEmpty) {
      if (!mounted) return null;
      showAppToast(context, _l10n.chatAddFriendInputHint);
      return null;
    }

    final accessToken = await _effectiveAccessToken();
    final remote = ref.read(remoteChatServiceProvider);
    final resolved = await remote.resolveContact(
      baseUrl: widget.serverUrl,
      accessToken: accessToken,
      recipientId: friendId,
      recipientServerUrl: serverUrl,
    );

    String displayName = resolved.displayHandle;
    String? avatarBase64;
    String? description;
    try {
      final profile = await ref
          .read(remoteUserProfileServiceProvider)
          .getUserProfile(
            baseUrl: widget.serverUrl,
            accessToken: accessToken,
            userId: resolved.partnerId,
          );
      if (profile.username.trim().isNotEmpty) {
        displayName = profile.username.trim();
      }
      avatarBase64 = profile.avatarBase64;
    } catch (_) {
      // fallback to resolved handle only
    }
    description = await ref
        .read(userProfilePreferencesProvider)
        .readDescription(resolved.partnerId);

    return _ResolvedTargetProfile(
      partnerId: resolved.partnerId,
      recipientServerUrl: resolved.recipientServerUrl,
      displayName: displayName,
      displayHandle: resolved.displayHandle,
      avatarBase64: avatarBase64,
      description: description,
    );
  }

  Future<void> _openFromTarget(_ChatTargetInput target) async {
    try {
      final resolved = await _resolveTarget(target);
      if (!mounted || resolved == null) {
        return;
      }
      final sentMessageCount = await _sentMessageCountForPartner(
        resolved.partnerId,
      );
      final prefs = ref.read(userProfilePreferencesProvider);
      final isFriend = (await prefs.readFriendIds()).contains(
        resolved.partnerId,
      );
      final friendAddedAt = isFriend
          ? await prefs.readFriendAddedAt(resolved.partnerId)
          : null;
      if (!mounted) {
        return;
      }

      final action = await Navigator.of(context).push<ChatTargetProfileAction>(
        MaterialPageRoute<ChatTargetProfileAction>(
          builder: (_) => ChatTargetProfileScreen(
            displayName: resolved.displayName,
            displayHandle: resolved.displayHandle,
            avatarBase64: resolved.avatarBase64,
            isFriend: isFriend,
            friendAddedAt: friendAddedAt,
            sentMessageCount: sentMessageCount,
            description: resolved.description,
          ),
        ),
      );
      if (!mounted || action == null) {
        return;
      }

      if (action == ChatTargetProfileAction.cancelFriend) {
        await prefs.removeFriendId(resolved.partnerId);
        ref.invalidate(friendIdsProvider);
        if (!mounted) {
          return;
        }
        showAppToast(context, _l10n.friendRemoved);
        return;
      }
      if (action == ChatTargetProfileAction.addFriend && mounted) {
        await prefs.addFriendId(resolved.partnerId);
        ref.invalidate(friendIdsProvider);
        if (!mounted) {
          return;
        }
        showAppToast(context, _l10n.friendAdded, duration: const Duration(milliseconds: 900));
      }
      if (action == ChatTargetProfileAction.startChat ||
          action == ChatTargetProfileAction.addFriend) {
        _partnerServerUrlOverrides[resolved.partnerId] =
            resolved.recipientServerUrl;
        await _openPartner(resolved.partnerId);
      }
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, error.toString(), variant: AppToastVariant.error);
    }
  }

  Future<void> _openNewFriendOrChat() async {
    final target = await _promptForChatTarget();
    if (!mounted || target == null || target.friendId.isEmpty) {
      return;
    }
    await _openFromTarget(target);
  }

  Future<void> _scanQrAndOpen() async {
    final payload = await Navigator.of(context).push<FriendQrPayload>(
      MaterialPageRoute<FriendQrPayload>(
        builder: (_) => const FriendQrScannerScreen(),
      ),
    );
    if (!mounted || payload == null) {
      return;
    }

    await _openFromTarget(
      _ChatTargetInput(friendId: payload.userId, serverUrl: payload.serverUrl),
    );
  }

  Future<void> _sendMessage() async {
    if (_activePartnerId == null) return;
    final text = _messageController.text.trim();
    final mediaBytes = _selectedMediaBytes;
    final mediaToken = mediaBytes == null
        ? ''
        : '[media-data:${base64Encode(mediaBytes)}]';
    final content = [text, mediaToken].where((p) => p.isNotEmpty).join('\n');
    if (content.isEmpty) return;

    _messageController.clear();
    _typingIdleTimer?.cancel();
    if (_typingSignalSent) {
      _sendTypingSignal(false);
      _typingSignalSent = false;
    }

    _clearMedia();
    await _sendMessageWithOptimisticBubble(content);
  }

  Future<void> _sendMessageWithOptimisticBubble(String content) async {
    final partnerId = _activePartnerId;
    if (partnerId == null || partnerId.isEmpty) {
      return;
    }
    final draftId = _addOutgoingDraft(partnerId: partnerId, body: content);

    try {
      final accessToken = await _effectiveAccessToken();
      await ref
          .read(conversationMessagesProvider(partnerId).notifier)
          .sendMessage(
            baseUrl: widget.serverUrl,
            accessToken: accessToken,
            currentUserId: widget.currentUserId,
            body: content,
            recipientServerUrl: _partnerServerUrlOverrides[partnerId],
          );
      _removeOutgoingDraft(partnerId: partnerId, draftId: draftId);
      await ref
          .read(unreadCountsProvider.notifier)
          .refresh(baseUrl: widget.serverUrl, accessToken: accessToken);
      await ref
          .read(backupControllerProvider.notifier)
          .maybeAutoBackup(baseUrl: widget.serverUrl, accessToken: accessToken);
    } catch (error) {
      _markOutgoingDraftFailed(partnerId: partnerId, draftId: draftId);
      if (!mounted) {
        return;
      }
      showAppToast(context, error.toString(), variant: AppToastVariant.error);
    }
  }

  String _addOutgoingDraft({required String partnerId, required String body}) {
    final id =
        'draft-${DateTime.now().microsecondsSinceEpoch}-${body.length.hashCode.abs()}';
    final next = _OutgoingMessageDraft(
      id: id,
      partnerId: partnerId,
      body: body,
      createdAt: DateTime.now().toUtc(),
      state: _OutgoingDeliveryState.sending,
    );
    setState(() {
      final current = _outgoingDraftsByPartner[partnerId] ?? const [];
      _outgoingDraftsByPartner[partnerId] = [next, ...current];
    });
    return id;
  }

  void _removeOutgoingDraft({
    required String partnerId,
    required String draftId,
  }) {
    if (!_outgoingDraftsByPartner.containsKey(partnerId)) {
      return;
    }
    setState(() {
      final next = (_outgoingDraftsByPartner[partnerId] ?? const [])
          .where((draft) => draft.id != draftId)
          .toList(growable: false);
      if (next.isEmpty) {
        _outgoingDraftsByPartner.remove(partnerId);
      } else {
        _outgoingDraftsByPartner[partnerId] = next;
      }
    });
  }

  void _markOutgoingDraftFailed({
    required String partnerId,
    required String draftId,
  }) {
    if (!_outgoingDraftsByPartner.containsKey(partnerId)) {
      return;
    }
    setState(() {
      final next = (_outgoingDraftsByPartner[partnerId] ?? const [])
          .map(
            (draft) => draft.id == draftId
                ? draft.copyWith(state: _OutgoingDeliveryState.failed)
                : draft,
          )
          .toList(growable: false);
      _outgoingDraftsByPartner[partnerId] = next;
    });
  }

  Future<void> _retryOutgoingDraft(_OutgoingMessageDraft draft) async {
    if (draft.state != _OutgoingDeliveryState.failed) {
      return;
    }
    setState(() {
      final current = _outgoingDraftsByPartner[draft.partnerId] ?? const [];
      _outgoingDraftsByPartner[draft.partnerId] = current
          .map(
            (item) => item.id == draft.id
                ? item.copyWith(state: _OutgoingDeliveryState.sending)
                : item,
          )
          .toList(growable: false);
    });

    try {
      final accessToken = await _effectiveAccessToken();
      await ref
          .read(conversationMessagesProvider(draft.partnerId).notifier)
          .sendMessage(
            baseUrl: widget.serverUrl,
            accessToken: accessToken,
            currentUserId: widget.currentUserId,
            body: draft.body,
            recipientServerUrl: _partnerServerUrlOverrides[draft.partnerId],
          );
      _removeOutgoingDraft(partnerId: draft.partnerId, draftId: draft.id);
      await ref
          .read(unreadCountsProvider.notifier)
          .refresh(baseUrl: widget.serverUrl, accessToken: accessToken);
      await ref
          .read(backupControllerProvider.notifier)
          .maybeAutoBackup(baseUrl: widget.serverUrl, accessToken: accessToken);
    } catch (_) {
      _markOutgoingDraftFailed(partnerId: draft.partnerId, draftId: draft.id);
    }
  }

  Future<void> _openActivePartnerProfile() async {
    final partnerId = _activePartnerId;
    if (partnerId == null || partnerId.isEmpty) {
      return;
    }
    await _syncUserProfile(partnerId);
    if (!mounted) {
      return;
    }
    final displayName = _displayNameOrFallback(
      partnerId,
      ref.read(userDisplayNameProvider(partnerId)).value,
    );
    final avatarBase64 = ref.read(userAvatarBase64Provider(partnerId)).value;
    final description = ref.read(userDescriptionProvider(partnerId)).value;
    final sentMessageCount = await _sentMessageCountForPartner(partnerId);
    final prefs = ref.read(userProfilePreferencesProvider);
    final isFriend = (await prefs.readFriendIds()).contains(partnerId);
    final friendAddedAt = isFriend
        ? await prefs.readFriendAddedAt(partnerId)
        : null;
    if (!mounted) {
      return;
    }
    final action = await Navigator.of(context).push<ChatTargetProfileAction>(
      MaterialPageRoute<ChatTargetProfileAction>(
        builder: (_) => ChatTargetProfileScreen(
          displayName: displayName,
          displayHandle: partnerId,
          avatarBase64: avatarBase64,
          isFriend: isFriend,
          friendAddedAt: friendAddedAt,
          sentMessageCount: sentMessageCount,
          description: description,
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == ChatTargetProfileAction.addFriend) {
      await ref.read(userProfilePreferencesProvider).addFriendId(partnerId);
      ref.invalidate(friendIdsProvider);
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        _l10n.friendAdded,
        duration: const Duration(milliseconds: 900),
      );
      return;
    }
    if (action == ChatTargetProfileAction.cancelFriend) {
      await ref.read(userProfilePreferencesProvider).removeFriendId(partnerId);
      ref.invalidate(friendIdsProvider);
      if (!mounted) {
        return;
      }
      showAppToast(context, _l10n.friendRemoved);
      return;
    }
    if (action == ChatTargetProfileAction.startChat) {
      await _openPartner(partnerId);
    }
  }

  Future<int> _sentMessageCountForPartner(String partnerId) async {
    final messages = await ref
        .read(chatRepositoryProvider)
        .listMessages(conversationId: partnerId, limit: 5000);
    return messages
        .where((message) => message.senderId == widget.currentUserId)
        .length;
  }

  Future<void> _markAllUnreadAsRead(Map<String, int> unreadCounts) async {
    final partnerIds = unreadCounts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (partnerIds.isEmpty) {
      return;
    }

    final accessToken = await _effectiveAccessToken();
    final failed = <String>[];
    for (final partnerId in partnerIds) {
      try {
        await ref
            .read(conversationMessagesProvider(partnerId).notifier)
            .markRead(baseUrl: widget.serverUrl, accessToken: accessToken);
        ref.read(unreadCountsProvider.notifier).clearForPartner(partnerId);
      } catch (_) {
        failed.add(partnerId);
      }
    }

    await ref
        .read(unreadCountsProvider.notifier)
        .refresh(baseUrl: widget.serverUrl, accessToken: accessToken);
    ref.invalidate(conversationSummariesProvider);

    if (!mounted) {
      return;
    }
    if (failed.isEmpty) {
      showAppToast(
        context,
        _l10n.chatMarkedAllAsRead,
        duration: const Duration(milliseconds: 900),
      );
      return;
    }
    showAppToast(
      context,
      _l10n.chatMarkReadPartial(
        partnerIds.length - failed.length,
        partnerIds.length,
      ),
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;

    final cs = Theme.of(context).colorScheme;
    final stickers =
        ref.watch(stickerControllerProvider).value ?? const <Sticker>[];
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ?? const <String, int>{};
    final currentUserAvatarBase64 = ref
        .watch(userAvatarBase64Provider(widget.currentUserId))
        .value;
    final partnerAvatarBase64 = _activePartnerId == null
        ? null
        : ref.watch(userAvatarBase64Provider(_activePartnerId!)).value;
    final conversationSummaries =
        ref.watch(conversationSummariesProvider).value ??
        const <ConversationSummary>[];
    final searchQuery = _partnerController.text.trim().toLowerCase();
    final filteredSummaries = searchQuery.isEmpty
        ? conversationSummaries
        : conversationSummaries
              .where((summary) {
                return summary.conversationId.toLowerCase().contains(
                      searchQuery,
                    ) ||
                    summary.lastBody.toLowerCase().contains(searchQuery);
              })
              .toList(growable: false);
    final summariesById = <String, ConversationSummary>{
      for (final summary in filteredSummaries) summary.conversationId: summary,
    };
    final orderedConversationIds =
        <String>{
          ...unreadCounts.keys,
          ...filteredSummaries.map((summary) => summary.conversationId),
        }.toList(growable: false)..sort((a, b) {
          final aHasUnread = (unreadCounts[a] ?? 0) > 0;
          final bHasUnread = (unreadCounts[b] ?? 0) > 0;
          if (aHasUnread != bHasUnread) {
            return aHasUnread ? -1 : 1;
          }

          final aLastAt = summariesById[a]?.lastAt;
          final bLastAt = summariesById[b]?.lastAt;
          if (aLastAt != null && bLastAt != null) {
            return bLastAt.compareTo(aLastAt);
          }
          if (aLastAt != null) {
            return -1;
          }
          if (bLastAt != null) {
            return 1;
          }
          return a.compareTo(b);
        });
    final rowUserIds = orderedConversationIds.toSet();
    _prefetchVisibleProfiles(rowUserIds);
    final activeUnread = _activePartnerId == null
        ? 0
        : (unreadCounts[_activePartnerId!] ?? 0);
    final inConversation = _activePartnerId != null;
    final activeDisplayName = _activePartnerId == null
        ? null
        : _displayNameOrFallback(
            _activePartnerId!,
            ref.watch(userDisplayNameProvider(_activePartnerId!)).value,
          );
    final realtimeState = ref.watch(realtimeSyncControllerProvider).value;
    final typingStyleModeEnabled =
        ref.watch(typingStyleModeControllerProvider).value ?? false;
    final typingStyleSpeedMs =
        ref.watch(typingStyleSpeedControllerProvider).value ??
        ChatUiPreferences.defaultTypingStyleSpeedMs;
    final isTargetTyping =
        _activePartnerId != null &&
        (realtimeState?.typingPartnerIds.contains(_activePartnerId!) ?? false);
    final messagesAsync = _activePartnerId == null
        ? null
        : ref.watch(conversationMessagesProvider(_activePartnerId!));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: inConversation
          ? AppBar(
              backgroundColor: AppPalette.transparent,
              surfaceTintColor: AppPalette.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              forceMaterialTransparency: true,
              centerTitle: true,
              title: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _openActivePartnerProfile,
                child: Text(
                  activeDisplayName ?? _l10n.chatDefaultTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _closeActiveConversation,
              ),
              automaticallyImplyLeading: false,
              actions: [
                if (activeUnread > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _UnreadBadge(count: activeUnread),
                  ),
              ],
            )
          : null,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: _activePartnerId == null
            ? SafeArea(
                child: _ConversationStarter(
                  controller: _partnerController,
                  focusNode: _partnerFocusNode,
                  unreadCounts: unreadCounts,
                  orderedConversationIds: orderedConversationIds,
                  summariesById: summariesById,
                  onQuickAction: (action) {
                    switch (action) {
                      case _ChatQuickAction.newFriendOrChat:
                        _openNewFriendOrChat();
                      case _ChatQuickAction.scanFriendQr:
                        _scanQrAndOpen();
                    }
                  },
                  onOpenConversation: (id) async {
                    await _openPartner(id);
                  },
                  onMarkAllRead: () => _markAllUnreadAsRead(unreadCounts),
                  onStartNewChat: _openNewFriendOrChat,
                  onAddFriend: _openNewFriendOrChat,
                ),
              )
            : GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity > 450) {
                    _closeActiveConversation();
                  }
                },
                child: Column(
                  children: [
                    // Messages list
                    Expanded(
                      child: messagesAsync == null
                          ? const Center(child: CircularProgressIndicator())
                          : messagesAsync.when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (err, _) => Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    '$err',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              data: (messages) {
                                final activePartnerId = _activePartnerId;
                                final draftMessages = activePartnerId == null
                                    ? const <_OutgoingMessageDraft>[]
                                    : (_outgoingDraftsByPartner[activePartnerId] ??
                                          const <_OutgoingMessageDraft>[]);
                                final draftById =
                                    <String, _OutgoingMessageDraft>{
                                      for (final draft in draftMessages)
                                        draft.id: draft,
                                    };
                                final displayedMessages = <LocalChatMessage>[
                                  ...draftMessages.map(
                                    (draft) => LocalChatMessage(
                                      id: draft.id,
                                      conversationId: draft.partnerId,
                                      senderId: widget.currentUserId,
                                      body: draft.body,
                                      createdAt: draft.createdAt,
                                    ),
                                  ),
                                  ...messages,
                                ];

                                return displayedMessages.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.chat_bubble_outline,
                                              size: 48,
                                              color: cs.outlineVariant,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              _l10n.chatNoMessagesYet,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        reverse: true,
                                        controller: _messageScrollController,
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          8,
                                          12,
                                          8,
                                        ),
                                        itemCount: displayedMessages.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(height: 6),
                                        itemBuilder: (ctx, i) {
                                          final message = displayedMessages[i];
                                          final draft = draftById[message.id];
                                          final showDayDivider =
                                              i ==
                                                  displayedMessages.length -
                                                      1 ||
                                              !_isSameDay(
                                                message.createdAt,
                                                displayedMessages[i + 1]
                                                    .createdAt,
                                              );
                                          return Column(
                                            children: [
                                              if (showDayDivider)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        0,
                                                        8,
                                                        0,
                                                        6,
                                                      ),
                                                  child: _DayDivider(
                                                    label: _dayLabel(
                                                      context,
                                                      message.createdAt,
                                                    ),
                                                  ),
                                                ),
                                              _MessageBubble(
                                                key: ValueKey(message.id),
                                                message: message,
                                                isMine:
                                                    message.senderId ==
                                                    widget.currentUserId,
                                                currentUserId:
                                                    widget.currentUserId,
                                                currentUserAvatarBase64:
                                                    currentUserAvatarBase64,
                                                partnerAvatarBase64:
                                                    partnerAvatarBase64,
                                                onPartnerAvatarTap:
                                                    _openActivePartnerProfile,
                                                stickers: stickers,
                                                serverUrl: widget.serverUrl,
                                                accessToken: widget.accessToken,
                                                deliveryState: draft?.state,
                                                onRetryTap: draft == null
                                                    ? null
                                                    : () => _retryOutgoingDraft(
                                                        draft,
                                                      ),
                                                typingStyleModeEnabled:
                                                    typingStyleModeEnabled,
                                                typingStyleSpeedMs:
                                                    typingStyleSpeedMs,
                                                animateAsDraft: draft != null,
                                              ),
                                            ],
                                          );
                                        },
                                      );
                              },
                            ),
                    ),

                    // Typing indicator
                    if (isTargetTyping)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _l10n.chatTypingIndicator(
                              activeDisplayName ?? _l10n.chatDefaultPartner,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),

                    // Composer
                    SafeArea(
                      top: false,
                      child: _Composer(
                        messageController: _messageController,
                        selectedMediaBytes: _selectedMediaBytes,
                        selectedMediaName: _selectedMediaName,
                        stickers: stickers,
                        onChanged: _onComposerChanged,
                        onSend: _sendMessage,
                        onPickMedia: _pickMedia,
                        onClearMedia: _clearMedia,
                        onStickerSelected: (sticker) async {
                          if (_activePartnerId == null) return;
                          await _sendMessageWithOptimisticBubble(
                            '[sticker:${sticker.id}:${sticker.name}]',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

enum _ChatQuickAction { newFriendOrChat, scanFriendQr }

enum _OutgoingDeliveryState { sending, failed }

class _OutgoingMessageDraft {
  const _OutgoingMessageDraft({
    required this.id,
    required this.partnerId,
    required this.body,
    required this.createdAt,
    required this.state,
  });

  final String id;
  final String partnerId;
  final String body;
  final DateTime createdAt;
  final _OutgoingDeliveryState state;

  _OutgoingMessageDraft copyWith({_OutgoingDeliveryState? state}) {
    return _OutgoingMessageDraft(
      id: id,
      partnerId: partnerId,
      body: body,
      createdAt: createdAt,
      state: state ?? this.state,
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

String _dayLabel(BuildContext context, DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return AppLocalizations.of(context)!.chatToday;
  }
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppPalette.neutral500.withValues(alpha: 0.22),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppPalette.neutral300,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppPalette.neutral500.withValues(alpha: 0.22),
          ),
        ),
      ],
    );
  }
}

class _ChatTargetInput {
  const _ChatTargetInput({required this.friendId, required this.serverUrl});

  final String friendId;
  final String serverUrl;
}

class _ResolvedTargetProfile {
  const _ResolvedTargetProfile({
    required this.partnerId,
    required this.recipientServerUrl,
    required this.displayName,
    required this.displayHandle,
    required this.avatarBase64,
    required this.description,
  });

  final String partnerId;
  final String recipientServerUrl;
  final String displayName;
  final String displayHandle;
  final String? avatarBase64;
  final String? description;
}

// —————————————————————————————————————————————————————
// Conversation starter (empty state)
// —————————————————————————————————————————————————————

class _ConversationStarter extends ConsumerWidget {
  const _ConversationStarter({
    required this.controller,
    required this.focusNode,
    required this.unreadCounts,
    required this.orderedConversationIds,
    required this.summariesById,
    required this.onQuickAction,
    required this.onOpenConversation,
    required this.onMarkAllRead,
    required this.onStartNewChat,
    required this.onAddFriend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Map<String, int> unreadCounts;
  final List<String> orderedConversationIds;
  final Map<String, ConversationSummary> summariesById;
  final ValueChanged<_ChatQuickAction> onQuickAction;
  final ValueChanged<String> onOpenConversation;
  final Future<void> Function() onMarkAllRead;
  final VoidCallback onStartNewChat;
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    final unreadConversationIds = orderedConversationIds
        .where((id) => (unreadCounts[id] ?? 0) > 0)
        .toList(growable: false);
    final chatConversationIds = orderedConversationIds
        .where((id) => (unreadCounts[id] ?? 0) == 0)
        .toList(growable: false);
    final hasAnyRows =
        unreadConversationIds.isNotEmpty || chatConversationIds.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      children: [
        // ── search + quick action ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autocorrect: false,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: inkColor,
                ),
                decoration: InputDecoration(
                  hintText: l10n.chatSearchHint,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: AppPalette.neutral500.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w300,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: ruleColor),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: ruleColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppPalette.neutral500),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                final action = await showModalBottomSheet<_ChatQuickAction>(
                  context: context,
                  backgroundColor: bgColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  builder: (_) => _QuickActionSheet(
                    inkColor: inkColor,
                    mutedColor: AppPalette.neutral500,
                    ruleColor: ruleColor,
                  ),
                );
                if (action != null) onQuickAction(action);
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.add, color: inkColor, size: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── unread section ──
        if (unreadConversationIds.isNotEmpty) ...[
          Row(
            children: [
              Text(
                l10n.chatUnreadHeader,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.4,
                  color: AppPalette.neutral500,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onMarkAllRead,
                child: Text(
                  l10n.chatMarkAllRead,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppPalette.neutral500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 1, color: ruleColor),
          const SizedBox(height: 4),
          ...unreadConversationIds.map(
            (userId) => _buildConversationRow(
              context,
              ref,
              userId,
              summariesById,
              inkColor,
              AppPalette.neutral500,
            ),
          ),
        ],

        if (hasAnyRows && chatConversationIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.chatChatsHeader,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.4,
              color: AppPalette.neutral500,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 1, color: ruleColor),
          const SizedBox(height: 4),
        ],

        if (!hasAnyRows)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              l10n.chatNoChatsYet,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: AppPalette.neutral500,
              ),
            ),
          )
        else
          ...chatConversationIds.map(
            (userId) => _buildConversationRow(
              context,
              ref,
              userId,
              summariesById,
              inkColor,
              AppPalette.neutral500,
            ),
          ),
      ],
    );
  }

  Widget _buildConversationRow(
    BuildContext context,
    WidgetRef ref,
    String userId,
    Map<String, ConversationSummary> summariesById,
    Color inkColor,
    Color mutedColor,
  ) {
    final summary = summariesById[userId];
    final unreadCount = unreadCounts[userId] ?? 0;
    final displayNameAsync = ref.watch(userDisplayNameProvider(userId));
    final avatarBase64Async = ref.watch(userAvatarBase64Provider(userId));
    final displayName = _displayNameOrFallback(userId, displayNameAsync.value);

    // avatar warm palette
    const palette = [
      AppPalette.avatarTone1,
      AppPalette.avatarTone2,
      AppPalette.avatarTone3,
      AppPalette.avatarTone4,
      AppPalette.avatarTone5,
      AppPalette.avatarTone6,
    ];
    final hash = userId.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarColor = palette[hash.abs() % palette.length];

    return Column(
      children: [
        InkWell(
          onTap: () => onOpenConversation(userId),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarColor,
                  child: avatarBase64Async.value == null
                      ? Text(
                          userId.length >= 2
                              ? userId.substring(0, 2).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppPalette.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                          ),
                        )
                      : ClipOval(
                          child: SizedBox.expand(
                            child: Image.memory(
                              base64Decode(avatarBase64Async.value!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: inkColor,
                        ),
                      ),
                      if (summary != null)
                        Text(
                          summary.lastBody,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: mutedColor,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (summary != null)
                      Text(
                        _timeLabel(summary.lastAt),
                        style: TextStyle(fontSize: 11, color: mutedColor),
                      ),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppPalette.danger700,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$unreadCount',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppPalette.danger700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _displayNameOrFallback(String userId, String? displayName) {
  final normalized = (displayName ?? '').trim();
  if (normalized.isNotEmpty) {
    return normalized;
  }
  return userId.length >= 8 ? userId.substring(0, 8) : userId;
}

String _timeLabel(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// —————————————————————————————————————————————————————
// Composer toolbar
// —————————————————————————————————————————————————————

class _Composer extends StatelessWidget {
  const _Composer({
    required this.messageController,
    required this.selectedMediaBytes,
    required this.selectedMediaName,
    required this.stickers,
    required this.onChanged,
    required this.onSend,
    required this.onPickMedia,
    required this.onClearMedia,
    required this.onStickerSelected,
  });

  final TextEditingController messageController;
  final Uint8List? selectedMediaBytes;
  final String? selectedMediaName;
  final List<Sticker> stickers;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onPickMedia;
  final VoidCallback onClearMedia;
  final ValueChanged<Sticker> onStickerSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Media preview
          if (selectedMediaBytes != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: ruleColor)),
              child: Row(
                children: [
                  ClipRRect(
                    child: Image.memory(
                      selectedMediaBytes!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedMediaName ?? l10n.chatSelectedMediaFallback,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: AppPalette.neutral500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onClearMedia,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppPalette.neutral500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Divider(height: 1, thickness: 1, color: ruleColor),

          // Input row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach
                _ComposerIconButton(
                  icon: Icons.attach_file_outlined,
                  tooltip: l10n.chatAttachImageTooltip,
                  onPressed: onPickMedia,
                ),
                // Stickers
                _ComposerIconButton(
                  icon: Icons.tag_faces_outlined,
                  tooltip: l10n.chatStickersTooltip,
                  onPressed: () async {
                    final selected = await showModalBottomSheet<Sticker>(
                      context: context,
                      backgroundColor: bgColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      builder: (_) => _StickerPicker(stickers: stickers),
                    );
                    if (selected != null) {
                      onStickerSelected(selected);
                    }
                  },
                ),
                // Text field
                Expanded(
                  child: TextField(
                    controller: messageController,
                    onChanged: onChanged,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.chatMessageHint,
                      hintStyle: const TextStyle(
                        color: AppPalette.neutral500,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                      filled: false,
                      border: const UnderlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Send — plain text arrow
                GestureDetector(
                  onTap: onSend,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      size: 22,
                      color: AppPalette.neutral500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      onPressed: onPressed,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
    );
  }
}

// —————————————————————————————————————————————————————
// Sticker picker
// —————————————————————————————————————————————————————

class _StickerPicker extends StatefulWidget {
  const _StickerPicker({required this.stickers});
  final List<Sticker> stickers;

  @override
  State<_StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<_StickerPicker> {
  String? _selectedGroup;

  String _normalizeGroupName(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return "General";
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.stickers.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(
            l10n.chatNoStickersYet,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: AppPalette.neutral500,
            ),
          ),
        ),
      );
    }

    final grouped = <String, List<Sticker>>{};
    for (final sticker in widget.stickers) {
      final groupName = _normalizeGroupName(sticker.groupName);
      grouped.putIfAbsent(groupName, () => <Sticker>[]).add(sticker);
    }
    final groups = grouped.keys.toList(growable: false);
    final selectedGroup = groups.contains(_selectedGroup)
        ? _selectedGroup!
        : groups.first;
    final visibleStickers = (grouped[selectedGroup] ?? const <Sticker>[])
        .where((s) => s.name != '__tab__')
        .toList(growable: false);

    return SizedBox(
      height: 320,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.chatStickersHeader,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.8,
                  fontWeight: FontWeight.w400,
                  color: AppPalette.neutral500,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppPalette.neutral300),
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final groupName = groups[i];
                return ChoiceChip(
                  label: Text(groupName),
                  selected: groupName == selectedGroup,
                  onSelected: (_) {
                    setState(() {
                      _selectedGroup = groupName;
                    });
                  },
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: groups.length,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: visibleStickers.length,
              itemBuilder: (_, i) {
                final sticker = visibleStickers[i];
                Uint8List bytes;
                try {
                  bytes = base64Decode(sticker.contentBase64);
                } catch (_) {
                  return const SizedBox.shrink();
                }
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(sticker),
                  child: Image.memory(bytes, fit: BoxFit.cover),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// —————————————————————————————————————————————————————
// Message bubble
// —————————————————————————————————————————————————————

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.currentUserId,
    required this.currentUserAvatarBase64,
    required this.partnerAvatarBase64,
    required this.onPartnerAvatarTap,
    required this.stickers,
    required this.serverUrl,
    required this.accessToken,
    this.deliveryState,
    this.onRetryTap,
    this.typingStyleModeEnabled = false,
    this.typingStyleSpeedMs = ChatUiPreferences.defaultTypingStyleSpeedMs,
    this.animateAsDraft = false,
  });

  final LocalChatMessage message;
  final bool isMine;
  final String currentUserId;
  final String? currentUserAvatarBase64;
  final String? partnerAvatarBase64;
  final VoidCallback onPartnerAvatarTap;
  final List<Sticker> stickers;
  final String serverUrl;
  final String accessToken;
  final _OutgoingDeliveryState? deliveryState;
  final VoidCallback? onRetryTap;
  final bool typingStyleModeEnabled;
  final int typingStyleSpeedMs;
  final bool animateAsDraft;

  static const double _kMaxBubbleHeight = 180;

  static String? _parseStickerId(String body) {
    final match =
        RegExp(r'^\[sticker:([^:\]]+):[^\]]*\]$').firstMatch(body.trim());
    return match?.group(1);
  }

  /// Returns the decoded image bytes and remaining text from a body that
  /// contains a [media-data:base64] token. Returns null if none found.
  static ({Uint8List bytes, String text})? _parseMediaData(String body) {
    final match =
        RegExp(r'\[media-data:([A-Za-z0-9+/=]+)\]').firstMatch(body);
    if (match == null) return null;
    try {
      final bytes = base64Decode(match.group(1)!);
      final text = body.replaceFirst(match.group(0)!, '').trim();
      return (bytes: bytes, text: text);
    } catch (_) {
      return null;
    }
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MessageDetailScreen(message: message, isMine: isMine),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;

    // Warm bubble colours
    final myBubble = isDark
        ? AppPalette.chatBubbleSelfDark
        : AppPalette.chatBubbleSelfLight;
    final theirBubble = isDark
        ? AppPalette.chatBubblePeerDark
        : AppPalette.chatBubblePeerLight;

    final bubbleColor = isMine ? myBubble : theirBubble;
    final onBubble = inkColor;
    final statusColor = deliveryState == _OutgoingDeliveryState.failed
        ? AppPalette.danger700
        : AppPalette.neutral500;
    const textMaxLines = 7;
    final messageTextStyle = TextStyle(
      color: onBubble,
      fontSize: 14,
      fontWeight: FontWeight.w300,
      height: 1.5,
    );
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.68;
    final overflowProbe = TextPainter(
      text: TextSpan(text: message.body, style: messageTextStyle),
      textDirection: Directionality.of(context),
      maxLines: textMaxLines,
    )..layout(maxWidth: maxBubbleWidth - 24);
    final isTruncated = overflowProbe.didExceedMaxLines;

    final avatarId = isMine ? currentUserId : message.senderId;
    final avatarBase64 = isMine ? currentUserAvatarBase64 : partnerAvatarBase64;

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
    final media = _parseMediaData(message.body);
    if (media != null) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...
            [
              GestureDetector(
                onTap: onPartnerAvatarTap,
                child: _MessageAvatar(
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
                Container(
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
                      Image.memory(
                        media.bytes,
                        fit: BoxFit.cover,
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
                const SizedBox(height: 2),
                Text(
                  _timeLabel(message.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppPalette.neutral500,
                  ),
                ),
              ],
            ),
            if (isMine) ...
            [
              const SizedBox(width: 6),
              _MessageAvatar(
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
    final stickerId = _parseStickerId(message.body);
    if (stickerId != null) {
      Sticker? found;
      for (final s in stickers) {
        if (s.id == stickerId) {
          found = s;
          break;
        }
      }
      // If not in local cache, try fetching on-demand from server
      if (found == null) {
        final remote = ref.watch(
          stickerByIdProvider((
            id: stickerId,
            baseUrl: serverUrl,
            accessToken: accessToken,
          )),
        );
        found = remote.valueOrNull;
      }
      if (found != null) {
        Uint8List? stickerBytes;
        try {
          stickerBytes = base64Decode(found.contentBase64);
        } catch (_) {}
        if (stickerBytes != null) {
          return Align(
            alignment:
                isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMine) ...
                [
                  GestureDetector(
                    onTap: onPartnerAvatarTap,
                    child: _MessageAvatar(
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        stickerBytes,
                        width: 128,
                        height: 128,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeLabel(message.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppPalette.neutral500,
                      ),
                    ),
                  ],
                ),
                if (isMine) ...
                [
                  const SizedBox(width: 6),
                  _MessageAvatar(
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
    }
    // ────────────────────────────────────────────────────────────────────────

    Widget bubble = Container(
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
            child: _TypingStyleMessageText(
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
                        if (deliveryState != null) ...[
                          if (deliveryState == _OutgoingDeliveryState.sending)
                            Icon(Icons.schedule, size: 11, color: statusColor),
                          if (deliveryState == _OutgoingDeliveryState.failed)
                            GestureDetector(
                              onTap: onRetryTap,
                              child: Icon(
                                Icons.refresh,
                                size: 12,
                                color: statusColor,
                              ),
                            ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _timeLabel(message.createdAt),
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
                          _timeLabel(message.createdAt),
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

    bubble = GestureDetector(onTap: () => _openDetail(context), child: bubble);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            GestureDetector(
              onTap: onPartnerAvatarTap,
              child: _MessageAvatar(
                userId: avatarId,
                avatarBase64: avatarBase64,
                avatarBg: avatarBg,
              ),
            ),
            const SizedBox(width: 6),
          ],
          bubble,
          if (isMine) ...[
            const SizedBox(width: 6),
            _MessageAvatar(
              userId: avatarId,
              avatarBase64: avatarBase64,
              avatarBg: avatarBg,
            ),
          ],
        ],
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TypingStyleMessageText extends StatefulWidget {
  const _TypingStyleMessageText({
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
  State<_TypingStyleMessageText> createState() =>
      _TypingStyleMessageTextState();
}

class _TypingStyleMessageTextState extends State<_TypingStyleMessageText> {
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
  void didUpdateWidget(covariant _TypingStyleMessageText oldWidget) {
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

// —————————————————————————————————————————————————————
// Message detail screen
// —————————————————————————————————————————————————————

class _MessageDetailScreen extends StatelessWidget {
  const _MessageDetailScreen({required this.message, required this.isMine});

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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                AppLocalizations.of(context)!.actionCopy,
                style: TextStyle(
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

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({
    required this.userId,
    required this.avatarBase64,
    required this.avatarBg,
  });

  final String userId;
  final String? avatarBase64;
  final Color avatarBg;

  @override
  Widget build(BuildContext context) {
    final initials = userId.length >= 2
        ? userId.substring(0, 2).toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 12,
      backgroundColor: avatarBg,
      child: avatarBase64 == null
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
                child: Image.memory(
                  base64Decode(avatarBase64!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
    );
  }
}

// —————————————————————————————————————————————————————
// Quick action sheet (Minimal)
// —————————————————————————————————————————————————————

class _QuickActionSheet extends StatelessWidget {
  const _QuickActionSheet({
    required this.inkColor,
    required this.mutedColor,
    required this.ruleColor,
  });

  final Color inkColor;
  final Color mutedColor;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context)!.chatQuickNewHeader,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.8,
                color: mutedColor,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: ruleColor),
            _SheetItem(
              label: AppLocalizations.of(context)!.chatQuickFriendOrStart,
              inkColor: inkColor,
              onTap: () =>
                  Navigator.of(context).pop(_ChatQuickAction.newFriendOrChat),
            ),
            Divider(height: 1, color: ruleColor),
            _SheetItem(
              label: AppLocalizations.of(context)!.chatQuickScanFriendQr,
              inkColor: inkColor,
              onTap: () =>
                  Navigator.of(context).pop(_ChatQuickAction.scanFriendQr),
            ),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  AppLocalizations.of(context)!.actionCancel,
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
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.label,
    required this.inkColor,
    required this.onTap,
  });

  final String label;
  final Color inkColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: inkColor,
          ),
        ),
      ),
    );
  }
}

// —————————————————————————————————————————————————————
// Unread badge
// —————————————————————————————————————————————————————

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppPalette.danger700,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: AppPalette.danger700,
            fontSize: 11,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}
