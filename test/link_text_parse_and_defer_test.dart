import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/deferred_hyperlink_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/link_text_parse_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_hyperlink_text_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/chat_id_mention_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/common/utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/widgets/link_text.dart';

void main() {
  final parseCache = LinkTextParseCache.instance;
  final hyperlinkCache = MessageHyperlinkTextCache.instance;

  setUp(() {
    parseCache.clear();
    hyperlinkCache.clear();
  });
  tearDown(() {
    parseCache.clear();
    hyperlinkCache.clear();
  });

  testWidgets('LinkText second build hits flagged parse cache', (tester) async {
    const text = 'see https://example.com/a and @alice_01';
    void onMention(String _) {}

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkText(
            messageText: text,
            onTapChatIdMention: onMention,
          ),
        ),
      ),
    );
    expect(parseCache.flaggedMisses, 1);
    expect(parseCache.flaggedHits, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkText(
            messageText: text,
            onTapChatIdMention: onMention,
          ),
        ),
      ),
    );
    expect(parseCache.flaggedMisses, 1);
    expect(parseCache.flaggedHits, 1);
  });

  test('wrap and getURLMatches reuse cache for identical text', () {
    const text = 'hi @alice_01 see https://example.com/x';
    final firstWrap = LinkUtils.wrapChatIdMentionsForExtendedText(text);
    final secondWrap = LinkUtils.wrapChatIdMentionsForExtendedText(text);
    expect(identical(firstWrap, secondWrap), isTrue);
    expect(parseCache.wrappedMisses, 1);
    expect(parseCache.wrappedHits, 1);

    final firstUrls = LinkUtils.getURLMatches(text);
    final secondUrls = LinkUtils.getURLMatches(text);
    expect(firstUrls, secondUrls);
    expect(parseCache.urlMisses, 1);
    expect(parseCache.urlHits, 1);
    expect(firstWrap.contains(ChatIdMentionText.flag), isTrue);
  });

  testWidgets(
      'MessageHyperlinkTextCache callback change still shares parse cache',
      (tester) async {
    const text = 'tap https://example.com/z';
    final first = hyperlinkCache.getOrCreate(
      messageKey: 'm1',
      messageText: text,
      isMarkdown: false,
      onTapChatIdMention: (_) {},
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: first(style: const TextStyle()))),
    );
    final missesAfterFirst = parseCache.flaggedMisses;

    final second = hyperlinkCache.getOrCreate(
      messageKey: 'm1',
      messageText: text,
      isMarkdown: false,
      onTapChatIdMention: (_) {},
    );
    expect(identical(first, second), isFalse);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: second(style: const TextStyle()))),
    );
    expect(parseCache.flaggedMisses, missesAfterFirst);
    expect(parseCache.flaggedHits, greaterThan(0));
  });

  testWidgets('DeferredHyperlinkText enriches after first frame', (tester) async {
    var ready = false;
    var enrichBuilderCalls = 0;
    const text = 'hello https://example.com/defer';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeferredHyperlinkText(
            identity: 'msg-1\u0000$text',
            displayText: text,
            textStyle: const TextStyle(fontSize: 16),
            onReadyChanged: (value) => ready = value,
            buildEnriched: () {
              enrichBuilderCalls++;
              return ({TextStyle? style}) => LinkText(
                    messageText: text,
                    style: style,
                  );
            },
          ),
        ),
      ),
    );

    // Test binding may flush post-frame callbacks inside pumpWidget; ensure
    // at least one more pump so enrich is applied, then assert outcomes.
    await tester.pump();

    final state = tester.state<DeferredHyperlinkTextState>(
      find.byType(DeferredHyperlinkText),
    );
    expect(state.isHyperlinkReady, isTrue);
    expect(ready, isTrue);
    expect(enrichBuilderCalls, greaterThan(0));
    expect(parseCache.flaggedMisses, greaterThan(0));
  });
}
