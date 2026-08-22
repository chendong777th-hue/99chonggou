import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_tab_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart';

V2TimConversation _c2c(String id, {int unread = 0, bool pinned = false}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    unreadCount: unread,
    isPinned: pinned,
    orderkey: unread + (pinned ? 1000 : 0),
    showName: id,
  );
}

V2TimMessage _textMessage(String text, {String msgID = 'msg_preview'}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_msg_id': msgID,
    'message_server_time': 1700000000,
    'message_is_from_self': true,
    'message_status': 1,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.msgID = msgID;
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
  message.textElem = V2TimTextElem(text: text);
  message.userID = 'peer';
  return message;
}

V2TimMessage _friendTipMessage({String msgID = 'tip_preview'}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_msg_id': msgID,
    'message_server_time': 1700001000,
    'message_is_from_self': true,
    'message_status': 1,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.msgID = msgID;
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
  message.userID = 'peer';
  message.customElem = V2TimCustomElem(
    data:
        '{"businessID":"$kFriendBecameFriendsBusinessID","text":"你们已成为好友，现在可以开始聊天了"}',
  );
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ConversationPerfFlags.conversationListSdkPrimary = false;
    ConversationTabStore.debugFetchOverride = null;
    ConversationTabStore.instance.clear();
    ConversationListNotifier.instance.setConversationsForTest(const []);
  });

  tearDown(() {
    ConversationPerfFlags.conversationListSdkPrimary = false;
    ConversationTabStore.debugFetchOverride = null;
    ConversationTabStore.instance.clear();
    ConversationListNotifier.instance.setConversationsForTest(const []);
    ConversationPinSyncService.instance.debugReplacePinnedIdsForTest(const {});
  });

  test('flag off: ensurePrimed is no-op', () async {
    var fetches = 0;
    ConversationTabStore.debugFetchOverride = ({
      required int convType,
      required String nextSeq,
      required int count,
    }) async {
      fetches++;
      return (
        conversationList: <V2TimConversation>[_c2c('c2c_a')],
        nextSeq: '0',
        isFinished: true,
        code: 0,
        desc: '',
      );
    };
    await ConversationTabStore.instance.ensurePrimed(convType: 1);
    expect(fetches, 0);
    expect(ConversationTabStore.instance.countForType(1), 0);
  });

  test('flag on: loadFirstPage + loadMore via filter override', () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    final pages = <String, List<V2TimConversation>>{
      '0': [_c2c('c2c_1'), _c2c('c2c_2')],
      '2': [_c2c('c2c_3')],
    };
    ConversationTabStore.debugFetchOverride = ({
      required int convType,
      required String nextSeq,
      required int count,
    }) async {
      expect(convType, 1);
      final page = pages[nextSeq] ?? const <V2TimConversation>[];
      final finished = nextSeq != '0';
      return (
        conversationList: page,
        nextSeq: finished ? '0' : '2',
        isFinished: finished,
        code: 0,
        desc: '',
      );
    };

    await ConversationTabStore.instance.loadFirstPage(convType: 1, count: 2);
    expect(ConversationTabStore.instance.countForType(1), 2);
    expect(ConversationTabStore.instance.finishedForType(1), isFalse);

    await ConversationTabStore.instance.loadMore(convType: 1, count: 2);
    expect(ConversationTabStore.instance.countForType(1), 3);
    expect(ConversationTabStore.instance.finishedForType(1), isTrue);
    expect(
      ConversationTabStore.instance.itemsForType(1).map((c) => c.conversationID),
      ['c2c_1', 'c2c_2', 'c2c_3'],
    );
  });

  test('applyPatches preserves preview and unread on pin metadata patch', () {
    final lastMessage = _textMessage('你好');
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [
        V2TimConversation(
          conversationID: 'c2c_peer',
          type: 1,
          userID: 'peer',
          unreadCount: 2,
          isPinned: false,
          orderkey: 1700000000,
          showName: '阿阳',
          lastMessage: lastMessage,
        ),
      ],
      finished: true,
    );
    ConversationPinSyncService.instance
        .debugReplacePinnedIdsForTest(const {'c2c_peer'});
    ConversationTabStore.instance.applyPatches([
      V2TimConversation(
        conversationID: 'c2c_peer',
        type: 1,
        userID: 'peer',
        unreadCount: 0,
        isPinned: true,
        orderkey: 1700000100,
        showName: '阿阳',
      ),
    ], reason: 'pin_sdk_changed');
    final row = ConversationTabStore.instance
        .itemsForType(1)
        .firstWhere((c) => c.conversationID == 'c2c_peer');
    expect(row.isPinned, isTrue);
    expect(row.lastMessage?.msgID, 'msg_preview');
    expect(row.unreadCount, 2);
  });

  test('applyPatches keeps chat preview over newer friend became friends tip', () {
    final chatPreview = _textMessage('最近聊的内容');
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [
        V2TimConversation(
          conversationID: 'c2c_peer',
          type: 1,
          userID: 'peer',
          unreadCount: 0,
          isPinned: false,
          orderkey: 1700000000,
          showName: '秋',
          lastMessage: chatPreview,
        ),
      ],
      finished: true,
    );
    ConversationTabStore.instance.applyPatches([
      V2TimConversation(
        conversationID: 'c2c_peer',
        type: 1,
        userID: 'peer',
        unreadCount: 0,
        isPinned: false,
        orderkey: 1700001000,
        showName: '秋',
        lastMessage: _friendTipMessage(),
      ),
    ], reason: 'friend_became_friends_sent');
    final row = ConversationTabStore.instance
        .itemsForType(1)
        .firstWhere((c) => c.conversationID == 'c2c_peer');
    expect(row.lastMessage?.msgID, 'msg_preview');
    expect(row.lastMessage?.textElem?.text, '最近聊的内容');
  });

  test('applyPatches updates in-window row and admits hot unread', () {
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [_c2c('c2c_old', unread: 0)],
      finished: true,
    );
    ConversationTabStore.instance.applyPatches([
      _c2c('c2c_old', unread: 3),
      _c2c('c2c_hot', unread: 1),
    ], reason: 'test');
    expect(ConversationTabStore.instance.countForType(1), 2);
    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .map((c) => c.conversationID)
          .toSet(),
      {'c2c_old', 'c2c_hot'},
    );
    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .firstWhere((c) => c.conversationID == 'c2c_old')
          .unreadCount,
      3,
    );
  });

  test('applyPatches keeps batched inserts in UI order', () {
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: const [],
      finished: true,
    );
    ConversationTabStore.instance.applyPatches(
      [
        _c2c('c2c_low', unread: 1),
        _c2c('c2c_high', unread: 5),
      ],
      reason: 'test',
      forceAdmitIds: {'c2c_low', 'c2c_high'},
    );
    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .map((c) => c.conversationID),
      ['c2c_high', 'c2c_low'],
    );
  });

  test('notifier sdk-primary: applyConversationsFromStore goes to TabStore',
      () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    final notifier = ConversationListNotifier.instance;
    notifier.ensureTabStoreBridgeAttached();
    await notifier.applyConversationsFromStore(
      upserted: [_c2c('c2c_bridge', unread: 2)],
    );
    expect(ConversationTabStore.instance.countForType(1), 1);
    expect(
      notifier.conversations.any((c) => c.conversationID == 'c2c_bridge'),
      isTrue,
    );
    expect(notifier.conversationAtTypeIndex(1, 0)?.conversationID, 'c2c_bridge');
  });

  test('flag off: applyConversationsFromStore stays on legacy path', () async {
    ConversationPerfFlags.conversationListSdkPrimary = false;
    final notifier = ConversationListNotifier.instance;
    await notifier.applyConversationsFromStore(
      upserted: [_c2c('c2c_legacy', unread: 1)],
    );
    expect(ConversationTabStore.instance.countForType(1), 0);
    expect(
      notifier.conversations.any((c) => c.conversationID == 'c2c_legacy'),
      isTrue,
    );
  });
}
