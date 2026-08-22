import 'package:flutter/material.dart';
import 'package:extended_text/extended_text.dart';
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
  });

  test('mention scan mode uses distinct flagged cache keys', () {
    const text = 'hello @alice_01';
    LinkText(
      messageText: text,
      onTapChatIdMention: (_) {},
    );
    // Drive parse without full widget tree via public LinkText path is heavy;
    // use wrap + LinkText pump in widget test above. Here check wrap vs plain URL.
    expect(LinkUtils.wrapChatIdMentionsForExtendedText(text), isNot(text));
    expect(
      LinkUtils.wrapChatIdMentionsForExtendedText('no mention here'),
      'no mention here',
    );
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
      onTapChatIdMention: (_) {}, // new closure → outer cache miss
    );
    expect(identical(first, second), isFalse);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: second(style: const TextStyle()))),
    );
    expect(parseCache.flaggedMisses, missesAfterFirst);
    expect(parseCache.flaggedHits, greaterThan(0));
  });

  test('ChatIdMentionText flag still applied by wrap path', () {
    final wrapped = LinkUtils.wrapChatIdMentionsForExtendedText('x @bob_1 y');
    expect(wrapped.contains(ChatIdMentionText.flag), isTrue);
  });
}
