import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_feed_body.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_feed_sync_gate.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_slidable.dart';

void main() {
  group('conversation feed scroll lifecycle', () {
    test('cached and active owners require a detach frame', () {
      expect(
        conversationFeedModeSwitchNeedsDetach(
          mounted: ConversationFeedMountMode.cached,
          desired: ConversationFeedMountMode.active,
        ),
        isTrue,
      );
      expect(
        conversationFeedModeSwitchNeedsDetach(
          mounted: ConversationFeedMountMode.active,
          desired: ConversationFeedMountMode.active,
        ),
        isFalse,
      );
      expect(
        conversationFeedModeSwitchNeedsDetach(
          mounted: null,
          desired: ConversationFeedMountMode.cached,
        ),
        isFalse,
      );
    });

    test('slidable releases on pointer cancel or tab deactivation', () {
      expect(
        conversationSlidableShouldRelease(
          wasTickerActive: true,
          tickerActive: false,
          pointerCanceled: false,
        ),
        isTrue,
      );
      expect(
        conversationSlidableShouldRelease(
          wasTickerActive: true,
          tickerActive: true,
          pointerCanceled: true,
        ),
        isTrue,
      );
      expect(
        conversationSlidableShouldRelease(
          wasTickerActive: false,
          tickerActive: true,
          pointerCanceled: false,
        ),
        isFalse,
      );
    });

    test('avatar warm range looks ahead in both scroll directions', () {
      final down = conversationAvatarWarmRange(
        offset: 720,
        viewportDimension: 720,
        rowExtent: 72,
        rowCount: 100,
        direction: 1,
        lookaheadRows: 16,
      );
      final up = conversationAvatarWarmRange(
        offset: 1440,
        viewportDimension: 720,
        rowExtent: 72,
        rowCount: 100,
        direction: -1,
        lookaheadRows: 16,
      );

      expect(down, (start: 20, end: 36));
      expect(up, (start: 4, end: 20));
    });
  });
}
