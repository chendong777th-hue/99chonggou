import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conversation live badge stays single-line and not width-locked to avatar',
      () {
    final source = File(
      'lib/src/widgets/group_live/group_live_conversation_badge.dart',
    ).readAsStringSync();

    // Former bug: Positioned(left:0, right:0) capped chip to avatar width → wrap.
    final wrapAt = source.indexOf('class GroupLiveConversationListAvatarWrap');
    expect(wrapAt, greaterThanOrEqualTo(0));
    final wrapBody = source.substring(wrapAt, wrapAt + 1600);
    expect(wrapBody.contains('left: 0'), isFalse);
    expect(wrapBody.contains('right: 0'), isFalse);
    expect(wrapBody.contains('clipBehavior: Clip.none'), isTrue);

    final badgeAt = source.indexOf('class GroupLiveConversationBadge');
    expect(badgeAt, greaterThanOrEqualTo(0));
    final badgeBody = source.substring(badgeAt, badgeAt + 2200);
    expect(badgeBody.contains('maxLines: 1'), isTrue);
    expect(badgeBody.contains('softWrap: false'), isTrue);
    expect(badgeBody.contains('withNoTextScaling'), isTrue);
  });
}
