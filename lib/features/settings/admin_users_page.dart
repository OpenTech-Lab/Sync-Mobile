import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../services/remote_admin_service.dart';
import '../../state/admin_controller.dart';
import '../../state/app_controller.dart';
import '../../ui/components/atoms/app_toast.dart';
import '../../ui/components/molecules/app_dialog.dart';
import '../../ui/tokens/colors/app_palette.dart';

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key, required this.serverUrl});

  final String serverUrl;

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final Set<String> _pendingUserIds = <String>{};

  Future<String> _resolveAccessToken() async {
    final fresh = await ref
        .read(appControllerProvider.notifier)
        .ensureFreshAccessToken();
    if (fresh != null && fresh.trim().isNotEmpty) return fresh.trim();
    final appState = ref.read(appControllerProvider).value;
    return appState?.accessToken?.trim() ?? '';
  }

  Future<void> _refresh() {
    return ref.refresh(adminUsersProvider.future);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String eyebrow,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final dialogColors = AppDialogColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          eyebrow: eyebrow,
          title: title,
          message: message,
          showDividerAboveActions: true,
          actions: AppDialogActions(
            children: [
              AppDialogTextAction(
                label: 'Cancel',
                color: dialogColors.muted,
                onTap: () => Navigator.of(dialogContext).pop(false),
              ),
              AppDialogTextAction(
                label: confirmLabel,
                color: dialogColors.ink,
                onTap: () => Navigator.of(dialogContext).pop(true),
                fontSize: 11,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _issueYellowCard(AdminUser user) async {
    if (_pendingUserIds.contains(user.id)) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirm(
      context,
      eyebrow: l10n.adminActionYellowCard,
      title: l10n.adminYellowCardConfirmTitle,
      message: l10n.adminYellowCardConfirmMessage,
      confirmLabel: l10n.adminActionYellowCard,
    );
    if (!mounted || !confirmed) return;

    setState(() => _pendingUserIds.add(user.id));
    try {
      final accessToken = await _resolveAccessToken();
      await ref
          .read(remoteAdminServiceProvider)
          .issueYellowCard(
            baseUrl: widget.serverUrl,
            accessToken: accessToken,
            userId: user.id,
          );
      ref.invalidate(adminUsersProvider);
      if (!mounted) return;
      showAppToast(context, l10n.adminYellowCardIssued);
    } catch (error) {
      if (!mounted) return;
      final message = error is RemoteAdminApiException
          ? error.message
          : l10n.adminYellowCardIssued;
      showAppToast(context, message, variant: AppToastVariant.error);
    } finally {
      if (mounted) setState(() => _pendingUserIds.remove(user.id));
    }
  }

  Future<void> _clearYellowCard(AdminUser user) async {
    if (_pendingUserIds.contains(user.id)) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _pendingUserIds.add(user.id));
    try {
      final accessToken = await _resolveAccessToken();
      await ref
          .read(remoteAdminServiceProvider)
          .clearYellowCard(
            baseUrl: widget.serverUrl,
            accessToken: accessToken,
            userId: user.id,
          );
      ref.invalidate(adminUsersProvider);
      if (!mounted) return;
      showAppToast(context, l10n.adminYellowCardCleared);
    } catch (error) {
      if (!mounted) return;
      final message = error is RemoteAdminApiException
          ? error.message
          : l10n.adminYellowCardCleared;
      showAppToast(context, message, variant: AppToastVariant.error);
    } finally {
      if (mounted) setState(() => _pendingUserIds.remove(user.id));
    }
  }

  Future<void> _suspendUser(AdminUser user) async {
    if (_pendingUserIds.contains(user.id)) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirm(
      context,
      eyebrow: l10n.adminActionSuspend,
      title: l10n.adminSuspendConfirmTitle,
      message: l10n.adminSuspendConfirmMessage,
      confirmLabel: l10n.adminActionSuspend,
    );
    if (!mounted || !confirmed) return;

    setState(() => _pendingUserIds.add(user.id));
    try {
      final accessToken = await _resolveAccessToken();
      await ref
          .read(remoteAdminServiceProvider)
          .suspendUser(
            baseUrl: widget.serverUrl,
            accessToken: accessToken,
            userId: user.id,
          );
      ref.invalidate(adminUsersProvider);
      if (!mounted) return;
      showAppToast(context, l10n.adminUserSuspended);
    } catch (error) {
      if (!mounted) return;
      final message = error is RemoteAdminApiException
          ? error.message
          : l10n.adminUserSuspended;
      showAppToast(context, message, variant: AppToastVariant.error);
    } finally {
      if (mounted) setState(() => _pendingUserIds.remove(user.id));
    }
  }

  Future<void> _activateUser(AdminUser user) async {
    if (_pendingUserIds.contains(user.id)) return;
    setState(() => _pendingUserIds.add(user.id));
    final l10n = AppLocalizations.of(context)!;
    try {
      final accessToken = await _resolveAccessToken();
      await ref
          .read(remoteAdminServiceProvider)
          .activateUser(
            baseUrl: widget.serverUrl,
            accessToken: accessToken,
            userId: user.id,
          );
      ref.invalidate(adminUsersProvider);
      if (!mounted) return;
      showAppToast(context, l10n.adminUserActivated);
    } catch (error) {
      if (!mounted) return;
      final message = error is RemoteAdminApiException
          ? error.message
          : l10n.adminUserActivated;
      showAppToast(context, message, variant: AppToastVariant.error);
    } finally {
      if (mounted) setState(() => _pendingUserIds.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;
    final adminUsersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          l10n.adminUsersTitle,
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
        top: false,
        child: adminUsersAsync.when(
          loading: () => Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: inkColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.adminUsersErrorLoad,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: AppPalette.neutral500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _refresh,
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: inkColor,
                        decoration: TextDecoration.underline,
                        decorationColor: ruleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          data: (users) {
            if (users.isEmpty) {
              return Center(
                child: Text(
                  l10n.adminUsersEmpty,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: AppPalette.neutral500,
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                itemCount: users.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: ruleColor,
                ),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isPending = _pendingUserIds.contains(user.id);
                  return _AdminUserRow(
                    user: user,
                    isPending: isPending,
                    inkColor: inkColor,
                    ruleColor: ruleColor,
                    onYellowCard: () => _issueYellowCard(user),
                    onClearCard: () => _clearYellowCard(user),
                    onSuspend: () => _suspendUser(user),
                    onActivate: () => _activateUser(user),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminUserRow extends StatelessWidget {
  const _AdminUserRow({
    required this.user,
    required this.isPending,
    required this.inkColor,
    required this.ruleColor,
    required this.onYellowCard,
    required this.onClearCard,
    required this.onSuspend,
    required this.onActivate,
  });

  final AdminUser user;
  final bool isPending;
  final Color inkColor;
  final Color ruleColor;
  final VoidCallback onYellowCard;
  final VoidCallback onClearCard;
  final VoidCallback onSuspend;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── username + status badges ──
          Row(
            children: [
              Expanded(
                child: Text(
                  user.username.trim().isEmpty ? user.id : user.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: inkColor,
                  ),
                ),
              ),
              if (user.yellowCardActive) ...[
                const SizedBox(width: 8),
                _StatusBadge(
                  label: l10n.adminStatusYellowCard,
                  color: const Color(0xFFB8860B),
                ),
              ],
              if (!user.isActive) ...[
                const SizedBox(width: 8),
                _StatusBadge(
                  label: l10n.adminStatusSuspended,
                  color: AppPalette.danger700,
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            user.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: AppPalette.neutral500,
            ),
          ),
          const SizedBox(height: 10),
          // ── action buttons ──
          if (isPending)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: inkColor.withValues(alpha: 0.5),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                if (user.yellowCardActive)
                  _ActionChip(
                    label: l10n.adminActionClearCard,
                    inkColor: inkColor,
                    borderColor: ruleColor,
                    onTap: onClearCard,
                  )
                else
                  _ActionChip(
                    label: l10n.adminActionYellowCard,
                    inkColor: const Color(0xFFB8860B),
                    borderColor: const Color(0xFFB8860B),
                    onTap: onYellowCard,
                  ),
                if (!user.isActive)
                  _ActionChip(
                    label: l10n.adminActionActivate,
                    inkColor: inkColor,
                    borderColor: ruleColor,
                    onTap: onActivate,
                  )
                else
                  _ActionChip(
                    label: l10n.adminActionSuspend,
                    inkColor: AppPalette.danger700,
                    borderColor: AppPalette.danger700,
                    onTap: onSuspend,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.inkColor,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final Color inkColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w400,
            color: inkColor,
          ),
        ),
      ),
    );
  }
}
