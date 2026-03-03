import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/friend_qr_payload.dart';
import '../state/app_controller.dart';
import '../state/user_profile_controller.dart';

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({
    super.key,
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
    final myQrPayload = FriendQrPayload(
      userId: currentUserId,
      serverUrl: serverUrl,
    ).encode();

    Future<void> saveUsername() async {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) =>
            _UsernameEditDialog(initialValue: displayName),
      );

      if (result == null || result.isEmpty) {
        return;
      }

      final usernamePattern = RegExp(r'^[a-zA-Z0-9._-]{3,32}$');
      if (!usernamePattern.hasMatch(result)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username must be 3-32 chars: a-zA-Z0-9._-'),
          ),
        );
        return;
      }

      try {
        final freshToken =
            await ref
                .read(appControllerProvider.notifier)
                .ensureFreshAccessToken() ??
            accessToken;
        final remote = ref.read(remoteUserProfileServiceProvider);
        final profile = await remote.updateMyProfile(
          baseUrl: serverUrl,
          accessToken: freshToken,
          username: result,
        );
        await ref
            .read(userProfilePreferencesProvider)
            .writeDisplayName(currentUserId, profile.username);
        ref.invalidate(userDisplayNameProvider(currentUserId));
        ref
            .read(appControllerProvider.notifier)
            .setCurrentUsername(profile.username);

        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Username updated')));
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update username')),
        );
      }
    }

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

    Future<void> editAvatar() async {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();
      if (bytes.length > 256 * 1024) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Avatar too large (max 256KB). Choose a smaller image.',
            ),
          ),
        );
        return;
      }

      try {
        final freshToken =
            await ref
                .read(appControllerProvider.notifier)
                .ensureFreshAccessToken() ??
            accessToken;
        final remote = ref.read(remoteUserProfileServiceProvider);
        final profile = await remote.updateMyProfile(
          baseUrl: serverUrl,
          accessToken: freshToken,
          avatarBase64: base64Encode(bytes),
        );
        await ref
            .read(userProfilePreferencesProvider)
            .writeAvatarBase64(currentUserId, profile.avatarBase64);
        await ref
            .read(userProfilePreferencesProvider)
            .writeDisplayName(currentUserId, profile.username);
        ref.invalidate(userAvatarBase64Provider(currentUserId));
        ref.invalidate(userDisplayNameProvider(currentUserId));
        ref
            .read(appControllerProvider.notifier)
            .setCurrentUsername(profile.username);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload avatar')),
        );
        return;
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar updated'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          width: 160,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(36),
                onTap: editAvatar,
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: avatarColor,
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (avatarBase64 == null)
                          Center(
                            child: Text(
                              currentUserId.length >= 2
                                  ? currentUserId.substring(0, 2).toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else
                          Image.memory(
                            base64Decode(avatarBase64),
                            fit: BoxFit.cover,
                          ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 20,
                            width: double.infinity,
                            alignment: Alignment.center,
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: .88,
                            ),
                            child: Text(
                              'Edit',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
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
                              Icons.edit_outlined,
                              size: 15,
                              color: cs.onSurfaceVariant,
                            ),
                            tooltip: 'Edit username',
                            onPressed: saveUsername,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
                              size: 14,
                              color: cs.onSurfaceVariant,
                            ),
                            tooltip: 'Copy ID',
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: currentUserId),
                              );
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
          ),
          const SizedBox(height: 20),
          Text(
            'My Friend QR',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: .45),
              ),
            ),
            child: Column(
              children: [
                Center(
                  child: QrImageView(
                    data: myQrPayload,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Contains your server URL and ID',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: myQrPayload));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('QR payload copied'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        width: 180,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Copy QR payload'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
