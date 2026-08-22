import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

V2TimConversation _c2c(int index) {
  return V2TimConversation(
    conversationID: 'c2c_$index',
    userID: '$index',
    type: 1,
  );
}

void main() {
  late ConversationListNotifier notifier;

  setUp(() {
    notifier = ConversationListNotifier.instance;
    notifier.clearSession();
  });

  tearDown(() {
    notifier.clearSession();
  });

  test('cached type-index row survives after hydrate window moves', () {
    notifier.setTypeHydrateForTest(
      convType: 1,
      start: 0,
      total: 6,
      page: <V2TimConversation>[_c2c(0), _c2c(1), _c2c(2)],
    );

    expect(notifier.conversationAtTypeIndex(1, 1)?.conversationID, 'c2c_1');

    notifier.setTypeHydrateForTest(
      convType: 1,
      start: 3,
      total: 6,
      page: <V2TimConversation>[_c2c(3), _c2c(4), _c2c(5)],
    );

    expect(notifier.conversationAtTypeIndex(1, 1)?.conversationID, 'c2c_1');
    expect(notifier.conversationAtTypeIndex(1, 4)?.conversationID, 'c2c_4');
  });
}
