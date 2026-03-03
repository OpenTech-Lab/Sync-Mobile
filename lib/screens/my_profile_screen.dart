import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../constants/planet_presets.dart';
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
    final description = ref.watch(userDescriptionProvider(currentUserId)).value;
    final oneLineDescription = (description ?? '').trim();
    final planetLabel = _planetNameFromServerUrl(serverUrl);
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

    Future<void> saveDescription() async {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) =>
            _DescriptionEditDialog(initialValue: description ?? ''),
      );

      if (result == null) {
        return;
      }

      final normalized = result.trim();
      final words = _wordCount(normalized);
      if (words > 100) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Description must be 100 words or less')),
        );
        return;
      }

      await ref
          .read(userProfilePreferencesProvider)
          .writeDescription(currentUserId, normalized.isEmpty ? null : normalized);
      ref.invalidate(userDescriptionProvider(currentUserId));

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Description updated')));
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
                        const SizedBox(width: 6),
                        _PlanetBadge(label: planetLabel),
                        const SizedBox(width: 4),
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
                            tooltip: 'Copy friend link',
                            onPressed: () {
                              final link = _friendLink(
                                serverUrl: serverUrl,
                                userId: currentUserId,
                              );
                              Clipboard.setData(ClipboardData(text: link));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Friend link copied'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                  width: 180,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            oneLineDescription.isEmpty
                                ? 'No description yet'
                                : oneLineDescription,
                            style: tt.bodySmall?.copyWith(
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
                              Icons.edit_note_outlined,
                              size: 14,
                              color: cs.onSurfaceVariant,
                            ),
                            tooltip: 'Edit description',
                            onPressed: saveDescription,
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

class _DescriptionEditDialog extends StatefulWidget {
  const _DescriptionEditDialog({required this.initialValue});
  final String initialValue;

  @override
  State<_DescriptionEditDialog> createState() => _DescriptionEditDialogState();
}

class _DescriptionEditDialogState extends State<_DescriptionEditDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = _wordCount(_ctrl.text);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isOverLimit = words > 100;
    final isNearLimit = words > 80;

    final counterColor = isOverLimit
        ? cs.error
        : isNearLimit
            ? const Color(0xFFF59E0B)
            : cs.onSurfaceVariant;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: cs.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About you',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Let others know who you are',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.onSurfaceVariant,
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant.withOpacity(0.5)),

          // ── Text field ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  maxLines: 5,
                  style: tt.bodyMedium?.copyWith(height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Write something about yourself…',
                    hintStyle: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withOpacity(0.55),
                      height: 1.5,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.45),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: cs.outlineVariant,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.primary, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.error, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Word counter ───────────────────────────────────────────
                Row(
                  children: [
                    if (isOverLimit) ...[
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: cs.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Over the 100‑word limit',
                        style: tt.labelSmall?.copyWith(color: cs.error),
                      ),
                    ],
                    const Spacer(),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: (tt.labelSmall ?? const TextStyle()).copyWith(
                        color: counterColor,
                        fontWeight: isNearLimit
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      child: Text('$words / 100'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Actions ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isOverLimit
                        ? null
                        : () => Navigator.of(context).pop(_ctrl.text.trim()),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanetBadge extends StatelessWidget {
  const _PlanetBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

int _wordCount(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return 0;
  }
  return normalized.split(RegExp(r'\s+')).length;
}

String _planetNameFromServerUrl(String serverUrl) {
  final normalized = serverUrl.trim();
  final preset = officialPlanetPresets.firstWhere(
    (item) => item.url.toLowerCase() == normalized.toLowerCase(),
    orElse: () => const PlanetPreset(name: '', url: ''),
  );
  if (preset.name.isNotEmpty) {
    return preset.name;
  }
  final host = Uri.tryParse(normalized)?.host.trim() ?? '';
  if (host.isNotEmpty) {
    return host;
  }
  return normalized;
}

String _friendLink({required String serverUrl, required String userId}) {
  final normalized = serverUrl.trim().endsWith('/')
      ? serverUrl.trim().substring(0, serverUrl.trim().length - 1)
      : serverUrl.trim();
  return '$normalized/${userId.trim()}';
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
