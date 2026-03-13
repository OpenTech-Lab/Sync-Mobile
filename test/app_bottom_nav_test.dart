import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/ui/components/organisms/app_bottom_nav.dart';

void main() {
  testWidgets('bottom nav renders only home, chats, and planet tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(selectedIndex: 1, onTap: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GestureDetector), findsNWidgets(3));
    expect(find.text('home'), findsOneWidget);
    expect(find.text('planet'), findsOneWidget);
    expect(find.text('settings'), findsNothing);
  });
}
