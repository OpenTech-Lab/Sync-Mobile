import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';

import '../models/local_chat_message.dart';
import '../models/sticker.dart';
import '../models/friend_qr_payload.dart';
import 'friend_qr_scanner_screen.dart';
import '../services/local_chat_repository.dart';
import '../state/app_controller.dart';
import '../state/conversation_messages_controller.dart';
import '../state/sticker_controller.dart';
import '../state/unread_counts_controller.dart';
import '../state/user_profile_controller.dart';

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
  bool _isTyping = false;
  Timer? _typingTimer;
  Uint8List? _selectedMediaBytes;
  String? _selectedMediaName;
  final Set<String> _profileSyncInFlight = <String>{};
  final Set<String> _profileSyncedOnce = <String>{};
  final Map<String, String> _partnerServerUrlOverrides = <String, String>{};

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
    _typingTimer?.cancel();
    _partnerController.removeListener(_onSearchChanged);
    _partnerController.dispose();
    _partnerFocusNode.dispose();
    _messageController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  void _onComposerChanged(String value) {
    _typingTimer?.cancel();
    final typing = value.trim().isNotEmpty;
    if (typing != _isTyping) setState(() => _isTyping = typing);
    if (typing) {
      _typingTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }
  }

  Future<void> _pickMedia() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
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

  Future<void> _openPartner(String partnerId) async {
    setState(() => _activePartnerId = partnerId);
    _partnerController.text = partnerId;
    widget.onPartnerChanged(partnerId);
    await _syncUserProfile(partnerId, force: true);
    final accessToken = await _effectiveAccessToken();
    await ref
        .read(conversationMessagesProvider(partnerId).notifier)
        .syncLatest(baseUrl: widget.serverUrl, accessToken: accessToken);
    await ref
        .read(conversationMessagesProvider(partnerId).notifier)
        .markRead(baseUrl: widget.serverUrl, accessToken: accessToken);
    ref.read(unreadCountsProvider.notifier).clearForPartner(partnerId);
    ref.invalidate(conversationSummariesProvider);
  }

  Future<_ChatTargetInput?> _promptForChatTarget({
    required String title,
    required String confirmLabel,
  }) async {
    final idController = TextEditingController();
    final serverController = TextEditingController();
    final result = await showDialog<_ChatTargetInput>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Friend ID',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {},
              ),
              const SizedBox(height: 12),
              TextField(
                controller: serverController,
                decoration: const InputDecoration(
                  hintText: 'Friend server URL (required for other planet)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _ChatTargetInput(
                  friendId: idController.text.trim(),
                  serverUrl: serverController.text.trim(),
                ),
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    idController.dispose();
    serverController.dispose();
    return result;
  }

  Future<void> _openFromTarget(_ChatTargetInput target) async {
    final friendId = target.friendId.trim();
    if (friendId.isEmpty) {
      return;
    }

    final serverUrl = target.serverUrl.trim();
    if (serverUrl.isEmpty) {
      _partnerServerUrlOverrides.remove(friendId);
      await _openPartner(friendId);
      return;
    }

    try {
      final accessToken = await _effectiveAccessToken();
      final remote = ref.read(remoteChatServiceProvider);
      final resolved = await remote.resolveContact(
        baseUrl: widget.serverUrl,
        accessToken: accessToken,
        recipientId: friendId,
        recipientServerUrl: serverUrl,
      );
      _partnerServerUrlOverrides[resolved.partnerId] =
          resolved.recipientServerUrl;
      await _openPartner(resolved.partnerId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _startNewChat() async {
    final target = await _promptForChatTarget(
      title: 'Start new chat',
      confirmLabel: 'Start',
    );

    if (!mounted || target == null || target.friendId.isEmpty) {
      return;
    }

    await _openFromTarget(target);
  }

  Future<void> _showAddFriendDialog() async {
    final target = await _promptForChatTarget(
      title: 'Add friend',
      confirmLabel: 'Add',
    );

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
    final mediaLabel = _selectedMediaName == null
        ? ''
        : '[media-preview:${_selectedMediaName!}]';
    final content = [text, mediaLabel].where((p) => p.isNotEmpty).join('\n');
    if (content.isEmpty) return;

    _messageController.clear();
    setState(() => _isTyping = false);

    final accessToken = await _effectiveAccessToken();

    await ref
        .read(conversationMessagesProvider(_activePartnerId!).notifier)
        .sendMessage(
          baseUrl: widget.serverUrl,
          accessToken: accessToken,
          body: content,
          recipientServerUrl: _partnerServerUrlOverrides[_activePartnerId!],
        );
    _clearMedia();
    await ref
        .read(unreadCountsProvider.notifier)
        .refresh(baseUrl: widget.serverUrl, accessToken: accessToken);
  }

  @override
  Widget build(BuildContext context) {
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
    final rowUserIds = <String>{
      ...filteredSummaries.map((s) => s.conversationId),
      ...unreadCounts.keys,
    };
    _prefetchVisibleProfiles(rowUserIds);
    final activeUnread = _activePartnerId == null
        ? 0
        : (unreadCounts[_activePartnerId!] ?? 0);
    final inConversation = _activePartnerId != null;
    final messagesAsync = _activePartnerId == null
        ? null
        : ref.watch(conversationMessagesProvider(_activePartnerId!));
    final activePartnerName = _activePartnerId == null
        ? null
        : ref.watch(userDisplayNameProvider(_activePartnerId!)).value;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: inConversation ? Colors.transparent : cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: inConversation,
        title: _activePartnerId == null
            ? const Text('Chats')
            : Text(
                (activePartnerName ?? '').trim().isEmpty
                    ? 'Conversation'
                    : activePartnerName!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        leading: _activePartnerId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() => _activePartnerId = null);
                  widget.onPartnerChanged(null);
                },
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          if (_activePartnerId == null)
            PopupMenuButton<_ChatQuickAction>(
              tooltip: 'New chat or add friend',
              icon: const Icon(Icons.add),
              onSelected: (action) {
                switch (action) {
                  case _ChatQuickAction.newChat:
                    _startNewChat();
                  case _ChatQuickAction.newChatQr:
                    _scanQrAndOpen();
                  case _ChatQuickAction.addFriend:
                    _showAddFriendDialog();
                  case _ChatQuickAction.addFriendQr:
                    _scanQrAndOpen();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_ChatQuickAction>(
                  value: _ChatQuickAction.newChat,
                  child: Text('Start new chat'),
                ),
                PopupMenuItem<_ChatQuickAction>(
                  value: _ChatQuickAction.newChatQr,
                  child: Text('Start new chat (QR)'),
                ),
                PopupMenuItem<_ChatQuickAction>(
                  value: _ChatQuickAction.addFriend,
                  child: Text('Add friend'),
                ),
                PopupMenuItem<_ChatQuickAction>(
                  value: _ChatQuickAction.addFriendQr,
                  child: Text('Add friend (QR)'),
                ),
              ],
            ),
          if (_activePartnerId != null && activeUnread > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _UnreadBadge(count: activeUnread),
            ),
        ],
      ),
      body: _activePartnerId == null
          ? _ConversationStarter(
              controller: _partnerController,
              focusNode: _partnerFocusNode,
              unreadCounts: unreadCounts,
              summaries: filteredSummaries,
              onOpenConversation: (id) async {
                await _openPartner(id);
              },
              onRefresh: () async {
                final accessToken = await _effectiveAccessToken();
                await ref
                    .read(unreadCountsProvider.notifier)
                    .refresh(
                      baseUrl: widget.serverUrl,
                      accessToken: accessToken,
                    );
              },
              onStartNewChat: _startNewChat,
              onAddFriend: _showAddFriendDialog,
            )
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: messagesAsync == null
                      ? const Center(child: CircularProgressIndicator())
                      : messagesAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('$err', textAlign: TextAlign.center),
                            ),
                          ),
                          data: (messages) => messages.isEmpty
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
                                        'No messages yet.\nSay hello!',
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
                                  itemCount: messages.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (ctx, i) => _MessageBubble(
                                    message: messages[i],
                                    isMine:
                                        messages[i].senderId ==
                                        widget.currentUserId,
                                    currentUserId: widget.currentUserId,
                                    currentUserAvatarBase64:
                                        currentUserAvatarBase64,
                                    partnerAvatarBase64: partnerAvatarBase64,
                                  ),
                                ),
                        ),
                ),

                // Typing indicator
                if (_isTyping)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Typing…',
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
                      final accessToken = await _effectiveAccessToken();
                      await ref
                          .read(
                            conversationMessagesProvider(
                              _activePartnerId!,
                            ).notifier,
                          )
                          .sendMessage(
                            baseUrl: widget.serverUrl,
                            accessToken: accessToken,
                            body: '[sticker:${sticker.id}:${sticker.name}]',
                            recipientServerUrl:
                                _partnerServerUrlOverrides[_activePartnerId!],
                          );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

enum _ChatQuickAction { newChat, newChatQr, addFriend, addFriendQr }

class _ChatTargetInput {
  const _ChatTargetInput({required this.friendId, required this.serverUrl});

  final String friendId;
  final String serverUrl;
}

// —————————————————————————————————————————————————————
// Conversation starter (empty state)
// —————————————————————————————————————————————————————

class _ConversationStarter extends ConsumerWidget {
  const _ConversationStarter({
    required this.controller,
    required this.focusNode,
    required this.unreadCounts,
    required this.summaries,
    required this.onOpenConversation,
    required this.onRefresh,
    required this.onStartNewChat,
    required this.onAddFriend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Map<String, int> unreadCounts;
  final List<ConversationSummary> summaries;
  final ValueChanged<String> onOpenConversation;
  final VoidCallback onRefresh;
  final VoidCallback onStartNewChat;
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'Search chat history',
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Chat history',
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (summaries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'No matching chats yet.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          )
        else
          ...summaries.map((summary) {
            final userId = summary.conversationId;
            final displayNameAsync = ref.watch(userDisplayNameProvider(userId));
            final avatarBase64Async = ref.watch(
              userAvatarBase64Provider(userId),
            );
            final displayName = _displayNameOrFallback(
              userId,
              displayNameAsync.value,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: _ProfileAvatar(
                  userId: userId,
                  avatarBase64: avatarBase64Async.value,
                  radius: 18,
                ),
                title: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  summary.lastBody,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                trailing: Text(
                  _timeLabel(summary.lastAt),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                onTap: () {
                  onOpenConversation(userId);
                },
              ),
            );
          }),

        if (unreadCounts.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              Text(
                'Conversations with unread',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Refresh', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...unreadCounts.entries.map((e) {
            final userId = e.key;
            final displayNameAsync = ref.watch(userDisplayNameProvider(userId));
            final avatarBase64Async = ref.watch(
              userAvatarBase64Provider(userId),
            );
            final displayName = _displayNameOrFallback(
              userId,
              displayNameAsync.value,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: _ProfileAvatar(
                  userId: userId,
                  avatarBase64: avatarBase64Async.value,
                  radius: 18,
                ),
                title: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: _UnreadBadge(count: e.value),
                onTap: () {
                  controller.text = userId;
                  onOpenConversation(userId);
                },
              ),
            );
          }),
        ],
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.userId,
    required this.avatarBase64,
    required this.radius,
  });

  final String userId;
  final String? avatarBase64;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = userId.length >= 2
        ? userId.substring(0, 2).toUpperCase()
        : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.secondaryContainer,
      child: avatarBase64 == null
          ? Text(
              initials,
              style: TextStyle(
                color: cs.onSecondaryContainer,
                fontSize: radius * 0.45,
                fontWeight: FontWeight.w700,
              ),
            )
          : ClipOval(
              child: SizedBox.expand(
                child: Image.memory(
                  base64Decode(avatarBase64!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: cs.onSecondaryContainer,
                        fontSize: radius * 0.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
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
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Media preview
          if (selectedMediaBytes != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      selectedMediaBytes!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedMediaName ?? 'Image',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClearMedia,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attach
              _ComposerIconButton(
                icon: Icons.attach_file,
                tooltip: 'Attach image',
                onPressed: onPickMedia,
              ),
              // Stickers
              _ComposerIconButton(
                icon: Icons.emoji_emotions_outlined,
                tooltip: 'Stickers',
                onPressed: () async {
                  final selected = await showModalBottomSheet<Sticker>(
                    context: context,
                    backgroundColor: cs.surfaceContainerHighest,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
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
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Send
              InkWell(
                onTap: onSend,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ],
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

class _StickerPicker extends StatelessWidget {
  const _StickerPicker({required this.stickers});
  final List<Sticker> stickers;

  @override
  Widget build(BuildContext context) {
    if (stickers.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('No stickers yet.')),
      );
    }

    return SizedBox(
      height: 260,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Stickers',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: stickers.length,
              itemBuilder: (_, i) {
                final sticker = stickers[i];
                Uint8List bytes;
                try {
                  bytes = base64Decode(sticker.contentBase64);
                } catch (_) {
                  return const SizedBox.shrink();
                }
                return InkWell(
                  onTap: () => Navigator.of(context).pop(sticker),
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(bytes, fit: BoxFit.cover),
                  ),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.currentUserId,
    required this.currentUserAvatarBase64,
    required this.partnerAvatarBase64,
  });

  final LocalChatMessage message;
  final bool isMine;
  final String currentUserId;
  final String? currentUserAvatarBase64;
  final String? partnerAvatarBase64;

  static const double _kMaxBubbleHeight = 180;

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MessageDetailScreen(message: message, isMine: isMine),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bubbleColor = isMine ? cs.primary : cs.surfaceContainerHighest;
    final onBubble = isMine ? cs.onPrimary : cs.onSurface;

    final avatarId = isMine ? currentUserId : message.senderId;
    final avatarBase64 = isMine ? currentUserAvatarBase64 : partnerAvatarBase64;

    Widget bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.68,
        maxHeight: _kMaxBubbleHeight,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 26),
            child: Text(
              message.body,
              maxLines: 7,
              overflow: TextOverflow.fade,
              softWrap: true,
              textAlign: isMine ? TextAlign.right : TextAlign.left,
              style: TextStyle(color: onBubble, fontSize: 14),
            ),
          ),
          // Bottom gradient + timestamp row — always pinned to bottom.
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
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: Align(
                alignment: isMine
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Text(
                  _timeLabel(message.createdAt),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine
                        ? cs.onPrimary.withValues(alpha: .7)
                        : cs.onSurfaceVariant,
                  ),
                ),
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
            _MessageAvatar(userId: avatarId, avatarBase64: avatarBase64),
            const SizedBox(width: 6),
          ],
          bubble,
          if (isMine) ...[
            const SizedBox(width: 6),
            _MessageAvatar(userId: avatarId, avatarBase64: avatarBase64),
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

// —————————————————————————————————————————————————————
// Message detail screen
// —————————————————————————————————————————————————————

class _MessageDetailScreen extends StatelessWidget {
  const _MessageDetailScreen({required this.message, required this.isMine});

  final LocalChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final local = message.createdAt.toLocal();
    final dateStr =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(isMine ? 'Your message' : 'Message'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message.body));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  width: 200,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isMine
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                message.body,
                style: tt.bodyLarge?.copyWith(
                  color: isMine ? cs.onPrimaryContainer : cs.onSurface,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            if (!isMine) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      message.senderId,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.userId, required this.avatarBase64});

  final String userId;
  final String? avatarBase64;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = userId.length >= 2
        ? userId.substring(0, 2).toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 13,
      backgroundColor: cs.secondaryContainer,
      child: avatarBase64 == null
          ? Text(
              initials,
              style: TextStyle(
                color: cs.onSecondaryContainer,
                fontSize: 9,
                fontWeight: FontWeight.w700,
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
// Unread badge
// —————————————————————————————————————————————————————

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: cs.onError,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
