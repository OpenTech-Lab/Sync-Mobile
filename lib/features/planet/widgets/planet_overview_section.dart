import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../services/server_health_service.dart';
import '../../../ui/components/atoms/outline_action_button.dart';
import '../../../ui/tokens/colors/app_palette.dart';

class PlanetOverviewSection extends StatelessWidget {
  const PlanetOverviewSection({
    super.key,
    required this.planetInfo,
    required this.stickerCount,
    required this.isConnected,
    required this.notificationsActive,
    required this.isReconnecting,
    required this.onReconnect,
    required this.inkColor,
    required this.ruleColor,
  });

  final PlanetInfo? planetInfo;
  final int stickerCount;
  final bool isConnected;
  final bool notificationsActive;
  final bool isReconnecting;
  final VoidCallback? onReconnect;
  final Color inkColor;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: l10n.settingsMyPlanet, ruleColor: ruleColor),
        _PlanetCard(
          planetName: _planetNameFromData(planetInfo: planetInfo, l10n: l10n),
          planetDescription: _planetDescriptionFromData(
            planetInfo: planetInfo,
            l10n: l10n,
          ),
          stickerCount: stickerCount,
          memberCount: _planetResidentCountFromData(planetInfo: planetInfo),
          isConnected: isConnected,
          notifActive: notificationsActive,
          serverCreatedDate: _serverCreatedDateFromData(planetInfo: planetInfo),
          isReconnecting: isReconnecting,
          onReconnect: onReconnect,
          inkColor: inkColor,
          mutedColor: AppPalette.neutral500,
        ),
      ],
    );
  }
}

String _planetNameFromData({
  required PlanetInfo? planetInfo,
  required AppLocalizations l10n,
}) {
  final remoteName = planetInfo?.instanceName?.trim();
  if (remoteName != null && remoteName.isNotEmpty) {
    return remoteName;
  }
  return l10n.settingsPlanetUnknownName;
}

String _planetDescriptionFromData({
  required PlanetInfo? planetInfo,
  required AppLocalizations l10n,
}) {
  final remoteDescription = planetInfo?.instanceDescription?.trim();
  if (remoteDescription != null && remoteDescription.isNotEmpty) {
    return remoteDescription;
  }
  return l10n.settingsPlanetNoDescription;
}

String _serverCreatedDateFromData({required PlanetInfo? planetInfo}) {
  final value = planetInfo?.serverCreatedAt;
  if (value == null) {
    return '--';
  }
  return DateFormat('yyyy-MM-dd').format(value.toLocal());
}

int _planetResidentCountFromData({required PlanetInfo? planetInfo}) {
  final value = planetInfo?.memberCount;
  if (value == null || value < 0) {
    return 0;
  }
  return value;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.ruleColor});

  final String label;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
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

class _PlanetCard extends StatelessWidget {
  const _PlanetCard({
    required this.planetName,
    required this.planetDescription,
    required this.stickerCount,
    required this.memberCount,
    required this.isConnected,
    required this.notifActive,
    required this.serverCreatedDate,
    required this.isReconnecting,
    required this.onReconnect,
    required this.inkColor,
    required this.mutedColor,
  });

  final String planetName;
  final String planetDescription;
  final int stickerCount;
  final int memberCount;
  final bool isConnected;
  final bool notifActive;
  final String serverCreatedDate;
  final bool isReconnecting;
  final VoidCallback? onReconnect;
  final Color inkColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                planetName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  color: inkColor,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            _InlineStatus(
              active: isConnected,
              label: isConnected ? l10n.settingsOnline : l10n.settingsOffline,
              mutedColor: mutedColor,
            ),
            const SizedBox(width: 12),
            _InlineStatus(
              active: notifActive,
              label: notifActive
                  ? l10n.settingsNotificationsOn
                  : l10n.settingsNotificationsOff,
              mutedColor: mutedColor,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          planetDescription,
          style: TextStyle(
            fontSize: 12,
            color: mutedColor,
            letterSpacing: 0.2,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _TextStat(
              value: '$memberCount',
              label: l10n.settingsResidents,
              inkColor: inkColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(width: 28),
            _TextStat(
              value: '$stickerCount',
              label: l10n.settingsStickers,
              inkColor: inkColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(width: 28),
            _TextStat(
              value: 'E2EE',
              label: l10n.settingsEncrypted,
              inkColor: inkColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(width: 28),
            _TextStat(
              value: serverCreatedDate,
              label: l10n.settingsCreated,
              inkColor: inkColor,
              mutedColor: mutedColor,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 168,
            child: OutlineActionButton(
              key: const ValueKey('planet_reconnect_button'),
              label: isReconnecting
                  ? l10n.planetReconnectInProgress
                  : l10n.planetReconnectAction,
              borderColor: inkColor,
              textColor: inkColor,
              onTap: onReconnect,
              disabled: isReconnecting,
              compact: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({
    required this.active,
    required this.label,
    required this.mutedColor,
  });

  final bool active;
  final String label;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final dotColor = active
        ? AppPalette.success700
        : mutedColor.withValues(alpha: 0.5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? AppPalette.success700 : mutedColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _TextStat extends StatelessWidget {
  const _TextStat({
    required this.value,
    required this.label,
    required this.inkColor,
    required this.mutedColor,
  });

  final String value;
  final String label;
  final Color inkColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w200,
            color: inkColor,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: mutedColor, letterSpacing: 0.3),
        ),
      ],
    );
  }
}
