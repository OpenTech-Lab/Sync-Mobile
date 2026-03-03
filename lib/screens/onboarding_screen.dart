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
                hintText: 'https://sync.example.com',
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Connection successful',
                      style: TextStyle(color: Colors.green.shade800),
                    ),
                  ],
                ),
              ),
              if (widget.planetInfo != null) ...[
                const SizedBox(height: 10),
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
    final checked = info.checkedAt.toLocal();
    final hh = checked.hour.toString().padLeft(2, '0');
    final mm = checked.minute.toString().padLeft(2, '0');
    final ss = checked.second.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planet Information',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _InfoLine(label: 'Server', value: info.baseUrl),
          if ((info.instanceName ?? '').isNotEmpty)
            _InfoLine(label: 'Planet', value: info.instanceName!),
          if ((info.instanceDomain ?? '').isNotEmpty)
            _InfoLine(label: 'Domain', value: info.instanceDomain!),
          _InfoLine(label: 'Host', value: info.host),
          _InfoLine(label: 'Protocol', value: info.scheme.toUpperCase()),
          if ((info.countryName ?? '').isNotEmpty ||
              (info.countryCode ?? '').isNotEmpty)
            _InfoLine(
              label: 'Country',
              value: [
                if ((info.countryName ?? '').isNotEmpty) info.countryName!,
                if ((info.countryCode ?? '').isNotEmpty)
                  '(${info.countryCode!})',
              ].join(' '),
            ),
          _InfoLine(label: 'Health', value: info.healthStatus),
          _InfoLine(label: 'Latency', value: '${info.latencyMs} ms'),
          _InfoLine(label: 'Checked', value: '$hh:$mm:$ss'),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: cs.onSurface)),
          ),
        ],
      ),
    );
  }
}
