import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_last_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_tips_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_tips_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';

V2TimMessage _groupTips({
  required String msgID,
  required String opUserId,
  required String groupId,
  int type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_GROUP_INFO_CHANGE,
  List<V2TimGroupChangeInfo?>? changes,
  List<V2TimGroupMemberInfo?>? members,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': 100,
    'message_msg_id': msgID,
    'message_is_from_self': false,
    'message_status': MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS;
  message.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
  message.msgID = msgID;
  message.groupID = groupId;
  message.timestamp = 100;
  message.groupTipsElem = V2TimGroupTipsElem(
    groupID: groupId,
    type: type,
    opMember: V2TimGroupMemberInfo(userID: opUserId),
    memberList: members,
    groupChangeInfoList: changes,
    memberCount: 3,
  );
  return message;
}

void main() {
  test('group tip cache key changes when operator is patched', () {
    final before = _groupTips(
      msgID: 'gt1',
      opUserId: '',
      groupId: '@TGS#123',
    );
    final after = _groupTips(
      msgID: 'gt1',
      opUserId: 'owner_uid',
      groupId: '@TGS#123',
    );
    expect(groupTipsPreviewFingerprint(before), isNot(groupTipsPreviewFingerprint(after)));
    expect(
      conversationPreviewCacheMessageKey(before),
      isNot(conversationPreviewCacheMessageKey(after)),
    );
  });

  test('group tip cache key changes when group name change info updates', () {
    final before = _groupTips(
      msgID: 'gt2',
      opUserId: 'owner_uid',
      groupId: '@TGS#123',
      changes: [
        V2TimGroupChangeInfo(type: 1, value: '旧群名'),
      ],
    );
    final after = _groupTips(
      msgID: 'gt2',
      opUserId: 'owner_uid',
      groupId: '@TGS#123',
      changes: [
        V2TimGroupChangeInfo(type: 1, value: '新群名'),
      ],
    );
    expect(
      conversationPreviewCacheMessageKey(before),
      isNot(conversationPreviewCacheMessageKey(after)),
    );
  });

  test('plain text messages have empty group-tip fingerprint', () {
    final message = V2TimMessage.fromJson(<String, dynamic>{
      'message_server_time': 100,
      'message_msg_id': 't1',
      'message_is_from_self': true,
      'message_status': MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      'message_custom_str': '',
      'message_risk_type_identified': 0,
      'message_sender_group_member_info': <String, dynamic>{},
      'message_group_at_user_array': <String>[],
    });
    message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
    expect(groupTipsPreviewFingerprint(message), isEmpty);
  });
}
