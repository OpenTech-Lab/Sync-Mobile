import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const ProviderScope(child: SyncMobileApp()));
}

class SyncMobileApp extends ConsumerWidget {
  const SyncMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStateAsync = ref.watch(appControllerProvider);

    return MaterialApp(
      title: 'Sync',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
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
                isSubmitting: state.isSubmitting,
                errorMessage: state.authError,
                onSignIn: (email, password) =>
                    ref.read(appControllerProvider.notifier).login(
                          email: email,
                          password: password,
                        ),
                onSignUp: (username, email, password) =>
                    ref.read(appControllerProvider.notifier).signUp(
                          username: username,
                          email: email,
                          password: password,
                        ),
                onBackToUrl: () => ref
                    .read(appControllerProvider.notifier)
                    .resetServerUrl(),
              );
            case AppStage.home:
              return MainShell(
                serverUrl: state.serverUrl!,
                accessToken: state.accessToken!,
                currentUserId: state.currentUserId!,
                onSignOut:
                    ref.read(appControllerProvider.notifier).logout,
              );
          }
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5), // indigo-600
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(size: 22),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync,
                size: 48,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
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
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Failed to start: $message',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
