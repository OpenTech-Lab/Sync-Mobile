import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../models/chat_room.dart';
import '../../state/app_controller.dart';
import '../../state/conversation_messages_controller.dart';
import '../../state/user_profile_controller.dart';
import '../../ui/components/atoms/outline_action_button.dart';
import '../../ui/components/molecules/app_dialog.dart';
import '../../ui/tokens/colors/app_palette.dart';

enum RoomDetailAction { left, deleted, startChat }

class RoomDetailPage extends ConsumerStatefulWidget {
  const RoomDetailPage({
    super.key,
    required this.serverUrl,
    required this.roomId,
    required this.currentUserId,
  });

  final String serverUrl;
  final String roomId;
  final String currentUserId;

  @override
  ConsumerState<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends ConsumerState<RoomDetailPage> {
  RoomDetail? _detail;
  String? _error;
  bool _loading = true;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<String> _accessToken() async {
    final fresh = await ref
        .read(appControllerProvider.notifier)
        .ensureFreshAccessToken();
    final state = ref.read(appControllerProvider).value;
    final stored = state?.accessToken ?? '';
    return (fresh == null || fresh.isEmpty) ? stored : fresh;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _accessToken();
      final service = ref.read(remoteChatServiceProvider);
      final detail = await service.getRoom(
        baseUrl: widget.serverUrl,
        accessToken: token,
        roomId: widget.roomId,
      );
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<String?> _promptForRoomRename() async {
    final detail = _detail;
    if (detail == null) {
      return null;
    }

    final originalName = detail.name.trim();
    final controller = TextEditingController(text: originalName);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    final l10n = AppLocalizations.of(context)!;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final nextName = controller.text.trim();
            final canSave =
                nextName.isNotEmpty &&
                nextName != originalName &&
                !_actionInProgress;
            final dialogColors = AppDialogColors.of(context);
            return AppDialog(
              eyebrow: 'EDIT ROOM',
              title: 'Change room name',
              bodySpacing: 20,
              body: TextField(
                controller: controller,
                autofocus: true,
                cursorColor: AppPalette.neutral500,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (canSave) {
                    Navigator.of(context).pop(nextName);
                  }
                },
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: dialogColors.ink,
                ),
                decoration: InputDecoration(
                  labelText: 'Room name',
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: AppPalette.neutral500.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w300,
                  ),
                  floatingLabelStyle: const TextStyle(
                    color: AppPalette.neutral500,
                    fontWeight: FontWeight.w300,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: dialogColors.rule),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: dialogColors.rule),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppPalette.neutral500),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  isDense: true,
                ),
              ),
              actions: AppDialogActions(
                children: [
                  AppDialogTextAction(
                    label: l10n.actionCancel,
                    color: dialogColors.muted,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  AppDialogTextAction(
                    label: 'S A V E',
                    color: canSave
                        ? dialogColors.ink
                        : AppPalette.neutral500.withValues(alpha: 0.5),
                    onTap: canSave
                        ? () => Navigator.of(context).pop(nextName)
                        : null,
                    fontSize: 11,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w500,
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    return result?.trim();
  }

  Future<List<String>?> _promptForInviteMembers() async {
    final detail = _detail;
    if (detail == null) {
      return null;
    }
    final l10n = AppLocalizations.of(context)!;

    final memberIds = detail.members.map((member) => member.userId).toSet();
    final friendIds =
        ref.read(friendIdsProvider).value ??
        await ref.read(friendIdsProvider.future).catchError((_) {
          return const <String>[];
        });
    if (!mounted) {
      return null;
    }

    final options =
        friendIds
            .where((userId) => !memberIds.contains(userId))
            .map(
              (userId) => _InviteMemberOption(
                userId: userId,
                displayName: _displayNameOrFallback(
                  userId,
                  ref.read(userDisplayNameProvider(userId)).value,
                ),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

    if (options.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          final dialogColors = AppDialogColors.of(context);
          return AppDialog(
            eyebrow: 'INVITE',
            title: 'No friends available to invite.',
            actions: AppDialogActions(
              spacing: 0,
              children: [
                AppDialogTextAction(
                  label: l10n.actionClose,
                  color: dialogColors.muted,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
      );
      return null;
    }

    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        final selectedIds = <String>{};
        return StatefulBuilder(
          builder: (context, setState) {
            final dialogColors = AppDialogColors.of(context);
            return AppDialog(
              eyebrow: 'INVITE',
              title: 'Add members to this room',
              body: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: dialogColors.rule),
                  itemBuilder: (_, index) {
                    final option = options[index];
                    final selected = selectedIds.contains(option.userId);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (_) {
                        setState(() {
                          if (selected) {
                            selectedIds.remove(option.userId);
                          } else {
                            selectedIds.add(option.userId);
                          }
                        });
                      },
                      activeColor: dialogColors.ink,
                      checkColor: dialogColors.background,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        option.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          color: dialogColors.ink,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: AppDialogActions(
                children: [
                  AppDialogTextAction(
                    label: l10n.actionCancel,
                    color: dialogColors.muted,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  AppDialogTextAction(
                    label: 'I N V I T E',
                    color: selectedIds.isEmpty
                        ? AppPalette.neutral500.withValues(alpha: 0.5)
                        : dialogColors.ink,
                    onTap: selectedIds.isEmpty
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pop(selectedIds.toList(growable: false)),
                    fontSize: 11,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w500,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _inviteMembers() async {
    final detail = _detail;
    if (detail == null ||
        _actionInProgress ||
        detail.createdBy != widget.currentUserId) {
      return;
    }

    final memberIds = await _promptForInviteMembers();
    if (!mounted || memberIds == null || memberIds.isEmpty) {
      return;
    }

    setState(() => _actionInProgress = true);
    try {
      final token = await _accessToken();
      final updated = await ref
          .read(roomConversationsProvider.notifier)
          .inviteMembers(
            baseUrl: widget.serverUrl,
            accessToken: token,
            roomId: widget.roomId,
            memberIds: memberIds,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = updated;
        _actionInProgress = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            memberIds.length == 1 ? 'Member invited.' : 'Members invited.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _actionInProgress = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<bool> _confirmRemoveMember(RoomMemberProfile member) async {
    final detail = _detail;
    if (detail == null || member.userId == detail.createdBy) {
      return false;
    }

    final l10n = AppLocalizations.of(context)!;
    final memberName = _displayNameOrFallback(member.userId, member.username);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogColors = AppDialogColors.of(context);
        return AppDialog(
          eyebrow: 'REMOVE MEMBER',
          title: 'Remove $memberName from this room?',
          message: 'They will lose access to the room immediately.',
          showDividerAboveActions: true,
          actions: AppDialogActions(
            children: [
              AppDialogTextAction(
                label: l10n.actionCancel,
                color: dialogColors.muted,
                onTap: () => Navigator.of(context).pop(false),
              ),
              AppDialogTextAction(
                label: 'R E M O V E',
                color: AppPalette.danger700,
                onTap: () => Navigator.of(context).pop(true),
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

  Future<void> _removeMember(RoomMemberProfile member) async {
    final detail = _detail;
    if (detail == null ||
        _actionInProgress ||
        detail.createdBy != widget.currentUserId ||
        member.userId == detail.createdBy) {
      return;
    }

    final confirmed = await _confirmRemoveMember(member);
    if (!mounted || !confirmed) {
      return;
    }

    setState(() => _actionInProgress = true);
    try {
      final token = await _accessToken();
      final updated = await ref
          .read(roomConversationsProvider.notifier)
          .removeMember(
            baseUrl: widget.serverUrl,
            accessToken: token,
            roomId: widget.roomId,
            memberId: member.userId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = updated;
        _actionInProgress = false;
      });
      final memberName = _displayNameOrFallback(member.userId, member.username);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$memberName removed.')));
    } catch (e) {
      if (mounted) {
        setState(() => _actionInProgress = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<bool> _confirmLeaveRoom() async {
    final detail = _detail;
    if (detail == null) {
      return false;
    }

    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogColors = AppDialogColors.of(context);
        return AppDialog(
          eyebrow: 'LEAVE ROOM',
          title: 'Leave ${detail.name}?',
          message: 'You will lose access until someone invites you back.',
          showDividerAboveActions: true,
          actions: AppDialogActions(
            children: [
              AppDialogTextAction(
                label: l10n.actionCancel,
                color: dialogColors.muted,
                onTap: () => Navigator.of(context).pop(false),
              ),
              AppDialogTextAction(
                label: 'L E A V E',
                color: AppPalette.danger700,
                onTap: () => Navigator.of(context).pop(true),
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

  Future<void> _leaveRoom() async {
    if (_actionInProgress) {
      return;
    }

    final confirmed = await _confirmLeaveRoom();
    if (!mounted || !confirmed) {
      return;
    }

    setState(() => _actionInProgress = true);
    try {
      final token = await _accessToken();
      await ref
          .read(roomConversationsProvider.notifier)
          .leaveRoom(
            baseUrl: widget.serverUrl,
            accessToken: token,
            roomId: widget.roomId,
          );
      if (mounted) Navigator.of(context).pop(RoomDetailAction.left);
    } catch (e) {
      if (mounted) {
        setState(() => _actionInProgress = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _renameRoom() async {
    final detail = _detail;
    if (detail == null ||
        _actionInProgress ||
        detail.createdBy != widget.currentUserId) {
      return;
    }

    final nextName = await _promptForRoomRename();
    if (!mounted || nextName == null || nextName.isEmpty) {
      return;
    }

    setState(() => _actionInProgress = true);
    try {
      final token = await _accessToken();
      final updated = await ref
          .read(roomConversationsProvider.notifier)
          .renameRoom(
            baseUrl: widget.serverUrl,
            accessToken: token,
            roomId: widget.roomId,
            name: nextName,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = updated;
        _actionInProgress = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Room name updated.')));
    } catch (e) {
      if (mounted) {
        setState(() => _actionInProgress = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteRoom() async {
    setState(() => _actionInProgress = true);
    try {
      final token = await _accessToken();
      await ref
          .read(roomConversationsProvider.notifier)
          .deleteRoom(
            baseUrl: widget.serverUrl,
            accessToken: token,
            roomId: widget.roomId,
          );
      if (mounted) Navigator.of(context).pop(RoomDetailAction.deleted);
    } catch (e) {
      if (mounted) {
        setState(() => _actionInProgress = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;
    final subColor = AppPalette.neutral500;
    final detail = _detail;
    final showDeleteAction =
        detail != null && detail.createdBy == widget.currentUserId;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppPalette.neutral500),
        actions: [
          if (showDeleteAction)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlineActionButton(
                label: 'Remove this room',
                borderColor: AppPalette.danger700.withValues(alpha: 0.45),
                textColor: AppPalette.danger700,
                variant: OutlineActionVariant.danger,
                compact: true,
                disabled: _actionInProgress,
                onTap: _deleteRoom,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: TextStyle(color: inkColor),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _buildContent(
              context,
              isDark: isDark,
              inkColor: inkColor,
              ruleColor: ruleColor,
              subColor: subColor,
            ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required bool isDark,
    required Color inkColor,
    required Color ruleColor,
    required Color subColor,
  }) {
    final detail = _detail!;
    final isCreator = detail.createdBy == widget.currentUserId;

    const palette = [
      AppPalette.avatarTone1,
      AppPalette.avatarTone2,
      AppPalette.avatarTone3,
      AppPalette.avatarTone4,
      AppPalette.avatarTone5,
      AppPalette.avatarTone6,
    ];
    final hash = detail.name.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarBg = palette[hash.abs() % palette.length];
    final initials = detail.name.trim().isEmpty
        ? '#'
        : detail.name.trim().substring(0, 1).toUpperCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      children: [
        // ── avatar ──
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: avatarBg,
            child: Text(
              initials,
              style: const TextStyle(
                color: AppPalette.white,
                fontWeight: FontWeight.w300,
                fontSize: 22,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── room name ──
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  detail.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    color: inkColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (isCreator)
                Tooltip(
                  message: 'Edit room name',
                  child: IconButton(
                    onPressed: _actionInProgress ? null : _renameRoom,
                    icon: const Icon(Icons.edit_outlined),
                    iconSize: 18,
                    color: subColor,
                    disabledColor: subColor.withValues(alpha: 0.4),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${detail.memberCount} ${detail.memberCount == 1 ? 'member' : 'members'}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: subColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Divider(height: 1, color: ruleColor),
        const SizedBox(height: 20),

        // ── actions ──
        Row(
          children: [
            Expanded(
              child: OutlineActionButton(
                label: 'Open chat',
                borderColor: ruleColor,
                textColor: inkColor,
                disabled: _actionInProgress,
                onTap: () =>
                    Navigator.of(context).pop(RoomDetailAction.startChat),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlineActionButton(
                label: 'Leave this room',
                borderColor: ruleColor,
                textColor: inkColor,
                disabled: _actionInProgress,
                onTap: _leaveRoom,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Divider(height: 1, color: ruleColor),
        const SizedBox(height: 16),

        // ── members section label ──
        Row(
          children: [
            Expanded(
              child: Text(
                'MEMBERS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.4,
                  color: subColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Tooltip(
              message: isCreator ? 'Invite member' : 'Only owner can invite',
              child: IconButton(
                onPressed: isCreator && !_actionInProgress
                    ? _inviteMembers
                    : null,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                iconSize: 18,
                color: subColor,
                disabledColor: subColor.withValues(alpha: 0.4),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── member list ──
        ...detail.members.map(
          (m) => _MemberRow(
            member: m,
            currentUserId: widget.currentUserId,
            isOwnerViewing: isCreator,
            actionInProgress: _actionInProgress,
            onRemove: () => _removeMember(m),
            isDark: isDark,
            inkColor: inkColor,
            subColor: subColor,
          ),
        ),
      ],
    );
  }
}

String _displayNameOrFallback(String userId, String? displayName) {
  final normalized = (displayName ?? '').trim();
  if (normalized.isNotEmpty) {
    return normalized;
  }
  return userId.length >= 8 ? userId.substring(0, 8) : userId;
}

class _InviteMemberOption {
  const _InviteMemberOption({required this.userId, required this.displayName});

  final String userId;
  final String displayName;
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.currentUserId,
    required this.isOwnerViewing,
    required this.actionInProgress,
    required this.onRemove,
    required this.isDark,
    required this.inkColor,
    required this.subColor,
  });

  final RoomMemberProfile member;
  final String currentUserId;
  final bool isOwnerViewing;
  final bool actionInProgress;
  final VoidCallback onRemove;
  final bool isDark;
  final Color inkColor;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    const palette = [
      AppPalette.avatarTone1,
      AppPalette.avatarTone2,
      AppPalette.avatarTone3,
      AppPalette.avatarTone4,
      AppPalette.avatarTone5,
      AppPalette.avatarTone6,
    ];
    final hash = member.username.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarBg = palette[hash.abs() % palette.length];
    final initials = member.username.trim().isEmpty
        ? '?'
        : member.username.trim().substring(0, 1).toUpperCase();
    final isOwnerRow = member.role == 'owner';
    final canRemove = isOwnerViewing && !isOwnerRow && !actionInProgress;
    final tooltipMessage = isOwnerRow
        ? 'Owner cannot be removed'
        : isOwnerViewing
        ? 'Remove member'
        : 'Only owner can remove members';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarBg,
            child: Text(
              initials,
              style: const TextStyle(
                color: AppPalette.white,
                fontWeight: FontWeight.w300,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.username,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: inkColor,
                  ),
                ),
                if (member.userId == currentUserId)
                  Text(
                    'You',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: subColor,
                    ),
                  ),
              ],
            ),
          ),
          if (member.role == 'owner' || member.role == 'admin') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? AppPalette.neutral800 : AppPalette.neutral100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                member.role,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: isDark ? AppPalette.neutral300 : AppPalette.neutral500,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Tooltip(
            message: tooltipMessage,
            child: IconButton(
              onPressed: canRemove ? onRemove : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              iconSize: 18,
              color: AppPalette.danger700,
              disabledColor: subColor.withValues(alpha: 0.4),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
