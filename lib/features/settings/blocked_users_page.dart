import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_controller.dart';
import '../../state/safety_controller.dart';
import '../../services/remote_safety_service.dart';
import '../../ui/components/atoms/app_toast.dart';
import '../../ui/components/molecules/app_dialog.dart';
import '../../ui/tokens/colors/app_palette.dart';

class BlockedUsersPage extends ConsumerStatefulWidget {
  const BlockedUsersPage({super.key, required this.serverUrl});

  final String serverUrl;

  @override
  ConsumerState<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends ConsumerState<BlockedUsersPage> {
  final Set<String> _pendingUserIds = <String>{};
  final Set<String> _dismissedUserIds = <String>{};

  Future<String> _resolveAccessToken() async {
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
    throw StateError('Missing access token.');
  }

  Future<bool> _confirmUnblock(BlockedUser user) async {
    final dialogColors = AppDialogColors.of(context);
    final title = user.username.trim().isEmpty ? user.userId : user.username;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          eyebrow: 'UNBLOCK USER',
          title: 'Allow $title to appear again?',
          message:
              'This user can appear in your feed again after you remove them from the blocked list.',
          showDividerAboveActions: true,
          actions: AppDialogActions(
            children: [
              AppDialogTextAction(
                label: 'Cancel',
                color: dialogColors.muted,
                onTap: () => Navigator.of(dialogContext).pop(false),
              ),
              AppDialogTextAction(
                label: 'UNBLOCK',
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

  Future<void> _unblockUser(BlockedUser user) async {
    if (_pendingUserIds.contains(user.userId)) {
      return;
    }
    final confirmed = await _confirmUnblock(user);
    if (!mounted || !confirmed) {
      return;
    }

    setState(() => _pendingUserIds.add(user.userId));
    try {
      final accessToken = await _resolveAccessToken();
      await ref
          .read(remoteSafetyServiceProvider)
          .unblockUser(
            baseUrl: widget.serverUrl,
            accessToken: accessToken,
            userId: user.userId,
          );
      ref.invalidate(blockedUsersProvider);
      ref.invalidate(blockedUserIdsProvider);
      if (!mounted) {
        return;
      }
      setState(() => _dismissedUserIds.add(user.userId));
      showAppToast(context, 'User unblocked.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is RemoteSafetyApiException
          ? error.message
          : 'Failed to unblock user.';
      showAppToast(context, message, variant: AppToastVariant.error);
    } finally {
      if (mounted) {
        setState(() => _pendingUserIds.remove(user.userId));
      }
    }
  }

  Future<void> _refreshBlockedUsers() async {
    final refresh = ref.refresh(blockedUsersProvider.future);
    await refresh;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blockedUsersAsync = ref.watch(blockedUsersProvider);
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Blocked users',
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
        child: blockedUsersAsync.when(
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
          error: (error, _) => _BlockedUsersErrorState(
            inkColor: inkColor,
            ruleColor: ruleColor,
            onRetry: _refreshBlockedUsers,
          ),
          data: (users) {
            final visibleUsers = users
                .where((user) => !_dismissedUserIds.contains(user.userId))
                .toList(growable: false);

            return RefreshIndicator(
              onRefresh: _refreshBlockedUsers,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                children: [
                  _BlockedUsersSectionHeader(ruleColor: ruleColor),
                  if (visibleUsers.isEmpty)
                    _EmptyBlockedUsersCard(
                      inkColor: inkColor,
                      ruleColor: ruleColor,
                    )
                  else
                    ...visibleUsers.map(
                      (user) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BlockedUserRow(
                          user: user,
                          inkColor: inkColor,
                          ruleColor: ruleColor,
                          pending: _pendingUserIds.contains(user.userId),
                          onUnblock: () => _unblockUser(user),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BlockedUsersSectionHeader extends StatelessWidget {
  const _BlockedUsersSectionHeader({required this.ruleColor});

  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BLOCKED USERS',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.8,
              fontWeight: FontWeight.w400,
              color: AppPalette.neutral500,
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 1, color: ruleColor),
          const SizedBox(height: 8),
          const Text(
            'Review blocked users and remove them from the list at any time.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: AppPalette.neutral500,
              letterSpacing: 0.2,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBlockedUsersCard extends StatelessWidget {
  const _EmptyBlockedUsersCard({
    required this.inkColor,
    required this.ruleColor,
  });

  final Color inkColor;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(color: ruleColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.block_outlined, size: 20, color: inkColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No blocked users.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: inkColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedUsersErrorState extends StatelessWidget {
  const _BlockedUsersErrorState({
    required this.inkColor,
    required this.ruleColor,
    required this.onRetry,
  });

  final Color inkColor;
  final Color ruleColor;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: ruleColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 22, color: inkColor),
              const SizedBox(height: 12),
              Text(
                'Failed to load blocked users.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: inkColor,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedUserRow extends StatelessWidget {
  const _BlockedUserRow({
    required this.user,
    required this.inkColor,
    required this.ruleColor,
    required this.pending,
    required this.onUnblock,
  });

  final BlockedUser user;
  final Color inkColor;
  final Color ruleColor;
  final bool pending;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final title = user.username.trim().isEmpty ? user.userId : user.username;
    final showUserId = user.userId.trim().isNotEmpty && user.userId != title;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: Border.all(color: ruleColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BlockedUserAvatar(
            username: title,
            avatarBase64: user.avatarBase64,
            inkColor: inkColor,
            ruleColor: ruleColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: inkColor,
                  ),
                ),
                if (showUserId) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.userId,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: AppPalette.neutral500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Blocked ${_formatBlockedDate(user.blockedAt)}',
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
          const SizedBox(width: 12),
          TextButton(
            onPressed: pending ? null : onUnblock,
            child: pending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  )
                : const Text(
                    'UNBLOCK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BlockedUserAvatar extends StatelessWidget {
  const _BlockedUserAvatar({
    required this.username,
    required this.avatarBase64,
    required this.inkColor,
    required this.ruleColor,
  });

  final String username;
  final String? avatarBase64;
  final Color inkColor;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    final imageBytes = _decodeBase64(avatarBase64);
    final initial = username.trim().isEmpty
        ? '?'
        : username.trim().substring(0, 1).toUpperCase();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ruleColor),
        color: AppPalette.neutral500.withValues(alpha: 0.12),
        image: imageBytes == null
            ? null
            : DecorationImage(
                image: MemoryImage(imageBytes),
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      child: imageBytes == null
          ? Text(
              initial,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: inkColor,
              ),
            )
          : null,
    );
  }
}

Uint8List? _decodeBase64(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  try {
    return base64Decode(normalized);
  } catch (_) {
    return null;
  }
}

String _formatBlockedDate(DateTime blockedAt) {
  final local = blockedAt.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
