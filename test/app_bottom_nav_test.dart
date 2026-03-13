import 'package:flutter/cupertino.dart';
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
    expect(find.byIcon(CupertinoIcons.house), findsOneWidget);
    expect(
      find.byIcon(CupertinoIcons.bubble_left_bubble_right_fill),
      findsOneWidget,
    );
    expect(find.byIcon(CupertinoIcons.globe), findsOneWidget);
    expect(find.text('settings'), findsNothing);
    expect(find.text('CHATS'), findsOneWidget);
  });

  testWidgets('bottom nav animates selection when a new tab is tapped', (
    tester,
  ) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              bottomNavigationBar: AppBottomNav(
                selectedIndex: selectedIndex,
                onTap: (index) => setState(() => selectedIndex = index),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.house_fill), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.globe));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('PLANET'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.globe), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.house), findsOneWidget);
  });
}
