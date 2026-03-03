import 'dart:convert';

import 'package:flutter/material.dart';

enum ChatTargetProfileAction { startChat, addFriend }

class ChatTargetProfileScreen extends StatelessWidget {
  const ChatTargetProfileScreen({
    super.key,
    required this.displayName,
    required this.displayHandle,
    required this.avatarBase64,
  });

  final String displayName;
  final String displayHandle;
  final String? avatarBase64;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Target Profile')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              CircleAvatar(
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
              const SizedBox(height: 12),
              Text(
                displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                displayHandle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(ChatTargetProfileAction.addFriend),
                  child: const Text('Add friend'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
