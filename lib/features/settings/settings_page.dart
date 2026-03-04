import 'package:flutter/material.dart';
import '../../ui/tokens/colors/app_palette.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/realtime_event.dart';
import '../../services/server_health_service.dart';
import '../../state/app_controller.dart';
import '../../state/backup_controller.dart';
import '../../state/conversation_messages_controller.dart';
import '../../state/notification_controller.dart';
import '../../state/realtime_sync_controller.dart';
import '../../state/sticker_controller.dart';
import '../../state/theme_mode_controller.dart';
import '../../state/unread_counts_controller.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({
    super.key,
    required this.serverUrl,
    required this.planetInfo,
    required this.currentUserId,
    required this.activePartnerId,
    required this.onSignOut,
  });

  final String serverUrl;
  final PlanetInfo? planetInfo;
  final String currentUserId;
  final String? activePartnerId;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    final planetName = _planetNameFromData(planetInfo: planetInfo);
    final planetDescription = _planetDescriptionFromData(
      planetInfo: planetInfo,
    );

    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    final themeModes = [
      (ThemeMode.light, 'Light'),
      (ThemeMode.system, 'System'),
      (ThemeMode.dark, 'Dark'),
    ];

    Future<String?> resolveAccessToken() async {
      final fresh = await ref
          .read(appControllerProvider.notifier)
          .ensureFreshAccessToken();
      if (fresh != null && fresh.isNotEmpty) {
        return fresh;
      }
      final fallback = ref.read(appControllerProvider).value?.accessToken;
      if (fallback != null && fallback.isNotEmpty) {
        return fallback;
      }
      return null;
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            // ── My Planet ────────────────────────────────────────────────
            _SectionHeader(label: 'My Planet', ruleColor: ruleColor),
            _PlanetCard(
              planetName: planetName,
              planetDescription: planetDescription,
              stickerCount: stickers.length,
              memberCount: unreadCounts.keys.length,
              isConnected: isConnected,
              notifActive: notifActive,
              inkColor: inkColor,
              mutedColor: AppPalette.neutral500,
            ),

            const SizedBox(height: 32),

            // ── Appearance ───────────────────────────────────────────────
            _SectionHeader(label: 'Appearance', ruleColor: ruleColor),
            const SizedBox(height: 4),
            Text(
              'THEME',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.4,
                color: AppPalette.neutral500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final (mode, label) in themeModes) ...[
                  GestureDetector(
                    onTap: () =>
                        ref.read(themeModeProvider.notifier).setMode(mode),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: Column(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: themeMode == mode
                                  ? FontWeight.w500
                                  : FontWeight.w300,
                              color: themeMode == mode
                                  ? inkColor
                                  : AppPalette.neutral500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 1,
                            width: 24,
                            color: themeMode == mode
                                ? inkColor
                                : AppPalette.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 32),

            // ── Encrypted backups ─────────────────────────────────────────
            _SectionHeader(label: 'Encrypted Backups', ruleColor: ruleColor),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable backups',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: inkColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'End-to-end encrypted on planet server',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppPalette.neutral500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                _SettingsToggle(
                  value: backupState?.enabled ?? false,
                  activeColor: inkColor,
                  inactiveColor: AppPalette.neutral500,
                  trackColor: ruleColor,
                  onChanged: (v) => ref
                      .read(backupControllerProvider.notifier)
                      .setEnabled(v),
                ),
              ],
            ),
            if (backupState?.enabled == true) ...[
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: ruleColor),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 10,
                children: [
                  _BackupTextButton(
                    label: 'Create backup',
                    busy: backupState?.isBusy == true,
                    inkColor: inkColor,
                    mutedColor: AppPalette.neutral500,
                    onPressed: () async {
                      final token = await resolveAccessToken();
                      if (token == null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Missing access token for backup.'),
                          ),
                        );
                        return;
                      }
                      await ref
                          .read(backupControllerProvider.notifier)
                          .createBackup(
                            baseUrl: serverUrl,
                            accessToken: token,
                          );
                    },
                  ),
                  _BackupTextButton(
                    label: 'Restore',
                    busy: backupState?.isBusy == true,
                    inkColor: inkColor,
                    mutedColor: AppPalette.neutral500,
                    onPressed: () async {
                      final token = await resolveAccessToken();
                      if (token == null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Missing access token for restore.'),
                          ),
                        );
                        return;
                      }
                      await ref
                          .read(backupControllerProvider.notifier)
                          .restoreBackup(baseUrl: serverUrl, accessToken: token);
                      if (activePartnerId != null) {
                        ref.invalidate(
                          conversationMessagesProvider(activePartnerId!),
                        );
                      }
                    },
                  ),
                  _BackupTextButton(
                    label: 'Delete backup data',
                    busy: backupState?.isBusy == true,
                    inkColor: AppPalette.danger700,
                    mutedColor: AppPalette.neutral500,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => _ConfirmDialog(
                          title: 'Delete backup data',
                          message:
                              'This removes the encrypted backup file from this device.\nThis cannot be undone.',
                          confirmLabel: 'D E L E T E   B A C K U P',
                          isDark: isDark,
                        ),
                      );
                      if (confirmed != true) {
                        return;
                      }
                      final token = await resolveAccessToken();
                      if (token == null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Missing access token for backup delete.',
                            ),
                          ),
                        );
                        return;
                      }
                      await ref
                          .read(backupControllerProvider.notifier)
                          .deleteBackupData(
                            baseUrl: serverUrl,
                            accessToken: token,
                          );
                    },
                  ),
                ],
              ),
              if (backupState?.statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    backupState!.statusMessage!,
                    style: TextStyle(fontSize: 12, color: AppPalette.neutral500),
                  ),
                ),
            ],

            const SizedBox(height: 18),
            Divider(height: 1, thickness: 1, color: ruleColor),
            const SizedBox(height: 14),
            _SectionHeader(label: 'Local Data', ruleColor: ruleColor),
            Align(
              alignment: Alignment.centerLeft,
              child: _BackupTextButton(
                label: 'Delete all local chat data',
                busy: backupState?.isBusy == true,
                inkColor: AppPalette.danger700,
                mutedColor: AppPalette.neutral500,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => _ConfirmDialog(
                      title: 'Delete local chat data',
                      message:
                          'This deletes all chat history stored on this device.\nServer-side data is not changed.',
                      confirmLabel: 'D E L E T E   L O C A L   C H A T S',
                      isDark: isDark,
                    ),
                  );
                  if (confirmed != true) {
                    return;
                  }
                  await ref
                      .read(backupControllerProvider.notifier)
                      .deleteLocalChatData();
                  if (activePartnerId != null) {
                    ref.invalidate(conversationMessagesProvider(activePartnerId!));
                  }
                },
              ),
            ),

            const SizedBox(height: 48),
            Divider(height: 1, thickness: 1, color: ruleColor),
            const SizedBox(height: 20),

            // ── Sign out ──────────────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => _ConfirmDialog(
                      title: 'Sign out',
                      message:
                          'You will be signed out of this account.\nLocal messages remain on device.',
                      confirmLabel: 'S I G N   O U T',
                      isDark: isDark,
                    ),
                  );
                  if (confirmed == true) await onSignOut();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'sign out',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppPalette.danger700,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w300,
                    ),
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

String _planetNameFromData({required PlanetInfo? planetInfo}) {
  final remoteName = planetInfo?.instanceName?.trim();
  if (remoteName != null && remoteName.isNotEmpty) {
    return remoteName;
  }
  return 'Unknown planet';
}

String _planetDescriptionFromData({required PlanetInfo? planetInfo}) {
  final remoteDescription = planetInfo?.instanceDescription?.trim();
  if (remoteDescription != null && remoteDescription.isNotEmpty) {
    return remoteDescription;
  }
  return 'No planet description available yet.';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.ruleColor});
  final String label;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 2.8,
              fontWeight: FontWeight.w400,
              color: AppPalette.neutral500,
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 1, color: ruleColor),
        ],
      ),
    );
  }
}

class _BackupTextButton extends StatelessWidget {
  const _BackupTextButton({
    required this.label,
    required this.busy,
    required this.inkColor,
    required this.mutedColor,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final Color inkColor;
  final Color mutedColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: busy ? mutedColor.withValues(alpha: 0.4) : inkColor,
              letterSpacing: 0.2,
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: SizedBox(
                width: 60,
                height: 1,
                child: LinearProgressIndicator(minHeight: 1),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.value,
    required this.activeColor,
    required this.inactiveColor,
    required this.trackColor,
    required this.onChanged,
  });

  final bool value;
  final Color activeColor;
  final Color inactiveColor;
  final Color trackColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 52,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value
                ? activeColor.withValues(alpha: 0.12)
                : trackColor.withValues(alpha: 0.35),
            border: Border.all(
              color: value ? activeColor : inactiveColor.withValues(alpha: 0.7),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Align(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? activeColor : inactiveColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanetCard extends StatelessWidget {
  const _PlanetCard({
    required this.planetName,
    required this.planetDescription,
    required this.stickerCount,
    required this.memberCount,
    required this.isConnected,
    required this.notifActive,
    required this.inkColor,
    required this.mutedColor,
  });

  final String planetName;
  final String planetDescription;
  final int stickerCount;
  final int memberCount;
  final bool isConnected;
  final bool notifActive;
  final Color inkColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          planetName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w300,
            color: inkColor,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          planetDescription,
          style: TextStyle(
            fontSize: 12,
            color: mutedColor,
            letterSpacing: 0.2,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _InlineStatus(
              active: isConnected,
              label: isConnected ? 'online' : 'offline',
              mutedColor: mutedColor,
            ),
            const SizedBox(width: 20),
            _InlineStatus(
              active: notifActive,
              label: notifActive ? 'notifications on' : 'notifications off',
              mutedColor: mutedColor,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _TextStat(
              value: '$memberCount',
              label: 'residents',
              inkColor: inkColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(width: 28),
            _TextStat(
              value: '$stickerCount',
              label: 'stickers',
              inkColor: inkColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(width: 28),
            _TextStat(
              value: 'E2EE',
              label: 'encrypted',
              inkColor: inkColor,
              mutedColor: mutedColor,
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({
    required this.active,
    required this.label,
    required this.mutedColor,
  });
  final bool active;
  final String label;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final dotColor = active
        ? AppPalette.success700
        : mutedColor.withValues(alpha: 0.5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? AppPalette.success700 : mutedColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _TextStat extends StatelessWidget {
  const _TextStat({
    required this.value,
    required this.label,
    required this.inkColor,
    required this.mutedColor,
  });

  final String value;
  final String label;
  final Color inkColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w200,
            color: inkColor,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: mutedColor, letterSpacing: 0.3),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.isDark,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    return Dialog(
      backgroundColor: bgColor,
      surfaceTintColor: AppPalette.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w300,
                color: inkColor,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: AppPalette.neutral500,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            Divider(height: 1, thickness: 1, color: ruleColor),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      'cancel',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppPalette.neutral500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w500,
                        color: AppPalette.danger700,
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
  }
}
