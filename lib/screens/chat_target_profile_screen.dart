import 'dart:convert';

import 'package:flutter/material.dart';

enum ChatTargetProfileAction { startChat, addFriend, cancelFriend }

class ChatTargetProfileScreen extends StatelessWidget {
  const ChatTargetProfileScreen({
    super.key,
    required this.displayName,
    required this.displayHandle,
    required this.avatarBase64,
    this.isFriend = false,
    this.friendAddedAt,
    this.sentMessageCount,
    this.description,
    this.showActions = true,
  });

  final String displayName;
  final String displayHandle;
  final String? avatarBase64;
  final bool isFriend;
  final DateTime? friendAddedAt;
  final int? sentMessageCount;
  final String? description;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = displayName.trim().isEmpty ? 'Profile' : displayName.trim();
    final initials = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isFriend)
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(ChatTargetProfileAction.cancelFriend),
              child: const Text('Cancel friend'),
            ),
        ],
      ),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              const SizedBox(height: 24),
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: cs.secondaryContainer,
                  child: avatarBase64 == null
                      ? Text(
                          initials,
                          style: TextStyle(
                            color: cs.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                          ),
                        )
                      : ClipOval(
                          child: SizedBox.expand(
                            child: Image.memory(
                              base64Decode(avatarBase64!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Text(
                                initials,
                                style: TextStyle(
                                  color: cs.onSecondaryContainer,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _TargetProfileQuickAction(
                        icon: isFriend
                            ? Icons.how_to_reg_outlined
                            : Icons.person_add_alt_1_outlined,
                        label: isFriend ? 'Friend' : 'Add to friend',
                        onTap: isFriend
                            ? null
                            : () {
                                Navigator.of(
                                  context,
                                ).pop(ChatTargetProfileAction.addFriend);
                              },
                      ),
                    ),
                    Expanded(
                      child: _TargetProfileQuickAction(
                        icon: Icons.notifications_off_outlined,
                        label: 'Mute',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mute is not available yet'),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _TargetProfileQuickAction(
                        icon: Icons.block_outlined,
                        label: 'Block',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Block is not available yet'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (isFriend && friendAddedAt != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Friend since ${_friendSinceLabel(friendAddedAt!)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              if (isFriend && sentMessageCount != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Messages sent: $sentMessageCount',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (showActions) ...[
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(ChatTargetProfileAction.startChat),
                    child: const Text('Start chat'),
                  ),
                ),
              ],
              if ((description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description!.trim(),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _friendSinceLabel(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

class _TargetProfileQuickAction extends StatelessWidget {
  const _TargetProfileQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final enabled = onTap != null;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? cs.onSurfaceVariant : cs.outline),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(
                color: enabled ? cs.onSurfaceVariant : cs.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
