class PlanetPreset {
  const PlanetPreset({required this.name, required this.url});

  final String name;
  final String url;
}

const officialPlanetPresets = <PlanetPreset>[
  PlanetPreset(name: 'Earth (Official)', url: 'https://sync.earth.planet'),
  PlanetPreset(name: 'Europa', url: 'https://sync.europa.planet'),
  PlanetPreset(name: 'Mars', url: 'https://sync.mars.planet'),
  PlanetPreset(name: 'Local Dev', url: 'http://10.0.2.2:8080'),
];
