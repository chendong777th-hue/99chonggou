import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

V2TimMessage _msg({
  required String msgID,
  required int ts,
  required int elemType,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': ts,
    'message_msg_id': msgID,
    'message_seq': '1',
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
    'elem_type': elemType,
  });
  message.timestamp = ts;
  message.elemType = elemType;
  message.msgID = msgID;
  return message;
}

void main() {
  test('empty group tip does not anchor a time divider', () {
    expect(
      TUIChatGlobalModel.messageAnchorsTimeDivider(
        _msg(
          msgID: 'tip',
          ts: 1000,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS,
        ),
      ),
      isFalse,
    );
    expect(
      TUIChatGlobalModel.messageAnchorsTimeDivider(
        _msg(
          msgID: 'm1',
          ts: 1000,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        ),
      ),
      isTrue,
    );
  });

  test('invisible message between batches does not leave orphan divider', () {
    final tipTs = DateTime(2026, 7, 20, 21, 54).millisecondsSinceEpoch ~/ 1000;
    final msgTs = DateTime(2026, 7, 20, 22, 9).millisecondsSinceEpoch ~/ 1000;
    final attached = TUIChatGlobalModel.attachTimeDividersForTesting(
      [
        _msg(
          msgID: 'tip',
          ts: tipTs,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS,
        ),
        _msg(
          msgID: 'm1',
          ts: msgTs,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        ),
        _msg(
          msgID: 'm2',
          ts: msgTs,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        ),
      ],
      intervalSeconds: 300,
    );

    final dividers = attached
        .where((m) => m.elemType == 11)
        .map((m) => m.timestamp)
        .toList();
    expect(dividers, [msgTs]);
    expect(attached.where((m) => m.elemType != 11).map((m) => m.msgID), [
      'm1',
      'm2',
    ]);
  });

  test('stripOrphanTimeDividers removes consecutive and trailing dividers', () {
    final cleaned = TUIChatGlobalModel.stripOrphanTimeDividersForTesting([
      _msg(msgID: 'time-divider-1000', ts: 1000, elemType: 11),
      _msg(msgID: 'time-divider-orphan', ts: 1500, elemType: 11),
      _msg(
        msgID: 'a',
        ts: 1000,
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      ),
      _msg(msgID: 'time-divider-2000', ts: 2000, elemType: 11),
      _msg(
        msgID: 'b',
        ts: 2000,
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      ),
      _msg(msgID: 'time-divider-tail', ts: 3000, elemType: 11),
    ]);

    expect(
      cleaned.map((m) => m.msgID).toList(),
      ['time-divider-orphan', 'a', 'time-divider-2000', 'b'],
    );
  });

  test('gap over interval still inserts a divider between visible messages',
      () {
    final attached = TUIChatGlobalModel.attachTimeDividersForTesting(
      [
        _msg(
          msgID: 'early',
          ts: 1000,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        ),
        _msg(
          msgID: 'late',
          ts: 1000 + 301,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        ),
      ],
      intervalSeconds: 300,
    );
    expect(attached.where((m) => m.elemType == 11).length, 2);
    expect(
      attached.map((m) => m.elemType).toList(),
      [
        11,
        MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        11,
        MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      ],
    );
  });

  test('crossing midnight inserts a divider even within the interval', () {
    final beforeMidnight =
        DateTime(2026, 7, 20, 23, 59).millisecondsSinceEpoch ~/ 1000;
    final afterMidnight =
        DateTime(2026, 7, 21, 0, 1).millisecondsSinceEpoch ~/ 1000;
    final attached = TUIChatGlobalModel.attachTimeDividersForTesting(
      [
        _msg(
            msgID: 'before',
            ts: beforeMidnight,
            elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT),
        _msg(
            msgID: 'after',
            ts: afterMidnight,
            elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT),
      ],
      intervalSeconds: 300,
    );

    expect(attached.where((m) => m.elemType == 11).length, 2);
  });
}
