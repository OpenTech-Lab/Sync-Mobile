import 'package:flutter/material.dart';

import '../constants/planet_presets.dart';
import '../state/app_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.initialUrl,
    required this.connectionStatus,
    required this.errorMessage,
    required this.onValidate,
    required this.onContinue,
  });

  final String? initialUrl;
  final ConnectionStatus connectionStatus;
  final String? errorMessage;
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
    final isValidating = widget.connectionStatus == ConnectionStatus.validating;
    final canContinue = widget.connectionStatus == ConnectionStatus.success;

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Connect to your planet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter a custom server URL or pick an official planet preset.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _serverUrlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://sync.example.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: officialPlanetPresets
                .map(
                  (preset) => ActionChip(
                    label: Text(preset.name),
                    onPressed: () {
                      _serverUrlController.text = preset.url;
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isValidating
                ? null
                : () => widget.onValidate(_serverUrlController.text),
            icon: isValidating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(isValidating
                ? 'Validating connection...'
                : 'Validate connection'),
          ),
          if (widget.connectionStatus == ConnectionStatus.success)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Connection successful.',
                style: TextStyle(color: Colors.green),
              ),
            ),
          if (widget.connectionStatus == ConnectionStatus.failure)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                widget.errorMessage ?? 'Connection failed.',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canContinue
                ? () => widget.onContinue(_serverUrlController.text)
                : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
