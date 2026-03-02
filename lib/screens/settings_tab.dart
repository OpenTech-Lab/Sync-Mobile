import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/backup_controller.dart';
import '../state/conversation_messages_controller.dart';

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
    final backupAsync = ref.watch(backupControllerProvider);
    final backupState = backupAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
              // — Account section
              _SectionHeader(label: 'Account'),
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'User ID',
                subtitle: currentUserId,
                mono: true,
                canCopy: true,
              ),
              _SettingsTile(
                icon: Icons.dns_outlined,
                title: 'Server',
                subtitle: serverUrl,
              ),
              const SizedBox(height: 20),

              // — Backup section
              _SectionHeader(label: 'Encrypted backups'),
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      secondary: const Icon(Icons.backup_outlined),
                      title: const Text('Enable backups'),
                      subtitle: const Text(
                          'Locally encrypted using AES-GCM'),
                      value: backupState?.enabled ?? false,
                      onChanged: (v) => ref
                          .read(backupControllerProvider.notifier)
                          .setEnabled(v),
                    ),
                    if (backupState?.enabled == true) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                                      conversationMessagesProvider(
                                          activePartnerId!),
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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Text(
                            backupState!.statusMessage!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // — Sign out
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
                  onPressed: onSignOut,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.mono = false,
    this.canCopy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool mono;
  final bool canCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon, size: 20, color: cs.onSurfaceVariant),
        title: Text(title, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            fontFamily: mono ? 'monospace' : null,
            color: cs.onSurfaceVariant,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: canCopy
            ? IconButton(
                icon: Icon(Icons.copy_outlined,
                    size: 16, color: cs.onSurfaceVariant),
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: subtitle));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      width: 180,
                    ),
                  );
                },
              )
            : null,
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
