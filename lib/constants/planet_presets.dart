import '../services/server_scope.dart';

class PlanetPreset {
  const PlanetPreset({required this.name, required this.url});

  final String name;
  final String url;
}

const officialPlanetPresets = <PlanetPreset>[
  PlanetPreset(name: 'SYNC', url: 'https://sync.icyanstudio.net'),
  PlanetPreset(name: 'Local', url: 'https://localhost'),
];

String resolvePlanetName({
  required String serverUrl,
  String? instanceName,
  required String fallbackName,
}) {
  final remoteName = instanceName?.trim();
  if (remoteName != null && remoteName.isNotEmpty) {
    return remoteName;
  }

  final normalized = normalizeServerUrl(serverUrl);
  final preset = officialPlanetPresets.firstWhere(
    (item) =>
        normalizeServerUrl(item.url).toLowerCase() == normalized.toLowerCase(),
    orElse: () => const PlanetPreset(name: '', url: ''),
  );
  if (preset.name.isNotEmpty) {
    return preset.name;
  }

  return fallbackName;
}
