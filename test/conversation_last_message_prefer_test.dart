import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_last_message_prefer.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_last_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_text_elem.dart';

V2TimMessage _base({
  required String msgID,
  required int ts,
  required int elemType,
  int status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
  String? seq,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': ts,
    'message_msg_id': msgID,
    'message_is_from_self': true,
    'message_status': status,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = elemType;
  message.msgID = msgID;
  message.timestamp = ts;
  message.seq = seq;
  return message;
}

V2TimMessage _sequencedText({
  required String id,
  required String text,
  required int ts,
  required String seq,
}) {
  final message = _text(id: id, text: text, ts: ts);
  message.seq = seq;
  return message;
}

V2TimMessage _text({
  required String id,
  required String text,
  required int ts,
  int status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
}) {
  final message = _base(
    msgID: id,
    ts: ts,
    elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
    status: status,
  );
  message.textElem = V2TimTextElem(text: text);
  return message;
}

V2TimMessage _weakCustom({
  required String id,
  required int ts,
}) {
  final message = _base(
    msgID: id,
    ts: ts,
    elemType: MessageElemType.V2TIM_ELEM_TYPE_CUSTOM,
  );
  message.customElem = V2TimCustomElem(data: '{"businessID":"unknown_xyz"}');
  return message;
}

V2TimMessage _friendTip({
  required String id,
  required int ts,
}) {
  final message = _base(
    msgID: id,
    ts: ts,
    elemType: MessageElemType.V2TIM_ELEM_TYPE_CUSTOM,
  );
  message.customElem = V2TimCustomElem(
    data:
        '{"businessID":"$kFriendBecameFriendsBusinessID","text":"你们已成为好友，现在可以开始聊天了"}',
  );
  message.userID = 'peer_new';
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('weak custom is detected via business-message fallback', () {
    final weak = _weakCustom(id: 'c1', ts: 2);
    expect(ConversationLastMessagePrefer.isWeakCustomLastMessage(weak), isTrue);
    expect(lightCustomConversationPreview(weak), isNull);
    expect(
      ConversationLastMessagePrefer.isStrongLastMessage(
        _text(id: 't1', text: 'hello', ts: 1),
      ),
      isTrue,
    );
  });

  test('prefer keeps strong text over newer weak custom', () {
    final text = _text(id: 't1', text: 'hello', ts: 10);
    final weak = _weakCustom(id: 'c1', ts: 20);
    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: text,
      incoming: weak,
    );
    expect(preferred?.msgID, 't1');
    expect(preferred?.textElem?.text, 'hello');
  });

  test('prefer keeps strong text over newer friend became friends tip', () {
    final text = _text(id: 't1', text: '最近聊的内容', ts: 10);
    final tip = _friendTip(id: 'tip1', ts: 20);
    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: text,
      incoming: tip,
    );
    expect(preferred?.msgID, 't1');
    expect(preferred?.textElem?.text, '最近聊的内容');
    expect(ConversationLastMessagePrefer.isWeakCustomLastMessage(tip), isTrue);
  });

  test('prefer allows friend tip when no existing last message', () {
    final tip = _friendTip(id: 'tip1', ts: 1);
    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: null,
      incoming: tip,
    );
    expect(preferred?.msgID, 'tip1');
  });

  test('prefer allows weak when no existing', () {
    final weak = _weakCustom(id: 'c1', ts: 1);
    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: null,
      incoming: weak,
    );
    expect(preferred?.msgID, 'c1');
  });

  test('prefer allows newer strong text over older text', () {
    final older = _text(id: 't1', text: 'old', ts: 10);
    final newer = _text(id: 't2', text: 'new', ts: 20);
    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: older,
      incoming: newer,
    );
    expect(preferred?.msgID, 't2');
  });

  test('same-second messages use server seq instead of callback order', () {
    final newer = _sequencedText(
      id: 'm-new',
      text: 'new',
      ts: 20,
      seq: '102',
    );
    final delayedOlder = _sequencedText(
      id: 'm-old',
      text: 'old',
      ts: 20,
      seq: '101',
    );
    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: newer,
      incoming: delayedOlder,
    );
    expect(preferred?.msgID, 'm-new');
  });

  test('same-second unsequenced delayed object cannot replace preview', () {
    final current = _text(id: 'm-current', text: 'current', ts: 20);
    final delayed = _text(id: 'm-delayed', text: 'delayed', ts: 20);
    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: current,
      incoming: delayed,
    );
    expect(preferred?.msgID, 'm-current');
  });

  test('new local sending message can replace same-second preview without seq',
      () {
    final current = _text(id: 'm-current', text: 'current', ts: 20);
    final sending = V2TimMessage.fromJson(<String, dynamic>{
      'message_server_time': 20,
      'message_msg_id': 'm-sending',
      'message_is_from_self': true,
      'message_status': MessageStatus.V2TIM_MSG_STATUS_SENDING,
      'message_custom_str': '',
      'message_risk_type_identified': 0,
      'message_sender_group_member_info': <String, dynamic>{},
      'message_group_at_user_array': <String>[],
    })
      ..elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT
      ..textElem = V2TimTextElem(text: 'sending');
    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: current,
      incoming: sending,
    );
    expect(preferred?.msgID, 'm-sending');
  });

  test('prefer upgrades same id SUCC to revoked', () {
    final succ = _text(id: 'img1', text: 'pic', ts: 100);
    succ.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    final revoked = _text(id: 'img1', text: 'pic', ts: 100);
    applyRevokedStateToMessage(revoked);
    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: succ,
      incoming: revoked,
    );
    expect(preferred?.msgID, 'img1');
    expect(isRevokedMessage(preferred), isTrue);
  });

  test('prefer keeps revoked over late SUCC same id', () {
    final revoked = _text(id: 'img1', text: 'pic', ts: 100);
    applyRevokedStateToMessage(revoked);
    final succ = _text(id: 'img1', text: 'pic', ts: 100);
    succ.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: revoked,
      incoming: succ,
    );
    expect(isRevokedMessage(preferred), isTrue);
  });

  test('same msgID content enrichment wins even with an older timestamp', () {
    final existing = _text(id: 'same', text: '旧预览', ts: 100);
    final incoming = _text(id: 'same', text: '补全后的预览', ts: 0);

    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: existing,
      incoming: incoming,
    );

    expect(preferred?.textElem?.text, '补全后的预览');
  });

  test('same msgID peer-read enrichment wins without regressing status', () {
    final existing = _text(id: 'same-read', text: '已发送', ts: 100)
      ..isPeerRead = false;
    final incoming = _text(id: 'same-read', text: '已发送', ts: 100)
      ..isPeerRead = true;

    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: existing,
      incoming: incoming,
    );

    expect(preferred?.isPeerRead, isTrue);
  });

  test('late same msgID content cannot regress a terminal send status', () {
    final existing = _text(id: 'same-status', text: '正文', ts: 100)
      ..status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    final incoming = _text(
      id: 'same-status',
      text: '补充字段',
      ts: 100,
      status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
    );

    final preferred = ConversationLastMessagePrefer.preferLastMessage(
      existing: existing,
      incoming: incoming,
    );

    expect(preferred?.status, MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC);
    expect(preferred?.textElem?.text, '正文');
  });
}
