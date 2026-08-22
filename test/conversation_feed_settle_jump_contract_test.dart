import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scroll_end hydrate jumps only via settle jump flag', () {
    final conversation = File('lib/src/conversation.dart').readAsStringSync();
    expect(
      conversation.contains('conversationVirtualHydrateShouldJumpWindow('),
      isTrue,
    );
    expect(conversation.contains('allowWindowJump: jump'), isTrue);
    expect(conversation.contains('forceReload: jump'), isTrue);
    expect(conversation.contains('forceNotify: force'), isTrue);

    final hydrateStart = conversation.indexOf(
      'void _requestVirtualHydrateForFeedScroll({',
    );
    final hydrateEnd = conversation.indexOf(
      'void _scheduleVirtualFeedHydrateAfterChatReturn(',
    );
    expect(hydrateStart, greaterThanOrEqualTo(0));
    expect(hydrateEnd, greaterThan(hydrateStart));
    final settleSite = conversation.substring(hydrateStart, hydrateEnd);
    expect(settleSite.contains('allowWindowJump: true'), isFalse);
    expect(settleSite.contains('allowWindowJump: jump'), isTrue);
  });

  test('hydrate covered-skip notifies on settle', () {
    final notifier = File(
      'lib/src/services/conversation_local/conversation_list_notifier.dart',
    ).readAsStringSync();
    expect(notifier.contains('bool forceNotify = false'), isTrue);
    expect(notifier.contains('hydrate_settle_covered'), isTrue);
    expect(
      notifier.contains('conversationVirtualHydrateShouldNotifyOnCoveredSkip('),
      isTrue,
    );
  });
}
