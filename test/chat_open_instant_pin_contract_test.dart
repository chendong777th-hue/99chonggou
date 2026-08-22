import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract: entering chat must pin with jump, not smooth animateTo.
void main() {
  test('open pin uses instant jump instead of smooth animate', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();

    final scrollFn = source.indexOf('void _scrollToBottomTarget(');
    expect(scrollFn, greaterThanOrEqualTo(0));
    final nextFn = source.indexOf('void _startRowRevealTransaction(', scrollFn);
    final body = source.substring(scrollFn, nextFn);
    expect(body.contains('scroll_to_bottom_instant_open'), isTrue);
    expect(body.contains('_isInitialRouteSettleWindow'), isTrue);
    expect(body.contains('_isPostRevealMicroSuppressWindow'), isTrue);
    expect(body.contains('_historyOpenRevealPainted'), isTrue);

    final commit = source.indexOf('void _commitHistoryOpenRevealReady({');
    expect(commit, greaterThanOrEqualTo(0));
    final commitEnd = source.indexOf(
      'void _armHistoryOpenRevealWaitBudget(',
      commit,
    );
    final commitBody = source.substring(commit, commitEnd);
    final readyAssign = commitBody.indexOf('_historyOpenRevealReady = true');
    expect(readyAssign, greaterThanOrEqualTo(0));
    final afterReady = commitBody.substring(readyAssign);
    final jumpIdx = afterReady.indexOf('_pinScrollToBottomImmediate()');
    final paintedIdx = afterReady.indexOf('_historyOpenRevealPainted = true');
    expect(jumpIdx, greaterThanOrEqualTo(0));
    expect(paintedIdx, greaterThan(jumpIdx));
  });
}
