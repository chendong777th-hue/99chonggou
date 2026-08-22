import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/enum/conversation_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

void main() {
  test('typed sync flag defaults on and mixed path retired', () {
    expect(ConversationPerfFlags.conversationTypedByFilterSyncEnabled, isTrue);
    expect(ConversationPerfFlags.c2cCursorHealEnabled, isTrue);
  });

  test('ConversationSyncMeta haveMoreForType and withTypedCursor', () {
    const meta = ConversationSyncMeta(
      c2cNextSeq: '0',
      c2cHaveMore: true,
      groupNextSeq: '3',
      groupHaveMore: false,
    );
    expect(meta.haveMoreForType(ConversationType.V2TIM_C2C), isTrue);
    expect(meta.haveMoreForType(ConversationType.V2TIM_GROUP), isFalse);
    expect(meta.nextSeqForType(2), '3');
    expect(meta.haveMore, isTrue);

    final next = meta.withTypedCursor(
      convType: ConversationType.V2TIM_C2C,
      nextSeq: '9',
      haveMore: false,
      hasSyncedOnce: true,
    );
    expect(next.c2cNextSeq, '9');
    expect(next.c2cHaveMore, isFalse);
    expect(next.groupHaveMore, isFalse);
    expect(next.haveMore, isFalse);
    expect(next.hasSyncedOnce, isTrue);
    expect(next.groupNextSeq, '3');
  });

  test('copyWith recomputes aggregate haveMore from typed flags', () {
    const meta = ConversationSyncMeta(
      c2cHaveMore: true,
      groupHaveMore: true,
    );
    final next = meta.copyWith(c2cHaveMore: false);
    expect(next.haveMore, isTrue);
    final done = next.copyWith(groupHaveMore: false);
    expect(done.haveMore, isFalse);
  });

  test('V2TimConversationFilter type constants match store conv_type', () {
    expect(ConversationType.V2TIM_C2C, 1);
    expect(ConversationType.V2TIM_GROUP, 2);
    final sample = V2TimConversation(
      conversationID: 'c2c_u1',
      type: ConversationType.V2TIM_C2C,
      userID: 'u1',
    );
    expect(sample.type, 1);
  });

  test('shouldHealC2cCursor when cursor dead and rows below floor', () {
    expect(
      ConversationSyncService.shouldHealC2cCursor(
        healEnabled: true,
        c2cHaveMore: false,
        c2cRowCount: 3,
        healFloor: 40,
      ),
      isTrue,
    );
    expect(
      ConversationSyncService.shouldHealC2cCursor(
        healEnabled: true,
        c2cHaveMore: false,
        c2cRowCount: 40,
        healFloor: 40,
      ),
      isFalse,
    );
    expect(
      ConversationSyncService.shouldHealC2cCursor(
        healEnabled: true,
        c2cHaveMore: true,
        c2cRowCount: 3,
        healFloor: 40,
      ),
      isFalse,
    );
    expect(
      ConversationSyncService.shouldHealC2cCursor(
        healEnabled: false,
        c2cHaveMore: false,
        c2cRowCount: 3,
        healFloor: 40,
      ),
      isFalse,
    );
  });
}
