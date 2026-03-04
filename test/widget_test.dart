import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:mobile/state/app_controller.dart';

void main() {
  testWidgets('shows onboarding content', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          initialUrl: '',
          connectionStatus: ConnectionStatus.idle,
          errorMessage: null,
          planetInfo: null,
          onValidate: (_) async {},
          onContinue: (_) async {},
        ),
      ),
    );

    expect(find.text('Welcome to Sync'), findsOneWidget);
    expect(find.text('C H E C K   C O N N E C T I O N'), findsOneWidget);
  });
}
