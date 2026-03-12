import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';
import '../../ui/tokens/colors/app_palette.dart';
import '../../ui/components/atoms/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';

import '../../models/chat_room.dart';
import '../../models/local_chat_message.dart';
import '../../models/sticker.dart';
import '../../models/friend_qr_payload.dart';
import 'chat_send_error_feedback.dart';
import 'friend_qr_scanner_page.dart';
import 'chat_target_profile_page.dart';
import 'room_detail_page.dart';
import '../../services/backup_preferences.dart';
import '../../services/local_chat_repository.dart';
import '../../services/chat_ui_preferences.dart';
import '../../state/app_controller.dart';
import '../../state/backup_controller.dart';
import '../../state/conversation_messages_controller.dart';
import '../../state/hidden_conversation_ids_controller.dart';
import '../../state/realtime_sync_controller.dart';
import '../../state/sticker_controller.dart';
import '../../state/typing_style_mode_controller.dart';
import '../../state/unread_counts_controller.dart';
import '../../state/user_profile_controller.dart';
import 'models/outgoing_draft.dart';
import 'utils/chat_helpers.dart';
import 'widgets/conversation_starter.dart';
import 'widgets/composer.dart';
import 'widgets/message_bubble.dart';
import 'widgets/quick_action_sheet.dart';

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

class _ChatsTabState extends ConsumerState<ChatsTab>
    with SingleTickerProviderStateMixin {
  final _imagePicker = ImagePicker();
  final _partnerController = TextEditingController();
  final _partnerFocusNode = FocusNode();
  final _messageController = TextEditingController();
  final _messageScrollController = ScrollController();
  late final AnimationController _conversationPaneController;
  String? _activePartnerId;
  String? _selectedFriendTag;
  bool _typingSignalSent = false;
  bool _isBackGestureInProgress = false;
  bool _isClosingActiveConversation = false;
  Timer? _typingIdleTimer;
  Uint8List? _selectedMediaBytes;
  String? _selectedMediaName;
  final Set<String> _profileSyncInFlight = <String>{};
  final Set<String> _profileSyncedOnce = <String>{};
  final Map<String, String> _partnerServerUrlOverrides = <String, String>{};
  final Map<String, List<OutgoingMessageDraft>> _outgoingDraftsByPartner =
      <String, List<OutgoingMessageDraft>>{};
  List<ConversationSummary> _conversationSummariesCache = const [];
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _conversationPaneController = AnimationController(
      vsync: this,
      duration: chatPaneTransitionDuration,
      reverseDuration: chatPaneTransitionReverseDuration,
    );
    _partnerController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncRooms());
    });
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
    if (widget.serverUrl != oldWidget.serverUrl ||
        widget.accessToken != oldWidget.accessToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_syncRooms());
      });
    }
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
    _conversationPaneController.dispose();
    super.dispose();
  }

  void _sendTypingSignal(bool isTyping) {
    final partnerId = _activePartnerId;
    if (partnerId == null ||
        partnerId.isEmpty ||
        isRoomConversationId(partnerId)) {
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
      final oldAvatar = await prefs.readAvatarBase64(
        widget.serverUrl,
        normalized,
      );
      final oldDescription = await prefs.readDescription(
        widget.serverUrl,
        normalized,
      );
      await prefs.writeDisplayName(
        widget.serverUrl,
        normalized,
        profile.username,
      );
      await prefs.writeAvatarBase64(
        widget.serverUrl,
        normalized,
        profile.avatarBase64,
      );
      await prefs.writeDescription(
        widget.serverUrl,
        normalized,
        profile.description,
      );
      ref.invalidate(userDisplayNameProvider(normalized));
      // Only invalidate the avatar provider when the image actually changed.
      // An unconditional invalidate causes a loading→data cycle that makes
      // every _MessageAvatar flash back to initials and then re-render.
      if (profile.avatarBase64 != oldAvatar) {
        ref.invalidate(userAvatarBase64Provider(normalized));
      }
      if ((profile.description?.trim() ?? '') !=
          ((oldDescription ?? '').trim())) {
        ref.invalidate(userDescriptionProvider(normalized));
      }
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

  void _setBackGestureInProgress(bool value) {
    if (_isBackGestureInProgress == value || !mounted) {
      return;
    }
    setState(() => _isBackGestureInProgress = value);
  }

  void _closeActiveConversation() {
    unawaited(_closeActiveConversationWithAnimation());
  }

  Future<void> _closeActiveConversationWithAnimation() async {
    if (_activePartnerId == null || _isClosingActiveConversation) {
      return;
    }
    _isClosingActiveConversation = true;
    _conversationPaneController.stop();
    _setBackGestureInProgress(false);
    await _conversationPaneController.animateBack(0);
    if (!mounted) {
      return;
    }
    if (_typingSignalSent) {
      _sendTypingSignal(false);
      _typingSignalSent = false;
    }
    _typingIdleTimer?.cancel();
    setState(() => _activePartnerId = null);
    widget.onPartnerChanged(null);
    _isClosingActiveConversation = false;
  }

  void _handleBackGestureStart() {
    if (_activePartnerId == null) {
      return;
    }
    _conversationPaneController.stop();
  }

  void _handleBackGestureUpdate(DragUpdateDetails details, double paneWidth) {
    if (_activePartnerId == null || paneWidth <= 0) {
      return;
    }
    final delta = details.primaryDelta ?? 0;
    if (!_isBackGestureInProgress) {
      if (delta <= 0) {
        return;
      }
      _setBackGestureInProgress(true);
    }
    final nextValue = (_conversationPaneController.value - (delta / paneWidth))
        .clamp(0.0, 1.0);
    _conversationPaneController.value = nextValue;
  }

  void _handleBackGestureCancel() {
    if (_activePartnerId == null) {
      return;
    }
    _setBackGestureInProgress(false);
    _conversationPaneController.animateTo(1);
  }

  Future<void> _handleBackGestureEnd(DragEndDetails details) async {
    if (_activePartnerId == null) {
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final shouldClose = shouldCompleteChatBackGesture(
      transitionProgress: _conversationPaneController.value,
      velocity: velocity,
    );
    if (shouldClose) {
      await _closeActiveConversationWithAnimation();
      return;
    }
    _setBackGestureInProgress(false);
    await _conversationPaneController.animateTo(1);
  }

  Future<void> _clearConversation(String conversationId) async {
    if (_activePartnerId == conversationId) {
      _closeActiveConversation();
    }
    final clearedAt = DateTime.now().toUtc();
    final repository = ref.read(chatRepositoryProvider);
    await BackupPreferences().writeConversationClearedAt(
      serverUrl: widget.serverUrl,
      conversationId: conversationId,
      clearedAt: clearedAt,
    );
    await repository.clearConversation(conversationId);
    await ref.read(hiddenConversationIdsProvider.notifier).hide(conversationId);
    ref.read(unreadCountsProvider.notifier).clearForPartner(conversationId);
    ref.invalidate(conversationMessagesProvider(conversationId));
    ref.invalidate(conversationSummariesProvider);
  }

  Future<void> _syncRooms() async {
    try {
      final accessToken = await _effectiveAccessToken();
      await ref
          .read(roomConversationsProvider.notifier)
          .syncRooms(baseUrl: widget.serverUrl, accessToken: accessToken);
    } catch (_) {
      // Keep the direct-message experience functional even if room sync fails.
    }
  }

  Future<void> _openPartner(String partnerId) async {
    if (_typingSignalSent) {
      _sendTypingSignal(false);
      _typingSignalSent = false;
    }
    final shouldAnimateIn = _activePartnerId == null;
    _conversationPaneController.stop();
    if (shouldAnimateIn) {
      _conversationPaneController.value = 0;
    }
    _setBackGestureInProgress(false);
    setState(() => _activePartnerId = partnerId);
    widget.onPartnerChanged(partnerId);
    if (shouldAnimateIn) {
      _conversationPaneController.animateTo(1);
    }
    if (!isRoomConversationId(partnerId)) {
      await _syncUserProfile(partnerId, force: true);
    }
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
    if (!isRoomConversationId(partnerId)) {
      ref.read(unreadCountsProvider.notifier).clearForPartner(partnerId);
    }
  }

  Future<ChatTargetInput?> _promptForChatTarget() async {
    final targetController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    final result = await showDialog<ChatTargetInput>(
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

  ChatTargetInput _parseChatTargetInput(
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
      return ChatTargetInput(
        friendId: id,
        serverUrl: origin.isEmpty ? defaultServerUrl : origin,
      );
    }

    return ChatTargetInput(friendId: value, serverUrl: defaultServerUrl);
  }

  Future<ResolvedTargetProfile?> _resolveTarget(ChatTargetInput target) async {
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
    int? guildLevel;
    String? guildRank;
    final prefs = ref.read(userProfilePreferencesProvider);
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
      description = (profile.description ?? '').trim().isEmpty
          ? null
          : profile.description!.trim();
      await prefs.writeDescription(
        widget.serverUrl,
        resolved.partnerId,
        description,
      );
      guildLevel = profile.guild?.level;
      guildRank = profile.guild?.rank;
    } catch (_) {
      // fallback to resolved handle only
    }
    description ??= await prefs.readDescription(
      widget.serverUrl,
      resolved.partnerId,
    );

    return ResolvedTargetProfile(
      partnerId: resolved.partnerId,
      recipientServerUrl: resolved.recipientServerUrl,
      displayName: displayName,
      displayHandle: resolved.displayHandle,
      avatarBase64: avatarBase64,
      description: description,
      level: guildLevel,
      rank: guildRank,
    );
  }

  Future<void> _openFromTarget(ChatTargetInput target) async {
    try {
      final resolved = await _resolveTarget(target);
      if (!mounted || resolved == null) {
        return;
      }
      final sentMessageCount = await _sentMessageCountForPartner(
        resolved.partnerId,
      );
      final prefs = ref.read(userProfilePreferencesProvider);
      final isFriend = (await prefs.readFriendIds(
        widget.serverUrl,
      )).contains(resolved.partnerId);
      final friendAddedAt = isFriend
          ? await prefs.readFriendAddedAt(widget.serverUrl, resolved.partnerId)
          : null;
      if (!mounted) {
        return;
      }

      final action = await Navigator.of(context).push<ChatTargetProfileAction>(
        MaterialPageRoute<ChatTargetProfileAction>(
          builder: (_) => ChatTargetProfileScreen(
            serverUrl: widget.serverUrl,
            userId: resolved.partnerId,
            displayName: resolved.displayName,
            displayHandle: resolved.displayHandle,
            avatarBase64: resolved.avatarBase64,
            isFriend: isFriend,
            friendAddedAt: friendAddedAt,
            sentMessageCount: sentMessageCount,
            description: resolved.description,
            level: resolved.level,
            rank: resolved.rank,
          ),
        ),
      );
      if (!mounted || action == null) {
        ref.invalidate(friendTagCatalogProvider);
        ref.invalidate(friendTagMapProvider);
        ref.invalidate(friendTagsProvider(resolved.partnerId));
        return;
      }
      ref.invalidate(friendTagCatalogProvider);
      ref.invalidate(friendTagMapProvider);
      ref.invalidate(friendTagsProvider(resolved.partnerId));

      if (action == ChatTargetProfileAction.cancelFriend) {
        await prefs.removeFriendId(widget.serverUrl, resolved.partnerId);
        ref.invalidate(friendIdsProvider);
        if (!mounted) {
          return;
        }
        showAppToast(context, _l10n.friendRemoved);
        return;
      }
      if (action == ChatTargetProfileAction.addFriend && mounted) {
        await prefs.addFriendId(widget.serverUrl, resolved.partnerId);
        ref.invalidate(friendIdsProvider);
        if (!mounted) {
          return;
        }
        showAppToast(
          context,
          _l10n.friendAdded,
          duration: const Duration(milliseconds: 900),
        );
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

  Future<CreateRoomInput?> _promptForRoomCreation() async {
    final nameController = TextEditingController();
    final friendIds =
        ref.read(friendIdsProvider).value ??
        await ref.read(friendIdsProvider.future).catchError((_) {
          return const <String>[];
        });
    final friendTagCatalog =
        ref.read(friendTagCatalogProvider).value ??
        await ref.read(friendTagCatalogProvider.future).catchError((_) {
          return const <String>[];
        });
    final friendTagMap =
        ref.read(friendTagMapProvider).value ??
        await ref.read(friendTagMapProvider.future).catchError((_) {
          return const <String, List<String>>{};
        });
    if (!mounted) {
      return null;
    }
    final memberOptions =
        friendIds
            .map(
              (userId) => RoomMemberOption(
                userId: userId,
                displayName: displayNameOrFallback(
                  userId,
                  ref.read(userDisplayNameProvider(userId)).value,
                ),
                tags: friendTagMap[userId] ?? const <String>[],
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    final result = await showDialog<CreateRoomInput>(
      context: context,
      builder: (context) {
        final selectedIds = <String>{};
        String? selectedTag = friendTagCatalog.contains(_selectedFriendTag)
            ? _selectedFriendTag
            : null;
        return StatefulBuilder(
          builder: (context, setState) {
            final hasName = nameController.text.trim().isNotEmpty;
            final visibleMemberOptions = selectedTag == null
                ? memberOptions
                : memberOptions
                      .where(
                        (option) => friendMatchesSelectedTag(
                          friendTags: option.tags,
                          selectedFriendTag: selectedTag,
                        ),
                      )
                      .toList(growable: false);
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
                      _l10n.chatCreateRoomHeader,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.6,
                        color: AppPalette.neutral500,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _l10n.chatCreateRoomTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: inkColor,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        color: inkColor,
                      ),
                      decoration: InputDecoration(
                        labelText: _l10n.chatCreateRoomNameLabel,
                        hintText: _l10n.chatCreateRoomNameHint,
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
                    Text(
                      _l10n.chatCreateRoomMembersLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppPalette.neutral500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (friendTagCatalog.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: friendTagCatalog.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, index) {
                            final tag = index == 0
                                ? null
                                : friendTagCatalog[index - 1];
                            final selected = tag == null
                                ? selectedTag == null
                                : tag == selectedTag;
                            return ChoiceChip(
                              label: Text(tag ?? 'All'),
                              selected: selected,
                              onSelected: (_) {
                                setState(() => selectedTag = tag);
                              },
                              backgroundColor: isDark
                                  ? AppPalette.neutral800
                                  : AppPalette.neutral100,
                              selectedColor: isDark
                                  ? AppPalette.neutral700
                                  : AppPalette.neutral300,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                                color: inkColor,
                              ),
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: selected
                                      ? AppPalette.neutral500
                                      : ruleColor,
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (memberOptions.isEmpty)
                      Text(
                        _l10n.chatCreateRoomNoFriends,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.neutral500,
                          fontWeight: FontWeight.w300,
                        ),
                      )
                    else if (visibleMemberOptions.isEmpty)
                      Text(
                        'No friends match this tag.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.neutral500,
                          fontWeight: FontWeight.w300,
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: visibleMemberOptions.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: ruleColor),
                          itemBuilder: (_, index) {
                            final option = visibleMemberOptions[index];
                            final selected = selectedIds.contains(
                              option.userId,
                            );
                            return CheckboxListTile(
                              value: selected,
                              onChanged: (_) {
                                setState(() {
                                  if (selected) {
                                    selectedIds.remove(option.userId);
                                  } else {
                                    selectedIds.add(option.userId);
                                  }
                                });
                              },
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                option.displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: inkColor,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
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
                          onTap: hasName
                              ? () => Navigator.of(context).pop(
                                  CreateRoomInput(
                                    name: nameController.text.trim(),
                                    memberIds: selectedIds.toList(
                                      growable: false,
                                    ),
                                  ),
                                )
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Text(
                              _l10n.chatCreateRoomAction,
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 2.4,
                                fontWeight: FontWeight.w500,
                                color: hasName
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
    });
    return result;
  }

  Future<void> _openNewRoom() async {
    final input = await _promptForRoomCreation();
    if (!mounted || input == null) {
      return;
    }

    try {
      final accessToken = await _effectiveAccessToken();
      final room = await ref
          .read(roomConversationsProvider.notifier)
          .createRoom(
            baseUrl: widget.serverUrl,
            accessToken: accessToken,
            name: input.name,
            memberIds: input.memberIds,
          );
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        _l10n.chatRoomCreated,
        duration: const Duration(milliseconds: 900),
      );
      await _openPartner(room.conversationId);
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, error.toString(), variant: AppToastVariant.error);
    }
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
      ChatTargetInput(friendId: payload.userId, serverUrl: payload.serverUrl),
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
      _handleOutgoingSendError(
        error: error,
        partnerId: partnerId,
        draftId: draftId,
      );
    }
  }

  String _addOutgoingDraft({required String partnerId, required String body}) {
    final id =
        'draft-${DateTime.now().microsecondsSinceEpoch}-${body.length.hashCode.abs()}';
    final next = OutgoingMessageDraft(
      id: id,
      partnerId: partnerId,
      body: body,
      createdAt: DateTime.now().toUtc(),
      state: OutgoingDeliveryState.sending,
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
    _updateOutgoingDraftStatus(
      partnerId: partnerId,
      draftId: draftId,
      state: OutgoingDeliveryState.failed,
    );
  }

  void _markOutgoingDraftBlocked({
    required String partnerId,
    required String draftId,
    required String statusLabel,
  }) {
    _updateOutgoingDraftStatus(
      partnerId: partnerId,
      draftId: draftId,
      state: OutgoingDeliveryState.blocked,
      statusLabel: statusLabel,
    );
  }

  void _updateOutgoingDraftStatus({
    required String partnerId,
    required String draftId,
    required OutgoingDeliveryState state,
    String? statusLabel,
  }) {
    if (!_outgoingDraftsByPartner.containsKey(partnerId)) {
      return;
    }
    setState(() {
      final next = (_outgoingDraftsByPartner[partnerId] ?? const [])
          .map(
            (draft) => draft.id == draftId
                ? draft.copyWith(
                    state: state,
                    statusLabel: statusLabel,
                    resetStatusLabel: state != OutgoingDeliveryState.blocked,
                  )
                : draft,
          )
          .toList(growable: false);
      _outgoingDraftsByPartner[partnerId] = next;
    });
  }

  void _handleOutgoingSendError({
    required Object error,
    required String partnerId,
    required String draftId,
  }) {
    final feedback = buildChatSendErrorFeedback(error, _l10n);
    if (feedback != null && !feedback.allowsRetry) {
      _markOutgoingDraftBlocked(
        partnerId: partnerId,
        draftId: draftId,
        statusLabel: feedback.inlineMessage ?? feedback.toastMessage,
      );
    } else {
      _markOutgoingDraftFailed(partnerId: partnerId, draftId: draftId);
    }
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      feedback?.toastMessage ?? error.toString(),
      variant: AppToastVariant.error,
    );
  }

  Future<void> _retryOutgoingDraft(OutgoingMessageDraft draft) async {
    if (draft.state != OutgoingDeliveryState.failed) {
      return;
    }
    setState(() {
      final current = _outgoingDraftsByPartner[draft.partnerId] ?? const [];
      _outgoingDraftsByPartner[draft.partnerId] = current
          .map(
            (item) => item.id == draft.id
                ? item.copyWith(
                    state: OutgoingDeliveryState.sending,
                    resetStatusLabel: true,
                  )
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
    } catch (error) {
      _handleOutgoingSendError(
        error: error,
        partnerId: draft.partnerId,
        draftId: draft.id,
      );
    }
  }

  Future<void> _openUserProfile(String partnerId) async {
    await _syncUserProfile(partnerId);
    if (!mounted) {
      return;
    }
    final displayName = displayNameOrFallback(
      partnerId,
      ref.read(userDisplayNameProvider(partnerId)).value,
    );
    final avatarBase64 = ref.read(userAvatarBase64Provider(partnerId)).value;
    final sentMessageCount = await _sentMessageCountForPartner(partnerId);
    final prefs = ref.read(userProfilePreferencesProvider);
    final description = await prefs.readDescription(
      widget.serverUrl,
      partnerId,
    );
    final isFriend = (await prefs.readFriendIds(
      widget.serverUrl,
    )).contains(partnerId);
    final friendAddedAt = isFriend
        ? await prefs.readFriendAddedAt(widget.serverUrl, partnerId)
        : null;
    int? guildLevel;
    String? guildRank;
    try {
      final accessToken = await _effectiveAccessToken();
      final profile = await ref
          .read(remoteUserProfileServiceProvider)
          .getUserProfile(
            baseUrl: widget.serverUrl,
            accessToken: accessToken,
            userId: partnerId,
          );
      guildLevel = profile.guild?.level;
      guildRank = profile.guild?.rank;
    } catch (_) {
      // guild data is optional
    }
    if (!mounted) {
      return;
    }
    final action = await Navigator.of(context).push<ChatTargetProfileAction>(
      MaterialPageRoute<ChatTargetProfileAction>(
        builder: (_) => ChatTargetProfileScreen(
          serverUrl: widget.serverUrl,
          userId: partnerId,
          displayName: displayName,
          displayHandle: partnerId,
          avatarBase64: avatarBase64,
          isFriend: isFriend,
          friendAddedAt: friendAddedAt,
          sentMessageCount: sentMessageCount,
          description: description,
          level: guildLevel,
          rank: guildRank,
        ),
      ),
    );
    if (!mounted || action == null) {
      ref.invalidate(friendTagCatalogProvider);
      ref.invalidate(friendTagMapProvider);
      ref.invalidate(friendTagsProvider(partnerId));
      return;
    }
    ref.invalidate(friendTagCatalogProvider);
    ref.invalidate(friendTagMapProvider);
    ref.invalidate(friendTagsProvider(partnerId));
    if (action == ChatTargetProfileAction.addFriend) {
      await ref
          .read(userProfilePreferencesProvider)
          .addFriendId(widget.serverUrl, partnerId);
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
      await ref
          .read(userProfilePreferencesProvider)
          .removeFriendId(widget.serverUrl, partnerId);
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

  Future<void> _openActivePartnerProfile() async {
    final partnerId = _activePartnerId;
    if (partnerId == null ||
        partnerId.isEmpty ||
        isRoomConversationId(partnerId)) {
      return;
    }
    await _openUserProfile(partnerId);
  }

  Future<void> _openRoomDetail() async {
    final partnerId = _activePartnerId;
    if (partnerId == null || !isRoomConversationId(partnerId)) return;
    final roomId = tryParseRoomId(partnerId);
    if (roomId == null) return;

    final result = await Navigator.of(context).push<RoomDetailAction>(
      MaterialPageRoute<RoomDetailAction>(
        builder: (_) => RoomDetailPage(
          serverUrl: widget.serverUrl,
          roomId: roomId,
          currentUserId: widget.currentUserId,
        ),
      ),
    );

    if (!mounted) return;
    if (result == RoomDetailAction.left || result == RoomDetailAction.deleted) {
      _closeActiveConversation();
      final accessToken = await _effectiveAccessToken();
      if (!mounted) return;
      await ref
          .read(roomConversationsProvider.notifier)
          .syncRooms(baseUrl: widget.serverUrl, accessToken: accessToken);
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
        if (isRoomConversationId(partnerId)) {
          final roomId = tryParseRoomId(partnerId);
          if (roomId != null) {
            await ref
                .read(roomConversationsProvider.notifier)
                .markRoomReadLocal(roomId);
          }
        } else {
          ref.read(unreadCountsProvider.notifier).clearForPartner(partnerId);
        }
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
    final remoteUnreadCounts =
        ref.watch(unreadCountsProvider).value ?? const <String, int>{};
    final hiddenConversationIds =
        ref.watch(hiddenConversationIdsProvider).value ?? const <String>{};
    final friendTagCatalog =
        ref.watch(friendTagCatalogProvider).value ?? const <String>[];
    final friendTagMap =
        ref.watch(friendTagMapProvider).value ?? const <String, List<String>>{};
    final selectedFriendTag = friendTagCatalog.contains(_selectedFriendTag)
        ? _selectedFriendTag
        : null;
    if (_selectedFriendTag != null && selectedFriendTag == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() => _selectedFriendTag = null);
      });
    }
    ref.listen<AsyncValue<List<ConversationSummary>>>(
      conversationSummariesProvider,
      (_, next) {
        final value = next.valueOrNull;
        if (value != null) {
          _conversationSummariesCache = value;
        }
      },
    );
    final conversationSummaries =
        ref.watch(conversationSummariesProvider).valueOrNull ??
        _conversationSummariesCache;
    final allSummariesById = <String, ConversationSummary>{
      for (final summary in conversationSummaries)
        summary.conversationId: summary,
    };
    final unreadCounts = <String, int>{
      ...remoteUnreadCounts,
      for (final summary in conversationSummaries)
        summary.conversationId: summary.isRoom
            ? summary.unreadCount
            : (remoteUnreadCounts[summary.conversationId] ??
                  summary.unreadCount),
    };
    final searchQuery = _partnerController.text.trim().toLowerCase();
    final filteredSummaries = searchQuery.isEmpty && selectedFriendTag == null
        ? conversationSummaries
        : conversationSummaries
              .where((summary) {
                if (!conversationMatchesSelectedFriendTag(
                  conversationId: summary.conversationId,
                  selectedFriendTag: selectedFriendTag,
                  friendTagsById: friendTagMap,
                )) {
                  return false;
                }
                return (summary.title ?? summary.conversationId)
                        .toLowerCase()
                        .contains(searchQuery) ||
                    summary.conversationId.toLowerCase().contains(
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
            }
            .where(
              (id) =>
                  !hiddenConversationIds.contains(id) &&
                  conversationMatchesSelectedFriendTag(
                    conversationId: id,
                    selectedFriendTag: selectedFriendTag,
                    friendTagsById: friendTagMap,
                  ),
            )
            .toList(growable: false)
          ..sort((a, b) {
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
    // Preload message providers for the top conversations so that opening one
    // has data ready immediately (no AsyncLoading flash).
    for (final id in orderedConversationIds.take(15)) {
      ref.watch(conversationMessagesProvider(id));
    }

    final rowUserIds = orderedConversationIds
        .where((id) => !isRoomConversationId(id))
        .toSet();
    _prefetchVisibleProfiles(rowUserIds);
    final activeSummary = _activePartnerId == null
        ? null
        : allSummariesById[_activePartnerId!];
    final activeUnread = _activePartnerId == null
        ? 0
        : (unreadCounts[_activePartnerId!] ?? 0);
    final inConversation = _activePartnerId != null;
    final activeDisplayName = _activePartnerId == null
        ? null
        : isRoomConversationId(_activePartnerId!)
        ? (activeSummary?.title ?? _l10n.chatDefaultRoom)
        : displayNameOrFallback(
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
        !isRoomConversationId(_activePartnerId!) &&
        (realtimeState?.typingPartnerIds.contains(_activePartnerId!) ?? false);
    final messagesAsync = _activePartnerId == null
        ? null
        : ref.watch(conversationMessagesProvider(_activePartnerId!));
    final listPane = SafeArea(
      child: ConversationStarter(
        controller: _partnerController,
        focusNode: _partnerFocusNode,
        unreadCounts: unreadCounts,
        orderedConversationIds: orderedConversationIds,
        summariesById: summariesById,
        onQuickAction: (action) {
          switch (action) {
            case ChatQuickAction.newRoom:
              _openNewRoom();
              break;
            case ChatQuickAction.newFriendOrChat:
              _openNewFriendOrChat();
              break;
            case ChatQuickAction.scanFriendQr:
              _scanQrAndOpen();
              break;
          }
        },
        onOpenConversation: (id) async {
          await _openPartner(id);
        },
        onClearConversation: _clearConversation,
        onMarkAllRead: () => _markAllUnreadAsRead(unreadCounts),
        onStartNewChat: _openNewFriendOrChat,
        onAddFriend: _openNewFriendOrChat,
        availableFriendTags: friendTagCatalog,
        selectedFriendTag: selectedFriendTag,
        onSelectedFriendTag: (tag) {
          setState(() => _selectedFriendTag = tag);
        },
      ),
    );
    final conversationPage = Material(
      color: bgColor,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(CupertinoIcons.back),
                      onPressed: _closeActiveConversation,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _activePartnerId == null
                            ? null
                            : isRoomConversationId(_activePartnerId!)
                            ? _openRoomDetail
                            : _openActivePartnerProfile,
                        child: Text(
                          activeDisplayName ?? _l10n.chatDefaultTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  if (activeUnread > 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: UnreadBadge(count: activeUnread),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: messagesAsync == null
                      ? const SizedBox.expand()
                      : messagesAsync.when(
                          loading: () => const SizedBox.expand(),
                          error: (err, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('$err', textAlign: TextAlign.center),
                            ),
                          ),
                          data: (messages) {
                            final activePartnerId = _activePartnerId;
                            final draftMessages = activePartnerId == null
                                ? const <OutgoingMessageDraft>[]
                                : (_outgoingDraftsByPartner[activePartnerId] ??
                                      const <OutgoingMessageDraft>[]);
                            final draftById = <String, OutgoingMessageDraft>{
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
                            _prefetchVisibleProfiles(
                              displayedMessages.map((m) => m.senderId),
                            );

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
                                          i == displayedMessages.length - 1 ||
                                          !isSameDay(
                                            message.createdAt,
                                            displayedMessages[i + 1].createdAt,
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
                                              child: DayDivider(
                                                label: dayLabel(
                                                  context,
                                                  message.createdAt,
                                                ),
                                              ),
                                            ),
                                          MessageBubble(
                                            key: ValueKey(message.id),
                                            message: message,
                                            isMine:
                                                message.senderId ==
                                                widget.currentUserId,
                                            currentUserId: widget.currentUserId,
                                            partnerId: _activePartnerId!,
                                            isRoomConversation:
                                                isRoomConversationId(
                                                  _activePartnerId!,
                                                ),
                                            onAvatarTap:
                                                message.senderId ==
                                                    widget.currentUserId
                                                ? null
                                                : () => _openUserProfile(
                                                    message.senderId,
                                                  ),
                                            stickers: stickers,
                                            serverUrl: widget.serverUrl,
                                            accessToken: widget.accessToken,
                                            deliveryState: draft?.state,
                                            statusLabel: draft?.statusLabel,
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
                SafeArea(
                  top: false,
                  child: Composer(
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
        ],
      ),
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!inConversation) {
              return listPane;
            }
            return AnimatedBuilder(
              animation: _conversationPaneController,
              child: conversationPage,
              builder: (context, child) {
                final progress = _conversationPaneController.value;
                final backgroundOffset =
                    -constraints.maxWidth *
                    chatPaneBackgroundParallaxProgress(
                      progress,
                      linearTransition: _isBackGestureInProgress,
                    );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.translate(
                      offset: Offset(backgroundOffset, 0),
                      child: IgnorePointer(ignoring: true, child: listPane),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: (_) => _handleBackGestureStart(),
                      onHorizontalDragUpdate: (details) =>
                          _handleBackGestureUpdate(
                            details,
                            constraints.maxWidth,
                          ),
                      onHorizontalDragCancel: _handleBackGestureCancel,
                      onHorizontalDragEnd: (details) {
                        unawaited(_handleBackGestureEnd(details));
                      },
                      child: CupertinoPageTransition(
                        primaryRouteAnimation: _conversationPaneController.view,
                        secondaryRouteAnimation:
                            const AlwaysStoppedAnimation<double>(0),
                        linearTransition: _isBackGestureInProgress,
                        child: child!,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
