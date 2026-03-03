import 'dart:convert';

import 'package:flutter/material.dart';

enum ChatTargetProfileAction { startChat, addFriend, cancelFriend }

class ChatTargetProfileScreen extends StatelessWidget {
  const ChatTargetProfileScreen({
    super.key,
    required this.displayName,
    required this.displayHandle,
    required this.avatarBase64,
    this.isFriend = false,
    this.friendAddedAt,
    this.sentMessageCount,
    this.description,
    this.showActions = true,
  });

  final String displayName;
  final String displayHandle;
  final String? avatarBase64;
  final bool isFriend;
  final DateTime? friendAddedAt;
  final int? sentMessageCount;
  final String? description;
  final bool showActions;

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

    const palette = [
      Color(0xFF8A8069), Color(0xFF7A9080), Color(0xFF9B7B6E),
      Color(0xFF7D8A74), Color(0xFF8E8278), Color(0xFF7B8A8A),
    ];
    final hash = displayHandle.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarBg = palette[hash.abs() % palette.length];

    final initials = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: mujiMuted),
        actions: [
          if (isFriend)
            GestureDetector(
              onTap: () => Navigator.of(context)
                  .pop(ChatTargetProfileAction.cancelFriend),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'cancel friend',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9B3A2A),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        children: [
          // ── avatar + name ──
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: avatarBg,
              child: avatarBase64 == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w300,
                        fontSize: 22,
                      ),
                    )
                  : ClipOval(
                      child: SizedBox.expand(
                        child: Image.memory(
                          base64Decode(avatarBase64!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w300,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w300,
              color: inkColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            displayHandle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: mujiMuted,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),
          Divider(height: 1, color: ruleColor),
          const SizedBox(height: 20),

          // ── actions row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isFriend)
                GestureDetector(
                  onTap: () => Navigator.of(context)
                      .pop(ChatTargetProfileAction.addFriend),
                  child: Text(
                    'A D D   F R I E N D',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w500,
                      color: inkColor,
                    ),
                  ),
                )
              else
                Text(
                  'friend',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF6B8F6B),
                  ),
                ),
              if (showActions) ...[
                const SizedBox(width: 32),
                GestureDetector(
                  onTap: () => Navigator.of(context)
                      .pop(ChatTargetProfileAction.startChat),
                  child: Text(
                    'S T A R T   C H A T',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w500,
                      color: inkColor,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // ── friend since ──
          if (isFriend && friendAddedAt != null) ...[
            const SizedBox(height: 28),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 16),
            const Text(
              'FRIEND SINCE',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.4,
                color: mujiMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _friendSinceLabel(friendAddedAt!),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: inkColor,
              ),
            ),
          ],

          // ── messages sent ──
          if (isFriend && sentMessageCount != null) ...[
            const SizedBox(height: 20),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 16),
            const Text(
              'MESSAGES SENT',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.4,
                color: mujiMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$sentMessageCount',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: inkColor,
              ),
            ),
          ],

          // ── description ──
          if ((description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 16),
            const Text(
              'ABOUT',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.4,
                color: mujiMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description!.trim(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: inkColor,
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _friendSinceLabel(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}


