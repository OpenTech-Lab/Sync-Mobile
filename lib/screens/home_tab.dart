import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/realtime_event.dart';
import '../state/notification_controller.dart';
import '../state/realtime_sync_controller.dart';
import '../state/sticker_controller.dart';
import '../state/unread_counts_controller.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({
    super.key,
    required this.serverUrl,
    required this.currentUserId,
    this.onOpenChat,
  });

  final String serverUrl;
  final String currentUserId;
  /// Called when user taps a friend to open chat
  final ValueChanged<String>? onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final realtimeState = ref.watch(realtimeSyncControllerProvider).value;
    final notifState = ref.watch(notificationControllerProvider).value;
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ?? const <String, int>{};
    final stickers = ref.watch(stickerControllerProvider).value ?? [];

    final isConnected =
        realtimeState?.status == RealtimeConnectionStatus.connected;
    final totalUnread = unreadCounts.values.fold(0, (s, v) => s + v);

    // Friends = everyone we've exchanged messages with (keys of unread map)
    final friendIds = unreadCounts.keys.toList();

    // Derive a display short-ID (first 8 chars of UUID)
    String shortId(String uuid) =>
        uuid.length >= 8 ? uuid.substring(0, 8) : uuid;

    // Initials avatar from short id
    String initials(String uuid) =>
        uuid.isEmpty ? '?' : uuid.substring(0, 2).toUpperCase();

    // Parse host for display
    final host = Uri.tryParse(serverUrl)?.host ?? serverUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ── My Profile ──────────────────────────────────────────────
          _SectionLabel('My Profile'),
          _ProfileCard(
            currentUserId: currentUserId,
            isConnected: isConnected,
            notifActive: notifState?.initialized == true,
          ),
          const SizedBox(height: 20),

          // ── Planet Info ─────────────────────────────────────────────
          _SectionLabel('My Planet'),
          _PlanetCard(
            host: host,
            serverUrl: serverUrl,
            stickerCount: stickers.length,
            memberCount: friendIds.length,
          ),
          const SizedBox(height: 20),

          // ── Unread banner ───────────────────────────────────────────
          if (totalUnread > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.mark_chat_unread_outlined,
                      size: 18, color: cs.onPrimaryContainer),
                  const SizedBox(width: 10),
                  Text(
                    '$totalUnread unread ${totalUnread == 1 ? 'message' : 'messages'}',
                    style: tt.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Friends ─────────────────────────────────────────────────
          _SectionLabel('Friends (${friendIds.length})'),
          if (friendIds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline,
                        size: 40, color: cs.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text('No friends yet',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    Text('Open Chats and start a conversation',
                        style: tt.labelSmall
                            ?.copyWith(color: cs.outlineVariant)),
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
                separatorBuilder: (_, _) =>
                    Divider(height: 1, indent: 60, color: cs.outlineVariant),
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
                            color: Colors.white),
                      ),
                    ),
                    title: Text(
                      shortId(id),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace'),
                    ),
                    subtitle: Text(
                      id,
                      style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$unread',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onPrimary,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        if (unread > 0) const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(Icons.copy_outlined,
                              size: 15, color: cs.onSurfaceVariant),
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
      Color(0xFF6366F1), // indigo
      Color(0xFF0EA5E9), // sky
      Color(0xFF10B981), // emerald
      Color(0xFFF59E0B), // amber
      Color(0xFFEC4899), // pink
      Color(0xFF8B5CF6), // violet
    ];
    final hash = id.codeUnits.fold(0, (a, b) => a ^ b);
    return palette[hash.abs() % palette.length];
  }
}

// ── Section label ───────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

// ── My Profile card ─────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.currentUserId,
    required this.isConnected,
    required this.notifActive,
  });

  final String currentUserId;
  final bool isConnected;
  final bool notifActive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final short = currentUserId.length >= 8
        ? currentUserId.substring(0, 8)
        : currentUserId;

    // Avatar color derived from user ID
    const palette = [
      Color(0xFF6366F1),
      Color(0xFF0EA5E9),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
    ];
    final hash =
        currentUserId.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarColor = palette[hash.abs() % palette.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: avatarColor,
            child: Text(
              currentUserId.length >= 2
                  ? currentUserId.substring(0, 2).toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  short,
                  style: tt.titleSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentUserId,
                        style: tt.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.copy_outlined,
                            size: 13, color: cs.onSurfaceVariant),
                        tooltip: 'Copy ID',
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: currentUserId));
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
          // Status badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusDot(
                  active: isConnected,
                  label: isConnected ? 'Online' : 'Offline'),
              const SizedBox(height: 6),
              _StatusDot(
                  active: notifActive,
                  label: notifActive ? 'Notifs on' : 'Notifs off'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active, required this.label});
  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green.shade500 : Colors.grey.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Planet card ──────────────────────────────────────────────────────────────
class _PlanetCard extends StatelessWidget {
  const _PlanetCard({
    required this.host,
    required this.serverUrl,
    required this.stickerCount,
    required this.memberCount,
  });

  final String host;
  final String serverUrl;
  final int stickerCount;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.public, size: 22, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(host,
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(serverUrl,
                        style: tt.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stats row
          Row(
            children: [
              _PlanetStat(
                icon: Icons.people_outline,
                value: '$memberCount',
                label: 'Residents',
              ),
              const SizedBox(width: 12),
              _PlanetStat(
                icon: Icons.emoji_emotions_outlined,
                value: '$stickerCount',
                label: 'Stickers',
              ),
              const SizedBox(width: 12),
              _PlanetStat(
                icon: Icons.lock_outline,
                value: 'E2EE',
                label: 'Encrypted',
                highlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanetStat extends StatelessWidget {
  const _PlanetStat({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = highlight ? cs.primary : cs.onSurface;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: highlight ? cs.primaryContainer.withValues(alpha: .4) : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: highlight ? cs.primary.withValues(alpha: .3) : cs.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
