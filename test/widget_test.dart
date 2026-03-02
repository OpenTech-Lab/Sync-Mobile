import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:mobile/screens/onboarding_screen.dart';
import 'package:mobile/state/app_controller.dart';

void main() {
  testWidgets('shows onboarding content', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          initialUrl: '',
          connectionStatus: ConnectionStatus.idle,
          errorMessage: null,
          onValidate: (_) async {},
          onContinue: (_) async {},
        ),
      ),
    );

    expect(find.text('Connect to your planet'), findsOneWidget);
    expect(find.text('Validate connection'), findsOneWidget);
  });
}
