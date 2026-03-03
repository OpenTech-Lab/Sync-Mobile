class PlanetPreset {
  const PlanetPreset({required this.name, required this.url});

  final String name;
  final String url;
}

const officialPlanetPresets = <PlanetPreset>[
  PlanetPreset(name: 'SYNC', url: 'https://sync.icyanstudio.net'),
  PlanetPreset(name: 'Local', url: 'https://localhost'),
];
