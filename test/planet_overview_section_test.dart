import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/planet/widgets/planet_overview_section.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/services/server_health_service.dart';
import 'package:mobile/ui/tokens/colors/app_palette.dart';

void main() {
  testWidgets('planet overview section shows the moved my planet summary', (
    tester,
  ) async {
    final planetInfo = PlanetInfo(
      baseUrl: 'https://example.com',
      host: 'example.com',
      scheme: 'https',
      instanceName: 'Example Planet',
      instanceDescription: 'A quiet place for testing.',
      instanceImageUrl: null,
      memberCount: 3147,
      linkedPlanets: const <String>[],
      instanceDomain: 'example.com',
      countryCode: 'JP',
      countryName: 'Japan',
      serverCreatedAt: DateTime.utc(2026, 3, 1),
      healthStatus: 'ok',
      latencyMs: 25,
      checkedAt: DateTime.utc(2026, 3, 13, 12, 0),
      registrationRequiresApproval: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PlanetOverviewSection(
            planetInfo: planetInfo,
            stickerCount: 12,
            isConnected: true,
            notificationsActive: true,
            inkColor: AppPalette.neutral800,
            ruleColor: AppPalette.neutral300,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MY PLANET'), findsOneWidget);
    expect(find.text('Example Planet'), findsOneWidget);
    expect(find.text('3147'), findsOneWidget);
    expect(find.text('residents'), findsOneWidget);
  });
}
