import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../ui/tokens/colors/app_palette.dart';
import '../../ui/components/atoms/outline_action_button.dart';
import '../../ui/components/atoms/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../models/realtime_event.dart';
import '../../services/server_health_service.dart';
import '../../services/chat_ui_preferences.dart';
import '../../state/app_controller.dart';
import '../../state/backup_controller.dart';
import '../../state/conversation_messages_controller.dart';
import '../../state/notification_controller.dart';
import '../../state/realtime_sync_controller.dart';
import '../../state/sticker_controller.dart';
import '../../state/typing_style_mode_controller.dart';
import '../../state/theme_mode_controller.dart';
import '../../state/unread_counts_controller.dart';
import '../../state/user_profile_controller.dart';
import '../../ui/components/molecules/language_picker.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({
    super.key,
    required this.serverUrl,
    required this.planetInfo,
    required this.currentUserId,
    required this.activePartnerId,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final String serverUrl;
  final PlanetInfo? planetInfo;
  final String currentUserId;
  final String? activePartnerId;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final backupAsync = ref.watch(backupControllerProvider);
    final backupState = backupAsync.value;
    final stickers = ref.watch(stickerControllerProvider).value ?? const [];
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ?? const <String, int>{};
    final realtimeState = ref.watch(realtimeSyncControllerProvider).value;
    final notifState = ref.watch(notificationControllerProvider).value;
    final typingStyleModeEnabled =
        ref.watch(typingStyleModeControllerProvider).value ?? false;
    final typingStyleSpeedMs =
        ref.watch(typingStyleSpeedControllerProvider).value ??
        ChatUiPreferences.defaultTypingStyleSpeedMs;
    final isConnected =
        realtimeState?.status == RealtimeConnectionStatus.connected;
    final notifActive = notifState?.initialized == true;
    final planetName = _planetNameFromData(planetInfo: planetInfo, l10n: l10n);
    final planetDescription = _planetDescriptionFromData(
      planetInfo: planetInfo,
      l10n: l10n,
    );
    final serverCreatedDate = _serverCreatedDateFromData(planetInfo: planetInfo);

    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    final themeModes = [
      (ThemeMode.light, l10n.themeLight),
      (ThemeMode.system, l10n.themeSystem),
      (ThemeMode.dark, l10n.themeDark),
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
            _SectionHeader(label: l10n.settingsMyPlanet, ruleColor: ruleColor),
            _PlanetCard(
              planetName: planetName,
              planetDescription: planetDescription,
              stickerCount: stickers.length,
              memberCount: unreadCounts.keys.length,
              isConnected: isConnected,
              notifActive: notifActive,
              serverCreatedDate: serverCreatedDate,
              inkColor: inkColor,
              mutedColor: AppPalette.neutral500,
            ),

            const SizedBox(height: 32),

            // ── Appearance ───────────────────────────────────────────────
            _SectionHeader(
              label: l10n.settingsAppearance,
              ruleColor: ruleColor,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.settingsTheme,
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
            const SizedBox(height: 14),
            Text(
              l10n.languageLabel,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.4,
                color: AppPalette.neutral500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: LanguagePicker(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsTypingStyleMode,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: inkColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.settingsTypingStyleModeHint,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppPalette.neutral500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                _SettingsToggle(
                  value: typingStyleModeEnabled,
                  activeColor: inkColor,
                  inactiveColor: AppPalette.neutral500,
                  trackColor: ruleColor,
                  onChanged: (v) => ref
                      .read(typingStyleModeControllerProvider.notifier)
                      .setEnabled(v),
                ),
              ],
            ),
            if (typingStyleModeEnabled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    l10n.settingsTypingStyleSpeed,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.neutral500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l10n.settingsTypingStyleSpeedValue(typingStyleSpeedMs),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.neutral500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: inkColor,
                  inactiveTrackColor: ruleColor,
                  thumbColor: inkColor,
                  overlayColor: inkColor.withValues(alpha: 0.12),
                  trackHeight: 2,
                ),
                child: Slider(
                  min: ChatUiPreferences.minTypingStyleSpeedMs.toDouble(),
                  max: ChatUiPreferences.maxTypingStyleSpeedMs.toDouble(),
                  divisions:
                      ChatUiPreferences.maxTypingStyleSpeedMs -
                      ChatUiPreferences.minTypingStyleSpeedMs,
                  value: typingStyleSpeedMs.toDouble().clamp(
                    ChatUiPreferences.minTypingStyleSpeedMs.toDouble(),
                    ChatUiPreferences.maxTypingStyleSpeedMs.toDouble(),
                  ),
                  onChanged: (value) => ref
                      .read(typingStyleSpeedControllerProvider.notifier)
                      .setSpeedMs(value.round()),
                ),
              ),
              Text(
                l10n.settingsTypingStyleSpeedHint,
                style: TextStyle(
                  fontSize: 11,
                  color: AppPalette.neutral500,
                  letterSpacing: 0.2,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Encrypted backups ─────────────────────────────────────────
            _SectionHeader(
              label: l10n.settingsEncryptedBackups,
              ruleColor: ruleColor,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsEnableBackups,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: inkColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.settingsBackupSubtitle,
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
                  onChanged: (v) =>
                      ref.read(backupControllerProvider.notifier).setEnabled(v),
                ),
              ],
            ),
            if (backupState?.enabled == true) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlineActionButton(
                    label: l10n.settingsCreateBackup,
                    borderColor: inkColor,
                    textColor: inkColor,
                    disabled: backupState?.isBusy == true,
                    onTap: () async {
                      final token = await resolveAccessToken();
                      if (token == null) {
                        if (!context.mounted) return;
                        showAppToast(
                          context,
                          l10n.settingsMissingAccessTokenBackup,
                          variant: AppToastVariant.error,
                        );
                        return;
                      }
                      await ref
                          .read(backupControllerProvider.notifier)
                          .createBackup(baseUrl: serverUrl, accessToken: token);
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlineActionButton(
                    label: l10n.settingsRestore,
                    borderColor: inkColor,
                    textColor: inkColor,
                    disabled: backupState?.isBusy == true,
                    onTap: () async {
                      final token = await resolveAccessToken();
                      if (token == null) {
                        if (!context.mounted) return;
                        showAppToast(
                          context,
                          l10n.settingsMissingAccessTokenRestore,
                          variant: AppToastVariant.error,
                        );
                        return;
                      }
                      await ref
                          .read(backupControllerProvider.notifier)
                          .restoreBackup(
                            baseUrl: serverUrl,
                            accessToken: token,
                          );
                      if (activePartnerId != null) {
                        ref.invalidate(
                          conversationMessagesProvider(activePartnerId!),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlineActionButton(
                    label: l10n.settingsDeleteBackupData,
                    borderColor: AppPalette.danger700.withValues(alpha: isDark ? 0.55 : 0.45),
                    textColor: AppPalette.danger700,
                    variant: OutlineActionVariant.danger,
                    disabled: backupState?.isBusy == true,
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => _ConfirmDialog(
                          title: l10n.settingsDeleteBackupTitle,
                          message: l10n.settingsDeleteBackupMessage,
                          confirmLabel: l10n.settingsDeleteBackupConfirm,
                          isDark: isDark,
                        ),
                      );
                      if (confirmed != true) {
                        return;
                      }
                      final token = await resolveAccessToken();
                      if (token == null) {
                        if (!context.mounted) return;
                        showAppToast(
                          context,
                          l10n.settingsMissingAccessTokenBackupDelete,
                          variant: AppToastVariant.error,
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
              const SizedBox(height: 10),
              Text(
                l10n.settingsAutoBackupSchedule(
                  backupState?.autoBackupMessageThreshold ?? 20,
                ),
                style: TextStyle(
                  fontSize: 11,
                  color: AppPalette.neutral500,
                  letterSpacing: 0.15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    l10n.settingsAutoBackupThreshold,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.neutral500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: (backupState?.isBusy == true)
                        ? null
                        : () => ref
                              .read(backupControllerProvider.notifier)
                              .setAutoBackupMessageThreshold(
                                (backupState?.autoBackupMessageThreshold ??
                                        20) -
                                    1,
                              ),
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedMinusSign, color: AppPalette.neutral500, size: 16),
                    tooltip: l10n.settingsAutoBackupDecreaseTooltip,
                    color: AppPalette.neutral500,
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    '${backupState?.autoBackupMessageThreshold ?? 20}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: inkColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.settingsMessagesUnit,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.neutral500,
                    ),
                  ),
                  IconButton(
                    onPressed: (backupState?.isBusy == true)
                        ? null
                        : () => ref
                              .read(backupControllerProvider.notifier)
                              .setAutoBackupMessageThreshold(
                                (backupState?.autoBackupMessageThreshold ??
                                        20) +
                                    1,
                              ),
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedPlusSign, color: AppPalette.neutral500, size: 16),
                    tooltip: l10n.settingsAutoBackupIncreaseTooltip,
                    color: AppPalette.neutral500,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (backupState?.statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    backupState!.statusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.neutral500,
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 32),
            _DangerNavRow(
              label: l10n.settingsDangerousActions,
              isDark: isDark,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _DangerousActionsPage(
                    serverUrl: serverUrl,
                    activePartnerId: activePartnerId,
                    onSignOut: onSignOut,
                    onDeleteAccount: onDeleteAccount,
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

// ── Dangerous Actions Page ────────────────────────────────────────────────────

class _DangerousActionsPage extends ConsumerWidget {
  const _DangerousActionsPage({
    required this.serverUrl,
    required this.activePartnerId,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final String serverUrl;
  final String? activePartnerId;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;
    final backupState = ref.watch(backupControllerProvider).value;

    Future<String?> resolveAccessToken() async {
      final fresh = await ref
          .read(appControllerProvider.notifier)
          .ensureFreshAccessToken();
      if (fresh != null && fresh.isNotEmpty) return fresh;
      final fallback = ref.read(appControllerProvider).value?.accessToken;
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return null;
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          l10n.settingsDangerousActions,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w300,
            color: inkColor,
          ),
        ),
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        iconTheme: IconThemeData(color: inkColor),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
          children: [
            // ── Local Data ──────────────────────────────────────────────
            _SectionHeader(label: l10n.settingsLocalData, ruleColor: ruleColor),
            OutlineActionButton(
              label: l10n.settingsDeleteAllLocalChats,
              borderColor: AppPalette.danger700.withValues(alpha: isDark ? 0.55 : 0.45),
              textColor: AppPalette.danger700,
              variant: OutlineActionVariant.danger,
              disabled: backupState?.isBusy == true,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => _ConfirmDialog(
                    title: l10n.settingsDeleteLocalChatsTitle,
                    message: l10n.settingsDeleteLocalChatsMessage,
                    confirmLabel: l10n.settingsDeleteLocalChatsConfirm,
                    isDark: isDark,
                  ),
                );
                if (confirmed != true) return;
                await ref
                    .read(backupControllerProvider.notifier)
                    .deleteLocalChatData();
                ref.invalidate(conversationMessagesProvider);
              },
            ),
            const SizedBox(height: 10),
            OutlineActionButton(
              label: l10n.settingsDeleteAllAppData,
              borderColor: AppPalette.danger700.withValues(alpha: isDark ? 0.55 : 0.45),
              textColor: AppPalette.danger700,
              variant: OutlineActionVariant.danger,
              disabled: backupState?.isBusy == true,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => _ConfirmDialog(
                    title: l10n.settingsDeleteAllAppDataTitle,
                    message: l10n.settingsDeleteAllAppDataMessage,
                    confirmLabel: l10n.settingsDeleteAllAppDataConfirm,
                    isDark: isDark,
                  ),
                );
                if (confirmed != true) return;
                await ref
                    .read(backupControllerProvider.notifier)
                    .deleteAllLocalData();
                ref.invalidate(conversationSummariesProvider);
                ref.invalidate(friendIdsProvider);
                ref.invalidate(userAvatarBase64Provider);
                ref.invalidate(userDisplayNameProvider);
                ref.invalidate(userDescriptionProvider);
                ref.invalidate(friendAddedAtProvider);
                ref.invalidate(conversationMessagesProvider);
              },
            ),
            // ── Sign Out ────────────────────────────────────────────────
            const SizedBox(height: 32),
            _SectionHeader(label: l10n.settingsSignOut, ruleColor: ruleColor),
            OutlineActionButton(
              label: l10n.settingsSignOut,
              borderColor: AppPalette.danger700.withValues(alpha: isDark ? 0.55 : 0.45),
              textColor: AppPalette.danger700,
              variant: OutlineActionVariant.danger,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => _ConfirmDialog(
                    title: l10n.settingsSignOut,
                    message: l10n.settingsSignOutMessage,
                    confirmLabel: l10n.settingsSignOutConfirm,
                    isDark: isDark,
                  ),
                );
                if (confirmed == true) await onSignOut();
              },
            ),
            const SizedBox(height: 12),
            OutlineActionButton(
              label: l10n.settingsDeleteAccount,
              borderColor: AppPalette.danger700.withValues(alpha: isDark ? 0.55 : 0.45),
              textColor: AppPalette.danger700,
              variant: OutlineActionVariant.danger,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => _ConfirmDialog(
                    title: l10n.settingsDeleteAccount,
                    message: l10n.settingsDeleteAccountMessage,
                    confirmLabel: l10n.settingsDeleteAccountConfirm,
                    isDark: isDark,
                  ),
                );
                if (confirmed != true) return;
                final token = await resolveAccessToken();
                if (token != null) {
                  await ref
                      .read(backupControllerProvider.notifier)
                      .deleteBackupData(
                        baseUrl: serverUrl,
                        accessToken: token,
                      );
                }
                await ref
                    .read(backupControllerProvider.notifier)
                    .deleteAllLocalData();
                await onDeleteAccount();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Danger Nav Row ────────────────────────────────────────────────────────────

class _DangerNavRow extends StatelessWidget {
  const _DangerNavRow({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        AppPalette.danger700.withValues(alpha: isDark ? 0.55 : 0.45);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: AppPalette.danger700.withValues(alpha: 0.10),
          highlightColor: AppPalette.danger700.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  color: AppPalette.danger700,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                      color: AppPalette.danger700,
                    ),
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: AppPalette.danger700,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _planetNameFromData({
  required PlanetInfo? planetInfo,
  required AppLocalizations l10n,
}) {
  final remoteName = planetInfo?.instanceName?.trim();
  if (remoteName != null && remoteName.isNotEmpty) {
    return remoteName;
  }
  return l10n.settingsPlanetUnknownName;
}

String _planetDescriptionFromData({
  required PlanetInfo? planetInfo,
  required AppLocalizations l10n,
}) {
  final remoteDescription = planetInfo?.instanceDescription?.trim();
  if (remoteDescription != null && remoteDescription.isNotEmpty) {
    return remoteDescription;
  }
  return l10n.settingsPlanetNoDescription;
}

String _serverCreatedDateFromData({required PlanetInfo? planetInfo}) {
  final value = planetInfo?.serverCreatedAt;
  if (value == null) {
    return '--';
  }
  return DateFormat('yyyy-MM-dd').format(value.toLocal());
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

/// A full-width, bordered danger action button used for destructive or
/// high-impact actions such as deleting data or signing out.
class _DangerActionButton extends StatelessWidget {
  const _DangerActionButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.isDark,
    required this.onPressed,
  });

  final String label;
  final List<List<dynamic>> icon;
  final bool busy;
  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDisabled = busy;
    final borderColor = isDisabled
        ? AppPalette.neutral500.withValues(alpha: 0.25)
        : AppPalette.danger700.withValues(alpha: isDark ? 0.55 : 0.45);
    final bgColor = isDisabled
        ? AppPalette.neutral500.withValues(alpha: 0.05)
        : AppPalette.danger700.withValues(alpha: isDark ? 0.10 : 0.06);
    final textColor = isDisabled
        ? AppPalette.neutral500.withValues(alpha: 0.45)
        : AppPalette.danger700;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            onTap: isDisabled ? null : onPressed,
            borderRadius: BorderRadius.circular(10),
            splashColor: AppPalette.danger700.withValues(alpha: 0.12),
            highlightColor: AppPalette.danger700.withValues(alpha: 0.07),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      HugeIcon(
                        icon: icon,
                        size: 18,
                        color: textColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: textColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                  if (busy)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppPalette.neutral500.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  else
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 18,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                ],
              ),
            ),
          ),
        ),
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
    required this.serverCreatedDate,
    required this.inkColor,
    required this.mutedColor,
  });

  final String planetName;
  final String planetDescription;
  final int stickerCount;
  final int memberCount;
  final bool isConnected;
  final bool notifActive;
  final String serverCreatedDate;
  final Color inkColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              label: isConnected ? l10n.settingsOnline : l10n.settingsOffline,
              mutedColor: mutedColor,
            ),
            const SizedBox(width: 20),
            _InlineStatus(
              active: notifActive,
              label: notifActive
                  ? l10n.settingsNotificationsOn
                  : l10n.settingsNotificationsOff,
              mutedColor: mutedColor,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _TextStat(
              value: '$memberCount',
              label: l10n.settingsResidents,
              inkColor: inkColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(width: 28),
            _TextStat(
              value: '$stickerCount',
              label: l10n.settingsStickers,
              inkColor: inkColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(width: 28),
            _TextStat(
              value: 'E2EE',
              label: l10n.settingsEncrypted,
              inkColor: inkColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(width: 28),
            _TextStat(
              value: serverCreatedDate,
              label: l10n.settingsCreated,
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
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 28,
              runSpacing: 10,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.actionCancel,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppPalette.neutral500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
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
