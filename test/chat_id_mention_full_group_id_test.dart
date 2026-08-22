import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/chat_id_mention_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/common/utils.dart';

void main() {
  group('full community group id mention', () {
    const full =
        '@TGS#_@TGS#cL54PNMM62CN';
    const publicId = '@TGS#2HGQG6M5CD';
    const short = '@cL54PNMM62CN';

    test('chatIdMentionReg matches full community id as one span', () {
      final text = 'join $full please';
      final matches = LinkUtils.chatIdMentionReg.allMatches(text).toList();
      expect(matches, hasLength(1));
      expect(matches.single.group(0), full);
    });

    test('chatIdMentionReg matches public and short forms', () {
      expect(
        LinkUtils.chatIdMentionReg.firstMatch('x $publicId y')?.group(0),
        publicId,
      );
      expect(
        LinkUtils.chatIdMentionReg.firstMatch('x $short y')?.group(0),
        short,
      );
    });

    test('app regex stays aligned with UIKit', () {
      final text = 'see $full and $publicId';
      final app = ChatIdFormat.chatIdMentionInTextReg
          .allMatches(text)
          .map((m) => m.group(0))
          .toList();
      final uikit = LinkUtils.chatIdMentionReg
          .allMatches(text)
          .map((m) => m.group(0))
          .toList();
      expect(app, uikit);
      expect(app, <String>[full, publicId]);
    });

    test('wrap keeps full community id clickable', () {
      final wrapped = LinkUtils.wrapChatIdMentionsForExtendedText(
        'open $full now',
      );
      expect(wrapped.contains('${ChatIdMentionText.flag}$full${ChatIdMentionText.flag}'), isTrue);
      expect(wrapped.contains('@TGS${ChatIdMentionText.flag}'), isFalse);
    });

    test('parseRawId keeps leading @ for TGS ids', () {
      expect(ChatIdMentionText.parseRawId(full), full);
      expect(
        ChatIdMentionText.parseRawId('TGS#_@TGS#cL54PNMM62CN'),
        full,
      );
      expect(ChatIdMentionText.parseRawId('@alice_01'), 'alice_01');
    });

    test('isChatIdMentionToken accepts full community id', () {
      expect(ChatIdFormat.isChatIdMentionToken(full), isTrue);
      expect(ChatIdFormat.isChatIdMentionToken(publicId), isTrue);
      expect(ChatIdFormat.isChatIdMentionToken(short), isTrue);
    });
  });

  group('link/mention candidate gates (plan 006)', () {
    test('plain text without @ / url markers stays unchanged', () {
      const plain = '你好 hello world 今天天气不错';
      expect(LinkUtils.wrapChatIdMentionsForExtendedText(plain), plain);
      expect(LinkUtils.getURLMatches(plain), isEmpty);
    });

    test('mention wrap still detects @name', () {
      final wrapped = LinkUtils.wrapChatIdMentionsForExtendedText('hi @alice_01');
      expect(
        wrapped.contains(
          '${ChatIdMentionText.flag}@alice_01${ChatIdMentionText.flag}',
        ),
        isTrue,
      );
    });

    test('getURLMatches keeps http / https / mixed-case / www', () {
      expect(
        LinkUtils.getURLMatches('see http://example.com/a'),
        contains('http://example.com/a'),
      );
      expect(
        LinkUtils.getURLMatches('see https://example.com/b'),
        contains('https://example.com/b'),
      );
      expect(
        LinkUtils.getURLMatches('see HTTP://EXAMPLE.com/c'),
        isNotEmpty,
      );
      expect(
        LinkUtils.getURLMatches('see www.example.com/d'),
        isNotEmpty,
      );
    });

    test('mixed mention + url both survive', () {
      const text = 'ping @bob_02 and https://example.com/x';
      final wrapped = LinkUtils.wrapChatIdMentionsForExtendedText(text);
      expect(
        wrapped.contains(
          '${ChatIdMentionText.flag}@bob_02${ChatIdMentionText.flag}',
        ),
        isTrue,
      );
      expect(LinkUtils.getURLMatches(text), contains('https://example.com/x'));
    });

    test('lone @ and short garbage stay behavior-stable', () {
      expect(LinkUtils.wrapChatIdMentionsForExtendedText('just @'), 'just @');
      expect(LinkUtils.getURLMatches('htt'), isEmpty);
      expect(LinkUtils.getURLMatches('www'), isEmpty);
    });
  });
}
