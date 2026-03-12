import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chats/widgets/composer.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/ui/tokens/colors/app_palette.dart';

void main() {
  testWidgets(
    'composer send button is prominent and has a large tappable area',
    (tester) async {
      final controller = TextEditingController(text: 'hello');
      addTearDown(controller.dispose);

      var sendCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Composer(
              messageController: controller,
              selectedMediaBytes: null,
              selectedMediaName: null,
              stickers: const [],
              onChanged: (_) {},
              onSend: () => sendCount += 1,
              onPickMedia: () {},
              onClearMedia: () {},
              onStickerSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sendButton = find.byKey(const ValueKey('composer_send_button'));
      expect(sendButton, findsOneWidget);

      final buttonMaterial = tester.widget<Material>(sendButton);
      expect(buttonMaterial.color, AppPalette.neutral800);

      final rect = tester.getRect(sendButton);
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(rect.height, greaterThanOrEqualTo(48));

      final icon = tester.widget<Icon>(
        find.descendant(
          of: sendButton,
          matching: find.byIcon(Icons.arrow_upward_rounded),
        ),
      );
      expect(icon.size, 24);
      expect(icon.color, AppPalette.white);

      await tester.tapAt(Offset(rect.right - 6, rect.center.dy));
      await tester.pump();

      expect(sendCount, 1);
    },
  );
}
