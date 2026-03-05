import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';
import '../../ui/tokens/colors/app_palette.dart';
import '../../ui/components/atoms/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../constants/planet_presets.dart';
import '../../models/friend_qr_payload.dart';
import '../../models/qr_login_payload.dart';
import '../../services/auth_service.dart';
import '../../state/app_controller.dart';
import '../../state/user_profile_controller.dart';
import 'device_login_qr_scanner_page.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final avatarBase64 = ref
        .watch(userAvatarBase64Provider(currentUserId))
        .value;
    final watchedUsername =
        ref.watch(userDisplayNameProvider(currentUserId)).value ?? currentUsername;
    final displayName = (watchedUsername ?? '').trim().isEmpty
        ? (currentUserId.length >= 8
              ? currentUserId.substring(0, 8)
              : currentUserId)
        : watchedUsername!.trim();
    final description = ref.watch(userDescriptionProvider(currentUserId)).value;
    final oneLineDescription = (description ?? '').trim();
    final planetLabel = _planetNameFromServerUrl(serverUrl);
    final myQrPayload = FriendQrPayload(
      userId: currentUserId,
      serverUrl: serverUrl,
    ).encode();
    final authService = AuthService();
    final isMobileDevice =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    Future<void> saveUsername() async {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) =>
            _UsernameEditDialog(initialValue: displayName),
      );

      if (result == null || result.isEmpty) {
        return;
      }

      final usernamePattern = RegExp(r'^[a-zA-Z0-9._ -]{3,32}$');
      if (!usernamePattern.hasMatch(result)) {
        if (!context.mounted) return;
        showAppToast(
          context,
          l10n.profileUsernameValidationError,
          variant: AppToastVariant.error,
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
        showAppToast(context, l10n.profileUsernameUpdated);
      } catch (_) {
        if (!context.mounted) return;
        showAppToast(
          context,
          l10n.profileUsernameUpdateFailed,
          variant: AppToastVariant.error,
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
        showAppToast(
          context,
          l10n.profileDescriptionWordLimitError,
          variant: AppToastVariant.error,
        );
        return;
      }

      await ref
          .read(userProfilePreferencesProvider)
          .writeDescription(
            currentUserId,
            normalized.isEmpty ? null : normalized,
          );
      ref.invalidate(userDescriptionProvider(currentUserId));

      if (!context.mounted) return;
      showAppToast(context, l10n.profileDescriptionUpdated);
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
        showAppToast(
          context,
          l10n.profileAvatarTooLarge,
          variant: AppToastVariant.error,
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
        showAppToast(
          context,
          l10n.profileAvatarUploadFailed,
          variant: AppToastVariant.error,
        );
        return;
      }

      if (!context.mounted) return;
      showAppToast(
        context,
        l10n.profileAvatarUpdated,
        duration: const Duration(seconds: 1),
      );
    }

    Future<void> scanDeviceLoginQr() async {
      final payload = await Navigator.of(context).push<QrLoginPayload>(
        MaterialPageRoute(builder: (_) => const DeviceLoginQrScannerPage()),
      );
      if (!context.mounted || payload == null) {
        return;
      }
      try {
        final freshToken =
            await ref
                .read(appControllerProvider.notifier)
                .ensureFreshAccessToken() ??
            accessToken;
        await authService.approveQrLoginSession(
          baseUrl: serverUrl,
          accessToken: freshToken,
          sessionId: payload.sessionId,
          secret: payload.secret,
        );
        if (!context.mounted) return;
        showAppToast(
          context,
          l10n.profileDeviceLoginApproved,
          duration: const Duration(milliseconds: 900),
        );
      } catch (_) {
        if (!context.mounted) return;
        showAppToast(
          context,
          l10n.profileDeviceLoginFailed,
          variant: AppToastVariant.error,
          duration: const Duration(milliseconds: 900),
        );
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    // warm muted avatar palette
    const palette = [
      AppPalette.avatarTone1,
      AppPalette.avatarTone2,
      AppPalette.avatarTone3,
      AppPalette.avatarTone4,
      AppPalette.avatarTone5,
      AppPalette.avatarTone6,
    ];
    final hash2 = currentUserId.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarToneColor = palette[hash2.abs() % palette.length];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.profileTitle,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: inkColor,
          ),
        ),
        iconTheme: IconThemeData(color: AppPalette.neutral500),
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
                      backgroundColor: avatarToneColor,
                      child: avatarBase64 == null
                          ? Text(
                              currentUserId.length >= 2
                                  ? currentUserId.substring(0, 2).toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                                color: AppPalette.white,
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
                    // planet label
                    Text(
                      planetLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppPalette.neutral500,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 6),
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
                        IconButton(
                          onPressed: saveUsername,
                          icon: const Icon(Icons.edit_outlined),
                          iconSize: 16,
                          color: AppPalette.neutral500,
                          tooltip: l10n.actionEdit,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // description row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            oneLineDescription.isEmpty
                                ? l10n.profileNoDescriptionYet
                                : oneLineDescription,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                              color: oneLineDescription.isEmpty
                                  ? AppPalette.neutral500
                                  : inkColor,
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: saveDescription,
                          icon: const Icon(Icons.edit_outlined),
                          iconSize: 16,
                          color: AppPalette.neutral500,
                          tooltip: l10n.actionEdit,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
                          constraints: const BoxConstraints(),
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
                        showAppToast(
                          context,
                          l10n.profileFriendLinkCopied,
                          duration: const Duration(milliseconds: 900),
                        );
                      },
                      child: Text(
                        l10n.profileCopyFriendLink,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppPalette.neutral500,
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
          Text(
            l10n.profileFriendQrTitle,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.8,
              color: AppPalette.neutral500,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: QrImageView(
              data: myQrPayload,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: AppPalette.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppPalette.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppPalette.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              l10n.profileFriendQrHint,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: AppPalette.neutral500,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: _CopyQrPayloadButton(
              payload: myQrPayload,
              ruleColor: ruleColor,
              textColor: AppPalette.neutral500,
            ),
          ),
          if (isMobileDevice) ...[
            const SizedBox(height: 28),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 16),
            Text(
              l10n.profileDeviceLoginSectionTitle,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 2.8,
                color: AppPalette.neutral500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: scanDeviceLoginQr,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: ruleColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 20,
                      color: AppPalette.neutral500,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.profileDeviceLoginAction,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: inkColor,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.profileDeviceLoginHint,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w300,
                              color: AppPalette.neutral500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppPalette.neutral500,
                    ),
                  ],
                ),
              ),
            ),
          ],
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

class _CopyQrPayloadButton extends StatefulWidget {
  const _CopyQrPayloadButton({
    required this.payload,
    required this.ruleColor,
    required this.textColor,
  });

  final String payload;
  final Color ruleColor;
  final Color textColor;

  @override
  State<_CopyQrPayloadButton> createState() => _CopyQrPayloadButtonState();
}

class _CopyQrPayloadButtonState extends State<_CopyQrPayloadButton> {
  Timer? _copiedResetTimer;
  bool _isCopied = false;

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  void _showCopiedState() {
    _copiedResetTimer?.cancel();
    setState(() => _isCopied = true);
    _copiedResetTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _isCopied = false);
    });
  }

  void _copyQrPayload() {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: widget.payload));
    _showCopiedState();
    showAppToast(
      context,
      l10n.profileQrPayloadCopied,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final foregroundColor = _isCopied
        ? AppPalette.success700
        : widget.textColor;

    return GestureDetector(
      onTap: _copyQrPayload,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isCopied ? Icons.check : Icons.copy_rounded,
              size: 14,
              color: foregroundColor,
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 12,
                color: foregroundColor,
                letterSpacing: 0.3,
                decoration: TextDecoration.underline,
                decorationColor: widget.ruleColor,
              ),
              child: Text(
                _isCopied
                    ? l10n.profileQrPayloadCopied
                    : l10n.profileCopyQrPayload,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    final l10n = AppLocalizations.of(context)!;
    final words = _wordCount(_ctrl.text);
    final isOverLimit = words > 100;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Minimal warm-neutral palette ────────────────────────────────────────

    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;
    final counterColor = isOverLimit
        ? AppPalette.danger700
        : AppPalette.neutral500;

    return Dialog(
      backgroundColor: bgColor,
      surfaceTintColor: AppPalette.transparent,
      shadowColor: AppPalette.black26,
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
              l10n.profileAboutYouLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.8,
                color: AppPalette.neutral500,
              ),
            ),
            const SizedBox(height: 10),

            // ── Heading ───────────────────────────────────────────────────
            Text(
              l10n.profileAboutYouTitle,
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
                hintText: l10n.profileDescriptionHint,
                hintStyle: TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: AppPalette.neutral500.withValues(alpha: 0.65),
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
                  borderSide: BorderSide(color: AppPalette.neutral500),
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
                    l10n.profileDescriptionExceeded,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.4,
                      color: AppPalette.danger700,
                    ),
                  ),
                const Spacer(),
                Text(
                  l10n.profileWordCount(words),
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
                      l10n.actionCancel,
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
                  onTap: isOverLimit
                      ? null
                      : () => Navigator.of(context).pop(_ctrl.text.trim()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      l10n.actionSave,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w500,
                        color: isOverLimit
                            ? AppPalette.neutral500.withValues(alpha: 0.35)
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
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    return Dialog(
      backgroundColor: bgColor,
      surfaceTintColor: AppPalette.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.profileUsernameDialogTitle,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.8,
                color: AppPalette.neutral500,
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
                hintText: l10n.profileUsernameHint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppPalette.neutral500.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w300,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppPalette.neutral500),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      l10n.actionCancel,
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
                  onTap: () => Navigator.of(context).pop(_ctrl.text.trim()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      l10n.actionSave,
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
