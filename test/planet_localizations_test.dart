import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('planet labels use corrected english copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Column(
              children: [
                Text(l10n.settingsMyPlanet.toUpperCase()),
                Text(l10n.planetNewsTitle.toUpperCase()),
              ],
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('MY PLANET'), findsOneWidget);
    expect(find.text('NEWS'), findsOneWidget);
    expect(find.textContaining('PLAENT'), findsNothing);
  });
}
