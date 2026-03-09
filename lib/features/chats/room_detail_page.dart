import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_room.dart';
import '../../services/remote_chat_service.dart';
import '../../state/app_controller.dart';
import '../../state/conversation_messages_controller.dart';
import '../../ui/components/atoms/outline_action_button.dart';
import '../../ui/tokens/colors/app_palette.dart';

enum RoomDetailAction { left, deleted }

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
      if (mounted) setState(() { _detail = detail; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _leaveRoom() async {
    setState(() => _actionInProgress = true);
    try {
      final token = await _accessToken();
      await ref
          .read(roomConversationsProvider.notifier)
          .leaveRoom(baseUrl: widget.serverUrl, accessToken: token, roomId: widget.roomId);
      if (mounted) Navigator.of(context).pop(RoomDetailAction.left);
    } catch (e) {
      if (mounted) {
        setState(() => _actionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _deleteRoom() async {
    setState(() => _actionInProgress = true);
    try {
      final token = await _accessToken();
      await ref
          .read(roomConversationsProvider.notifier)
          .deleteRoom(baseUrl: widget.serverUrl, accessToken: token, roomId: widget.roomId);
      if (mounted) Navigator.of(context).pop(RoomDetailAction.deleted);
    } catch (e) {
      if (mounted) {
        setState(() => _actionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppPalette.neutral500),
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
                  bgColor: bgColor,
                  inkColor: inkColor,
                  ruleColor: ruleColor,
                  subColor: subColor,
                ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required bool isDark,
    required Color bgColor,
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
        Text(
          detail.name,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            color: inkColor,
          ),
          textAlign: TextAlign.center,
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
        OutlineActionButton(
          label: 'Leave this room',
          borderColor: ruleColor,
          textColor: inkColor,
          disabled: _actionInProgress,
          onTap: _leaveRoom,
        ),
        if (isCreator) ...[
          const SizedBox(height: 12),
          OutlineActionButton(
            label: 'Remove this room',
            borderColor: AppPalette.danger700.withValues(alpha: 0.45),
            textColor: AppPalette.danger700,
            variant: OutlineActionVariant.danger,
            disabled: _actionInProgress,
            onTap: _deleteRoom,
          ),
        ],
        const SizedBox(height: 28),
        Divider(height: 1, color: ruleColor),
        const SizedBox(height: 16),

        // ── members section label ──
        Text(
          'MEMBERS',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2.4,
            color: subColor,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 12),

        // ── member list ──
        ...detail.members.map((m) => _MemberRow(
              member: m,
              isDark: isDark,
              inkColor: inkColor,
              subColor: subColor,
              ruleColor: ruleColor,
            )),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isDark,
    required this.inkColor,
    required this.subColor,
    required this.ruleColor,
  });

  final RoomMemberProfile member;
  final bool isDark;
  final Color inkColor;
  final Color subColor;
  final Color ruleColor;

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
            child: Text(
              member.username,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: inkColor,
              ),
            ),
          ),
          if (member.role == 'owner' || member.role == 'admin')
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
        ],
      ),
    );
  }
}
