import 'dart:convert';
import 'dart:typed_data';

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isValidating = widget.connectionStatus == ConnectionStatus.validating;
    final isSuccess = widget.connectionStatus == ConnectionStatus.success;
    final isFailure = widget.connectionStatus == ConnectionStatus.failure;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          children: [
            // — Logo / hero
            Center(
              child: Image.asset('assets/logo.png', width: 72, height: 72),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Sync',
              style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to your planet server to get started.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),

            // — Server URL field
            TextField(
              controller: _serverUrlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://localhost',
                prefixIcon: const Icon(Icons.dns_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // — Planet presets
            if (officialPlanetPresets.isNotEmpty) ...[
              Text(
                'Or choose a preset',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: officialPlanetPresets
                    .map(
                      (preset) => ActionChip(
                        avatar: Icon(Icons.public, size: 15, color: cs.primary),
                        label: Text(
                          preset.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          _serverUrlController.text = preset.url;
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // — Validate button
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: isValidating
                    ? null
                    : () => widget.onValidate(_serverUrlController.text),
                icon: isValidating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.wifi_tethering, size: 18),
                label: Text(
                  isValidating ? 'Checking connection…' : 'Check connection',
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // — Status feedback
            if (isSuccess) ...[
              const SizedBox(height: 14),
              if (widget.planetInfo != null) ...[
                _PlanetInfoCard(info: widget.planetInfo!),
              ],
            ],
            if (isFailure) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.errorMessage ?? 'Connection failed.',
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // — Continue button (active only when server is validated)
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: isSuccess
                    ? () => widget.onContinue(_serverUrlController.text)
                    : null,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanetInfoCard extends StatelessWidget {
  const _PlanetInfoCard({required this.info});

  final PlanetInfo info;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final planetName = (info.instanceName ?? '').trim().isEmpty
        ? info.host
        : info.instanceName!.trim();
    final planetImageBytes = _decodeImageDataUrl(info.instanceImageBase64);
    final countryLabel = [
      if ((info.countryName ?? '').isNotEmpty) info.countryName!,
      if ((info.countryCode ?? '').isNotEmpty) info.countryCode!,
    ].join(' • ');
    final countryChipText = countryLabel.isEmpty
        ? 'Country unavailable'
        : countryLabel;
    final isSecure = info.scheme.toLowerCase() == 'https';

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: planetImageBytes == null
                        ? Icon(
                            Icons.public,
                            color: cs.onPrimaryContainer,
                            size: 20,
                          )
                        : Image.memory(planetImageBytes, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          planetName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Planet Information',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        if ((info.instanceDescription ?? '').isNotEmpty)
                          Text(
                            info.instanceDescription!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(icon: Icons.place_outlined, text: countryChipText),
                  _InfoChip(
                    icon: Icons.speed_outlined,
                    text: '${info.latencyMs} ms',
                  ),
                  _InfoChip(
                    icon: isSecure ? Icons.lock_outline : Icons.info_outline,
                    text: isSecure ? 'Secure' : 'Standard',
                  ),
                ],
              ),
              if ((info.instanceDomain ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  info.instanceDomain!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.green.shade500,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade200,
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Uint8List? _decodeImageDataUrl(String? dataUrl) {
  if (dataUrl == null || dataUrl.trim().isEmpty) {
    return null;
  }
  final value = dataUrl.trim();
  final comma = value.indexOf(',');
  if (comma <= 0 || comma >= value.length - 1) {
    return null;
  }
  try {
    return base64Decode(value.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
