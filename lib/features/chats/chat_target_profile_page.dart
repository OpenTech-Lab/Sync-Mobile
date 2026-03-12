import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/services/user_profile_preferences.dart';
import '../../ui/tokens/colors/app_palette.dart';
import '../../ui/components/atoms/outline_action_button.dart';

enum ChatTargetProfileAction { startChat, addFriend, cancelFriend }

class ChatTargetProfileScreen extends StatefulWidget {
  const ChatTargetProfileScreen({
    super.key,
    required this.serverUrl,
    required this.userId,
    required this.displayName,
    required this.displayHandle,
    required this.avatarBase64,
    this.isFriend = false,
    this.friendAddedAt,
    this.sentMessageCount,
    this.description,
    this.level,
    this.rank,
  });

  final String serverUrl;
  final String userId;
  final String displayName;
  final String displayHandle;
  final String? avatarBase64;
  final bool isFriend;
  final DateTime? friendAddedAt;
  final int? sentMessageCount;
  final String? description;
  final int? level;
  final String? rank;

  @override
  State<ChatTargetProfileScreen> createState() =>
      _ChatTargetProfileScreenState();
}

class _ChatTargetProfileScreenState extends State<ChatTargetProfileScreen> {
  final _preferences = UserProfilePreferences();
  List<String> _friendTags = const <String>[];
  bool _loadingTags = false;

  @override
  void initState() {
    super.initState();
    _loadingTags = widget.isFriend;
    if (widget.isFriend) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadFriendTags();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChatTargetProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverUrl == widget.serverUrl &&
        oldWidget.userId == widget.userId &&
        oldWidget.isFriend == widget.isFriend) {
      return;
    }
    if (!widget.isFriend) {
      setState(() {
        _loadingTags = false;
        _friendTags = const <String>[];
      });
      return;
    }
    setState(() => _loadingTags = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFriendTags();
    });
  }

  Future<void> _loadFriendTags() async {
    if (!widget.isFriend) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingTags = false;
        _friendTags = const <String>[];
      });
      return;
    }
    final tags = await _preferences.readFriendTags(
      widget.serverUrl,
      widget.userId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingTags = false;
      _friendTags = tags;
    });
  }

  Future<void> _editFriendTags() async {
    final catalog = await _preferences.readFriendTagCatalog(widget.serverUrl);
    if (!mounted) {
      return;
    }
    final nextTags = await _showTagEditorDialog(existingCatalog: catalog);
    if (!mounted || nextTags == null) {
      return;
    }
    await _preferences.writeFriendTags(
      widget.serverUrl,
      widget.userId,
      nextTags,
    );
    if (!mounted) {
      return;
    }
    setState(() => _friendTags = nextTags);
  }

  Future<List<String>?> _showTagEditorDialog({
    required List<String> existingCatalog,
  }) async {
    final controller = TextEditingController();
    var availableTags = normalizeFriendTagLabels(
      existingCatalog,
      preferredCasing: existingCatalog,
    );
    final selectedTags = <String>{..._friendTags};
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;
    final subColor = AppPalette.neutral500;

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void addDraftTag() {
              final canonical = canonicalizeFriendTagLabel(
                controller.text,
                availableTags,
              );
              if (canonical == null) {
                return;
              }
              setDialogState(() {
                availableTags = normalizeFriendTagLabels([
                  ...availableTags,
                  canonical,
                ], preferredCasing: availableTags);
                selectedTags.add(canonical);
                controller.clear();
              });
            }

            return Dialog(
              backgroundColor: bgColor,
              surfaceTintColor: AppPalette.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 44,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'TAGS',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2.4,
                            color: subColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Group this friend with reusable labels',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: inkColor,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => addDraftTag(),
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(
                                    friendTagMaxLength,
                                  ),
                                ],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color: inkColor,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Tag name',
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(color: ruleColor),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: ruleColor),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: AppPalette.neutral500,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            GestureDetector(
                              onTap: addDraftTag,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Text(
                                  'CREATE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.8,
                                    fontWeight: FontWeight.w500,
                                    color: inkColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (availableTags.isEmpty)
                          Text(
                            'Create your first tag to reuse it on other friends.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              color: subColor,
                              height: 1.45,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availableTags
                                .map((tag) {
                                  final selected = selectedTags.contains(tag);
                                  return ChoiceChip(
                                    label: Text(tag),
                                    selected: selected,
                                    onSelected: (_) {
                                      setDialogState(() {
                                        if (selected) {
                                          selectedTags.remove(tag);
                                        } else {
                                          selectedTags.add(tag);
                                        }
                                      });
                                    },
                                    backgroundColor: isDark
                                        ? AppPalette.neutral800
                                        : AppPalette.neutral100,
                                    selectedColor: isDark
                                        ? AppPalette.neutral700
                                        : AppPalette.neutral300,
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w300,
                                      color: inkColor,
                                    ),
                                    shape: StadiumBorder(
                                      side: BorderSide(
                                        color: selected
                                            ? AppPalette.neutral500
                                            : ruleColor,
                                      ),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  );
                                })
                                .toList(growable: false),
                          ),
                        const SizedBox(height: 18),
                        Divider(height: 1, color: ruleColor),
                        const SizedBox(height: 14),
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
                                    color: subColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(
                                canonicalizeFriendTagLabels(
                                  selectedTags,
                                  preferredCasing: availableTags,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Text(
                                  'S A V E',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 2.2,
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
                ),
              ),
            );
          },
        );
      },
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    const palette = [
      AppPalette.avatarTone1,
      AppPalette.avatarTone2,
      AppPalette.avatarTone3,
      AppPalette.avatarTone4,
      AppPalette.avatarTone5,
      AppPalette.avatarTone6,
    ];
    final hash = widget.displayHandle.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarBg = palette[hash.abs() % palette.length];

    final initials = widget.displayName.trim().isEmpty
        ? '?'
        : widget.displayName.trim().substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppPalette.neutral500),
        actions: [
          if (widget.isFriend)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlineActionButton(
                label: l10n.chatTargetCancelFriend,
                borderColor: AppPalette.danger700.withValues(alpha: 0.45),
                textColor: AppPalette.danger700,
                variant: OutlineActionVariant.danger,
                compact: true,
                onTap: () => Navigator.of(
                  context,
                ).pop(ChatTargetProfileAction.cancelFriend),
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
              backgroundColor: widget.avatarBase64 != null
                  ? Colors.transparent
                  : avatarBg,
              child: widget.avatarBase64 == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: AppPalette.white,
                        fontWeight: FontWeight.w300,
                        fontSize: 22,
                      ),
                    )
                  : ClipOval(
                      child: SizedBox.expand(
                        child: Image.memory(
                          base64Decode(widget.avatarBase64!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(
                            initials,
                            style: const TextStyle(
                              color: AppPalette.white,
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
            widget.displayName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w300,
              color: inkColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.level != null ||
              (widget.rank != null && widget.rank!.isNotEmpty)) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.level != null)
                  _guildBadge('Lv ${widget.level}', isDark),
                if (widget.level != null &&
                    widget.rank != null &&
                    widget.rank!.isNotEmpty)
                  const SizedBox(width: 6),
                if (widget.rank != null && widget.rank!.isNotEmpty)
                  _guildBadge(widget.rank!, isDark),
              ],
            ),
          ],
          if (widget.isFriend) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedUserCheck01,
                  size: 13,
                  color: AppPalette.success700,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.chatTargetFriend,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: AppPalette.success700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          Divider(height: 1, color: ruleColor),
          const SizedBox(height: 20),

          // ── actions row ──
          Row(
            children: [
              Expanded(
                child: OutlineActionButton(
                  label: l10n.chatTargetAddFriend,
                  borderColor: ruleColor,
                  textColor: inkColor,
                  disabled: widget.isFriend,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(ChatTargetProfileAction.addFriend),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlineActionButton(
                  label: l10n.chatTargetStartChat,
                  borderColor: ruleColor,
                  textColor: inkColor,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(ChatTargetProfileAction.startChat),
                ),
              ),
            ],
          ),

          if (widget.isFriend) ...[
            const SizedBox(height: 28),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TAGS',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.4,
                      color: AppPalette.neutral500,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                OutlineActionButton(
                  label: _friendTags.isEmpty ? 'Add tags' : 'Edit tags',
                  borderColor: ruleColor,
                  textColor: inkColor,
                  compact: true,
                  disabled: _loadingTags,
                  onTap: _loadingTags ? null : _editFriendTags,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingTags)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_friendTags.isEmpty)
              Text(
                'No tags yet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: AppPalette.neutral500,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _friendTags
                    .map((tag) => _FriendTagPill(label: tag, isDark: isDark))
                    .toList(growable: false),
              ),
          ],

          // ── friend since ──
          if (widget.isFriend && widget.friendAddedAt != null) ...[
            const SizedBox(height: 28),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 16),
            Text(
              l10n.chatTargetFriendSince,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.4,
                color: AppPalette.neutral500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _friendSinceLabel(widget.friendAddedAt!),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: inkColor,
              ),
            ),
          ],

          // ── messages sent ──
          if (widget.isFriend && widget.sentMessageCount != null) ...[
            const SizedBox(height: 20),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 16),
            Text(
              l10n.chatTargetMessagesSent,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.4,
                color: AppPalette.neutral500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.sentMessageCount}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: inkColor,
              ),
            ),
          ],

          // ── description ──
          if ((widget.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 16),
            Text(
              l10n.chatTargetAbout,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.4,
                color: AppPalette.neutral500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.description!.trim(),
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

class _FriendTagPill extends StatelessWidget {
  const _FriendTagPill({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.neutral800 : AppPalette.neutral100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? AppPalette.neutral700 : AppPalette.neutral300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w300,
          color: isDark ? AppPalette.neutral100 : AppPalette.neutral700,
        ),
      ),
    );
  }
}

Widget _guildBadge(String label, bool isDark) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: isDark ? AppPalette.neutral800 : AppPalette.neutral100,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: isDark ? AppPalette.neutral300 : AppPalette.neutral500,
      ),
    ),
  );
}

String _friendSinceLabel(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}
