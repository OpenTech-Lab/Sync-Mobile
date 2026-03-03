import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'my_profile_screen.dart';
import '../state/unread_counts_controller.dart';
import '../state/user_profile_controller.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({
    super.key,
    required this.serverUrl,
    required this.accessToken,
    required this.currentUserId,
    required this.currentUsername,
    this.onOpenChat,
  });

  final String serverUrl;
  final String accessToken;
  final String currentUserId;
  final String? currentUsername;
  final ValueChanged<String>? onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final unreadCounts =
        ref.watch(unreadCountsProvider).value ?? const <String, int>{};
    final totalUnread = unreadCounts.values.fold(
      0,
      (sum, count) => sum + count,
    );
    final friendIds = unreadCounts.keys.toList();

    String shortId(String uuid) =>
        uuid.length >= 8 ? uuid.substring(0, 8) : uuid;
    String initials(String uuid) =>
        uuid.isEmpty ? '?' : uuid.substring(0, 2).toUpperCase();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _SectionLabel('My Profile'),
          _ProfileCard(
            serverUrl: serverUrl,
            accessToken: accessToken,
            currentUserId: currentUserId,
            currentUsername: currentUsername,
          ),
          const SizedBox(height: 20),
          if (totalUnread > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.mark_chat_unread_outlined,
                    size: 18,
                    color: cs.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$totalUnread unread ${totalUnread == 1 ? 'message' : 'messages'}',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          _SectionLabel('Friends (${friendIds.length})'),
          if (friendIds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 40,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No friends yet',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Text(
                      'Open Chats and start a conversation',
                      style: tt.labelSmall?.copyWith(color: cs.outlineVariant),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: friendIds.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 60,
                  color: cs.outlineVariant.withValues(alpha: .45),
                ),
                itemBuilder: (ctx, i) {
                  final id = friendIds[i];
                  final unread = unreadCounts[id] ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: _avatarColor(id, cs),
                      child: Text(
                        initials(id),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    title: Text(
                      shortId(id),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    subtitle: Text(
                      id,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$unread',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (unread > 0) const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(
                            Icons.copy_outlined,
                            size: 15,
                            color: cs.onSurfaceVariant,
                          ),
                          tooltip: 'Copy ID',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Friend ID copied'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                                width: 160,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    onTap: () => onOpenChat?.call(id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Color _avatarColor(String id, ColorScheme cs) {
    const palette = [
      Color(0xFF6366F1),
      Color(0xFF0EA5E9),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
    ];
    final hash = id.codeUnits.fold(0, (a, b) => a ^ b);
    return palette[hash.abs() % palette.length];
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: .45),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({
    required this.serverUrl,
    required this.accessToken,
    required this.currentUserId,
    required this.currentUsername,
  });

  final String serverUrl;
  final String accessToken;
  final String currentUserId;
  final String? currentUsername;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final avatarBase64 = ref
        .watch(userAvatarBase64Provider(currentUserId))
        .value;
    final displayName = (currentUsername ?? '').trim().isEmpty
        ? (currentUserId.length >= 8
              ? currentUserId.substring(0, 8)
              : currentUserId)
        : currentUsername!.trim();

    const palette = [
      Color(0xFF6366F1),
      Color(0xFF0EA5E9),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
    ];
    final hash = currentUserId.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarColor = palette[hash.abs() % palette.length];

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MyProfileScreen(
                  serverUrl: serverUrl,
                  accessToken: accessToken,
                  currentUserId: currentUserId,
                  currentUsername: currentUsername,
                ),
              ),
            );
            ref.invalidate(userAvatarBase64Provider(currentUserId));
            ref.invalidate(userDisplayNameProvider(currentUserId));
          },
          child: CircleAvatar(
            radius: 28,
            backgroundColor: avatarColor,
            child: avatarBase64 == null
                ? Text(
                    currentUserId.length >= 2
                        ? currentUserId.substring(0, 2).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  )
                : ClipOval(
                    child: SizedBox.expand(
                      child: Image.memory(
                        base64Decode(avatarBase64),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      currentUserId,
                      style: tt.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.copy_outlined,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      tooltip: 'Copy ID',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: currentUserId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Your ID copied'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            width: 160,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dedicated dialog widget — owns its TextEditingController lifecycle so that
// dispose() is never called while the exit animation still uses the TextField.
// ---------------------------------------------------------------------------
class _UsernameEditDialog extends StatefulWidget {
  const _UsernameEditDialog({required this.initialValue});
  final String initialValue;

  @override
  State<_UsernameEditDialog> createState() => _UsernameEditDialogState();
}

class _UsernameEditDialogState extends State<_UsernameEditDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit username'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Username (3-32, a-zA-Z0-9._-)',
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
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
