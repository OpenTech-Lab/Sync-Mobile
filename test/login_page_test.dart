import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'allows sign in after ALTCHA resolves without a pre-login terms checkbox',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var autoLoginCalls = 0;
      String? capturedAltchaPayload = 'unset';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: LoginScreen(
              serverUrl: 'https://example.com',
              savedUserId: 'user-1',
              isSubmitting: false,
              errorMessage: null,
              altchaFetcher: () async => null,
              onAutoLogin: ({altchaPayload}) async {
                autoLoginCalls += 1;
                capturedAltchaPayload = altchaPayload;
              },
              onBackToUrl: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('I agree to the Terms of Use and Safety Policy.'),
        findsNothing,
      );

      await tester.tap(find.text('S I G N   I N'));
      await tester.pump();

      expect(autoLoginCalls, 1);
      expect(capturedAltchaPayload, isNull);
    },
  );
}
