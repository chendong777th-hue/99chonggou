import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

void main() {
  test('lightweight fingerprint flag defaults on', () {
    expect(ConversationPerfFlags.useLightweightFingerprint, isTrue);
  });

  test('lightweight fingerprint is stable for same content', () {
    final a = V2TimConversation(
      conversationID: 'c2c_u1',
      type: 1,
      userID: 'u1',
      showName: 'Alice',
      unreadCount: 2,
      orderkey: 9,
    );
    final b = V2TimConversation(
      conversationID: 'c2c_u1',
      type: 1,
      userID: 'u1',
      showName: 'Alice',
      unreadCount: 2,
      orderkey: 9,
    );
    expect(
      ConversationLocalStore.lightweightContentFingerprintForTest(a),
      ConversationLocalStore.lightweightContentFingerprintForTest(b),
    );
  });

  test('lightweight fingerprint changes when unread changes', () {
    final base = V2TimConversation(
      conversationID: 'c2c_u1',
      type: 1,
      userID: 'u1',
      unreadCount: 1,
    );
    final changed = V2TimConversation(
      conversationID: 'c2c_u1',
      type: 1,
      userID: 'u1',
      unreadCount: 2,
    );
    expect(
      ConversationLocalStore.lightweightContentFingerprintForTest(base),
      isNot(
        ConversationLocalStore.lightweightContentFingerprintForTest(changed),
      ),
    );
  });

  test('lightweight fingerprint changes when custom data changes', () {
    final base = V2TimConversation(
      conversationID: 'c2c_u1',
      type: 1,
      userID: 'u1',
      customData: 'before',
    );
    final changed = V2TimConversation(
      conversationID: 'c2c_u1',
      type: 1,
      userID: 'u1',
      customData: 'after',
    );
    expect(
      ConversationLocalStore.lightweightContentFingerprintForTest(base),
      isNot(
        ConversationLocalStore.lightweightContentFingerprintForTest(changed),
      ),
    );
  });
}
