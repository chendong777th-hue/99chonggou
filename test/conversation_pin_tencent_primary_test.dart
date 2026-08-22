import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

void main() {
  setUp(() {
    ConversationPinSyncService.debugResetTestHooks();
    ConversationPinSyncService.debugAccountScopeOverride = 'pin_test_user';
    ConversationPinSyncService.debugSkipPersistAndUiForTest = true;
    ConversationPinSyncService.instance.clearSession();
    ConversationPinSyncService.instance.debugReplacePinnedIdsForTest(
      const <String>[],
    );
  });

  tearDown(() {
    ConversationPinSyncService.debugResetTestHooks();
    ConversationPinSyncService.instance.clearSession();
  });

  test('flags default to tencent-primary + follow-write + migrate', () {
    expect(ConversationPerfFlags.conversationPinTencentPrimary, isTrue);
    expect(ConversationPerfFlags.conversationPinFollowWriteBackend, isTrue);
    expect(
      ConversationPerfFlags.conversationPinMigrateBackendToTencentOnLogin,
      isTrue,
    );
  });

  test('TIM fail does not follow-write backend and keeps local set', () async {
    final timCalls = <({String id, bool pinned})>[];
    final followCalls = <({String chatType, String peerId, bool pinned})>[];

    ConversationPinSyncService.debugPinConversationOverride =
        (conversationID, isPinned) async {
      timCalls.add((id: conversationID, pinned: isPinned));
      return false;
    };
    ConversationPinSyncService.debugFollowWriteOverride = ({
      required chatType,
      required peerId,
      required pinned,
    }) async {
      followCalls.add(
        (chatType: chatType, peerId: peerId, pinned: pinned),
      );
    };

    final conversation = V2TimConversation(
      conversationID: 'c2c_u1',
      type: 1,
      userID: 'u1',
      isPinned: false,
    );

    final result = await ConversationPinService.instance.setPinned(
      conversation: conversation,
      isPinned: true,
      source: 'test_tim_fail',
    );

    expect(result.sdkOk, isFalse);
    expect(result.applied, isFalse);
    expect(result.isPinned, isFalse);
    expect(timCalls, hasLength(1));
    expect(timCalls.single.id, 'c2c_u1');
    expect(timCalls.single.pinned, isTrue);
    expect(followCalls, isEmpty);
    expect(
      ConversationPinSyncService.instance.isPinnedConversationId('c2c_u1'),
      isFalse,
    );
  });

  test('TIM ok then follow-write; follow-write fail still applied', () async {
    final order = <String>[];
    ConversationPinSyncService.debugPinConversationOverride =
        (conversationID, isPinned) async {
      order.add('tim:$conversationID:$isPinned');
      return true;
    };
    ConversationPinSyncService.debugFollowWriteOverride = ({
      required chatType,
      required peerId,
      required pinned,
    }) async {
      order.add('backend:$chatType:$peerId:$pinned');
      throw StateError('backend down');
    };

    final conversation = V2TimConversation(
      conversationID: 'c2c_u2',
      type: 1,
      userID: 'u2',
      isPinned: false,
    );

    final result = await ConversationPinService.instance.setPinned(
      conversation: conversation,
      isPinned: true,
      source: 'test_tim_ok',
    );

    expect(result.sdkOk, isTrue);
    expect(result.applied, isTrue);
    expect(result.isPinned, isTrue);
    expect(order, <String>[
      'tim:c2c_u2:true',
      'backend:c2c:u2:true',
    ]);
    expect(
      ConversationPinSyncService.instance.isPinnedConversationId('c2c_u2'),
      isTrue,
    );
  });

  test('unpin TIM ok updates local set and follow-writes false', () async {
    ConversationPinSyncService.instance.debugReplacePinnedIdsForTest(
      const <String>['group_g1'],
    );
    final followCalls = <bool>[];
    ConversationPinSyncService.debugPinConversationOverride =
        (conversationID, isPinned) async => true;
    ConversationPinSyncService.debugFollowWriteOverride = ({
      required chatType,
      required peerId,
      required pinned,
    }) async {
      followCalls.add(pinned);
    };

    final conversation = V2TimConversation(
      conversationID: 'group_g1',
      type: 2,
      groupID: 'g1',
      isPinned: true,
    );

    final result = await ConversationPinService.instance.setPinned(
      conversation: conversation,
      isPinned: false,
      source: 'test_unpin',
    );

    expect(result.applied, isTrue);
    expect(result.sdkOk, isTrue);
    expect(result.isPinned, isFalse);
    expect(followCalls, <bool>[false]);
    expect(
      ConversationPinSyncService.instance.isPinnedConversationId('group_g1'),
      isFalse,
    );
  });
}
