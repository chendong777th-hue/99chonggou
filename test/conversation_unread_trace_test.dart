import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_unread_trace.dart';

void main() {
  test('ConversationUnreadTrace formats release log line', () {
    expect(
      ConversationUnreadTrace.formatLineForTest(
        'clear_local_open_fast',
        conversationID: 'group_g1',
        unreadBefore: 3,
        unreadAfter: 0,
      ),
      'UnreadTrace event=clear_local_open_fast conv=group_g1 unreadBefore=3 unreadAfter=0',
    );
  });
}
