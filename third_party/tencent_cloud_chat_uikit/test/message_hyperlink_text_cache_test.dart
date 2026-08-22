import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_hyperlink_text_cache.dart';

void main() {
  final cache = MessageHyperlinkTextCache.instance;

  setUp(cache.clear);
  tearDown(cache.clear);

  test('reuses the builder while callbacks are unchanged', () {
    void onMention(String _) {}
    void onLink(String _) {}

    final first = cache.getOrCreate(
      messageKey: 'message-1',
      messageText: '@shortAlias',
      isMarkdown: false,
      onLinkTap: onLink,
      onTapChatIdMention: onMention,
    );
    final second = cache.getOrCreate(
      messageKey: 'message-1',
      messageText: '@shortAlias',
      isMarkdown: false,
      onLinkTap: onLink,
      onTapChatIdMention: onMention,
    );

    expect(identical(first, second), isTrue);
  });

  testWidgets('rebuilds with the latest mention callback', (tester) async {
    var oldCallbackCount = 0;
    var newCallbackCount = 0;

    final oldBuilder = cache.getOrCreate(
      messageKey: 'message-1',
      messageText: '@shortAlias',
      isMarkdown: false,
      onTapChatIdMention: (_) => oldCallbackCount++,
    );
    final newBuilder = cache.getOrCreate(
      messageKey: 'message-1',
      messageText: '@shortAlias',
      isMarkdown: false,
      onTapChatIdMention: (_) => newCallbackCount++,
    );

    expect(identical(oldBuilder, newBuilder), isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: newBuilder(style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
    await tester.tap(find.textContaining('@shortAlias'));
    await tester.pump();

    expect(oldCallbackCount, 0);
    expect(newCallbackCount, 1);
  });
}
