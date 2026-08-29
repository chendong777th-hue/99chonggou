import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cold-open keeps one visible interactive chat tree', () {
    final source = File('lib/src/chat.dart').readAsStringSync();
    final wrapperStart = source.indexOf('_wrapChatWithOpenHistoryGate(');
    final wrapperEnd =
        source.indexOf('_seedSelfMemberFromLocalStore(', wrapperStart);
    expect(wrapperStart, greaterThanOrEqualTo(0));
    expect(wrapperEnd, greaterThan(wrapperStart));
    final wrapper = source.substring(wrapperStart, wrapperEnd);

    expect(wrapper.contains('AbsorbPointer'), isFalse);
    expect(wrapper.contains('FutureBuilder'), isFalse);
    expect(wrapper.contains('return chatWidget;'), isTrue);
    expect(source.contains('_buildChatHistoryGateShell'), isFalse);
    expect(source.contains('ChatMessageListSkeleton'), isFalse);
    expect(source.contains('Offstage('), isFalse);
  });

  test('open history gate always soft-timeouts preparation (thin + cold)', () {
    final source = File('lib/src/chat.dart').readAsStringSync();

    // Thin window must not await preparation without timeout (scroll lock forever).
    expect(source.contains('history_gate_thin_timeout_1_2s'), isTrue);
    expect(source.contains('history_gate_timeout_1_2s'), isTrue);
    expect(source.contains('history_gate_tips_merge_timeout'), isTrue);

    final runner = source.indexOf('_runOpenHistoryGateWithTipsMerge');
    expect(runner, greaterThanOrEqualTo(0));
    final body = source.substring(runner, runner + 1800);
    expect(body.contains('preparation.timeout('), isTrue);
    // Old thin path: bare `await preparation;` without timeout — must be gone.
    expect(
      RegExp(r'else\s*\{\s*await preparation;\s*\}').hasMatch(body),
      isFalse,
    );
  });
}
