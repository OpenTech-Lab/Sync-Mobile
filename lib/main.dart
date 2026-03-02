import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/chat_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_controller.dart';

void main() {
  runApp(const ProviderScope(child: SyncMobileApp()));
}

class SyncMobileApp extends ConsumerWidget {
  const SyncMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStateAsync = ref.watch(appControllerProvider);

    return MaterialApp(
      title: 'Sync Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
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
                onSubmit: (email, password) =>
                    ref.read(appControllerProvider.notifier).login(
                          email: email,
                          password: password,
                        ),
              );
            case AppStage.home:
              return ChatHomeScreen(
                serverUrl: state.serverUrl!,
                accessToken: state.accessToken!,
                currentUserId: state.currentUserId!,
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
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
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
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to start app: $message',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
