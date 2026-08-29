import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_open_perf_log.dart';

void main() {
  tearDown(() {
    ChatOpenPerfLog.debugSink = null;
  });

  test('emits milestones and summary without raw identifiers', () {
    final lines = <String>[];
    ChatOpenPerfLog.debugSink = lines.add;

    ChatOpenPerfLog.beginOpen(
      conversationID: 'c2c_user_private_123',
      phase: 'conv_item_tap',
      extras: const <String, Object?>{
        'rawConvID': 'c2c_user_private_123',
      },
    );
    ChatOpenPerfLog.markMessagesFirstVisible(
      conversationID: 'c2c_user_private_123',
      messageCount: 3,
    );

    expect(lines, hasLength(3));
    expect(lines[0], contains('[ChatOpenPerf] event=session_begin'));
    expect(lines[1], contains('event=messages_first_visible'));
    expect(lines[2], contains('event=open_summary'));
    expect(lines[2], contains('region=⑧打开汇总'));
    expect(lines[2], contains('session=open_'));
    expect(lines[2], contains('totalMs='));
    expect(lines.join('\n'), isNot(contains('c2c_user_private_123')));
    expect(lines.join('\n'), contains('convHash='));
  });

  test('does not emit an empty-message milestone', () {
    final lines = <String>[];
    ChatOpenPerfLog.debugSink = lines.add;

    ChatOpenPerfLog.beginOpen(
      conversationID: 'empty_conversation',
      phase: 'conv_item_tap',
    );
    ChatOpenPerfLog.markMessagesFirstVisible(
      conversationID: 'empty_conversation',
      messageCount: 0,
    );

    expect(lines, hasLength(1));
    expect(lines.single, contains('event=session_begin'));
  });
}
