import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';

import '../../models/local_chat_message.dart';
import '../../models/sticker.dart';
import '../../state/backup_controller.dart';
import '../../state/conversation_messages_controller.dart';
import '../../state/notification_controller.dart';
import '../../state/realtime_sync_controller.dart';
import '../../state/sticker_controller.dart';
import '../../state/unread_counts_controller.dart';

class ChatHomeScreen extends ConsumerStatefulWidget {
  const ChatHomeScreen({
    super.key,
    required this.serverUrl,
    required this.accessToken,
    required this.currentUserId,
    required this.onSignOut,
  });

  final String serverUrl;
  final String accessToken;
  final String currentUserId;
  final Future<void> Function() onSignOut;

  @override
  ConsumerState<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends ConsumerState<ChatHomeScreen> {
  final _imagePicker = ImagePicker();
  final _partnerController = TextEditingController();
  final _messageController = TextEditingController();
  String? _activePartnerId;
  bool _isTyping = false;
  Timer? _typingTimer;
  Uint8List? _selectedMediaBytes;
  String? _selectedMediaName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshUnreadCounts();
      await ref
          .read(stickerControllerProvider.notifier)
          .sync(baseUrl: widget.serverUrl, accessToken: widget.accessToken);
      await ref
          .read(notificationControllerProvider.notifier)
          .initialize(
            baseUrl: widget.serverUrl,
            accessToken: widget.accessToken,
          );
      await ref
          .read(realtimeSyncControllerProvider.notifier)
          .connect(
            baseUrl: widget.serverUrl,
            accessTokenProvider: () async => widget.accessToken,
            currentUserId: widget.currentUserId,
          );
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    ref.read(realtimeSyncControllerProvider.notifier).disconnect();
    _partnerController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _refreshUnreadCounts() {
    return ref
        .read(unreadCountsProvider.notifier)
        .refresh(baseUrl: widget.serverUrl, accessToken: widget.accessToken);
  }

  void _onComposerChanged(String value) {
    _typingTimer?.cancel();

    final typingNow = value.trim().isNotEmpty;
    if (typingNow != _isTyping) {
      setState(() {
        _isTyping = typingNow;
      });
    }

    if (typingNow) {
      _typingTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
          });
        }
      });
    }
  }

  Future<void> _pickMedia() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }
    final bytes = await image.readAsBytes();
    setState(() {
      _selectedMediaBytes = bytes;
      _selectedMediaName = image.name;
    });
  }

  void _clearMedia() {
    setState(() {
      _selectedMediaBytes = null;
      _selectedMediaName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stickers =
        ref.watch(stickerControllerProvider).value ?? const <Sticker>[];
    final backupAsync = ref.watch(backupControllerProvider);
    final backupState = backupAsync.value;
    final notificationState = ref.watch(notificationControllerProvider).value;
    final realtimeState = ref.watch(realtimeSyncControllerProvider).value;

    final unreadAsync = ref.watch(unreadCountsProvider);
    final unreadCounts = unreadAsync.value ?? const <String, int>{};
    final activeUnread = _activePartnerId == null
        ? 0
        : (unreadCounts[_activePartnerId!] ?? 0);
    final messagesAsync = _activePartnerId == null
        ? null
        : ref.watch(conversationMessagesProvider(_activePartnerId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Chats'),
        actions: [
          IconButton(
            onPressed: widget.onSignOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server: ${widget.serverUrl}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label:
                          'Realtime: ${realtimeState?.status.name ?? 'disconnected'}',
                    ),
                    _StatusChip(
                      label: notificationState?.initialized == true
                          ? 'Push: initialized'
                          : 'Push: pending',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _partnerController,
                        decoration: const InputDecoration(
                          hintText: 'Partner user UUID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final partnerId = _partnerController.text.trim();
                        if (partnerId.isEmpty) {
                          return;
                        }
                        setState(() {
                          _activePartnerId = partnerId;
                        });
                        await ref
                            .read(
                              conversationMessagesProvider(partnerId).notifier,
                            )
                            .syncLatest(
                              baseUrl: widget.serverUrl,
                              accessToken: widget.accessToken,
                            );
                        await ref
                            .read(
                              conversationMessagesProvider(partnerId).notifier,
                            )
                            .markRead(
                              baseUrl: widget.serverUrl,
                              accessToken: widget.accessToken,
                            );
                        ref
                            .read(unreadCountsProvider.notifier)
                            .clearForPartner(partnerId);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Open'),
                          if (unreadCounts[_partnerController.text.trim()] !=
                                  null &&
                              unreadCounts[_partnerController.text.trim()]! >
                                  0) ...[
                            const SizedBox(width: 8),
                            _UnreadBadge(
                              count:
                                  unreadCounts[_partnerController.text.trim()]!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _refreshUnreadCounts,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh unread'),
                  ),
                ),
                if (activeUnread > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Unread from active partner: $activeUnread',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: backupState?.enabled ?? false,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable encrypted backups'),
                  onChanged: (value) => ref
                      .read(backupControllerProvider.notifier)
                      .setEnabled(value),
                ),
                if (backupState?.enabled == true)
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: backupState?.isBusy == true
                            ? null
                            : () => ref
                                  .read(backupControllerProvider.notifier)
                                  .createBackup(),
                        child: const Text('Create backup'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: backupState?.isBusy == true
                            ? null
                            : () async {
                                await ref
                                    .read(backupControllerProvider.notifier)
                                    .restoreBackup();
                                if (_activePartnerId != null) {
                                  ref.invalidate(
                                    conversationMessagesProvider(
                                      _activePartnerId!,
                                    ),
                                  );
                                }
                              },
                        child: const Text('Restore backup'),
                      ),
                    ],
                  ),
                if (backupState?.statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      backupState!.statusMessage!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: messagesAsync == null
                ? const Center(
                    child: Text('Enter a partner UUID to load conversation.'),
                  )
                : messagesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Failed to load messages: $error',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    data: (messages) {
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text('No messages yet. Send one below.'),
                        );
                      }

                      return Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () async {
                                await ref
                                    .read(
                                      conversationMessagesProvider(
                                        _activePartnerId!,
                                      ).notifier,
                                    )
                                    .loadMore(
                                      baseUrl: widget.serverUrl,
                                      accessToken: widget.accessToken,
                                    );
                              },
                              child: const Text('Load older'),
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              reverse: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                return _LocalMessageTile(message: message);
                              },
                              separatorBuilder: (_, index) =>
                                  const SizedBox(height: 8),
                              itemCount: messages.length,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  if (_selectedMediaBytes != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _selectedMediaBytes!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedMediaName ?? 'Selected image',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: _clearMedia,
                            icon: const Icon(Icons.close),
                            tooltip: 'Remove media',
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _pickMedia,
                        icon: const Icon(Icons.attach_file),
                        tooltip: 'Attach image',
                      ),
                      IconButton(
                        onPressed: () async {
                          final selected = await showModalBottomSheet<Sticker>(
                            context: context,
                            builder: (context) {
                              if (stickers.isEmpty) {
                                return const SizedBox(
                                  height: 160,
                                  child: Center(
                                    child: Text('No cached stickers yet.'),
                                  ),
                                );
                              }

                              return GridView.builder(
                                padding: const EdgeInsets.all(12),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                itemCount: stickers.length,
                                itemBuilder: (context, index) {
                                  final sticker = stickers[index];
                                  Uint8List bytes;
                                  try {
                                    bytes = base64Decode(sticker.contentBase64);
                                  } catch (_) {
                                    return const SizedBox.shrink();
                                  }

                                  return InkWell(
                                    onTap: () =>
                                        Navigator.of(context).pop(sticker),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        bytes,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );

                          if (selected != null && _activePartnerId != null) {
                            await ref
                                .read(
                                  conversationMessagesProvider(
                                    _activePartnerId!,
                                  ).notifier,
                                )
                                .sendMessage(
                                  baseUrl: widget.serverUrl,
                                  accessToken: widget.accessToken,
                                  body:
                                      '[sticker:${selected.id}:${selected.name}]',
                                );
                          }
                        },
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        tooltip: 'Stickers',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          onChanged: _onComposerChanged,
                          decoration: const InputDecoration(
                            hintText: 'Type a message',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (_activePartnerId == null) {
                            return;
                          }

                          final text = _messageController.text.trim();
                          final mediaLabel = _selectedMediaName == null
                              ? ''
                              : '[media-preview:${_selectedMediaName!}]';
                          final content = [
                            text,
                            mediaLabel,
                          ].where((part) => part.isNotEmpty).join('\n');

                          if (content.isEmpty) {
                            return;
                          }

                          _messageController.clear();
                          setState(() {
                            _isTyping = false;
                          });
                          await ref
                              .read(
                                conversationMessagesProvider(
                                  _activePartnerId!,
                                ).notifier,
                              )
                              .sendMessage(
                                baseUrl: widget.serverUrl,
                                accessToken: widget.accessToken,
                                body: content,
                              );
                          _clearMedia();
                          await _refreshUnreadCounts();
                        },
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Typing…'),
            ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _LocalMessageTile extends StatelessWidget {
  const _LocalMessageTile({required this.message});

  final LocalChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.body),
          const SizedBox(height: 6),
          Text(
            message.createdAt.toLocal().toIso8601String(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
