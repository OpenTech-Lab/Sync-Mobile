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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const mujiPaper   = Color(0xFFFAF9F6);
    const mujiPaperDk = Color(0xFF1E1C19);
    const mujiInk     = Color(0xFF2C2A27);
    const mujiInkDk   = Color(0xFFE8E4DC);
    const mujiMuted   = Color(0xFF8A8680);
    const mujiRule    = Color(0xFFDDD8CF);
    const mujiRuleDk  = Color(0xFF3A3730);
    final bgColor   = isDark ? mujiPaperDk : mujiPaper;
    final inkColor  = isDark ? mujiInkDk   : mujiInk;
    final ruleColor = isDark ? mujiRuleDk  : mujiRule;

    // warm muted avatar palette
    const palette = [
      Color(0xFF8A8069), Color(0xFF7A9080), Color(0xFF9B7B6E),
      Color(0xFF7D8A74), Color(0xFF8E8278), Color(0xFF7B8A8A),
    ];
    final hash2 = currentUserId.codeUnits.fold(0, (a, b) => a ^ b);
    final mujiAvatarColor = palette[hash2.abs() % palette.length];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'profile',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: inkColor,
          ),
        ),
        iconTheme: IconThemeData(color: mujiMuted),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        children: [
          // ── avatar row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: editAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: mujiAvatarColor,
                      child: avatarBase64 == null
                          ? Text(
                              currentUserId.length >= 2
                                  ? currentUserId.substring(0, 2).toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
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
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // username row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w300,
                              color: inkColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: saveUsername,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 2, 0, 2),
                            child: Text(
                              'edit',
                              style: TextStyle(
                                fontSize: 11,
                                color: mujiMuted,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // planet label
                    Text(
                      planetLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: mujiMuted,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // description row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            oneLineDescription.isEmpty
                                ? 'no description yet'
                                : oneLineDescription,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                              color: oneLineDescription.isEmpty
                                  ? mujiMuted
                                  : inkColor,
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: saveDescription,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 2, 0, 2),
                            child: Text(
                              'edit',
                              style: TextStyle(
                                fontSize: 11,
                                color: mujiMuted,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // copy friend link
                    GestureDetector(
                      onTap: () {
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
                      child: Text(
                        'copy friend link',
                        style: TextStyle(
                          fontSize: 11,
                          color: mujiMuted,
                          letterSpacing: 0.3,
                          decoration: TextDecoration.underline,
                          decorationColor: ruleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),
          Divider(height: 1, color: ruleColor),
          const SizedBox(height: 16),

          // ── QR section ──
          const Text(
            'FRIEND QR',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.8,
              color: mujiMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: QrImageView(
              data: myQrPayload,
              version: QrVersions.auto,
              size: 200,
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
          const SizedBox(height: 16),
          Center(
            child: Text(
              'contains your server url and id',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: mujiMuted,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: () {
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
              child: Text(
                'copy qr payload',
                style: TextStyle(
                  fontSize: 12,
                  color: mujiMuted,
                  letterSpacing: 0.3,
                  decoration: TextDecoration.underline,
                  decorationColor: ruleColor,
                ),
              ),
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
    final isOverLimit = words > 100;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Muji warm-neutral palette ────────────────────────────────────────
    const mujiPaper   = Color(0xFFFAF9F6);
    const mujiPaperDk = Color(0xFF1E1C19);
    const mujiInk     = Color(0xFF2C2A27);
    const mujiInkDk   = Color(0xFFE8E4DC);
    const mujiMuted   = Color(0xFF8A8680);
    const mujiRule    = Color(0xFFDDD8CF);
    const mujiRuleDk  = Color(0xFF3A3730);
    const mujiRed     = Color(0xFF9B3A2A);

    final bgColor      = isDark ? mujiPaperDk : mujiPaper;
    final inkColor     = isDark ? mujiInkDk   : mujiInk;
    final ruleColor    = isDark ? mujiRuleDk  : mujiRule;
    final counterColor = isOverLimit ? mujiRed : mujiMuted;

    return Dialog(
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Eyebrow label ─────────────────────────────────────────────
            Text(
              'ABOUT YOU',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.8,
                color: mujiMuted,
              ),
            ),
            const SizedBox(height: 10),

            // ── Heading ───────────────────────────────────────────────────
            Text(
              'A few words about yourself',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                height: 1.4,
                color: inkColor,
              ),
            ),
            const SizedBox(height: 28),

            // ── Text field (underline only) ───────────────────────────────
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 5,
              style: TextStyle(
                fontSize: 14,
                height: 1.8,
                color: inkColor,
                fontWeight: FontWeight.w300,
              ),
              decoration: InputDecoration(
                hintText: 'What would you like others to know…',
                hintStyle: TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: mujiMuted.withOpacity(0.65),
                  fontWeight: FontWeight.w300,
                ),
                filled: false,
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: mujiMuted),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // ── Word counter ──────────────────────────────────────────────
            Row(
              children: [
                if (isOverLimit)
                  Text(
                    'exceeded 100-word limit',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.4,
                      color: mujiRed,
                    ),
                  ),
                const Spacer(),
                Text(
                  '$words / 100',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: counterColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            Divider(height: 1, thickness: 1, color: ruleColor),
            const SizedBox(height: 20),

            // ── Actions (text only, right-aligned) ────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      'cancel',
                      style: TextStyle(
                        fontSize: 13,
                        color: mujiMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                GestureDetector(
                  onTap: isOverLimit
                      ? null
                      : () => Navigator.of(context).pop(_ctrl.text.trim()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      'S A V E',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w500,
                        color: isOverLimit
                            ? mujiMuted.withOpacity(0.35)
                            : inkColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const mujiPaper   = Color(0xFFFAF9F6);
    const mujiPaperDk = Color(0xFF1E1C19);
    const mujiInk     = Color(0xFF2C2A27);
    const mujiInkDk   = Color(0xFFE8E4DC);
    const mujiMuted   = Color(0xFF8A8680);
    const mujiRule    = Color(0xFFDDD8CF);
    const mujiRuleDk  = Color(0xFF3A3730);
    final bgColor   = isDark ? mujiPaperDk : mujiPaper;
    final inkColor  = isDark ? mujiInkDk   : mujiInk;
    final ruleColor = isDark ? mujiRuleDk  : mujiRule;

    return Dialog(
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'USERNAME',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.8,
                color: mujiMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w300,
                color: inkColor,
              ),
              decoration: InputDecoration(
                hintText: '3–32 chars, a-zA-Z0-9._-',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: mujiMuted.withOpacity(0.55),
                  fontWeight: FontWeight.w300,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: mujiMuted),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
            ),
            const SizedBox(height: 28),
            Divider(height: 1, thickness: 1, color: ruleColor),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      'cancel',
                      style: TextStyle(
                        fontSize: 13,
                        color: mujiMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pop(_ctrl.text.trim()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    child: Text(
                      'S A V E',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w500,
                        color: inkColor,
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
