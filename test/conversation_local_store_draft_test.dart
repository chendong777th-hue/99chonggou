import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

V2TimConversation _conversation({required String id}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
  );
}

void main() {
  group('ConversationLocalStore local draft', () {
    test('normalizeDraftText trims and removes zero-width spaces', () {
      expect(
        ConversationLocalStore.normalizeDraftTextForTest(' \ufeff hello '),
        'hello',
      );
    });

    test('applyLocalDraftToConversation sets and clears draft fields', () {
      final conversation = _conversation(id: 'c2c_a');
      ConversationLocalStore.applyLocalDraftToConversation(
        conversation,
        text: 'draft body',
        updatedAtMs: 1719000000000,
      );
      expect(conversation.draftText, 'draft body');
      expect(conversation.draftTimestamp, 1719000000);

      ConversationLocalStore.applyLocalDraftToConversation(
        conversation,
        text: '',
        updatedAtMs: 0,
      );
      expect(conversation.draftText, isNull);
      expect(conversation.draftTimestamp, isNull);
    });

    test('preserved local draft survives sdk incoming without draft', () {
      final incoming = _conversation(id: 'c2c_a');
      incoming.draftText = 'sdk draft';
      incoming.draftTimestamp = 100;

      ConversationLocalStore.instance.applyPreservedLocalDraftForTest(
        incoming,
        preservedLocalDraftText: 'local draft',
        preservedLocalDraftUpdatedAtMs: 1719000000000,
      );

      expect(incoming.draftText, 'local draft');
      expect(incoming.draftTimestamp, 1719000000);
    });

    test('empty local draft clears draft on conversation object', () {
      final conversation = _conversation(id: 'c2c_peer');
      conversation.draftText = 'sdk draft';
      conversation.draftTimestamp = 123;

      ConversationLocalStore.applyLocalDraftToConversation(
        conversation,
        text: '',
        updatedAtMs: 0,
      );

      expect(conversation.draftText, isNull);
      expect(conversation.draftTimestamp, isNull);
    });

    test('active time prefers local draft timestamp', () {
      final conversation = _conversation(id: 'c2c_a');
      conversation.lastMessage = null;
      conversation.orderkey = 100;

      final active = ConversationLocalStore.activeTimeForPersistedRowForTest(
        conversation,
        localDraftText: 'draft',
        localDraftUpdatedAtMs: 1719000000000,
      );

      expect(active, 1719000000000);
    });
  });
}
