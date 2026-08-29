import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_shadow_bridge.dart';
import 'package:tencent_cloud_chat_sdk/enum/conversation_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

V2TimConversation _conversation({
  String id = 'group_room',
  String messageId = 'message',
  int timestamp = 1,
  int unread = 0,
  String? showName,
}) {
  return V2TimConversation(
    conversationID: id,
    type: ConversationType.V2TIM_GROUP,
    groupID: 'room',
    unreadCount: unread,
    showName: showName,
    lastMessage: V2TimMessage.fromJson(<String, dynamic>{
      'message_msg_id': messageId,
      'message_server_time': timestamp,
      'message_status': 2,
      'message_custom_str': '',
      'message_risk_type_identified': 0,
      'message_sender_group_member_info': <String, dynamic>{},
      'message_group_at_user_array': <String>[],
      'message_conv_type': ConversationType.V2TIM_GROUP,
      'message_conv_id': 'room',
      'message_elem_array': const <dynamic>[],
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationMutationShadowBridge', () {
    late ConversationMutationShadowBridge bridge;

    setUp(() {
      bridge = ConversationMutationShadowBridge.instance;
      bridge.resetForTest();
    });

    tearDown(() {
      bridge.resetForTest();
    });

    test('realtime projection is not rolled back by an older SDK page',
        () async {
      bridge.observeSdkConversations(
        ownerUserId: 'owner',
        conversations: [
          _conversation(
            messageId: 'new',
            timestamp: 20,
            unread: 4,
          ),
        ],
        source: ConversationMutationSource.sdkRealtime,
      );
      bridge.observeSdkConversations(
        ownerUserId: 'owner',
        conversations: [
          _conversation(
            messageId: 'old',
            timestamp: 10,
            unread: 1,
          ),
        ],
        source: ConversationMutationSource.sdkPage,
      );
      await bridge.flush();

      final snapshot = bridge.coordinator.snapshot(
        ownerUserId: 'owner',
        conversationId: 'group_room',
        conversationType: ConversationMutationConversationType.group,
      );
      final last = snapshot?.values[ConversationMutationField.lastMessage]
          as ConversationShadowLastMessage?;
      expect(last?.messageId, 'new');
      expect(snapshot?.values[ConversationMutationField.unread], 4);
    });

    test('authoritative commit rejects an older SDK page after realtime',
        () async {
      final realtime = await bridge.admitSdkConversationsForCommit(
        ownerUserId: 'owner',
        conversations: [
          _conversation(
            messageId: 'new',
            timestamp: 20,
            unread: 4,
          ),
        ],
        source: ConversationMutationSource.sdkRealtime,
      );
      final stalePage = await bridge.admitSdkConversationsForCommit(
        ownerUserId: 'owner',
        conversations: [
          _conversation(
            messageId: 'old',
            timestamp: 10,
            unread: 1,
          ),
        ],
        source: ConversationMutationSource.sdkPage,
      );

      expect(realtime, hasLength(1));
      expect(stalePage, isEmpty);
    });

    test('authoritative SDK rows produce one concrete Store commit plan',
        () async {
      final conversation = _conversation(
        messageId: 'server-message',
        timestamp: 30,
        unread: 2,
      );
      final commits = await bridge.prepareSdkConversationCommits(
        ownerUserId: 'owner',
        conversations: [conversation],
        source: ConversationMutationSource.sdkRealtime,
      );

      expect(commits, hasLength(1));
      expect(commits.single.conversation, same(conversation));
      expect(
        commits.single.plan.changeType,
        ConversationDatabaseChangeType.upsert,
      );
      expect(commits.single.plan.fullSnapshot, same(conversation));
      expect(commits.single.plan.tombstone, isFalse);
      expect(commits.single.plan.idempotencyKey, isNotEmpty);
    });

    test('local read barrier uses message version and blocks old SDK unread',
        () async {
      bridge.observeSdkConversations(
        ownerUserId: 'owner',
        conversations: [
          _conversation(messageId: 'read-message', timestamp: 100, unread: 4),
        ],
        source: ConversationMutationSource.sdkRealtime,
      );
      await bridge.flush();

      final readPlan = await bridge.prepareLocalIntentCommit(
        ownerUserId: 'owner',
        conversationId: 'group_room',
        fieldPatch: const <ConversationMutationField, Object?>{
          ConversationMutationField.unread: 0,
        },
        sourceVersion: 101,
      );
      expect(readPlan, isNotNull);

      bridge.observeSdkConversations(
        ownerUserId: 'owner',
        conversations: [
          _conversation(messageId: 'read-message', timestamp: 100, unread: 4),
        ],
        source: ConversationMutationSource.sdkRealtime,
      );
      await bridge.flush();

      final snapshot = bridge.coordinator.snapshot(
        ownerUserId: 'owner',
        conversationId: 'group_room',
        conversationType: ConversationMutationConversationType.group,
      );
      expect(snapshot?.values[ConversationMutationField.unread], 0);
    });

    test('delete blocks late page and new conversation recreates generation',
        () async {
      bridge.observeSdkConversations(
        ownerUserId: 'owner',
        conversations: [_conversation(messageId: 'before')],
        source: ConversationMutationSource.sdkRealtime,
      );
      bridge.observeSdkDeleted(
        ownerUserId: 'owner',
        conversationIds: const ['group_room'],
      );
      bridge.observeSdkConversations(
        ownerUserId: 'owner',
        conversations: [_conversation(messageId: 'late', timestamp: 50)],
        source: ConversationMutationSource.sdkPage,
      );
      await bridge.flush();
      expect(
        bridge.coordinator
            .snapshot(
              ownerUserId: 'owner',
              conversationId: 'group_room',
              conversationType: ConversationMutationConversationType.group,
            )
            ?.deleted,
        isTrue,
      );

      bridge.observeSdkConversations(
        ownerUserId: 'owner',
        conversations: [_conversation(messageId: 'rejoined', timestamp: 60)],
        source: ConversationMutationSource.sdkRealtime,
        allowRecreate: true,
      );
      await bridge.flush();
      final recreated = bridge.coordinator.snapshot(
        ownerUserId: 'owner',
        conversationId: 'group_room',
        conversationType: ConversationMutationConversationType.group,
      );
      expect(recreated?.deleted, isFalse);
      expect(recreated?.conversationGeneration, 2);
    });

    test('authoritative commit tombstones delete until new conversation',
        () async {
      final initial = await bridge.admitSdkConversationsForCommit(
        ownerUserId: 'owner',
        conversations: [_conversation(messageId: 'before')],
        source: ConversationMutationSource.sdkRealtime,
      );
      final deleted = await bridge.admitSdkDeletedForCommit(
        ownerUserId: 'owner',
        conversationIds: const ['group_room'],
      );
      final latePage = await bridge.admitSdkConversationsForCommit(
        ownerUserId: 'owner',
        conversations: [_conversation(messageId: 'late', timestamp: 50)],
        source: ConversationMutationSource.sdkPage,
      );
      final recreated = await bridge.admitSdkConversationsForCommit(
        ownerUserId: 'owner',
        conversations: [_conversation(messageId: 'rejoined', timestamp: 60)],
        source: ConversationMutationSource.sdkRealtime,
        allowRecreate: true,
      );

      expect(initial, hasLength(1));
      expect(deleted, const ['group_room']);
      expect(latePage, isEmpty);
      expect(recreated, hasLength(1));
    });

    test('SDK delete produces a tombstone Store commit plan', () async {
      final plans = await bridge.prepareSdkDeleteCommits(
        ownerUserId: 'owner',
        conversationIds: const ['group_room'],
      );

      expect(plans, hasLength(1));
      expect(plans.single.changeType, ConversationDatabaseChangeType.delete);
      expect(plans.single.tombstone, isTrue);
      expect(plans.single.fullSnapshot, isNull);
    });

    test('durable generation is restored before delete and recreate', () async {
      bridge.restoreDurableConversationState(
        ownerUserId: 'owner',
        conversationId: 'group_room',
        generation: 4,
        tombstoned: false,
      );
      final deleted = await bridge.prepareSdkDeleteCommits(
        ownerUserId: 'owner',
        conversationIds: const ['group_room'],
      );
      expect(deleted.single.generation, 5);

      final recreated = await bridge.prepareSdkConversationCommits(
        ownerUserId: 'owner',
        conversations: <V2TimConversation>[_conversation()],
        source: ConversationMutationSource.sdkRealtime,
        allowRecreate: true,
      );
      expect(recreated.single.plan.generation, 6);
      expect(recreated.single.plan.recreatesDeletedConversation, isTrue);
    });

    test('local draft produces a typed patch plan without full snapshot',
        () async {
      final plan = await bridge.prepareLocalIntentCommit(
        ownerUserId: 'owner-a',
        conversationId: 'c2c_peer-a',
        fieldPatch: const <ConversationMutationField, Object?>{
          ConversationMutationField.draft: 'draft',
        },
      );

      expect(plan, isNotNull);
      expect(plan!.changeType, ConversationDatabaseChangeType.upsert);
      expect(plan.fullSnapshot, isNull);
      expect(plan.fieldPatch, const <ConversationMutationField, Object?>{
        ConversationMutationField.draft: 'draft',
      });
    });

    test('local mark-read produces an unread-zero patch plan', () async {
      final plan = await bridge.prepareLocalIntentCommit(
        ownerUserId: 'owner-a',
        conversationId: 'group_room',
        fieldPatch: const <ConversationMutationField, Object?>{
          ConversationMutationField.unread: 0,
        },
      );

      expect(plan, isNotNull);
      expect(plan!.fullSnapshot, isNull);
      expect(plan.fieldPatch[ConversationMutationField.unread], 0);
    });

    test('local pin produces a typed boolean patch plan', () async {
      final conversation = _conversation();
      final plan = await bridge.prepareLocalIntentCommit(
        ownerUserId: 'owner-a',
        conversationId: 'group_room',
        fieldPatch: const <ConversationMutationField, Object?>{
          ConversationMutationField.pin: true,
        },
        fullSnapshot: conversation,
      );

      expect(plan, isNotNull);
      expect(plan!.fullSnapshot, same(conversation));
      expect(plan.fieldPatch[ConversationMutationField.pin], isTrue);
    });

    test('local mute produces a typed recvOpt patch plan', () async {
      final conversation = _conversation();
      final plan = await bridge.prepareLocalIntentCommit(
        ownerUserId: 'owner-a',
        conversationId: 'group_room',
        fieldPatch: const <ConversationMutationField, Object?>{
          ConversationMutationField.mute: 2,
        },
        fullSnapshot: conversation,
      );

      expect(plan, isNotNull);
      expect(plan!.fullSnapshot, same(conversation));
      expect(plan.fieldPatch[ConversationMutationField.mute], 2);
    });

    test('session clear rejects queued old-owner state', () async {
      bridge.observeSdkConversations(
        ownerUserId: 'owner_a',
        conversations: [_conversation(unread: 9)],
        source: ConversationMutationSource.sdkRealtime,
      );
      await bridge.flush();
      bridge.clearSession();
      bridge.observeSdkConversations(
        ownerUserId: 'owner_b',
        conversations: [_conversation(unread: 1)],
        source: ConversationMutationSource.sdkRealtime,
      );
      await bridge.flush();

      expect(
        bridge.coordinator.snapshot(
          ownerUserId: 'owner_a',
          conversationId: 'group_room',
          conversationType: ConversationMutationConversationType.group,
        ),
        isNull,
      );
      expect(
        bridge.coordinator
            .snapshot(
              ownerUserId: 'owner_b',
              conversationId: 'group_room',
              conversationType: ConversationMutationConversationType.group,
            )
            ?.values[ConversationMutationField.unread],
        1,
      );
    });

    test('comparison reports only changed SDK-owned fields', () async {
      final authoritative = _conversation(
        messageId: 'new',
        timestamp: 20,
        unread: 4,
      );
      bridge.observeSdkConversations(
        ownerUserId: 'owner',
        conversations: [authoritative],
        source: ConversationMutationSource.sdkRealtime,
      );

      final same = await bridge.compareLegacyProjection(
        ownerUserId: 'owner',
        conversations: [authoritative],
      );
      expect(same, isEmpty);

      final stale = _conversation(
        messageId: 'old',
        timestamp: 10,
        unread: 1,
      );
      final differences = await bridge.compareLegacyProjection(
        ownerUserId: 'owner',
        conversations: [stale],
      );
      expect(differences, hasLength(1));
      expect(
        differences.single.fields,
        containsAll(<ConversationMutationField>{
          ConversationMutationField.lastMessage,
          ConversationMutationField.unread,
        }),
      );
    });
  });
}
