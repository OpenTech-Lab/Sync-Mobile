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
import '../../ui/components/atoms/app_toast.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

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
                    Builder(
                      builder: (ctx) {
                        final grouped = <String, List<Sticker>>{};
                        for (final s in data.stickers) {
                          grouped
                              .putIfAbsent(s.groupName, () => [])
                              .add(s);
                        }
                        final groups =
                            grouped.keys.toList(growable: false);
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: groups.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: ruleColor),
                          itemBuilder: (_, i) {
                            final groupName = groups[i];
                            final groupStickers = grouped[groupName]!;
                            final tabSticker = groupStickers.firstWhere(
                              (s) => s.name == '__tab__',
                              orElse: () => groupStickers.first,
                            );
                            final contentCount = groupStickers
                                .where((s) => s.name != '__tab__')
                                .length;
                            ImageProvider? tabImage;
                            try {
                              tabImage = MemoryImage(
                                base64Decode(tabSticker.contentBase64),
                              );
                            } catch (_) {}
                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  border: Border.all(color: ruleColor),
                                  borderRadius: BorderRadius.circular(8),
                                  color: isDark
                                      ? AppPalette.neutral800
                                      : AppPalette.neutral100,
                                  image: tabImage == null
                                      ? null
                                      : DecorationImage(
                                          image: tabImage,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                child: tabImage == null
                                    ? const Icon(
                                        Icons.image_outlined,
                                        size: 18,
                                        color: AppPalette.neutral500,
                                      )
                                    : null,
                              ),
                              title: Text(
                                groupName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color: inkColor,
                                ),
                              ),
                              subtitle: Text(
                                l10n.planetStickerGroupCount(contentCount),
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
                              onTap: () => Navigator.of(ctx).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => StickerGroupDetailPage(
                                    groupName: groupName,
                                    stickers: groupStickers,
                                  ),
                                ),
                              ),
                            );
                          },
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

class StickerGroupDetailPage extends ConsumerStatefulWidget {
  const StickerGroupDetailPage({
    super.key,
    required this.groupName,
    required this.stickers,
  });

  final String groupName;
  final List<Sticker> stickers;

  @override
  ConsumerState<StickerGroupDetailPage> createState() =>
      _StickerGroupDetailPageState();
}

class _StickerGroupDetailPageState
    extends ConsumerState<StickerGroupDetailPage> {
  bool _isDownloading = false;

  Future<void> _downloadGroup(
    List<Sticker> toDownload,
  ) async {
    if (_isDownloading || toDownload.isEmpty) return;
    setState(() => _isDownloading = true);
    try {
      for (final sticker in toDownload) {
        await ref
            .read(stickerControllerProvider.notifier)
            .downloadToLocal(sticker);
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppToast(context, l10n.planetStickerGroupDownloadedToast(widget.groupName));
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppToast(context, l10n.planetStickerDownloadFailed, variant: AppToastVariant.error);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
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
    final localIds = localStickers.map((s) => s.id).toSet();

    final tabSticker = widget.stickers.firstWhere(
      (s) => s.name == '__tab__',
      orElse: () => widget.stickers.first,
    );
    final contentStickers =
        widget.stickers.where((s) => s.name != '__tab__').toList();
    final pending =
        contentStickers.where((s) => !localIds.contains(s.id)).toList();
    final allDownloaded = pending.isEmpty;

    ImageProvider? tabImage;
    try {
      tabImage = MemoryImage(base64Decode(tabSticker.contentBase64));
    } catch (_) {}

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.groupName,
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
          children: [
            if (tabImage != null)
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: tabImage,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 28),
            if (contentStickers.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: contentStickers.length,
                itemBuilder: (_, i) {
                  final sticker = contentStickers[i];
                  final isLocal = localIds.contains(sticker.id);
                  ImageProvider? img;
                  try {
                    img = MemoryImage(
                      base64Decode(sticker.contentBase64),
                    );
                  } catch (_) {}
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: ruleColor),
                                borderRadius: BorderRadius.circular(8),
                                color: isDark
                                    ? AppPalette.neutral800
                                    : AppPalette.neutral100,
                                image: img == null
                                    ? null
                                    : DecorationImage(
                                        image: img,
                                        fit: BoxFit.contain,
                                      ),
                              ),
                              child: img == null
                                  ? const Center(
                                      child: Icon(
                                        Icons.image_outlined,
                                        size: 24,
                                        color: AppPalette.neutral500,
                                      ),
                                    )
                                  : null,
                            ),
                            if (isLocal)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppPalette.neutral700
                                        : AppPalette.neutral300,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 10,
                                    color: AppPalette.neutral500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sticker.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          color: AppPalette.neutral500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: allDownloaded || _isDownloading
                  ? null
                  : () => _downloadGroup(pending),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: allDownloaded
                        ? ruleColor
                        : inkColor,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isDownloading
                      ? l10n.planetStickerDownloading
                      : allDownloaded
                          ? l10n.planetStickerDownloaded
                          : l10n.planetStickerDownload,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.3,
                    color: allDownloaded
                        ? AppPalette.neutral500
                        : inkColor,
                  ),
                ),
              ),
            ),
          ],
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
