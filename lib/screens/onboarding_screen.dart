import 'package:flutter/material.dart';

import '../constants/planet_presets.dart';
import '../services/server_health_service.dart';
import '../state/app_controller.dart';

class OnboardingScreen extends StatefulWidget {
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
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const mujiPaper   = Color(0xFFFAF9F6);
    const mujiPaperDk = Color(0xFF1E1C19);
    const mujiInk     = Color(0xFF2C2A27);
    const mujiInkDk   = Color(0xFFE8E4DC);
    const mujiMuted   = Color(0xFF8A8680);
    const mujiRed     = Color(0xFF9B3A2A);
    const mujiRule    = Color(0xFFDDD8CF);
    const mujiRuleDk  = Color(0xFF3A3730);

    final bgColor   = isDark ? mujiPaperDk : mujiPaper;
    final inkColor  = isDark ? mujiInkDk   : mujiInk;
    final ruleColor = isDark ? mujiRuleDk  : mujiRule;

    final isValidating = widget.connectionStatus == ConnectionStatus.validating;
    final isSuccess    = widget.connectionStatus == ConnectionStatus.success;
    final isFailure    = widget.connectionStatus == ConnectionStatus.failure;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 40),
          children: [
            // ── hero ──
            Center(
              child: Image.asset('assets/logo.png', width: 56, height: 56),
            ),
            const SizedBox(height: 28),
            Text(
              'Welcome to Sync',
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
              'Connect to your planet server to get started.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: mujiMuted,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 44),

            // ── server URL label ──
            const Text(
              'SERVER URL',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.8,
                color: mujiMuted,
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
                hintText: 'https://my-planet.example.com',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: mujiMuted.withOpacity(0.5),
                  fontWeight: FontWeight.w300,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: mujiMuted),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),

            // ── presets ──
            if (officialPlanetPresets.isNotEmpty) ...[
              const SizedBox(height: 20),
              Divider(height: 1, color: ruleColor),
              const SizedBox(height: 14),
              const Text(
                'QUICK CONNECT',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.8,
                  color: mujiMuted,
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
            GestureDetector(
              onTap: isValidating
                  ? null
                  : () => widget.onValidate(_serverUrlController.text),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isValidating)
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: mujiMuted,
                      ),
                    ),
                  if (isValidating) const SizedBox(width: 10),
                  Text(
                    isValidating ? 'checking…' : 'C H E C K   C O N N E C T I O N',
                    style: TextStyle(
                      fontSize: isValidating ? 13 : 10,
                      letterSpacing: isValidating ? 0.2 : 2.2,
                      fontWeight: FontWeight.w500,
                      color: isValidating ? mujiMuted : inkColor,
                    ),
                  ),
                ],
              ),
            ),

            // ── status feedback ──
            if (isSuccess) ...[
              const SizedBox(height: 24),
              if (widget.planetInfo != null)
                _PlanetInfoCard(
                  info: widget.planetInfo!,
                  inkColor: inkColor,
                  mujiMuted: mujiMuted,
                  ruleColor: ruleColor,
                ),
              const SizedBox(height: 28),
              Divider(height: 1, color: ruleColor),
              const SizedBox(height: 20),
              // continue
              GestureDetector(
                onTap: () => widget.onContinue(_serverUrlController.text),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'C O N T I N U E',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w500,
                      color: inkColor,
                    ),
                  ),
                ),
              ),
            ],

            if (isFailure) ...[
              const SizedBox(height: 20),
              Text(
                widget.errorMessage ?? 'Connection failed.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: mujiRed,
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
    required this.mujiMuted,
    required this.ruleColor,
  });

  final PlanetInfo info;
  final Color inkColor;
  final Color mujiMuted;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
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
                color: mujiMuted.withOpacity(0.15),
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
                          color: mujiMuted,
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
                            color: mujiMuted,
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
                    color: Color(0xFF6B8F6B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'connected',
                  style: TextStyle(
                    fontSize: 11,
                    color: mujiMuted,
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
              color: mujiMuted,
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
              label: 'LATENCY',
              value: '${info.latencyMs} ms',
              inkColor: inkColor,
              mujiMuted: mujiMuted,
            ),
            const SizedBox(width: 28),
            if (countryLabel.isNotEmpty)
              _Stat(
                label: 'REGION',
                value: countryLabel,
                inkColor: inkColor,
                mujiMuted: mujiMuted,
              ),
            const SizedBox(width: 28),
            _Stat(
              label: 'SECURITY',
              value: isSecure ? 'HTTPS' : 'HTTP',
              inkColor: inkColor,
              mujiMuted: mujiMuted,
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
    required this.mujiMuted,
  });

  final String label;
  final String value;
  final Color inkColor;
  final Color mujiMuted;

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
            color: mujiMuted,
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
