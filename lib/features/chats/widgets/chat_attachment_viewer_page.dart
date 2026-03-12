import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../services/chat_attachment_download_service.dart';
import '../../../ui/components/atoms/app_toast.dart';
import '../../../ui/tokens/colors/app_palette.dart';

class ChatAttachmentViewerPage extends StatefulWidget {
  const ChatAttachmentViewerPage({
    super.key,
    required this.bytes,
    required this.suggestedFileName,
  });

  final Uint8List bytes;
  final String suggestedFileName;

  @override
  State<ChatAttachmentViewerPage> createState() =>
      _ChatAttachmentViewerPageState();
}

class _ChatAttachmentViewerPageState extends State<ChatAttachmentViewerPage> {
  bool _isDownloading = false;

  Future<void> _download() async {
    if (_isDownloading) {
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      await ChatAttachmentDownloadService().download(
        bytes: widget.bytes,
        suggestedFileName: widget.suggestedFileName,
      );
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        AppLocalizations.of(context)!.chatAttachmentDownloaded,
        duration: const Duration(milliseconds: 900),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        AppLocalizations.of(context)!.chatAttachmentDownloadFailed,
        variant: AppToastVariant.error,
        duration: const Duration(milliseconds: 900),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.chatAttachmentViewerTitle,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: inkColor,
          ),
        ),
        iconTheme: const IconThemeData(color: AppPalette.neutral500),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.memory(
                widget.bytes,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppPalette.neutral800 : AppPalette.neutral100,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppPalette.neutral700 : AppPalette.neutral300,
          ),
        ),
        child: IconButton(
          onPressed: _isDownloading ? null : _download,
          tooltip: l10n.chatDownloadAttachmentTooltip,
          icon: _isDownloading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark
                        ? AppPalette.neutral100
                        : AppPalette.neutral900,
                  ),
                )
              : Icon(
                  Icons.download_rounded,
                  color: isDark ? AppPalette.neutral100 : AppPalette.neutral900,
                ),
        ),
      ),
    );
  }
}
