import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../models/sticker.dart';
import '../../services/server_health_service.dart';
import '../../services/server_news_service.dart';
import '../../services/sticker_service.dart';
import '../../models/server_news.dart';
import '../../state/sticker_controller.dart';
import '../../ui/components/atoms/simple_markdown.dart';
import '../../ui/tokens/colors/app_palette.dart';

class PlanetTab extends ConsumerStatefulWidget {
  const PlanetTab({
    super.key,
    required this.serverUrl,
    required this.accessToken,
  });

  final String serverUrl;
  final String accessToken;

  @override
  ConsumerState<PlanetTab> createState() => _PlanetTabState();
}

class _PlanetTabState extends ConsumerState<PlanetTab> {
  late Future<_PlanetTabData> _future;
  final Set<String> _downloadingStickerIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlanetTabData> _load() async {
    final healthService = ServerHealthService();
    final current = await healthService.validate(widget.serverUrl);

    final planets = <PlanetInfo>[];
    for (final url in current.linkedPlanets.take(20)) {
      try {
        final info = await healthService.validate(url);
        planets.add(info);
      } catch (_) {
        // Skip offline or invalid planets.
      }
    }

    final news = await ServerNewsService().listNews(
      baseUrl: widget.serverUrl,
      accessToken: widget.accessToken,
      limit: 30,
    );

    List<Sticker> stickers;
    try {
      stickers = await StickerService().syncAll(
        baseUrl: widget.serverUrl,
        accessToken: widget.accessToken,
      );
    } catch (_) {
      stickers = const <Sticker>[];
    }

    return _PlanetTabData(planets: planets, news: news, stickers: stickers);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _downloadSticker(Sticker sticker) async {
    if (_downloadingStickerIds.contains(sticker.id)) {
      return;
    }

    setState(() {
      _downloadingStickerIds.add(sticker.id);
    });

    try {
      await ref.read(stickerControllerProvider.notifier).downloadToLocal(sticker);
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.planetStickerDownloadedToast(sticker.name))),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.planetStickerDownloadFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingStickerIds.remove(sticker.id);
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
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;
    final localStickers =
        ref.watch(stickerControllerProvider).value ?? const <Sticker>[];
    final localStickerIds = localStickers.map((item) => item.id).toSet();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FutureBuilder<_PlanetTabData>(
          future: _future,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;

            if (snapshot.hasError && !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                children: [
                  _SectionLabel(text: l10n.tabPlanet, ruleColor: ruleColor),
                  const SizedBox(height: 18),
                  Text(
                    l10n.planetLoadFailed,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppPalette.danger700,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              );
            }

            if (isLoading) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                children: [
                  _SectionLabel(text: l10n.tabPlanet, ruleColor: ruleColor),
                  const SizedBox(height: 18),
                  Text(
                    l10n.planetLoading,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppPalette.neutral500,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              );
            }

            final data =
                snapshot.data ??
                const _PlanetTabData(
                  planets: <PlanetInfo>[],
                  news: <ServerNewsItem>[],
                  stickers: <Sticker>[],
                );

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                children: [
                  _SectionLabel(
                    text: l10n.planetNewsTitle,
                    ruleColor: ruleColor,
                  ),
                  if (data.news.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        l10n.planetNewsEmpty,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.neutral500,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: data.news.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: ruleColor),
                      itemBuilder: (ctx, index) {
                        final item = data.news[index];
                        final summary = (item.summary ?? '').trim();
                        final dateText = DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(item.publishedAt.toLocal());

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              color: inkColor,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                dateText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppPalette.neutral500,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (summary.isNotEmpty)
                                Text(
                                  summary,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppPalette.neutral500,
                                    fontWeight: FontWeight.w300,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
                                SimpleMarkdownText(
                                  markdown: item.markdownContent,
                                  baseStyle: const TextStyle(
                                    fontSize: 12,
                                    color: AppPalette.neutral500,
                                    fontWeight: FontWeight.w300,
                                  ),
                                  maxParagraphs: 2,
                                ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppPalette.neutral500,
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PlanetNewsDetailPage(
                                  serverUrl: widget.serverUrl,
                                  accessToken: widget.accessToken,
                                  item: item,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  if (data.stickers.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _SectionLabel(
                      text: l10n.planetStickersTitle,
                      ruleColor: ruleColor,
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: data.stickers.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: ruleColor),
                      itemBuilder: (ctx, index) {
                        final sticker = data.stickers[index];
                        final isDownloaded = localStickerIds.contains(sticker.id);
                        final isDownloading = _downloadingStickerIds.contains(
                          sticker.id,
                        );

                        ImageProvider<Object>? previewImage;
                        try {
                          previewImage = MemoryImage(
                            base64Decode(sticker.contentBase64),
                          );
                        } catch (_) {
                          previewImage = null;
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border.all(color: ruleColor),
                              borderRadius: BorderRadius.circular(8),
                              color: isDark
                                  ? AppPalette.neutral800
                                  : AppPalette.neutral100,
                              image: previewImage == null
                                  ? null
                                  : DecorationImage(
                                      image: previewImage,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            child: previewImage == null
                                ? const Icon(
                                    Icons.image_outlined,
                                    size: 18,
                                    color: AppPalette.neutral500,
                                  )
                                : null,
                          ),
                          title: Text(
                            sticker.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              color: inkColor,
                            ),
                          ),
                          subtitle: Text(
                            sticker.groupName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppPalette.neutral500,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: isDownloaded || isDownloading
                                ? null
                                : () => _downloadSticker(sticker),
                            child: Text(
                              isDownloading
                                  ? l10n.planetStickerDownloading
                                  : isDownloaded
                                  ? l10n.planetStickerDownloaded
                                  : l10n.planetStickerDownload,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 32),
                  _SectionLabel(
                    text: l10n.planetOtherPlanetsTitle,
                    ruleColor: ruleColor,
                  ),
                  if (data.planets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        l10n.homeConnectedPlanetsEmpty,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.neutral500,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: data.planets.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: ruleColor),
                      itemBuilder: (ctx, index) {
                        final item = data.planets[index];
                        final title =
                            (item.instanceName ?? item.host).trim().isEmpty
                            ? item.host
                            : (item.instanceName ?? item.host).trim();
                        final subtitle =
                            item.countryName?.trim().isNotEmpty == true
                            ? item.countryName!.trim()
                            : item.host;
                        final members = item.memberCount ?? 0;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              color: inkColor,
                            ),
                          ),
                          subtitle: Text(
                            '$subtitle · ${l10n.homePlanetMembers(members)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppPalette.neutral500,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppPalette.neutral500,
                          ),
                          onTap: () => _showPlanetInfoDialog(context, item),
                        );
                      },
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

class PlanetNewsDetailPage extends StatefulWidget {
  const PlanetNewsDetailPage({
    super.key,
    required this.serverUrl,
    required this.accessToken,
    required this.item,
  });

  final String serverUrl;
  final String accessToken;
  final ServerNewsItem item;

  @override
  State<PlanetNewsDetailPage> createState() => _PlanetNewsDetailPageState();
}

class _PlanetNewsDetailPageState extends State<PlanetNewsDetailPage> {
  late Future<ServerNewsItem> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = ServerNewsService().getNewsDetail(
      baseUrl: widget.serverUrl,
      accessToken: widget.accessToken,
      newsId: widget.item.id,
    );
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
        title: Text(
          l10n.planetNewsDetailTitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w300,
            color: inkColor,
          ),
        ),
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
      ),
      body: SafeArea(
        child: FutureBuilder<ServerNewsItem>(
          future: _detailFuture,
          initialData: widget.item,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: Text(
                  l10n.planetLoading,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppPalette.neutral500,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              );
            }

            final item = snapshot.data!;
            final dateText = DateFormat(
              'yyyy-MM-dd HH:mm',
            ).format(item.publishedAt.toLocal());

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w300,
                    color: inkColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.neutral500,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                if ((item.summary ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    item.summary!.trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppPalette.neutral500,
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? AppPalette.neutral700 : AppPalette.neutral300,
                ),
                const SizedBox(height: 14),
                SimpleMarkdownText(
                  markdown: item.markdownContent,
                  baseStyle: TextStyle(
                    fontSize: 14,
                    color: inkColor,
                    fontWeight: FontWeight.w300,
                    height: 1.6,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanetTabData {
  const _PlanetTabData({
    required this.planets,
    required this.news,
    required this.stickers,
  });

  final List<PlanetInfo> planets;
  final List<ServerNewsItem> news;
  final List<Sticker> stickers;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.ruleColor});

  final String text;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.toUpperCase(),
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

void _showPlanetInfoDialog(BuildContext context, PlanetInfo info) {
  final l10n = AppLocalizations.of(context)!;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
  final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
  final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;
  final title = (info.instanceName ?? info.host).trim().isEmpty
      ? info.host
      : (info.instanceName ?? info.host).trim();
  final description = info.instanceDescription?.trim().isNotEmpty == true
      ? info.instanceDescription!.trim()
      : l10n.settingsPlanetNoDescription;
  final country = info.countryName?.trim().isNotEmpty == true
      ? info.countryName!.trim()
      : l10n.settingsPlanetUnknownName;
  final members = info.memberCount ?? 0;

  showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: inkColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: AppPalette.neutral500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: ruleColor),
              const SizedBox(height: 12),
              Text(
                '${l10n.planetCardHost}: ${info.host}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppPalette.neutral500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${l10n.planetCardCountry}: $country',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppPalette.neutral500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.homePlanetMembers(members),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppPalette.neutral500,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Text(
                    l10n.actionClose,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.neutral500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
