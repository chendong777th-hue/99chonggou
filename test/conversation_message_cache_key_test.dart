import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

V2TimMessage _histMsg({
  required String msgID,
  required int timestamp,
  bool isSelf = true,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': timestamp,
    'message_msg_id': msgID,
    'message_is_from_self': isSelf,
    'message_status': MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
    'elem_type': MessageElemType.V2TIM_ELEM_TYPE_TEXT,
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
  message.msgID = msgID;
  message.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
  message.timestamp = timestamp;
  message.isSelf = isSelf;
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setupServiceLocator();
  });

  test('C2C cache key is always c2c_<canonical uid>', () {
    final withUser = V2TimConversation(
      conversationID: 'c2c_peer_a',
      userID: 'peer_a',
      type: 1,
      lastMessage: null,
    );
    expect(
      ConversationPreviewHistorySync.conversationMessageCacheKey(withUser),
      'c2c_peer_a',
    );

    final convOnly = V2TimConversation(
      conversationID: 'c2c_peer_a',
      userID: '',
      type: 1,
      lastMessage: null,
    );
    expect(
      ConversationPreviewHistorySync.conversationMessageCacheKey(convOnly),
      'c2c_peer_a',
    );
  });

  test('history storage key merges bare uid and c2c_ alias', () {
    expect(
      TUIChatGlobalModel.canonicalHistoryStorageKey('peer_a'),
      'c2c_peer_a',
    );
    expect(
      TUIChatGlobalModel.canonicalHistoryStorageKey('c2c_peer_a'),
      'c2c_peer_a',
    );
    expect(
      TUIChatGlobalModel.isSameConversationIdForHistory(
        'peer_a',
        'c2c_peer_a',
      ),
      isTrue,
    );
  });

  test('group short code stays a group storage key', () {
    expect(
      TUIChatGlobalModel.canonicalHistoryStorageKey('m23RIKZN5C2'),
      'm23RIKZN5C2',
    );
    expect(
      TUIChatGlobalModel.canonicalHistoryStorageKey('group_m23RIKZN5C2'),
      'm23RIKZN5C2',
    );
    expect(
      TUIChatGlobalModel.isSameConversationIdForHistory(
        'group_m23RIKZN5C2',
        'm23RIKZN5C2',
      ),
      isTrue,
    );
    expect(
      TUIChatGlobalModel.isSameConversationIdForHistory(
        'c2c_m23rikzn5c2',
        'm23RIKZN5C2',
      ),
      isFalse,
    );
  });

  test('typed group conversation is not rewritten to c2c even with userID', () {
    final group = V2TimConversation(
      conversationID: 'group_m23RIKZN5C2',
      groupID: 'm23RIKZN5C2',
      userID: 'peer_a',
      type: 2,
      lastMessage: null,
    );
    expect(
      ConversationPreviewHistorySync.conversationMessageCacheKey(group),
      'm23RIKZN5C2',
    );
  });

  test('community TGS ids stay equivalent across group_ prefix', () {
    expect(
      TUIChatGlobalModel.isSameConversationIdForHistory(
        '@TGS#_mc2SX4NMM62CZ',
        'group_@TGS#_mc2SX4NMM62CZ',
      ),
      isTrue,
    );
  });

  test('older page merge keeps c2c tip when bare map slot is empty', () {
    final model = serviceLocator<TUIChatGlobalModel>();
    const c2cKey = 'c2c_alice_050';
    const bareKey = 'alice_050';
    addTearDown(() => model.removeMessageList(c2cKey));

    final tip = _histMsg(msgID: 'tip-200', timestamp: 200);
    final onC2c = <V2TimMessage>[
      tip,
      for (var i = 0; i < 4; i++)
        _histMsg(msgID: 'kept-$i', timestamp: 190 - i),
    ];
    model.setMessageList(
      c2cKey,
      onC2c,
      needResetNewMessageCount: false,
      replace: true,
    );

    expect(model.messageListMap[bareKey], isNull);
    expect(
      model.mergedAliasMessageList(bareKey).any((m) => m.msgID == 'tip-200'),
      isTrue,
    );

    final olderPage = <V2TimMessage>[
      for (var i = 0; i < 20; i++)
        _histMsg(msgID: 'old-$i', timestamp: 100 - i),
    ];
    final lost = TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: model.messageListMap[bareKey],
      fetched: olderPage,
    );
    expect(lost.any((m) => m.msgID == 'tip-200'), isFalse);
    expect(lost.length, 20);

    final kept = TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: model.mergedAliasMessageList(bareKey),
      fetched: olderPage,
    );
    expect(kept.any((m) => m.msgID == 'tip-200'), isTrue);
    expect(kept.first.msgID, 'tip-200');
  });
}
