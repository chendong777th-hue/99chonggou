import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_main_thread_perf.dart';

void main() {
  tearDown(() {
    ChatMainThreadPerf.debugForceEnabled = false;
    ChatMainThreadPerf.debugSink = null;
  });

  test('probe is disabled by default', () {
    expect(ChatMainThreadPerf.isEnabled, isFalse);
  });

  test('probe emits only bounded diagnostic fields', () {
    final lines = <String>[];
    ChatMainThreadPerf.debugForceEnabled = true;
    ChatMainThreadPerf.debugSink = lines.add;

    final result = ChatMainThreadPerf.measure(
      ChatMainThreadPerf.historyMergeMs,
      () => 7,
      count: 20,
      source: 'cloud newer/unsafe-id',
      conversationType: 'group',
    );

    expect(result, 7);
    expect(lines, hasLength(1));
    expect(lines.single, contains('metric=history_merge_ms'));
    expect(lines.single, contains('count=20'));
    expect(lines.single, contains('source=cloud_newer_unsafe-id'));
    expect(lines.single, contains('convType=group'));
    expect(lines.single, isNot(contains('token=')));
  });

  test('all six metric names stay stable', () {
    expect(
      <String>{
        ChatMainThreadPerf.historyMergeMs,
        ChatMainThreadPerf.setMessageListMs,
        ChatMainThreadPerf.groupMetadataApplyMs,
        ChatMainThreadPerf.conversationReloadMs,
        ChatMainThreadPerf.imageDecodeMs,
        ChatMainThreadPerf.keyboardLayoutMs,
      },
      hasLength(6),
    );
  });
}
