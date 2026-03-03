import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/realtime_event.dart';
import '../state/backup_controller.dart';
import '../state/conversation_messages_controller.dart';
import '../state/notification_controller.dart';
import '../state/realtime_sync_controller.dart';
import '../state/sticker_controller.dart';
import '../state/theme_mode_controller.dart';
import '../state/unread_counts_controller.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({
    super.key,
    required this.serverUrl,
    required this.currentUserId,
    required this.activePartnerId,
    required this.onSignOut,
  });

  final String serverUrl;
  final String currentUserId;
  final String? activePartnerId;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final backupAsync = ref.watch(backupControllerProvider);
    final backupState = backupAsync.value;
    final stickers = ref.watch(stickerControllerProvider).value ?? const [];
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ?? const <String, int>{};
    final realtimeState = ref.watch(realtimeSyncControllerProvider).value;
    final notifState = ref.watch(notificationControllerProvider).value;
    final isConnected =
        realtimeState?.status == RealtimeConnectionStatus.connected;
    final notifActive = notifState?.initialized == true;
    final host = Uri.tryParse(serverUrl)?.host ?? serverUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SectionHeader(label: 'My Planet'),
          _PlanetCard(
            host: host,
            serverUrl: serverUrl,
            stickerCount: stickers.length,
            memberCount: unreadCounts.keys.length,
            isConnected: isConnected,
            notifActive: notifActive,
          ),
          const SizedBox(height: 20),
          _SectionHeader(label: 'Appearance'),
          Row(
            children: [
              Icon(
                Icons.brightness_6_outlined,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text('Theme', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined, size: 16),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined, size: 16),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined, size: 16),
                label: Text('Dark'),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).setMode(s.first),
            style: SegmentedButton.styleFrom(
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(label: 'Encrypted backups'),
          SwitchListTile(
            secondary: const Icon(Icons.backup_outlined),
            title: const Text('Enable backups'),
            subtitle: const Text('Locally encrypted using AES-GCM'),
            value: backupState?.enabled ?? false,
            onChanged: (v) =>
                ref.read(backupControllerProvider.notifier).setEnabled(v),
          ),
          if (backupState?.enabled == true) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _BackupButton(
                      label: 'Create backup',
                      icon: Icons.upload_outlined,
                      busy: backupState?.isBusy == true,
                      onPressed: () => ref
                          .read(backupControllerProvider.notifier)
                          .createBackup(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BackupButton(
                      label: 'Restore',
                      icon: Icons.download_outlined,
                      busy: backupState?.isBusy == true,
                      onPressed: () async {
                        await ref
                            .read(backupControllerProvider.notifier)
                            .restoreBackup();
                        if (activePartnerId != null) {
                          ref.invalidate(
                            conversationMessagesProvider(activePartnerId!),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (backupState?.statusMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                child: Text(
                  backupState!.statusMessage!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error.withValues(alpha: .5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text(
                      'You will be signed out of this account. '
                      'Local messages are kept on device.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.error,
                          foregroundColor: cs.onError,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await onSignOut();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
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
            color: cs.outlineVariant,
          ),
        ],
      ),
    );
  }
}

class _BackupButton extends StatelessWidget {
  const _BackupButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _PlanetCard extends StatelessWidget {
  const _PlanetCard({
    required this.host,
    required this.serverUrl,
    required this.stickerCount,
    required this.memberCount,
    required this.isConnected,
    required this.notifActive,
  });

  final String host;
  final String serverUrl;
  final int stickerCount;
  final int memberCount;
  final bool isConnected;
  final bool notifActive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.public, size: 22, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(host, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    serverUrl,
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatusDot(active: isConnected, label: isConnected ? 'Online' : 'Offline'),
            const SizedBox(width: 12),
            _StatusDot(active: notifActive, label: notifActive ? 'Notifs on' : 'Notifs off'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _PlanetStat(icon: Icons.people_outline, value: '$memberCount', label: 'Residents'),
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
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active, required this.label});
  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = active ? Colors.green.shade600 : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withValues(alpha: .12)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? Colors.green.withValues(alpha: .35)
              : cs.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
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
            color: highlight ? cs.primary.withValues(alpha: .3) : cs.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
            ),
            Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
