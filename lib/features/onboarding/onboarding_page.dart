import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/l10n/app_localizations.dart';
import '../../ui/tokens/colors/app_palette.dart';
import '../../ui/components/atoms/outline_action_button.dart';
import '../../ui/components/molecules/language_picker.dart';

import '../../constants/planet_presets.dart';
import '../../services/server_health_service.dart';
import '../../state/app_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.initialUrl,
    required this.connectionStatus,
    required this.errorMessage,
    required this.planetInfo,
    required this.onValidate,
    required this.onContinue,
  });

  final String? initialUrl;
  final ConnectionStatus connectionStatus;
  final String? errorMessage;
  final PlanetInfo? planetInfo;
  final Future<void> Function(String url) onValidate;
  final Future<void> Function(String url) onContinue;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final TextEditingController _serverUrlController;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController(text: widget.initialUrl ?? '');
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    final isValidating = widget.connectionStatus == ConnectionStatus.validating;
    final isSuccess = widget.connectionStatus == ConnectionStatus.success;
    final isFailure = widget.connectionStatus == ConnectionStatus.failure;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 40),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: LanguagePicker(compact: true),
            ),
            const SizedBox(height: 16),
            // ── hero ──
            Center(
              child: Image.asset('assets/logo.png', width: 56, height: 56),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.welcomeTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w300,
                color: inkColor,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.welcomeSubtitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: AppPalette.neutral500,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 44),

            // ── server URL label ──
            Text(
              l10n.serverUrlLabel,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.8,
                color: AppPalette.neutral500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),

            // ── URL field ──
            TextField(
              controller: _serverUrlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w300,
                color: inkColor,
              ),
              decoration: InputDecoration(
                hintText: l10n.serverUrlHint,
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppPalette.neutral500.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w300,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppPalette.neutral500),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),

            // ── presets ──
            if (officialPlanetPresets.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SizedBox(height: 14),
              Text(
                l10n.quickConnectLabel,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.8,
                  color: AppPalette.neutral500,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 20,
                runSpacing: 10,
                children: officialPlanetPresets
                    .map(
                      (preset) => GestureDetector(
                        onTap: () => _serverUrlController.text = preset.url,
                        child: Text(
                          preset.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                            color: inkColor,
                            decoration: TextDecoration.underline,
                            decorationColor: ruleColor,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],

            const SizedBox(height: 36),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 20),

            // ── validate action ──
            OutlineActionButton(
              label: isValidating ? l10n.checkingConnection : l10n.checkConnectionAction,
              borderColor: ruleColor,
              textColor: isValidating ? AppPalette.neutral500 : inkColor,
              disabled: isValidating,
              onTap: () => widget.onValidate(_serverUrlController.text),
            ),

            // ── status feedback ──
            if (isSuccess) ...[
              const SizedBox(height: 24),
              if (widget.planetInfo != null)
                _PlanetInfoCard(
                  info: widget.planetInfo!,
                  inkColor: inkColor,
                  mutedColor: AppPalette.neutral500,
                  ruleColor: ruleColor,
                ),
              const SizedBox(height: 28),
              Divider(height: 1, color: ruleColor),
              const SizedBox(height: 20),
              // continue
              OutlineActionButton(
                label: l10n.continueAction,
                borderColor: ruleColor,
                textColor: inkColor,
                onTap: () => widget.onContinue(_serverUrlController.text),
              ),
            ],

            if (isFailure) ...[
              const SizedBox(height: 20),
              Text(
                widget.errorMessage ?? l10n.connectionFailed,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: AppPalette.danger700,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanetInfoCard extends StatelessWidget {
  const _PlanetInfoCard({
    required this.info,
    required this.inkColor,
    required this.mutedColor,
    required this.ruleColor,
  });

  final PlanetInfo info;
  final Color inkColor;
  final Color mutedColor;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final planetName = (info.instanceName ?? '').trim().isEmpty
        ? info.host
        : info.instanceName!.trim();
    final planetImageUri = _resolvePlanetImageUri(
      info.baseUrl,
      info.instanceImageUrl,
    );
    final countryLabel = (info.countryName ?? '').trim();
    final isSecure = info.scheme.toLowerCase() == 'https';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── planet name row ──
        Row(
          children: [
            // tiny avatar
            Container(
              width: 28,
              height: 28,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: mutedColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: planetImageUri == null
                  ? Center(
                      child: Text(
                        planetName.isNotEmpty
                            ? planetName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: mutedColor,
                        ),
                      ),
                    )
                  : Image.network(
                      planetImageUri.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          planetName.isNotEmpty
                              ? planetName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: mutedColor,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                planetName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: inkColor,
                ),
              ),
            ),
            // connected dot
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppPalette.success700,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.connectedStatus,
                  style: TextStyle(
                    fontSize: 11,
                    color: mutedColor,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),

        if ((info.instanceDescription ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            info.instanceDescription!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: mutedColor,
              height: 1.5,
            ),
          ),
        ],

        const SizedBox(height: 14),
        Divider(height: 1, color: ruleColor),
        const SizedBox(height: 12),

        // ── stats row ──
        Row(
          children: [
            _Stat(
              label: l10n.planetCardLatency,
              value: l10n.latencyValue(info.latencyMs.toString()),
              inkColor: inkColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(width: 28),
            if (countryLabel.isNotEmpty)
              _Stat(
                label: l10n.planetCardCountry,
                value: countryLabel,
                inkColor: inkColor,
                mutedColor: mutedColor,
              ),
            const SizedBox(width: 28),
            _Stat(
              label: l10n.planetCardProtocol,
              value: isSecure ? l10n.secureStatus : l10n.publicStatus,
              inkColor: inkColor,
              mutedColor: mutedColor,
            ),
          ],
        ),
      ],
    );
  }
}

Uri? _resolvePlanetImageUri(String baseUrl, String? instanceImageUrl) {
  if (instanceImageUrl == null || instanceImageUrl.trim().isEmpty) {
    return null;
  }
  final base = Uri.tryParse(baseUrl);
  final raw = Uri.tryParse(instanceImageUrl.trim());
  if (raw == null) {
    return null;
  }
  return raw.hasScheme ? raw : base?.resolveUri(raw);
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.inkColor,
    required this.mutedColor,
  });

  final String label;
  final String value;
  final Color inkColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 2.2,
            color: mutedColor,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: inkColor,
          ),
        ),
      ],
    );
  }
}
