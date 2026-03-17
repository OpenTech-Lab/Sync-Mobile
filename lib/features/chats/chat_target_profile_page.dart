import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/services/user_profile_preferences.dart';
import '../../services/chat_attachment_download_service.dart';
import '../../state/conversation_messages_controller.dart';
import '../../ui/components/atoms/app_toast.dart';
import '../../ui/tokens/colors/app_palette.dart';
import '../../ui/components/atoms/outline_action_button.dart';
import '../../ui/components/molecules/app_dialog.dart';

enum ChatTargetProfileAction { startChat, addFriend, cancelFriend }

class _FriendTagEditorResult {
  const _FriendTagEditorResult({
    required this.selectedTags,
    required this.deletedTags,
  });

  final List<String> selectedTags;
  final List<String> deletedTags;
}

class ChatTargetProfileScreen extends ConsumerStatefulWidget {
  const ChatTargetProfileScreen({
    super.key,
    required this.serverUrl,
    required this.userId,
    required this.currentUserId,
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
  final String currentUserId;
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
  ConsumerState<ChatTargetProfileScreen> createState() =>
      _ChatTargetProfileScreenState();
}

class _ChatTargetProfileScreenState extends ConsumerState<ChatTargetProfileScreen> {
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
    final result = await _showTagEditorDialog(existingCatalog: catalog);
    if (!mounted || result == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _loadingTags = true);
    if (result.deletedTags.isNotEmpty) {
      await _preferences.deleteFriendTags(widget.serverUrl, result.deletedTags);
    }
    await _preferences.writeFriendTags(
      widget.serverUrl,
      widget.userId,
      result.selectedTags,
    );
    await _loadFriendTags();
  }

  Future<bool> _confirmCancelFriend() async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogColors = AppDialogColors.of(context);
        return AppDialog(
          eyebrow: l10n.chatTargetCancelFriend.toUpperCase(),
          title: 'Remove ${widget.displayName} from your friend list?',
          message: 'You can add this friend again later.',
          showDividerAboveActions: true,
          actions: AppDialogActions(
            children: [
              AppDialogTextAction(
                label: l10n.actionCancel,
                color: dialogColors.muted,
                onTap: () => Navigator.of(context).pop(false),
              ),
              AppDialogTextAction(
                label: l10n.chatTargetCancelFriend.toUpperCase(),
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

  Future<void> _exportChatHistory() async {
    final l10n = AppLocalizations.of(context)!;
    final repository = ref.read(chatRepositoryProvider);
    final messages = await repository.listMessages(
      conversationId: widget.userId,
      limit: 5000,
    );
    if (!mounted) return;

    final partnerLabel = widget.displayName.trim().isNotEmpty
        ? widget.displayName.trim()
        : widget.displayHandle;

    final buffer = StringBuffer();
    buffer.writeln('=== Chat history with $partnerLabel ===');
    buffer.writeln('Exported: ${_formatExportDate(DateTime.now().toLocal())}');
    buffer.writeln();
    for (final msg in messages.reversed) {
      final senderLabel =
          msg.senderId == widget.currentUserId ? 'You' : partnerLabel;
      final time = _formatExportDate(msg.createdAt.toLocal());
      buffer.writeln('[$time] $senderLabel: ${msg.body}');
    }
    final text = buffer.toString();

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.chatExportHistory.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.4,
                    color: AppPalette.neutral500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, thickness: 1, color: ruleColor),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.copy_outlined, color: inkColor, size: 20),
                  title: Text(
                    l10n.chatExportCopyAction,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: inkColor,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    await Clipboard.setData(ClipboardData(text: text));
                    if (mounted) showAppToast(context, l10n.chatExportCopied);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.save_alt_outlined, color: inkColor, size: 20),
                  title: Text(
                    l10n.chatExportSaveAction,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: inkColor,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    try {
                      final bytes = Uint8List.fromList(
                        const Utf8Encoder().convert(text),
                      );
                      final fileName =
                          'chat_${partnerLabel.replaceAll(RegExp(r'[\s\\/:*?"<>|]'), '_')}.txt';
                      await ChatAttachmentDownloadService().download(
                        bytes: bytes,
                        suggestedFileName: fileName,
                      );
                      if (mounted) showAppToast(context, l10n.chatExportSaved);
                    } catch (_) {
                      if (mounted) {
                        showAppToast(
                          context,
                          l10n.chatExportFailed,
                          variant: AppToastVariant.error,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_FriendTagEditorResult?> _showTagEditorDialog({
    required List<String> existingCatalog,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    var availableTags = normalizeFriendTagLabels(
      existingCatalog,
      preferredCasing: existingCatalog,
    );
    final selectedTags = <String>{..._friendTags};
    final deletedTags = <String>{};
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<_FriendTagEditorResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void removeDeletedTag(String tag) {
              final lower = tag.toLowerCase();
              deletedTags.removeWhere((value) => value.toLowerCase() == lower);
            }

            void addDraftTag() {
              final canonical = canonicalizeFriendTagLabel(
                controller.text,
                availableTags,
              );
              if (canonical == null) {
                return;
              }
              FocusScope.of(context).unfocus();
              setDialogState(() {
                availableTags = normalizeFriendTagLabels([
                  ...availableTags,
                  canonical,
                ], preferredCasing: availableTags);
                removeDeletedTag(canonical);
                selectedTags.add(canonical);
                controller.clear();
              });
            }

            Future<void> deleteTag(String tag) async {
              FocusScope.of(context).unfocus();
              final confirmed =
                  await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) {
                      final dialogColors = AppDialogColors.of(dialogContext);
                      return AppDialog(
                        eyebrow: 'DELETE TAG',
                        title: 'Delete $tag?',
                        message:
                            'Remove "$tag" from the reusable tag list and from every friend using it?',
                        showDividerAboveActions: true,
                        actions: AppDialogActions(
                          children: [
                            AppDialogTextAction(
                              label: l10n.actionCancel,
                              color: dialogColors.muted,
                              onTap: () =>
                                  Navigator.of(dialogContext).pop(false),
                            ),
                            AppDialogTextAction(
                              label: 'D E L E T E',
                              color: AppPalette.danger700,
                              onTap: () =>
                                  Navigator.of(dialogContext).pop(true),
                              fontSize: 11,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ],
                        ),
                      );
                    },
                  ) ??
                  false;
              if (!confirmed) {
                return;
              }
              final lower = tag.toLowerCase();
              setDialogState(() {
                availableTags = availableTags
                    .where((value) => value.toLowerCase() != lower)
                    .toList(growable: false);
                selectedTags.removeWhere(
                  (value) => value.toLowerCase() == lower,
                );
                removeDeletedTag(tag);
                deletedTags.add(tag);
              });
            }

            final dialogColors = AppDialogColors.of(context);
            return AppDialog(
              eyebrow: 'TAGS',
              title: 'Group this friend with reusable labels',
              body: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              cursorColor: AppPalette.neutral500,
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
                                color: dialogColors.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Tag name',
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: dialogColors.rule,
                                  ),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: dialogColors.rule,
                                  ),
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
                          TextButton(
                            onPressed: addDraftTag,
                            style: TextButton.styleFrom(
                              foregroundColor: dialogColors.ink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'CREATE',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.8,
                                fontWeight: FontWeight.w500,
                                color: dialogColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap a tag to assign it. Tap the close icon to delete it everywhere.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          color: dialogColors.muted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (availableTags.isEmpty)
                        Text(
                          'Create your first tag to reuse it on other friends.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: dialogColors.muted,
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
                                return InputChip(
                                  key: ValueKey('friend_tag_option_$tag'),
                                  label: Text(tag),
                                  selected: selected,
                                  onPressed: () {
                                    setDialogState(() {
                                      if (selected) {
                                        selectedTags.remove(tag);
                                      } else {
                                        selectedTags.add(tag);
                                      }
                                    });
                                  },
                                  onDeleted: () => deleteTag(tag),
                                  deleteIcon: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: dialogColors.muted,
                                  ),
                                  deleteButtonTooltipMessage: 'Delete tag',
                                  backgroundColor: isDark
                                      ? AppPalette.neutral800
                                      : AppPalette.neutral100,
                                  selectedColor: isDark
                                      ? AppPalette.neutral700
                                      : AppPalette.neutral300,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w300,
                                    color: dialogColors.ink,
                                  ),
                                  shape: StadiumBorder(
                                    side: BorderSide(
                                      color: selected
                                          ? AppPalette.neutral500
                                          : dialogColors.rule,
                                    ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                );
                              })
                              .toList(growable: false),
                        ),
                    ],
                  ),
                ),
              ),
              showDividerAboveActions: true,
              actions: AppDialogActions(
                children: [
                  AppDialogTextAction(
                    label: l10n.actionCancel,
                    color: dialogColors.muted,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  AppDialogTextAction(
                    label: 'S A V E',
                    color: dialogColors.ink,
                    onTap: () => Navigator.of(context).pop(
                      _FriendTagEditorResult(
                        selectedTags: canonicalizeFriendTagLabels(
                          selectedTags,
                          preferredCasing: availableTags,
                        ),
                        deletedTags: canonicalizeFriendTagLabels(
                          deletedTags,
                          preferredCasing: existingCatalog,
                        ),
                      ),
                    ),
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
                onTap: () async {
                  final confirmed = await _confirmCancelFriend();
                  if (!mounted || !confirmed) {
                    return;
                  }
                  Navigator.of(
                    this.context,
                  ).pop(ChatTargetProfileAction.cancelFriend);
                },
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
          if ((widget.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              widget.description!.trim(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: inkColor,
                height: 1.7,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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

          const SizedBox(height: 12),
          OutlineActionButton(
            label: l10n.chatExportHistory,
            borderColor: ruleColor,
            textColor: inkColor,
            onTap: _exportChatHistory,
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

String _formatExportDate(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}
