import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';

import '../models/local_chat_message.dart';
import '../models/sticker.dart';
import '../services/local_chat_repository.dart';
import '../state/conversation_messages_controller.dart';
import '../state/sticker_controller.dart';
import '../state/unread_counts_controller.dart';

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

  @override
  void initState() {
    super.initState();
    _partnerController.addListener(_onSearchChanged);
    if (widget.initialPartnerId != null && widget.initialPartnerId!.isNotEmpty) {
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
    final image =
        await _imagePicker.pickImage(source: ImageSource.gallery);
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

  Future<void> _openPartner(String partnerId) async {
    setState(() => _activePartnerId = partnerId);
    _partnerController.text = partnerId;
    widget.onPartnerChanged(partnerId);
    await ref
        .read(conversationMessagesProvider(partnerId).notifier)
        .syncLatest(
          baseUrl: widget.serverUrl,
          accessToken: widget.accessToken,
        );
    await ref
        .read(conversationMessagesProvider(partnerId).notifier)
        .markRead(
          baseUrl: widget.serverUrl,
          accessToken: widget.accessToken,
        );
    ref.read(unreadCountsProvider.notifier).clearForPartner(partnerId);
    ref.invalidate(conversationSummariesProvider);
  }

  Future<void> _startNewChat() async {
    final partnerController = TextEditingController();
    final partnerId = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Start new chat'),
          content: TextField(
            controller: partnerController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Friend user UUID',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(partnerController.text.trim()),
              child: const Text('Start'),
            ),
          ],
        );
      },
    );
    partnerController.dispose();

    if (!mounted || partnerId == null || partnerId.isEmpty) {
      return;
    }

    await _openPartner(partnerId);
  }

  Future<void> _showAddFriendDialog() async {
    final friendController = TextEditingController();
    final friendId = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add friend'),
          content: TextField(
            controller: friendController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Friend user UUID',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(friendController.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    friendController.dispose();

    if (!mounted || friendId == null || friendId.isEmpty) {
      return;
    }

    await _openPartner(friendId);
  }

  Future<void> _sendMessage() async {
    if (_activePartnerId == null) return;
    final text = _messageController.text.trim();
    final mediaLabel = _selectedMediaName == null
        ? ''
        : '[media-preview:${_selectedMediaName!}]';
    final content =
        [text, mediaLabel].where((p) => p.isNotEmpty).join('\n');
    if (content.isEmpty) return;

    _messageController.clear();
    setState(() => _isTyping = false);

    await ref
        .read(conversationMessagesProvider(_activePartnerId!).notifier)
        .sendMessage(
          baseUrl: widget.serverUrl,
          accessToken: widget.accessToken,
          body: content,
        );
    _clearMedia();
    await ref.read(unreadCountsProvider.notifier).refresh(
          baseUrl: widget.serverUrl,
          accessToken: widget.accessToken,
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stickers =
        ref.watch(stickerControllerProvider).value ?? const <Sticker>[];
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ?? const <String, int>{};
    final conversationSummaries =
      ref.watch(conversationSummariesProvider).value ??
        const <ConversationSummary>[];
    final searchQuery = _partnerController.text.trim().toLowerCase();
    final filteredSummaries = searchQuery.isEmpty
      ? conversationSummaries
      : conversationSummaries.where((summary) {
        return summary.conversationId.toLowerCase().contains(searchQuery) ||
          summary.lastBody.toLowerCase().contains(searchQuery);
        }).toList(growable: false);
    final activeUnread = _activePartnerId == null
        ? 0
        : (unreadCounts[_activePartnerId!] ?? 0);
    final messagesAsync = _activePartnerId == null
        ? null
        : ref.watch(conversationMessagesProvider(_activePartnerId!));

    return Scaffold(
      appBar: AppBar(
        title: _activePartnerId == null
            ? const Text('Chats')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Conversation',
                      style: TextStyle(fontSize: 16)),
                  Text(
                    _activePartnerId!,
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
                  case _ChatQuickAction.addFriend:
                    _showAddFriendDialog();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_ChatQuickAction>(
                  value: _ChatQuickAction.newChat,
                  child: Text('Start new chat'),
                ),
                PopupMenuItem<_ChatQuickAction>(
                  value: _ChatQuickAction.addFriend,
                  child: Text('Add friend'),
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
              onRefresh: () => ref
                  .read(unreadCountsProvider.notifier)
                  .refresh(
                    baseUrl: widget.serverUrl,
                    accessToken: widget.accessToken,
                  ),
              onStartNewChat: _startNewChat,
              onAddFriend: _showAddFriendDialog,
            )
          : Column(
              children: [
                // Load older bar
                Material(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  child: InkWell(
                    onTap: () => ref
                        .read(
                          conversationMessagesProvider(_activePartnerId!)
                              .notifier,
                        )
                        .loadMore(
                          baseUrl: widget.serverUrl,
                          accessToken: widget.accessToken,
                        ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.expand_less,
                              size: 16, color: cs.primary),
                          const SizedBox(width: 4),
                          Text('Load older',
                              style: TextStyle(
                                  fontSize: 12, color: cs.primary)),
                        ],
                      ),
                    ),
                  ),
                ),

                // Messages list
                Expanded(
                  child: messagesAsync == null
                      ? const Center(
                          child: CircularProgressIndicator())
                      : messagesAsync.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (err, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('$err',
                                  textAlign: TextAlign.center),
                            ),
                          ),
                          data: (messages) => messages.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                          Icons
                                              .chat_bubble_outline,
                                          size: 48,
                                          color: cs.outlineVariant),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No messages yet.\nSay hello!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color:
                                                cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  reverse: true,
                                  controller:
                                      _messageScrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 8, 12, 8),
                                  itemCount: messages.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (ctx, i) =>
                                      _MessageBubble(
                                    message: messages[i],
                                    isMine: messages[i].senderId ==
                                        widget.currentUserId,
                                  ),
                                ),
                        ),
                ),

                // Typing indicator
                if (_isTyping)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Typing…',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontStyle: FontStyle.italic),
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
                      await ref
                          .read(
                            conversationMessagesProvider(
                                    _activePartnerId!)
                                .notifier,
                          )
                          .sendMessage(
                            baseUrl: widget.serverUrl,
                            accessToken: widget.accessToken,
                            body:
                                '[sticker:${sticker.id}:${sticker.name}]',
                          );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

enum _ChatQuickAction { newChat, addFriend }

// —————————————————————————————————————————————————————
// Conversation starter (empty state)
// —————————————————————————————————————————————————————

class _ConversationStarter extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        Text('Chat history',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
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
          ...summaries.map(
            (summary) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.secondaryContainer,
                  radius: 18,
                  child: Icon(Icons.chat_bubble_outline,
                      size: 16, color: cs.onSecondaryContainer),
                ),
                title: Text(
                  summary.conversationId,
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
                  onOpenConversation(summary.conversationId);
                },
              ),
            ),
          ),

        if (unreadCounts.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              Text('Conversations with unread',
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
              const Spacer(),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Refresh',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...unreadCounts.entries.map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primary,
                  radius: 18,
                  child: Icon(Icons.person,
                      size: 16, color: cs.onPrimary),
                ),
                title: Text(
                  e.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: _UnreadBadge(count: e.value),
                onTap: () {
                  controller.text = e.key;
                  onOpenConversation(e.key);
                },
              ),
            ),
          ),
        ],
      ],
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
                  final selected =
                      await showModalBottomSheet<Sticker>(
                    context: context,
                    backgroundColor:
                        cs.surfaceContainerHighest,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                    builder: (_) => _StickerPicker(
                        stickers: stickers),
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
                  textCapitalization:
                      TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
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
                  child: Icon(Icons.send_rounded,
                      size: 20, color: cs.onPrimary),
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
              child: Text('Stickers',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
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
                  onTap: () =>
                      Navigator.of(context).pop(sticker),
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
  const _MessageBubble(
      {required this.message, required this.isMine});

  final LocalChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(
                color: isMine ? cs.onPrimary : cs.onSurface,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _timeLabel(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMine
                    ? cs.onPrimary.withValues(alpha: .7)
                    : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
            fontWeight: FontWeight.w700),
      ),
    );
  }
}
