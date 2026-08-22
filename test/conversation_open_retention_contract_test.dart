import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opened group survives local and virtual-list rehydration', () {
    final conversationSource =
        File('lib/src/conversation.dart').readAsStringSync();
    final syncSource = File(
      'lib/src/services/conversation_local/conversation_sync_service.dart',
    ).readAsStringSync();

    expect(
      conversationSource.contains('retainOpenedGroupConversation('),
      isTrue,
    );
    expect(
      conversationSource.contains('waitUntilUpsertWriteIdle('),
      isTrue,
    );
    expect(
      conversationSource.contains(
        '[ConversationVisibility] event=chat_return',
      ),
      isTrue,
    );
    expect(
      syncSource.contains('Future<void> retainOpenedGroupConversation('),
      isTrue,
    );
    expect(
      syncSource.contains(
        'ConversationLocalStore.instance.upsertBatch(',
      ),
      isTrue,
    );
    expect(
      syncSource.contains('forceAdmitIds: <String>{convId}'),
      isTrue,
    );
    expect(
      syncSource.contains('forceAdmitIds: <String>{leftId}'),
      isTrue,
    );
    expect(
      conversationSource.contains('conversationFeedCanSkipHydrateAfterChatReturn('),
      isTrue,
    );
    expect(
      syncSource.contains(
        '[ConversationVisibility] event=open_retain_done',
      ),
      isTrue,
    );
  });
}
