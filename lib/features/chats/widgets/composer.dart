import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../models/sticker.dart';
import '../../../ui/tokens/colors/app_palette.dart';

class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.messageController,
    required this.selectedMediaBytes,
    required this.selectedMediaName,
    required this.stickers,
    required this.onChanged,
    required this.onSend,
    required this.onPickMedia,
    required this.onClearMedia,
    required this.onStickerSelected,
  });

  final TextEditingController messageController;
  final Uint8List? selectedMediaBytes;
  final String? selectedMediaName;
  final List<Sticker> stickers;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onPickMedia;
  final VoidCallback onClearMedia;
  final ValueChanged<Sticker> onStickerSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Media preview
          if (selectedMediaBytes != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: ruleColor)),
              child: Row(
                children: [
                  ClipRRect(
                    child: Image.memory(
                      selectedMediaBytes!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedMediaName ?? l10n.chatSelectedMediaFallback,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: AppPalette.neutral500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onClearMedia,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppPalette.neutral500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Divider(height: 1, thickness: 1, color: ruleColor),

          // Input row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach
                ComposerIconButton(
                  icon: Icons.attach_file_outlined,
                  tooltip: l10n.chatAttachImageTooltip,
                  onPressed: onPickMedia,
                ),
                // Stickers
                ComposerIconButton(
                  icon: Icons.tag_faces_outlined,
                  tooltip: l10n.chatStickersTooltip,
                  onPressed: () async {
                    final selected = await showModalBottomSheet<Sticker>(
                      context: context,
                      backgroundColor: bgColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      builder: (_) => StickerPicker(stickers: stickers),
                    );
                    if (selected != null) {
                      onStickerSelected(selected);
                    }
                  },
                ),
                // Text field
                Expanded(
                  child: TextField(
                    controller: messageController,
                    onChanged: onChanged,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.chatMessageHint,
                      hintStyle: const TextStyle(
                        color: AppPalette.neutral500,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                      filled: false,
                      border: const UnderlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Send
                ComposerSendButton(tooltip: l10n.actionSend, onPressed: onSend),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ComposerIconButton extends StatelessWidget {
  const ComposerIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      onPressed: onPressed,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
    );
  }
}

class ComposerSendButton extends StatelessWidget {
  const ComposerSendButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = isDark ? AppPalette.neutral900 : AppPalette.transparent;
    final iconColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 0, 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: buttonColor,
          shape: const CircleBorder(),
          child: InkResponse(
            onTap: onPressed,
            radius: 28,
            containedInkWell: true,
            customBorder: const CircleBorder(),
            child: SizedBox(
              key: const ValueKey('composer_send_button'),
              width: 36,
              height: 36,
              child: Center(
                child: Icon(
                  CupertinoIcons.arrowtriangle_up_fill,
                  size: 24,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StickerPicker extends StatefulWidget {
  const StickerPicker({super.key, required this.stickers});
  final List<Sticker> stickers;

  @override
  State<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<StickerPicker> {
  String? _selectedGroup;

  String _normalizeGroupName(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return "General";
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final tabBackgroundColor = colorScheme.surfaceContainerLow;
    final tabSelectedBackgroundColor = colorScheme.surfaceContainerHighest;
    if (widget.stickers.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(
            l10n.chatNoStickersYet,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: AppPalette.neutral500,
            ),
          ),
        ),
      );
    }

    final grouped = <String, List<Sticker>>{};
    for (final sticker in widget.stickers) {
      final groupName = _normalizeGroupName(sticker.groupName);
      grouped.putIfAbsent(groupName, () => <Sticker>[]).add(sticker);
    }
    final groups = grouped.keys.toList(growable: false);
    final selectedGroup = groups.contains(_selectedGroup)
        ? _selectedGroup!
        : groups.first;
    final visibleStickers = (grouped[selectedGroup] ?? const <Sticker>[])
        .where((s) => s.name != '__tab__')
        .toList(growable: false);

    final tabImages = <String, Uint8List?>{};
    for (final groupName in groups) {
      final groupStickers = grouped[groupName] ?? const <Sticker>[];
      final tabSticker =
          groupStickers.where((s) => s.name == '__tab__').firstOrNull ??
          groupStickers.firstOrNull;
      if (tabSticker != null) {
        try {
          tabImages[groupName] = base64Decode(tabSticker.contentBase64);
        } catch (_) {}
      }
    }

    return SizedBox(
      height: 320,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.chatStickersHeader,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.8,
                  fontWeight: FontWeight.w400,
                  color: AppPalette.neutral500,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppPalette.neutral300),
          SizedBox(
            height: 60,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final groupName = groups[i];
                final tabImage = tabImages[groupName];
                final isSelected = groupName == selectedGroup;
                return Tooltip(
                  message: groupName,
                  child: Material(
                    color: AppPalette.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _selectedGroup = groupName;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? tabSelectedBackgroundColor
                              : tabBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: tabImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.memory(
                                  tabImage,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                              )
                            : Center(
                                child: Text(
                                  groupName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemCount: groups.length,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: visibleStickers.length,
              itemBuilder: (_, i) {
                final sticker = visibleStickers[i];
                Uint8List bytes;
                try {
                  bytes = base64Decode(sticker.contentBase64);
                } catch (_) {
                  return const SizedBox.shrink();
                }
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(sticker),
                  child: Image.memory(bytes, fit: BoxFit.cover),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
