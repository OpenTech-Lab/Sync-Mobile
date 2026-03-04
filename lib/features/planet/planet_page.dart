import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../services/server_health_service.dart';
import '../../services/server_news_service.dart';
import '../../models/server_news.dart';
import '../../ui/components/atoms/simple_markdown.dart';
import '../../ui/tokens/colors/app_palette.dart';

class PlanetTab extends StatefulWidget {
  const PlanetTab({
    super.key,
    required this.serverUrl,
    required this.accessToken,
  });

  final String serverUrl;
  final String accessToken;

  @override
  State<PlanetTab> createState() => _PlanetTabState();
}

class _PlanetTabState extends State<PlanetTab> {
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

    return _PlanetTabData(planets: planets, news: news);
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
  const _PlanetTabData({required this.planets, required this.news});

  final List<PlanetInfo> planets;
  final List<ServerNewsItem> news;
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
