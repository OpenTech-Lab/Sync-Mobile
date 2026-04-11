import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chats/widgets/message_bubble.dart';
import 'package:mobile/features/chats/models/outgoing_draft.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/models/local_chat_message.dart';

void main() {
  testWidgets(
    'tapping an attachment bubble opens the viewer with a download action',
    (tester) async {
      const transparentPngBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX2QAAAAASUVORK5CYII=';
      final message = LocalChatMessage(
        id: 'm1',
        conversationId: 'c1',
        senderId: 'me',
        body: 'caption\n[media-data:$transparentPngBase64]',
        createdAt: DateTime.utc(2026, 3, 12, 10, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: MessageBubble(
                  message: message,
                  isMine: true,
                  currentUserId: 'me',
                  partnerId: 'p1',
                  isRoomConversation: false,
                  stickers: const [],
                  serverUrl: 'https://example.com',
                  accessToken: 'token',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Attachment'), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Center),
          matching: find.byType(InteractiveViewer),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'failed outgoing message keeps retry control outside bubble on the left and tappable',
    (tester) async {
      var retryTapped = false;
      final message = LocalChatMessage(
        id: 'm2',
        conversationId: 'c1',
        senderId: 'me',
        body: 'failed draft message',
        createdAt: DateTime.utc(2026, 3, 13, 11, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: MessageBubble(
                  message: message,
                  isMine: true,
                  currentUserId: 'me',
                  partnerId: 'p1',
                  isRoomConversation: false,
                  stickers: const [],
                  serverUrl: 'https://example.com',
                  accessToken: 'token',
                  deliveryState: OutgoingDeliveryState.failed,
                  onRetryTap: () => retryTapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      final bubbleRect = tester.getRect(
        find.byKey(const ValueKey('message_bubble_surface')),
      );
      final statusRect = tester.getRect(
        find.byKey(const ValueKey('message_delivery_status')),
      );

      expect(statusRect.right, lessThanOrEqualTo(bubbleRect.left));

      await tester.tap(find.byKey(const ValueKey('message_delivery_status')));
      await tester.pump();

      expect(retryTapped, isTrue);
    },
  );
}
