import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract: adopt/swap must collapse optimistic + orphan SDK echo into one
/// bubble (一图两气泡). See plans/018-outgoing-image-dual-bubble.md.
void main() {
  test('swapOutgoingMessage collapses same-send rows before replace set', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();

    final swapStart = source.indexOf('void _swapOutgoingMessage({');
    expect(swapStart, greaterThanOrEqualTo(0));
    final swapEnd = source.indexOf('void _removeOutgoingMessage({', swapStart);
    expect(swapEnd, greaterThan(swapStart));
    final swapBody = source.substring(swapStart, swapEnd);

    expect(swapBody.contains('readOutgoingStableId'), isTrue);
    expect(swapBody.contains('isSameSend'), isTrue);
    expect(swapBody.contains('setMessageList(convID, next, replace: true)'),
        isTrue);
    expect(swapBody.contains('list.insert(0, newMessage)'), isFalse);
  });

  test('outgoing correlation prefers stable id over random/id', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'view_models/tui_chat_global_model.dart',
    ).readAsStringSync();

    final keyStart = source.indexOf('static String? _outgoingCorrelationKey(');
    expect(keyStart, greaterThanOrEqualTo(0));
    final keyEnd = source.indexOf('static bool _isClientPlaceholderMessage(', keyStart);
    final keyBody = source.substring(keyStart, keyEnd);
    final stableIdx = keyBody.indexOf('readOutgoingStableId');
    final randomIdx = keyBody.indexOf('_outgoingRandomValue');
    expect(stableIdx, greaterThanOrEqualTo(0));
    expect(randomIdx, greaterThan(stableIdx));
    expect(keyBody.contains("'stable:\$stableId:t"), isTrue);

    final findStart = source.indexOf('static int _findOutgoingPlaceholderIndex(');
    expect(findStart, greaterThanOrEqualTo(0));
    final findEnd = source.indexOf(
      'void bindOutgoingSyncMsgId(',
      findStart,
    );
    final findBody = source.substring(findStart, findEnd);
    expect(findBody.contains('readOutgoingStableId(incoming)'), isTrue);
    expect(findBody.contains('incoming.imageElem?.path'), isTrue);
  });
}
