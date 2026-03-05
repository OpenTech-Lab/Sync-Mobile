import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';
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
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 75,
    );
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
    final l10n = AppLocalizations.of(context)!;
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
        title: Text(l10n.chatHomeTitle),
        actions: [
          IconButton(
            onPressed: () async {
              await widget.onSignOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            tooltip: l10n.settingsSignOut,
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
                  l10n.chatHomeServerLabel(widget.serverUrl),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: l10n.chatHomeRealtimeStatus(
                        realtimeState?.status.name ?? l10n.chatHomeDisconnected,
                      ),
                    ),
                    _StatusChip(
                      label: notificationState?.initialized == true
                          ? l10n.chatHomePushInitialized
                          : l10n.chatHomePushPending,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _partnerController,
                        decoration: InputDecoration(
                          hintText: l10n.chatHomePartnerHint,
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
                              currentUserId: widget.currentUserId,
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
                          Text(l10n.chatHomeOpenAction),
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
                    label: Text(l10n.chatHomeRefreshUnread),
                  ),
                ),
                if (activeUnread > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.chatHomeActiveUnread(activeUnread),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: backupState?.enabled ?? false,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingsEnableBackups),
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
                                  .createBackup(
                                    baseUrl: widget.serverUrl,
                                    accessToken: widget.accessToken,
                                  ),
                        child: Text(l10n.settingsCreateBackup),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: backupState?.isBusy == true
                            ? null
                            : () async {
                                await ref
                                    .read(backupControllerProvider.notifier)
                                    .restoreBackup(
                                      baseUrl: widget.serverUrl,
                                      accessToken: widget.accessToken,
                                    );
                                if (_activePartnerId != null) {
                                  ref.invalidate(
                                    conversationMessagesProvider(
                                      _activePartnerId!,
                                    ),
                                  );
                                }
                              },
                        child: Text(l10n.settingsRestore),
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
                ? Center(
                    child: Text(l10n.chatHomeEnterPartnerPrompt),
                  )
                : messagesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.chatHomeFailedToLoadMessages(error.toString()),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    data: (messages) {
                      if (messages.isEmpty) {
                        return Center(
                          child: Text(l10n.chatNoMessagesYet),
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
                                      currentUserId: widget.currentUserId,
                                    );
                              },
                              child: Text(l10n.chatHomeLoadOlder),
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
                              _selectedMediaName ?? l10n.chatHomeSelectedImage,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: _clearMedia,
                            icon: const Icon(Icons.close),
                            tooltip: l10n.chatHomeRemoveMediaTooltip,
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _pickMedia,
                        icon: const Icon(Icons.attach_file),
                        tooltip: l10n.chatAttachImageTooltip,
                      ),
                      IconButton(
                        onPressed: () async {
                          final selected = await showModalBottomSheet<Sticker>(
                            context: context,
                            builder: (context) =>
                                _GroupedStickerPicker(stickers: stickers),
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
                                  currentUserId: widget.currentUserId,
                                  body:
                                      '[sticker:${selected.id}:${selected.name}]',
                                );
                            await ref
                                .read(backupControllerProvider.notifier)
                                .maybeAutoBackup(
                                  baseUrl: widget.serverUrl,
                                  accessToken: widget.accessToken,
                                );
                          }
                        },
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        tooltip: l10n.chatStickersTooltip,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          onChanged: _onComposerChanged,
                          decoration: InputDecoration(
                            hintText: l10n.chatMessageHint,
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
                          final mediaBytes = _selectedMediaBytes;
                          final mediaToken = mediaBytes == null
                              ? ''
                              : '[media-data:${base64Encode(mediaBytes)}]';
                          final content = [
                            text,
                            mediaToken,
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
                                currentUserId: widget.currentUserId,
                                body: content,
                              );
                          await ref
                              .read(backupControllerProvider.notifier)
                              .maybeAutoBackup(
                                baseUrl: widget.serverUrl,
                                accessToken: widget.accessToken,
                              );
                          _clearMedia();
                          await _refreshUnreadCounts();
                        },
                        child: Text(l10n.actionSend),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isTyping)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(l10n.chatHomeTyping),
            ),
        ],
      ),
    );
  }
}

class _GroupedStickerPicker extends StatefulWidget {
  const _GroupedStickerPicker({required this.stickers});

  final List<Sticker> stickers;

  @override
  State<_GroupedStickerPicker> createState() => _GroupedStickerPickerState();
}

class _GroupedStickerPickerState extends State<_GroupedStickerPicker> {
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
        height: 160,
        child: Center(
          child: Text(l10n.chatNoStickersYet),
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
    final visibleStickers = grouped[selectedGroup] ?? const <Sticker>[];

    return SizedBox(
      height: 330,
      child: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: visibleStickers.length,
              itemBuilder: (context, index) {
                final sticker = visibleStickers[index];
                Uint8List bytes;
                try {
                  bytes = base64Decode(sticker.contentBase64);
                } catch (_) {
                  return const SizedBox.shrink();
                }

                return InkWell(
                  onTap: () => Navigator.of(context).pop(sticker),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                    ),
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
