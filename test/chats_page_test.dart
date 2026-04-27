import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chats/chat_target_profile_page.dart';
import 'package:mobile/features/chats/chats_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/services/local_chat_repository.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/conversation_messages_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppController extends AppController {
  @override
  Future<AppState> build() async {
    return const AppState(
      serverUrl: 'https://example.com',
      accessToken: 'token',
      currentUserId: 'owner-id',
      currentUsername: 'owner',
      savedUserId: 'owner-id',
      connectionStatus: ConnectionStatus.idle,
      connectionError: null,
      planetInfo: null,
      isSubmitting: false,
      authError: null,
    );
  }

  @override
  Future<String?> ensureFreshAccessToken() async => 'token';
}

class _AutoPopProfileObserver extends NavigatorObserver {
  bool _handled = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_handled || previousRoute == null) {
      return;
    }
    _handled = true;
    scheduleMicrotask(() {
      route.navigator?.pop(ChatTargetProfileAction.blockUser);
    });
  }
}

void main() {
  testWidgets('blocking from active chat clears the shell partner selection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final partnerChanges = <String?>[];
    final navigatorObserver = _AutoPopProfileObserver();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(_FakeAppController.new),
          chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
        ],
        child: MaterialApp(
          navigatorObservers: [navigatorObserver],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatsTab(
              serverUrl: 'https://example.com',
              accessToken: 'token',
              currentUserId: 'owner-id',
              initialPartnerId: 'friend-a',
              onPartnerChanged: partnerChanges.add,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(partnerChanges, contains('friend-a'));
    expect(find.text('friend-a'), findsWidgets);

    await tester.tap(find.text('friend-a').first);
    await tester.pumpAndSettle();

    expect(partnerChanges.last, isNull);
  });

  testWidgets('direct chat keeps call buttons visible on Linux desktop', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(_FakeAppController.new),
          chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatsTab(
              serverUrl: 'https://example.com',
              accessToken: 'token',
              currentUserId: 'owner-id',
              initialPartnerId: 'friend-a',
              onPartnerChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final voiceButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.call_outlined),
    );
    final videoButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.videocam_outlined),
    );

    expect(voiceButton.onPressed, isNull);
    expect(videoButton.onPressed, isNull);
    expect(find.byIcon(Icons.call_outlined), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });
}
