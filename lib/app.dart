import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile/l10n/app_localizations.dart';

import 'ui/theme/dark_theme.dart';
import 'ui/theme/light_theme.dart';
import 'features/auth/login_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/shell/main_shell.dart';
import 'state/app_controller.dart';
import 'state/app_locale_controller.dart';
import 'state/theme_mode_controller.dart';

class SyncMobileApp extends ConsumerWidget {
  const SyncMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStateAsync = ref.watch(appControllerProvider);
    final selectedLocale = ref.watch(appLocaleProvider).toLocale();

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ref.watch(themeModeProvider),
      locale: selectedLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh'), Locale('zh', 'TW')],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (selectedLocale != null) {
          return selectedLocale;
        }
        if (deviceLocale == null) {
          return const Locale('en');
        }
        for (final locale in supportedLocales) {
          if (locale.languageCode == deviceLocale.languageCode &&
              (locale.countryCode == null ||
                  locale.countryCode == deviceLocale.countryCode)) {
            return locale;
          }
        }
        return const Locale('en');
      },
      home: appStateAsync.when(
        loading: () => const _LoadingScreen(),
        error: (error, _) => _ErrorScreen(message: error.toString()),
        data: (state) {
          switch (state.stage) {
            case AppStage.onboarding:
              return OnboardingScreen(
                initialUrl: state.serverUrl,
                connectionStatus: state.connectionStatus,
                errorMessage: state.connectionError,
                planetInfo: state.planetInfo,
                onValidate: (url) => ref
                    .read(appControllerProvider.notifier)
                    .validateServer(url),
                onContinue: (url) => ref
                    .read(appControllerProvider.notifier)
                    .completeOnboarding(url),
              );
            case AppStage.login:
              return LoginScreen(
                serverUrl: state.serverUrl!,
                savedUserId: state.savedUserId,
                isSubmitting: state.isSubmitting,
                errorMessage: state.authError,
                onAutoLogin: () => ref
                    .read(appControllerProvider.notifier)
                    .loginWithDeviceIdentity(),
                onBackToUrl: () =>
                    ref.read(appControllerProvider.notifier).resetServerUrl(),
              );
            case AppStage.home:
              return MainShell(
                serverUrl: state.serverUrl!,
                accessToken: state.accessToken!,
                currentUserId: state.currentUserId!,
                currentUsername: state.currentUsername,
                planetInfo: state.planetInfo,
                onSignOut: ref.read(appControllerProvider.notifier).logout,
              );
          }
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1C19) : const Color(0xFFFAF9F6);
    const muted = Color(0xFF8A8680);
    final ruleColor = isDark
        ? const Color(0xFF3A3730)
        : const Color(0xFFDDD8CF);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 56,
              height: 56,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                minHeight: 1,
                backgroundColor: ruleColor,
                valueColor: const AlwaysStoppedAnimation<Color>(muted),
                borderRadius: BorderRadius.zero,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.loadingSync,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2.8,
                fontWeight: FontWeight.w300,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1C19) : const Color(0xFFFAF9F6);
    final inkColor = isDark ? const Color(0xFFE8E4DC) : const Color(0xFF2C2A27);
    const muted = Color(0xFF8A8680);
    const red = Color(0xFF9B3A2A);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.errorTitle,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.8,
                  fontWeight: FontWeight.w400,
                  color: red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: inkColor,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.restartAppHint,
                style: TextStyle(
                  fontSize: 12,
                  color: muted,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
